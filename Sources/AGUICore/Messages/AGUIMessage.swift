import StructuredDataCore

/// メッセージの role。wire 上のディスクリミネータ。
public enum AGUIRole: String, Codable, Sendable, CaseIterable {
    case developer
    case system
    case assistant
    case user
    case tool
    case activity
    case reasoning
}

/// developer メッセージ。
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

/// system メッセージ。
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

/// assistant メッセージ。テキストとツールコールの少なくとも一方を持つ。
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

/// user メッセージのコンテンツ。プレーン文字列またはマルチモーダルパート配列。
public enum UserMessageContent: Sendable, Equatable {
    case text(String)
    case parts([InputContent])
}

/// user メッセージ。
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

/// tool メッセージ(ツール実行結果)。
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

/// activity メッセージ(構造化アクティビティ。A2UI サーフェス等)。
/// クライアント側専用 — `RunAgentInput.messages` には載せない(送信時に除去される)。
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

/// reasoning メッセージ(可視の推論テキスト)。
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

/// 会話メッセージ。wire 上は `role` で判別する discriminated union。
///
/// ミラー元: `@ag-ui/core` `types.ts` の `MessageSchema`。
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
