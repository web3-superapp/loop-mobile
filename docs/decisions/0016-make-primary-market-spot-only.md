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

## Chat Preview Closure

On 2026-08-26 the E9 asset-message Preview was brought under this decision.
Its former position direction, entry, size, return, copy-position and fake
`Save setup` language was not a harmless fixture: it kept an out-of-scope Perp
product concept reachable from the normal offline Chat demonstration. The card
now exposes only visibly labelled Spot fixture facts. Its single enabled action
opens the public Spot market ledger at `/market`; it does not invent a provider
index, open an order flow, or persist a Watch preference. Watch stays disabled.

The same closure removes fixture conversation claims that an address was saved
or a transfer alert was activated. Neither Watch persistence, Price Alerts nor
provider activity delivery is connected by the Chat memory gateway. Generic
class, enum, and route names containing `assetSnapshot` remain because they do
not encode a Perp capability.

Widget evidence covers the Spot-only language, disabled Watch control, exact
Market navigation and 390-point layout at 2x Dynamic Type. Production still
blocks `/preview/asset-message` through the existing Preview route guard.
Harness mutations reject restored or alternate position language, literal or
externally supplied buy-price/ROI facts, fake saved actions and localized or
imported active-alert claims, route drift or a no-op Market action, direct,
card-helper or page-helper interaction, removed Preview attribution, an enabled
Watch control, and hollow, unreachable, skipped or assertion-shadowed behavior
evidence. Normalized source fingerprints close the reviewed component, page,
fixture-content and evidence boundaries against cross-file substitution.

The focused Chat/Preview/catalog/production-inbox suite passed all 19 tests,
the complete Flutter suite passed all 473 tests, changed-file analysis passed,
the Harness passed, and all 171 Python mutation tests passed. No HTTP/provider
request, build, package, simulator or physical-device run was performed.
