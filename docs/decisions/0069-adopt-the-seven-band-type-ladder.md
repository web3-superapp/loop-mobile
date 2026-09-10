# 0069 · Adopt the seven-band type ladder and bundle Noto Sans SC

## Status

Accepted 2026-09-10, rebased onto decisions 0070 (S16-B copy), 0071 (S16-C
components and motion) and 0072 (S16-D member search) on 2026-09-11. Supersedes the font clause of
decision 0051 ("Noto Sans SC is intentionally not bundled (17.7 MB); CJK text
falls back to the platform font stack"). No contract, request, route or state
machine moves.

Where this met 0070, 0071 and 0072: structure and motion are 0071's,
user-visible strings are 0070's, and size / weight / family are this decision's. The
components 0071 introduced take band steps — `LoopEmpty`'s inline strip and
`LoopPageBlock` on band 5 `caption(11)`, the tab cell label on band 6
`label(12, w700)`, `LoopChatHeaderStrip` on `caption(11)` (it was written at
10px, below the prototype's own on-screen floor) — and `LoopTopbar` carries
0071's `updating` badge in its action row, outside the title column, so the
80px reserve derived below is unaffected.

## Context

A user ran the profile build on a simulator and reported that the whole app's
type looked wrong. Three separate causes were behind that one sentence.

**The Chinese face was never ours.** `pubspec.yaml` shipped Sora (variable) and
IBM Plex Mono. Sora has no Han coverage, so every Chinese glyph in the product
— which is most of the product — resolved through `LoopFonts.cjkFallback`,
whose first entry was `PingFang SC`. The Latin half of a line came from a
geometric grotesque tuned to a −0.65px title tracking; the Chinese half came
from whatever the device installed, at a different x-height, a different
stroke contrast and a weight that Sora's weight axis never touched. The two
halves of a 中英 line disagreed on every screen.

**The ladder had sixteen rungs.** `lib/` carried 104 raw
`LoopTypography.sora(size:…, weight:…)` / `.mono(size:…, weight:…)` call sites
plus 24 hand-written `fontSize` / `fontWeight` / `fontFamily` literals, across
sizes 8, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 14, 15, 16, 17, 18, 19, 20
and weights 400–800 in every combination. The single most common style in the
codebase was `11px / w400` — 27 sites — which is Chinese body copy set one step
below the prototype's own on-screen floor and two weight steps below its
document weight. The prototype is explicit about both:
`body{font-size:12px;line-height:1.5;font-weight:500}` and
`.scr :is(.label,.badge,…,small){font-size:11px}`.

**Fixed width was doing prose's job.** Six sites set IBM Plex Mono on Chinese
sentences or on prose-shaped strings, and four more asked for the literal
family `'monospace'`, which bypasses the bundled file entirely and lands on the
platform's default fixed-width face.

There was also a latent correctness bug. Sora is a variable font selected
through `fontVariations`, so `style.copyWith(fontWeight: FontWeight.w700)`
changed the matching weight but left the axis pinned at the old value: the
file kept rendering the previous weight. Four call sites did exactly that.

## Decision

### 1 · Bundle Noto Sans SC, subset, as three static weights

`assets/fonts/` gains `NotoSansSC-Regular.ttf` (400), `NotoSansSC-Medium.ttf`
(500) and `NotoSansSC-Bold.ttf` (700), each 2.22 MB — 6.66 MB total, against
17.7 MB for one upstream variable file. Each is an instance of Google Fonts'
`NotoSansSC[wght].ttf` (SIL OFL 1.1, licence text at
`assets/fonts/OFL-NotoSansSC.txt`) pinned to its weight with
`fontTools.varLib.instancer`, then subset with `pyftsubset` to 8 109 mapped
codepoints / 8 126 glyphs covering:

| Range | Why |
| --- | --- |
| The complete GB2312 repertoire (7 445 codepoints: 6 763 hanzi + 682 symbols) | The decreed floor; verified as exactly zero missing |
| ASCII + Latin-1 supplement | Digits, punctuation, accented Latin in names |
| U+2000–U+206F, U+20A0–U+20BF, U+2100–U+214F | Em dash, ellipsis, curly quotes, ¥ € ₿, № ™ ℃ |
| U+2190–U+22FF, U+2460–U+24FF, U+25A0–U+25FF, U+2600–U+264F | Arrows, ≈ ≤ ≥ ±, ①②③, ■ ● ▲, ★ ☑ |
| U+3000–U+303F, U+FE10–U+FE4F, U+FF00–U+FFEF | 、。《》「」【】 and the fullwidth/halfwidth forms |
| Greek + Cyrillic basics | α β σ Δ in numeric copy |
| A short list of extra hanzi | Traditional variants and colloquial chat characters outside GB2312 |

**Static, not variable, on purpose.** A single subset variable file would be
3.99 MB — smaller — but its default instance is `wght=100` (Thin). Flutter
would then render every Chinese glyph Thin on any platform or engine build
where `fontVariations` is not applied to a family reached through
`fontFamilyFallback`. Three statics matched by `fontWeight` have no such
failure mode, and a Thin Chinese app is precisely the complaint this decision
answers. 2.7 MB of app size is the price of not gambling on that.

**Fallback order changes.** `LoopFonts.cjkFallback` now leads with
`Noto Sans SC`, ahead of `PingFang SC`. Chinese renders in the file we ship, on
every device, and the platform stack only serves scripts we do not bundle.
`LoopFonts.monoFallback` leads with it too, so a Chinese eyebrow label set in
IBM Plex Mono still lands on the bundled face rather than the system
monospace.

### 2 · Seven bands, and nothing else

`LoopTypography` exposes seven band builders. Each band owns its weight, its
line height and a tracking ratio in `em`; a call site chooses only a step size
from the band's ladder.

| Band | Step | Size | Weight | Height | Tracking | Family |
| --- | --- | --- | --- | --- | --- | --- |
| 1 display | `displayXl` | 42 | 800 | 1.15 | −0.046em | Sora → Noto Sans SC |
| 1 display | `display` | 32 | 800 | 1.15 | −0.046em | Sora → Noto Sans SC |
| 1 display | `displaySm` | 27 | 800 | 1.15 | −0.046em | Sora → Noto Sans SC |
| 2 heading | `headingLg` | 24 | 800 | 1.22 | −0.027em | Sora → Noto Sans SC |
| 2 heading | `heading` | 21 | 700 | 1.22 | −0.027em | Sora → Noto Sans SC |
| 2 heading | `headingSm` | 18 | 700 | 1.22 | −0.027em | Sora → Noto Sans SC |
| 3 title | `titleLg` | 17 | 700 | 1.35 | −0.012em | Sora → Noto Sans SC |
| 3 title | `title` | 15 | 600 | 1.35 | −0.012em | Sora → Noto Sans SC |
| 3 title | `titleSm` | 13 | 600 | 1.35 | −0.012em | Sora → Noto Sans SC |
| 4 body | `bodyLg` | 15 | 500 | 1.55 | 0 | Sora → Noto Sans SC |
| 4 body | `body` | 14 | 500 | 1.55 | 0 | Sora → Noto Sans SC |
| 4 body | `bodySm` | 13 | 500 | 1.55 | 0 | Sora → Noto Sans SC |
| 5 caption | `caption` | 12 | 500 | 1.45 | 0 | Sora → Noto Sans SC |
| 5 caption | `captionSm` | 11 | 500 | 1.45 | 0 | Sora → Noto Sans SC |
| 6 label | `action` | 14 | 700 | 1.25 | +0.008em | Sora → Noto Sans SC |
| 6 label | `label` | 12 | 600 | 1.25 | +0.008em | Sora → Noto Sans SC |
| 6 label | `eyebrow` | 11 | 600 | 1.25 | +0.15em | IBM Plex Mono → Noto Sans SC |
| 7 mono | `monoDisplay` | 32 | 600 | 1.05 | −0.008em | IBM Plex Mono |
| 7 mono | `monoTitle` | 20 | 600 | 1.15 | −0.008em | IBM Plex Mono |
| 7 mono | `monoQuote` | 17 | 600 | 1.15 | −0.008em | IBM Plex Mono |
| 7 mono | `monoValue` | 13 | 600 | 1.35 | −0.008em | IBM Plex Mono |
| 7 mono | `monoBody` | 12 | 500 | 1.50 | −0.008em | IBM Plex Mono |
| 7 mono | `monoStamp` | 11 | 500 | 1.35 | −0.008em | IBM Plex Mono |

Where the numbers come from, and where they deliberately do not:

- Sizes are the prototype's. `[data-page-title]` 24, `[data-primary-body]` 14,
  `[data-support-copy]` 12, `[data-primary-control]` 14, `.hero-num` 32,
  `.folio-heading` 27, `.tcard-quote b` 17, `.scr .row-end .v` 12.5 → 13.
- **Nothing goes below 11.** The prototype floors auxiliary text at 11px inside
  `.scr` and rewrites every inline 8/9/9.5/10/10.5px style to 11px. That floor
  was never carried into Flutter; it is now the bottom of the ladder.
- **Body weight is 500, not 400.** `body{font-weight:500}`. This is the single
  largest visible change: Chinese body copy now resolves Noto Sans SC Medium.
- **Line heights are raised over the prototype's, on purpose.** The CSS values
  (0.96 on `.folio-heading`, 1.12 on `.topbar h2`) are Latin measurements. Han
  glyphs fill their em box, so a two-line Chinese heading at 0.96 overlaps.
  Display takes 1.15 and heading 1.22.
- Every band sets `TextLeadingDistribution.even`, because a mixed 中英 line
  resolves two files with different ascent/descent ratios and proportional
  leading shifts the baseline wherever a run switches script.

The Material `TextTheme` is a view onto the bands, not a second ladder:
display{Large,Medium,Small} → band 1, headline\* → band 2, title\* → band 3,
bodyLarge → `body`, bodyMedium → `bodySm`, bodySmall → `caption`,
labelLarge → `action`, labelMedium → `label`, labelSmall → `captionSm`.
`.apply()` is no longer used on it, because it would overwrite the mono
family on the slots that carry figures.

### 3 · Fixed width is for figures only

IBM Plex Mono is permitted on numbers, amounts, addresses, IDs, timestamps and
eyebrow labels — nothing else. `LoopMono.*` survives as an alias set over band
7 plus the eyebrow, so existing call sites keep working. Prose that had drifted
onto the mono band went back to band 4/5, and the four `fontFamily: 'monospace'`
literals — which never reached the bundled file at all — are gone.

### 3b · One chat bubble size, not two

`.msg-txt` is 11px in the stylesheet and carries no `data-primary-body` tag,
but that tag was introduced by the later "97-route first-screen contract"
block and was never back-applied to the chat. The in-house bubble
(`chat_components.dart`) was already set at 14 while Stream's bubble
(`stream_chat_appearance.dart`) was at 11, so the same conversation rendered at
two sizes depending on which transport drew it. Both now take band 4 `body`
(14 / 500). A message is the primary body of the chat page; this is the one
place the ladder deliberately departs from a literal stylesheet number, and it
resolves an existing inconsistency rather than creating one.

### 4 · Restating a weight moves the axis

`LoopTypography.withWeight(style, weight)` sets `fontWeight` **and**
`fontVariations` together, and is the only sanctioned way to re-weight a style.
`copyWith(fontWeight:)` on a Sora style is a silent no-op and is now
unreachable from `lib/features/**` and `lib/widgets/**`.

### 5 · The guard

`scripts/check_harness.py :: check_typography_band_contract` fails the build
when any file under `lib/features/**` or `lib/widgets/**` contains a literal
`fontSize:`, `fontWeight:` or `fontFamily:` outside comments. The allowlist is
`lib/core/theme/loop_theme.dart` (which defines the bands) and
`lib/integrations/communication/stream_chat_appearance.dart` (which maps the
bands onto Stream's own theme objects). The same check asserts that the three
Noto Sans SC files and the OFL text exist and are registered in
`pubspec.yaml`.

## Consequences

- App size grows by 6.66 MB, all of it the Chinese face. This is not
  negotiable for a Chinese-language product; the alternative was shipping type
  we do not control.
- Text got larger nearly everywhere: 11 → 12 for secondary copy, 12 → 13 for
  body, weight 400 → 500 for prose. Two layouts had to absorb it.
  `LoopLayout.topbarHeight` (80) and `topbarContentHeight` (74) replace the
  bare `68` / `72` that used to be written in three places: the reserve is now
  derived from the ladder — 6 top padding + one 11px eyebrow line + two 24px
  title lines at 1.22 — because a page title wraps to two lines in Chinese far
  more often than in English. `LoopStatusPill` now lets its label shrink
  (`Flexible` + ellipsis) instead of forcing the pill wider than its parent,
  which also fixed two pre-existing 2× Dynamic Type overflows.
- Three widget tests had to scroll where they previously did not, because
  their target moved below a lazily built viewport. No assertion was relaxed.
- Regenerating the fonts is reproducible: instance
  `NotoSansSC[wght].ttf` at 400/500/700, subset against the charset described
  above, and rewrite the name table so each file reports family `Noto Sans SC`
  with the right `usWeightClass`, `fsSelection` and `macStyle`. The upstream
  file's own default instance is Thin, so the name table it carries after
  instancing is wrong and must be corrected.
- Decision 0051's "Noto Sans SC is intentionally not bundled" clause no longer
  holds. The `pubspec.yaml` comment that stated it has been replaced.

## Evidence

- `bin/dart format --output=none --set-exit-if-changed lib test`
- `bin/flutter analyze` — no issues
- `bin/flutter test --concurrency=2` — 2008 passing
- `python3 scripts/check_harness.py` — passes, and fails as intended when a
  `fontSize:` / `fontWeight:` / `fontFamily:` literal is planted under
  `lib/widgets/`
- `python3 -m unittest discover -s tests`
- `bin/flutter build apk --profile --dart-define-from-file=config/debug.json`
  — the three font assets land in the APK
- `test/loop_theme_test.dart :: the seven bands are the whole vocabulary`
  asserts the family, the fallback head, the weight/axis agreement, the even
  leading and the 11px floor for all 23 steps.

The six representative pages were pumped — plus the two surfaces this branch
was rebased onto, S16-C's sliding tab bar and S16-D's member search — and every
`Text` in each tree was resolved through its `DefaultTextStyle`. Nothing renders
below 11px, nothing names a family other than Sora or IBM Plex Mono, and every
style falls back to the bundled `Noto Sans SC` before any platform face:

| Surface | Distinct rendered styles (family / size / weight / height, first fallback) |
| --- | --- |
| `community` | `IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/13.0/500/h1.55/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/25.0/800/h1.15/fb:Noto Sans SC` |
| `token-detail` | `IBM Plex Mono/11.0/500/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/12.0/500/h1.50/fb:Noto Sans SC`<br>`IBM Plex Mono/13.0/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/15.0/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/17.0/600/h1.15/fb:Noto Sans SC`<br>`IBM Plex Mono/17.7/600/h1.35/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/11.0/700/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/600/h1.25/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/13.0/500/h1.55/fb:Noto Sans SC`<br>`Sora/14.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/29.0/800/h1.15/fb:Noto Sans SC` |
| `wallet` | `IBM Plex Mono/11.0/500/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/12.2/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/13.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/29.0/800/h1.15/fb:Noto Sans SC` |
| `security` | `IBM Plex Mono/11.0/500/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`IBM Plex Mono/13.0/600/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/17.0/600/h1.15/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/11.0/700/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/27.0/800/h1.15/fb:Noto Sans SC` |
| `settings` | `IBM Plex Mono/11.0/500/h1.35/fb:Noto Sans SC`<br>`IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`IBM Plex Mono/13.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/11.0/700/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/27.0/800/h1.15/fb:Noto Sans SC` |
| `community-chat` | `Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/13.0/500/h1.55/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC` |
| `community-members` | `IBM Plex Mono/11.0/600/h1.25/fb:Noto Sans SC`<br>`Sora/11.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/11.0/700/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/500/h1.45/fb:Noto Sans SC`<br>`Sora/12.0/600/h1.25/fb:Noto Sans SC`<br>`Sora/12.0/700/h1.25/fb:Noto Sans SC`<br>`Sora/13.0/500/h1.55/fb:Noto Sans SC`<br>`Sora/15.0/600/h1.35/fb:Noto Sans SC`<br>`Sora/24.0/800/h1.22/fb:Noto Sans SC`<br>`Sora/25.0/800/h1.15/fb:Noto Sans SC` |
| `tab-bar` | `Sora/12.0/700/h1.25/fb:Noto Sans SC` |

The fractional mono sizes (`12.2`, `17.7`) are the asset-mark initials, which
scale with the diameter of their circle (`figure(size * 0.34)`); `25 / 27 / 29`
are the per-archetype folio heading steps inside band 1. `Sora/11.0/700` is a
band-5 caption restated bold through `LoopTypography.withWeight`, which is the
only sanctioned way to move a weight.
