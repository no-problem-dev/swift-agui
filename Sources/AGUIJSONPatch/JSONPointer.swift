import StructuredDataCore

/// RFC 6901 JSON Pointer。
public struct JSONPointer: Sendable, Equatable {
    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// 参照トークン列(アンエスケープ済み)。空配列はドキュメント全体を指す。
    public let tokens: [String]

    public init(_ string: String) throws {
        if string.isEmpty {
            tokens = []
            return
        }
        guard string.hasPrefix("/") else {
            throw ParseError(description: "JSON Pointer must start with '/' (got \(string))")
        }
        tokens = string.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
            $0.replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
        }
    }

    public init(tokens: [String]) {
        self.tokens = tokens
    }

    public var isRoot: Bool { tokens.isEmpty }

    public var parent: JSONPointer? {
        guard !tokens.isEmpty else {
            return nil
        }
        return JSONPointer(tokens: Array(tokens.dropLast()))
    }

    public var lastToken: String? { tokens.last }

    /// self が other の真の接頭辞(= other の祖先)かどうか。
    public func isProperPrefix(of other: JSONPointer) -> Bool {
        tokens.count < other.tokens.count && Array(other.tokens.prefix(tokens.count)) == tokens
    }

    public var description: String {
        tokens.map {
            "/" + $0.replacingOccurrences(of: "~", with: "~0")
                .replacingOccurrences(of: "/", with: "~1")
        }.joined()
    }
}
