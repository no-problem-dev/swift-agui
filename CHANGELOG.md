# Changelog

## [Unreleased]

## [0.2.1] - 2026-08-11

### Changed

- Raised the swift-structured-data pin to 3.0.0. That release makes the YAML parser reject
  constructs it does not model instead of silently dropping them; nothing in this package's own
  API changes.


## [0.2.0] - 2026-08-06

### Added

- `AGUIHTTPAgent` can now omit chosen top-level keys from the request body. `RunAgentInput`
  mirrors upstream, so it carries fields as required even when the endpoint you are talking to
  ignores them; sending `state` or `tools` on every request to a server that never reads them is
  wasted bytes. Identifiers still have to be sent — the agent does not check which keys the far
  side needs, so that judgement stays with the caller.

## [0.1.1] - 2026-07-30

### Changed

- Raised the swift-structured-data pin to 2.0.0.

## [0.1.0] - 2026-07-30

First release. A Swift client and server encoder for the AG-UI protocol, tracking the TypeScript
SDK `@ag-ui/core` 0.0.57. Unofficial, and not aiming at specification conformance.

### Added

- `AGUICore`: the event vocabulary, the message union, run input, interrupt and resume, and agent
  capabilities. An unknown event type decodes to a fallback case rather than failing the stream,
  so a producer on a different version degrades instead of crashing the consumer.
- `AGUIEncoder`: server-side SSE framing.
- `AGUIClient`: SSE parsing, chunk expansion, protocol-order verification, and a URLSession-backed
  agent.
- `AGUIJSONPatch`: RFC 6902 and RFC 6901 over `StructuredValue`, kept in its own target because it
  is an IETF specification rather than anything AG-UI specific.
- `AGUIState`: a default reducer from events to messages and state, for clients that do not want
  to write their own.
