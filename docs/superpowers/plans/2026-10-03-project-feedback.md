# Project feedback implementation plan

> For agentic workers: use subagent-driven-development for independent tasks and review the final integrated diff. Track each task below.

**Goal:** Implement the agreed non-contract product changes on the 6639279 visual baseline and update the contract handoff only.

**Architecture:** Reuse existing Community, Chat, Mining, Launch, Market and Wallet controllers and provider gates. Add Plaza as a primary destination, retain Mining as a child, and compose MEME and Intelligence from existing reads. Never infer platform assets from tickers, public-room access from presence, or a successful write from a local selection.

**Tech Stack:** Existing pinned Flutter/Riverpod/go_router/Stream/Privy dependencies.

- [x] Navigation and discovery: Community / Plaza / MEME / Intelligence / Wallet. Add `/plaza` to the manifest, keep `/mining` as child. Plaza paginates the existing community directory in batches of six; read each visible record's voice section with bounded fanout, distinguish unavailable from no live room, enter the existing reviewed lobby.
- [x] Intelligence and MEME: keep market overview, source-bound prices, sorting and watchlist. Move New Pairs and Smart Money to a More sheet; expose mining/user/community rankings and referral access. MEME has launch and platform-assets segments; platform membership comes only from matching Launch detail saleConfig.projectToken plus chainId and a confirmed configVersion, never ticker matching. Community asset filtering comes only from canonical boundAssetKey.
- [x] Account/community onboarding: use the backend home recommendation order, default up to five, allow deselection and skipping, join through existing gateway and confirm each returned membership; retain pending selections on partial failure. Keep Privy and recovery/security logic, expose registration invitation binding through existing Referral controller. Document service gaps for customizable referral codes, deferred install attribution and notifications rather than claiming completion.
- [x] Wallet/social: consolidate wallet management, security and settings in the wallet tab; preserve money-action availability. Reuse official Chat/friends/group/message/voice logic. List missing non-contract service contracts honestly with concrete acceptance cases.
- [x] Handoff: document three rounds (NFT whitelist / LOOP stake priority / public), inner10% outer2%, NFT100USD1, destination CZ address as the project's product definition of disposal, manual execution preferred, consensus/power pools, 900-day emission, launch thresholds and unresolved contract addresses/pool/LP decisions. No contract implementation.
- [x] Verification: test navigation, visible directory scope, recommendation deselection and partial failure, More-only discovery, exact asset membership and wallet callbacks. Run relevant existing tests, analyze, harness, build explicit Preview, inspect mobile views, final impact scan, commit and push the same feature branch.

## Final verification

165 scoped Flutter acceptance tests and 407 Python tests passed; analyze and harness passed. Full Flutter regression: 4035 passed, 3 skipped, 15 baseline failures reproduced on 6639279. Preview built and browser routes verified, including 390×844 layout. Contract code and financial authorization remain unchanged. See docs/handoff/2026-10-03-non-contract-delivery.md for results and service gaps.
