# 0109 — Market reference layout and friend-first primary Chat

## Status
Approved by the product owner on 2026-10-02. Base: integration/v2 ebf5f49.

## Context
The owner requested a denser market reference layout, Chat as a primary destination, ordinary visible social identity, and a labelled fake-data catalog for page tuning. Existing canonical identity, backend capabilities and transaction boundaries still apply.

## Decision
Six primary destinations are Community / Chat / Mining / Launch / Market / Wallet. This supersedes the five-tab requirements in 0048; Community remains the post-login home. Existing `/chat` is promoted into the shell and canonical manifest, which now counts 94 routes while preserving all 93 prototype routes, order values and source provenance. Native Chat has extension order 93. Conversation, requests, connections and Profile routes remain children.

Market retains LOOP Ink/Lime branding and sourced exact values, with denser reference-inspired identity/volume rows and stacked price/change, canonical asset filtering, quote/chart focus and a direct discussion entry. Only data-backed controls are offered; no perpetuals/stocks or fictional market caps.

Anonymous mode is retired from product controls. User identity is avatar, nickname and LOOP ID. Existing `anonymousMode` DTO remains accepted for server compatibility: reads remain honest, while a user-initiated Privacy Save writes false using the existing CAS and preserves all other preferences. Public profile sheets reuse V2 message requests for friendship; an accepted relationship is required for normal private conversation admission. Previously hidden server identities are never reconstructed client-side. Wallet addresses and asset privacy remain protected.

## Preview catalog
The owner explicitly requested fake data for page tuning. Only `lib/main_preview.dart` injects the in-memory catalog for Market, Mining, Launch, Wallet and related pages. All routes carry an exact-session development-preview banner. Fixtures are deterministic display examples; no real receive address, signature, broadcast, claim or provider transaction is generated. Production defaults and real session authorization are unchanged.

## Consequences
The six-tab shell and 94-route manifest replace the navigation contract only; existing provider and security gates remain in force. Production release still requires the backend migration and device validation below.

### Backend handoff before product release
Retire legacy anonymous-mode selection server-side and return ordinary permitted public profile projections for social discovery/member directories/voice rooms. Agree migration of existing users with anonymousMode=true; do not infer or disclose identities in the frontend. This branch removes the UI option and supports explicit save normalization, but cannot silently undo server privacy projection. Verify friend request acceptance and direct channel creation against the deployed V2 API/Stream on devices.

## Validation
See the task report for commands and evidence. WebAssembly is used for local browser preview because the inherited cache fingerprint uses a 64-bit integer unsupported by Dart-to-JavaScript. No core hashing change was made. Native device/provider validation is not inferred from local tests.
