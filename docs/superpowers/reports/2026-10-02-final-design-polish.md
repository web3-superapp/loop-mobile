# Final app design polish — 2026-10-02

Direction and scope: decision0113. Builds on the94-route source inventory in `2026-10-02-frontend-design-coverage.md`; no route or controller is replaced.

## Coverage

- Identity and account steps: shared input fill, action typography and visible tap/focus feedback; validation and consent remain unchanged.
- Community and Chat: compact editorial title tabs, Lime discovery entry, mineral-green record groups. Stream conversation rendering and message state stay provider-owned.
- Market: record surfaces and shared filter styling inherit the palette; existing custom full-width K-line and dense quote layouts are retained.
- Wallet: sourced hero figures, record surfaces, actions and form controls inherit the new hierarchy; confirmation and signing gates unchanged.
- Mining: flat tinted summary with Lime numeric power, same three sourced metrics and callbacks.
- Launch and Referral: compact primary and record surfaces inherit depth; same catalogue, eligibility, prepare and confirm flow.
- Profile and Settings: shared fields, record groups and actions inherit the treatment, with the previous default/upload avatar flow unchanged.
- System states: same shared control style; no missing data, error or permission state is hidden.

## Self-critique

A palette alone would not fix the Community first-screen hierarchy. Its white full-width segment was heavier than its content; replacing it with underlined tabs makes the discovery entry the deliberate point of contrast. The entry stays below80px at normal mobile scale, preserving the previous density contract. Quiet folios previously used an olive glow plus a bright outline; both now become a stable green/black alpha-blended plane with a restrained white edge. Brand colour is concentrated on content and action. Buttons receive14px labels rather than an indiscriminate enlargement of all typography.

## Verification record

Main affected group:196 passes; the two community height assertions passed on the focused rerun after restoring the below80px discovery entry (198 cases covered). Dart analysis: no issues; repository harness: passed. Intermediate cross-domain group:617 passes and one pre-existing stale DM copy expectation; that expectation was updated to the already-shipped literal and its focused rerun passed. The final three-colour/type changes trigger a fresh combined regression below. Initial tests exposed historical decoration-tree assertions, a2px Ink padding regression, and the ground probe's inability to read Ink decoration. The implementation was simplified to DecoratedBox outside transparent Material, preserving geometry and observable background contrast while allowing ripple above the decoration. Native header weight remains600. Confirmed exFAT AppleDouble sidecar files were removed before source-scan tests.


## User steering incorporated

The final palette is restricted to green, white and black. Removed the independently introduced Pine/Sage tones; all new surfaces derive from existing Lime, Chalk and Ink alpha blends. Removed legacy blue/orange/red UI accent values, multicolour generated chat-avatar seeds and non-brand voice-room fills. Authentic image content is not recoloured. Gains/losses still carry their signs and canonical values. Information hierarchy is reinforced by22px bold page titles,16px row titles,14px semibold section titles,14px action labels and11–13px auxiliary copy; Mining's9–10px labels were enlarged. Final tests and browser captures below supersede the earlier intermediate palette evidence.


## Final verification

- Combined final palette/type regression:900 passed,4 failed initially. Two failures were low-contrast generated-avatar edges (fixed to the shared white edge); two were source scanners attempting to decode a newly-created macOS AppleDouble sidecar as Dart. Removed only confirmed metadata. The complete affected Chat navigation and Stream appearance group then passed18/18, covering all4 failures. Combined unique coverage:904 cases across30 test files. Includes narrow360/390 layouts, shared surfaces, community, identity, wallet/market, financial confirmations, mining/launch/referral, unavailable/offline/error states, candle interaction and reduced-motion components.
- Source colour audit found no remaining blue/red/orange/purple UI colour-literal candidates in Dart. Theme regression locks the four historical accent aliases to Lime or Chalk. Identity image assets are content and retain their own branding.
- Dart analysis: no issues. Format and Git whitespace checks passed. Repository harness passed after required decision headings were corrected.
- Final Preview rebuilt with Flutter WASM; only the temporary8767 compiler server was stopped, persistent8766 stays available. No production/device/provider acceptance claimed.

- Final browser checks: Community, Chat, Market and Mining at390px, Profile edit at360px. No visible horizontal overflow on the checked layouts. Screenshots: `.tooling/three-color-{community,chat,market,mining}-390.jpg` and `.tooling/three-color-profile-360.jpg`. Restored the normal viewport and left Community open.
- Staged impact scan:15 files,22 symbols,12 processes, HIGH shared-component impact; changes are limited to theme, typography and presentation plus supporting tests/docs. No controller or source-model flow added.
