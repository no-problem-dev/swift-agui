import AGUICore
import AGUIJSONPatch
import StructuredDataCore

/// Something the reducer skipped rather than failed on: the event is dropped and the
/// stream keeps running.
public enum AGUIStateWarning: Sendable, Equatable {
    case contentForInactiveMessage(messageId: String)
    case argsForInactiveToolCall(toolCallId: String)
    case statePatchFailed(reason: String)
    case activityPatchFailed(messageId: String, reason: String)
    case activityDeltaForNonActivity(messageId: String)
}

/// Default reducer that folds events into a message list and a state document.
///
/// Mirrors `apply/default.ts` (`defaultApplyEvents`) in `@ag-ui/client`. A client with its
/// own reducer has no need for this layer.
///
/// It keeps the three special rules from upstream:
/// 1. Four-step resolution of the assistant message a tool call belongs to
/// 2. `TOOL_CALL_RESULT` is inserted right after its owning assistant message; appending
///    it at the end is what makes providers answer 400
/// 3. `MESSAGES_SNAPSHOT` merges by edit, with an all-or-nothing rule per role that keeps
///    client-only activity / reasoning messages alive
public struct AGUIClientState: Sendable, Equatable {
    public var messages: [AGUIMessage]
    public var state: StructuredValue
    /// Interrupts left open by the last run that finished with an interrupt outcome.
    /// `RUN_ERROR` does not clear them, matching upstream. Persisting them is the
    /// caller's job.
    public var pendingInterrupts: [Interrupt]

    public init(
        messages: [AGUIMessage] = [],
        state: StructuredValue = .object(OrderedObject()),
        pendingInterrupts: [Interrupt] = []
    ) {
        self.messages = messages
        self.state = state
        self.pendingInterrupts = pendingInterrupts
    }

