# Model Watchlist Before Its HTTP Adapter

## Status

Accepted on 2026-08-25.

## Context

The LOOP backend already fixes the authenticated owner's Watchlist as one
versioned, grouped, ordered snapshot. Replacements use optimistic concurrency,
and asset keys are preferences rather than market facts or proof of
tradability. The Flutter Watchlist route is still a read-only visual fixture:
it cannot model edits, dirty state, concurrent saves, conflicts, or an
unavailable production service.

Decision 0008 requires application behavior to be completed behind narrow
ports before new private transports. Connecting the route directly to Dio now
would mix draft semantics with authentication and wire parsing, while leaving
the conflict behavior hard to verify independently.

## Decision

- Add immutable Watchlist snapshot, group, and item models that preserve the
  backend's current limits and validation rules: at most 20 groups and 100
  items, canonical group and asset keys, unique group keys, unique assets per
  group, bounded display names, and the version/timestamp invariant.
- Add a feature-owned `WatchlistGateway` port and Riverpod controller. The
  controller owns load, draft edits, order, dirty state, one in-flight save,
  explicit discard/reload, sanitized failure, and version-conflict behavior.
- Every save sends the committed snapshot version as `expectedVersion` and the
  complete draft. A conflict never overwrites either the remote resource or the
  local draft and requires an explicit reload before another save.
- Keep the production gateway directly unavailable. Do not add Dio, bearer
  handling, backend route literals, retry policy, or wire DTO parsing in this
  slice.
- Inject a deterministic memory implementation only from tests and
  `lib/main_preview.dart`. Preview content and successful preview saves remain
  visibly labelled `开发预览`; they are not account persistence evidence.
- Watchlist items contain only owner-local asset keys. Market names, prices,
  changes, provider freshness, tradability, alert state, and order actions do
  not enter the Watchlist model or gateway.

## Consequences

The app can fully exercise grouped Watchlist editing, validation, ordering,
save state, retry, discard, and conflict recovery without waiting for a
deployed API. Production remains truthfully unavailable until a later
integration adapter is implemented and verified against the authenticated
backend contract.

The future adapter must translate the existing HTTP contract behind the same
port, preserve exact optimistic-concurrency semantics, and add wire-contract
tests without changing the feature state machine. Account rotation and
authenticated transport ownership remain integration concerns for that later
slice.
