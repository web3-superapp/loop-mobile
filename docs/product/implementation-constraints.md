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
- Only introduce a bounded message-history projection after measured evidence shows the official controller cannot meet the long-history performance target. This rule is separate from a small, freshness-bounded facts cache keyed by currently visible token references.
- The only production token-reference attachment is Stream type `token_card` with schema `token_card.v1`. Its `extraData` keys are exactly `loop_schema`, `asset_id`, `chain_id`, `contract_id`, and canonical millisecond UTC `snapshot_at`; any missing, extra, malformed, or future-version field fails closed as unsupported.
- A token card admitted by a compliant producer or server before-send gate contains identifiers only. Price, liquidity, ownership, contract facts, risk claims, provider URLs, watch state, and executable actions are forbidden from that durable message contract; receive-side rejection can hide violations but cannot prove what Stream stored.
- The Stream attachment builder is synchronous and read-only. It must not fetch per historical message, build a second message/history source, or show stale cached facts as current. Until a separately bounded fresh backend facts projection exists, a valid production card displays `Current facts unavailable` with no Buy or Watch action.
- A future facts projection must be independently freshness-bounded, attributable, cached outside Stream persistence, and cleared on stale/error. A future Buy entry must open the canonical backend-mediated review/intent flow; it never executes from attachment data.
- Before production Token Card sending is enabled, the backend or Stream before-send policy must enforce the entire wire shape: one non-mixed card, no standard Attachment title/text/media/URL/action fields, and exactly the five v1 `extraData` keys. Flutter intercepts every raw `token_card` and hides malformed or mixed input, but a receiver cannot by itself guarantee what Stream stored.

## Stream Video, UUID, and push truth

- Stream `Call`, `CallState`, and its push notification manager are the call source of truth. Map SDK state into UI; do not create a second authoritative call state machine or reimplement signaling.
- Audio Room v1 uses only the fixed `audio_room` call type and a backend-authorized room ID. The backend pre-creates the room, assigns membership and a mobile role without `create-call`; Flutter never calls `getOrCreate` or accepts a client-selected call type/CID.
- Every first Audio Room join explicitly disables camera, microphone and screen share. `Joined` means media is still connecting; only official `Connected` state may be presented as live or enable the microphone.
- Generate a new UUID call ID for every outgoing call. Never reuse a call ID that has already rung.
- Generate a new UUID for every idempotent backend request. Persist and reuse that request ID only while reconciling the same business intent; a retry is not a new intent.
- MVP states include outgoing, ringing, accept, reject, cancel, timeout, missed, permission denial, and weak-network recovery.
- Android chat and ringing use one centralized FCM router. iOS chat uses one ordinary notification path while ringing uses VoIP Push plus CallKit. A single call must never ring once from ordinary push and again from VoIP push.
- Background ringing stays feature-flagged until provider credentials exist.
- Notification classification accepts only the exact LOOP-owned `notification.v1` normalized envelope with String values, canonical UUID v4 event ID, backend-derived recipient Stream user ID, bounded canonical UTC lifetime, and a fixed kind-specific key set. Raw Firebase, Stream Chat, Stream Video, APNs, and PushKit payloads are unknown until their exact provider templates are captured and verified.
- Foreground/background delivery cannot navigate. A matching authenticated user interaction may resolve only a validated official Chat CID, the Audio Room lobby, or the truthful notification center. Payload routes, URLs, title/body, call type, room/call IDs for Audio Room, auto-join, auto-unmute, wallet, trading, and signing destinations are forbidden.
- The current bounded receipt ledger is process-local. Do not claim cross-isolate or exactly-once delivery; background push and ordinary-push/VoIP ringing require an atomic persistent receipt design before enablement.
- Foreground Audio Room v1 does not enable camera, background media, Telecom, full-screen incoming-call UI, PushKit, CallKit, or push entitlements. Those capabilities require a separate native/provider decision and device matrix.
- `stream_video_push_notification` stays outside the foreground Audio Room dependency graph because version 1.4.3 auto-registers native Telecom/CallKit behavior. Do not restore it until the push/ringing decision enables and verifies those capabilities.
- Any terminal cleanup, including `paused`, `hidden`, or `detached`, immediately starts native audio suspension, a terminal mute, and one single-flight leave without letting a possibly stuck media command delay leave. Resume or rejoin stays disabled until the old object disappears from the Stream client's `activeCalls`, every earlier microphone command settles, and a second post-command mute runs. Stream Video 1.4.3 Audio Room Calls allow only one Speak start; after Mute, leave and rejoin before speaking again so the SDK's stopped-track recreation path is never entered. Failure exposes only a cleanup retry. SDK auto-mute/auto-restore is not used, so an old Call never republishes the microphone or rejoins automatically.

