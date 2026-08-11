import StructuredDataCore

/// One streamed agent event, which is a single JSON object on the wire discriminated
/// by `type`, as in `{"type": "RUN_STARTED", ...}`.
///
/// Mirrors the `EventSchemas` discriminated union in `@ag-ui/core` `events.ts`.
/// Upstream-deprecated `THINKING_*` events are not modelled and arrive as `.unknown`.
///
/// Forward-compatibility rules a consumer can rely on:
/// - An unrecognised `type` decodes to `.unknown` rather than throwing, and keeps the
///   entire original object in `raw`, so nothing is dropped and it can still be forwarded.
/// - A recognised `type` with a malformed payload throws a decoding error instead, which
///   matches the upstream zod semantics where a schema violation ends the stream.
/// - Fields this version does not know about are accepted and ignored.
public enum AGUIEvent: Sendable, Equatable {
    case textMessageStart(TextMessageStartEvent)
    case textMessageContent(TextMessageContentEvent)
    case textMessageEnd(TextMessageEndEvent)
    case textMessageChunk(TextMessageChunkEvent)
    case toolCallStart(ToolCallStartEvent)
    case toolCallArgs(ToolCallArgsEvent)
    case toolCallEnd(ToolCallEndEvent)
    case toolCallChunk(ToolCallChunkEvent)
    case toolCallResult(ToolCallResultEvent)
    case stateSnapshot(StateSnapshotEvent)
    case stateDelta(StateDeltaEvent)
    case messagesSnapshot(MessagesSnapshotEvent)
    case activitySnapshot(ActivitySnapshotEvent)
    case activityDelta(ActivityDeltaEvent)
    case raw(RawEvent)
    case custom(CustomEvent)
    case runStarted(RunStartedEvent)
    case runFinished(RunFinishedEvent)
    case runError(RunErrorEvent)
    case stepStarted(StepStartedEvent)
    case stepFinished(StepFinishedEvent)
    case reasoningStart(ReasoningStartEvent)
    case reasoningMessageStart(ReasoningMessageStartEvent)
    case reasoningMessageContent(ReasoningMessageContentEvent)
    case reasoningMessageEnd(ReasoningMessageEndEvent)
    case reasoningMessageChunk(ReasoningMessageChunkEvent)
    case reasoningEnd(ReasoningEndEvent)
    case reasoningEncryptedValue(ReasoningEncryptedValueEvent)
    /// An event type this version does not model; `raw` holds the whole wire object,
    /// including its `type` field, and re-encoding reproduces it byte for byte.
    case unknown(type: String, raw: StructuredValue)

    /// The modelled discriminator, or `nil` for `.unknown` — reach for `typeName` when
    /// what matters is the string that was actually on the wire.
    public var eventType: AGUIEventType? {
        switch self {
        case .textMessageStart: .textMessageStart
        case .textMessageContent: .textMessageContent
        case .textMessageEnd: .textMessageEnd
        case .textMessageChunk: .textMessageChunk
        case .toolCallStart: .toolCallStart
        case .toolCallArgs: .toolCallArgs
        case .toolCallEnd: .toolCallEnd
        case .toolCallChunk: .toolCallChunk
        case .toolCallResult: .toolCallResult
        case .stateSnapshot: .stateSnapshot
        case .stateDelta: .stateDelta
        case .messagesSnapshot: .messagesSnapshot
        case .activitySnapshot: .activitySnapshot
        case .activityDelta: .activityDelta
        case .raw: .raw
        case .custom: .custom
        case .runStarted: .runStarted
        case .runFinished: .runFinished
        case .runError: .runError
        case .stepStarted: .stepStarted
        case .stepFinished: .stepFinished
        case .reasoningStart: .reasoningStart
        case .reasoningMessageStart: .reasoningMessageStart
        case .reasoningMessageContent: .reasoningMessageContent
        case .reasoningMessageEnd: .reasoningMessageEnd
        case .reasoningMessageChunk: .reasoningMessageChunk
        case .reasoningEnd: .reasoningEnd
        case .reasoningEncryptedValue: .reasoningEncryptedValue
        case .unknown: nil
        }
    }

    /// The `type` string as it appeared on the wire, available for `.unknown` events too.
    public var typeName: String {
        switch self {
        case .unknown(let type, _): type
        default: eventType?.rawValue ?? ""
        }
    }
}

