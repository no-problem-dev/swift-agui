import AGUICore
import Foundation

/// The two content types an AG-UI stream can be served as.
public enum AGUIMediaType {
    /// The default transport, and the only one this package can produce.
    public static let eventStream = "text/event-stream"
    /// The binary protobuf transport, which this package does not implement. The constant
    /// exists so a content type can be recognized and refused.
    public static let protobuf = "application/vnd.ag-ui.event+proto"
}

/// Server-side framing of events into an SSE stream.
///
/// Mirrors `EventEncoder` in `@ag-ui/encoder`. The only framing is `data: {json}\n\n`;
/// the `event:` field is never written, because the kind of an event is the `type` member
/// of the JSON body.
public struct EventEncoder: Sendable {
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = encoder
    }

    /// Always `text/event-stream`, since the binary transport is not implemented.
    public var contentType: String { AGUIMediaType.eventStream }

    /// Frames one event as `data: {json}\n\n`, leaving slashes unescaped in the JSON.
    public func encodeSSE(_ event: AGUIEvent) throws -> String {
        let data = try encoder.encode(event)
        return "data: \(String(decoding: data, as: UTF8.self))\n\n"
    }

    /// UTF-8 bytes of that same SSE frame, ready to write to an HTTP response body.
    /// Despite the name this is still SSE text, not the binary protobuf transport.
    public func encodeBinary(_ event: AGUIEvent) throws -> Data {
        Data(try encodeSSE(event).utf8)
    }

    /// SSE comment line to send periodically so proxies and load balancers do not drop an
    /// idle connection. Clients ignore it silently.
    public static let keepAlive = ": ping\n\n"
}
