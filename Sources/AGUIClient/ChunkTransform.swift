import AGUICore

/// `*_CHUNK` イベントを START / CONTENT / END の三つ組へ展開するステートフル変換。
/// サーバー実装の揺れ(省略形での emit)をクライアント側で吸収する。
///
/// ミラー元: `@ag-ui/client` `chunks/transform.ts`。
///
/// 規則:
/// - 初回チャンクの必須フィールド: text / reasoning は `messageId`、
///   tool は `toolCallId` と `toolCallName`
/// - モード変更・id 変更・非チャンクイベントの到来・ストリーム終端で
///   開いているエンティティを暗黙クローズ(合成 END を emit)する
/// - クローズしないパススルー例外: RAW / ACTIVITY_SNAPSHOT / ACTIVITY_DELTA /
///   REASONING_ENCRYPTED_VALUE
public struct ChunkTransform: Sendable {
    private enum Mode: Equatable {
        case text(messageId: String)
        case tool(toolCallId: String)
        case reasoning(messageId: String)
    }

    private var mode: Mode?

    public init() {}

    /// 1 イベントを正規形の列へ変換する。
    public mutating func transform(_ event: AGUIEvent) throws -> [AGUIEvent] {
        switch event {
        case .textMessageChunk(let chunk):
            return try transformTextChunk(chunk)
        case .toolCallChunk(let chunk):
            return try transformToolChunk(chunk)
        case .reasoningMessageChunk(let chunk):
            return try transformReasoningChunk(chunk)
        case .raw, .activitySnapshot, .activityDelta, .reasoningEncryptedValue:
            // パススルー: 開いているエンティティをクローズしない
            return [event]
        default:
            var events = closeOpenEntity()
            events.append(event)
            return events
        }
    }

    /// ストリーム終端。開いているエンティティをクローズする。
    public mutating func finish() -> [AGUIEvent] {
        closeOpenEntity()
    }

    private mutating func closeOpenEntity() -> [AGUIEvent] {
        defer { mode = nil }
        switch mode {
        case .text(let messageId):
            return [.textMessageEnd(TextMessageEndEvent(messageId: messageId))]
        case .tool(let toolCallId):
            return [.toolCallEnd(ToolCallEndEvent(toolCallId: toolCallId))]
        case .reasoning(let messageId):
            return [.reasoningMessageEnd(ReasoningMessageEndEvent(messageId: messageId))]
        case nil:
            return []
        }
    }

    private mutating func transformTextChunk(_ chunk: TextMessageChunkEvent) throws -> [AGUIEvent] {
        var events: [AGUIEvent] = []
        let continuesCurrent: Bool = if case .text(let currentId) = mode {
            chunk.messageId == nil || chunk.messageId == currentId
        } else {
            false
        }
        if !continuesCurrent {
            events.append(contentsOf: closeOpenEntity())
            guard let messageId = chunk.messageId else {
                throw AGUIError("First TEXT_MESSAGE_CHUNK must include messageId")
            }
            mode = .text(messageId: messageId)
            events.append(.textMessageStart(
                TextMessageStartEvent(messageId: messageId, role: chunk.role ?? .assistant, name: chunk.name)
            ))
        }
        if let delta = chunk.delta, case .text(let messageId) = mode {
            events.append(.textMessageContent(TextMessageContentEvent(messageId: messageId, delta: delta)))
        }
        return events
    }

    private mutating func transformToolChunk(_ chunk: ToolCallChunkEvent) throws -> [AGUIEvent] {
        var events: [AGUIEvent] = []
        let continuesCurrent: Bool = if case .tool(let currentId) = mode {
            chunk.toolCallId == nil || chunk.toolCallId == currentId
        } else {
            false
        }
        if !continuesCurrent {
            events.append(contentsOf: closeOpenEntity())
            guard let toolCallId = chunk.toolCallId, let toolCallName = chunk.toolCallName else {
                throw AGUIError("First TOOL_CALL_CHUNK must include toolCallId and toolCallName")
            }
            mode = .tool(toolCallId: toolCallId)
            events.append(.toolCallStart(
                ToolCallStartEvent(
                    toolCallId: toolCallId,
                    toolCallName: toolCallName,
                    parentMessageId: chunk.parentMessageId
                )
            ))
        }
        if let delta = chunk.delta, case .tool(let toolCallId) = mode {
            events.append(.toolCallArgs(ToolCallArgsEvent(toolCallId: toolCallId, delta: delta)))
        }
        return events
    }

    private mutating func transformReasoningChunk(_ chunk: ReasoningMessageChunkEvent) throws -> [AGUIEvent] {
        var events: [AGUIEvent] = []
        let continuesCurrent: Bool = if case .reasoning(let currentId) = mode {
            chunk.messageId == nil || chunk.messageId == currentId
        } else {
            false
        }
        if !continuesCurrent {
            events.append(contentsOf: closeOpenEntity())
            guard let messageId = chunk.messageId else {
                throw AGUIError("First REASONING_MESSAGE_CHUNK must include messageId")
            }
            mode = .reasoning(messageId: messageId)
            events.append(.reasoningMessageStart(ReasoningMessageStartEvent(messageId: messageId)))
        }
        if let delta = chunk.delta, case .reasoning(let messageId) = mode {
            events.append(.reasoningMessageContent(ReasoningMessageContentEvent(messageId: messageId, delta: delta)))
        }
        return events
    }
}