extension AGUIEvent: Codable {
    private enum TypeCodingKey: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeCodingKey.self)
        let rawType = try container.decode(String.self, forKey: .type)
        guard let type = AGUIEventType(rawValue: rawType) else {
            self = try .unknown(type: rawType, raw: StructuredValue(from: decoder))
            return
        }
        switch type {
        case .textMessageStart:
            self = try .textMessageStart(TextMessageStartEvent(from: decoder))
        case .textMessageContent:
            self = try .textMessageContent(TextMessageContentEvent(from: decoder))
        case .textMessageEnd:
            self = try .textMessageEnd(TextMessageEndEvent(from: decoder))
        case .textMessageChunk:
            self = try .textMessageChunk(TextMessageChunkEvent(from: decoder))
        case .toolCallStart:
            self = try .toolCallStart(ToolCallStartEvent(from: decoder))
        case .toolCallArgs:
            self = try .toolCallArgs(ToolCallArgsEvent(from: decoder))
        case .toolCallEnd:
            self = try .toolCallEnd(ToolCallEndEvent(from: decoder))
        case .toolCallChunk:
            self = try .toolCallChunk(ToolCallChunkEvent(from: decoder))
        case .toolCallResult:
            self = try .toolCallResult(ToolCallResultEvent(from: decoder))
        case .stateSnapshot:
            self = try .stateSnapshot(StateSnapshotEvent(from: decoder))
        case .stateDelta:
            self = try .stateDelta(StateDeltaEvent(from: decoder))
        case .messagesSnapshot:
            self = try .messagesSnapshot(MessagesSnapshotEvent(from: decoder))
        case .activitySnapshot:
            self = try .activitySnapshot(ActivitySnapshotEvent(from: decoder))
        case .activityDelta:
            self = try .activityDelta(ActivityDeltaEvent(from: decoder))
        case .raw:
            self = try .raw(RawEvent(from: decoder))
        case .custom:
            self = try .custom(CustomEvent(from: decoder))
        case .runStarted:
            self = try .runStarted(RunStartedEvent(from: decoder))
        case .runFinished:
            self = try .runFinished(RunFinishedEvent(from: decoder))
        case .runError:
            self = try .runError(RunErrorEvent(from: decoder))
        case .stepStarted:
            self = try .stepStarted(StepStartedEvent(from: decoder))
        case .stepFinished:
            self = try .stepFinished(StepFinishedEvent(from: decoder))
        case .reasoningStart:
            self = try .reasoningStart(ReasoningStartEvent(from: decoder))
        case .reasoningMessageStart:
            self = try .reasoningMessageStart(ReasoningMessageStartEvent(from: decoder))
        case .reasoningMessageContent:
            self = try .reasoningMessageContent(ReasoningMessageContentEvent(from: decoder))
        case .reasoningMessageEnd:
            self = try .reasoningMessageEnd(ReasoningMessageEndEvent(from: decoder))
        case .reasoningMessageChunk:
            self = try .reasoningMessageChunk(ReasoningMessageChunkEvent(from: decoder))
        case .reasoningEnd:
            self = try .reasoningEnd(ReasoningEndEvent(from: decoder))
        case .reasoningEncryptedValue:
            self = try .reasoningEncryptedValue(ReasoningEncryptedValueEvent(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        if case .unknown(_, let raw) = self {
            try raw.encode(to: encoder)
            return
        }
        var container = encoder.container(keyedBy: TypeCodingKey.self)
        try container.encode(typeName, forKey: .type)
        switch self {
        case .textMessageStart(let event): try event.encode(to: encoder)
        case .textMessageContent(let event): try event.encode(to: encoder)
        case .textMessageEnd(let event): try event.encode(to: encoder)
        case .textMessageChunk(let event): try event.encode(to: encoder)
        case .toolCallStart(let event): try event.encode(to: encoder)
        case .toolCallArgs(let event): try event.encode(to: encoder)
        case .toolCallEnd(let event): try event.encode(to: encoder)
        case .toolCallChunk(let event): try event.encode(to: encoder)
        case .toolCallResult(let event): try event.encode(to: encoder)
        case .stateSnapshot(let event): try event.encode(to: encoder)
        case .stateDelta(let event): try event.encode(to: encoder)
        case .messagesSnapshot(let event): try event.encode(to: encoder)
        case .activitySnapshot(let event): try event.encode(to: encoder)
        case .activityDelta(let event): try event.encode(to: encoder)
        case .raw(let event): try event.encode(to: encoder)
        case .custom(let event): try event.encode(to: encoder)
        case .runStarted(let event): try event.encode(to: encoder)
        case .runFinished(let event): try event.encode(to: encoder)
        case .runError(let event): try event.encode(to: encoder)
        case .stepStarted(let event): try event.encode(to: encoder)
        case .stepFinished(let event): try event.encode(to: encoder)
        case .reasoningStart(let event): try event.encode(to: encoder)
        case .reasoningMessageStart(let event): try event.encode(to: encoder)
        case .reasoningMessageContent(let event): try event.encode(to: encoder)
        case .reasoningMessageEnd(let event): try event.encode(to: encoder)
        case .reasoningMessageChunk(let event): try event.encode(to: encoder)
        case .reasoningEnd(let event): try event.encode(to: encoder)
        case .reasoningEncryptedValue(let event): try event.encode(to: encoder)
        case .unknown: break
        }
    }
}
