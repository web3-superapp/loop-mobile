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
- The production Chat inbox uses Stream's official client, persistence, token provider, channel-list controller/view, channel scope and message page. Stream owns messages, pagination, ACK/read state, presence, typing and offline synchronization.
- `communicationGatewayProvider` remains the fail-closed seam for preview-only secondary communication surfaces that have not yet moved to official SDK UI. Only `lib/main_preview.dart` injects memory data; `lib/main.dart` never injects it.
- Communication mode is explicit: memory data is `preview`; the Stream seam is `production`. Preview UI continuously identifies itself as offline, simulated and not connected.
- The official client may be constructed from the public API key without connecting. A production session source must obtain a backend-derived Stream user ID and short-lived server-issued token; missing or failed authorization prevents controller/message UI from mounting.
- Privy user ID is only an opaque logout/account-switch key in Flutter. It is never converted into the Stream user ID. Each principal gets an isolated Stream client/persistence pair; logout and account switches retire the old pair, invalidate in-flight authorization, and disconnect without deleting per-user offline history.
- Text chat composition is wired through official UI. Attachments and voice recording remain disabled until platform permissions, upload policy and provider/device verification are complete.
- Stream Video now has a foreground-only, principal-bound SDK lifecycle and a narrow backend identity/token seam. The SDK is constructed only after an initial backend token is available, connects with push registration disabled, and is retired on route disposal, logout, or account change.
- Production voice surfaces never render preview room/member data. They remain disabled until the backend supplies a room/callee contract and native media permissions are reviewed; a future mounted call view must read the official `CallState` directly.
- The current Flutter code contains a shared LOOP identity Bootstrap source, but no Stream Chat/Video token source and no create/join path for a production `Call`. It does not prove that chat writes, presence, push, ringing, media, or voice rooms are live.
- A persistent group with 200,000 members is not a verified Stream capability. LOOP must obtain written provider confirmation covering membership, message semantics, reactions, mentions, history, search and moderation before promising it.
- Without that written confirmation, the product must adopt a sharded-group or channel model and update the information architecture before implementation.

## Identity and safety language

- An internal immutable `user id` is the primary identity for accounts, social relationships and communication-provider mapping.
- The native client now has a principal-bound adapter for the implemented `POST /v1/bootstrap` boundary. It sends one current Privy Bearer access token, accepts only the backend-derived LOOP and Stream identities, retries one HTTP 401 at most once with a newly requested token, and keeps the validated identity in memory only.
- Chat and Video share that trusted `stream_user_id` projection, but remain disconnected while the separately owned Stream token contract is unavailable.
- Wallet addresses are bindable and replaceable credentials. They are not database primary keys, public chat identities or communication user IDs.
- LOOP does not present an AI Guard brand or a proprietary risk score.
- Safety UI may show concrete, attributable facts such as simulation asset changes, allowance scope, malicious-domain signals, policy state and source time. Missing or stale evidence fails closed.

## Delivery truth

- Preview and memory adapters are UI evidence only. Their simulated writes and voice controls must never be presented as connected provider activity.
- Production status requires configured SDKs, short-lived server-issued tokens, testnet or sandbox evidence, native-device verification and observable provider responses.
- The production BFF remains responsible for server-only credentials, token issuance, stable error mapping, rate limits, audit events and request correlation.
