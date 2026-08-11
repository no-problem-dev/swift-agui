import StructuredDataCore

/// A parsed RFC 6901 pointer: a slash-separated path with its `~0` / `~1` escapes resolved.
public struct JSONPointer: Sendable, Equatable {
    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// Reference tokens with escapes already resolved. Empty means the whole document.
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

    /// Whether this is a strict ancestor of `other`. A pointer is never a proper prefix of
    /// itself, which is what makes it usable as the `move` guard.
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
