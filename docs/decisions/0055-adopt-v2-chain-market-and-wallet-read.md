# 0055 · Adopt the V2 chain, market and wallet-read modules

## Status

Accepted 2026-09-08. Retires the mounted Hyperliquid Spot Market slice, the
`SpotMarketRoute` identity, the Preview Net Worth / wallet-asset /
wallet-history slices, the Preview Watchlist adapter and the V1
notification-preference module.

## Context

Step 5 (S5) connects `loop-api` decisions 0033 and 0034 — the `chain`,
`wallet`, `market`, `watchlist` and `notifications` module gates — and rebuilds
nineteen frozen-prototype pages on the step-1 component library: the nine
Market pages (`market`, `token`, `chart-full`, `token-holders`,
`token-trades`, `watchlist-edit`, `alerts`, `new-pairs`, `smart-money`), the
seven read-only Wallet pages (`wallet`, `networth`, `asset`, `receive`,
`wallets`, `tx-history`, `networks`), `notif-settings`, and the context
notification entry points on `token` and `alerts`.

Six constraints shaped the result:

- **A number without provenance is not a fact.** Every market value arrives as
  the same six-field object — `{value, source, fetchedAt, ttlSeconds, quality,
  reasonCode}` — and `quality` is one of `fresh | stale | derived | proxied |
  unavailable`. A provider outage is not an HTTP error: the request succeeds
  and the affected block arrives `unavailable`. Rendering `0`, `—` or a cached
  figure for any of them would invent a fact the server refused to state.
- **"Read failed" and "holds none" are different facts.** The balances
  response keeps one row per readable registry asset whatever happens, with a
  discriminated union under `balance`. A failed chain read that rendered as
  `0` would be indistinguishable from an empty wallet.
- **Net worth is not a balance.** The wire carries `isSpendable: false` and a
  `partial` status with an `unavailableCount`; a partial sum is the total of
  the rows that could be valued, not the account's assets.
- **A ticker is not an identity.** Two contracts can share `PEPE`. Only the
  canonical CAIP `assetId` may address an asset, and only the opaque
  `walletId` may address a wallet — the server refuses a client-chosen
  address.
- **Precision is load-bearing.** A BSC price can carry eighteen significant
  decimals; `747.482453211647133359` and `747.482453211647133360` are equal as
  `double` and different as `Decimal`.
- **Most of the prototype has no source yet.** Holder distribution, new pairs,
  smart money, mining weight, community discussion counts, 24h net-worth
  change, native transfers, cross-chain activity, custom RPC, testnets, chart
  indicators and push delivery are all deferred. Every one of them is a
  `{status: unavailable, reasonCode}` projection or an absent capability.

## Decision

1. **Six strict transports under `lib/integrations/backend/v2/`.** `chain/`,
   `wallet/`, `market/`, `watchlist/`, `alerts/` and `notifications/` each
   parse with `LoopV2Contract.strictMap` against the frozen key set.
   `LoopV2ChainCodec` holds the decoders they share — the fact object, the
   unavailable projection, the registry summary, block numbers as `BigInt`,
   amounts as `Decimal`, and opaque cursors echoed verbatim. An unknown field,
   a wrong `contractVersion`, a missing `Cache-Control: no-store`, or a
   `correlationId` that differs from `X-Request-ID` is an invalid payload.
   The codec also refuses payloads that would be internally inconsistent: a
   `swappable: true`, an archived wallet reported as active, a proxied
   valuation with no `proxyAsset`, a `partial` net worth with a zero
   unavailable count, an open candle bucket that is not the last one, and a
   triggered alert with no `triggeredAt`.
2. **Two write shapes, kept apart.** A create (`POST /v2/alerts`,
   `POST …/read`) carries exactly one canonical UUIDv4 `Idempotency-Key` from
   `LoopV2CommandKeyring`, replayed only while the outcome stays unresolved. A
   compare-and-set (`PUT /v2/wallets/active`, `PUT /v2/watchlist`,
   `PUT/DELETE /v2/alerts/{id}`, `PUT /v2/notification-preferences`) carries no
   key at all — the server answers `400` if one is present, because the version
   is what makes the write safe to repeat. Both may carry the optional
   `X-Loop-Platform` / `X-Loop-Device-ID` annotation, resolved once from the
   session module's installation identity and simply omitted on failure.
3. **`lib/features/` depends only on ports.** `ChainGateway`,
   `WalletReadGateway`, `MarketReadGateway`, `WatchlistGateway`,
   `AlertsGateway` and `NotificationsGateway` expose domain models; every
   production default is an `Unavailable…Gateway`, and `main.dart` overrides
   them with the V2 adapters. No Dio type and no `/v2/` literal crosses into a
   feature module.
4. **Every block owns its own state.** `LoopChainResourceState<T>` plus
   `LoopChainStateBlock` render the five reviewed states per block, so a
   failing Watchlist never blanks a loaded trending list and a missing candle
   series never hides the asset's registry facts.
5. **Every rendered fact carries its provenance.** `LoopFactLine` and
   `loopFactProvenance` print "来源 X · 观察于 Y" next to the figure;
   `stale`, `derived` and `proxied` add a visible marker ("数据可能过期",
   "链上成交聚合", "以 WBNB 计价"). An unavailable fact renders
   `loopReasonCodeText(reasonCode)` — never `0`, never an em dash.
6. **`MarketAssetRoute` and `WalletRoute` replace `SpotMarketRoute`.** A page
   accepts only the exact canonical identity it produces; a missing, repeated,
   extra or malformed parameter fails closed rather than substituting an
   asset. The paths in the 93-route manifest are unchanged.
