# LOOP — content-first application design pass

## Brief and direction

The user explicitly requested Frontend-design optimization of every page's layout, structure, UI and interaction. This extends their confirmed minimal-copy, minimal-step, unified Community/Chat and full-width market chart direction. Preserve real capabilities, routes, data provenance and irreversible-action confirmations. Implement on the current feature branch; no merge.

Subject: a mobile crypto community and asset app, for people moving between token data, conversations and wallet actions. Each page must foreground its one job. Retain the established brand rather than introducing a new template.

## Tokens

Palette: Ink #050604 (canvas), Chalk #F3F5EF (primary text), Graphite #171A16 (interactive grouping), Muted #7F897B (secondary labels), Lime #B8FF20 (selection/primary action), Danger #FF6B82 (loss/error). Existing alpha variants remain.
Typography: existing system/Noto Sans SC for Chinese display/body; existing numeric utility roles for figures. Use existing LoopType/LoopTypography ladder; no new font dependency. Restrained title weight, consistent tabular values, readable secondary text.
Layout: 16px content gutter, 8px plot gutter; 8/12/16/24 spacing; minimum44px touch targets. Compact headers, one section title per group. Keep safe-area and keyboard clearance. Lists and data align to a shared left edge, not nested cards. Forms and confirmation summaries may retain purposeful grouping.
Signature: a quiet black data-and-relationship canvas, with Lime marking where the user can act; remove giant saturated empty panels. The dominant element is the actual chart, asset amount, conversation or form—not a decorative hero.
Motion: preserve reduced-motion support; use only feedback, selection and state transition. No new ambient effect.

## Alternatives and critique

A global recolor would miss the user's spacing/flow complaint. Rebuilding every route from scratch would risk existing deep links and provider contracts. Chosen: shared primitive refinement plus explicit module-level restructuring, with an inventory of all94 routes. Do not simply reduce all font sizes or hide important facts. Use whitespace to group content; preserve44px targets while reducing decorative area. Each module still reflects its task rather than applying one dashboard-card template everywhere.

```
LIST / DATA             FORM / ACTION           CONVERSATION
Title         actions   Back  Task              Back Avatar Name actions
Filter/search           Field group            Message history
Aligned content rows    Inline validation      ...
...                     Essential review       Composer
Primary tabs            Main action + safearea Keyboard-aware actions
```

## Scope and independent ownership

Root: all-route inventory, shared theme/widgets/layout/shell, Market/Chain, system-wide QA and integration.
Social: Community/Chat/Social/Profile, including children, requests and voice layouts; preserve official Stream behavior.
Capital: Wallet/Account/System, including onboarding, money forms, signing states and failures; preserve financial gates.
Participation: Mining/Launch/Referral, including catalogue, detail, application, records and calculations; preserve typed facts and disabled writes.

## Acceptance

- All94 manifest routes mapped to a page family and review treatment, including deferred/fail-closed surfaces; no invented operational capability.
- Preserve five primary tabs, Community/Chat segment, original exact private chat identity and full-width chart pan/zoom.
- Representative360/390 responsive screenshots per module plus automated coverage of affected page families; distinguish source audit from actually rendered pages.
- Relevant behavioral tests, Dart analysis, repository harness, guarded tests when changed.
- Record concrete before/after improvements and any untested device/provider behavior without claiming production acceptance.

## User steering during implementation

- Registration and profile editing show one default avatar; no preset-selection grid. Username uses the existing Alias contract. Optional selected image is local to the explicit preview session until a reviewed backend upload contract exists; do not forge avatar references or report remote upload success.
- Fomo examples guide identity/action adjacency, dense holder/leaderboard rows and numeric alignment. Do not add unavailable financial fields or contract trading.
- Inspect LOOP's own models, controllers and permission rules before every reference-driven change. Adapt the layout to those capabilities; do not copy reference flows blindly.
