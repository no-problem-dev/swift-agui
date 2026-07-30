import AGUICore
import Foundation
import StructuredDataCore

/// interrupt / resume の契約バリデーション。
///
/// ミラー元: `@ag-ui/client` `interrupts/index.ts` と `AbstractAgent.onInitialize`。
/// 契約(仕様の MUST):
/// - 部分 resume は不可 — 1 つの resume 配列が開いている全 interrupt を網羅する
/// - 未知の interrupt id への応答は不正
/// - 期限切れ(`expiresAt` 超過)の interrupt へ resume を送ってはならない
public enum InterruptResume {
    /// 次の run を送る前の事前検証。
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

    /// interrupt id → 応答 payload の対応から resume 配列を構築する
    /// (全網羅・未知 id 拒否を検証済みの状態で返す)。
    ///
    /// - Parameter responses: 応答。値が nil のエントリは `.cancelled` になる。
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
