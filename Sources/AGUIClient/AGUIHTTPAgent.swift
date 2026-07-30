import AGUICore
import Foundation

/// HTTP レスポンスがストリームとして成立しなかったときのエラー。
public struct AGUIHTTPError: Error, Sendable, CustomStringConvertible {
    public let statusCode: Int
    /// レスポンスボディ(診断用。JSON ならサーバーのエラーペイロード)。
    public let body: String

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    public var description: String { "HTTP \(statusCode): \(body)" }
}

/// HTTP + SSE の AG-UI エージェント接続。
///
/// ミラー元: `@ag-ui/client` の `HttpAgent`。
/// - リクエスト: 単一 URL への `POST`、ボディ = `RunAgentInput` の JSON、
///   `Accept: text/event-stream`
/// - レスポンス: content-type がバイナリプロトコル完全一致ならエラー(非対応)、
///   それ以外は SSE としてパースする
/// - キャンセルは例外ではなく `RUN_ERROR(code: "abort")` に正規化してから終了する
public final class AGUIHTTPAgent: AGUIAgent {
    /// 非 2xx レスポンスのボディ読み取り上限。
    private static let maxErrorBodySize = 1024 * 1024

    private let url: URL
    private let headers: [String: String]
    private let session: URLSession

    /// - Parameters:
    ///   - url: エージェントのエンドポイント(パス形状の規定は仕様にない)。
    ///   - headers: 追加ヘッダ(認証トークン等の注入ポイント)。
    ///   - session: 差し替え可能な URLSession(テスト・カスタム構成用)。
    public init(url: URL, headers: [String: String] = [:], session: URLSession = .shared) {
        self.url = url
        self.headers = headers
        self.session = session
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
        request.httpBody = try JSONEncoder().encode(input)

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

/// メディアタイプ定数(AGUIEncoder と重複定義しない、クライアント側の最小セット)。
enum AGUIMediaTypeConstants {
    static let eventStream = "text/event-stream"
    static let protobuf = "application/vnd.ag-ui.event+proto"
}
