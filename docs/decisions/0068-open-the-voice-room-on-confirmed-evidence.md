# 0068 · The voice room opens on confirmed evidence

## Status

Accepted 2026-09-10. Extends decision 0005 (the `voiceRooms` provider-evidence
gate) and decision 0055 (the community-scoped Audio Room). It consumes one
additive change to `GET /v2/meta/capabilities`; no other contract, request,
route or state machine moves.

## Context

Decision 0005 closed `voiceroom` and `voiceroom-full` behind a provider-evidence
precondition: LOOP may connect a member to a Stream Audio Room only after an
operator has proved that Stream's `user` role on `audio_room` cannot *create* a
call, because a client that can create one can also create a room LOOP never
authorized. Until that proof exists the whole page renders one explanation and
issues no request at all.

`evidence.status` had exactly two values, `notApplicable` and `pending`, and
`voiceRooms` was the only capability that ever published `pending`. That is a
gate with no way out: the operator could satisfy the precondition, and the
document had no way to say so. The page stayed closed on a fact that was no
longer true.

## Contract facts this rests on

| Fact | Value |
| ---- | ----- |
| Resource | `GET /v2/meta/capabilities` (public, credential-free) |
| New `evidence.status` value | `confirmed`, beside `notApplicable` and `pending` |
| New key | `evidence.reference`, a 1–120 character operational string |
| When the key is present | `confirmed` only, where it is **required** |
| When the key is absent | every other status — absent, never `null` |
| `evidence.reasonCode` when confirmed | `null` |
| Which capability may publish it | `voiceRooms` alone, once the operator sets `STREAM_AUDIO_ROOM_USER_ROLE_EVIDENCE_REF` |

## Decision

`confirmed` is the operator's recorded answer to the decision-0005
precondition, and `reference` is the record.

- `LoopV2CapabilityEvidenceStatus` gains `confirmed`.
  `LoopV2CapabilityEvidence` gains a nullable `reference`.
- Parsing is strict in both directions, because the two halves are one fact.
  A `confirmed` without a `reference` is refused rather than read as an
  unreferenced confirmation; a `reference` published beside `pending` or
  `notApplicable` describes a confirmation the same document denies and is
  refused too. An explicit `null`, an empty string, and a string over 120
  characters are all invalid payloads.
- Only `voiceRooms` may carry the key. Since the reference is mandatory with
  `confirmed`, that also refuses `confirmed` on any other capability — which is
  the intended reading: no other capability has this precondition, so no other
  capability can have met it. `evidence.launchChainId` (decision 0038) is
  untouched and keeps its own `launch`-only rule.
- `LoopCapabilityProjection.evidencePending` is now written as an exhaustive
  switch: `pending` is the only status that closes a surface, and
  `notApplicable` and `confirmed` both leave the page to its own five states.
  A status added to the contract later has to be classified here rather than
  defaulting to "open".
- `voiceroom` and `voiceroom-full` therefore lose the whole-page
  `voiceroom-evidence-pending` block once the evidence reads `confirmed`, and
  run the ordinary five-state read they were always written for.

Nothing else about the page changes. Confirmed evidence opens the gate; it does
not authorize a room. The locator contract of decision 0055 is untouched: the
room must already exist on the server, it is handed to the reviewed lobby as a
constructor argument rather than through a scoped provider, and the viewer's
role, speaking rights and mute state still come only from Stream's official
`CallState`. An `unavailable` or `deferred` `voiceRooms` capability still closes
the page ahead of the evidence, and Preview mode still ignores the evidence
entirely.

`reference` is an operator's audit string, not product copy. It is parsed and
validated so a malformed document is caught, and no surface renders it. No
colour, type size or component is added anywhere.

`/v2/security/capabilities` is a different document with its own six Privy ids,
all permanently `unavailable` with `pending` evidence. Its parser still accepts
`pending` alone; widening it would claim a device-verified Privy feature that
has none.

## Consequences

- A backend that has not set `STREAM_AUDIO_ROOM_USER_ROLE_EVIDENCE_REF` parses
  and renders exactly as it did before: `voiceRooms` reads `pending`, the page
  stays closed and issues no request.
- Once the operator sets it, the page opens without a client release. The
  capability document is already re-armed after a failed read (decision 0064),
  so an app that started before the change picks it up on its next successful
  observation.
- The evidence status is not a connection, a Stream token, a membership or a
  device verification. A confirmed precondition still leads to the same
  five-state read against the same server resources, and a room that does not
  exist still renders the server's own `COMMUNITY_VOICE_ROOM_NOT_LIVE`.
- `AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING` copy stays in
  `communicationUnavailableReason`: it is still the right sentence while the
  status is `pending`.

## Evidence

`test/s15_voice_room_evidence_test.dart` covers the parse in both directions —
confirmed with a reference, confirmed without one, a reference beside `pending`
and beside `notApplicable`, a reference on another capability, a confirmed
evidence that also names a reason, the empty / 120 / 121 character boundaries,
an explicit `null`, and an unknown status — plus the untouched document, the
other 30 capabilities keeping their evidence, and the page itself: the pending
block gone, loading, empty, offline, permission and error, the pre-created room
reaching the lobby unchanged, a listener still getting member controls only,
and an `unavailable` capability still closing the page before any read.
`test/communication_pages_test.dart` keeps the `pending` page.
