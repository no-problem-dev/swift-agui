import StructuredDataCore

/// Roles a streamed text message may claim; tool results and reasoning text are
/// separate event families with their own single-valued role types.
public enum TextMessageRole: String, Codable, Sendable {
    case developer
    case system
    case assistant
    case user
}

/// `TEXT_MESSAGE_START` — opens a message that later deltas append to.
///
/// An absent `role` on the wire decodes as `.assistant`, matching the upstream
/// `.default("assistant")` in zod, so producers that omit it are not rejected.
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

/// `TEXT_MESSAGE_CONTENT` — one delta to append to an already-open message.
///
/// A `TEXT_MESSAGE_START` carrying the same `messageId` must precede it; without one,
/// order verification rejects the stream rather than starting a message implicitly.
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

/// `TEXT_MESSAGE_END` — closes the message so that `RUN_FINISHED` may be sent.
/// Deltas for the same `messageId` after this point are a protocol violation.
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

/// `TEXT_MESSAGE_CHUNK` — the shorthand a producer may send instead of the
/// START / CONTENT / END triple.
///
/// Every field is optional on the wire, so the client-side chunk expansion layer is what
/// normalises a run of chunks back into the triple; it requires `messageId` on the first
/// chunk and throws if it is missing.
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
