import StructuredDataCore

/// `STATE_SNAPSHOT`。共有 state の完全置換(マージではない)。
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

/// `STATE_DELTA`。RFC 6902 JSON Patch による増分更新。
/// パッチ操作は wire 上の生値のまま保持する(適用は AGUIState / AGUIJSONPatch の責務)。
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

/// `MESSAGES_SNAPSHOT`。会話履歴のスナップショット。
/// activity / reasoning ロールは「1 つでも含まれていればそのロールの完全集合」
/// という編集ベースマージの規則がある(適用は AGUIState の責務)。
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
