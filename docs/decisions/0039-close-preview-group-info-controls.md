# 0039 Close Preview group-information controls

## Status

Accepted on 2026-08-28.

## Context

The exact-conversation guard kept the legacy group-information page inside the
Development Preview, but the page still exposed provider-shaped controls. Two
notification switches changed only widget Booleans without saying that no
Stream preference was read or written. Every member row contained an enabled
empty options button, and confirming Leave merely closed a dialog while the
Preview group and membership stayed unchanged.

Those controls could be interpreted as persisted notification, moderation, or
membership changes even though `CommunicationGateway` has no such operation
and production Stream Chat remains on its official channel route.

## Decision

- Keep group information behind the existing exact Preview conversation guard.
- Label notification controls as process-local layout state. They make no
  persistence, delivery, read, or Stream-setting claim.
- Turning off the parent notification example clears the dependent
  mentions-only example, so the visible local state remains internally
  consistent.
- Remove enabled member-option placeholders. Member rows state that no member
  action is available.
- Keep Leave disabled until an official Stream-owned membership mutation and
  its outcome semantics are connected. Closing a dialog or showing a snackbar
  cannot substitute for that mutation.
- Preserve the working exact-scope search, labelled member-list layout, and
  production Stream CID path unchanged.

## Consequences

The Preview still demonstrates group information and dependent preference UI,
but every enabled control now has an exact visible local effect. It does not
add persistence, a second Chat state machine, Stream writes, moderation,
membership state, a backend route, or a provider request.

## Evidence

`test/chat_preview_conversation_identity_test.dart` verifies the process-local
labels and dependent switch transition, the absence of member action buttons,
the disabled Leave action, and the existing exact conversation/search scope.
The repository Harness fingerprints the reviewed page, its separate member-list
sheet, and executable evidence. It mutates the truth labels, dependent reset,
member actions on both surfaces, and Leave action.
