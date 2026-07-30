/// AG-UI プロトコル違反・契約違反のエラー。
///
/// ミラー元: `@ag-ui/core` の `AGUIError`。
public struct AGUIError: Error, Sendable, Equatable, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}
