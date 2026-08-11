import StructuredDataCore

/// A tool the client declares it can run.
///
/// The agent only emits `TOOL_CALL_*` events for it; running the tool and sending back a
/// tool message is the app's job, and nothing happens if the app ignores the call.
public struct AGUITool: Codable, Sendable, Equatable {
    public var name: String
    public var description: String
    /// JSON Schema for the arguments. It is passed through verbatim and never validated
    /// here, so a malformed schema surfaces only at the agent.
    public var parameters: StructuredValue
    /// Free-form extension slot, used for things like an A2UI component schema.
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

/// A labelled piece of ambient context for the agent. Both fields are strings, so
/// structured context has to be serialised into `value` by the caller.
public struct AGUIContext: Codable, Sendable, Equatable {
    public var description: String
    public var value: String

    public init(description: String, value: String) {
        self.description = description
        self.value = value
    }
}

/// Everything one run needs, and the JSON body `POST`ed to the agent endpoint.
///
/// Mirrors `RunAgentInputSchema` in `@ag-ui/core` `types.ts`. `messages`, `tools`,
/// `context`, `state`, and `forwardedProps` are not omittable and always encode, empty or
/// not; `resume` is written only when it was set, so it never goes out as `[]`.
public struct RunAgentInput: Codable, Sendable, Equatable {
    /// Identifies the conversation across runs. The client owns it and the agent
    /// correlates history by it.
    public var threadId: String
    /// Identifies this run. The client mints a new one per run — reusing one makes two
    /// runs indistinguishable in the agent's logs.
    public var runId: String
    public var parentRunId: String?
    /// State shared with the agent, which `STATE_SNAPSHOT` and `STATE_DELTA` then update.
    public var state: StructuredValue
    /// Conversation history. Leave out `activity` messages: that role is client-side only.
    public var messages: [AGUIMessage]
    /// Tools the frontend can execute. Tools the agent runs on its own side do not belong
    /// here — the agent already knows about those.
    public var tools: [AGUITool]
    public var context: [AGUIContext]
    /// Anything else to hand the agent, such as auth tokens or A2UI actions. It stays
    /// untyped end to end.
    public var forwardedProps: StructuredValue
    /// Answers to the interrupts that ended the previous run. Cover every one of them —
    /// a partial set is not a valid resume.
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
