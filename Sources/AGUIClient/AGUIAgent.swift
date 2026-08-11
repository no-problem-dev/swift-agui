import AGUICore

/// Starts one run and streams back the events it produces.
///
/// Mirrors `AbstractAgent.run` in `@ag-ui/client`, narrowed to a single
/// `AsyncThrowingStream`: holding state and managing subscribers is the caller's job.
public protocol AGUIAgent: Sendable {
    func run(_ input: RunAgentInput) -> AsyncThrowingStream<AGUIEvent, Error>
}

extension AGUIAgent {
    /// Runs the stream through chunk expansion and then through protocol ordering checks.
    ///
    /// The pipeline order is faithful to upstream: chunks are expanded into their
    /// START / CONTENT / END triples first, so the verifier never sees a `*_CHUNK` event.
    /// A producer that breaks the ordering rules ends the stream by throwing `AGUIError`;
    /// events already yielded stay delivered.
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
