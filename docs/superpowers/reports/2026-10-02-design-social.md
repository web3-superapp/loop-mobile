# Social / community / profile design audit — 2026-10-02

Scope: 17 Community manifest routes, 13 Profile routes (referral belongs to participation), and existing social child routes. Applied frontend-design against the existing Ink/Lime/Chalk system. Signature: the community index opens with actual memberships, while the public identity sheet keeps relationship actions adjacent to the identity. No new financial projection, execution action, API, persistence contract, or provider path.

## Implementation and source boundaries

- Community home formerly spent a large Lime folio on a count plus a promotional discovery card. It now uses a compact title/count row and one 48+ dp discovery row. Count still derives only from joined + owned memberships with `hasBoundAsset`; discovery still opens `/community/discover`. Missing facts remain missing. Refresh, loading, offline and capability blocks remain controller-owned.
- Profile home formerly printed the identity twice (hero then identity card). The actual identity card is now first; editing, LOOP ID copy/share and original account/module reads remain intact. Participation label is explicit. Alias Next and multiline Bio/Newline keyboard intents are explicit.
- Directory, member, social request, connection, blocklist, group-information, forward, security, device, and privacy folios use existing compact sizing without decorative rings. They expose existing records sooner; no new action becomes authorized.
- Public identity sheet places original Add friend and Open DM actions in a single row directly beneath identity. Original `offersFriendRequest`, `publicProfileDirectMessageOffered`, exact target ID and backend request paths still decide availability. No Fomo PnL, holdings, biography, handle or relationship count is fabricated from the four-field public projection.
- Avatar edit uses the shared `LoopAvatarEditor` from the account agent and removes the preset grid. `LoopProfileAvatar.useLocalAvatar` defaults false and only owner instances opt in; other people's identities cannot display the owner's bytes. Preview file bytes remain session-local, and Production is explicitly unavailable until an authenticated upload contract exists. Existing reference validators stay unchanged.
- Friend children keep original request/group controllers while shortening explanatory headers and removing development-mode eyebrow copy. No accepted relationship or provider-connected state is inferred from preview.

## Route-by-route audit

| Slug / child | Original issue / inspected structure | Treatment | Verification |
|---|---|---|---|
| community | Large empty count folio and promotional band displace memberships | Compact membership header + discovery row | 360/390 first-row visibility, tap discovery and exact community route; aggregate regressions |
| chat | Existing segmented inbox and official Stream controller/list | Reviewed unchanged; preserve shared Community tab, preview list and official production path | Source audit; shared shell/inbox integration owned by root |
| search | Domain scope and keyboard search already compact | Reviewed unchanged; backend-controlled result destination kinds | Community social search regressions |
| community-discover | Large directory header before filter and rows | Compact no-ring context header | Community sort/pagination/capability regressions |
| community-profile | Existing source-backed community identity, member and mining facts | Reviewed unchanged; never borrow unsupported Fomo asset facts | Community detail/membership tests |
| community-chat | Dense two-line identity header, official Stream channel surface | Reviewed unchanged | Source audit; channelCid and membership gating retained |
| community-ai | Context brief and source-linked question/feed structure | Reviewed unchanged | Source audit; capability/state gates retained |
| community-members | Large folio before searchable roster | Compact no-ring header | Member filter, keyboard, pagination and search regressions |
| voiceroom | Role-driven controls and provider-state lifecycle | Reviewed unchanged | Source audit; microphone/leave semantics untouched |
| voiceroom-full | Host controls share voice lifecycle | Reviewed unchanged | Source audit; host authorization retained |
| dm | Existing identity-scoped conversation and official composer | Reviewed unchanged per user request | Source audit; existing DM preserved |
| dm-requests | Oversized request count/context header | Compact header | Accept/report/block result regressions |
| group | Official channel and Alias scope | Reviewed unchanged | Source audit; provider and alias isolation retained |
| group-info | Oversized group context before member/actions | Compact no-ring header | Source audit; no group permission changes |
| chat-search | Already compact search scope with controller-backed results | Reviewed unchanged | Source audit; keyboard/search scope preserved |
| chat-forward | Header context competes with selected messages/targets | Compact no-ring header | Source audit; exact selected identifiers and confirmation retained |
| chat-merge-preview | Empty merge state uses oversized folio | Compact empty-state folio; actual export layout untouched | Source audit; anonymization/export unchanged |
| profile | Identity repeated in hero + card | Remove duplicate hero; retain real identity/copy/share/edit and grouped module rows | Profile state, navigation and source-backed figure tests |
| profile-edit | Preset-avatar grid and generic keyboard behavior | Shared single avatar/upload action; Next username and multiline bio | Profile save/conflict/error/state regressions; account agent tests upload seam |
| privacy | Large context header above actual preferences | Compact no-ring header | Profile tests and source audit; CAS and allowed values unchanged |
| security | Oversized security folio | Compact existing context; no fabricated all-clear | Security pages regressions |
| devices | Oversized device folio | Compact existing context; original confirmation | Security pages regressions |
| key-export | Existing sensitive gate and compact action context | Reviewed unchanged | Security pages regressions; no export capability enabled |
| social-recovery | Existing sensitive gate and compact action context | Reviewed unchanged | Security pages regressions; no recovery capability enabled |
| notif-settings | Existing grouped category switches and security lock | Reviewed unchanged | Source audit; exact ten categories and security.event lock preserved |
| connections | Large relation summary displaces people | Compact context and existing direction chips | Follow/unfollow/DM exact-target regressions |
| blocklist | Large header displaces blocked identities | Compact context | Unblock confirmation and result regressions |
| settings | Already direct grouped setting rows without hero | Reviewed unchanged | Source audit; persistence/app-lock ownership unchanged |
| about | Build metadata/legal rows already grouped | Reviewed unchanged | Source audit; verified terms/build sources unchanged |
| support | Existing issue field, submission state, ticket detail | Reviewed unchanged | Source audit; original confirmed-submission gate |
| public-profile sheet | Three separate full-width relationship actions | Add friend + DM adjacent under identity; follow stays separate | Exact target/friend request/privacy/public-profile regressions |
| friends list | Repeated implementation vocabulary in header | Remove redundant subtitle and developer eyebrow | Friend feature regressions |
| add-friend | Long identity-boundary explanation before query | Short query purpose; existing nickname discovery only | Friend feature regressions |
| create-group | Long identity-boundary explanation before fields | Short instruction; keep accepted-friend selector | Friend feature regressions |
| friend-requests | Technical relationship explanation / service copy | Compact header and user-facing unavailable state | Friend request accept/reject/reconciliation regressions |
| group-alias | Existing immutable alias form and channel binding | Reviewed unchanged | Source audit; namespace unchanged |
| network-diagnostics | Existing explicit user-triggered probe surface | Reviewed unchanged | Source audit; no inferred connection status |

