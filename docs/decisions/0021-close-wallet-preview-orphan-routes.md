# Close Wallet Preview Orphan Routes

## Status

Accepted on 2026-08-26.

## Context

Wallet readiness now exposes one current Privy Embedded Ethereum wallet
identity without enabling funds. Several older prototype routes still broke
that truth boundary: every asset row opened an Ethereum-only detail page, a
naked Signing Review route manufactured a local ETH intent, the DApp layout
displayed a fixture wallet, and the product catalog described Preview layouts
as provider capabilities.

These defects do not authorize a transfer integration. The reviewed backend
transfer routes remain default-closed and publish no success DTO. The app must
not fill missing route state with an asset, intent, wallet, quote, provider
fact, or transaction claim.

## Decision

- Carry a typed, immutable `WalletPreviewAsset` from each labelled portfolio
  fixture into its detail route. Missing or wrong route state returns to
  Wallet; it never defaults to ETH. The detail page displays only that exact
  fixture and says that no balance or activity request occurred.
- Require a real in-memory `SigningIntent` object at the Signing Review route.
  A naked or restored route returns to Wallet and creates no UUID, expiry,
  transfer field, or local intent.
- Remove the DApp fixture wallet. The disabled DApp layout may project only the
  complete current-session wallet identity already admitted by
  `WalletReadiness`; otherwise it displays unavailable. The typed domain is a
  local layout value and is never described as trusted, opened, resolved, or
  wallet-connected. Session rotation, restricted state, and logout immediately
  remove the prior identity; source guards reject every complete Ethereum
  address literal in this layout rather than one known fixture value.
- Keep embedded browsing, wallet injection, permissions, network support,
  provider balances, asset activity, transfer, signing, and submission
  unavailable.
- Rewrite F1-F20 catalog descriptions to state the mounted readiness,
  labelled Preview, deferred, and unavailable boundaries. Product priority is
  not delivery evidence.

## Consequences

Every mounted Wallet asset detail and critical review route now needs explicit
typed origin state. Restoring or deep-linking without that process-local state
fails closed instead of fabricating a default. The DApp preview can show the
same current public wallet identity as Wallet but gains no provider or signing
authority.

No backend route, DTO, signing capability, transaction result, or persistence
model is added. Swap snapshot consistency and the one fixed transfer decimal
wire rule are separate follow-up slices because they require their own failure
and mutation evidence.
