import AGUICore
import AGUIJSONPatch
import StructuredDataCore

/// apply 層の警告(ストリームを落とさずスキップした事象の通知)。
public enum AGUIStateWarning: Sendable, Equatable {
    case contentForInactiveMessage(messageId: String)
    case argsForInactiveToolCall(toolCallId: String)
    case statePatchFailed(reason: String)
    case activityPatchFailed(messageId: String, reason: String)
    case activityDeltaForNonActivity(messageId: String)
}

/// イベントを messages / state へ還元するデフォルトリデューサ。
///
/// ミラー元: `@ag-ui/client` `apply/default.ts`(`defaultApplyEvents`)。
/// 独自リデューサを持つクライアントはこの層を使わなくてよい。
///
/// 上流の 3 つの特殊規則を保持する:
/// 1. ツールコールの親 assistant メッセージ解決(4 段階)
/// 2. `TOOL_CALL_RESULT` は所有 assistant メッセージの直後へ挿入
///    (末尾 append は provider 400 の原因になる)
/// 3. `MESSAGES_SNAPSHOT` は編集ベースマージ(activity / reasoning の
///    全か無か規則でクライアント専用メッセージを保護)
public struct AGUIClientState: Sendable, Equatable {
    public var messages: [AGUIMessage]
    public var state: StructuredValue
    /// 直近の run が interrupt で終わった場合の未解決 interrupt。
    /// `RUN_ERROR` ではクリアされない(上流仕様)。永続化は利用側の責務。
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

    /// 1 イベントを適用する。回復可能な不整合は警告として返し、状態は進める。
    /// `*_CHUNK` は展開済みが前提(届いたら `AGUIError` を throw)。
    @discardableResult
    public mutating func apply(_ event: AGUIEvent) throws -> [AGUIStateWarning] {
        switch event {
        case .textMessageChunk, .toolCallChunk, .reasoningMessageChunk:
            throw AGUIError("\(event.typeName) must be transformed before being applied (run ChunkTransform first)")

        case .textMessageStart(let start):
            // 既存 id(先行する TOOL_CALL_START が作った assistant 等)には触れない
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
                // 存在しないアクティビティへの delta は no-op(上流仕様)
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
            // サーバーが正準の入力を注入した場合、未知 id のメッセージを取り込む
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
            // pendingInterrupts はクリアしない(上流仕様)
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

    // MARK: - 特殊規則 1: ツールコールの親メッセージ解決(4 段階)

    private mutating func resolveOrCreateAssistantMessage(parentMessageId: String?, toolCallId: String) -> Int {
        if let parentMessageId {
            if let index = messages.firstIndex(where: { $0.id == parentMessageId }) {
                if case .assistant = messages[index] {
                    return index // 1. 既存 assistant に合流
                }
                // 2. id 衝突(非 assistant)→ toolCallId をキーに新規
                messages.append(.assistant(AssistantMessage(id: toolCallId)))
                return messages.count - 1
            }
            // 3. parentMessageId 指定だが不在 → その id で新規
            messages.append(.assistant(AssistantMessage(id: parentMessageId)))
            return messages.count - 1
        }
        // 4. 無指定 → toolCallId をキーに新規
        messages.append(.assistant(AssistantMessage(id: toolCallId)))
        return messages.count - 1
    }

    // MARK: - 特殊規則 2: TOOL_CALL_RESULT の挿入位置

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
        // 所有 assistant の直後、既存の tool メッセージ列の後ろに挿入
        // (chat → tool → chat ループで後続テキストより前に結果を置くための正当性要件)
        var insertIndex = ownerIndex + 1
        while insertIndex < messages.count, case .tool = messages[insertIndex] {
            insertIndex += 1
        }
        messages.insert(toolMessage, at: insertIndex)
    }

    // MARK: - 特殊規則 3: MESSAGES_SNAPSHOT の編集ベースマージ

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
            // snapshot に無いローカルメッセージは破棄
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
                break // encryptedValue フィールドを持たない(上流仕様)
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
