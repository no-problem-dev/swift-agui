import AGUICore
import Testing

@testable import AGUIClient

struct ChunkTransformTests {
    @Test func textChunksExpandToTriple() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "こん")))
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(delta: "にちは")))
        events += transform.finish()
        #expect(events == [
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "こん")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "にちは")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
        ])
    }

    @Test func firstTextChunkRequiresMessageId() {
        var transform = ChunkTransform()
        #expect(throws: AGUIError.self) {
            _ = try transform.transform(.textMessageChunk(TextMessageChunkEvent(delta: "x")))
        }
    }

    @Test func toolChunksExpandToTriple() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(
            .toolCallChunk(ToolCallChunkEvent(toolCallId: "c1", toolCallName: "search_recipes", delta: #"{"q":"#))
        )
        events += try transform.transform(.toolCallChunk(ToolCallChunkEvent(delta: #""鶏肉"}"#)))
        events += transform.finish()
        #expect(events == [
            .toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "search_recipes")),
            .toolCallArgs(ToolCallArgsEvent(toolCallId: "c1", delta: #"{"q":"#)),
            .toolCallArgs(ToolCallArgsEvent(toolCallId: "c1", delta: #""鶏肉"}"#)),
            .toolCallEnd(ToolCallEndEvent(toolCallId: "c1")),
        ])
    }

    @Test func firstToolChunkRequiresIdAndName() {
        var transform = ChunkTransform()
        #expect(throws: AGUIError.self) {
            _ = try transform.transform(.toolCallChunk(ToolCallChunkEvent(toolCallId: "c1", delta: "{")))
        }
    }

    @Test func reasoningChunksExpandToTriple() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(.reasoningMessageChunk(ReasoningMessageChunkEvent(messageId: "r1", delta: "…")))
        events += transform.finish()
        #expect(events == [
            .reasoningMessageStart(ReasoningMessageStartEvent(messageId: "r1")),
            .reasoningMessageContent(ReasoningMessageContentEvent(messageId: "r1", delta: "…")),
            .reasoningMessageEnd(ReasoningMessageEndEvent(messageId: "r1")),
        ])
    }

    /// id が変わったら現在のエンティティを閉じて新規に開く。
    @Test func idChangeClosesAndReopens() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "a")))
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m2", delta: "b")))
        events += transform.finish()
        #expect(events == [
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            .textMessageStart(TextMessageStartEvent(messageId: "m2")),
            .textMessageContent(TextMessageContentEvent(messageId: "m2", delta: "b")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m2")),
        ])
    }

    /// モード変更(text → tool)も暗黙クローズする。
    @Test func modeChangeClosesCurrentEntity() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "a")))
        events += try transform.transform(.toolCallChunk(ToolCallChunkEvent(toolCallId: "c1", toolCallName: "f")))
        events += transform.finish()
        #expect(events == [
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            .toolCallStart(ToolCallStartEvent(toolCallId: "c1", toolCallName: "f")),
            .toolCallEnd(ToolCallEndEvent(toolCallId: "c1")),
        ])
    }

    /// 非チャンクイベントは開いているエンティティを閉じてから通す。
    @Test func nonChunkEventClosesOpenEntity() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "a")))
        events += try transform.transform(.stepFinished(StepFinishedEvent(stepName: "s")))
        #expect(events == [
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            .stepFinished(StepFinishedEvent(stepName: "s")),
        ])
    }

    /// パススルー例外(ACTIVITY_SNAPSHOT 等)はエンティティを閉じない。
    @Test func passthroughEventsDoNotClose() throws {
        var transform = ChunkTransform()
        var events: [AGUIEvent] = []
        let snapshot = AGUIEvent.activitySnapshot(
            ActivitySnapshotEvent(messageId: "a", activityType: "a2ui-surface", content: .object([:]))
        )
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(messageId: "m1", delta: "a")))
        events += try transform.transform(snapshot)
        events += try transform.transform(.textMessageChunk(TextMessageChunkEvent(delta: "b")))
        events += transform.finish()
        #expect(events == [
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "a")),
            snapshot,
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "b")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
        ])
    }
}
