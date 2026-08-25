# Connect Principal-Bound Perp Private Reads

## Status

Accepted on 2026-08-25.

## Context

The Loop backend now implements an explicit Privy master-wallet binding
lifecycle and strict, read-only Hyperliquid Testnet projections for config,
account, positions, open orders, recent fills, and recent funding. Flutter
already has a principal-bound `POST /v1/bootstrap` owner, but every private
Perp surface still renders labelled fixtures and no mobile adapter consumes
these contracts.

Private Perp reads have a different lifecycle from identity bootstrap. A
wallet may be created or replaced without changing the Privy principal, every
request needs a current Bearer token, wallet binding is an explicit optimistic
action, and account facts expire within the server-provided source window.

## Decision

- Keep `LoopBootstrapSession` limited to LOOP/Stream identity. Add a separate
  principal-bound Perp session that gates every request on successful bootstrap,
  obtains one current Privy access token for the immediate request, and retries
  exactly one HTTP 401 with a newly requested token.
- Rotate the Perp session on Privy principal or local embedded-wallet changes.
  Disposal invalidates in-flight work before it can publish facts for another
  owner. Wallet addresses remain local rotation signals and never enter a Loop
  request, DTO, error, or log.
- Add exact mobile models and a strict Dio adapter for wallet-binding GET, PUT,
  and DELETE plus all six private-read endpoints. Trading decimals use
  `Decimal`; binding versions, provider uint64 identifiers, and opaque cursors
  remain strings.
- Send only the contract-owned request fields. Binding PUT sends one
  `expected_binding_version` JSON field; DELETE sends only that query field.
  Private reads never send an owner, LOOP user ID, Privy DID, wallet address,
  wallet ID, network, DEX, or provider URL.
- Require exact response keys, canonical values, `Cache-Control: no-store`, a
  matching UUID request ID, fixed Testnet/Core scope, bounded source freshness,
  and cursor/limit exclusivity. Contract drift and stale facts fail closed.
- Make `/perp/account` the first production UI slice. It runs bootstrap,
  binding read, an explicit user-confirmed bind when required, config read, and
  account read in that order. It shows only backend-proven account values and
  clears them when `source.expires_at` is reached.
- A binding mutation timeout is unknown, not failed. Reconcile with binding GET
  and never automatically replay PUT or DELETE. Version conflicts require a
  fresh binding read and another explicit user confirmation.
- Keep the existing D8 fixture only in the explicit offline Preview entry point.
  Positions, orders, fills, and funding transports are prepared here, while
  their production screens and pagination controllers remain later slices.
- Keep `LOOP_BACKEND_BASE_URL` an explicit client-safe build input. Physical
  device runs use `https://api-dev.quant-dinger.cc`; missing or unsafe origins,
  signed-out sessions, Preview, and authenticated-unverified sessions perform
  no private request.

## Consequences

Flutter can establish and display a short-lived, backend-mediated Testnet Perp
account projection without learning wallet authority or enabling a trading
mutation. The adapter and deterministic tests are implementation evidence only.
Live Privy OTP, real wallet binding, non-empty Hyperliquid account data, TLS
tunnel behavior, and physical-device connectivity remain unverified until the
separate device integration pass.
