import StructuredDataCore

/// `RUN_STARTED` — opens a run, meaning one turn of execution.
///
/// It must be the first event of a stream (only `RUN_ERROR` may take its place), and a
/// second one is accepted only after `RUN_FINISHED`, where it starts a fresh run on the
/// same stream.
public struct RunStartedEvent: Codable, Sendable, Equatable {
    public var threadId: String
    public var runId: String
    public var parentRunId: String?
    /// The input the server considers canonical, echoed back so it can replay a run or
    /// inject messages the client never sent.
    /// The apply layer adopts any message here whose id it has not seen before.
    public var input: RunAgentInput?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        threadId: String,
        runId: String,
        parentRunId: String? = nil,
        input: RunAgentInput? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.threadId = threadId
        self.runId = runId
        self.parentRunId = parentRunId
        self.input = input
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// How a run ended, as a nested object with its own `type` discriminator.
///
/// The wire forms are `{"type": "success"}` and
/// `{"type": "interrupt", "interrupts": [...]}`. An omitted outcome, which legacy
/// producers send, means the run completed normally.
public enum RunFinishedOutcome: Sendable, Equatable {
    case success
    /// The run stopped to wait for a human. It is over — the client answers every
    /// interrupt through the next run's `RunAgentInput.resume`, not on this stream.
    /// The array must be non-empty; decoding an empty one throws.
    case interrupt([Interrupt])
}

extension RunFinishedOutcome: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case interrupts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "success":
            self = .success
        case "interrupt":
            let interrupts = try container.decode([Interrupt].self, forKey: .interrupts)
            guard !interrupts.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .interrupts,
                    in: container,
                    debugDescription: "interrupt outcome requires at least one interrupt"
                )
            }
            self = .interrupt(interrupts)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown RunFinishedOutcome type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success:
            try container.encode("success", forKey: .type)
        case .interrupt(let interrupts):
            try container.encode("interrupt", forKey: .type)
            try container.encode(interrupts, forKey: .interrupts)
        }
    }
}

/// `RUN_FINISHED` — ends the run, either successfully or at an interrupt.
///
/// `result` sits at the root of the event rather than inside `outcome`, kept there for
/// backward compatibility. An explicit `outcome: null` is accepted as an omission
/// because the Python SDK emits it. Sending this while a text message, tool call,
/// reasoning message, or step is still open fails verification.
public struct RunFinishedEvent: Codable, Sendable, Equatable {
    public var threadId: String
    public var runId: String
    public var result: StructuredValue?
    public var outcome: RunFinishedOutcome?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        threadId: String,
        runId: String,
        result: StructuredValue? = nil,
        outcome: RunFinishedOutcome? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.threadId = threadId
        self.runId = runId
        self.result = result
        self.outcome = outcome
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `RUN_ERROR` — the run failed; this is terminal and no further event may follow on
/// the stream, not even a new `RUN_STARTED`.
public struct RunErrorEvent: Codable, Sendable, Equatable {
    public var message: String
    public var code: String?
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(
        message: String,
        code: String? = nil,
        timestamp: Int64? = nil,
        rawEvent: StructuredValue? = nil
    ) {
        self.message = message
        self.code = code
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `STEP_STARTED` — opens a named step, purely as progress reporting.
///
/// The name is the identity: starting a step whose name is already open is rejected,
/// and every open step must be closed before `RUN_FINISHED`.
public struct StepStartedEvent: Codable, Sendable, Equatable {
    public var stepName: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(stepName: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.stepName = stepName
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}

/// `STEP_FINISHED` — closes the step with the matching `stepName`; a name that is not
/// currently open is a violation rather than a no-op.
public struct StepFinishedEvent: Codable, Sendable, Equatable {
    public var stepName: String
    public var timestamp: Int64?
    public var rawEvent: StructuredValue?

    public init(stepName: String, timestamp: Int64? = nil, rawEvent: StructuredValue? = nil) {
        self.stepName = stepName
        self.timestamp = timestamp
        self.rawEvent = rawEvent
    }
}
