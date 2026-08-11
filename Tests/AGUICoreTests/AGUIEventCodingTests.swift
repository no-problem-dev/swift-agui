import Foundation
import StructuredDataCore
import Testing

@testable import AGUICore

/// Pins the conversion to and from wire JSON. The fixtures are goldens transcribed from
/// the `@ag-ui/core` 0.0.57 schemas, so a diff here means the wire format moved.
struct AGUIEventCodingTests {
    private func decodeEvent(_ json: String) throws -> AGUIEvent {
        try JSONDecoder().decode(AGUIEvent.self, from: Data(json.utf8))
    }

    /// Checks that encoding then decoding gives back an equal value, and that every
    /// expected fragment appears in the encoded JSON.
    private func assertRoundTrip(
        _ event: AGUIEvent,
        expectedFragments: [String],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        let json = String(decoding: data, as: UTF8.self)
        for fragment in expectedFragments {
            #expect(json.contains(fragment), "missing \(fragment) in \(json)", sourceLocation: sourceLocation)
        }
        let decoded = try JSONDecoder().decode(AGUIEvent.self, from: data)
        #expect(decoded == event, sourceLocation: sourceLocation)
    }

    @Test func runStartedRoundTrip() throws {
        try assertRoundTrip(
            .runStarted(RunStartedEvent(threadId: "t1", runId: "r1")),
            expectedFragments: [#""type":"RUN_STARTED""#, #""threadId":"t1""#, #""runId":"r1""#]
        )
    }

    @Test func runFinishedSuccessOutcome() throws {
        let json = """
        {"type":"RUN_FINISHED","threadId":"t1","runId":"r1","outcome":{"type":"success"}}
        """
        let event = try decodeEvent(json)
        #expect(event == .runFinished(RunFinishedEvent(threadId: "t1", runId: "r1", outcome: .success)))
    }

    @Test func runFinishedInterruptOutcome() throws {
        let json = """
        {"type":"RUN_FINISHED","threadId":"t1","runId":"r1","outcome":{"type":"interrupt","interrupts":[{"id":"i1","reason":"input_required","message":"どの食材で探しますか?"}]}}
        """
        guard case .runFinished(let event) = try decodeEvent(json),
              case .interrupt(let interrupts) = event.outcome else {
            Issue.record("expected interrupt outcome")
            return
        }
        #expect(interrupts.count == 1)
        #expect(interrupts[0].id == "i1")
        #expect(interrupts[0].reason == Interrupt.Reason.inputRequired)
    }

    /// The Python SDK emits `outcome: null`, which must be accepted as an omission.
    @Test func runFinishedNullOutcomeIsAccepted() throws {
        let json = """
        {"type":"RUN_FINISHED","threadId":"t1","runId":"r1","outcome":null}
        """
        guard case .runFinished(let event) = try decodeEvent(json) else {
            Issue.record("expected runFinished")
            return
        }
        #expect(event.outcome == nil)
    }

    /// An interrupt outcome with an empty `interrupts` array violates the minimum of one.
    @Test func runFinishedEmptyInterruptsRejected() throws {
        let json = """
        {"type":"RUN_FINISHED","threadId":"t1","runId":"r1","outcome":{"type":"interrupt","interrupts":[]}}
        """
        #expect(throws: DecodingError.self) {
            _ = try decodeEvent(json)
        }
    }

    @Test func runErrorRoundTrip() throws {
        try assertRoundTrip(
            .runError(RunErrorEvent(message: "boom", code: "abort")),
            expectedFragments: [#""type":"RUN_ERROR""#, #""message":"boom""#, #""code":"abort""#]
        )
    }

    @Test func textMessageRoleDefaultsToAssistant() throws {
        let json = """
        {"type":"TEXT_MESSAGE_START","messageId":"m1"}
        """
        guard case .textMessageStart(let event) = try decodeEvent(json) else {
            Issue.record("expected textMessageStart")
            return
        }
        #expect(event.role == .assistant)
    }

    @Test func textMessageContentRoundTrip() throws {
        try assertRoundTrip(
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "こん")),
            expectedFragments: [#""type":"TEXT_MESSAGE_CONTENT""#, #""delta":"こん""#]
        )
    }

    /// .NET adapters emit `parentMessageId: null`, which must be accepted as an omission.
    @Test func toolCallStartNullParentMessageIdIsAccepted() throws {
        let json = """
        {"type":"TOOL_CALL_START","toolCallId":"c1","toolCallName":"search_recipes","parentMessageId":null}
        """
        guard case .toolCallStart(let event) = try decodeEvent(json) else {
            Issue.record("expected toolCallStart")
            return
        }
        #expect(event.parentMessageId == nil)
    }

