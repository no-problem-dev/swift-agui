import StructuredDataCore

/// `REASONING_START`。推論フェーズの開始。
public struct ReasoningStartEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(messageId: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `REASONING_MESSAGE_START` の role(常に "reasoning")。
public enum ReasoningRole: String, Codable, Sendable {
    case reasoning
}

/// `REASONING_MESSAGE_START`。可視の推論テキストメッセージの開始。
public struct ReasoningMessageStartEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var role: ReasoningRole
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        role: ReasoningRole = .reasoning,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.role = role
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `REASONING_MESSAGE_CONTENT`。
public struct ReasoningMessageContentEvent: Codable, Sendable, Equatable {
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

/// `REASONING_MESSAGE_END`。
public struct ReasoningMessageEndEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(messageId: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `REASONING_MESSAGE_CHUNK`。省略形(chunk 展開層が三つ組へ正規化する)。
public struct ReasoningMessageChunkEvent: Codable, Sendable, Equatable {
    public var messageId: String?
    public var delta: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String? = nil,
        delta: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.delta = delta
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `REASONING_END`。
public struct ReasoningEndEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(messageId: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `REASONING_ENCRYPTED_VALUE` の対象種別。
public enum ReasoningEncryptedValueSubtype: String, Codable, Sendable {
    case toolCall = "tool-call"
    case message
}

/// `REASONING_ENCRYPTED_VALUE`。ゼロデータ保持モードの暗号化推論値。
/// `entityId` が指すメッセージ/ツールコールの `encryptedValue` に格納する。
public struct ReasoningEncryptedValueEvent: Codable, Sendable, Equatable {
    public var subtype: ReasoningEncryptedValueSubtype
    public var entityId: String
    public var encryptedValue: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        subtype: ReasoningEncryptedValueSubtype,
        entityId: String,
        encryptedValue: String,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.subtype = subtype
        self.entityId = entityId
        self.encryptedValue = encryptedValue
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
