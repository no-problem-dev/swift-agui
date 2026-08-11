import StructuredDataCore

/// One operation of an RFC 6902 patch; `value` and `from` are each required by only some
/// of the six kinds.
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

/// Thrown when a patch cannot be applied: a malformed operation, a pointer that does not
/// resolve, or a `test` whose value did not match.
public struct JSONPatchError: Error, Sendable, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

/// Applies RFC 6902 patches to a `StructuredValue`, supporting all six operations
/// (add, remove, replace, move, copy, test).
/// Application is atomic because the document is a value type: a failure part-way through
/// leaves the caller's document untouched.
public enum JSONPatch {
    /// Returns a new document with the operations applied in order.
    ///
    /// - Throws: `JSONPatchError` on the first operation that does not apply — an
    ///   unresolvable path, an out-of-range array index, or a failed `test`.
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

    /// Applies operations still in their wire form, as `STATE_DELTA.delta` and
    /// `ACTIVITY_DELTA.patch` carry them.
    ///
    /// - Throws: `JSONPatchError` when an entry is not an object, is missing `op` or
    ///   `path`, or names an `op` outside the six RFC 6902 kinds.
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

    /// Walks down to the container holding the last token, applies `transform` there, and
    /// rebuilds the document around the result.
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

    /// Resolves an RFC 6901 array index. "-" means past the end and is valid for add only;
    /// a leading zero is rejected. Returns nil for anything out of range.
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
