import AGUICore
import Testing

@testable import AGUIClient

/// 上流 `verify.lifecycle.test.ts` から移植したライフサイクル検証。
struct EventVerifierTests {
    private func verifyAll(_ events: [AGUIEvent]) throws {
        var verifier = EventVerifier()
        for event in events {
            try verifier.verify(event)
        }
    }

    private let started = AGUIEvent.runStarted(RunStartedEvent(threadId: "t", runId: "r"))
    private let finished = AGUIEvent.runFinished(RunFinishedEvent(threadId: "t", runId: "r"))

    @Test func minimalRunPasses() throws {
        try verifyAll([started, finished])
    }

    @Test func firstEventMustBeRunStartedOrRunError() {
        #expect(throws: AGUIError.self) {
            try verifyAll([.textMessageStart(TextMessageStartEvent(messageId: "m"))])
        }
        // RUN_ERROR が先頭は合法
        #expect(throws: Never.self) {
            try verifyAll([.runError(RunErrorEvent(message: "x"))])
        }
    }

    @Test func noEventsAfterRunError() {
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .runError(RunErrorEvent(message: "x")), finished])
        }
    }

    @Test func afterRunFinishedOnlyRunErrorOrNewRunStarted() throws {
        // RUN_ERROR は合法
        try verifyAll([started, finished, .runError(RunErrorEvent(message: "late"))])
        // 新しい RUN_STARTED は状態リセットの上で合法
        try verifyAll([started, finished, started, finished])
        // それ以外は違反
        #expect(throws: AGUIError.self) {
            try verifyAll([started, finished, .stepStarted(StepStartedEvent(stepName: "s"))])
        }
    }

    @Test func duplicateRunStartedRejected() {
        #expect(throws: AGUIError.self) {
            try verifyAll([started, started])
        }
    }

    @Test func textMessageLifecycle() throws {
        try verifyAll([
            started,
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            finished,
        ])
        // 同一 id の二重 START
        #expect(throws: AGUIError.self) {
            try verifyAll([
                started,
                .textMessageStart(TextMessageStartEvent(messageId: "m1")),
                .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            ])
        }
        // START なしの CONTENT
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a"))])
        }
        // START なしの END
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageEnd(TextMessageEndEvent(messageId: "m1"))])
        }
    }

    /// 異なる id の並行メッセージ・交錯は合法(Map 管理、スタックではない)。
    @Test func concurrentMessagesAreLegal() throws {
        try verifyAll([
            started,
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageStart(TextMessageStartEvent(messageId: "m2")),
            .textMessageContent(TextMessageContentEvent(messageId: "m2", delta: "b")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m2")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            finished,
        ])
    }

    @Test func toolCallLifecycle() throws {
        try verifyAll([
            started,
            .toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f")),
            .toolCallArgs(ToolCallArgsEvent(toolCallId: "c1", delta: "{}")),
            .toolCallEnd(ToolCallEndEvent(toolCallId: "c1")),
            finished,
        ])
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .toolCallArgs(ToolCallArgsEvent(toolCallId: "c1", delta: "{"))])
        }
    }

    /// TOOL_CALL_RESULT は検証対象外(上流と同じ)— 未知の toolCallId でも通る。
    @Test func toolCallResultIsNotValidated() throws {
        try verifyAll([
            started,
            .toolCallResult(ToolCallResultEvent(messageId: "m", toolCallId: "never-started", content: "x")),
            finished,
        ])
    }

    /// REASONING_MESSAGE_* の順序検証(上流より厳格化した独自ルール)。
    @Test func reasoningMessageLifecycleIsEnforced() throws {
        try verifyAll([
            started,
            .reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r1")),
            .reasoningMessageContent(ReasoningMessageContentEvent(messageId: "r1", delta: "…")),
            .reasoningMessageEnd(ReasoningMessageEndEvent(messageId: "r1")),
            finished,
        ])
        #expect(throws: AGUIError.self) {
            try verifyAll([
                started,
                .reasoningMessageContent(ReasoningMessageContentEvent(messageId: "r1", delta: "…")),
            ])
        }
    }

    @Test func stepLifecycle() throws {
        try verifyAll([
            started,
            .stepStarted(StepStartedEvent(stepName: "plan")),
            .stepFinished(StepFinishedEvent(stepName: "plan")),
            finished,
        ])
        #expect(throws: AGUIError.self) {
            try verifyAll([
                started,
                .stepStarted(StepStartedEvent(stepName: "plan")),
                .stepStarted(StepStartedEvent(stepName: "plan")),
            ])
        }
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .stepFinished(StepFinishedEvent(stepName: "plan"))])
        }
    }

    @Test func runFinishedRejectedWhileEntitiesActive() {
        // step が未完了
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .stepStarted(StepStartedEvent(stepName: "s")), finished])
        }
        // text message が未完了
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageStart(TextMessageStartEvent(messageId: "m")), finished])
        }
        // tool call が未完了
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .toolCallStart(ToolCallStartEvent(toolCallId: "c", toolCallName: "f")), finished])
        }
        // reasoning message が未完了(独自ルール)
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r")), finished])
        }
    }

    /// 検証対象外イベントは run 中なら素通し、RUN_ERROR 後はグローバルゲートで拒否。
    @Test func unvalidatedEventsPassThroughButRespectGlobalGates() throws {
        try verifyAll([
            started,
            .stateSnapshot(StateSnapshotEvent(snapshot: .object([:]))),
            .activitySnapshot(ActivitySnapshotEvent(messageId: "a", activityType: "a2ui-surface", content: .object([:]))),
            .custom(CustomEvent(name: "delish.usage")),
            .unknown(type: "FUTURE", raw: .object([:])),
            finished,
        ])
        #expect(throws: AGUIError.self) {
            try verifyAll([
                .runError(RunErrorEvent(message: "x")),
                .custom(CustomEvent(name: "late")),
            ])
        }
    }
}
