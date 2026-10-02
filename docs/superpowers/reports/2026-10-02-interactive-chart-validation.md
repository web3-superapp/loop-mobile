# Interactive market chart validation

The user reported that the static candle drawing was unusable and requested exchange-style behavior. This change keeps the existing feature branch and read-only market contract.

## Changed behavior

- Bounded historical viewport with pan, timestamp-anchored pinch/wheel zoom, zoom buttons and return-to-latest.
- Hover, tap and long press select real candles, including around timestamp gaps. OHLCV and UTC time follow selection; asset/interval changes reset it.
- Larger inline chart, readable price and time axes, current-price marker and crosshair. Nearby axis ticks are omitted when a current-price badge would partly cover them; narrow plots use fewer time labels.
- MA is calculated before viewport slicing and clipped geometrically outside the price domain. Off-scale latest prices use arrows instead of false in-scale lines.
- Full-screen reuses all interactions. Existing five intervals and indicators remain data-backed. No new dependencies or live exchange feed.

## Evidence

- Initial interaction and selection integration tests failed before implementation.
- 7 new chart tests cover pan/reset at 360 and 390, real two-pointer pinch, wheel zoom bounds, actual timestamps across gaps, empty/flat/tiny data, full-history MA and unclamped off-scale geometry.
- Final chart/selection integration run: 8 passed. Selection integration verifies OHLC and interval reset.
- Existing candle suite: 19 passed. Market/token/fullscreen regression suite: 87 passed.
- Scoped Dart analysis: no issues. Repository harness passed unchanged. Git diff whitespace and format checks passed.
- GitNexus impact reviewed (LOW direct symbol impacts, MEDIUM aggregate changed flows).
- Browser WASM preview inspected at 390px. Visible range changed from 16–60 to 21–54 after zoom and to 13–46 after dragging; selecting a historical candle updated time, OHLCV and crosshair. Full-screen opened successfully.

## Scope boundary

The current preview uses offline synthetic data. History navigation is limited to delivered candles, and does not pretend to load an exchange's complete historical feed. No transaction or signing path was enabled. Native-device and live-provider acceptance were not performed.
