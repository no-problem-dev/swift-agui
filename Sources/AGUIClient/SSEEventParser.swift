import AGUICore
import Foundation

/// Incremental parser that takes the bytes of an SSE stream and hands back the `data`
/// payload (a JSON string) of every completed event.
///
/// Accepting rules, mirroring `transform/sse.ts` in `@ag-ui/client`:
/// - Events are separated by a blank line, in either framing (`\n\n` or `\r\n\r\n`); an
///   incomplete fragment stays buffered
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
        buffer.append(byte)
        guard buffer.count <= Self.maxBufferSize else {
            throw AGUIError("SSE event exceeds maximum buffer size (\(Self.maxBufferSize) bytes)")
        }
        guard let blockEnd = Self.blankLineStart(endingAt: buffer) else { return }
        let block = Array(buffer[..<blockEnd])
        buffer.removeAll(keepingCapacity: true)
        if let payload = Self.parseBlock(block) {
            payloads.append(payload)
        }
    }

    /// Where the event ends, when the last byte just appended closed a blank line.
    ///
    /// The separator is a line ending followed by an empty line, and both endings can be `\n` or
    /// `\r\n` independently — so `\n\n`, `\r\n\r\n`, `\r\n\n` and `\n\r\n` all terminate an event.
    /// Testing only for two consecutive `\n` misses `\r\n\r\n`, the framing many SSE servers send,
    /// and the stream then runs on until the buffer ceiling.
    private static func blankLineStart(endingAt buffer: [UInt8]) -> Int? {
        guard buffer.last == UInt8(ascii: "\n") else { return nil }
        let separatorStart = buffer.count - 1
        guard separatorStart > 0 else { return nil }
        if buffer[separatorStart - 1] == UInt8(ascii: "\n") {
            return separatorStart - 1
        }
        guard separatorStart > 1,
              buffer[separatorStart - 1] == UInt8(ascii: "\r"),
              buffer[separatorStart - 2] == UInt8(ascii: "\n") else { return nil }
        return separatorStart - 2
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