## Impact analysis

GitNexus index reports 3 commits behind HEAD; exact summaries were used with current source review. CommunityScreen/DiscoverHero LOW (1/2 direct), ProfileHome/Edit MEDIUM (7 direct each); private states LOW except ProfileHome/Edit/Privacy MEDIUM. No affected flows for those changes. PublicProfileSheetState LOW (3 direct). LoopProfileAvatar HIGH (14 direct, 3 processes, 4 modules): warned root before changing; compatibility default `useLocalAvatar=false` protects other identity consumers. No commit or push performed.

## Validation

Commands use the pinned SDK through `bin/flutter --no-pub`, `bin/dart`, and repository TMPDIR. Final targeted runs and analyzer results appended below. Physical provider/device behavior is not claimed by widget/source checks. Changed old Community tests only where they asserted the removed giant folio and its old ordering; loading still has record skeleton and controller-owned error state.

Final results:

- `bin/dart analyze lib/features/community lib/features/profile lib/features/social lib/features/chat/friends lib/features/chat/v2/chat_forward_screens.dart lib/features/chat/v2/group_screens.dart test/design_social_layout_test.dart test/design_social_avatar_test.dart` — **No issues found**.
- `bin/flutter test --no-pub test/design_social_layout_test.dart test/community_pages_test.dart test/community_public_profile_and_apply_test.dart test/profile_v2_pages_test.dart test/community_social_pages_test.dart test/friend_feature_test.dart test/friend_request_feature_test.dart test/s8_security_pages_test.dart` — **237 passed**. Includes real 360/390 viewport first-community visibility, discovery tap and exact community-ID navigation, plus save/conflict, request admission, relationship identity and sensitive-capability regressions.
- `bin/flutter test --no-pub test/design_social_avatar_test.dart` — **2 passed**. Selected owner image remains after opening/closing a peer route; peer avatar never reads owner bytes. Default owner avatar remains the same person glyph for different usernames. This is presentation/provider state verification; OS picker/file decoding and session reset are separately tested by the account agent.
- `git diff --check` — passed.
- Widget harness ground/readability probes remain active. Root owns integrated preview build, device screenshots and overall route QA; this report does not claim physical provider or device acceptance.

Browser QA follow-up: removed the remaining PROFILE EDIT / alias / PUBLIC folio from edit (home keeps its sole identity card). Editable alias is labeled 用户名; model, dirty state, advanced-version save confirmation, and bottom save callback are unchanged. Test now asserts no duplicate identity folio, a visible username field above y=400 at 390 dp width, and unchanged chip targets. Re-ran profile suite: **25 passed**; focused analyzer: **No issues found**. Source frozen for root's final preview rebuild.
