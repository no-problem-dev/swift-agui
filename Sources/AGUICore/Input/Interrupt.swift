import StructuredDataCore

/// run を中断して人間の入力を待つ割り込み。
/// `RUN_FINISHED { outcome: interrupt }` で届き、次の run の
/// `RunAgentInput.resume` で応答する(ターミナルモデル — ストリームは保持しない)。
public struct Interrupt: Codable, Sendable, Equatable {
    /// 相関キー。resume はこの id を参照する。
    public var id: String
    /// コア分類は "tool_call" / "input_required" / "confirmation"。
    /// それ以外の文字列も有効(`<framework>:<name>` で名前空間化推奨)。
    /// 未知の reason でエラーにせず、message / responseSchema からフォールバック描画する。
    public var reason: String
    public var message: String?
    public var toolCallId: String?
    /// 応答 payload の JSON Schema。
    public var responseSchema: StructuredValue?
    /// ISO-8601。期限切れの interrupt へ resume を送ってはならない。
    public var expiresAt: String?
    public var metadata: StructuredValue?

    public init(
        id: String,
        reason: String,
        message: String? = nil,
        toolCallId: String? = nil,
        responseSchema: StructuredValue? = nil,
        expiresAt: String? = nil,
        metadata: StructuredValue? = nil
    ) {
        self.id = id
        self.reason = reason
        self.message = message
        self.toolCallId = toolCallId
        self.responseSchema = responseSchema
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}

extension Interrupt {
    /// コア reason 分類。
    public enum Reason {
        public static let toolCall = "tool_call"
        public static let inputRequired = "input_required"
        public static let confirmation = "confirmation"
    }
}

/// resume エントリの状態。拒否は別ステータスではなく
/// `.resolved` の payload 内で表現する(例: `{"approved": false}`)。
public enum ResumeStatus: String, Codable, Sendable {
    case resolved
    case cancelled
}

/// interrupt への応答。次の run の `RunAgentInput.resume` に載せる。
/// 1 つの resume 配列が開いている全 interrupt を網羅すること(部分 resume は不可)。
public struct ResumeEntry: Codable, Sendable, Equatable {
    public var interruptId: String
    public var status: ResumeStatus
    public var payload: StructuredValue?

    public init(interruptId: String, status: ResumeStatus, payload: StructuredValue? = nil) {
        self.interruptId = interruptId
        self.status = status
        self.payload = payload
    }
}