    @Test func toolCallResultRoundTrip() throws {
        try assertRoundTrip(
            .toolCallResult(
                ToolCallResultEvent(messageId: "m2", toolCallId: "c1", content: "{}", role: .tool)
            ),
            expectedFragments: [#""type":"TOOL_CALL_RESULT""#, #""messageId":"m2""#, #""role":"tool""#]
        )
    }

    @Test func activitySnapshotReplaceDefaultsToTrue() throws {
        let json = """
        {"type":"ACTIVITY_SNAPSHOT","messageId":"a2ui-surface-c1","activityType":"a2ui-surface","content":{"a2ui_operations":[]}}
        """
        guard case .activitySnapshot(let event) = try decodeEvent(json) else {
            Issue.record("expected activitySnapshot")
            return
        }
        #expect(event.replace == true)
        #expect(event.activityType == "a2ui-surface")
        #expect(event.content["a2ui_operations"].arrayValue?.isEmpty == true)
    }

    @Test func stateDeltaKeepsRawPatchOperations() throws {
        let json = """
        {"type":"STATE_DELTA","delta":[{"op":"replace","path":"/count","value":2}]}
        """
        guard case .stateDelta(let event) = try decodeEvent(json) else {
            Issue.record("expected stateDelta")
            return
        }
        #expect(event.delta.count == 1)
        #expect(event.delta[0]["op"].stringValue == "replace")
    }

    @Test func customEventRoundTrip() throws {
        try assertRoundTrip(
            .custom(CustomEvent(name: "delish.usage", value: .object(["modelId": .string("gpt")]))),
            expectedFragments: [#""type":"CUSTOM""#, #""name":"delish.usage""#, #""modelId":"gpt""#]
        )
    }

    /// An unrecognised type decodes to `.unknown` and keeps the whole original object.
    @Test func unknownEventTypeIsTolerated() throws {
        let json = """
        {"type":"SOME_FUTURE_EVENT","payload":{"x":1}}
        """
        guard case .unknown(let type, let raw) = try decodeEvent(json) else {
            Issue.record("expected unknown")
            return
        }
        #expect(type == "SOME_FUTURE_EVENT")
        #expect(raw["payload"]["x"].numberValue != nil)
    }

    /// The upstream-deprecated THINKING_* events are not modelled, so they are accepted
    /// as unknown rather than rejected.
    @Test func deprecatedThinkingEventsFallToUnknown() throws {
        let event = try decodeEvent(#"{"type":"THINKING_START","title":"x"}"#)
        guard case .unknown(let type, _) = event else {
            Issue.record("expected unknown")
            return
        }
        #expect(type == "THINKING_START")
    }

    /// Unrecognised fields must be ignored, not rejected — the forward-compatibility rule.
    @Test func unknownFieldsAreIgnored() throws {
        let json = """
        {"type":"TEXT_MESSAGE_END","messageId":"m1","someFutureField":true}
        """
        let event = try decodeEvent(json)
        #expect(event == .textMessageEnd(TextMessageEndEvent(messageId: "m1")))
    }

    @Test func reasoningEncryptedValueRoundTrip() throws {
        try assertRoundTrip(
            .reasoningEncryptedValue(
                ReasoningEncryptedValueEvent(subtype: .toolCall, entityId: "c1", encryptedValue: "enc")
            ),
            expectedFragments: [#""type":"REASONING_ENCRYPTED_VALUE""#, #""subtype":"tool-call""#]
        )
    }

    @Test func reasoningMessageStartRequiresReasoningRole() throws {
        #expect(throws: DecodingError.self) {
            _ = try decodeEvent(#"{"type":"REASONING_MESSAGE_START","messageId":"m1","role":"assistant"}"#)
        }
    }

    @Test func timestampIsEpochMilliseconds() throws {
        let json = """
        {"type":"STEP_STARTED","stepName":"plan","timestamp":1753840000000}
        """
        guard case .stepStarted(let event) = try decodeEvent(json) else {
            Issue.record("expected stepStarted")
            return
        }
        #expect(event.timestamp == 1_753_840_000_000)
    }

    @Test func chunkEventsRoundTrip() throws {
        try assertRoundTrip(
            .textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "hi")),
            expectedFragments: [#""type":"TEXT_MESSAGE_CHUNK""#]
        )
        try assertRoundTrip(
            .toolCallChunk(ToolCallChunkEvent(toolCallId: "c1", toolCallName: "f", delta: "{")),
            expectedFragments: [#""type":"TOOL_CALL_CHUNK""#]
        )
        try assertRoundTrip(
            .reasoningMessageChunk(ReasoningMessageChunkEvent(messageId: "m1", delta: "…")),
            expectedFragments: [#""type":"REASONING_MESSAGE_CHUNK""#]
        )
    }

    @Test func messagesSnapshotRoundTrip() throws {
        let event = AGUIEvent.messagesSnapshot(
            MessagesSnapshotEvent(messages: [
                .user(UserMessage(id: "u1", content: .text("鶏肉のレシピ"))),
                .assistant(AssistantMessage(id: "a1", content: "こちらです", toolCalls: [
                    AGUIToolCall(id: "c1", function: AGUIFunctionCall(name: "search_recipes", arguments: #"{"q":"鶏肉"}"#)),
                ])),
                .tool(ToolMessage(id: "t1", content: "[]", toolCallId: "c1")),
            ])
        )
        try assertRoundTrip(
            event,
            expectedFragments: [#""type":"MESSAGES_SNAPSHOT""#, #""role":"user""#, #""role":"assistant""#, #""role":"tool""#]
        )
    }
}
