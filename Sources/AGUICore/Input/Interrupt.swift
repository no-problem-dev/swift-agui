import StructuredDataCore

/// A stop point where the agent needs a human before it can go on.
///
/// It arrives inside `RUN_FINISHED { outcome: interrupt }` and is answered through the
/// next run's `RunAgentInput.resume`. The model is terminal, not suspended: the stream is
/// already closed, so there is nothing to keep open while the person decides.
public struct Interrupt: Codable, Sendable, Equatable {
    /// Correlation key that the matching resume entry points back at.
    public var id: String
    /// Why the agent stopped. The core values are `"tool_call"`, `"input_required"`, and
    /// `"confirmation"`, but any string is legal, so namespace custom ones as
    /// `<framework>:<name>`. Treat an unrecognised reason as renderable rather than fatal:
    /// fall back to `message` and `responseSchema`.
    public var reason: String
    public var message: String?
    public var toolCallId: String?
    /// JSON Schema the resume payload should satisfy, for building a form to answer with.
    public var responseSchema: StructuredValue?
    /// ISO-8601 deadline. Nothing here enforces it — do not resume an interrupt past it.
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
    /// The reason strings the protocol defines, spelled exactly as they go on the wire.
    public enum Reason {
        public static let toolCall = "tool_call"
        public static let inputRequired = "input_required"
        public static let confirmation = "confirmation"
    }
}

/// How an interrupt was settled. There is no "rejected" status: a refusal is still
/// `.resolved`, expressed inside the payload as something like `{"approved": false}`,
/// while `.cancelled` is for an interrupt no answer was ever given for.
public enum ResumeStatus: String, Codable, Sendable {
    case resolved
    case cancelled
}

/// One answer to one interrupt, carried in the next run's `RunAgentInput.resume`.
///
/// The array it sits in has to cover every open interrupt; partial resumes are not
/// allowed, and nothing in this package checks that before the request goes out.
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
