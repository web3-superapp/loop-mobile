# 0036 Mount Public Spot Full Chart

## Status

Accepted on 2026-08-28.

## Context

C3 `/market/chart` was still a simulated Preview surface. It accepted a display
symbol through navigation extras, silently defaulted missing input to ETH,
rendered invented candles, exposed a non-contract `15M` period, and displayed
MA/MACD/RSI selectors that changed labels without calculating an indicator.
The live C2 Spot detail already had an exact `spotIndex`, an admitted provider
coin, and the bounded public `candleSnapshot` adapter from decision 0019, but it
could not open C3.

## Decision

- C3 uses only `/market/chart?spotIndex=<canonical non-negative integer>`.
  Missing, repeated, extra, signed, padded, malformed, negative, and overflowing
  query input fails closed. Scheme/authority, fragment, and non-canonical raw
  query shapes also fail closed after URI normalization. Navigation extras and
  display symbols are not identity and cannot select a market.
- C2 constructs the location from the exact market admitted by the current
  `spotMetaAndAssetCtxs` snapshot. C3 resolves that index again from the current
  snapshot before mounting a candle reader. An invalid or stale index therefore
  causes zero candle requests and never substitutes ETH, another Spot market,
  Preview fixtures, or Perp data.
- C3 reuses the decision-0019 provider family with the admitted market's exact
  provider coin and only `1H/1h`, `4H/4h`, `1D/1d`, `1W/1w`, and `1M/1M`.
  Exact OHLCV stays String plus Decimal and floating point remains confined to
  normalized chart coordinates.
- Loading, empty, sanitized error, forming-candle, client-receipt-time, retry,
  refresh, and period states remain explicit. Pending chart work selects one I8
  chart presentation; no Preview candle is shown while data is pending.
- The screen is scrollable in portrait and landscape. Drawing, calculated
  indicators, balance, Buy, Sell, order, signing, transfer, withdrawal, and
  execution controls remain absent.
- C3 stays outside the six-destination Shell, so the chart does not render a
  bottom bar or misattribute a tab. Close pops back to C2 when C3 was pushed;
  a root deep link with no history returns explicitly to `/market`.
- No backend route, SDK, dependency, polling, automatic retry, persistence,
  account fact, native capability, or Perp product path is added.

## Consequences

C3 is now a real public Testnet Spot discovery surface and C2 can reach it with
one exact provider identity. Deep links cannot choose a market through mutable
display text or restore the legacy ETH fallback. The larger chart improves
inspection without expanding the mobile trust boundary into trading.

## Evidence

- `test/spot_market_route_test.dart` covers canonical construction and rejects
  missing, repeated, extra, signed, padded, malformed, negative, wrong-path, and
  overflowing identities.
- `test/market_screen_test.dart` covers C2-to-C3 identity, exact provider coin,
  five periods, zero-request failure closure, truthful chart loading, removal of
  Preview/indicator/execution UI, and portrait/landscape layouts at 200% text.
- `test/app_navigation_test.dart` covers the real router, legacy extra and
  malformed-query failure closure, absence of the Shell on C3, and root-link
  Close fallback to Market.
- The focused route, Market, and application-navigation files passed all 50
  tests on 2026-08-28.
- The full Flutter suite passed all 579 tests, Harness validation passed, and
  the Python mutation suite passed all 214 tests on 2026-08-28.
- Formatting and analysis passed for all eight changed Dart files. The
  repository-wide checks reported only the two pre-existing user-owned files:
  one formatting difference in `lib/widgets/loop_ui.dart` and one info lint in
  that file plus one info lint in `test/loop_perp_providers_test.dart`.
- No native build, simulator, interactive run, physical-device validation, or
  package artifact was produced for this slice.
