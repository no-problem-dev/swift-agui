import AGUICore

/// AG-UI エージェントへの接続。1 run の入力を渡すとイベントストリームが返る。
///
/// ミラー元: `@ag-ui/client` の `AbstractAgent.run`。API は
/// `AsyncThrowingStream` 1 本に絞る(状態保持・購読者管理は利用側の責務)。
public protocol AGUIAgent: Sendable {
    func run(_ input: RunAgentInput) -> AsyncThrowingStream<AGUIEvent, Error>
}

extension AGUIAgent {
    /// chunk 展開 → プロトコル順序検証を通した正規化ストリームを返す。
    ///
    /// パイプライン順序は上流に忠実: chunk を先に三つ組へ展開するため、
    /// 検証層は `*_CHUNK` を見ない。
    public func runVerified(_ input: RunAgentInput) -> AsyncThrowingStream<AGUIEvent, Error> {
        let upstream = run(input)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var transform = ChunkTransform()
                var verifier = EventVerifier()
                do {
                    for try await event in upstream {
                        for expanded in try transform.transform(event) {
                            try verifier.verify(expanded)
                            continuation.yield(expanded)
                        }
                    }
                    for expanded in transform.finish() {
                        try verifier.verify(expanded)
                        continuation.yield(expanded)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
