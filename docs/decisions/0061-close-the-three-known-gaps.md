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
2. **Four codes map onto it.** `PERMISSION_DENIED`, `POLICY_BLOCKED` and
   `REGION_BLOCKED` become `permissionDenied`; `AUTH_STEP_UP_REQUIRED` becomes
   `stepUpRequired` (`dio_loop_v2_profile_gateway.dart`,
   `loop_v2_chain_failure.dart`). `REGION_BLOCKED` is added to
   `LoopV2Contract._kindForCode`, and the four codes are added to the `403`
   entry of every module error catalogue that can answer with them —
   `readErrors`, `chainReadErrors`, `writeErrors`, `casWriteErrors`,
   `chainIdempotentWriteErrors`, `moneyActionReadErrors`,
   `moneyActionWriteErrors` and the four Profile catalogues. Without that the
   strict parser would reject the refusal as an invalid payload and the page
   would show an error where the server stated a rule.
3. **A refusal is rendered as `LoopPermissionState`, and never offers a retry.**
   Retrying would claim the answer might change. The block states the rule, what
   did not happen, and the one alternative that exists; only the step-up branch
   offers a destination, and it is the security centre, because step-up is not
   delivered and there is nothing else to offer.
   `loopChainPermissionPurpose` owns that sentence for the chain family, and
   `LoopChainCommandPermission` renders a refused **command** on an
   already-loaded page (`LoopChainStateBlock` keeps covering a refused read).
4. **Every refusal block carries the page's own key**, so an assertion names one
   page: `profile-permission`, `profile-edit-permission`, `privacy-permission`,
   `privacy-save-permission`, `notification-preferences-permission`,
   `watchlist-save-permission`, `alerts-command-permission`,
   `send-to-permission`, `send-confirm-permission`, `swap-permission`,
   `approval-guard-permission`, `approvals-revoke-permission`, and
   `tx-result-state-permission` from the shared state block.
5. **`MoneyPolicyNotice` becomes a permission state.** It already named the six
   policy rules; it now renders them through `LoopPermissionState`, covers
   `stepUpRequired`, and takes the page's `blockKey`. Its copy is unchanged: a
   ceiling is still described as the server's grey-release limit and never as an
   adjustable wallet setting.
6. **Both Preview adapters are rewritten against the V2 contracts.**
   `MemoryWatchlistGateway` replaces the whole resource under a version CAS and
   answers a stale version with `versionConflict`; its fixture keeps one
   unreadable row, because "listed but no longer readable" is a contract case
   the editor must handle. `MemoryNotificationsGateway` always answers with all
   ten categories, keeps `security.event` locked and refuses a write that omits
   a category or sets it to `false`, and pins delivery to
   `PUSH_RUNTIME_DEFERRED` whatever is saved. Both are `LoopChainGatewayMode.preview`,
   so `LoopChainPreviewNotice` renders the visible `演示数据` label and
   `loopChainPreviewKicker` the `开发预览` eyebrow on `watchlist-edit` and
   `notif-settings`. Only `lib/main_preview.dart` composes them; the production
   defaults stay `UnavailableWatchlistGateway` / `UnavailableNotificationsGateway`.
7. **`.ledger-card::before` is a `CustomPainter` with the CSS's own numbers.**
   `LoopLedgerTexture` carries the 9px grid, the 1px dot, the 105° mask and its
   28% transparent stop as values, and computes the mask with the CSS
   gradient-line formula. Ink at 70% under a 24% layer for the primary card,
   Lime at 50% under a 12% layer for `ledger-quiet`. It is painted, not
   animated, so reduced motion changes nothing — and the parameters are asserted
   directly instead of through a golden image.
8. **The Token Card's line is a real read.** `TokenCardSparkline` reads
   `GET /v2/market/assets/{assetId}/candles?interval=1h` through the existing
   market port and draws the last 24 closes with `LoopCandleChart`'s
   normalisation rule: the model stays `Decimal`, and the single `double`
   appears only after a value is mapped into the plot's zero-to-one space. When
   the series is unavailable, empty or unread it draws **nothing** and renders
   the server's `reasonCode` instead.
9. **The card is mounted on `token` and `community-profile`**, the two pages
   whose frozen prototype sections contain a `.tcard.tcard-signature`. On
   `token` the card carries the identity and the line only: the price, the
   change and the three metrics are each rendered once, with their source and
   observation time, in the hero and the fact list, and the prototype's own
   comment argues against a third copy of the main figure. On
   `community-profile` the card replaces the plain bound-asset panel; the
   community module still does not resolve the address, so the card states
   `价格无来源` rather than an em dash — `LoopTokenCardModel.priceReason` exists
   for exactly that, and an absent price with no stated reason now renders
   nothing at all instead of `—`.

## Consequences

- Permission coverage in the 93-page matrix goes from 53/93 to 62/93, and pages
  with all five states from 52 to 61. The 31 pages still without it are static
  or component-showcase pages, the two module-0 gate projections, and the three
  pages already recorded as "requests no device permission".
- `LoopTokenCard` renders its chart slot in every state except `loading`. The
  slot's content owns its own unavailable copy, so a card with no series is
  still honest.
- `token` now shows the same reason twice when the candle series is
  unavailable — once in the card's line slot, once in the K-line terminal.
  Both are reads of the same series and both state the reason rather than draw a
  shape; `s5_market_pages_test.dart` pins both keys.
- The widened `403` catalogues mean a refusal is now parsed rather than rejected
  on every module. No other status or code was added.

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
  the labelled surfaces, and the production ports staying fail-closed.
- `test/loop_ledger_texture_test.dart` — the CSS parameters, the grid, the mask
  ramp, and reduced motion.
- `test/loop_sparkline_test.dart` — the 24-close window, the normalisation, an
  unchanged price, `Decimal` precision a `double` would lose, and the drawn /
  not-drawn states on `token` and `community-profile`.
