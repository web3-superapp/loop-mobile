# Loop Implementation Constraints

This file records non-negotiable product and engineering boundaries. Read it before planning or implementing product behavior. A numbered decision may refine these rules; ordinary feature work must not silently weaken them.

## Product shape and environments

- Home, Market, Launch, Chat, Wallet, and Profile remain the six primary destinations. Launchpad is first-class; Perp stays inside Market rather than becoming a seventh destination.
- Development and Hyperliquid Testnet are the only enabled environments. Mainnet, real deposits/withdrawals, and automated trading remain feature-flagged off.
- Prefer runnable vertical slices and current official Privy/Stream Flutter SDKs. Do not add a second identity, messaging, calling, state-management, routing, or HTTP stack.
- Preview content is always labelled `演示数据` or `开发预览`; it never claims provider delivery, read state, presence, ringing, signing, or execution.

## Identity, wallet, and secrets

- Privy is the only identity provider. The first Development flow enables Email OTP only; Apple and Google are later dashboard choices.
- Create one Privy instance. Preserve not-ready, unauthenticated, authenticated-unverified, and authenticated states. Treat authenticated-unverified as a restricted offline session, not logout.
- Application code never reads, persists, refreshes, logs, or forwards the Privy refresh token. Obtain a current access token through Privy for backend calls and retry one authentication failure at most once with a newly requested token.
- Privy DID, email, phone, and wallet addresses are external identifiers, not Loop's business primary key. The backend bootstrap returns the immutable internal user ID and backend-derived Stream user ID.
- Wallet MFA protects embedded-wallet private-key operations and is not generic login MFA.
- Provider secrets, Firebase service accounts, APNs private keys, backend signing keys, and Hyperliquid agent private keys never enter Flutter, fixtures, logs, or Git.

## Stream Chat truth and history

- Use Stream Chat's official client, controllers, UI, token provider, and persistence. Stream remains the source of truth for messages, ACK/read state, presence, typing, pagination, and offline synchronization.
- Keep one message list with bidirectional pagination. Load only a recent page initially, prepend older pages while preserving the visible anchor, and page forward to latest after anchored search or unread navigation.
- Deduplicate by stable message ID and merge sending/sent/failed/retry states by client message ID. New messages must not force a user reading history to the bottom.
- Never use nested scrolling message lists, `while (hasMore)`/recursive full-history fetches, startup or reconnect full-history synchronization, a full-message search mirror, a second ACK/read/presence/typing state machine, or a second complete message database.
- Only introduce a bounded projection after measured evidence shows the official controller cannot meet the long-history performance target.

## Stream Video, UUID, and push truth

- Stream `Call`, `CallState`, and its push notification manager are the call source of truth. Map SDK state into UI; do not create a second authoritative call state machine or reimplement signaling.
- Generate a new UUID call ID for every outgoing call. Never reuse a call ID that has already rung.
- Generate a new UUID for every idempotent backend request. Persist and reuse that request ID only while reconciling the same business intent; a retry is not a new intent.
- MVP states include outgoing, ringing, accept, reject, cancel, timeout, missed, permission denial, and weak-network recovery.
- Android chat and ringing use one centralized FCM router. iOS chat uses one ordinary notification path while ringing uses VoIP Push plus CallKit. A single call must never ring once from ordinary push and again from VoIP push.
- Background ringing stays feature-flagged until provider credentials exist.

## Hyperliquid trading boundary

- The direct mobile Hyperliquid adapter is public, Testnet-only, and read-only.
- Flutter submits private business intents only. The backend owns account/order/position queries, order/modify/cancel/leverage operations, Agent/API wallet management and L1 signing, nonce allocation, policy/risk checks, idempotency, relay, and reconciliation.
- User-signed actions use an allowlisted canonical operation intent. Flutter displays network, asset, amount, destination, expiry, and risk, rejects changed or unknown typed data, and never blindly signs arbitrary payloads from a URL.
- Represent price, amount, quantity, fees, and PnL with decimal/string-safe types. Never use `double` for trading calculations.
- Order state distinguishes submitting, accepted, partial, filled, cancelled, rejected, and unknown/reconciling.
- A client timeout is not a confirmed failure and must not trigger an automatic duplicate order. Reconcile the idempotent intent before enabling retry.
- Networks, minimums, and fees come from the backend/configuration; do not hard-code them in Flutter.

## Experience and acceptance

- Preserve the current 103-surface catalog, dark design direction, Dynamic Type, accessibility semantics, Reduce Motion, platform conventions, keyboard behavior, and smooth message scrolling.
- Every flow accounts for loading, empty, error, offline, retry, disabled, and skeleton states as applicable.
- Every stage reports completed functionality, changed files, commands, and actual results. Provider/device tests that were not run remain explicitly unverified.
