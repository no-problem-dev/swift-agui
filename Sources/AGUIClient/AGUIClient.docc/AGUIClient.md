# ``AGUIClient``

The receiving half: run an agent over HTTP, read its server-sent events as typed values, and find out when the producer breaks the protocol instead of rendering the result of it.

## Overview

``AGUIHTTPAgent`` posts a `RunAgentInput` as JSON with `Accept: text/event-stream` and
yields events as they arrive. A non-2xx response throws ``AGUIHTTPError`` before any event
is parsed, carrying up to 1 MiB of the body for diagnosis and silently cutting off past
that. A response whose content type is exactly the binary protocol's is refused, because
that transport is not implemented; anything else is parsed as SSE whatever the content
type claims, which is what makes servers with a careless content type work. Cancelling the
task is not an error — the stream yields a `RUN_ERROR` event with code `abort` and then
finishes normally, so a cancelled run and a failed one do not look alike.

`run(_:)` hands you exactly what the producer sent. `runVerified(_:)` puts two stages in
front of it, in that order. ``ChunkTransform`` expands the `*_CHUNK` shorthands back into
their START / CONTENT / END triples, closing an open message implicitly when the id
changes, when a non-chunk event arrives, or at the end of the stream; the first chunk of a
run must carry `messageId`, or for a tool call both `toolCallId` and `toolCallName`, and an
`AGUIError` ends the stream if it does not. `RAW`, the activity events and
`REASONING_ENCRYPTED_VALUE` pass through without closing anything.

``EventVerifier`` then checks ordering. The first event must be `RUN_STARTED` or
`RUN_ERROR`. Content cannot arrive for a message or tool call that was never started, or
for one already ended. `RUN_FINISHED` is rejected while a text message, tool call,
reasoning message or step is still open. Nothing may follow `RUN_ERROR`, and only a fresh
`RUN_STARTED` may follow `RUN_FINISHED`, which starts a new run on the same stream. When a
producer violates any of this the consumer sees the stream throw an `AGUIError` and end;
events already delivered stay delivered, so a view keeps what it had rather than emptying.
`TOOL_CALL_RESULT`, the state, messages-snapshot, activity, raw, custom and unmodelled
events are not order-checked.

``SSEEventParser`` is usable on its own when the bytes come from somewhere else. It reads
`data:` lines only, joins several within one event with a newline, and ignores `event:`,
`id:`, `retry:` and comment lines — which is how `: ping` keep-alives disappear. Boundaries
are found byte by byte, so a multi-byte character split across two reads survives. One
unterminated event is capped at 8 MiB; past that it throws `AGUIError`, and since the
oversized buffer is kept, every later call throws too. A producer that never sends the
blank line therefore ends the stream instead of growing memory without limit.

``InterruptResume`` validates the answer to a run that stopped for a person before you send
the next one: every open interrupt must be addressed, unknown ids are rejected, and an
interrupt whose `expiresAt` has passed cannot be resumed.

```swift
let agent = AGUIHTTPAgent(url: endpoint)

for try await event in agent.runVerified(input) {
    if case .textMessageContent(let content) = event {
        print(content.delta, terminator: "")
    }
}
```

## Topics

### Running an agent

- ``AGUIAgent``
- ``AGUIHTTPAgent``

### Reading and checking the stream

- ``SSEEventParser``
- ``ChunkTransform``
- ``EventVerifier``

### Answering interrupts

- ``InterruptResume``

### Errors

- ``AGUIHTTPError``
