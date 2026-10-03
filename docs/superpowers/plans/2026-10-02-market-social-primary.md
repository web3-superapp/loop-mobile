# Market and Social Primary Navigation Implementation Plan

> **For agentic workers:** Use subagent-driven-development with scoped review. Independent file ownership may use dispatching-parallel-agents.

**Goal:** Deliver the user-approved market redesign, six primary destinations and friend-first social UI.
**Architecture:** Reuse Flutter route manifest, existing V2 read/command ports and official chat controllers. Keep backend identity and transaction authority intact.
**Tech Stack:** Pinned Flutter 3.47.1, Dart 3.13.1, Riverpod, go_router; no dependency changes.

## Task 1: Navigation and chat landing
Files: lib/core/navigation/route_manifest.dart, docs/product/routes-manifest.json, lib/features/shell/loop_shell.dart, lib/app.dart, lib/features/chat/chat_inbox_page.dart, lib/features/chat/stream_chat_inbox_page.dart, test/loop_shell_test.dart, test/route_manifest_test.dart.
- [ ] Impact-check symbols, add tests for /chat as second tab, root back behavior, six destination tap geometry.
- [ ] Add chat after community in JSON/Dart/tab shell, preserve 93 existing routes and promote native Chat as the 94th. Chat landing uses tabPage and provides friends/requests/add actions via mounted routes.
- [ ] Run targeted Flutter navigation/chat tests, review changes.

## Task 2: Market list and token detail
Files: lib/features/market/market_screen.dart, market_widgets.dart, token_screen.dart, market_read_models.dart if required; dedicated reference_market_widgets.dart if splitting helps; test/market_reference_layout_test.dart.
- [ ] Inspect read models and existing tests; impact-check relevant symbols.
- [ ] Add behavior tests for listing/filter/sort and detail chart/tab interaction at narrow widths.
- [ ] Build dense two-column list using sourced fields, compact chain/category controls; present missing market cap honestly without per-row new requests.
- [ ] Reorganize detail around quote/chart/social tabs and community action, preserve underlying data and transaction gates.
- [ ] Run targeted market tests and review.

## Task 3: Friend-first identity
Files: lib/features/profile/profile_v2_screens.dart, lib/features/profile/privacy/privacy_controller.dart, lib/features/social/public_profile_sheet.dart, current community/profile social callers; associated profile/privacy/friend tests.
- [ ] Trace anonymous presentation and existing requests/direct chat; impact-check.
- [ ] Remove anonymous product control/badge, use unified profile display and honest missing-profile state. Preserve wire compatibility and private-asset facets.
- [ ] Ensure reachable add-friend and accepted-friend message actions use existing gateways; label preview; test meaningful flows.
- [ ] Record backend migration requirement rather than fabricate missing identities or silently reset saved preferences.

## Task 4: Integration and handoff
Files: AGENTS.md, README.md, harness.json, docs/product-decisions.md, docs/decisions/0109-market-social-primary.md.
- [ ] Update six-tab product contract and retirement of anonymous UI, preserve data/security boundaries.
- [ ] Format changed Dart, analyze, run relevant/full tests and Python harness checks.
- [ ] Use detect_changes before commit; review against integration/v2 (main comparison includes 519 unrelated upstream commits).
- [ ] Run WASM preview and inspect market/detail/chat/community on phone and desktop.
- [ ] Save tested changes on user branch, provide exact results and backend/device limitations.

## Execution rulings
- User approval of the concrete design is sufficient; no second permission loop for this plan.
- Repo requires GitNexus impact before symbol edits. Try CLI/index; if unavailable, document tooling failure and equivalent source-level callers/process analysis, never pretend automated impact succeeded.
- Keep existing clean, dedicated clone and requested branch; do not create another worktree.

## Accepted plan review corrections
- Chat moves inside app.dart ShellRoute; both inbox implementations lose child treatment.
- Explicit Save of legacy anonymousMode=true sends false under existing CAS, preserving every unrelated setting; no load-time writes.
- User additionally requested fake data for page tuning: main_preview and new lib/preview adapters cover market, mining, launch, wallet and related pages, isolated from production.
- Additive native Chat manifest entry makes 94, not 93; preserve all original routes.
- External disk macOS sidecars are removed only from this newly cloned checkout before analysis/build; system disk is full, so test TMPDIR points to ignored .tooling/tmp on the project disk.
