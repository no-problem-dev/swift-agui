import AGUICore
import Testing

@testable import AGUIClient

/// Lifecycle checks ported from upstream `verify.lifecycle.test.ts`.
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
        // RUN_ERROR in first position is legal
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
        // RUN_ERROR is legal
        try verifyAll([started, finished, .runError(RunErrorEvent(message: "late"))])
        // A new RUN_STARTED is legal, and resets the per-run state
        try verifyAll([started, finished, started, finished])
        // Anything else is a violation
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
        // Two STARTs with the same id
        #expect(throws: AGUIError.self) {
            try verifyAll([
                started,
                .textMessageStart(TextMessageStartEvent(messageId: "m1")),
                .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            ])
        }
        // CONTENT with no START
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a"))])
        }
        // END with no START
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageEnd(TextMessageEndEvent(messageId: "m1"))])
        }
    }

    /// Interleaved messages with different ids are legal: tracked by id, not as a stack.
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

    /// TOOL_CALL_RESULT is not checked, as upstream: an unknown toolCallId passes.
    @Test func toolCallResultIsNotValidated() throws {
        try verifyAll([
            started,
            .toolCallResult(ToolCallResultEvent(messageId: "m", toolCallId: "never-started", content: "x")),
            finished,
        ])
    }

    /// Ordering for REASONING_MESSAGE_*, which is stricter here than upstream.
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
        // Step still open
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .stepStarted(StepStartedEvent(stepName: "s")), finished])
        }
        // Text message still open
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .textMessageStart(TextMessageStartEvent(messageId: "m")), finished])
        }
        // Tool call still open
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .toolCallStart(ToolCallStartEvent(toolCallId: "c", toolCallName: "f")), finished])
        }
        // Reasoning message still open, the rule that goes beyond upstream
        #expect(throws: AGUIError.self) {
            try verifyAll([started, .reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r")), finished])
        }
    }

    /// Unchecked events pass through during a run, but the global gate rejects them once
    /// RUN_ERROR has been seen.
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
