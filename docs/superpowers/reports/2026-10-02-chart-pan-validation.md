# Chart horizontal movement correction

## Cause

The preview loaded only 60 candles while the default viewport showed 45. Horizontal PointerScroll deltas were ignored. Absolute gesture anchoring accumulated overscroll beyond either boundary, causing a dead zone before reversal took effect.

## Change

- Incremental translation for touch and native trackpad whenever scale is unchanged; clamp each movement instead of accumulating out-of-range movement.
- Horizontal PointerScroll pans; vertical wheel continues to zoom at the pointer.
- Rebase both count and cumulative scale after translation so pinch → pan → pinch retains the correct zoom baseline.
- Preview history defaults to 360 candles with explicit limits honored up to 500. Production data sources and identity remain unchanged.
- Retain real history bounds, timestamp selection, full-history moving averages and Decimal price calculations.

## Verification

`bin/flutter test --no-pub test/interactive_candle_chart_test.dart --reporter expanded`: 10 passed. Includes horizontal wheel, touch reversal, native PointerPanZoom reversal, mixed pinch/pan/pinch, 360/390 widths, selection, tiny/flat prices and averages across gaps.

Separate spec and code-quality reviews approved the scoped correction. Browser verification and remaining regression results are recorded with the app cleanup validation.

Final regression: 10-file market/chart run completed 166 passing checks; the four remaining checks expected provenance before opening the newly collapsed details. Those four now explicitly expand the details and retain their source/unit assertions. Rerunning `test/s5_market_pages_test.dart test/market_chart_selection_test.dart` passed all 42 checks, including the added collapsed-unit/expanded-source interaction. Direct Dart analysis of all touched chart/shared-page code and these tests passed without issues.

Browser validation at 390×844 and the default viewport: drag moved the 45-candle window from 316–360 to 288–332, reverse drag restored newer history, units stayed visible, and the chart rendered without overflow. Screenshots are local ignored evidence in `.tooling/chart-pan-mobile.jpg`. Compilation used `flutter run --wasm -d web-server -t lib/main_preview.dart`; the resulting build is served by the existing detached static preview server on port 8766. Standard `flutter build web --wasm` still attempts a JS fallback and fails on the repository's pre-existing 64-bit cache hash literal; no cache/hash behavior was changed.

## Follow-up: data-first chart layout

The user rejected the boxed chart in the live preview. The follow-up removes the chart card rather than making it transparent, uses 8-pixel horizontal spacing, increases the inline chart budget from 320 to 380 pixels and defaults to 60 visible candles. MA and volume share one compact readout while OHLC remains directly above the plot. Price units stay visible; optional provenance stays expandable. Fullscreen preserves its own responsive chart budget with less surrounding chrome. Final layout tests and browser measurements are recorded below after validation.

Density follow-up verification: 58 chart/reference/fidelity tests and 92 selection/S5/density/S82 tests passed. New assertions cover 360/390 pixel inline/fullscreen views, no card ancestor, near-full viewport width, meaningful chart height and historical MA alignment. Dart analysis and repository harness passed. Spec review measured 46 pixels additional canvas width (328→374 at390) and 60 pixels additional inline chart height; actual mobile browser matches the unboxed layout. Final screenshot: `.tooling/chart-density-mobile.jpg`.
