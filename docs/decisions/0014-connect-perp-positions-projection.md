# Connect the Perp Positions Projection

## Status

Accepted on 2026-08-25.

## Context

Decision 0013 established a principal-bound mobile session and strict backend
adapter for Hyperliquid Testnet private reads. Its first mounted production
slice was D8 Perp account. D4 Positions still rendered a labelled static
position, portfolio ratio, and route to the D5 management preview even when the
normal application entry point was used.

Positions are short-lived private facts rather than durable local state. The
backend limits Core positions to BTC, ETH, and SOL, returns an opaque
principal/wallet/binding/route-bound continuation cursor, and gives every page
its own source expiry. Position pagination is a live keyset traversal, not a
frozen account snapshot. A fresh empty response is meaningful only until that
same expiry boundary.

## Decision

- Mount D4 production through `PerpPrivateGateway.listPositions`. Keep the
  existing fixture in the explicit Development Preview composition and put no
  preview position, ratio, detail route, or management control in the live
  branch.
- Use a dedicated principal-scoped `PerpPositionsController`. It watches the
  private gateway owner, shares one in-flight operation, retires late results
  after gateway rotation or expiry, releases the logical single-flight when an
  expired continuation is still physically pending, and stores no bearer
  token, wallet address, route, Dio client, or owner identifier.
- Request an initial page with limit `2`. Request exactly one continuation page
  at a time using only the opaque cursor; never repeat the limit or recursively
  drain the collection. Preserve strict BTC/ETH/SOL ordering and reject a
  repeated cursor, mismatched dataset, coverage metadata, or an empty page that
  claims another cursor.
- Treat the projection expiry as the earliest expiry among all loaded pages.
  Clear positions, empty evidence, cursors, timestamps, and page failures when
  it is reached. Check the clock synchronously during rendering, continuation,
  and application resume in case a suspended timer did not fire.
- Preserve an already-rendered page after a continuation timeout or connection
  failure only while that page is still fresh. Any schema, authorization,
  binding, version, cancellation, or unexpected continuation failure clears
  the complete projection.
- On `wallet_binding_required`, show an explicit route to D8 Perp account. D4
  never calls wallet binding and never implies that opening the route completed
  a binding.
- Render trading numbers directly from the strict `Decimal` models without
  converting through `double`. Do not synthesize a mark price, risk ratio, or
  liquidation distance that the positions contract did not return.
- Keep D4 read-only. Close, reduce, leverage, margin, TP/SL, transfer,
  withdrawal, signing, and every other mutation remain unavailable.
- Fail D5 production closed until a separately reviewed live detail contract is
  mounted. The Development Preview may retain its visibly labelled ETH detail,
  but production does not substitute that fixture or link to it from D4.
- Add behavior tests and Harness mutations for cursor-only continuation,
  freshness expiry, owner rotation, no automatic binding, preview isolation,
  Decimal rendering, lifecycle resume, and the D5 unavailable boundary.

## Consequences

The normal application can display backend-proven, short-lived Testnet Core
positions and bounded continuation pages without gaining wallet authority or
exposing a trading action. Empty, loading, retryable, binding-required, stale,
unavailable, and invalid-data states remain distinguishable, and every old
fact disappears at its contractual expiry.

This decision does not prove a live Privy OTP session, wallet binding, a
non-empty Hyperliquid account, physical-device networking, or provider behavior.
It also does not connect D5 position detail, orders, fills, funding, trading
writes, Firebase, or background delivery; those remain separate verified
vertical slices.
