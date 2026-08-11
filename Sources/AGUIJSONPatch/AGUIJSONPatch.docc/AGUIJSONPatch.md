# ``AGUIJSONPatch``

RFC 6902 JSON Patch and RFC 6901 JSON Pointer over `StructuredValue`, so a delta on the wire can be turned into the next document.

## Overview

Nothing in this target is AG-UI specific. It is here as its own library because those are
IETF specifications with their own rules, and because the state layer needs them to apply
`STATE_DELTA` and `ACTIVITY_DELTA` — but you can depend on it alone.

All six operations are implemented: `add`, `remove`, `replace`, `move`, `copy` and `test`.
Applying an array of them is atomic, which falls out of these being value types: if any
operation fails you get a ``JSONPatchError`` and the document you passed in is untouched,
so a half-applied patch is not a state you can reach.

A pointer that does not resolve is an error rather than a no-op, which is the main thing to
plan for. Adding under a parent that does not exist, removing a key that is not there, an
array index past the end, and any token that walks into a scalar all throw. `test` compares
by value and throws when it differs, which is how you make a patch conditional. Array
indices follow RFC 6901: `-` means the position after the last element and is accepted only
by `add`, and a leading zero is rejected. `move` refuses a `from` that is a proper prefix of
`path`, since moving a value into its own subtree has no meaning, and `remove` refuses the
whole-document pointer.

Deltas arriving on the wire are untyped values, so `JSONPatch.apply(raw:to:)` takes them
as they come and decodes each operation on the way; an entry missing `op` or `path`, or
naming an operation that does not exist, throws before anything is applied.

``JSONPointer`` parses the string form: an empty string is the whole document, anything
else must start with `/`, and the escapes `~1` and `~0` unescape to `/` and `~`. Its
`description` writes the pointer back out with those escapes restored.

```swift
let updated = try JSONPatch.apply(
    [JSONPatchOperation(op: .replace, path: "/user/name", value: .string("Ada"))],
    to: document
)
```

## Topics

### Applying a patch

- ``JSONPatch``
- ``JSONPatchOperation``

### Addressing part of a document

- ``JSONPointer``

### Errors

- ``JSONPatchError``
