# 0115 Mobile card hierarchy and continuous lists

Date: 2026-10-03

## Status

Accepted under the user's continued request to redesign page structure and UI with frontend-design after reviewing the current implementation. Refines 0114 and the 6639279 card baseline; does not restore rejected later commits.

## Context

The user rejected flat presentation and desktop page controls, then clarified Chat as the first primary destination and Plaza as the owner of Community/Voice sections. Existing UI mixed title navigation with content filters and spent too much space on ordinary summaries.

## Decision

Keep the five destinations and their source contracts. Restore distinct neutral cards for actual records, reserve Lime for selection and primary actions, and use Chalk for the wallet's main balance. Quiet folios and ordinary record/surface cards use Graphite/elevated grounds instead of tinting every block Lime. Section headings become 18 logical pixels, page headings 24, record support copy 13 and record values 16. Platform fonts and tabular figures remain; no new font dependency. A folio may accept an optional headingStyle for a page's main balance, but always derives its foreground color from the actual ground.

Wallet account tools are compact and separate from holdings. Community and Plaza emphasize records; MEME and Intelligence use full-width primary switches apart from secondary filters and toolbar actions. Shared primitives also carry the presentation into child screens. Capability, freshness, signing and unknown-state facts remain authoritative.

Plaza, platform MEME and community assets are continuous vertical feeds. A forward gesture near the end loads the next bounded batch and appends records. Pulling at the top re-reads the feed. There are no previous/next controls or page counters. Partial batches are filled before advancing; duplicate/in-flight/end guards and account/gateway invalidation remain. An append failure retains visible rows, suspends automatic reads and offers explicit retry. Source cursors remain internal transport details, not navigation controls.

This adapts [Apple list behavior](https://developer.apple.com/documentation/swiftui/lists), [Apple scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views) and [Android dynamic lists](https://developer.android.com/develop/ui/views/layout/recyclerview) to existing Flutter scaffolds. It does not claim that either guideline universally prohibits paged content or that a Web Preview proves real-device accessibility acceptance.

## Verification boundary

Run shared component, mobile layout and gesture tests, static analysis, harness and regression checks. Review 320/390 logical-pixel browser views. Native provider, assistive-technology and physical-device acceptance remain separate. Contract economic changes stay in the handoff document.

## Consequences

The dock keeps five destinations with Chat first. Community management becomes a child page. Full-width underlined page sections and compact list filters express different roles. Touch targets are at least 48 logical pixels. Feed append includes drag inertia and has an accessible load-more fallback; failed refreshes retain records and retry the exact failed batch. Providers and real-device acceptance are unaffected by presentation checks.
