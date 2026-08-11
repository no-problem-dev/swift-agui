/// Signals that a producer broke the protocol contract: events arriving out of order,
/// or a chunk missing a field the expansion layer requires.
///
/// Mirrors `AGUIError` in `@ag-ui/core`. It carries a human-readable message and nothing
/// machine-readable, so a consumer can report it but cannot branch on it — the stream is over.
public struct AGUIError: Error, Sendable, Equatable, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}
