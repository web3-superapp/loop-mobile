# Adopt the 93-route manifest and retire the 103-surface catalog

## Status

Accepted on 2026-09-07. This supersedes the migration-inventory role of the
103-surface catalog in decision 0048 and `docs/product-decisions.md`. Provider,
security, truth-source, and Preview boundaries from earlier decisions remain
active.

## Context

The 2026-09-01 product package freezes 93 routes across eight modules with the
five primary destinations Community, Mining, Launch, Market, Wallet and
`community` as the post-login route. The current router still mounts `/home`,
`/onboarding`, `/notifications`, `/onramp`, `/pay/*` catalog placeholders,
`/auth/wallet/seed*`, retained `/perp/*` redirects, and 21 auto-generated
catalog placeholder routes that have no counterpart in the frozen product.

Two prototype builds exist. Only the cliview.org build matches the handover
fingerprint (SHA-256 `bdbe1832…`, 93 screens). The workspace keeps a verified
copy at `LOOP/docs/prototype/loop-v2.html`; `reference/legacy-prototype/` (42
screens) is older history.

## Decision

- `docs/product/routes-manifest.json` is the only route inventory. Every slug
  maps to exactly one go_router path; the router test asserts that the set of
  product paths equals the manifest and that no retired path is mounted.
- The retired paths are removed from product navigation in the next step
  (workspace step 1). `/home` and `/launchpad` keep their redirects to
  `/community` and `/launch` for installed-client compatibility only; every
  other retired path resolves to the unmatched handler and lands on
  `/community` with a logged routing error.
- Retained Perp source stays unmounted history until a separate cleanup
  decision deletes it. It must not be relabelled or reused.
- Visual restoration uses the frozen prototype section
  `<section id="scr-<slug>">` for each slug. The Vercel build is not a
  reference.
- The design tokens, fonts (Sora, Noto Sans SC, IBM Plex Mono), SVG sprite and
  token/network/brand assets are introduced in workspace step 1 from the
  prototype; until then the Material icon set remains a placeholder.

## Consequences

- `lib/core/navigation/route_manifest.dart` is the single Dart mirror of the
  manifest; `lib/app.dart` mounts its 93 paths plus the two compatibility
  redirects and an explicit, tested list of supplementary implementation
  routes (Stream channel deep links, friend/group creation, local signing
  review, guarded chat previews) that have no slug yet.
- Retired locations (`/onboarding`, `/notifications`, `/onramp`, Pay
  sub-routes, seed reveal/verify, wallet import, `/home/*`, `/perp/*`,
  copy permissions, rewards, `/inventory`) resolve to the unmatched handler,
  are recorded in `LoopRoutingErrorLog` and land on `/community`.
- Unimplemented slugs mount `LoopPendingSurface` so every route is reachable
  without fixtures; `surface_catalog.dart` and the catalog screens stop being
  a routing source (the catalog file stays as read-only history for its
  reviewed delivery-truth wording).
- The notification router's legacy `/notifications` intent now lands on
  Community with a logged routing error until an in-context notice target is
  decided.

## Verification

Baseline on 2026-09-07 with the pinned Flutter 3.47.1 in `.tooling/flutter`:
`pub get --enforce-lockfile`, `dart format`, `flutter analyze`,
`check_harness.py`, and the harness unit tests pass. The shell must run
`flutter`/`dart` with `PUB_HOSTED_URL` and `FLUTTER_STORAGE_BASE_URL` unset
because the committed lockfile resolves against `pub.dev`; a mirror URL makes
`--enforce-lockfile` fail and silently rewrites the lockfile without it.
Full `flutter test` results are recorded in `LOOP/docs/modules/D0-baseline.md`.