    /// Applies one event, reporting recoverable inconsistencies as warnings instead of
    /// failing, and moving the state forward regardless.
    /// `*_CHUNK` events must be expanded first; one that arrives here throws `AGUIError`.
    @discardableResult
    public mutating func apply(_ event: AGUIEvent) throws -> [AGUIStateWarning] {
        switch event {
        case .textMessageChunk, .toolCallChunk, .reasoningMessageChunk:
            throw AGUIError("\(event.typeName) must be transformed before being applied (run ChunkTransform first)")

        case .textMessageStart(let start):
            // Leave an existing id alone; a preceding TOOL_CALL_START may have made it
            if !messages.contains(where: { $0.id == start.messageId }) {
                messages.append(Self.emptyMessage(id: start.messageId, role: start.role, name: start.name))
            }
            return []

        case .textMessageContent(let content):
            guard let index = messages.firstIndex(where: { $0.id == content.messageId }) else {
                return [.contentForInactiveMessage(messageId: content.messageId)]
            }
            messages[index] = Self.appendingContent(messages[index], delta: content.delta)
            return []

        case .textMessageEnd:
            return []

        case .toolCallStart(let start):
            let index = resolveOrCreateAssistantMessage(
                parentMessageId: start.parentMessageId,
                toolCallId: start.toolCallId
            )
            guard case .assistant(var assistant) = messages[index] else {
                return []
            }
            var toolCalls = assistant.toolCalls ?? []
            toolCalls.append(
                AGUIToolCall(id: start.toolCallId, function: AGUIFunctionCall(name: start.toolCallName, arguments: ""))
            )
            assistant.toolCalls = toolCalls
            messages[index] = .assistant(assistant)
            return []

        case .toolCallArgs(let args):
            guard let (messageIndex, toolCallIndex) = findToolCall(id: args.toolCallId) else {
                return [.argsForInactiveToolCall(toolCallId: args.toolCallId)]
            }
            guard case .assistant(var assistant) = messages[messageIndex], var toolCalls = assistant.toolCalls else {
                return []
            }
            toolCalls[toolCallIndex].function.arguments += args.delta
            assistant.toolCalls = toolCalls
            messages[messageIndex] = .assistant(assistant)
            return []

        case .toolCallEnd:
            return []

        case .toolCallResult(let result):
            insertToolResult(result)
            return []

        case .stateSnapshot(let snapshot):
            state = snapshot.snapshot
            return []

        case .stateDelta(let delta):
            do {
                state = try JSONPatch.apply(raw: delta.delta, to: state)
                return []
            } catch {
                return [.statePatchFailed(reason: String(describing: error))]
            }

        case .messagesSnapshot(let snapshot):
            mergeMessagesSnapshot(snapshot.messages)
            return []

        case .activitySnapshot(let snapshot):
            if let index = messages.firstIndex(where: { $0.id == snapshot.messageId }) {
                if snapshot.replace {
                    messages[index] = .activity(
                        ActivityMessage(id: snapshot.messageId, activityType: snapshot.activityType, content: snapshot.content)
                    )
                }
            } else {
                messages.append(.activity(
                    ActivityMessage(id: snapshot.messageId, activityType: snapshot.activityType, content: snapshot.content)
                ))
            }
            return []

        case .activityDelta(let delta):
            guard let index = messages.firstIndex(where: { $0.id == delta.messageId }) else {
                // A delta for an activity that is not there is a no-op, matching upstream
                return []
            }
            guard case .activity(var activity) = messages[index] else {
                return [.activityDeltaForNonActivity(messageId: delta.messageId)]
            }
            do {
                activity.content = try JSONPatch.apply(raw: delta.patch, to: activity.content)
                activity.activityType = delta.activityType
                messages[index] = .activity(activity)
                return []
            } catch {
                return [.activityPatchFailed(messageId: delta.messageId, reason: String(describing: error))]
            }

        case .runStarted(let started):
            // When the server echoes the canonical input, adopt the messages not seen yet
            if let injected = started.input?.messages {
                let known = Set(messages.map(\.id))
                messages.append(contentsOf: injected.filter { !known.contains($0.id) })
            }
            return []

        case .runFinished(let finished):
            if case .interrupt(let interrupts) = finished.outcome {
                pendingInterrupts = interrupts
            } else {
                pendingInterrupts = []
            }
            return []

        case .runError:
            // pendingInterrupts survive a run error, matching upstream
            return []

        case .reasoningMessageStart(let start):
            if !messages.contains(where: { $0.id == start.messageId }) {
                messages.append(.reasoning(ReasoningMessage(id: start.messageId, content: "")))
            }
            return []

        case .reasoningMessageContent(let content):
            guard let index = messages.firstIndex(where: { $0.id == content.messageId }) else {
                return [.contentForInactiveMessage(messageId: content.messageId)]
            }
            messages[index] = Self.appendingContent(messages[index], delta: content.delta)
            return []

        case .reasoningEncryptedValue(let event):
            applyEncryptedValue(event)
            return []

        case .reasoningMessageEnd, .reasoningStart, .reasoningEnd,
             .stepStarted, .stepFinished, .raw, .custom, .unknown:
            return []
        }
    }

    // MARK: - Special rule 1: four-step resolution of a tool call's parent message

    private mutating func resolveOrCreateAssistantMessage(parentMessageId: String?, toolCallId: String) -> Int {
        if let parentMessageId {
            if let index = messages.firstIndex(where: { $0.id == parentMessageId }) {
                if case .assistant = messages[index] {
                    return index // 1. Join the assistant that is already there
                }
                // 2. Id taken by a non-assistant message: start a new one under toolCallId
                messages.append(.assistant(AssistantMessage(id: toolCallId)))
                return messages.count - 1
            }
            // 3. parentMessageId given but absent: start a new one under that id
            messages.append(.assistant(AssistantMessage(id: parentMessageId)))
            return messages.count - 1
        }
        // 4. Not given at all: start a new one under toolCallId
        messages.append(.assistant(AssistantMessage(id: toolCallId)))
        return messages.count - 1
    }

    // MARK: - Special rule 2: where TOOL_CALL_RESULT is inserted

