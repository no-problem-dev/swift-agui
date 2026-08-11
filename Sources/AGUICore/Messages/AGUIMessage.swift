import StructuredDataCore

/// The `role` field that tells the message variants apart on the wire.
///
/// Unlike event types, there is no fallback case: a role this enum does not list fails to
/// decode and takes the whole message with it.
public enum AGUIRole: String, Codable, Sendable, CaseIterable {
    case developer
    case system
    case assistant
    case user
    case tool
    case activity
    case reasoning
}

/// Instructions the application itself supplies. `content` is a required plain string —
/// the multimodal part array exists only on a user message.
public struct DeveloperMessage: Codable, Sendable, Equatable {
    public var id: String
    public var content: String
    public var name: String?
    public var encryptedValue: String?

    public init(id: String, content: String, name: String? = nil, encryptedValue: String? = nil) {
        self.id = id
        self.content = content
        self.name = name
        self.encryptedValue = encryptedValue
    }
}

/// The classic system prompt, identical in shape to a developer message. The protocol
/// defines no precedence between the two, so which one wins is the agent's choice.
public struct SystemMessage: Codable, Sendable, Equatable {
    public var id: String
    public var content: String
    public var name: String?
    public var encryptedValue: String?

    public init(id: String, content: String, name: String? = nil, encryptedValue: String? = nil) {
        self.id = id
        self.content = content
        self.name = name
        self.encryptedValue = encryptedValue
    }
}

/// What the agent said, requested, or both.
///
/// A meaningful message carries text or tool calls, but both fields are optional on the
/// wire and nothing here rejects one that has neither.
public struct AssistantMessage: Codable, Sendable, Equatable {
    public var id: String
    public var content: String?
    public var name: String?
    public var toolCalls: [AGUIToolCall]?
    public var encryptedValue: String?

    public init(
        id: String,
        content: String? = nil,
        name: String? = nil,
        toolCalls: [AGUIToolCall]? = nil,
        encryptedValue: String? = nil
    ) {
        self.id = id
        self.content = content
        self.name = name
        self.toolCalls = toolCalls
        self.encryptedValue = encryptedValue
    }
}

/// The two shapes the wire allows for what a user sent: a bare string, or an array of
/// typed parts. Which one comes in is preserved, and encoding writes the same shape back.
public enum UserMessageContent: Sendable, Equatable {
    case text(String)
    case parts([InputContent])
}

/// What the person typed or attached; the only message whose content can be multimodal.
public struct UserMessage: Sendable, Equatable {
    public var id: String
    public var content: UserMessageContent
    public var name: String?
    public var encryptedValue: String?

    public init(
        id: String,
        content: UserMessageContent,
        name: String? = nil,
        encryptedValue: String? = nil
    ) {
        self.id = id
        self.content = content
        self.name = name
        self.encryptedValue = encryptedValue
    }
}

extension UserMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case name
        case encryptedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let text = try? container.decode(String.self, forKey: .content) {
            content = .text(text)
        } else {
            content = try .parts(container.decode([InputContent].self, forKey: .content))
        }
        name = try container.decodeIfPresent(String.self, forKey: .name)
        encryptedValue = try container.decodeIfPresent(String.self, forKey: .encryptedValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch content {
        case .text(let text):
            try container.encode(text, forKey: .content)
        case .parts(let parts):
            try container.encode(parts, forKey: .content)
        }
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(encryptedValue, forKey: .encryptedValue)
    }
}

/// The outcome of one tool call, tied back to it by `toolCallId`.
///
/// A failure is reported by filling `error`; `content` is required either way, so a failed
/// call still has to say something in it.
public struct ToolMessage: Codable, Sendable, Equatable {
    public var id: String
    public var content: String
    public var toolCallId: String
    public var error: String?
    public var encryptedValue: String?

    public init(
        id: String,
        content: String,
        toolCallId: String,
        error: String? = nil,
        encryptedValue: String? = nil
    ) {
        self.id = id
        self.content = content
        self.toolCallId = toolCallId
        self.error = error
        self.encryptedValue = encryptedValue
    }
}

/// A structured activity such as an A2UI surface, built up locally from
/// `ACTIVITY_SNAPSHOT` and `ACTIVITY_DELTA`.
///
/// - Important: This role is client-side only. Nothing strips it for you, so exclude it
///   yourself when assembling `RunAgentInput.messages`.
public struct ActivityMessage: Codable, Sendable, Equatable {
    public var id: String
    public var activityType: String
    public var content: StructuredValue

    public init(id: String, activityType: String, content: StructuredValue) {
        self.id = id
        self.activityType = activityType
        self.content = content
    }
}

/// Reasoning text meant to be shown, accumulated from `REASONING_MESSAGE_CONTENT` deltas.
/// `encryptedValue` holds the opaque form used in zero-data-retention mode.
public struct ReasoningMessage: Codable, Sendable, Equatable {
    public var id: String
    public var content: String
    public var encryptedValue: String?

    public init(id: String, content: String, encryptedValue: String? = nil) {
        self.id = id
        self.content = content
        self.encryptedValue = encryptedValue
    }
}

/// One conversation message, carried on the wire as an object discriminated by `role`.
///
/// Mirrors `MessageSchema` in `@ag-ui/core` `types.ts`. There is no tolerant fallback
/// here: a role this version does not know throws, so an unrecognised message is loud
/// rather than lost.
public enum AGUIMessage: Sendable, Equatable {
    case developer(DeveloperMessage)
    case system(SystemMessage)
    case assistant(AssistantMessage)
    case user(UserMessage)
    case tool(ToolMessage)
    case activity(ActivityMessage)
    case reasoning(ReasoningMessage)

    public var role: AGUIRole {
        switch self {
        case .developer: .developer
        case .system: .system
        case .assistant: .assistant
        case .user: .user
        case .tool: .tool
        case .activity: .activity
        case .reasoning: .reasoning
        }
    }

    public var id: String {
        switch self {
        case .developer(let message): message.id
        case .system(let message): message.id
        case .assistant(let message): message.id
        case .user(let message): message.id
        case .tool(let message): message.id
        case .activity(let message): message.id
        case .reasoning(let message): message.id
        }
    }
}

extension AGUIMessage: Codable {
    private enum RoleCodingKey: String, CodingKey {
        case role
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RoleCodingKey.self)
        let role = try container.decode(AGUIRole.self, forKey: .role)
        switch role {
        case .developer:
            self = try .developer(DeveloperMessage(from: decoder))
        case .system:
            self = try .system(SystemMessage(from: decoder))
        case .assistant:
            self = try .assistant(AssistantMessage(from: decoder))
        case .user:
            self = try .user(UserMessage(from: decoder))
        case .tool:
            self = try .tool(ToolMessage(from: decoder))
        case .activity:
            self = try .activity(ActivityMessage(from: decoder))
        case .reasoning:
            self = try .reasoning(ReasoningMessage(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RoleCodingKey.self)
        try container.encode(role, forKey: .role)
        switch self {
        case .developer(let message): try message.encode(to: encoder)
        case .system(let message): try message.encode(to: encoder)
        case .assistant(let message): try message.encode(to: encoder)
        case .user(let message): try message.encode(to: encoder)
        case .tool(let message): try message.encode(to: encoder)
        case .activity(let message): try message.encode(to: encoder)
        case .reasoning(let message): try message.encode(to: encoder)
        }
    }
}
