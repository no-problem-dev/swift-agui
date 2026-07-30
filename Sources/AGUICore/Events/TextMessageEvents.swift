import StructuredDataCore

/// テキストメッセージが取り得る role("tool" 以外)。
public enum TextMessageRole: String, Codable, Sendable {
    case developer
    case system
    case assistant
    case user
}

/// `TEXT_MESSAGE_START`。role は省略時 assistant(上流 zod の `.default("assistant")`)。
public struct TextMessageStartEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var role: TextMessageRole
    public var name: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        role: TextMessageRole = .assistant,
        name: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.role = role
        self.name = name
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }

    private enum CodingKeys: String, CodingKey {
        case messageId
        case role
        case name
        case timestamp
        case rawEvent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(String.self, forKey: .messageId)
        role = try container.decodeIfPresent(TextMessageRole.self, forKey: .role) ?? .assistant
        name = try container.decodeIfPresent(String.self, forKey: .name)
        timestamp = try container.decodeIfPresent(Int64.self, forKey: .timestamp)
        rawEvent = try container.decodeIfPresent(StructuredValue.self, forKey: .rawEvent)
    }
}

/// `TEXT_MESSAGE_CONTENT`。同一 messageId の START が先行している必要がある。
public struct TextMessageContentEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var delta: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        delta: String,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.delta = delta
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `TEXT_MESSAGE_END`。
public struct TextMessageEndEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(messageId: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `TEXT_MESSAGE_CHUNK`。START/CONTENT/END の省略形。
/// クライアントの chunk 展開層が三つ組へ正規化する(初回チャンクは messageId 必須)。
public struct TextMessageChunkEvent: Codable, Sendable, Equatable {
    public var messageId: String?
    public var role: TextMessageRole?
    public var delta: String?
    public var name: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String? = nil,
        role: TextMessageRole? = nil,
        delta: String? = nil,
        name: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.role = role
        self.delta = delta
        self.name = name
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
