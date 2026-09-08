# 0054 · Adopt the V2 community, social-graph and search modules

## Status

Accepted 2026-09-08. Retires the Home-era Global Search slice, the V1 friend
list route and the V1 alias-search route.

## Context

Step 3 (S3) connects `loop-api` decision 0031's two module gates, `community`
and `search`, and rebuilds nine frozen-prototype pages on the step-1 component
library: `community`, `community-discover`, `community-profile`,
`community-members`, `search`, `connections`, `blocklist`, `dm-requests` and
`referral`.

Four constraints shaped the result:

- Almost every figure the prototype shows has no source yet. Online counts,
  unread counts, live voice, mining power, announcements, official links,
  message previews, AI moderation verdicts, referral relationship counts and
  the invite code are all `{status: unavailable, reasonCode}` projections in
  the contract. Rendering `0` for any of them would be an invented fact.
- The permission matrix is server-owned. The response carries
  `viewer.canInviteAdmin / canMute / canBan` plus each row's `isSelf`, role
  and status; a second client-side matrix could only drift.
- Every write is idempotent. A timed-out retry must replay the same
  `Idempotency-Key`, and a resolved outcome must not.
- The V1 friend list (`/profile/friends`) and alias search
  (`/chat/friends/add`) overlap the new `search` + `connections` pages. Keeping
  both would give the same relationship two competing sources of truth.

## Decision

1. **Three strict transports under `lib/integrations/backend/v2/`.**
   `community/`, `social/` and `search/` each parse with
   `LoopV2Contract.strictMap` against the frozen key set. An unknown field, a
   wrong `contractVersion`, a missing `Cache-Control: no-store`, or a
   `correlationId` that differs from `X-Request-ID` is an invalid payload, not
   a partially trusted projection. `LoopV2ProjectionCodec` holds the decoders
   the three modules share.
2. **`LoopV2CommandKeyring` owns write identity.** One logical operation
   reserves exactly one canonical lowercase UUIDv4. Only an unresolved outcome
   — a timeout or a lost connection — keeps the key for an identical retry; a
   success or a terminal rejection releases it, so the next attempt can never
   collide with the recorded key.
3. **Cursors stay opaque.** They are shape-checked and echoed back verbatim,
   never parsed, and never sent alongside a `limit`.
4. **`lib/features/` depends only on ports.** `CommunityGateway`,
   `SocialGateway` and `SearchGateway` expose domain models; production
   defaults are `Unavailable*` implementations, `main.dart` overrides them with
   the V2 adapters, and `main_preview.dart` overrides them with labelled
   memory adapters.
5. **Unavailable is rendered, never replaced.** Every
   `{status, reasonCode}` field renders an explanation through
   `CommunityUnavailableCard`; a missing figure renders `—`. The prototype's
   sample stranger-request body and its "AI flagged as fraud" card are not
   reproduced.
6. **Action visibility comes only from `viewer`.** `communityGovernanceActions`
   filters by the server flags plus the row's own facts; it adds no rule of its
   own. Every governance, membership, follow, block and stranger-request
   decision passes through a `LoopSheet` second confirmation, and a success
   Toast is raised only after a 2xx.
7. **`search` moves to `lib/features/community/search_screen.dart`** with the
   five domain segments. `users` and `communities` are backed; `assets`,
   `launch` and `dapps` render the server's own `reasonCode`. A result is
   opened only through `destination.kind`; no route is assembled from display
   copy, a ticker or a domain name.
8. **`/profile/friends` and `/chat/friends/add` are retired** into
   `informationalRetiredPaths`. They are no longer mounted; the product links
   that emitted them now point at `search` and `connections`.
   `/chat/friends/requests` stays mounted until D7 folds it in.
9. **The error catalogue grows to 30 codes** with
   `PROFILE_ACTIVATION_REQUIRED` and `RESOURCE_CONFLICT`, and the capability
   enum follows the contract's 23 ids.

## Consequences

- `community-discover` shows only the two server-backed orders. "算力最高" and
  "讨论最多" stay disabled with the step that will give them a source.
- `community-profile` renders no Token Card when `boundAssetKey` is null, and
  when it is present it shows the key with an explicit note that the server has
  not resolved it. No price, market cap, liquidity or holder figure appears.
- `referral` shows the five versioned ratios as the server's decimal strings.
  Relationship counts and the invite code are unavailable, so the share action
  stays disabled.
- The Home-era `GlobalSearchScreen` and its four Preview-fixture tests are
  gone. `scripts/check_harness.py` now fails if that class returns to
  `home_screens.dart`.
- Preview-mode reads and writes are visibly labelled `演示数据` and never reach
  an account or a provider.

## Evidence

- `test/community_api_contract_test.dart` — strict parsing, the seven-field
  envelope, header shape, cursor passthrough and quota preflight.
- `test/community_idempotency_test.dart` — key reservation, replay after an
  unresolved outcome, release after a resolved one.
- `test/community_pages_test.dart` — the five states for the four community
  pages plus the permission matrix.
- `test/community_social_pages_test.dart` — the five states for connections,
  blocklist, dm-requests, referral and search, plus domain switching.
- `test/route_manifest_test.dart`, `test/friend_feature_test.dart` — the two
  retired locations fail closed and are recorded as informational.
