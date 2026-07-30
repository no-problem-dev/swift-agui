import StructuredDataCore

/// `ACTIVITY_SNAPSHOT`。構造化アクティビティ(A2UI サーフェス等)のスナップショット。
///
/// `replace` は省略時 true(上流 zod の `.default(true)`)。false のとき、既存の
/// 同一 messageId のアクティビティがあればスナップショットは無視される。
public struct ActivitySnapshotEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var activityType: String
    public var content: StructuredValue
    public var replace: Bool
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        activityType: String,
        content: StructuredValue,
        replace: Bool = true,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.activityType = activityType
        self.content = content
        self.replace = replace
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }

    private enum CodingKeys: String, CodingKey {
        case messageId
        case activityType
        case content
        case replace
        case timestamp
        case rawEvent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try container.decode(String.self, forKey: .messageId)
        activityType = try container.decode(String.self, forKey: .activityType)
        content = try container.decode(StructuredValue.self, forKey: .content)
        replace = try container.decodeIfPresent(Bool.self, forKey: .replace) ?? true
        timestamp = try container.decodeIfPresent(Int64.self, forKey: .timestamp)
        rawEvent = try container.decodeIfPresent(StructuredValue.self, forKey: .rawEvent)
    }
}

/// `ACTIVITY_DELTA`。アクティビティ content への RFC 6902 JSON Patch。
public struct ActivityDeltaEvent: Codable, Sendable, Equatable {
    public var messageId: String
    public var activityType: String
    public var patch: [StructuredValue]
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messageId: String,
        activityType: String,
        patch: [StructuredValue],
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messageId = messageId
        self.activityType = activityType
        self.patch = patch
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
