import AGUICore
import AGUIEncoder
import Foundation
import Testing

@testable import AGUIClient

struct SSEEventParserTests {
    private func feedAll(_ text: String) throws -> [String] {
        var parser = SSEEventParser()
        var payloads = try parser.feed(Array(text.utf8))
        payloads.append(contentsOf: parser.finish())
        return payloads
    }

    @Test func singleEvent() throws {
        let payloads = try feedAll("data: {\"type\":\"RUN_STARTED\"}\n\n")
        #expect(payloads == [#"{"type":"RUN_STARTED"}"#])
    }

    @Test func multipleEventsInOneFeed() throws {
        let payloads = try feedAll("data: 1\n\ndata: 2\n\ndata: 3\n\n")
        #expect(payloads == ["1", "2", "3"])
    }

    /// Several data: lines join with \n into a single payload.
    @Test func multipleDataLinesAreJoined() throws {
        let payloads = try feedAll("data: line1\ndata: line2\n\n")
        #expect(payloads == ["line1\nline2"])
    }

    /// Comment lines (the `: ping` keep-alive), event:, id: and retry: are all ignored.
    @Test func nonDataLinesAreIgnored() throws {
        let payloads = try feedAll(": ping\n\nevent: message\nid: 42\nretry: 1000\ndata: x\n\n: another ping\n\n")
        #expect(payloads == ["x"])
    }

    /// Exactly one space after the colon is stripped, never two.
    @Test func onlyOneLeadingSpaceIsStripped() throws {
        let payloads = try feedAll("data:  two spaces\n\ndata:none\n\n")
        #expect(payloads == [" two spaces", "none"])
    }

    /// A UTF-8 multi-byte character split across chunk boundaries survives.
    @Test func multibyteCharacterSplitAcrossFeeds() throws {
        let text = "data: {\"delta\":\"こんにちは\"}\n\n"
        let bytes = Array(text.utf8)
        var parser = SSEEventParser()
        var payloads: [String] = []
        // One byte at a time, the worst case
        for byte in bytes {
            payloads.append(contentsOf: try parser.feed(CollectionOfOne(byte)))
        }
        payloads.append(contentsOf: parser.finish())
        #expect(payloads == [#"{"delta":"こんにちは"}"#])
    }

    /// At EOF the buffered remainder, never terminated by a blank line, becomes one event.
    @Test func finishFlushesTrailingEvent() throws {
        var parser = SSEEventParser()
        let mid = try parser.feed(Array("data: tail".utf8))
        #expect(mid.isEmpty)
        #expect(parser.finish() == ["tail"])
    }

    /// A CRLF line ending is tolerated: the trailing \r is stripped off the data line.
    @Test func crlfLineEndingsAreTolerated() throws {
        let payloads = try feedAll("data: x\r\n\ndata: y\n\n")
        #expect(payloads == ["x", "y"])
    }

    /// Growing one event past the 8 MiB buffer ceiling throws AGUIError.
    @Test func bufferOverflowThrows() {
        var parser = SSEEventParser()
        let chunk = [UInt8](repeating: UInt8(ascii: "a"), count: 1024 * 1024)
        #expect(throws: AGUIError.self) {
            for _ in 0 ..< 9 {
                _ = try parser.feed(chunk)
            }
        }
    }

    /// Interoperability from the server-side encoder to the client-side parser.
    @Test func encoderParserRoundTrip() throws {
        let encoder = EventEncoder()
        let events: [AGUIEvent] = [
            .runStarted(RunStartedEvent(threadId: "t", runId: "r")),
            .textMessageStart(TextMessageStartEvent(messageId: "m")),
            .textMessageContent(TextMessageContentEvent(messageId: "m", delta: "絵文字🍳と改行\nを含む")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m")),
            .runFinished(RunFinishedEvent(threadId: "t", runId: "r", outcome: .success)),
        ]
        var stream = ""
        for event in events {
            stream += try encoder.encodeSSE(event)
            stream += EventEncoder.keepAlive
        }
        let payloads = try feedAll(stream)
        let decoded = try payloads.map { try JSONDecoder().decode(AGUIEvent.self, from: Data($0.utf8)) }
        #expect(decoded == events)
    }
}
