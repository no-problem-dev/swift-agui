// swift-tools-version: 6.2
import PackageDescription

// AG-UI (Agent-User Interaction Protocol) の Swift 実装。
// 準拠上流: ag-ui-protocol/ag-ui の TypeScript SDK 0.0.57。
// 「仕様の完全ミラー」と「仕様外の独自部分」をターゲット境界で分離する
// (swift-a2ui と同じ流儀)。各ターゲット冒頭コメントにミラー元を明記する。
let package = Package(
    name: "swift-agui",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AGUICore", targets: ["AGUICore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.3.0"),
    ],
    targets: [
        // @ag-ui/core 0.0.57 のミラー: イベント語彙(34種)・Message union・
        // RunAgentInput・Interrupt/Resume・AgentCapabilities。
        // `state` / `forwardedProps` 等の any 相当は StructuredValue で表現する。
        .target(name: "AGUICore", dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
        ]),
        .testTarget(name: "AGUICoreTests", dependencies: ["AGUICore"]),
    ]
)
