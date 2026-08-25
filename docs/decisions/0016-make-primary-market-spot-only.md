# Make the Primary Market Experience Spot-Only

## Status

Accepted on 2026-08-25.

Decision 0017 supersedes only this decision's temporary conclusion that the
Market tab has no reviewed spot source. The spot-only navigation, disabled
perpetual implementation, and unavailable execution boundaries remain active.

## Context

The Flutter client inherited a public Hyperliquid Testnet perpetual-market
feed, private Perp account and position reads, and visibly labelled Preview
routes. Product has now removed perpetuals from LOOP's scope: the application
will offer spot products only.

The existing public feed cannot be relabelled as spot. It reads
`metaAndAssetCtxs` and exposes perpetual-specific mark price, funding, and
leverage facts. A spot data contract and a backend-mediated spot execution
contract have not yet been reviewed or implemented.

## Decision

- Keep Home, Market, Launch, Chat, Wallet, and Profile as the six primary
  destinations. Launchpad remains first-class.
- Make Market a truthful spot-only surface. Until a reviewed spot data source
  exists, it shows an unavailable state and issues no request to the legacy
  perpetual feed.
- Remove every direct `/perp` navigation path and perpetual account/trading
  claim from the six primary feature modules, including Home activity,
  notifications and search, the Market quick actions, and the Wallet overview.
- Set `BuildPolicy.perpetualsEnabled` and `BuildPolicy.spotExecutionEnabled` to
  false. Spot UI work may proceed against unavailable or explicitly labelled
  Preview ports, but no order execution may be claimed.
- Retain the existing Perp routes, adapters, models, tests, and numbered
  decisions temporarily as disabled implementation history. They are not
  mounted by product navigation and receive no further feature development.
- Keep the former public Testnet feed in a named legacy screen only for
  read-only regression coverage. Do not expose it from product routes and do
  not reinterpret its values as spot facts.
- Require Harness and widget checks that reject a re-enabled perpetual policy
  or a new `/perp` path under any primary feature module.

## Consequences

The normal application no longer exposes a perpetual market, margin account,
position, order, or transfer entry. The Market tab honestly reports that spot
data is not connected while retaining labelled, providerless frontend previews
such as Watchlist.

Existing Perp code remains dormant and recoverable, so this change is not yet a
deletion migration. A later cleanup may remove its routes and dependencies once
the spot architecture is accepted. Before spot can be called connected, LOOP
still needs decimal-safe spot models, a reviewed market-data source, an
authenticated backend intent contract, balance and fee facts, idempotency and
reconciliation behavior, and provider/device evidence.
