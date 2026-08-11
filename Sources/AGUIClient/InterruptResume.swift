import AGUICore
import Foundation
import StructuredDataCore

/// Contract checks for the interrupt / resume handshake, run before the next run is sent.
///
/// Mirrors `interrupts/index.ts` and `AbstractAgent.onInitialize` in `@ag-ui/client`.
/// The contract, all MUSTs in the spec:
/// - No partial resume — one resume array covers every open interrupt
/// - Answering an interrupt id that is not open is invalid
/// - No resume may be sent for an interrupt whose `expiresAt` has passed
public enum InterruptResume {
    /// Throws unless the resume array answers exactly the open interrupts, none expired.
    ///
    /// - Note: An `expiresAt` that does not parse as ISO-8601 counts as no expiry at all,
    ///   so a malformed timestamp lets the resume through.
    public static func validate(
        pending: [Interrupt],
        resume: [ResumeEntry],
        now: Date = Date()
    ) throws {
        let pendingIds = Set(pending.map(\.id))
        let resumeIds = Set(resume.map(\.interruptId))

        let unaddressed = pendingIds.subtracting(resumeIds)
        guard unaddressed.isEmpty else {
            throw AGUIError(
                "Thread has \(unaddressed.count) pending interrupt(s) not addressed by resume: \(unaddressed.sorted().joined(separator: ", "))"
            )
        }
        let unknown = resumeIds.subtracting(pendingIds)
        guard unknown.isEmpty else {
            throw AGUIError(
                "Resume references unknown interrupt id(s): \(unknown.sorted().joined(separator: ", "))"
            )
        }
        for interrupt in pending {
            if let expiresAt = interrupt.expiresAt,
               let expiry = parseISO8601(expiresAt),
               expiry <= now {
                throw AGUIError("Interrupt \(interrupt.id) expired at \(expiresAt)")
            }
        }
    }

    /// Builds the resume array that answers every open interrupt, resolved or cancelled.
    ///
    /// The result comes back already validated: it covers all of them and names no
    /// unknown id.
    ///
    /// - Parameters:
    ///   - interrupts: The interrupts open on the thread; the result answers all of them.
    ///   - responses: Payloads keyed by interrupt id. An id that is absent, or present
    ///     with a nil value, becomes `.cancelled`.
    ///   - now: Clock the expiry check reads, injectable for tests.
    public static func buildResumeArray(
        interrupts: [Interrupt],
        responses: [String: StructuredValue?],
        now: Date = Date()
    ) throws -> [ResumeEntry] {
        let resume = interrupts.map { interrupt in
            if let payload = responses[interrupt.id], let payload {
                ResumeEntry(interruptId: interrupt.id, status: .resolved, payload: payload)
            } else {
                ResumeEntry(interruptId: interrupt.id, status: .cancelled)
            }
        }
        let interruptIds = Set(interrupts.map(\.id))
        let unknown = Set(responses.keys).subtracting(interruptIds)
        guard unknown.isEmpty else {
            throw AGUIError(
                "Responses reference unknown interrupt id(s): \(unknown.sorted().joined(separator: ", "))"
            )
        }
        try validate(pending: interrupts, resume: resume, now: now)
        return resume
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
