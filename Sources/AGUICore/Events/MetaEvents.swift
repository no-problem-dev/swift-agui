import StructuredDataCore

/// `RAW`。外部システムのイベントを原形のまま包む通過用コンテナ。
public struct RawEvent: Codable, Sendable, Equatable {
    public var event: StructuredValue
    public var source: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        event: StructuredValue,
        source: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.event = event
        self.source = source
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `CUSTOM`。プロトコル拡張の正式な口。`name` で識別し `value` に任意値を載せる。
public struct CustomEvent: Codable, Sendable, Equatable {
    public var name: String
    public var value: StructuredValue?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        name: String,
        value: StructuredValue? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.name = name
        self.value = value
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
