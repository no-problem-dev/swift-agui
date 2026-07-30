import AGUICore

/// プロトコル順序の検証。違反は `AGUIError` を throw し、ストリームを終了させる。
///
/// ミラー元: `@ag-ui/client` `verify/verify.ts`。上流との意図的な差分:
/// - `REASONING_MESSAGE_*` に `TEXT_MESSAGE_*` と対称の順序検証を入れる
///   (上流は型追加に検証が追随していない)
/// - `*_CHUNK` は展開済みが前提(`ChunkTransform` を先に通す)。届いた場合は
///   上流同様、検証せず素通しする
///
/// 検証対象外(上流と同じ): TOOL_CALL_RESULT / STATE_* / MESSAGES_SNAPSHOT /
/// ACTIVITY_* / RAW / CUSTOM / unknown。ただしグローバルゲート
/// (RUN_ERROR 後の全拒否等)は全イベントに適用する。
public struct EventVerifier: Sendable {
    private var runStarted = false
    private var runFinished = false
    private var runError = false
    private var firstEventReceived = false
    private var activeMessages: Set<String> = []
    private var activeToolCalls: Set<String> = []
    private var activeReasoningMessages: Set<String> = []
    private var activeSteps: Set<String> = []

    public init() {}

    public mutating func verify(_ event: AGUIEvent) throws {
        // グローバルゲート(順序が仕様)
        if runError {
            throw AGUIError(
                "The run has already errored with 'RUN_ERROR'. No further events can be sent."
            )
        }
        if case .runError = event {
            runError = true
            return
        }
        if runFinished {
            guard case .runStarted = event else {
                throw AGUIError(
                    "The run has already finished with 'RUN_FINISHED'. Only 'RUN_ERROR' or a new 'RUN_STARTED' can follow."
                )
            }
            // 同一ストリームでの新しい run — 状態をリセットして受理する
            resetRunState()
            runStarted = true
            firstEventReceived = true
            return
        }
        if !firstEventReceived {
            firstEventReceived = true
            guard case .runStarted = event else {
                throw AGUIError("First event must be 'RUN_STARTED' or 'RUN_ERROR' (got '\(event.typeName)')")
            }
            runStarted = true
            return
        }

        switch event {
        case .runStarted:
            throw AGUIError("Cannot send 'RUN_STARTED' while a run is already active")

        case .runFinished:
            if !activeSteps.isEmpty {
                throw AGUIError(
                    "Cannot send 'RUN_FINISHED' while steps are still active: \(activeSteps.sorted().joined(separator: ", "))"
                )
            }
            if !activeMessages.isEmpty {
                throw AGUIError(
                    "Cannot send 'RUN_FINISHED' while text messages are still active: \(activeMessages.sorted().joined(separator: ", "))"
                )
            }
            if !activeToolCalls.isEmpty {
                throw AGUIError(
                    "Cannot send 'RUN_FINISHED' while tool calls are still active: \(activeToolCalls.sorted().joined(separator: ", "))"
                )
            }
            if !activeReasoningMessages.isEmpty {
                throw AGUIError(
                    "Cannot send 'RUN_FINISHED' while reasoning messages are still active: \(activeReasoningMessages.sorted().joined(separator: ", "))"
                )
            }
            runFinished = true

        case .textMessageStart(let start):
            guard activeMessages.insert(start.messageId).inserted else {
                throw AGUIError("Text message '\(start.messageId)' is already active")
            }

        case .textMessageContent(let content):
            guard activeMessages.contains(content.messageId) else {
                throw AGUIError(
                    "Cannot send 'TEXT_MESSAGE_CONTENT' for inactive message '\(content.messageId)'"
                )
            }

        case .textMessageEnd(let end):
            guard activeMessages.remove(end.messageId) != nil else {
                throw AGUIError("Cannot send 'TEXT_MESSAGE_END' for inactive message '\(end.messageId)'")
            }

        case .toolCallStart(let start):
            guard activeToolCalls.insert(start.toolCallId).inserted else {
                throw AGUIError("Tool call '\(start.toolCallId)' is already active")
            }

        case .toolCallArgs(let args):
            guard activeToolCalls.contains(args.toolCallId) else {
                throw AGUIError("Cannot send 'TOOL_CALL_ARGS' for inactive tool call '\(args.toolCallId)'")
            }

        case .toolCallEnd(let end):
            guard activeToolCalls.remove(end.toolCallId) != nil else {
                throw AGUIError("Cannot send 'TOOL_CALL_END' for inactive tool call '\(end.toolCallId)'")
            }

        case .reasoningMessageStart(let start):
            guard activeReasoningMessages.insert(start.messageId).inserted else {
                throw AGUIError("Reasoning message '\(start.messageId)' is already active")
            }

        case .reasoningMessageContent(let content):
            guard activeReasoningMessages.contains(content.messageId) else {
                throw AGUIError(
                    "Cannot send 'REASONING_MESSAGE_CONTENT' for inactive message '\(content.messageId)'"
                )
            }

        case .reasoningMessageEnd(let end):
            guard activeReasoningMessages.remove(end.messageId) != nil else {
                throw AGUIError(
                    "Cannot send 'REASONING_MESSAGE_END' for inactive message '\(end.messageId)'"
                )
            }

        case .stepStarted(let step):
            guard activeSteps.insert(step.stepName).inserted else {
                throw AGUIError("Step \"\(step.stepName)\" is already active")
            }

        case .stepFinished(let step):
            guard activeSteps.remove(step.stepName) != nil else {
                throw AGUIError("Cannot send 'STEP_FINISHED' for inactive step \"\(step.stepName)\"")
            }

        default:
            break
        }
    }

    private mutating func resetRunState() {
        runFinished = false
        activeMessages.removeAll()
        activeToolCalls.removeAll()
        activeReasoningMessages.removeAll()
        activeSteps.removeAll()
    }
}
