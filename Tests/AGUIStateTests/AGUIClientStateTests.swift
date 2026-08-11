import AGUICore
import StructuredDataCore
import Testing

@testable import AGUIState

struct AGUIClientStateTests {
    @Test func textMessageAccumulation() throws {
        var state = AGUIClientState()
        try state.apply(.textMessageStart(TextMessageStartEvent(messageId: "m1")))
        try state.apply(.textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "こん")))
        try state.apply(.textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "にちは")))
        try state.apply(.textMessageEnd(TextMessageEndEvent(messageId: "m1")))
        guard case .assistant(let assistant) = state.messages.first else {
            Issue.record("expected assistant message")
            return
        }
        #expect(assistant.content == "こんにちは")
    }

    @Test func contentForUnknownMessageWarnsAndSkips() throws {
        var state = AGUIClientState()
        let warnings = try state.apply(.textMessageContent(TextMessageContentEvent(messageId: "ghost", delta: "x")))
        #expect(warnings == [.contentForInactiveMessage(messageId: "ghost")])
        #expect(state.messages.isEmpty)
    }

    @Test func chunkEventsMustBeTransformedFirst() {
        var state = AGUIClientState()
        #expect(throws: AGUIError.self) {
            try state.apply(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "x")))
        }
    }

    // MARK: - Special rule 1: parent message resolution

    @Test func toolCallJoinsExistingAssistantParent() throws {
        var state = AGUIClientState()
        try state.apply(.textMessageStart(TextMessageStartEvent(messageId: "a1")))
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f", parentMessageId: "a1")))
        #expect(state.messages.count == 1)
        guard case .assistant(let assistant) = state.messages[0] else {
            Issue.record("expected assistant")
            return
        }
        #expect(assistant.toolCalls?.map(\.id) == ["c1"])
    }

    @Test func toolCallWithNonAssistantParentCreatesNewByToolCallId() throws {
        var state = AGUIClientState(messages: [.user(UserMessage(id: "u1", content: .text("q")))])
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f", parentMessageId: "u1")))
        #expect(state.messages.count == 2)
        #expect(state.messages[1].id == "c1")
    }

    @Test func toolCallWithMissingParentCreatesNewByParentId() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f", parentMessageId: "p1")))
        #expect(state.messages.first?.id == "p1")
    }

    @Test func toolCallWithoutParentCreatesNewByToolCallId() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f")))
        try state.apply(.toolCallArgs(ToolCallArgsEvent(toolCallId: "c1", delta: #"{"q":1}"#)))
        guard case .assistant(let assistant) = state.messages.first else {
            Issue.record("expected assistant")
            return
        }
        #expect(assistant.id == "c1")
        #expect(assistant.toolCalls?.first?.function.arguments == #"{"q":1}"#)
    }

    // MARK: - Special rule 2: where TOOL_CALL_RESULT is inserted

    @Test func toolResultInsertsAfterOwnerNotAtEnd() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f", parentMessageId: "a1")))
        try state.apply(.toolCallEnd(ToolCallEndEvent(toolCallId: "c1")))
        // The case where later text streams in before the tool result arrives
        try state.apply(.textMessageStart(TextMessageStartEvent(messageId: "a2")))
        try state.apply(.textMessageContent(TextMessageContentEvent(messageId: "a2", delta: "結果を見てみますね")))
        try state.apply(.toolCallResult(ToolCallResultEvent(messageId: "t1", toolCallId: "c1", content: "[]")))
        // Order must be assistant(tool_call) -> tool -> text, which is what avoids a provider 400
        #expect(state.messages.map(\.id) == ["a1", "t1", "a2"])
        #expect(state.messages[1].role == .tool)
    }

    @Test func parallelToolResultsKeepArrivalOrder() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f", parentMessageId: "a1")))
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c2", toolCallName: "g", parentMessageId: "a1")))
        try state.apply(.toolCallResult(ToolCallResultEvent(messageId: "t1", toolCallId: "c1", content: "1")))
        try state.apply(.toolCallResult(ToolCallResultEvent(messageId: "t2", toolCallId: "c2", content: "2")))
        #expect(state.messages.map(\.id) == ["a1", "t1", "t2"])
    }

    @Test func toolResultWithoutOwnerAppends() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallResult(ToolCallResultEvent(messageId: "t1", toolCallId: "ghost", content: "x")))
        #expect(state.messages.map(\.id) == ["t1"])
    }

    // MARK: - state

    @Test func stateSnapshotReplacesEntirely() throws {
        var state = AGUIClientState(state: .object(["old": .bool(true)]))
        try state.apply(.stateSnapshot(StateSnapshotEvent(snapshot: .object(["new": .bool(true)]))))
        #expect(state.state.objectValue?["old"] == nil)
        #expect(state.state["new"].boolValue == true)
    }

    @Test func stateDeltaAppliesPatch() throws {
        var state = AGUIClientState(state: .object(["count": .number(StructuredNumber(unchecked: "1"))]))
        let warnings = try state.apply(.stateDelta(StateDeltaEvent(delta: [
            .object(["op": .string("replace"), "path": .string("/count"), "value": .number(StructuredNumber(unchecked: "2"))]),
        ])))
        #expect(warnings.isEmpty)
        #expect(String(describing: state.state["count"].numberValue!) == "2")
    }

    /// A failed patch warns and is skipped, without bringing the stream down.
    @Test func failedStateDeltaWarnsAndKeepsState() throws {
        var state = AGUIClientState(state: .object(["count": .number(StructuredNumber(unchecked: "1"))]))
        let warnings = try state.apply(.stateDelta(StateDeltaEvent(delta: [
            .object(["op": .string("remove"), "path": .string("/ghost")]),
        ])))
        #expect(warnings.count == 1)
        #expect(String(describing: state.state["count"].numberValue!) == "1")
    }

    // MARK: - activity

    @Test func activitySnapshotUpsertsAndHonorsReplaceFlag() throws {
        var state = AGUIClientState()
        let first = ActivitySnapshotEvent(
            messageId: "a2ui-surface-c1",
            activityType: "a2ui-surface",
            content: .object(["status": .string("building")])
        )
        try state.apply(.activitySnapshot(first))
        // replace: true (the default): the paint replaces the skeleton
        let paint = ActivitySnapshotEvent(
            messageId: "a2ui-surface-c1",
            activityType: "a2ui-surface",
            content: .object(["a2ui_operations": .array([])])
        )
        try state.apply(.activitySnapshot(paint))
        #expect(state.messages.count == 1)
        guard case .activity(let activity) = state.messages[0] else {
            Issue.record("expected activity")
            return
        }
        #expect(activity.content.objectValue?["a2ui_operations"] != nil)
        // replace: false: ignored when one is already there
        var noReplace = ActivitySnapshotEvent(
            messageId: "a2ui-surface-c1",
            activityType: "a2ui-surface",
            content: .object(["status": .string("building")])
        )
        noReplace.replace = false
        try state.apply(.activitySnapshot(noReplace))
        guard case .activity(let unchanged) = state.messages[0] else {
            Issue.record("expected activity")
            return
        }
        #expect(unchanged.content.objectValue?["a2ui_operations"] != nil)
    }

    @Test func activityDeltaForMissingMessageIsNoOp() throws {
        var state = AGUIClientState()
        let warnings = try state.apply(.activityDelta(ActivityDeltaEvent(messageId: "ghost", activityType: "x", patch: [])))
        #expect(warnings.isEmpty)
        #expect(state.messages.isEmpty)
    }

    // MARK: - Special rule 3: MESSAGES_SNAPSHOT merge

    @Test func messagesSnapshotPreservesClientOnlyActivity() throws {
        var state = AGUIClientState(messages: [
            .user(UserMessage(id: "u1", content: .text("q"))),
            .activity(ActivityMessage(id: "act1", activityType: "a2ui-surface", content: .object([:]))),
        ])
        // Snapshot with no activity: the local activity survives, u1 is replaced, a1 is added
        try state.apply(.messagesSnapshot(MessagesSnapshotEvent(messages: [
            .user(UserMessage(id: "u1", content: .text("q"))),
            .assistant(AssistantMessage(id: "a1", content: "answer")),
        ])))
        #expect(state.messages.map(\.id) == ["u1", "act1", "a1"])
    }

    @Test func messagesSnapshotWithActivityOwnsCompleteSet() throws {
        var state = AGUIClientState(messages: [
            .activity(ActivityMessage(id: "act-old", activityType: "a2ui-surface", content: .object([:]))),
        ])
        // A snapshot holding any activity is the complete set for that role, so act-old goes
        try state.apply(.messagesSnapshot(MessagesSnapshotEvent(messages: [
            .activity(ActivityMessage(id: "act-new", activityType: "a2ui-surface", content: .object([:]))),
        ])))
        #expect(state.messages.map(\.id) == ["act-new"])
    }

    @Test func messagesSnapshotDropsLocalMessagesNotInSnapshot() throws {
        var state = AGUIClientState(messages: [
            .user(UserMessage(id: "u1", content: .text("q"))),
            .assistant(AssistantMessage(id: "a-local", content: "stale")),
        ])
        try state.apply(.messagesSnapshot(MessagesSnapshotEvent(messages: [
            .user(UserMessage(id: "u1", content: .text("q"))),
        ])))
        #expect(state.messages.map(\.id) == ["u1"])
    }

    // MARK: - interrupts / run lifecycle

    @Test func interruptOutcomeSetsPendingAndSuccessClears() throws {
        var state = AGUIClientState()
        let interrupt = Interrupt(id: "i1", reason: Interrupt.Reason.inputRequired)
        try state.apply(.runFinished(RunFinishedEvent(threadId: "t", runId: "r1", outcome: .interrupt([interrupt]))))
        #expect(state.pendingInterrupts == [interrupt])
        try state.apply(.runFinished(RunFinishedEvent(threadId: "t", runId: "r2", outcome: .success)))
        #expect(state.pendingInterrupts.isEmpty)
    }

    @Test func runErrorDoesNotClearPendingInterrupts() throws {
        var state = AGUIClientState(pendingInterrupts: [Interrupt(id: "i1", reason: "confirmation")])
        try state.apply(.runError(RunErrorEvent(message: "boom")))
        #expect(state.pendingInterrupts.count == 1)
    }

    @Test func runStartedInjectsUnknownCanonicalMessages() throws {
        var state = AGUIClientState(messages: [.user(UserMessage(id: "u1", content: .text("q")))])
        let input = RunAgentInput(
            threadId: "t",
            runId: "r",
            messages: [
                .user(UserMessage(id: "u1", content: .text("q"))),
                .system(SystemMessage(id: "s1", content: "injected")),
            ]
        )
        try state.apply(.runStarted(RunStartedEvent(threadId: "t", runId: "r", input: input)))
        #expect(state.messages.map(\.id) == ["u1", "s1"])
    }

    // MARK: - reasoning

    @Test func reasoningMessageAccumulation() throws {
        var state = AGUIClientState()
        try state.apply(.reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r1")))
        try state.apply(.reasoningMessageContent(ReasoningMessageContentEvent(messageId: "r1", delta: "うーん")))
        try state.apply(.reasoningMessageEnd(ReasoningMessageEndEvent(messageId: "r1")))
        guard case .reasoning(let reasoning) = state.messages.first else {
            Issue.record("expected reasoning message")
            return
        }
        #expect(reasoning.content == "うーん")
    }

    @Test func encryptedValueAttachesToToolCallAndMessage() throws {
        var state = AGUIClientState()
        try state.apply(.toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f")))
        try state.apply(.reasoningEncryptedValue(
            ReasoningEncryptedValueEvent(subtype: .toolCall, entityId: "c1", encryptedValue: "enc1")
        ))
        guard case .assistant(let assistant) = state.messages[0] else {
            Issue.record("expected assistant")
            return
        }
        #expect(assistant.toolCalls?.first?.encryptedValue == "enc1")

        try state.apply(.reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r1")))
        try state.apply(.reasoningEncryptedValue(
            ReasoningEncryptedValueEvent(subtype: .message, entityId: "r1", encryptedValue: "enc2")
        ))
        guard case .reasoning(let reasoning) = state.messages[1] else {
            Issue.record("expected reasoning")
            return
        }
        #expect(reasoning.encryptedValue == "enc2")
    }
}
