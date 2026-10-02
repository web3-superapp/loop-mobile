# Participation design — Mining, Launch, Referral

Scope: 18 manifest routes. Uses the approved frontend-design app spec and existing LOOP source/flow semantics. No controller, gateway, route, signing, settlement or source model was replaced. Changes are adaptive layout changes on each existing route, not transplanted reference components.

## Structure and treatment

- All owned folios use the existing compact mode. Catalogue, purchase quote and rewards use the quiet palette; Lime remains an actionable accent rather than a large unavailable-state panel.
- Mining summary is a flat data section with a bottom rule, no saturated card. Heading scales from 29/44 to 24/36, 18px inset removed within the existing 16px page gutter. Three typed metrics remain side by side. Both actions retain minimum44px targets, semantics and their original callbacks.
- Mining/Referral composite details no longer sit inside an additional rounded Graphite shell. The summary and aligned detail strip keep their existing order; detail inset changes from18px horizontal and16/17px vertical to0px horizontal and12px vertical.
- No capability gate, reason code, stale snapshot, estimate qualifier, financial confirmation or provider status is collapsed or removed. No extra transition or action was added.

| Route | Implemented treatment and logic retained |
|---|---|
| mining | Flat summary, restrained power type, direct existing rewards/assets actions; unavailable metrics and formula/snapshot labels retained. |
| mining-assets | Compact formula summary and flat detail strip; wallet holdings, weights and reference price source remain separate. |
| mining-rewards | Compact quiet claimable summary; rewards availability and claim gate unchanged. |
| mining-rank | Compact rank summary and flat strip; scope selection still reads its own ranking request. |
| mining-community | Compact community summary and flat strip; exact community identity, weighting and ranking states preserved. |
| mining-rules | Compact rule heading and flat strip; approved-version/formula disclosure and calculation semantics unchanged. |
| referral | Compact summary and flat levels band; invitation code, counts, server-verified binding and Mining-only explanation retained. |
| launch | Compact quiet catalogue header exposes segments and project list earlier; server catalogue/count/chain evidence preserved. |
| launch-detail | Compact project summary; existing rounds, track accordion, identity and actions retained. |
| launch-tier | Compact eligibility summary; tier/configuration absence remains explicit and staking callback unchanged. |
| loop-stake | Compact staking summary; unavailable staking states and financial review remain unchanged. |
| launch-trade | Compact quiet quote summary; input keyboard behavior, round selection, prepare/quote/review/signing sequence intact. |
| launch-holders | Compact holder summary; same subject, source and unavailable holder values. |
| launch-graduation | Compact graduation summary; proof/contract state remains distinct from off-chain configuration. |
| launch-history | Compact history summary; source events and existing timeline remain in original order. |
| launch-rounds | Compact rounds summary; configured and chain-read facts remain distinct, round navigation preserved. |
| loop-economy | Compact economics summary; unproven supply/tax/contract fields remain unavailable. |
| launch-apply | Compact application summary brings form earlier; owner projection, validation, status trail and four official link fields unchanged. |

## Impact and verification

GitNexus queried owning route classes and MiningSummaryHero/MiningCompositePrimary. Route results LOW except two symbols unresolved (MiningRulesScreen/MiningCommunityScreen) by stale index; MiningCompositePrimary HIGH because six Mining/Referral surfaces consume it. This was reported to the parent and checked across all18 routes at360/390. Index reports3 commits behind; impact output is supporting evidence, not an exact current dependency proof.

- `participation_design_density_test.dart`: 36 route×width cases pass. Each route renders at360/390×844 with geometry bounds and paint-ground checks. Mining actions remain at least44px tall and above550px; summary below340px. Folio heights below240px. No widget exceptions.
- Combined verification:202 tests passed across participation geometry, existing Mining/Launch/Referral behavior, Launch keyboard/copy and Launch round selection. Command: `LOOP_FLUTTER_ROOT="/Volumes/硬盘/Claude Workspace/项目/dinolabs/.toolchains/flutter" TMPDIR="$PWD/.tooling/tmp" bin/flutter test --no-pub test/participation_design_density_test.dart test/s7_mining_pages_test.dart test/s7_launch_pages_test.dart test/s7_referral_test.dart test/s83c3_launch_keyboard_copy_test.dart test/s105_launch_trade_round_selection_test.dart`.
- Additional structure and catalogue-copy verification:20 pass across `s59_mining_structure_test.dart`, `s59_mining_recorded_page_test.dart`, `s89a_launch_hero_copy_test.dart`;2 recorded-response cases skip because optional local capture artifacts are absent.
- Module Dart analysis: no issues. `git diff --check` clean for owned files.
- Raster captures exist under `.tooling/participation-design/` for mining/launch/referral at360/390. These use Flutter test fonts and verify geometry only; they do not establish real-font visual or device acceptance. Parent browser verification owns that boundary.
- Provider/device/signing production acceptance not performed; no claims about live payments or financial execution.
