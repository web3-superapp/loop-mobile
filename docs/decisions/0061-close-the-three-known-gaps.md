# 0061 · Close the three carried-over gaps: Permission contract, Preview V2 adapters, two visual details

## Status

Accepted 2026-09-09. Extends decisions 0053 and 0057.

## Context

Three items were carried forward, each with its reason recorded at the time:

- **Permission had no model.** `LOOP/docs/acceptance/93-pages.md` §3 recorded
  Permission as the only state 40 pages still lacked, and stated the reason for
  the funds pages, `profile-edit` and `privacy`: `ProfileGatewayFailureKind` and
  `PrivacyGatewayFailureKind` had no `permissionDenied` / `stepUpRequired`
  member, so the state could not be produced at all. The Profile transport's
  error catalogues did not list `403` either, so a refusal would have been
  parsed as an invalid payload.
- **Preview lost two surfaces.** Decision 0057 removed the V1 Watchlist and
  notification-preference Preview adapters with the modules they implemented
  and deliberately deferred rewriting them: an unavailable Preview surface is
  truthful, a fixture written against a retired contract is not.
- **Two visual details were unbuilt.** `.ledger-card::before` (the dot texture)
  had no Flutter counterpart, and the Token Card's small line existed only as
  an owner-supplied widget, with the only real chart being the full
  `LoopCandleChart` on `token` and `chart-full`.

## Decision

1. **Permission is "the server refused", never a device permission.**
   `ProfileGatewayFailureKind` and `PrivacyGatewayFailureKind` gain
   `permissionDenied` and `stepUpRequired`; `LoopResourcePhase` gains a
   `permission` branch. `LoopChainFailureKind` already carried both, so the
   Watchlist, alerts, notification-preference and money ports needed no new
   members — only pages that render them.
2. **Four codes map onto three kinds.** `PERMISSION_DENIED` and
   `POLICY_BLOCKED` become `permissionDenied`; `AUTH_STEP_UP_REQUIRED` becomes
   `stepUpRequired`; `REGION_BLOCKED` gets its **own** kind, `regionBlocked`,
   because it is refused by jurisdiction rather than by account — its copy must
   not suggest switching account or asset, since neither can change the answer
   (`dio_loop_v2_profile_gateway.dart`, `loop_v2_chain_failure.dart`, and the
   three failure enums). All three render the same Permission state.

3. **The `403` allowlists are not widened.** A first pass added all four codes
   to every catalogue; that was reverted to the combinations the backend
   actually answers with, because a client allowlist wider than the server's
   contract turns a genuinely invalid payload into a rendered refusal. The
   catalogues therefore stay exactly as `loop-api` defines them:

   | 403 code | catalogues that list it | routes |
   | --- | --- | --- |
   | `PERMISSION_DENIED` | `writeErrors`, `casWriteErrors`, `chainIdempotentWriteErrors`, communication `readErrors` | community / social / launch / referral writes; chain, watchlist, alerts and notification writes; chat and voice reads |
   | `POLICY_BLOCKED` | the same three write catalogues + `moneyActionReadErrors`, `moneyActionWriteErrors` | the above, plus every wallet-intent, swap and approval read and write |
   | `AUTH_STEP_UP_REQUIRED` | security `commandErrors` only | `/v2/security` device and session commands |
   | `REGION_BLOCKED` | none | it is not an HTTP error: the client-policy read carries the region decision as a `restriction.reasonCode` payload field (`system_region_truthfulness_test.dart:49`) |

   Read catalogues (`readErrors`, `chainReadErrors`) and the four Profile
   catalogues list no `403` at all.
4. **A refusal is rendered as `LoopPermissionState`, and never offers a retry.**
   Retrying would claim the answer might change. The block states the rule, what
   did not happen, and the one alternative that exists; only the step-up branch
   offers a destination, and it is the security centre, because step-up is not
   delivered and there is nothing else to offer.
   `loopChainPermissionPurpose` owns that sentence for the chain family, and
   `LoopChainCommandPermission` renders a refused **command** on an
   already-loaded page (`LoopChainStateBlock` keeps covering a refused read).
5. **Every refusal block carries the page's own key**, so an assertion names one
   page: `profile-permission`, `profile-edit-permission`, `privacy-permission`,
   `privacy-save-permission`, `notification-preferences-permission`,
   `watchlist-save-permission`, `alerts-command-permission`,
   `send-to-permission`, `send-confirm-permission`, `swap-permission`,
   `approval-guard-permission`, `approvals-revoke-permission`, and
   `tx-result-state-permission` from the shared state block.
6. **`MoneyPolicyNotice` becomes a permission state.** It already named the six
   policy rules; it now renders them through `LoopPermissionState`, covers
   `stepUpRequired`, and takes the page's `blockKey`. Its copy is unchanged: a
   ceiling is still described as the server's grey-release limit and never as an
   adjustable wallet setting.
7. **Both Preview adapters are rewritten against the V2 contracts.**
   `MemoryWatchlistGateway` replaces the whole resource under a version CAS and
   answers a stale version with `versionConflict`; its fixture keeps one
   unreadable row carrying the contract's own `ASSET_NOT_READABLE`, because
   "listed but no longer readable" is a case the editor must handle. `MemoryNotificationsGateway` always answers with all
   ten categories, keeps `security.event` locked and refuses a write that omits
   a category or sets it to `false`, and pins delivery to
   `PUSH_RUNTIME_DEFERRED` whatever is saved. Both are `LoopChainGatewayMode.preview`,
   so `LoopChainPreviewNotice` renders the visible `演示数据` label and
   `loopChainPreviewKicker` the `开发预览` eyebrow on `watchlist-edit` and
   `notif-settings`. Only `lib/main_preview.dart` composes them; the production
   defaults stay `UnavailableWatchlistGateway` / `UnavailableNotificationsGateway`.
