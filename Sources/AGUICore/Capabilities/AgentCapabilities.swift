import StructuredDataCore

// A typed snapshot of what an agent says it can do. Mirrors `@ag-ui/core` `capabilities.ts`.
//
// Discovery only: the protocol has no negotiation step, and no transport in this package
// fetches or sends these types — a caller obtains them out of band. Every field is
// optional, and an omitted one means undeclared, not unsupported.

/// A sub-agent the parent says it can delegate to, advertised for display and routing —
/// there is no way to address one over the wire from here.
public struct SubAgentInfo: Codable, Sendable, Equatable {
    public var name: String
    public var description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// Who the agent is and what it runs on — descriptive only, and every field may be absent.
public struct IdentityCapabilities: Codable, Sendable, Equatable {
    public var name: String?
    /// The underlying framework, such as `"langgraph"` or `"mastra"`, not a MIME or
    /// discriminator type.
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

/// Which ways of connecting the agent claims to accept. `AGUIHTTPAgent` speaks only
/// HTTP + SSE, so the other flags matter to a different client, not to it.
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

/// What the agent can do with tools.
///
/// `items` lists the tools the agent already owns; do not confuse it with the
/// client-provided `RunAgentInput.tools`, which the app has to execute itself.
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

/// What the agent can produce beyond plain text, such as schema-constrained output and
/// specific MIME types.
public struct OutputCapabilities: Codable, Sendable, Equatable {
    public var structuredOutput: Bool?
    public var supportedMimeTypes: [String]?

    public init(structuredOutput: Bool? = nil, supportedMimeTypes: [String]? = nil) {
        self.structuredOutput = structuredOutput
        self.supportedMimeTypes = supportedMimeTypes
    }
}

/// How the agent handles shared state: whether it emits snapshots, deltas, or both, and
/// whether anything survives the thread.
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

/// Whether the agent works with other agents, and which ones it names as reachable.
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

/// Whether reasoning is exposed at all, whether it streams, and whether it comes
/// encrypted for zero-data-retention mode.
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

/// Which attachment kinds the agent accepts. `pdf` and `file` both map to the
/// `document` input part; the split exists here only.
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

/// Which non-text media the agent can generate. There are no video or document
/// counterparts to declare.
public struct MultimodalOutputCapabilities: Codable, Sendable, Equatable {
    public var image: Bool?
    public var audio: Bool?

    public init(image: Bool? = nil, audio: Bool? = nil) {
        self.image = image
        self.audio = audio
    }
}

/// The two directions of media support, kept apart because an agent that reads images
/// usually cannot produce them.
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

/// What the agent may run and the ceilings it stops at.
public struct ExecutionCapabilities: Codable, Sendable, Equatable {
    public var codeExecution: Bool?
    public var sandboxed: Bool?
    public var maxIterations: Int?
    /// Milliseconds, not seconds.
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

/// How the agent involves a person mid-run.
public struct HumanInTheLoopCapabilities: Codable, Sendable, Equatable {
    public var supported: Bool?
    public var approvals: Bool?
    public var interventions: Bool?
    public var feedback: Bool?
    /// Whether the agent takes part in the interrupt protocol at all — that is,
    /// `RUN_FINISHED` with `outcome: interrupt`, answered by a later resume.
    public var interrupts: Bool?
    /// Whether a tool-call interrupt accepts `editedArgs` in its resume payload.
    /// That is what lets a person approve a call with changed arguments, rather than
    /// only yes or no.
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

/// Everything an agent declares about itself, grouped by concern.
///
/// A category left out encodes as an absent key, which reads as undeclared rather than
/// unsupported, so do not treat `nil` as a no. `custom` is where implementation-specific
/// capabilities go when no standard category fits.
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
