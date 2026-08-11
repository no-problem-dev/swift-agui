import AGUICore
import Foundation

/// Incremental parser that takes the bytes of an SSE stream and hands back the `data`
/// payload (a JSON string) of every completed event.
///
/// Accepting rules, mirroring `transform/sse.ts` in `@ag-ui/client`:
/// - Events are separated by a blank line (`\n\n`); an incomplete fragment stays buffered
/// - Only `data:` lines are read, and exactly one space after the colon is stripped
/// - Several `data:` lines in one event join with `\n` into a single payload
/// - `event:` / `id:` / `retry:` and comment lines (leading `:`, which covers the
///   `: ping` keep-alive) are ignored
/// - There is no terminating sentinel; at EOF `finish()` flushes what is still buffered
///
/// Boundaries are found byte by byte, so a UTF-8 multi-byte character split across chunks
/// survives — bytes become a String only once a whole event is in hand.
public struct SSEEventParser: Sendable {
    /// Ceiling on one unterminated event, guarding against a producer that grows the
    /// buffer forever by never sending the blank line.
    public static let maxBufferSize = 8 * 1024 * 1024

    private var buffer: [UInt8] = []
    private var payloads: [String] = []

    public init() {}

    /// Appends bytes and returns the data payloads of every event completed so far.
    ///
    /// - Throws: `AGUIError` once a single event exceeds `maxBufferSize`. The parser keeps
    ///   the oversized buffer, so every later call throws too.
    public mutating func feed(_ bytes: some Sequence<UInt8>) throws -> [String] {
        for byte in bytes {
            try feed(byte)
        }
        return drainPayloads()
    }

    /// Appends one byte; completed payloads pile up internally until they are drained.
    ///
    /// - Throws: `AGUIError` once a single event exceeds `maxBufferSize`.
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

    /// Removes and returns the payloads accumulated since the last drain.
    public mutating func drainPayloads() -> [String] {
        let drained = payloads
        payloads.removeAll(keepingCapacity: true)
        return drained
    }

    /// Ends the stream, parsing any unterminated trailing bytes as one final event.
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

    /// Assembles the data payload of one event block, the bytes between blank lines.
    /// Lines are split at byte level too: Swift's String treats `\r\n` as one grapheme,
    /// so splitting by Character cannot strip a CRLF line ending.
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
