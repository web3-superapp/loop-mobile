# 0114 · Project-party feedback, recommended communities and five destinations

Date: 2026-10-03

## Status

Accepted for the user-authorized non-contract implementation. Supersedes decision 0111's primary destination order and the Community card presentation changed after commit `6639279`. Contract feedback is recorded for review only.

## Context

The project party supplied product feedback and the user approved implementing the items that do not require a contract change. The existing verified identity, membership, market, wallet and signing boundaries continue to apply. The accepted Community card presentation is the implementation at commit `6639279`.

## Decision

The five primary destinations, in order, are Chat / Plaza / MEME / Intelligence / Wallet. Product labels are 聊天 / 广场 / MEME / 情报 / 钱包. Their technical slugs remain `chat`, `plaza`, `launch`, `market`, `wallet`, with paths `/chat`, `/plaza`, `/launch`, `/market`, `/wallet`. MEME and Intelligence rename existing destinations without introducing another market or launch stack.

The user clarified the first destination as Chat on 2026-10-03. Chat is the post-login home without a Community/Chat segment; `/community` remains the child “我的社区” page. official Stream conversation identities, friends and Profile routes stay intact. Plaza gets its own destination. Mining remains `/mining` as a child route outside the dock. New Pairs and Smart Money are second-level Intelligence destinations and retain their source-scoped unavailable behavior whenever their reviewed providers are absent.

The route manifest grows from 94 to 96 entries by adding `plaza` and `community-recommendations` in the Community module, immediately after `community`. They have prototype orders 94 and 95 respectively; the existing Chat extension retains order 93. `/community/recommendations` is a child route. The original frozen source timestamp, hash and historical route order remain provenance for the imported catalog, not a claim that these two new pages existed in the prototype. JSON and Dart mirrors must agree.

Restore Community cards to commit `6639279` as the presentation baseline. After an account completes onboarding, offer the recommended-community step with five choices selected by default; each choice can be cancelled and the whole step skipped. Recommendations and memberships must come from reviewed sources. Explicit joining uses the existing backend membership command and must inspect its returned membership state before reporting success. Selecting a card never creates membership locally. Do not make a successful join or five recommendations out of missing data.

Prefer deliberate manual controls wherever the reviewed flow permits them. This does not grant a new retry for an ambiguous command, polling authority, or an automatic money action. Existing unresolved-operation holds, source/time disclosures and backend capability gates remain authoritative.

## Contract-feedback boundary

The requested 10% two-way inner-market tax and 2% two-way outer-market tax, three launch rounds (NFT whitelist, LOOP staking priority and public participation) are recorded in the project-party feedback documents. They are pending a separate contract review and explicit implementation authorization. This decision neither changes contract parameters nor enables contract deployment, minting, fees, qualification, launch trading or settlement. Existing contract behavior and backend availability must be described from their verified sources.

## Verification

Harness guards verify the 96-route JSON/Dart order, the exact five technical tab slugs and product labels, Chat fallback, compatibility redirects, retained child Mining and unchanged security boundaries. Active shell, route-manifest and Chat navigation tests use the new destination order. Historical decisions remain evidence of their original implementations; active tests mounting the current LoopApp follow this decision. Automated checks and selected widget tests are distinct from real device, provider and contract acceptance.

## Consequences

The non-contract feedback is reviewable in one current decision. New UI entry points reuse existing identity, community membership and market owners. An entry point or selected recommendation is not proof of data availability or a completed join; contract requests remain a separate deliverable.
