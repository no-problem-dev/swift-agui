import StructuredDataCore

/// `ACTIVITY_SNAPSHOT` — the full content of a structured activity, such as an A2UI surface.
///
/// An absent `replace` decodes as `true`, matching the upstream `.default(true)`.
/// With `replace == false` the snapshot only creates: if an activity with the same
/// `messageId` already exists, the whole snapshot is discarded and nothing changes.
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

/// `ACTIVITY_DELTA` — an RFC 6902 JSON Patch applied to one activity's `content`.
///
/// A delta naming a `messageId` no activity has yet is a no-op, following upstream, so a
/// patch that arrives before its snapshot is silently lost rather than reported.
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
