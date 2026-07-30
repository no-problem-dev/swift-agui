import AGUICore
import Foundation
import StructuredDataCore
import Testing

@testable import AGUIClient

struct InterruptResumeTests {
    private let pending = [
        Interrupt(id: "i1", reason: Interrupt.Reason.inputRequired, message: "どの食材?"),
        Interrupt(id: "i2", reason: Interrupt.Reason.confirmation),
    ]

    @Test func fullResumePasses() throws {
        try InterruptResume.validate(pending: pending, resume: [
            ResumeEntry(interruptId: "i1", status: .resolved, payload: .object(["answer": .string("鶏もも")])),
            ResumeEntry(interruptId: "i2", status: .cancelled),
        ])
    }

    /// 部分 resume は不可 — 全 interrupt を網羅すること。
    @Test func partialResumeRejected() {
        #expect(throws: AGUIError.self) {
            try InterruptResume.validate(pending: pending, resume: [
                ResumeEntry(interruptId: "i1", status: .resolved),
            ])
        }
    }

    @Test func unknownInterruptIdRejected() {
        #expect(throws: AGUIError.self) {
            try InterruptResume.validate(pending: pending, resume: [
                ResumeEntry(interruptId: "i1", status: .resolved),
                ResumeEntry(interruptId: "i2", status: .cancelled),
                ResumeEntry(interruptId: "ghost", status: .resolved),
            ])
        }
    }

    @Test func expiredInterruptRejected() {
        let expired = [Interrupt(id: "i1", reason: "confirmation", expiresAt: "2020-01-01T00:00:00Z")]
        #expect(throws: AGUIError.self) {
            try InterruptResume.validate(
                pending: expired,
                resume: [ResumeEntry(interruptId: "i1", status: .resolved)]
            )
        }
    }

    @Test func buildResumeArrayMapsResponsesAndCancellations() throws {
        let resume = try InterruptResume.buildResumeArray(
            interrupts: pending,
            responses: ["i1": .object(["approved": .bool(false)])]
        )
        #expect(resume == [
            ResumeEntry(interruptId: "i1", status: .resolved, payload: .object(["approved": .bool(false)])),
            ResumeEntry(interruptId: "i2", status: .cancelled),
        ])
    }

    @Test func buildResumeArrayRejectsUnknownResponseIds() {
        #expect(throws: AGUIError.self) {
            _ = try InterruptResume.buildResumeArray(
                interrupts: pending,
                responses: ["ghost": .bool(true)]
            )
        }
    }
}
