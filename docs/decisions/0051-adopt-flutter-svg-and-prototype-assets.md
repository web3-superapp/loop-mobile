# Adopt flutter_svg and the frozen prototype assets, fonts and design tokens

## Status

Accepted on 2026-09-07 (workspace step 1, batch A of
`LOOP/docs/modules/S1-frontend-shell.md`). Builds on decision 0050.

## Context

The frozen cliview.org prototype (SHA-256 `bdbe1832…`) ships a 61-glyph
linear SVG sprite, SVG token and network logos, WebP brand marks, two WebP
identity atlases (people 4×3, communities 2×2) and three font families: Sora
(variable), IBM Plex Mono (Regular/Medium/SemiBold) and Noto Sans SC
(variable, 17.7 MB). Decision 0048 kept Material icons as a placeholder until
licensed assets existed in the repository. Flutter cannot render SVG without a
package; the pinned Stream Chat graph already resolves `flutter_svg` 2.3.0 as a
transitive dependency.

## Decision

- Add `flutter_svg` as a direct dependency pinned exactly to `2.3.0`, the
  version the committed lockfile already resolved transitively through
  `stream_chat_flutter`. `pubspec.lock` changed in exactly one line: the
  `flutter_svg` entry moved from `dependency: transitive` to
  `dependency: "direct main"`. No package was added, removed or re-resolved;
  `vector_graphics`, `vector_graphics_codec`, `vector_graphics_compiler`,
  `path_parsing`, `xml`, `args`, `http` and `meta` were already present at
  their current versions. `harness.json`, `check_harness.py`
  (`PINNED_DEPENDENCIES`) and the attribution register record the pin.
- Copy the prototype assets verbatim into `assets/`:
  `brand/`, `tokens/`, `networks/`, `people/`, `communities/` from
  `LOOP/docs/prototype/assets` and the 61 sprite glyphs into `assets/icons/`
  as `i-<name>.svg`. Atlases are never cut into loose images; the slot table
  from `FX.media` in `app-v2.js` lives in `lib/core/assets/loop_assets.dart`
  and `LoopIdentityAvatar` crops at render time.
- Bundle Sora (variable, weights selected through `FontVariation`) and IBM
  Plex Mono 400/500/600 under `assets/fonts/` with their OFL texts. Do not
  bundle Noto Sans SC: 17.7 MB would more than double the asset payload for a
  fallback face. CJK text falls back to the platform stack (PingFang SC,
  system Noto Sans SC on Android, Source Han Sans, Microsoft YaHei) declared
  in `LoopFonts.cjkFallback`. Revisit only with a measured rendering defect.
- Complete the design tokens in `lib/core/theme/loop_theme.dart` from the 01
  handover chapter 4 and `style-v2.css`: Panel / Card / Card 2 / Line / Line 2
  / Text 2 / Text 3 / Lime soft, spacing 8/14/22/30 with 16 page gutters,
  radii 24/20/16/12 (tab bar 23), depth `lift-primary`/`card`/`inner`/
  `primary-light`, z-axis constants, 44 touch minimum and 53 primary button.
  Flutter has no inset shadow; the inset light edge is modelled as a top edge
  colour. No blue accent is added; the legacy `market`/`chat`/`danger`/
  `warning` aliases stay only for unmigrated slices.
- Asset widgets `LoopIcon`, `LoopTokenLogo`, `LoopNetworkLogo`,
  `LoopIdentityAvatar` and `LoopBrandMark` in `lib/widgets/loop_assets.dart`
  carry a semantic label or are excluded from semantics (empty `alt`), and
  fall back to a monogram on unknown ids or load failure.

## Consequences

- `flutter_svg` becomes a direct pin the harness enforces; upgrading it later
  requires the same research and native evidence as any other pin.
- The Material icon placeholders in the shell are replaced by the sprite; other
  screens migrate glyph by glyph in their own steps.
- Text renders in Sora at the exact requested weight on both platforms;
  numbers, addresses and timestamps must use `LoopMono` styles instead of
  `fontFamily: 'monospace'`.
- Chinese copy depends on the platform CJK font. Visual QA on devices without
  a CJK font is an explicit unverified item.

## Verification

`pub get --enforce-lockfile`, `dart format`, `flutter analyze`, `flutter test`
(`test/loop_assets_test.dart`, `test/loop_theme_test.dart`,
`test/loop_shell_test.dart`), `check_harness.py` and the harness unit tests
pass; results are recorded in `LOOP/docs/modules/S1-frontend-shell.md`.
