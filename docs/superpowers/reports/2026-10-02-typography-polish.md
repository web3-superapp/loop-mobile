# Typography and spacing refinement — 2026-10-02

The user requested another pass on line spacing, type size and product finish. Continue the approved frontend-design direction and existing LOOP font/color system. No new font, dependency, business flow or data field.

## Design and critique

The previous edit page stacked avatar padding and nested a filled input inside another framed surface. This created empty space and competing outlines. Common captions were also too small relative to row titles. Refine hierarchy rather than globally shrinking or enlarging everything: preserve22px page headings and44px minimum controls; group fields at24px, labels8px above input, primary row15px, amount14px, secondary12px. Use existing system/Noto Sans SC and tabular figures. Original Ink/Lime/Chalk palette stays.

## Changes

- `LoopLabel`: normal group top gap30→24, related group22→16, tight14→12; label12→13 medium with stronger secondary contrast.
- `LoopRecordRow`:4px title/subtitle separation,12px higher-contrast subtitle,14px amount and12px caption with2px separation. Retain narrow-width3:2 allocation, entire wrapping values and right alignment.
- `LoopNotice`: supporting text11→12 and4px title/body separation. Existing content and warning meanings remain.
- Profile editor: remove redundant avatar padding and outer input cards, use15px body text in username/bio and8px input/action gap. Preserve native focused input outline, counters, keyboard actions, dirty/save/conflict logic and avatar state.

## Impact

Pre-edit GitNexus: LoopLabel CRITICAL (79direct/8processes), LoopRecordRow CRITICAL (177direct/46processes), ProfileEditScreen MEDIUM (7direct). Warning given before shared edits. LoopNotice unresolved in stale index; full current source reviewed and shared component regression included. No global typography-band definitions or navigation were changed.

## Verification

Results and browser proof appended after final review. Source changes are presentation-only; original controller and resource tests remain applicable.

Final checks:92 relevant widget tests passed, including shared components, long/short row values, Profile save/conflict, wallet360/390, market reference, Community/Chat navigation and all18 participation routes at360/390. Dart analysis found no issues. Repository harness passed. Initial run exposed only an unintended label-uppercase change; restored existing uppercase behavior and reran the full affected group.

Web preview rebuilt successfully. Actual390px browser review confirmed flatter Profile fields, earlier visible form content, readable group labels, and wallet amount/subtitle hierarchy.360px Profile checked separately. Local screenshots: `.tooling/typography-profile-390.jpg`, `.tooling/typography-wallet-390.jpg`, `.tooling/typography-profile-360.jpg`. These are visual/interaction checks, not provider or native acceptance.