## Hyperliquid trading boundary

- The direct mobile Hyperliquid adapter is public, Testnet-only, and read-only.
- Flutter submits private business intents only. The backend owns account/order/position queries, order/modify/cancel/leverage operations, Agent/API wallet management and L1 signing, nonce allocation, policy/risk checks, idempotency, relay, and reconciliation.
- User-signed actions use an allowlisted canonical operation intent. Flutter displays network, asset, amount, destination, expiry, and risk, rejects changed or unknown typed data, and never blindly signs arbitrary payloads from a URL.
- Represent price, amount, quantity, fees, and PnL with decimal/string-safe types. Never use `double` for trading calculations.
- Order state distinguishes submitting, accepted, partial, filled, cancelled, rejected, and unknown/reconciling.
- A client timeout is not a confirmed failure and must not trigger an automatic duplicate order. Reconcile the idempotent intent before enabling retry.
- Networks, minimums, and fees come from the backend/configuration; do not hard-code them in Flutter.

## Personalization boundaries

- The Watchlist is one owner-bound, versioned, grouped, ordered snapshot. A save replaces the complete draft using the committed version; a conflict never silently overwrites either side and requires explicit reload or reconciliation.
- Keep Watchlist records limited to canonical group keys, bounded display names, and ordered canonical asset keys. Asset references are preferences, not proof that a market exists, is fresh, or is tradable.
- Price, change, volume, funding, liquidity, risk, alert status, provider payloads, wallet data, and trading actions never enter Watchlist persistence or its application port.
- Until the authenticated backend adapter is implemented and verified, production uses the unavailable port. Only tests and `lib/main_preview.dart` may inject a deterministic memory implementation, and its saved state stays labelled `开发预览`.
- The Profile presentation resource contains only a nullable Alias and nullable opaque `avatar:` reference, plus its version and update time. Bio is not part of this contract, while discoverability and copy-trade visibility belong to the separately versioned Privacy resource.
- Alias handling matches the backend limits: at most 256 raw UTF-16 code units, 1–40 Unicode code points after trimming when non-null, and no control, surrogate, or bidirectional-override/isolate characters. Empty UI input means an explicit nullable Alias; arbitrary avatar URLs are never accepted.
- A Profile save replaces the complete reviewed values using the committed version. A conflict preserves the local draft but freezes editing and saving until an explicit reload; no UI reports success without a matching resource whose version advanced.
- A future authenticated Profile gateway is scoped to the immutable current owner. Account rotation replaces that gateway, immediately clears the prior resource/draft, retires late work, and reloads only the new owner; Flutter never reuses one owner's presentation across principals.
- Until an authenticated Profile adapter and reviewed avatar-reference source exist, production Profile persistence is unavailable and avatar editing stays disabled. The deterministic memory implementation is limited to tests and the visibly labelled Preview root.

## Experience and acceptance

- Preserve the current 103-surface catalog, dark design direction, Dynamic Type, accessibility semantics, Reduce Motion, platform conventions, keyboard behavior, and smooth message scrolling.
- Every flow accounts for loading, empty, error, offline, retry, disabled, and skeleton states as applicable.
- Every stage reports completed functionality, changed files, commands, and actual results. Provider/device tests that were not run remain explicitly unverified.
