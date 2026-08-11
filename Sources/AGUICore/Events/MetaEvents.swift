import StructuredDataCore

/// `RAW` — carries an event from a foreign system verbatim, for pass-through and diagnostics.
///
/// Nothing in this package interprets `event`; the chunk expansion layer forwards it
/// without closing an open text message or tool call.
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

/// `CUSTOM` — the sanctioned extension point: `name` identifies the extension and
/// `value` carries arbitrary JSON that stays untyped end to end.
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
