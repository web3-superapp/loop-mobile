# 0038 Bound New Pairs to Exact Preview

## Status

Accepted on 2026-08-28.

## Context

C10 `/market/new` was mounted in every product session with a constructor that
defaulted to `MarketSnapshotState.preview`. Authenticated production and
cached-unverified sessions therefore displayed BTC, ETH, and SOL as recently
observed, static relative ages, and a count of hidden candidates. The page was
visibly labelled as Preview, but its local fixture still crossed the repository
rule that deterministic facts enter only tests or the explicit Preview
composition.

The accepted public `spotMetaAndAssetCtxs` response does not include listing time.
Client receipt time is only local freshness attribution; the response's
volume and canonical flag likewise do not establish when a pair was listed,
whether it is new, or any pool age, liquidity, ownership, or safety fact.

## Decision

- `NewPairsScreen` reads the current `LoopSessionState` itself. Only
  `session.isPreview` selects the fixture branch; callers cannot pass a snapshot
  state or force Preview through route data.
- Authenticated and authenticated-unverified sessions render one neutral
  `New pairs not connected` state. C10 does not model loading, empty, offline,
  stale, retry, or region state because it owns no production request.
- C10 issues zero market and candle repository requests in every session. The
  existing public Spot source remains available on C1–C3, but is not reinterpreted
  as a new-pair source.
- Static pairs, fixture ages, and the folded-candidate example remain only in
  exact Development Preview and stay labelled `开发预览`, `演示数据`, and
  `PREVIEW` before their facts.
- A Preview pair may return only to bare `/market`. It cannot invent a
  `spotIndex`, token route, executable quote, risk result, or safety result.
- The C1 Preview quick-action rail mounts only in the exact Preview session.
  This also removes the still-fixture-backed C11 shortcut from the production
  Market path without claiming C11 is implemented.
- A reviewed listing-time source and truth model are required before production
  C10 can classify any pair as new.

## Consequences

Production no longer exposes unobserved pair identity, listing-age, or candidate
count facts. Direct links remain stable and explain the missing source instead
of claiming that no new pairs exist. Preview remains useful for layout and
navigation review without triggering Hyperliquid requests or implying provider
identity.

This change adds no gateway, backend route, provider call, dependency, polling,
refresh, retry, order, signing, or execution behavior. C5, C6, C9, and C11
remain separately unimplemented and are not made truthful by this decision.

## Evidence

- `test/new_pairs_truthfulness_test.dart` covers authenticated,
  authenticated-unverified, exact Preview, zero Market/Candle requests, Preview
  entry isolation, bare-Market navigation, portrait/landscape layout, and 200%
  text.
- `test/app_navigation_test.dart` proves the real authenticated `LoopApp`
  `/market/new` route remains unavailable without fixture facts or an additional
  public-market request.
- The Harness fingerprints the exact session selector, production branch,
  Preview branch, quick-action rail, route, pair card, and executable tests, with
  mutation coverage for the recorded regression modes.
