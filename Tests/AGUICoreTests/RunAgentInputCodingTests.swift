import Foundation
import StructuredDataCore
import Testing

@testable import AGUICore

struct RunAgentInputCodingTests {
    @Test func requiredArraysAreAlwaysEncoded() throws {
        let input = RunAgentInput(threadId: "t1", runId: "r1")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(input), as: UTF8.self)
        // messages / tools / context / state / forwardedProps are never omitted, even empty
        #expect(json.contains(#""messages":[]"#))
        #expect(json.contains(#""tools":[]"#))
        #expect(json.contains(#""context":[]"#))
        #expect(json.contains(#""state":{}"#))
        #expect(json.contains(#""forwardedProps":{}"#))
        // resume is written only when it was set explicitly
        #expect(!json.contains("resume"))
    }

    @Test func fullInputRoundTrip() throws {
        let input = RunAgentInput(
            threadId: "t1",
            runId: "r2",
            parentRunId: "r1",
            state: .object(["mode": .string("cooking")]),
            messages: [.user(UserMessage(id: "u1", content: .text("鶏肉のレシピ")))],
            tools: [
                AGUITool(
                    name: "search_recipes",
                    description: "レシピ検索",
                    parameters: .object(["type": .string("object")])
                ),
            ],
            context: [AGUIContext(description: "A2UI Component Schema", value: "{}")],
            forwardedProps: .object(["delishApiToken": .string("tok")]),
            resume: [ResumeEntry(interruptId: "i1", status: .resolved, payload: .object(["answer": .string("鶏もも")]))]
        )
        let data = try JSONEncoder().encode(input)
        let decoded = try JSONDecoder().decode(RunAgentInput.self, from: data)
        #expect(decoded == input)
    }

    @Test func resumeStatusVocabulary() throws {
        let cancelled = ResumeEntry(interruptId: "i1", status: .cancelled)
        let data = try JSONEncoder().encode(cancelled)
        #expect(String(decoding: data, as: UTF8.self).contains(#""status":"cancelled""#))
    }

    @Test func capabilitiesRoundTrip() throws {
        let capabilities = AgentCapabilities(
            identity: IdentityCapabilities(name: "delish-agent", version: "1.0.0"),
            transport: TransportCapabilities(streaming: true),
            tools: ToolsCapabilities(supported: true, clientProvided: true),
            humanInTheLoop: HumanInTheLoopCapabilities(supported: true, interrupts: true),
            custom: .object(["delish": .object(["models": .array([])])])
        )
        let data = try JSONEncoder().encode(capabilities)
        let decoded = try JSONDecoder().decode(AgentCapabilities.self, from: data)
        #expect(decoded == capabilities)
        // omitted means undeclared: a category left unset produces no key at all
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("multimodal"))
        #expect(!json.contains("execution"))
    }
}
