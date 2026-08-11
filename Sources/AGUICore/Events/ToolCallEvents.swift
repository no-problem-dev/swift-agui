import StructuredDataCore

/// `TOOL_CALL_START` — opens a tool call that argument deltas then fill in.
///
/// An explicit `parentMessageId: null` is accepted as an omission: .NET adapters are
/// known to emit it, and rejecting it would kill the run on its first tool call.
public struct ToolCallStartEvent: Codable, Sendable, Equatable {
    public var toolCallId: String
    public var toolCallName: String
    public var parentMessageId: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        toolCallId: String,
        toolCallName: String,
        parentMessageId: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.toolCallId = toolCallId
        self.toolCallName = toolCallName
        self.parentMessageId = parentMessageId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `TOOL_CALL_ARGS` — one fragment of the argument JSON, to be joined as text.
///
/// A fragment is not valid JSON on its own; concatenate every `delta` for a
/// `toolCallId` and parse only once the call is closed.
public struct ToolCallArgsEvent: Codable, Sendable, Equatable {
    public var toolCallId: String
    public var delta: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        toolCallId: String,
        delta: String,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.toolCallId = toolCallId
        self.delta = delta
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `TOOL_CALL_END` — marks the argument JSON complete and ready to parse; until it
/// arrives the call counts as active and `RUN_FINISHED` cannot be sent.
public struct ToolCallEndEvent: Codable, Sendable, Equatable {
    public var toolCallId: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(toolCallId: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.toolCallId = toolCallId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// The single role a tool result may carry on the wire; any other string fails to decode.
public enum ToolResultRole: String, Codable, Sendable {
    case tool
}

/// `TOOL_CALL_RESULT` — reports a tool the server already ran, so the client displays
/// the result instead of executing anything.
///
/// Order verification ignores this event, so it can arrive without a matching
/// `TOOL_CALL_START`; `messageId` is the id of the tool message it becomes.
public struct ToolCallResultEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var toolCallId: String
    public var content: String
    public var role: ToolResultRole?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        toolCallId: String,
        content: String,
        role: ToolResultRole? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.toolCallId = toolCallId
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `TOOL_CALL_CHUNK` — the shorthand a producer may send instead of the
/// START / ARGS / END triple.
///
/// Every field is optional on the wire; the chunk expansion layer rebuilds the triple and
/// throws unless the first chunk of a run carries both `toolCallId` and `toolCallName`.
public struct ToolCallChunkEvent: Codable, Sendable, Equatable {
    public var toolCallId: String?
    public var toolCallName: String?
    public var parentMessageId: String?
    public var delta: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        toolCallId: String? = nil,
        toolCallName: String? = nil,
        parentMessageId: String? = nil,
        delta: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.toolCallId = toolCallId
        self.toolCallName = toolCallName
        self.parentMessageId = parentMessageId
        self.delta = delta
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
