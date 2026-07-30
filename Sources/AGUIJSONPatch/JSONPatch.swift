import StructuredDataCore

/// RFC 6902 のパッチ操作。
public struct JSONPatchOperation: Codable, Sendable, Equatable {
    public enum Op: String, Codable, Sendable {
        case add
        case remove
        case replace
        case move
        case copy
        case test
    }

    public var op: Op
    public var path: String
    public var value: StructuredValue?
    public var from: String?

    public init(op: Op, path: String, value: StructuredValue? = nil, from: String? = nil) {
        self.op = op
        self.path = path
        self.value = value
        self.from = from
    }
}

/// RFC 6902 JSON Patch の適用エラー。
public struct JSONPatchError: Error, Sendable, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// RFC 6902 JSON Patch。`StructuredValue` に対して適用する。
/// 値型のため適用はアトミック(途中で失敗しても呼び出し側のドキュメントは不変)。
public enum JSONPatch {
    /// 型付き操作列を適用し、新しいドキュメントを返す。
    public static func apply(
        _ operations: [JSONPatchOperation],
        to document: StructuredValue
    ) throws -> StructuredValue {
        var result = document
        for operation in operations {
            result = try apply(operation, to: result)
        }
        return result
    }

    /// wire 上の生値(`STATE_DELTA.delta` / `ACTIVITY_DELTA.patch`)を適用する。
    public static func apply(
        raw operations: [StructuredValue],
        to document: StructuredValue
    ) throws -> StructuredValue {
        try apply(operations.map(decodeOperation), to: document)
    }

    private static func decodeOperation(_ value: StructuredValue) throws -> JSONPatchOperation {
        guard let object = value.objectValue,
              let opString = object["op"]?.stringValue,
              let op = JSONPatchOperation.Op(rawValue: opString),
              let path = object["path"]?.stringValue else {
            throw JSONPatchError("Malformed patch operation: \(value)")
        }
        return JSONPatchOperation(op: op, path: path, value: object["value"], from: object["from"]?.stringValue)
    }

    private static func apply(
        _ operation: JSONPatchOperation,
        to document: StructuredValue
    ) throws -> StructuredValue {
        let path = try JSONPointer(operation.path)
        switch operation.op {
        case .add:
            guard let value = operation.value else {
                throw JSONPatchError("'add' requires value (path: \(operation.path))")
            }
            return try add(value, at: path, in: document)
        case .remove:
            return try remove(at: path, in: document)
        case .replace:
            guard let value = operation.value else {
                throw JSONPatchError("'replace' requires value (path: \(operation.path))")
            }
            _ = try get(at: path, in: document)
            let removed = path.isRoot ? document : try remove(at: path, in: document)
            return try add(value, at: path, in: removed)
        case .move:
            guard let fromString = operation.from else {
                throw JSONPatchError("'move' requires from (path: \(operation.path))")
            }
            let from = try JSONPointer(fromString)
            guard !from.isProperPrefix(of: path) else {
                throw JSONPatchError("'move' from (\(fromString)) must not be a prefix of path (\(operation.path))")
            }
            let value = try get(at: from, in: document)
            let removed = try remove(at: from, in: document)
            return try add(value, at: path, in: removed)
        case .copy:
            guard let fromString = operation.from else {
                throw JSONPatchError("'copy' requires from (path: \(operation.path))")
            }
            let value = try get(at: JSONPointer(fromString), in: document)
            return try add(value, at: path, in: document)
        case .test:
            guard let value = operation.value else {
                throw JSONPatchError("'test' requires value (path: \(operation.path))")
            }
            let actual = try get(at: path, in: document)
            guard actual == value else {
                throw JSONPatchError("'test' failed at \(operation.path): expected \(value), got \(actual)")
            }
            return document
        }
    }

    // MARK: - Pointer navigation

    private static func get(at pointer: JSONPointer, in document: StructuredValue) throws -> StructuredValue {
        var current = document
        for token in pointer.tokens {
            switch current {
            case .object(let object):
                guard let next = object[token] else {
                    throw JSONPatchError("Path not found: \(pointer.description) (missing '\(token)')")
                }
                current = next
            case .array(let array):
                guard let index = arrayIndex(token, count: array.count, allowEnd: false) else {
                    throw JSONPatchError("Invalid array index '\(token)' at \(pointer.description)")
                }
                current = array[index]
            default:
                throw JSONPatchError("Cannot traverse into scalar at '\(token)' (\(pointer.description))")
            }
        }
        return current
    }

    private static func add(
        _ value: StructuredValue,
        at pointer: JSONPointer,
        in document: StructuredValue
    ) throws -> StructuredValue {
        if pointer.isRoot {
            return value
        }
        return try mutate(document, tokens: pointer.tokens) { container, token in
            switch container {
            case .object(var object):
                object[token] = value
                return .object(object)
            case .array(var array):
                guard let index = arrayIndex(token, count: array.count, allowEnd: true) else {
                    throw JSONPatchError("Invalid array index '\(token)' for add")
                }
                array.insert(value, at: index)
                return .array(array)
            default:
                throw JSONPatchError("Cannot add into scalar at '\(token)'")
            }
        }
    }

    private static func remove(
        at pointer: JSONPointer,
        in document: StructuredValue
    ) throws -> StructuredValue {
        guard !pointer.isRoot else {
            throw JSONPatchError("Cannot remove the whole document")
        }
        return try mutate(document, tokens: pointer.tokens) { container, token in
            switch container {
            case .object(var object):
                guard object[token] != nil else {
                    throw JSONPatchError("Cannot remove missing key '\(token)'")
                }
                object.removeValue(forKey: token)
                return .object(object)
            case .array(var array):
                guard let index = arrayIndex(token, count: array.count, allowEnd: false) else {
                    throw JSONPatchError("Invalid array index '\(token)' for remove")
                }
                array.remove(at: index)
                return .array(array)
            default:
                throw JSONPatchError("Cannot remove from scalar at '\(token)'")
            }
        }
    }

    /// tokens の最後の 1 つ手前まで辿り、最後のコンテナに `transform` を適用して
    /// ドキュメントを再構築する。
    private static func mutate(
        _ document: StructuredValue,
        tokens: [String],
        transform: (StructuredValue, String) throws -> StructuredValue
    ) throws -> StructuredValue {
        guard let token = tokens.first else {
            throw JSONPatchError("Empty pointer for mutation")
        }
        if tokens.count == 1 {
            return try transform(document, token)
        }
        switch document {
        case .object(var object):
            guard let child = object[token] else {
                throw JSONPatchError("Path not found: missing '\(token)'")
            }
            object[token] = try mutate(child, tokens: Array(tokens.dropFirst()), transform: transform)
            return .object(object)
        case .array(var array):
            guard let index = arrayIndex(token, count: array.count, allowEnd: false) else {
                throw JSONPatchError("Invalid array index '\(token)'")
            }
            array[index] = try mutate(array[index], tokens: Array(tokens.dropFirst()), transform: transform)
            return .array(array)
        default:
            throw JSONPatchError("Cannot traverse into scalar at '\(token)'")
        }
    }

    /// RFC 6901 の配列インデックス。"-" は末尾(add のみ)、先行ゼロは不正。
    private static func arrayIndex(_ token: String, count: Int, allowEnd: Bool) -> Int? {
        if token == "-" {
            return allowEnd ? count : nil
        }
        guard token == "0" || !token.hasPrefix("0"), let index = Int(token), index >= 0 else {
            return nil
        }
        let limit = allowEnd ? count : count - 1
        return index <= limit ? index : nil
    }
}
