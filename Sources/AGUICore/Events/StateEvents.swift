import StructuredDataCore

/// `STATE_SNAPSHOT` — replaces the shared state outright; keys absent from `snapshot`
/// are gone, because this is a replacement and never a merge.
public struct StateSnapshotEvent: Codable, Sendable, Equatable {
    public var snapshot: StructuredValue
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        snapshot: StructuredValue,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.snapshot = snapshot
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `STATE_DELTA` — an incremental update to the shared state as an RFC 6902 JSON Patch.
///
/// The operations stay as raw wire values and are never validated here; applying them,
/// and deciding what a failed patch means, belongs to `AGUIState` / `AGUIJSONPatch`.
public struct StateDeltaEvent: Codable, Sendable, Equatable {
    public var delta: [StructuredValue]
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        delta: [StructuredValue],
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.delta = delta
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `MESSAGES_SNAPSHOT` — the server's view of the conversation so far.
///
/// The apply layer merges rather than swaps: for the client-only `activity` and
/// `reasoning` roles, a snapshot containing even one message of that role is treated as
/// the complete set for it, and existing ones missing from the snapshot are dropped;
/// a snapshot containing none leaves them untouched.
public struct MessagesSnapshotEvent: Codable, Sendable, Equatable {
    public var messages: [AGUIMessage]
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        messages: [AGUIMessage],
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.messages = messages
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
