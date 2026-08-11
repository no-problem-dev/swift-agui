import AGUICore
import Foundation
import Testing

@testable import AGUIEncoder

struct EventEncoderTests {
    @Test func framingIsDataLineWithDoubleNewline() throws {
        let encoder = EventEncoder()
        let frame = try encoder.encodeSSE(.runStarted(RunStartedEvent(threadId: "t1", runId: "r1")))
        #expect(frame.hasPrefix("data: {"))
        #expect(frame.hasSuffix("}\n\n"))
        #expect(!frame.contains("event:"))
        // Exactly one data line inside the frame
        #expect(frame.components(separatedBy: "\n").filter { $0.hasPrefix("data:") }.count == 1)
    }

    @Test func contentTypeIsEventStream() {
        #expect(EventEncoder().contentType == "text/event-stream")
    }

    @Test func keepAliveIsCommentLine() {
        #expect(EventEncoder.keepAlive == ": ping\n\n")
    }

    @Test func encodedPayloadIsValidEventJSON() throws {
        let encoder = EventEncoder()
        let original = AGUIEvent.textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "こんにちは"))
        let frame = try encoder.encodeSSE(original)
        let payload = String(frame.dropFirst("data: ".count).dropLast(2))
        let decoded = try JSONDecoder().decode(AGUIEvent.self, from: Data(payload.utf8))
        #expect(decoded == original)
    }
}
