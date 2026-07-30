import Foundation
import StructuredDataCore
import Testing

@testable import AGUICore

struct MessageCodingTests {
    private func decodeMessage(_ json: String) throws -> AGUIMessage {
        try JSONDecoder().decode(AGUIMessage.self, from: Data(json.utf8))
    }

    private func roundTrip(_ message: AGUIMessage) throws -> AGUIMessage {
        let data = try JSONEncoder().encode(message)
        return try JSONDecoder().decode(AGUIMessage.self, from: data)
    }

    @Test func allRolesRoundTrip() throws {
        let messages: [AGUIMessage] = [
            .developer(DeveloperMessage(id: "d1", content: "dev")),
            .system(SystemMessage(id: "s1", content: "sys")),
            .assistant(AssistantMessage(id: "a1", content: "hi")),
            .user(UserMessage(id: "u1", content: .text("q"))),
            .tool(ToolMessage(id: "t1", content: "ok", toolCallId: "c1")),
            .activity(ActivityMessage(id: "act1", activityType: "a2ui-surface", content: .object(["status": .string("building")]))),
            .reasoning(ReasoningMessage(id: "r1", content: "考え中")),
        ]
        for message in messages {
            #expect(try roundTrip(message) == message)
        }
    }

    @Test func roleIsEncodedAsDiscriminator() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AGUIMessage.tool(ToolMessage(id: "t1", content: "ok", toolCallId: "c1")))
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""role":"tool""#))
        #expect(json.contains(#""toolCallId":"c1""#))
    }

    @Test func userContentAcceptsPlainString() throws {
        let message = try decodeMessage(#"{"role":"user","id":"u1","content":"鶏肉"}"#)
        guard case .user(let user) = message, case .text(let text) = user.content else {
            Issue.record("expected text content")
            return
        }
        #expect(text == "鶏肉")
    }

    @Test func userContentAcceptsMultimodalParts() throws {
        let json = """
        {"role":"user","id":"u1","content":[
            {"type":"text","text":"これは何?"},
            {"type":"image","source":{"type":"url","value":"https://example.com/x.jpg","mimeType":"image/jpeg"}},
            {"type":"document","source":{"type":"data","value":"QUJD","mimeType":"application/pdf"}}
        ]}
        """
        guard case .user(let user) = try decodeMessage(json), case .parts(let parts) = user.content else {
            Issue.record("expected parts content")
            return
        }
        #expect(parts.count == 3)
        #expect(parts[0] == .text("これは何?"))
        guard case .image(let media) = parts[1], case .url(let value, let mimeType) = media.source else {
            Issue.record("expected image url part")
            return
        }
        #expect(value == "https://example.com/x.jpg")
        #expect(mimeType == "image/jpeg")
    }

    @Test func unknownRoleIsRejected() throws {
        #expect(throws: DecodingError.self) {
            _ = try decodeMessage(#"{"role":"android","id":"x1","content":"hi"}"#)
        }
    }

    /// レガシー binary パートは実装しない(typed 形が正)。
    @Test func legacyBinaryPartIsRejected() throws {
        let json = """
        {"role":"user","id":"u1","content":[{"type":"binary","mimeType":"image/png","data":"QUJD"}]}
        """
        #expect(throws: DecodingError.self) {
            _ = try decodeMessage(json)
        }
    }

    @Test func assistantToolCallsRoundTrip() throws {
        let message = AGUIMessage.assistant(
            AssistantMessage(id: "a1", toolCalls: [
                AGUIToolCall(id: "c1", function: AGUIFunctionCall(name: "f", arguments: "{}")),
            ])
        )
        let decoded = try roundTrip(message)
        guard case .assistant(let assistant) = decoded else {
            Issue.record("expected assistant")
            return
        }
        #expect(assistant.content == nil)
        #expect(assistant.toolCalls?.first?.type == .function)
    }
}
