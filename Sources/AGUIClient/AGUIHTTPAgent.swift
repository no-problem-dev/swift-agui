import AGUICore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thrown when the agent answers with a non-2xx status, before any event is parsed.
public struct AGUIHTTPError: Error, Sendable, CustomStringConvertible {
    public let statusCode: Int
    /// Response body for diagnosis — the server's error payload when it answers JSON.
    /// Read up to 1 MiB and silently cut off past that, so a long body arrives truncated.
    public let body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    public var description: String { "HTTP \(statusCode): \(body)" }
}

/// Drives a run over HTTP and reads the reply as a Server-Sent Events stream.
///
/// Mirrors `HttpAgent` in `@ag-ui/client`.
/// - Request: `POST` to a single URL, body = `RunAgentInput` as JSON,
///   `Accept: text/event-stream`
/// - Response: a content type matching the binary protocol exactly is refused with
///   `AGUIError`; anything else is parsed as SSE, whatever its content type says
/// - Cancellation is not raised as an error. The stream yields
///   `RUN_ERROR(code: "abort")` and then finishes normally
public final class AGUIHTTPAgent: AGUIAgent {
    /// How much of a non-2xx body is read; the rest of the response is left unread.
    private static let maxErrorBodySize = 1024 * 1024

    private let url: URL
    private let headers: [String: String]
    private let session: URLSession
    private let omittedInputKeys: Set<String>

    /// - Parameters:
    ///   - url: The agent endpoint. The spec says nothing about the shape of the path.
    ///   - headers: Extra headers, the injection point for auth tokens and the like.
    ///   - session: Substitutable URLSession, for tests and custom configurations.
    ///   - omittedInputKeys: **Top-level keys to strip from the body.**
    ///     Empty by default, which sends everything the spec defines.
    ///
    ///     `RunAgentInput` (`AGUICore`) is a copy of the upstream type, so fields nobody
    ///     reads are still required by the type. **What actually goes on the wire is the
    ///     client's call**, and there is no value in sending `state` or `tools` on every
    ///     request to a server that ignores them. This is where that line is drawn.
    ///
    ///     Only top-level keys can be dropped. Stripping the identifiers
    ///     (`threadId` / `runId`) breaks the run, but which fields a given server needs is
    ///     that server's business, so nothing here rejects it — the caller carries the risk.
    public init(
        url: URL,
        headers: [String: String] = [:],
        session: URLSession = .shared,
        omittedInputKeys: Set<String> = []
    ) {
        self.url = url
        self.headers = headers
        self.session = session
        self.omittedInputKeys = omittedInputKeys
    }

    public func run(_ input: RunAgentInput) -> AsyncThrowingStream<AGUIEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.stream(input: input, into: continuation)
                    continuation.finish()
                } catch is CancellationError {
                    Self.finishAborted(continuation)
                } catch let error as URLError where error.code == .cancelled {
                    Self.finishAborted(continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Builds the request body.
    ///
    /// With `omittedInputKeys` empty the input is **encoded straight through**. Otherwise
    /// the encoded JSON is re-serialized without those top-level keys, which as a side
    /// effect also sorts the remaining ones.
    ///
    /// Keys are dropped from the output rather than from the type because `RunAgentInput`
    /// is a copy of upstream: the type stays as the spec defines it, and only what is sent
    /// changes here.
    private func encodeBody(_ input: RunAgentInput) throws -> Data {
        let data = try JSONEncoder().encode(input)
        guard !omittedInputKeys.isEmpty else {
            return data
        }
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        for key in omittedInputKeys {
            object.removeValue(forKey: key)
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func finishAborted(_ continuation: AsyncThrowingStream<AGUIEvent, Error>.Continuation) {
        continuation.yield(.runError(RunErrorEvent(message: "Run was aborted", code: "abort")))
        continuation.finish()
    }

    private func stream(
        input: RunAgentInput,
        into continuation: AsyncThrowingStream<AGUIEvent, Error>.Continuation
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AGUIMediaTypeConstants.eventStream, forHTTPHeaderField: "Accept")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try encodeBody(input)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AGUIError("Non-HTTP response from \(url)")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= Self.maxErrorBodySize {
                    break
                }
            }
            throw AGUIHTTPError(
                statusCode: http.statusCode,
                body: String(decoding: body, as: UTF8.self)
            )
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        if contentType == AGUIMediaTypeConstants.protobuf {
            throw AGUIError("Binary protocol (\(contentType)) is not supported; request SSE")
        }

        var parser = SSEEventParser()
        let decoder = JSONDecoder()
        for try await byte in bytes {
            try parser.feed(byte)
            for payload in parser.drainPayloads() {
                continuation.yield(try decoder.decode(AGUIEvent.self, from: Data(payload.utf8)))
            }
        }
        for payload in parser.finish() {
            continuation.yield(try decoder.decode(AGUIEvent.self, from: Data(payload.utf8)))
        }
    }
}

/// The smallest set of media types the client needs, kept here so this target does not
/// have to depend on AGUIEncoder for two string constants.
enum AGUIMediaTypeConstants {
    static let eventStream = "text/event-stream"
    static let protobuf = "application/vnd.ag-ui.event+proto"
}
