# ``AGUIState``

A default reducer that folds a stream of events into the two things a view needs: the list of messages and the shared state.

## Overview

This target is optional. A client that already has its own way of holding a conversation
can use the transport alone and skip it; this is here so that the common case does not have
to reassemble messages from deltas by hand.

Feed events to ``AGUIClientState`` in the order they arrive. `apply(_:)` moves the state
forward and returns ``AGUIStateWarning`` values for anything recoverable rather than
throwing: content for a message id that was never started, arguments for a tool call that
does not exist, a state patch that failed, an activity patch that failed. Each of those
leaves the rest of the state intact, so one bad event does not cost you the conversation.
The single case it throws for is a `*_CHUNK` event, which means chunk expansion was skipped
upstream and the reducer is being asked to guess.

`STATE_SNAPSHOT` replaces the shared state outright — keys absent from the snapshot are
gone, because it is a replacement and never a merge. `STATE_DELTA` applies a JSON Patch,
and when the patch fails the state is left exactly as it was and you get
`statePatchFailed`. An `ACTIVITY_DELTA` naming a message id no activity has yet is a silent
no-op, following upstream, so a patch that overtakes its own snapshot is lost without a
warning; one naming a message that exists but is not an activity does warn.

Three behaviours are worth knowing because they are not obvious from the events themselves.
A tool call attaches to the assistant message its `parentMessageId` names, and a new
assistant message keyed on the tool call id is created when that names nothing or names a
message of another role. `TOOL_CALL_RESULT` is inserted directly after the assistant
message that owns the call, past any results already sitting there, rather than appended at
the end — a history where a result trails later text is rejected by some providers.
`MESSAGES_SNAPSHOT` merges rather than swaps: local messages missing from the snapshot are
dropped, except that client-only `activity` and `reasoning` messages survive a snapshot
containing none of that role at all.

`pendingInterrupts` fills when a run finishes at an interrupt and empties when one finishes
successfully. `RUN_ERROR` does not clear it, so an interrupt outlives a failed run;
persisting it across launches is the app's job.

```swift
var client = AGUIClientState()

for event in events {
    for warning in try client.apply(event) {
        print("skipped: \(warning)")
    }
}
```

## Topics

### Holding the conversation

- ``AGUIClientState``

### Diagnostics

- ``AGUIStateWarning``
