# Use Public Hyperliquid Testnet Spot Market Data

## Status

Accepted on 2026-08-25.

## Context

Decision 0016 removed perpetuals from product navigation and required Market
to remain unavailable until LOOP reviewed a genuinely separate spot source.
The mobile client needs attributable spot discovery data before the private
account and execution backend is ready, but it must not invent balances,
tradability, quotes, orders, signing, or any other private behavior.

Hyperliquid documents the public Info request
[`spotMetaAndAssetCtxs`](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint/spot),
which returns spot token metadata and asset contexts. The response shape cannot
be joined by array position: token indices are sparse, universe rows reference
those indices, and the context collection may contain rows outside the spot
universe. It also provides no exchange snapshot timestamp.

## Decision

- Add a dedicated Hyperliquid Testnet spot adapter. It sends only `POST /info`
  with `{"type":"spotMetaAndAssetCtxs"}` and exposes public, read-only market
  discovery facts. It does not reuse or relabel the retained perpetual adapter.
- Index token metadata by its declared integer `index`, then resolve each
  universe row's two token references through that map. Never assume token
  rows are contiguous or position-aligned.
- Index asset contexts by exact provider `coin` and join them to universe rows
  by the universe `name`. Never zip universe and context arrays. Keep the
  provider `@<index>` identifier for protocol identity, but form the displayed
  `BASE/QUOTE` pair from the resolved token symbols.
- Preserve `markPx`, nullable `midPx`, `prevDayPx`, `dayNtlVlm`, and
  `dayBaseVlm` as the exact wire String together with a parsed `Decimal`.
  Reject numeric JSON values and malformed, negative, missing, or ambiguous
  facts rather than converting through `double` or guessing an association.
- Record the UTC instant when the complete response is received by the client.
  Label it as client receipt time only. It is not an exchange snapshot, trade,
  block, or provider event timestamp.
- In the default ledger, retain only pairs whose exact 24-hour notional volume
  is greater than zero, sort them by that exact value descending, and display
  at most 50. Search can match all valid returned pairs by base/quote symbol,
  displayed pair, provider coin, or spot index, but its display is also capped
  at 50. The cap is a rendering and scanning bound, not market completeness.
- Present public marks and volumes as discovery facts, never executable
  quotes. Keep `BuildPolicy.spotExecutionEnabled` false and mount no Buy, Sell,
  account, balance, order, cancellation, signing, transfer, or withdrawal path.
  Every private read and every mutation continues through a separately reviewed
  LOOP backend contract.
- Keep loading, empty, error, manual refresh, and restricted-session behavior
  explicit. Do not request before a user enters the product. Because this
  endpoint is identity-free and read-only, authenticated, cached-unverified,
  and explicit Development Preview sessions may read it; this exception does
  not enable any other provider-backed capability. Do not silently substitute
  perpetual or Preview prices when this public source is unavailable.

## Consequences

The Market tab can show live public Hyperliquid Testnet spot discovery data
without waiting for the private trading backend. The adapter has a deliberately
narrow capability surface, exact Decimal-safe parsing, deterministic sparse-key
joins, and truthful client-side freshness attribution.

This decision does not connect a user account or make spot trading available.
Balances, fees, executable price protection, intent review, authentication,
risk controls, signing, idempotency, relay, reconciliation, and provider/device
evidence remain future backend-mediated work. Decision 0016 continues to keep
all perpetual product surfaces disabled.
