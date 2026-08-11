import StructuredDataCore

/// `REASONING_START` — brackets the beginning of a reasoning phase.
///
/// It is a marker only: neither order verification nor the apply layer acts on it, and the
/// visible text arrives through the separate `REASONING_MESSAGE_*` events.
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

/// The single role a reasoning message may carry on the wire; any other string,
/// `"assistant"` included, fails to decode.
public enum ReasoningRole: String, Codable, Sendable {
    case reasoning
}

/// `REASONING_MESSAGE_START` — opens a message of reasoning text meant to be shown.
///
/// Unlike `TEXT_MESSAGE_START`, `role` is required here; there is no default to fall back on.
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

/// `REASONING_MESSAGE_CONTENT` — one delta appended to an open reasoning message.
/// A `messageId` that was never started is rejected rather than created on the spot.
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

/// `REASONING_MESSAGE_END` — closes the reasoning message so `RUN_FINISHED` may be sent;
/// this package verifies the pairing even though upstream does not.
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

/// `REASONING_MESSAGE_CHUNK` — the shorthand for the reasoning START / CONTENT / END triple.
///
/// Both fields are optional on the wire; the chunk expansion layer rebuilds the triple and
/// requires `messageId` on the first chunk of a run.
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

/// `REASONING_END` — brackets the end of the reasoning phase.
/// Like its opening marker it is neither verified nor applied, and carries no state.
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

/// What an encrypted reasoning value is attached to. Note the wire spelling of
/// `toolCall` is `"tool-call"`, hyphenated.
public enum ReasoningEncryptedValueSubtype: String, Codable, Sendable {
    case toolCall = "tool-call"
    case message
}

/// `REASONING_ENCRYPTED_VALUE` — an opaque reasoning blob for zero-data-retention mode,
/// which the client stores and hands back rather than reads.
///
/// The apply layer files it under the `encryptedValue` of whatever `entityId` names,
/// a message or a tool call depending on `subtype`.
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
