# LOOP current product decisions

> Canonical current scope. Updated 2026-08-25.

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
- Incoming Stream `token_card.v1` attachments are the narrow exception to disabled attachment composition: official Stream message rendering may display their strict identifier-only reference. A compliant producer/server contract forbids persisting price, liquidity, risk, ownership, provider links, watch state, or trading actions; the receiver hides violations without claiming they were never stored.
- The Token Card renderer is synchronous and fail-closed. Missing, extra, malformed, repeated, mixed, or unknown-version payloads show no supplied facts. Valid cards remain `Current facts unavailable` until a separately freshness-bounded backend facts projection exists; preview facts stay visibly marked `开发预览` and cannot mutate a watchlist or trade.
- Raw Token Cards are intercepted before Stream's computed link/media type can select a default renderer, and standard top-level URL/action/display fields are rejected. Compact message and draft previews replace every raw Token Card with a fixed safe label so captions, titles, URLs, and mutable facts cannot escape through channel, reply, thread, or search previews. Outgoing Token Card composition remains disabled until a backend or Stream before-send policy enforces the same complete wire shape; Flutter receive validation alone cannot guarantee stored data.
- The legacy group, direct-message, group-information, request, search, and token/facts preview routes remain preview-only. Production navigation cannot mount their fixture conversations; authenticated production chat continues through Stream's server-authorized inbox and CID route.
- Stream Video now has a foreground-only, principal-bound SDK lifecycle and a narrow backend identity/token seam. The SDK is constructed only after an initial backend token is available, connects with push registration disabled, and is retired on route disposal, logout, or account change.
- Production voice surfaces never render preview room/member data. Audio Room now has a foreground lobby, backend-authorized target seam, muted single-flight join, official `CallState` participant/capability/media UI, explicit Speak action and principal/target/client cleanup. Missing Video tokens or room locator keep the join action disabled.
- Audio Room uses only Stream's `audio_room` type. The backend must pre-create the room, add the server-derived Stream user and assign a role without `create-call`; the app never calls `getOrCreate`. This server permission is mandatory because Stream Video 1.4.3 internally sends `create: true` during `join()`.
- A first join disables camera, microphone and screen share, while foreground playback uses the speaker route. `Joined` is presented as media connecting; only official `Connected` state is Live and eligible for Speak.
- The first Audio Room release owns microphone-only native configuration and remains foreground-only. Every terminal cleanup, including paused/hidden/detached, immediately starts native suspension, terminal mute, and one single-flight leave without letting a possibly stuck Speak/Mute/native future delay leave. Cleanup succeeds only after the retired object disappears from Stream's `activeCalls`, earlier microphone work settles, and a second post-command mute runs; fast resume and rejoin remain blocked until then, and a completed failure can only be retried. Version 1.4.3 permits one Speak start per Call, so Mute requires leave/rejoin before another Speak and the unsafe stopped-track recreation path is never entered. The flow never uses Stream's track auto-restore path. The auto-registering Stream Video Push plugin is not linked; optional Android incoming-call/background/Telecom/push components are also removed from the merged app manifest, and iOS has no camera, background, PushKit, CallKit or push entitlement configuration.
- The current Flutter code contains a shared LOOP identity Bootstrap source and a production Audio Room join path, but no Stream Chat/Video token source or production room locator. It does not prove that chat writes, presence, push, ringing, media, or voice rooms are live.
- A provider-neutral `notification.v1` classifier now fixes the future navigation contract without enabling Firebase. It accepts only an exact LOOP-owned String envelope bound to the current backend-derived Stream user, treats foreground/background delivery as non-navigation, and allows an explicit interaction to resolve only an official Chat CID, the Audio Room lobby, or the truthful notification center. It does not parse raw Stream/Firebase payloads, register devices, initialize providers, ring, or claim delivery.
- Notification interaction deduplication is bounded and process-local. Cross-isolate/restart delivery and ordinary-push/VoIP ringing remain disabled until a persistent atomic receipt design, exact provider names, real payload fixtures, and native routing policy are approved.
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
