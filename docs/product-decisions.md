# LOOP current product decisions

> Canonical current scope. Updated 2026-08-24.

This document applies to the Flutter source at the repository root. Material under `reference/legacy-prototype/` is frozen history and does not override these decisions.

## Product shape

- LOOP is a Flutter iOS and Android app. Web output is only a local UI-verification target.
- The six primary destinations remain Home, Market, Launch, Chat, Wallet and Profile.
- Perpetuals remain inside Market rather than becoming a seventh primary destination.
- Privy is the selected login, wallet and final authorization boundary.
- Hyperliquid Core BTC, ETH and SOL are the selected perpetual markets. HIP-3, builder fees and a second trading core are out of scope.

## Pay priority and delivery

Product priority and current delivery are separate:

- Product priority uses A, B and C. It is not a release phase or delivery promise.
- The catalog remains 47 A-priority, 46 B-priority and 10 C-priority surfaces.
- B5 is A priority, B6 and B7 are B priority, and B8 is C priority.
- B5 through B8 are all deferred from the current release.
- Home keeps one Pay card labelled `Coming soon` so the planned product position remains visible.
- Every Pay route is informational only. It must not open a scanner, request camera access, collect an amount or recipient, select a payment provider, or submit a transaction.

## Communication

- Stream Chat + Stream Video/Audio Rooms is the selected communication integration.
- `communicationGatewayProvider` defaults to the unconfigured production Stream seam and fails closed. Only the explicit preview composition root in `main.dart` injects memory data.
- Communication mode is explicit: memory data is `preview`; the Stream seam is `production`. Preview UI continuously identifies itself as offline, simulated and not connected.
- A production session authorizer must obtain or refresh a short-lived, server-issued user token and establish the SDK session before every bridge operation. Missing or failed authorization stops the operation before the bridge is invoked.
- The current Flutter code does not contain a configured Stream SDK implementation or token service. It does not prove that chat writes, presence or voice rooms are live.
- A persistent group with 200,000 members is not a verified Stream capability. LOOP must obtain written provider confirmation covering membership, message semantics, reactions, mentions, history, search and moderation before promising it.
- Without that written confirmation, the product must adopt a sharded-group or channel model and update the information architecture before implementation.

## Identity and safety language

- An internal immutable `user id` is the primary identity for accounts, social relationships and communication-provider mapping.
- Wallet addresses are bindable and replaceable credentials. They are not database primary keys, public chat identities or communication user IDs.
- LOOP does not present an AI Guard brand or a proprietary risk score.
- Safety UI may show concrete, attributable facts such as simulation asset changes, allowance scope, malicious-domain signals, policy state and source time. Missing or stale evidence fails closed.

## Delivery truth

- Preview and memory adapters are UI evidence only. Their simulated writes and voice controls must never be presented as connected provider activity.
- Production status requires configured SDKs, short-lived server-issued tokens, testnet or sandbox evidence, native-device verification and observable provider responses.
- The production BFF remains responsible for server-only credentials, token issuance, stable error mapping, rate limits, audit events and request correlation.
