# LOOP mobile structure and UI refinement

User direction: rework the current UI with frontend-design, keep LOOP logic, use the supplied OKX references adaptively, restore useful card hierarchy, and remove web-style previous/next pagination.

## Design

The product is a mobile community and asset app. Use Chat / Plaza / MEME / Intelligence / Wallet in the user-confirmed order, with My Communities as a child, and preserve reviewed navigation, identity, provider, membership and financial controls. Build on the accepted card direction while improving hierarchy instead of retaining indistinct green-on-green treatment.

Palette: Ink #050604, Graphite #171A16, elevated #1D1E1C, Chalk #F3F5EF, Lime #B8FF20. Green marks primary actions and selection. Ordinary cards use neutral surfaces and a quiet edge. Price movement retains existing conventional up/down colors. No additional brand hues.

Typography: platform system display for headings and balances, system text for content, IBM Plex Mono only for addresses. Use size and weight together to distinguish titles, records, facts and provenance. Large balances belong to the balance card; keep the core type ladder compatible with dense market and historical message content.

Layout: one clear primary object per page. Wallet leads with net worth and money actions, then assets and concise account tools. Chat leads with existing conversations, friends and create tools. Plaza owns the Community / Voice sections and individual community cards; My Communities keeps joined records as a child. Market stays dense and charts retain width. MEME groups issuance stages and discovery without duplicating title/segment stacks. Child pages inherit shared headers, sections, rows and controls.

Signature: lime marks actions against neutral cards; data stays Chalk. Avoid decorative gradients, generic promotional heroes and invented metrics.

Interaction: vertical continuous lists with bounded appended batches, pull-to-refresh, no previous/next controls or page counters. Retain records on append failures, explicit retry, no overlapping reads, terminal-end guard, scope/owner invalidation. Preserve sheets, back, keyboard and capability restrictions. Retain at least 48 logical-pixel touch targets. Dense headers preserve title space and sticky headers grow for enlarged system text. Do not claim real-device accessibility acceptance from a web preview.

## Acceptance

Presentation and approved entry placement only. Preserve source/freshness/risk facts and reviewed callbacks. Validate page/gesture tests, shared UI/ground tests, static analysis, harness, and 390/320 logical-pixel browser layouts. Separate baseline failures from new failures. Contract handoff only; report non-contract service gaps. The document-to-code structure audit lives in docs/handoff/2026-10-03-navigation-structure-review.md.
