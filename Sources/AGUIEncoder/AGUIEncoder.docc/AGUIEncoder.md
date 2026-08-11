# ``AGUIEncoder``

Server-side framing: turn an AG-UI event into the bytes of a server-sent events response.

## Overview

This is the whole server side of the wire, and the only target a Swift backend needs. A
client app never builds it.

``EventEncoder`` writes one event as `data: {json}\n\n`. The SSE `event:` field is not
used, because the kind of an event is the `type` inside the JSON body, and a consumer that
switched on the SSE field would see nothing. Slashes are left unescaped, so a URL in a
payload stays readable in a log. `encodeSSE(_:)` gives you the frame as a `String` and
`encodeBinary(_:)` gives you its UTF-8 bytes for writing straight to the response body.

Long gaps between events are the practical problem with SSE: proxies and load balancers
drop an idle connection. `EventEncoder.keepAlive` is an SSE comment line to write during
those gaps — clients ignore comment lines, and this package's parser discards them without
producing an event.

``AGUIMediaType`` holds the two media types the protocol uses. The binary protobuf
transport is not implemented, and its type is here only so either end can recognise it and
refuse rather than trying to parse it as text.

Send events in an order a consumer can verify: `RUN_STARTED` first, every text message,
tool call, reasoning message and step closed before `RUN_FINISHED`, and nothing at all
after `RUN_ERROR`. A client using `runVerified(_:)` ends the stream with an error when a
producer does otherwise.

```swift
let encoder = EventEncoder()
let frame = try encoder.encodeSSE(
    .runStarted(RunStartedEvent(threadId: threadId, runId: runId))
)
```

## Topics

### Encoding events

- ``EventEncoder``

### Media types

- ``AGUIMediaType``
