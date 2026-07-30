import AGUICore
import Foundation

/// AG-UI のメディアタイプ。
public enum AGUIMediaType {
    /// SSE(既定)。
    public static let eventStream = "text/event-stream"
    /// バイナリプロトコル(protobuf)。本実装は非対応 — 定数は content-type
    /// 判別のために持つ。
    public static let protobuf = "application/vnd.ag-ui.event+proto"
}

/// サーバー側の SSE イベントエンコーダ。
///
/// ミラー元: `@ag-ui/encoder` の `EventEncoder`。フレーミングは
/// `data: {json}\n\n` のみで、`event:` フィールドは使わない(イベント種別は
/// JSON 本体の `type` で判別する)。
public struct EventEncoder: Sendable {
    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = encoder
    }

    /// レスポンスの Content-Type。
    public var contentType: String { AGUIMediaType.eventStream }

    /// 1 イベントを SSE フレームにエンコードする。
    public func encodeSSE(_ event: AGUIEvent) throws -> String {
        let data = try encoder.encode(event)
        return "data: \(String(decoding: data, as: UTF8.self))\n\n"
    }

    /// SSE フレームの UTF-8 バイト列。HTTP ボディへの書き出し用。
    public func encodeBinary(_ event: AGUIEvent) throws -> Data {
        Data(try encodeSSE(event).utf8)
    }

    /// キープアライブ用の SSE コメント行。プロキシ・LB によるアイドル切断を防ぐ。
    /// クライアントは黙って無視する。
    public static let keepAlive = ": ping\n\n"
}
