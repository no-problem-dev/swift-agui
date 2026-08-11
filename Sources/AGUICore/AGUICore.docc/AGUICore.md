# ``AGUICore``

The AG-UI wire vocabulary in Swift types: the events an agent streams, the messages a conversation is made of, the input that starts a run, and the interrupts that hand control back to a person.

## Overview

Nothing here opens a connection. These are the types both ends agree on, so a client, a
server, or a test fixture can all speak the same language, and the transport targets are
built on top of them.

Decoding is deliberately lopsided. An event whose `type` this version does not model
decodes to `AGUIEvent.unknown` with the entire wire object kept alongside it, so a stream
from a newer producer degrades instead of failing, nothing is dropped, and re-encoding the
event reproduces it byte for byte. The deprecated `THINKING_*` events arrive that way too.
A `type` that *is* modelled but whose payload is malformed throws instead, which ends the
stream. Messages are stricter than events: a `role` this version does not know throws and
takes the whole message with it, so an unrecognised message is loud rather than lost.

Several fields are optional here only because producers in other languages send `null`
where the schema says a value. ``ToolCallStartEvent`` accepts an explicit
`parentMessageId: null`, which .NET adapters emit, and ``RunFinishedEvent`` accepts
`outcome: null`, which the Python SDK emits; both are read as omissions rather than
rejected. An absent `role` on ``TextMessageStartEvent`` means `assistant` and an absent
`replace` on ``ActivitySnapshotEvent`` means `true`, following the upstream defaults. A
`RUN_FINISHED` that says it ended at an interrupt but carries an empty `interrupts` array
does throw — that shape is meaningless.

Two things to watch when you assemble a ``RunAgentInput``: ``ActivityMessage`` is a
client-side role that nothing strips for you, so leave those messages out; and the tools
you list are the ones *your app* will execute, not the ones the agent already owns.

This implementation is unofficial, and conforming to the specification is not a goal of the
project. It tracks the TypeScript SDK `@ag-ui/core` 0.0.57.

```swift
switch event {
case .textMessageContent(let content):
    transcript[content.messageId, default: ""] += content.delta
case .unknown(let type, _):
    print("ignoring unmodelled event \(type)")
default:
    break
}
```

## Topics

### The event union

- ``AGUIEvent``
- ``AGUIEventType``

### Text message events

- ``TextMessageStartEvent``
- ``TextMessageContentEvent``
- ``TextMessageEndEvent``
- ``TextMessageChunkEvent``
- ``TextMessageRole``

### Tool call events

- ``ToolCallStartEvent``
- ``ToolCallArgsEvent``
- ``ToolCallEndEvent``
- ``ToolCallChunkEvent``
- ``ToolCallResultEvent``
- ``ToolResultRole``

### Reasoning events

- ``ReasoningStartEvent``
- ``ReasoningMessageStartEvent``
- ``ReasoningMessageContentEvent``
- ``ReasoningMessageEndEvent``
- ``ReasoningMessageChunkEvent``
- ``ReasoningEndEvent``
- ``ReasoningEncryptedValueEvent``
- ``ReasoningEncryptedValueSubtype``
- ``ReasoningRole``

### State and activity events

- ``StateSnapshotEvent``
- ``StateDeltaEvent``
- ``MessagesSnapshotEvent``
- ``ActivitySnapshotEvent``
- ``ActivityDeltaEvent``

### Run lifecycle events

- ``RunStartedEvent``
- ``RunFinishedEvent``
- ``RunFinishedOutcome``
- ``RunErrorEvent``
- ``StepStartedEvent``
- ``StepFinishedEvent``

### Pass-through and extension events

- ``RawEvent``
- ``CustomEvent``

### Messages

- ``AGUIMessage``
- ``AGUIRole``
- ``DeveloperMessage``
- ``SystemMessage``
- ``AssistantMessage``
- ``UserMessage``
- ``UserMessageContent``
- ``ToolMessage``
- ``ActivityMessage``
- ``ReasoningMessage``

### Multimodal user input

- ``InputContent``
- ``InputContentSource``
- ``MediaInputContent``

### Tool calls on a message

- ``AGUIToolCall``
- ``AGUIFunctionCall``
- ``ToolCallKind``

### Starting a run

- ``RunAgentInput``
- ``AGUITool``
- ``AGUIContext``

### Interrupts and resume

- ``Interrupt``
- ``ResumeEntry``
- ``ResumeStatus``

### Agent capabilities

- ``AgentCapabilities``
- ``IdentityCapabilities``
- ``TransportCapabilities``
- ``ToolsCapabilities``
- ``OutputCapabilities``
- ``StateCapabilities``
- ``MultiAgentCapabilities``
- ``ReasoningCapabilities``
- ``MultimodalCapabilities``
- ``MultimodalInputCapabilities``
- ``MultimodalOutputCapabilities``
- ``ExecutionCapabilities``
- ``HumanInTheLoopCapabilities``
- ``SubAgentInfo``

### Errors

- ``AGUIError``
