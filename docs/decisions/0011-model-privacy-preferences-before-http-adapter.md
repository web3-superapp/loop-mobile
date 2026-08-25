# Model Privacy Preferences Before Its HTTP Adapter

## Status

Accepted on 2026-08-25.

## Context

The backend now owns an authenticated, owner-scoped Privacy resource, but this
Flutter phase intentionally completes application logic before adding another
private HTTP adapter. The existing H3 Privacy Center used widget-local switches
for anonymous Alias, portfolio broadcast, group allowlists, activity visibility,
and position visibility. None of those values exist in the reviewed backend
contract, and their local changes could be mistaken for durable account state.

The H4 Copy-trade permissions surface also offered audience, amount, drawdown,
and save controls even though no copy authorization or execution contract
exists. The backend explicitly states that copy-trade visibility is a
presentation preference only.

## Decision

- Model exactly two Privacy values: `discoverable` and
  `copyTradeVisibility`, whose only values are `private`, `followers`, and
  `public`.
- Preserve the backend's fail-closed version-zero defaults:
  `discoverable=false`, `copyTradeVisibility=private`, and no update time.
  Versions stay within `0..2147483647`, and version zero is equivalent to a
  null update time.
- Treat Privacy updates as complete replacements using the committed expected
  version. A stale identical retry converges on the current resource; a stale
  different write freezes the draft until an explicit reload. Load and apply
  operations are single-flight, and gateway rotation retires late work from the
  previous owner.
- Keep `privacyGatewayProvider` directly bound to
  `UnavailablePrivacyGateway` in production. Only tests and
  `lib/main_preview.dart` may compose `MemoryPrivacyGateway`, and Preview must
  remain visibly labelled `开发预览`.
- Do not add Dio, a `/v1/profile/privacy` route literal, bearer handling, owner
  IDs, or HTTP error parsing to `lib/features/`. A later authenticated adapter
  may implement the existing narrow gateway without changing the controller or
  UI state model.
- Replace the unsupported H3 controls with the exact two-field editor. The UI
  describes both values as preferences and does not claim that public discovery,
  followers, portfolio sharing, wallet visibility, or copy trading is active.
- Replace H4's fake permission form with a non-actionable explanation until a
  separately reviewed authorization and execution contract exists.
- Accept a committed change only from a matching returned resource whose
  version advances. Do not use SnackBars or positive success copy as evidence.

## Consequences

The frontend can finish deterministic Privacy editing, conflict recovery,
responsive UI, and account-rotation behavior while backend and adapter work
continue independently. Production remains honestly unavailable and makes no
request. Preview proves only in-process application behavior.

This decision does not implement public profile discovery, a follower graph,
copy-trade authorization, risk limits, order execution, Firebase delivery,
account export/deletion, or an authenticated Privacy transport. No failure
memory is added because the removed controls were inherited prototype fixtures,
not a reproduced production incident; executable Harness mutations now prevent
their return.