8. **`.ledger-card::before` is a `CustomPainter` with the CSS's own numbers.**
   `LoopLedgerTexture` carries the 9px grid, the 1px dot, the 105° mask and its
   28% transparent stop as values, and computes the mask with the CSS
   gradient-line formula. Ink at 70% under a 24% layer for the primary card,
   Lime at 50% under a 12% layer for `ledger-quiet`. It is painted, not
   animated, so reduced motion changes nothing — and the parameters are asserted
   directly instead of through a golden image. A 360x220 card holds ~900 dots,
   so the painter evaluates the mask once per dot, buckets them into
   `LoopLedgerTexture.maskSteps` quantised alpha steps and issues one
   `drawPoints` call per non-empty bucket — at most twelve draw calls whatever
   the size. It sits in a `RepaintBoundary` and is marked `isComplex: true`.
9. **The Token Card's line is a real read.** `TokenCardSparkline` reads
   `GET /v2/market/assets/{assetId}/candles?interval=1h` through the existing
   market port and draws the last 24 closes with `LoopCandleChart`'s
   normalisation rule: the model stays `Decimal`, and the single `double`
   appears only after a value is mapped into the plot's zero-to-one space. When
   the series is unavailable, empty or unread it draws **nothing** and renders
   the server's `reasonCode` instead. A page that already states that reason
   elsewhere passes `unavailableText` so the slot points at that block instead
   of repeating the sentence; `token` does, `community-profile` does not.
10. **The card is mounted on `token` and `community-profile`**, the two pages
    whose frozen prototype sections contain a `.tcard.tcard-signature`, and it
    carries the prototype's own contents. On `token` that is the full signature
    card: the `tcard-quote` (price and 24h change), the chart, and the three
    `tcard-cell` metrics — 市值 / 流动性 / 持有人. Every one of them comes from
    the same `MarketAssetDetail` the fact list below reads, and an unavailable
    one renders its `reasonCode` rather than a figure; the card's own community
    line prints the source and observation time of the quote it shows, so no
    figure appears without provenance. On `community-profile` the card replaces
    the plain bound-asset panel; the community module still does not resolve the
    address, so the card states `价格无来源` rather than an em dash —
    `LoopTokenCardModel.priceReason` exists for exactly that, and an absent
    price with no stated reason now renders nothing at all instead of `—`.

11. **The chart slot follows the prototype's own states.** Only 正常 and 已毕业
    carry a `tcard-chart`, so 识别中, 数据缺失 and 风险事实 render no slot at
    all. 数据缺失 also stops claiming `无 24H 数据`: a card that never read the
    fact says nothing about it.

## Consequences

- Permission coverage in the 93-page matrix goes from 53/93 to 62/93, and pages
  with all five states from 52 to 61. The 31 pages still without it are static
  or component-showcase pages, the two module-0 gate projections, and the three
  pages already recorded as "requests no device permission".
- `LoopTokenCard` renders its chart slot in every state except `loading`. The
  slot's content owns its own unavailable copy, so a card with no series is
  still honest.
- `token` states an unavailable candle reason exactly once, in the K-line
  terminal; the card's slot renders the short pointer instead.
  `s5_market_pages_test.dart` pins both keys and the single occurrence.
- Because the `403` allowlists were not widened, `stepUpRequired` is reachable
  only from the security module's own commands and `regionBlocked` is not
  reachable from any transport today. Both kinds and their copy exist so the
  translation table is complete the day `loop-api` adds either code to a
  catalogue; until then they are exercised at the port, not over the wire.
  `permissionDenied` on the funds pages arrives from `POLICY_BLOCKED`, which is
  what the six named policy rules already describe.
- Profile and Privacy answer no `403` at all today, so their two new members are
  produced only by an explicit port failure. They stay in the model because the
  page must render something honest the moment the server does refuse.

## Evidence

- `test/s8_chat_profile_state_pages_test.dart:582,609,715,864` — `profile-edit`
  (refusal and step-up), `privacy`, `notif-settings`.
- `test/s8_money_state_pages_test.dart:676,705,734,766,795,834` — the six funds
  pages, each asserting no error block, no signature and no handoff.
- `test/s8_chain_state_pages_test.dart:1069,1114` — a refused Watchlist save and
  a refused alert command keep what the page already read.
- `test/privacy_presentation_screen_test.dart:74` — the full
  `PrivacyGatewayFailureKind` → state map, size-checked against the enum.
- `test/s8_preview_v2_adapters_test.dart` — both adapters against the contract,
  the labelled surfaces, the production ports staying fail-closed, and a scan of
  every `.dart` file under `lib/` proving only the Preview root and the two
  adapters themselves name either class.
- `test/loop_ledger_texture_test.dart` — the CSS parameters, the grid, the mask
  ramp, reduced motion, and a draw-call ceiling asserted against a counting
  canvas that rejects any call but `drawPoints`.
- `test/loop_sparkline_test.dart` — the 24-close window, the normalisation, an
  unchanged price, `Decimal` precision a `double` would lose, and the drawn /
  not-drawn states on `token` and `community-profile`.
