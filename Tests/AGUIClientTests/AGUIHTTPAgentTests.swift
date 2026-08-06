import AGUICore
import Foundation
import Testing

@testable import AGUIClient

/// URLProtocol スタブで SSE レスポンスを供給する結合テスト。
/// スタブがプロセス共有のため直列実行にする。
@Suite(.serialized)
struct AGUIHTTPAgentTests {
    private func makeAgent() -> AGUIHTTPAgent {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return AGUIHTTPAgent(
            url: URL(string: "https://agent.test/run")!,
            headers: ["X-Test": "1"],
            session: URLSession(configuration: configuration)
        )
    }

    private func collect(_ agent: AGUIHTTPAgent, input: RunAgentInput) async throws -> [AGUIEvent] {
        var events: [AGUIEvent] = []
        for try await event in agent.run(input) {
            events.append(event)
        }
        return events
    }

    @Test func streamsEventsFromSSEResponse() async throws {
        let sse = """
        data: {"type":"RUN_STARTED","threadId":"t1","runId":"r1"}

        : ping

        data: {"type":"TEXT_MESSAGE_START","messageId":"m1"}

        data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m1","delta":"こんにちは"}

        data: {"type":"TEXT_MESSAGE_END","messageId":"m1"}

        data: {"type":"RUN_FINISHED","threadId":"t1","runId":"r1","outcome":{"type":"success"}}

        """
        // マルチバイト文字の途中で割ってチャンク供給する
        let bytes = Array(sse.utf8)
        let cut = bytes.count / 2
        StubURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://agent.test/run")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.value(forHTTPHeaderField: "X-Test") == "1")
            return (200, ["Content-Type": "text/event-stream"], [Data(bytes[..<cut]), Data(bytes[cut...])])
        }
        defer { StubURLProtocol.handler = nil }

        let events = try await collect(makeAgent(), input: RunAgentInput(threadId: "t1", runId: "r1"))
        #expect(events == [
            .runStarted(RunStartedEvent(threadId: "t1", runId: "r1")),
            .textMessageStart(TextMessageStartEvent(messageId: "m1")),
            .textMessageContent(TextMessageContentEvent(messageId: "m1", delta: "こんにちは")),
            .textMessageEnd(TextMessageEndEvent(messageId: "m1")),
            .runFinished(RunFinishedEvent(threadId: "t1", runId: "r1", outcome: .success)),
        ])
    }

    @Test func requestBodyIsRunAgentInputJSON() async throws {
        StubURLProtocol.handler = { request in
            let body = request.httpBodyData ?? Data()
            let decoded = try? JSONDecoder().decode(RunAgentInput.self, from: body)
            #expect(decoded?.threadId == "t1")
            #expect(decoded?.messages.count == 1)
            #expect(decoded?.tools.isEmpty == true)
            return (200, ["Content-Type": "text/event-stream"], [])
        }
        defer { StubURLProtocol.handler = nil }

        let input = RunAgentInput(
            threadId: "t1",
            runId: "r1",
            messages: [.user(UserMessage(id: "u1", content: .text("hi")))]
        )
        _ = try await collect(makeAgent(), input: input)
    }

    /// 既定では何も落とさない(仕様どおり全部送る)。
    @Test func requestBodyKeepsEveryKeyByDefault() async throws {
        StubURLProtocol.handler = { request in
            let body = request.httpBodyData ?? Data()
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            #expect(object?["state"] != nil)
            #expect(object?["tools"] != nil)
            return (200, ["Content-Type": "text/event-stream"], [])
        }
        defer { StubURLProtocol.handler = nil }

        _ = try await collect(makeAgent(), input: RunAgentInput(threadId: "t1", runId: "r1"))
    }

    /// 繋ぎ先が読まない項目は落として送れる。型(`RunAgentInput`)は
    /// 上流の写しのまま — 変えるのは送り方だけ。
    @Test func omittedInputKeysAreStrippedFromTheBody() async throws {
        StubURLProtocol.handler = { request in
            let body = request.httpBodyData ?? Data()
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            #expect(object?["state"] == nil)
            #expect(object?["tools"] == nil)
            // 落としていないものは残る
            #expect(object?["threadId"] as? String == "t1")
            #expect(object?["messages"] != nil)
            return (200, ["Content-Type": "text/event-stream"], [])
        }
        defer { StubURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let agent = AGUIHTTPAgent(
            url: URL(string: "https://agent.test/run")!,
            session: URLSession(configuration: configuration),
            omittedInputKeys: ["state", "tools"]
        )
        _ = try await collect(agent, input: RunAgentInput(threadId: "t1", runId: "r1"))
    }

    @Test func non2xxThrowsHTTPErrorWithBody() async {
        StubURLProtocol.handler = { _ in
            (401, ["Content-Type": "application/json"], [Data(#"{"error":"unauthorized"}"#.utf8)])
        }
        defer { StubURLProtocol.handler = nil }

        await #expect(throws: AGUIHTTPError.self) {
            _ = try await self.collect(self.makeAgent(), input: RunAgentInput(threadId: "t", runId: "r"))
        }
    }

    @Test func protobufContentTypeIsRejected() async {
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/vnd.ag-ui.event+proto"], [Data()])
        }
        defer { StubURLProtocol.handler = nil }

        await #expect(throws: AGUIError.self) {
            _ = try await self.collect(self.makeAgent(), input: RunAgentInput(threadId: "t", runId: "r"))
        }
    }

    /// 不正な JSON ペイロードはストリームエラー(上流 zod と同じ意味論)。
    @Test func malformedEventFailsStream() async {
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "text/event-stream"], [Data("data: {\"type\":\"RUN_STARTED\"}\n\n".utf8)])
        }
        defer { StubURLProtocol.handler = nil }

        await #expect(throws: DecodingError.self) {
            _ = try await self.collect(self.makeAgent(), input: RunAgentInput(threadId: "t", runId: "r"))
        }
    }
}

/// テスト用スタブ。ハンドラが (status, headers, body chunks) を返す。
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, [String: String], [Data]))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: AGUIError("StubURLProtocol.handler not set"))
            return
        }
        let (status, headers, chunks) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLProtocol 経由では httpBody が nil になり httpBodyStream に載るため、両対応で読む。
    var httpBodyData: Data? {
        if let body = httpBody {
            return body
        }
        guard let stream = httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }
}
