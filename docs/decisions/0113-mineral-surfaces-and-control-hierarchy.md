# 0113 — Mineral surfaces and control hierarchy

Date: 2026-10-02

## Status

Accepted for the user-requested design refinement on the feature branch.

## Context

The user asked for a final app-wide pass over colour, type, layout and interaction because many pages appeared flat and monochrome. Preserve the dense layouts accepted in 0112 and LOOP's existing logic.

Three directions were considered: a multicolour domain palette, a high-contrast light/dark editorial system, and a mineral-green extension of Lime Ledger. The third preserves identity and financial colour semantics while giving content planes more separation. Reject large decorative heroes and additional marketing sections: they would undo the user's data-density priority.

## Decision

### Design tokens and signature

The user subsequently constrained the palette to green, white and black only. The only base inks are existing Ink #050604, Lime #B8FF20 and Chalk #F3F5EF; existing near-black/grey neutrals remain. Depth comes from alpha blends of these inks. Independent Pine/Sage hex values were removed before completion. Compatibility market/chat/warning/danger names map to Lime or Chalk. Rising values remain green; falling values become white with their negative signs and candle geometry intact. This supersedes the red-down colour choice in0086, without changing directional data or unavailable meanings. Generated chat avatars and voice-room backgrounds use the same inks; authentic uploaded images and asset logos remain content.

Native system sans and bundled Noto Sans SC remain the title/body faces; tabular native figures remain for amounts, IBM Plex Mono for identifiers. Primary action labels use14px, page headings22px bold, list titles16px semibold, section headings14px semibold, secondary text12–13px. Mining summary labels previously9–10px become11–12px. No font dependency or global type-scale expansion.

Signature: compact luminous discovery entry against mineral-green records, with an Ink circular directional control. Community/Chat are editorial tabs with a Lime underline, not a large white segmented capsule. The community list remains visible in the first mobile viewport.

Layout:

    Community | Chat                  tools
    My communities                   count
    [ Lime discovery entry              > ]
    group label
    [ identity  title                 next ]

Market stays full-width; no card is added around its chart. Mining stays a flat band with a quiet directional tint and the sourced numeric power in Lime. Wallet and Launch retain their existing primary figures, compact folios and source lines.

## Implementation boundaries

- Extend shared surfaces, native segmented controls, inputs and button typography so existing route families inherit consistent treatment.
- Explicit card background overrides and light-ground ink remain authoritative.
- Put tappable decoration outside its transparent Material so ink feedback is visible; preserve geometry, callbacks, disabled semantics and44px minimums. Use standard ripple feedback, no new autonomous animation or timer.
- Preserve five primary destinations, community-owned Chat, Stream routing, source facts, identity rules, financial confirmations and the existing reduced-motion/navigation mechanisms.
- Do not add provider or transport code, fixture facts, route names or dependencies.

## Verification

See docs/superpowers/reports/2026-10-02-final-design-polish.md. Source-level inheritance across the94-route manifest is distinct from browser checks of selected populated pages and their widget states. Native/device/provider validation is not established by this design pass.

## Consequences

Global shared styling affects every mounted route that consumes these tokens. Colour no longer carries a separate red/amber meaning: signed figures, glyphs, literal error/warning copy and disabled semantics remain necessary. No backend/provider behavior or persisted preference changes. Source coverage and automated checks do not substitute for device acceptance.
