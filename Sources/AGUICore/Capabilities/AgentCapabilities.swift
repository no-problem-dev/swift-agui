import StructuredDataCore

// エージェント能力の型付きスナップショット。
// ミラー元: `@ag-ui/core` `capabilities.ts`。
//
// discovery only — wire 上のネゴシエーションは存在しない。全フィールド optional で、
// 省略は「未宣言(unknown)」であって「非対応」ではない。

/// 親エージェントが呼び出せるサブエージェントの情報。
public struct SubAgentInfo: Codable, Sendable, Equatable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// エージェントの識別情報。
public struct IdentityCapabilities: Codable, Sendable, Equatable {
    public var name: String?
    /// 基盤フレームワーク(例: "langgraph", "mastra")。
    public var type: String?
    public var description: String?
    public var version: String?
    public var provider: String?
    public var documentationUrl: String?
    public var metadata: StructuredValue?

    public init(
        name: String? = nil,
        type: String? = nil,
        description: String? = nil,
        version: String? = nil,
        provider: String? = nil,
        documentationUrl: String? = nil,
        metadata: StructuredValue? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.version = version
        self.provider = provider
        self.documentationUrl = documentationUrl
        self.metadata = metadata
    }
}

/// 対応トランスポート。
public struct TransportCapabilities: Codable, Sendable, Equatable {
    public var streaming: Bool?
    public var websocket: Bool?
    public var httpBinary: Bool?
    public var pushNotifications: Bool?
    public var resumable: Bool?

    public init(
        streaming: Bool? = nil,
        websocket: Bool? = nil,
        httpBinary: Bool? = nil,
        pushNotifications: Bool? = nil,
        resumable: Bool? = nil
    ) {
        self.streaming = streaming
        self.websocket = websocket
        self.httpBinary = httpBinary
        self.pushNotifications = pushNotifications
        self.resumable = resumable
    }
}

/// ツール呼び出し能力。`items` はエージェント自身が持つツール
/// (クライアント提供の `RunAgentInput.tools` とは別物)。
public struct ToolsCapabilities: Codable, Sendable, Equatable {
    public var supported: Bool?
    public var items: [AGUITool]?
    public var parallelCalls: Bool?
    public var clientProvided: Bool?

    public init(
        supported: Bool? = nil,
        items: [AGUITool]? = nil,
        parallelCalls: Bool? = nil,
        clientProvided: Bool? = nil
    ) {
        self.supported = supported
        self.items = items
        self.parallelCalls = parallelCalls
        self.clientProvided = clientProvided
    }
}

/// 出力形式の対応。
public struct OutputCapabilities: Codable, Sendable, Equatable {
    public var structuredOutput: Bool?
    public var supportedMimeTypes: [String]?

    public init(structuredOutput: Bool? = nil, supportedMimeTypes: [String]? = nil) {
        self.structuredOutput = structuredOutput
        self.supportedMimeTypes = supportedMimeTypes
    }
}

/// state・メモリ管理の対応。
public struct StateCapabilities: Codable, Sendable, Equatable {
    public var snapshots: Bool?
    public var deltas: Bool?
    public var memory: Bool?
    public var persistentState: Bool?

    public init(
        snapshots: Bool? = nil,
        deltas: Bool? = nil,
        memory: Bool? = nil,
        persistentState: Bool? = nil
    ) {
        self.snapshots = snapshots
        self.deltas = deltas
        self.memory = memory
        self.persistentState = persistentState
    }
}

/// マルチエージェント連携の対応。
public struct MultiAgentCapabilities: Codable, Sendable, Equatable {
    public var supported: Bool?
    public var delegation: Bool?
    public var handoffs: Bool?
    public var subAgents: [SubAgentInfo]?

    public init(
        supported: Bool? = nil,
        delegation: Bool? = nil,
        handoffs: Bool? = nil,
        subAgents: [SubAgentInfo]? = nil
    ) {
        self.supported = supported
        self.delegation = delegation
        self.handoffs = handoffs
        self.subAgents = subAgents
    }
}

/// 推論(reasoning)の可視化対応。
public struct ReasoningCapabilities: Codable, Sendable, Equatable {
    public var supported: Bool?
    public var streaming: Bool?
    public var encrypted: Bool?

    public init(supported: Bool? = nil, streaming: Bool? = nil, encrypted: Bool? = nil) {
        self.supported = supported
        self.streaming = streaming
        self.encrypted = encrypted
    }
}

