# swift-agui

Swift implementation of the [AG-UI (Agent-User Interaction) Protocol](https://github.com/ag-ui-protocol/ag-ui).

AG-UI is an open, event-based protocol that standardizes how AI agents connect to
user-facing applications: streaming text, tool calls, shared state, generative UI
(e.g. [A2UI](https://github.com/google/A2UI) carried over `ACTIVITY_SNAPSHOT`),
and human-in-the-loop interrupts — over plain HTTP + SSE.

- Tracks the TypeScript SDK **`@ag-ui/core` 0.0.57** (the protocol's canonical implementation)
- Platforms: iOS 17+ / macOS 14+
- Swift 6, strict concurrency

## Products

Spec mirrors (each target documents which upstream package it mirrors):

| Product | Mirrors | Contents |
|---|---|---|
| `AGUICore` | `@ag-ui/core` | Event vocabulary, `AGUIMessage` union, `RunAgentInput`, interrupts/resume, `AgentCapabilities` |
| `AGUIEncoder` | `@ag-ui/encoder` | SSE event framing for servers |
| `AGUIClient` | `@ag-ui/client` (transport + verify) | SSE parsing, chunk expansion, protocol-order verification, HTTP agent |
| `AGUIState` | `@ag-ui/client` (apply layer) | Default messages/state reducer |

Non-spec targets (kept deliberately separate):

| Product | Contents |
|---|---|
| `AGUIJSONPatch` | RFC 6902 / RFC 6901 over `StructuredValue` (used by `STATE_DELTA` / `ACTIVITY_DELTA`) |

## Design notes

- **No legacy compatibility.** Upstream-deprecated forms (`THINKING_*` events, the
  legacy `binary` input content) are not implemented. Unknown event types decode to
  `.unknown(type:raw:)` instead of failing, so streams from older producers degrade
  gracefully rather than crash.
- **Null is accepted as omission** where other-language producers are known to emit
  `null` (`parentMessageId`, `outcome`), per upstream core's own lenient schemas.
- JSON "any" values (`state`, `forwardedProps`, `CUSTOM.value`, …) are represented as
  [`StructuredValue`](https://github.com/no-problem-dev/swift-structured-data).

## Usage

```swift
import AGUICore

let input = RunAgentInput(
    threadId: threadId,
    runId: UUID().uuidString,
    messages: [.user(UserMessage(id: UUID().uuidString, content: .text("Hello")))],
    tools: [],
    context: []
)
```

See DocC documentation for the full API.

## License

MIT
