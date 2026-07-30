import StructuredDataCore

/// クライアント提供ツールの宣言。サーバーは `TOOL_CALL_*` を emit するだけで、
/// 実行はクライアント(アプリ)の責務。
public struct AGUITool: Codable, Sendable, Equatable {
    public var name: String
    public var description: String
    /// 引数の JSON Schema。
    public var parameters: StructuredValue
    /// 任意メタデータ(A2UI スキーマ等の拡張の口)。
    public var metadata: StructuredValue?

    public init(
        name: String,
        description: String,
        parameters: StructuredValue,
        metadata: StructuredValue? = nil
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.metadata = metadata
    }
}

/// クライアントがエージェントに渡す文脈情報。
public struct AGUIContext: Codable, Sendable, Equatable {
    public var description: String
    public var value: String

    public init(description: String, value: String) {
        self.description = description
        self.value = value
    }
}

/// 1 run の実行入力。エンドポイントへ `POST` する JSON ボディ。
///
/// ミラー元: `@ag-ui/core` `types.ts` の `RunAgentInputSchema`。
/// `messages` / `tools` / `context` は省略不可 — 空でも `[]` を送る。
/// `resume` は明示指定時のみ載せる(`[]` を既定にしない)。
public struct RunAgentInput: Codable, Sendable, Equatable {
    /// 会話スレッド識別子。クライアントが所有する。
    public var threadId: String
    /// run ごとにクライアントが発行する識別子。
    public var runId: String
    public var parentRunId: String?
    /// 共有 state。
    public var state: StructuredValue
    /// 会話履歴。activity ロールは載せない(クライアント側専用)。
    public var messages: [AGUIMessage]
    /// クライアント提供(フロントエンド)ツール。バックエンドツールは含めない。
    public var tools: [AGUITool]
    public var context: [AGUIContext]
    /// クライアント → エージェントの追加プロパティ(認証情報・A2UI アクション等)。
    public var forwardedProps: StructuredValue
    /// 開いている interrupt への応答。全 interrupt を網羅すること。
    public var resume: [ResumeEntry]?

    public init(
        threadId: String,
        runId: String,
        parentRunId: String? = nil,
        state: StructuredValue = .object(OrderedObject()),
        messages: [AGUIMessage] = [],
        tools: [AGUITool] = [],
        context: [AGUIContext] = [],
        forwardedProps: StructuredValue = .object(OrderedObject()),
        resume: [ResumeEntry]? = nil
    ) {
        self.threadId = threadId
        self.runId = runId
        self.parentRunId = parentRunId
        self.state = state
        self.messages = messages
        self.tools = tools
        self.context = context
        self.forwardedProps = forwardedProps
        self.resume = resume
    }
}
