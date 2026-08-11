/// The discriminator strings that appear in the `type` field of an event on the wire.
///
/// Mirrors `EventType` in `@ag-ui/core` `events.ts`. The five upstream-deprecated
/// `THINKING_*` values (scheduled for removal in 1.0.0, superseded by `REASONING_*`)
/// are deliberately absent; receiving one is not an error, it decodes as `.unknown`.
public enum AGUIEventType: String, Codable, Sendable, CaseIterable {
    case textMessageStart = "TEXT_MESSAGE_START"
    case textMessageContent = "TEXT_MESSAGE_CONTENT"
    case textMessageEnd = "TEXT_MESSAGE_END"
    case textMessageChunk = "TEXT_MESSAGE_CHUNK"
    case toolCallStart = "TOOL_CALL_START"
    case toolCallArgs = "TOOL_CALL_ARGS"
    case toolCallEnd = "TOOL_CALL_END"
    case toolCallChunk = "TOOL_CALL_CHUNK"
    case toolCallResult = "TOOL_CALL_RESULT"
    case stateSnapshot = "STATE_SNAPSHOT"
    case stateDelta = "STATE_DELTA"
    case messagesSnapshot = "MESSAGES_SNAPSHOT"
    case activitySnapshot = "ACTIVITY_SNAPSHOT"
    case activityDelta = "ACTIVITY_DELTA"
    case raw = "RAW"
    case custom = "CUSTOM"
    case runStarted = "RUN_STARTED"
    case runFinished = "RUN_FINISHED"
    case runError = "RUN_ERROR"
    case stepStarted = "STEP_STARTED"
    case stepFinished = "STEP_FINISHED"
    case reasoningStart = "REASONING_START"
    case reasoningMessageStart = "REASONING_MESSAGE_START"
    case reasoningMessageContent = "REASONING_MESSAGE_CONTENT"
    case reasoningMessageEnd = "REASONING_MESSAGE_END"
    case reasoningMessageChunk = "REASONING_MESSAGE_CHUNK"
    case reasoningEnd = "REASONING_END"
    case reasoningEncryptedValue = "REASONING_ENCRYPTED_VALUE"
}
