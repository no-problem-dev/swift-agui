import AGUICore
import Foundation

/// SSE ストリームのインクリメンタルパーサ。バイト列を受けて、完成した
/// イベントの `data` ペイロード(JSON 文字列)を返す。
///
/// 受理規則(ミラー元: `@ag-ui/client` `transform/sse.ts`):
/// - イベント境界は空行(`\n\n`)。不完全な断片はバッファに保持する
/// - `data:` 行のみ処理し、コロン直後のスペースは 1 個だけ除去する
/// - 複数の `data:` 行は `\n` で連結して 1 つのペイロードにする
/// - `event:` / `id:` / `retry:` / コメント行(`:` 始まり。キープアライブ
///   `: ping` を含む)は無視する
/// - 終端センチネルは存在しない。EOF 時に `finish()` でバッファ残余を処理する
///
/// バイトレベルで境界を検出するため、UTF-8 のマルチバイト文字がチャンク境界で
/// 分断されても壊れない(String 変換は完成したイベント単位でのみ行う)。
public struct SSEEventParser: Sendable {
    /// バッファ上限。終端の空行を送らずバッファを膨らませる DoS への防御。
    public static let maxBufferSize = 8 * 1024 * 1024

    private var buffer: [UInt8] = []
    private var payloads: [String] = []

    public init() {}

    /// バイト列を追加し、完成したイベントの data ペイロードを返す。
    public mutating func feed(_ bytes: some Sequence<UInt8>) throws -> [String] {
        for byte in bytes {
            try feed(byte)
        }
        return drainPayloads()
    }

    /// 1 バイトを追加する。完成したペイロードは内部に蓄積される。
    public mutating func feed(_ byte: UInt8) throws {
        if byte == UInt8(ascii: "\n"), buffer.last == UInt8(ascii: "\n") {
            let block = buffer
            buffer.removeAll(keepingCapacity: true)
            if let payload = Self.parseBlock(block) {
                payloads.append(payload)
            }
            return
        }
        buffer.append(byte)
        guard buffer.count <= Self.maxBufferSize else {
            throw AGUIError("SSE event exceeds maximum buffer size (\(Self.maxBufferSize) bytes)")
        }
    }

    /// 蓄積済みペイロードを取り出す。
    public mutating func drainPayloads() -> [String] {
        let drained = payloads
        payloads.removeAll(keepingCapacity: true)
        return drained
    }

    /// ストリーム終端。バッファ残余を最後のイベントとして処理する。
    public mutating func finish() -> [String] {
        if !buffer.isEmpty {
            let block = buffer
            buffer.removeAll()
            if let payload = Self.parseBlock(block) {
                payloads.append(payload)
            }
        }
        return drainPayloads()
    }

    /// 1 イベントブロック(空行区切りの内側)から data ペイロードを組み立てる。
    /// 行分割もバイトレベルで行う(Swift の String は `\r\n` を 1 書記素として
    /// 扱うため、Character 単位の分割では CRLF 行末を処理できない)。
    private static func parseBlock(_ block: [UInt8]) -> String? {
        let prefix = Array("data:".utf8)
        var dataLines: [String] = []
        for var line in block.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false) {
            if line.last == UInt8(ascii: "\r") {
                line = line.dropLast()
            }
            guard line.starts(with: prefix) else {
                continue
            }
            var payload = line.dropFirst(prefix.count)
            if payload.first == UInt8(ascii: " ") {
                payload = payload.dropFirst()
            }
            dataLines.append(String(decoding: payload, as: UTF8.self))
        }
        guard !dataLines.isEmpty else {
            return nil
        }
        return dataLines.joined(separator: "\n")
    }
}