7. **`SpotCandleChart` becomes `LoopCandleChart(List<LoopCandle>)`.** OHLC
   stay `Decimal`; `double` appears only after normalisation into the plot's
   zero-to-one coordinate space. The `isOpen` bucket is drawn as a dashed
   outline and named in the semantic label, because its close, high and low
   will still move.
8. **The Swap entry point is gated on `capability.swappable` and nothing
   else.** The backend pins it to `false` until D15, so `token` renders the
   server's `SWAP_MODULE_NOT_DELIVERED` explanation instead of a buy or sell
   control.
9. **The Hyperliquid Spot slice is unmounted.** `lib/integrations/hyperliquid/`
   is retained as history — its repositories and their tests still run — but no
   product route, screen or composition root references it. The preview candle
   sketch it fed moves into the retained Perp slice.
10. **`notif-settings` moves to the ten V2 categories.** `security.event` is
    locked on: the switch is not interactive and every write submits `true`,
    because the server rejects `false` rather than ignoring it. Delivery stays
    `PUSH_RUNTIME_DEFERRED` regardless of any saved intent.
11. **A triggered price alert opens the token page.** The router gains a fourth
    kind, `price_alert.triggered`, producing `LoopPriceAlertNotificationIntent`
    from the server's `contextRoute` + `contextParams`. The `assetId` is
    validated against the canonical pattern before it can become a location.
12. **The receive QR is encoded on the device.** `lib/core/qr/loop_qr_code.dart`
    is a dependency-free byte-mode QR encoder, so the EIP-681 URI becomes a
    scannable symbol without adding a package to the locked stack. It imports
    nothing beyond `package:flutter/foundation.dart`.
13. **The capability enum follows the contract's 27 ids** with `marketRead`,
    `priceAlerts` and `notificationsFeed`.
14. **The receive QR is not verified on a device.** The encoder is covered by
    known-answer tests against reference symbols, but no physical scan has
    been performed; it stays on the external Go/No-Go list.

## Consequences

- `market` shows the Watchlist and the trending list as separate blocks, each
  with its own state, and always states the trending ordering rule. The
  prototype's "成员数 / 算力倍数" columns have no backend and are absent.
- `token` renders GoPlus security facts as sentences with their own source and
  observation time and no score, rating or conclusion. Mining weight, community
  discussion counts and the community growth rank are unavailable.
- `chart-full` offers exactly the contract's five intervals. The prototype's
  `1m` segment and its MA / EMA / MACD / RSI / drawing tools are unavailable,
  not inert controls.
- `token-holders` shows only `holderCount`. No top-holder list, concentration
  percentage or cluster label appears.
- `token-trades` marks a row as "我" from the server's `isOwn` and never shows
  a counterparty address. "大单" is a local threshold view over `amountQuote`
  and says so; "聪明钱" is a disabled segment.
- `new-pairs` and `smart-money` are whole-page unavailable with the server's
  own `reasonCode`.
- `wallet` and `networth` state the snapshot block height and its observation
  time next to every figure, show the five balance meanings separately, and
  take the gas reserve from `gasReservePolicy` instead of a constant. The
  prototype's "MFA 已开启 / 8 个有效授权 / 4 条链已启用" subtitles have no
  backend and are unavailable.
- `receive` lists only BNB Smart Chain; the other networks are absent, not
  unavailable placeholders.
- `networks` identifies each endpoint by its irreversible `endpointRef` and
  never renders or guesses an RPC URL. A chain-id mismatch fails the whole
  page.
- `tx-history` covers only indexed ERC-20 transfers; the native-transfer and
  cross-chain segments render the server's reason. An indexer that never ran is
  `INDEXING_DELAYED`, never an empty list.
- The Preview Watchlist and notification-preference adapters are gone.
  `main_preview.dart` no longer composes them, so `watchlist-edit` and
  `notif-settings` are unavailable in Preview rather than showing a labelled
  fixture. Rewriting both memory adapters against the V2 contracts is
  deliberately deferred (ruling of 2026-09-08): Preview is UI evidence, and an
  unavailable Preview surface is truthful, where a fixture written against the
  old shape would not be.
- The wallet page keeps the prototype's Pay / 兑换 / 发送 / 跨链 entries and
  opens each one's own manifest slug (ruling of 2026-09-08). Every destination
  owns its unavailable state, so the entry point stays honest without this page
  speaking for four others.
- The V1 four-intent notification-preference module and its screen are
  deleted. The V1 resource stays frozen server-side; the client only speaks V2.

## Evidence

- `test/s5_api_contract_test.dart` — strict parsing across all six transports,
  the header shapes, the two write shapes, and the internal-consistency
  refusals listed above.
- `test/s5_market_pages_test.dart`, `test/s5_wallet_pages_test.dart` — the five
  reviewed states for all sixteen Market and Wallet pages plus the truth rules
  (stale marker, unavailable reason instead of `0`, blocked asset, absent Swap
  entry, net worth not spendable, partial total, proxied native price,
  unreadable balance row, chain-id mismatch, no RPC URL).
- `test/s5_watchlist_alerts_notifications_test.dart` — the Watchlist CAS with a
  second confirmation and a preserved draft after a conflict, the exact
  threshold string, the trigger history, the locked `security.event` switch,
  and the `priceAlertTriggered` intent.
- `test/loop_candle_chart_test.dart` — the generalised chart and a value whose
  precision a `double` would lose.
- `test/loop_qr_code_test.dart` — the QR encoder against reference symbols.
