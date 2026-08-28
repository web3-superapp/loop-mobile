# 0035 Require Explicit Loading Presentation

## Status

Accepted on 2026-08-28.

## Context

I8 previously opened a static gallery containing list, detail and chart
skeletons whenever its catalog route was visited. The route claimed that
content was on the way despite having no pending operation, and it announced
three identical `Loading content` live regions. The public list renderer also
accepted any integer: zero announced load without a visible placeholder,
negative values could throw and large values could create widgets without a
bound.

Market, Chat, Profile, Watchlist, Privy, Wallet and Audio Room already own
separate loading states through their controllers, providers or SDKs. Capability
placeholders such as Launchpad and Pay are unavailable rather than pending.
Neither group is evidence that the generic I8 route is loading.

## Decision

- `SystemSurfaceScreen.fromId('loading')` requires one explicit
  `LoopLoadingPresentation` before rendering an active I8 skeleton. Without a
  valid presentation, the route reports loading context as unavailable and may
  only return to LOOP.
- Named presentations select exactly one list, detail or chart skeleton. List
  placeholder count controls visual density only and is runtime-bounded to
  1–8. It is not an expected, available or returned provider-result count.
- `LoopSkeletonView` consumes the complete presentation and repeats the same
  runtime validity check, so direct feature use cannot bypass the route guard.
  Invalid input renders nothing and never reaches unbounded list generation.
- A presentation proves only that the exact owning feature selected this
  placeholder while its own state is pending. It does not prove that a network
  request began, content exists or will arrive, an object identity is valid,
  progress advanced, an ETA exists, facts are fresh or loading will succeed.
- List, detail and chart use one exact kind-specific live region. Decorative
  geometry remains excluded from semantics, contains no actions or fixture
  facts, and stays static without shimmer or another motion branch.
- Success, empty, error, offline and stale states immediately return to the
  owning feature's presentation and the existing I1, I2 or I7 boundary as
  appropriate. Active I8 consumes no generic system action.
- This slice preserves I8, `/preview/loading` and the 103-surface catalog. It
  adds no backend route, provider request, timer, polling, event bus,
  persistence, analytics, global loading overlay, SDK, dependency or native
  capability. Existing feature loading paths are not migrated by this change.

## Consequences

Catalog navigation and direct deep links no longer fabricate a pending
operation or repeatedly announce nonexistent work. Features can opt into one
bounded, accessible skeleton after their own state authority proves load,
without turning visual density into product or provider facts.

## Evidence

- `test/system_loading_truthfulness_test.dart`