/// 入力モダリティの対応。
public struct MultimodalInputCapabilities: Codable, Sendable, Equatable {
    public var image: Bool?
    public var audio: Bool?
    public var video: Bool?
    public var pdf: Bool?
    public var file: Bool?

    public init(
        image: Bool? = nil,
        audio: Bool? = nil,
        video: Bool? = nil,
        pdf: Bool? = nil,
        file: Bool? = nil
    ) {
        self.image = image
        self.audio = audio
        self.video = video
        self.pdf = pdf
        self.file = file
    }
}

/// 出力モダリティの対応。
public struct MultimodalOutputCapabilities: Codable, Sendable, Equatable {
    public var image: Bool?
    public var audio: Bool?

    public init(image: Bool? = nil, audio: Bool? = nil) {
        self.image = image
        self.audio = audio
    }
}

/// マルチモーダル入出力の対応。
public struct MultimodalCapabilities: Codable, Sendable, Equatable {
    public var input: MultimodalInputCapabilities?
    public var output: MultimodalOutputCapabilities?

    public init(
        input: MultimodalInputCapabilities? = nil,
        output: MultimodalOutputCapabilities? = nil
    ) {
        self.input = input
        self.output = output
    }
}

/// 実行制御と上限。
public struct ExecutionCapabilities: Codable, Sendable, Equatable {
    public var codeExecution: Bool?
    public var sandboxed: Bool?
    public var maxIterations: Int?
    /// ミリ秒。
    public var maxExecutionTime: Int?

    public init(
        codeExecution: Bool? = nil,
        sandboxed: Bool? = nil,
        maxIterations: Int? = nil,
        maxExecutionTime: Int? = nil
    ) {
        self.codeExecution = codeExecution
        self.sandboxed = sandboxed
        self.maxIterations = maxIterations
        self.maxExecutionTime = maxExecutionTime
    }
}

/// 人間介在(human-in-the-loop)の対応。
public struct HumanInTheLoopCapabilities: Codable, Sendable, Equatable {
    public var supported: Bool?
    public var approvals: Bool?
    public var interventions: Bool?
    public var feedback: Bool?
    /// AG-UI interrupt プロトコル(RUN_FINISHED outcome=interrupt + resume)への参加。
    public var interrupts: Bool?
    /// tool-call interrupt の resume payload で editedArgs を受けるか。
    public var approveWithEdits: Bool?

    public init(
        supported: Bool? = nil,
        approvals: Bool? = nil,
        interventions: Bool? = nil,
        feedback: Bool? = nil,
        interrupts: Bool? = nil,
        approveWithEdits: Bool? = nil
    ) {
        self.supported = supported
        self.approvals = approvals
        self.interventions = interventions
        self.feedback = feedback
        self.interrupts = interrupts
        self.approveWithEdits = approveWithEdits
    }
}

/// エージェント能力の型付きスナップショット。
/// `custom` は標準カテゴリに収まらない実装固有能力の口。
public struct AgentCapabilities: Codable, Sendable, Equatable {
    public var identity: IdentityCapabilities?
    public var transport: TransportCapabilities?
    public var tools: ToolsCapabilities?
    public var output: OutputCapabilities?
    public var state: StateCapabilities?
    public var multiAgent: MultiAgentCapabilities?
    public var reasoning: ReasoningCapabilities?
    public var multimodal: MultimodalCapabilities?
    public var execution: ExecutionCapabilities?
    public var humanInTheLoop: HumanInTheLoopCapabilities?
    public var custom: StructuredValue?

    public init(
        identity: IdentityCapabilities? = nil,
        transport: TransportCapabilities? = nil,
        tools: ToolsCapabilities? = nil,
        output: OutputCapabilities? = nil,
        state: StateCapabilities? = nil,
        multiAgent: MultiAgentCapabilities? = nil,
        reasoning: ReasoningCapabilities? = nil,
        multimodal: MultimodalCapabilities? = nil,
        execution: ExecutionCapabilities? = nil,
        humanInTheLoop: HumanInTheLoopCapabilities? = nil,
        custom: StructuredValue? = nil
    ) {
        self.identity = identity
        self.transport = transport
        self.tools = tools
        self.output = output
        self.state = state
        self.multiAgent = multiAgent
        self.reasoning = reasoning
        self.multimodal = multimodal
        self.execution = execution
        self.humanInTheLoop = humanInTheLoop
        self.custom = custom
    }
}
