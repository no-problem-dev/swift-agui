// swift-tools-version: 6.2
import PackageDescription

// Swift implementation of AG-UI (Agent-User Interaction Protocol).
// Upstream tracked: the TypeScript SDK 0.0.57 of ag-ui-protocol/ag-ui.
// Target boundaries keep "faithful mirror of the spec" apart from "outside the spec"
// (the same style as swift-a2ui). Each target's leading comment names what it mirrors.
let package = Package(
    name: "swift-agui",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AGUICore", targets: ["AGUICore"]),
        .library(name: "AGUIEncoder", targets: ["AGUIEncoder"]),
        .library(name: "AGUIClient", targets: ["AGUIClient"]),
        .library(name: "AGUIJSONPatch", targets: ["AGUIJSONPatch"]),
        .library(name: "AGUIState", targets: ["AGUIState"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "3.0.0"),
    ],
    targets: [
        // Mirrors @ag-ui/core 0.0.57: the event vocabulary (28 kinds + unknown), the
        // Message union, RunAgentInput, Interrupt/Resume and AgentCapabilities.
        // Fields typed `any` upstream (`state`, `forwardedProps`, ...) become StructuredValue.
        .target(name: "AGUICore", dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
        .testTarget(name: "AGUICoreTests", dependencies: ["AGUICore"]),

        // Mirrors @ag-ui/encoder: server-side SSE event framing (`data: {json}\n\n`).
        // The protobuf transport is not implemented; SSE alone carries the whole protocol.
        .target(name: "AGUIEncoder", dependencies: ["AGUICore"]),
        .testTarget(name: "AGUIEncoderTests", dependencies: ["AGUIEncoder"]),

        // Mirrors the transport and verification halves of @ag-ui/client: SSE parser,
        // chunk expansion, protocol ordering checks, interrupt validator and a
        // URLSession-backed HTTP agent.
        // The apply layer (messages/state reducers) lives in AGUIState instead.
        .target(name: "AGUIClient", dependencies: ["AGUICore"]),
        .testTarget(name: "AGUIClientTests", dependencies: ["AGUIClient", "AGUIEncoder"]),

        // Outside the spec: RFC 6902 (JSON Patch) and RFC 6901 (JSON Pointer) over
        // StructuredValue. Its own target because those are IETF specs with nothing
        // AG-UI specific about them. AGUIState uses it to apply STATE_DELTA / ACTIVITY_DELTA.
        .target(name: "AGUIJSONPatch", dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
        .testTarget(name: "AGUIJSONPatchTests", dependencies: ["AGUIJSONPatch"]),

        // Mirrors the apply layer of @ag-ui/client: the default reducer that folds events
        // into messages / state. Optional — a client with its own reducer needs
        // nothing beyond AGUIClient.
        .target(name: "AGUIState", dependencies: ["AGUICore", "AGUIJSONPatch"]),
        .testTarget(name: "AGUIStateTests", dependencies: ["AGUIState"]),
    ]
)
