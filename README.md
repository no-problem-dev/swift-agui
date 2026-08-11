# swift-agui

Connect a Swift app to an AI agent backend that speaks AG-UI, so the agent's replies, tool calls and shared state show up while it is still working instead of after it finishes.

> **Unofficial.** Not affiliated with or endorsed by the authors of the AG-UI Protocol. Conforming to the specification is not a goal of this project.

## Overview

[AG-UI](https://github.com/ag-ui-protocol/ag-ui) is an open, event-based protocol for the
wire between an AI agent and the app a person is looking at: streaming text, tool calls,
shared state, generative UI (for example [A2UI](https://github.com/google/A2UI) carried
over `ACTIVITY_SNAPSHOT`), and human-in-the-loop interrupts — over plain HTTP and
server-sent events.

Both ends are here. On the client you get a typed event stream to drive a view from, plus
a verifier that catches a producer emitting events out of order. On the server you get the
encoder that frames events for the wire. State arrives as JSON Patch and can be applied for
you, so a view can bind to the agent's state rather than reassembling it.

An unknown event type decodes to a fallback case instead of throwing, so a stream from a
newer or older producer degrades rather than crashing. Upstream-deprecated forms are not
implemented.

Requires iOS 17 / macOS 14 and Swift 6 with strict concurrency. Tracks the TypeScript SDK
`@ag-ui/core` 0.0.57.

## Usage

```swift
import AGUICore
import AGUIClient

let agent = AGUIHTTPAgent(url: endpoint)

let input = RunAgentInput(
    threadId: threadId,
    runId: UUID().uuidString,
    messages: [.user(UserMessage(id: UUID().uuidString, content: .text("Hello")))],
    tools: [],
    context: []
)

for try await event in agent.run(input) {
    if case .textMessageContent(let chunk) = event {
        print(chunk.delta, terminator: "")
    }
}
```

Use `runVerified(_:)` instead of `run(_:)` to have protocol ordering checked as the stream
arrives; a producer that breaks the ordering rules then surfaces as a thrown error rather
than as a view that quietly renders the wrong thing.

## Documentation

[API documentation](https://no-problem-dev.github.io/swift-agui/documentation/aguicore/)

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-agui.git", .upToNextMinor(from: "0.2.0"))
]
```

The libraries ship separately, so a client app never builds the server-side encoder:

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "AGUICore", package: "swift-agui"),      // events, messages, run input
    .product(name: "AGUIClient", package: "swift-agui"),    // SSE parsing, verification, HTTP agent
    .product(name: "AGUIState", package: "swift-agui"),     // default messages/state reducer
    .product(name: "AGUIEncoder", package: "swift-agui"),   // SSE framing, for servers
    .product(name: "AGUIJSONPatch", package: "swift-agui"), // RFC 6902 / RFC 6901
])
```

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

MIT. See [LICENSE](./LICENSE).