    private mutating func insertToolResult(_ result: ToolCallResultEvent) {
        let toolMessage = AGUIMessage.tool(
            ToolMessage(id: result.messageId, content: result.content, toolCallId: result.toolCallId)
        )
        guard let ownerIndex = messages.firstIndex(where: { message in
            if case .assistant(let assistant) = message {
                return assistant.toolCalls?.contains { $0.id == result.toolCallId } ?? false
            }
            return false
        }) else {
            messages.append(toolMessage)
            return
        }
        // Right after the owning assistant, behind any tool messages already there:
        // in a chat -> tool -> chat loop the result has to precede the text that follows it
        var insertIndex = ownerIndex + 1
        while insertIndex < messages.count, case .tool = messages[insertIndex] {
            insertIndex += 1
        }
        messages.insert(toolMessage, at: insertIndex)
    }

    // MARK: - Special rule 3: edit-based merge of MESSAGES_SNAPSHOT

    private mutating func mergeMessagesSnapshot(_ snapshot: [AGUIMessage]) {
        let snapshotHasActivity = snapshot.contains { $0.role == .activity }
        let snapshotHasReasoning = snapshot.contains { $0.role == .reasoning }
        let snapshotById = Dictionary(snapshot.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var merged: [AGUIMessage] = []
        var consumedIds = Set<String>()
        for message in messages {
            let isPreservedClientOnly = (message.role == .activity && !snapshotHasActivity)
                || (message.role == .reasoning && !snapshotHasReasoning)
            if isPreservedClientOnly {
                merged.append(message)
            } else if let replacement = snapshotById[message.id] {
                merged.append(replacement)
                consumedIds.insert(message.id)
            }
            // A local message absent from the snapshot is dropped
        }
        for message in snapshot where !consumedIds.contains(message.id) {
            merged.append(message)
        }
        messages = merged
    }

    // MARK: - Helpers

    private func findToolCall(id: String) -> (messageIndex: Int, toolCallIndex: Int)? {
        for (messageIndex, message) in messages.enumerated() {
            if case .assistant(let assistant) = message,
               let toolCallIndex = assistant.toolCalls?.firstIndex(where: { $0.id == id }) {
                return (messageIndex, toolCallIndex)
            }
        }
        return nil
    }

    private mutating func applyEncryptedValue(_ event: ReasoningEncryptedValueEvent) {
        switch event.subtype {
        case .toolCall:
            guard let (messageIndex, toolCallIndex) = findToolCall(id: event.entityId),
                  case .assistant(var assistant) = messages[messageIndex],
                  var toolCalls = assistant.toolCalls else {
                return
            }
            toolCalls[toolCallIndex].encryptedValue = event.encryptedValue
            assistant.toolCalls = toolCalls
            messages[messageIndex] = .assistant(assistant)
        case .message:
            guard let index = messages.firstIndex(where: { $0.id == event.entityId }) else {
                return
            }
            switch messages[index] {
            case .developer(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .developer(message)
            case .system(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .system(message)
            case .assistant(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .assistant(message)
            case .user(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .user(message)
            case .tool(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .tool(message)
            case .reasoning(var message):
                message.encryptedValue = event.encryptedValue
                messages[index] = .reasoning(message)
            case .activity:
                break // Activity messages have no encryptedValue field, matching upstream
            }
        }
    }

    private static func emptyMessage(id: String, role: TextMessageRole, name: String?) -> AGUIMessage {
        switch role {
        case .developer:
            .developer(DeveloperMessage(id: id, content: "", name: name))
        case .system:
            .system(SystemMessage(id: id, content: "", name: name))
        case .assistant:
            .assistant(AssistantMessage(id: id, content: "", name: name))
        case .user:
            .user(UserMessage(id: id, content: .text(""), name: name))
        }
    }

    private static func appendingContent(_ message: AGUIMessage, delta: String) -> AGUIMessage {
        switch message {
        case .developer(var payload):
            payload.content += delta
            return .developer(payload)
        case .system(var payload):
            payload.content += delta
            return .system(payload)
        case .assistant(var payload):
            payload.content = (payload.content ?? "") + delta
            return .assistant(payload)
        case .user(var payload):
            if case .text(let text) = payload.content {
                payload.content = .text(text + delta)
            }
            return .user(payload)
        case .tool(var payload):
            payload.content += delta
            return .tool(payload)
        case .reasoning(var payload):
            payload.content += delta
            return .reasoning(payload)
        case .activity:
            return message
        }
    }
}
