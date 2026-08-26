# Use Public Hyperliquid Testnet Spot Candles

## Status

Accepted on 2026-08-26.

## Context

Decision 0017 connected the mounted Market surface to Hyperliquid Testnet's
public `spotMetaAndAssetCtxs` discovery response and deliberately left
historical charts unavailable. The Spot detail now needs attributable OHLCV
history before the private account and execution backend is ready.

Hyperliquid documents the public Info request
[`candleSnapshot`](https://hyperliquid.gitbook.io/Hyperliquid-docs/for-developers/api/info-endpoint#candle-snapshot),
whose rows contain millisecond open/close times, provider coin and interval,
String OHLCV values, and trade count. The provider documents a maximum of the
most recent 5,000 candles and assigns additional
[rate-limit weight](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/rate-limits-and-user-limits)
per 60 returned rows. A requested window can legitimately be empty or contain
gaps. Its first returned candle can open before `startTime` when that candle
overlaps the requested window, and the final candle can still be forming when
the client receives it.

## Decision

- Add a second dedicated, public, read-only Testnet adapter for `POST /info`
  with `type: candleSnapshot`. Decision 0017's `spotMetaAndAssetCtxs` adapter
  remains the only source that admits a Spot market; the candle adapter accepts
  only the exact provider `coin` copied from that resolved market. An invalid or
  absent route `spotIndex` therefore produces zero candle requests.
- Mount exactly five product periods: `1H -> 1h`, `4H -> 4h`, `1D -> 1d`,
  `1W -> 1w`, and `1M -> 1M`. Wire values are case-sensitive; monthly `1M`
  must never collapse into minute `1m`. Treat their fixed provider row
  durations as one hour, four hours, one day, seven days, and 30 days
  respectively. For every accepted row, `T - t` equals that interval's fixed
  duration minus one millisecond.
- Request an approximately 120-candle lookback for each mounted period and
  retain at most the latest 120 distinct rows after parsing. Do not request the
  provider's complete history, poll, recursively backfill gaps, or
  automatically retry. Equal provider-coin/period readers may share one
  in-flight request and successful results may remain warm briefly; period
  changes and refreshes remain explicit user actions.
- Preserve `o`, `c`, `h`, `l`, and `v` as their exact wire String together with
  a parsed `Decimal`. Reject numeric JSON values, invalid identity, malformed
  time or Decimal values, negative volume/trade count, non-positive prices, and
  inconsistent OHLC bounds. Any floating-point projection is confined to
  normalized canvas coordinates and never replaces the exact model or enters
  a market/trading calculation.
- Accept a candle when its time range intersects the requested window; do not
  require its open time to be at or after `startTime`. Accept empty history and
  gaps without fabricating rows. Exact duration validation does not change this
  overlap rule: an interval-valid first candle can start before `startTime` and
  end inside the window. Sort accepted rows by open time, deduplicate by open
  time with the later response row winning, and retain the latest 120.
- Capture a separate UTC client receipt time before response-row parsing. Keep
  candle open/close times as provider row facts, and never label client receipt
  time as an exchange snapshot. If receipt time is not after the last candle's
  close time, label that candle as still forming and warn that its OHLCV may
  change after refresh.
- Show explicit loading, empty, sanitized error, retry, refresh, and period
  states. Never substitute Preview candles, another Spot market, perpetual
  data, or an invented continuous series. A candle failure must not hide the
  already accepted public Spot snapshot.
- Keep the entire projection discovery-only. It has no account, balance, Buy,
  Sell, order, cancellation, signing, key, nonce, transfer, withdrawal, or
  execution path. `BuildPolicy.spotExecutionEnabled` remains false, and all
  private reads and mutations remain backend-owned.

## Consequences

The resolved Spot detail can render real, attributable Hyperliquid Testnet
candles without waiting for the private trading backend. Requests and retained
state stay bounded, exact financial values remain Decimal-safe, and the UI is
truthful about missing history, gaps, freshness, and a possibly unfinished
last candle.

This is not a charting terminal or execution quote. There is no pagination,
backfill, WebSocket stream, auto-refresh, indicator engine, drawing tool,
account context, order action, or Mainnet capability. The public REST contract
has been probed directly on Testnet, while rendered physical-device behavior
remains unverified until the user-owned device checkpoint is run.
