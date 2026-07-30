import StructuredDataCore

/// `TOOL_CALL_START`。
///
/// `parentMessageId: null` は省略として受理する(.NET 製アダプタが `null` を
/// emit する実績があり、ここで落とすと最初のツールコールで run が死ぬ)。
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

/// `TOOL_CALL_ARGS`。`delta` は JSON 引数の断片(文字列連結で組み立てる)。
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

/// `TOOL_CALL_END`。
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

/// `TOOL_CALL_RESULT` の role(常に "tool")。
public enum ToolResultRole: String, Codable, Sendable {
    case tool
}

/// `TOOL_CALL_RESULT`。サーバー側で実行済みのツール結果の通知。
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

/// `TOOL_CALL_CHUNK`。START/ARGS/END の省略形。
/// 初回チャンクは toolCallId と toolCallName が必須(chunk 展開層が検証する)。
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
