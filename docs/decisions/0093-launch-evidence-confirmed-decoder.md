# 0093 · The capability decoder accepts a confirmed launch evidence

## Status

Accepted 2026-09-27. Consumes loop-api decision 0083. Extends 0068 (the
`reference` rule for `voiceRooms`) and 0038 (`launchChainId`).

## Context

loop-api 0083 made the `launch` capability's evidence follow the contract
adapter: once the four `LAUNCH_*` keys are set and the contract code was
observed, the API publishes `{status: "confirmed", reasonCode:
"LAUNCH_CONTRACT_CONFIRMED", launchChainId?, launchContractVersion?}`.

The decoder written for 0068 refused every part of that: `confirmed` had to
carry a null `reasonCode`, a `reference`, and was only admitted on
`voiceRooms`; `launchContractVersion` was an unknown key. The whole
capabilities document was rejected, and the app rendered its bootstrap failure
as 「连不上 LOOP」 on the device round of 2026-09-27 even though every request
had returned 200.

## Decision

1. On `launch`, `confirmed` **requires** a non-null `reasonCode` and refuses a
   `reference`; on every other capability the 0068 rule is unchanged
   (`confirmed` only on `voiceRooms`, with a reference and no reason code).
2. `launchContractVersion` is read on `launch` alone and only while `confirmed`:
   a semver string of at most 32 characters. Anywhere else, or malformed, the
   document is an invalid payload.
3. The projection is unchanged: `confirmed` is not pending, so the Launch
   surfaces open on the adapter's word.

## Lesson

An "optional" field added on the backend is still a wire change for a strict
decoder. Every backend addition needs its client counterpart in the same
batch, or the app fails closed as a whole.
