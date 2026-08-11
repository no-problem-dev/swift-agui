/// The kind of call being made. The protocol defines only `function` today, so any other
/// wire value fails to decode.
public enum ToolCallKind: String, Codable, Sendable {
    case function
}

/// A function the model wants called, with its arguments as a JSON *string* rather than
/// a parsed object — nothing here validates that the string parses.
public struct AGUIFunctionCall: Codable, Sendable, Equatable {
    public var name: String
    public var arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

/// A call the assistant is requesting, carried on its message; `id` is what the matching
/// tool message and `TOOL_CALL_*` events refer back to.
public struct AGUIToolCall: Codable, Sendable, Equatable {
    public var id: String
    public var type: ToolCallKind
    public var function: AGUIFunctionCall
    /// Opaque reasoning blob for zero-data-retention mode, filled in when a
    /// `REASONING_ENCRYPTED_VALUE` event names this call; send it back untouched.
    public var encryptedValue: String?

    public init(
        id: String,
        type: ToolCallKind = .function,
        function: AGUIFunctionCall,
        encryptedValue: String? = nil
    ) {
        self.id = id
        self.type = type
        self.function = function
        self.encryptedValue = encryptedValue
    }
}
