import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 本轮状态 · the LoopDynamic round card (client decision 0157)
// ---------------------------------------------------------------------------

/// What arms a round, said while none is running.
String get launch2DynamicIdleText =>
    LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicIdleText;

/// How a running round ends.
String get launch2DynamicEndText =>
    LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicEndText;

/// The round card's rows for one state, label first (decision 0159:
/// `currentDropBps`, `potUsd1`, `viewer.currentRoundWeightUsd1` and its
/// share of `roundTotalBuyWeightUsd1`, `candleEndsAt`).
List<(String key, String label, String value)> launch2DynamicRoundRows(
  Launch2DynamicPoolState state,
) {
  final viewer = state.viewer;
  final share = state.viewerSharePercent;
  final pot = (
    'pot',
    LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows,
    launch2Usd1Label(state.potUsd1, maxFractionDigits: 4),
  );
  if (!state.armed) return <(String, String, String)>[pot];
  return <(String, String, String)>[
    (
      'drop',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows2,
      // A candle that ended without a trade since: the Hook reads 0 until
      // the next swap, poke or claim closes it.
      state.rollPending
          ? LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows3
          : launch2BpsLabel(state.currentDropBps),
    ),
    pot,
    (
      'my-weight',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows4,
      // Decision 0202: no wallet, or no buy in this round, is 暂无 — not
      // 「0 USD1 · 占 0%」.
      viewer == null || viewer.currentRoundWeightUsd1 <= Decimal.zero
          ? LoopL10n.current.common_none
          : share == null
          ? launch2Usd1Label(
              viewer.currentRoundWeightUsd1,
              maxFractionDigits: 4,
            )
          : LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows5(
              loopFormatDecimal(share, maxFractionDigits: 2),
              launch2Usd1Label(
                viewer.currentRoundWeightUsd1,
                maxFractionDigits: 4,
              ),
            ),
    ),
    (
      'candle-end',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows6,
      loopClockLabel(state.candleEndsAt),
    ),
    (
      'end',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows7,
      launch2DynamicEndText,
    ),
  ];
}

/// 本轮状态: armed or not, the drop, the pot, how the round ends and the
/// reader's weight; above the official pool's figures.
class Launch2DynamicRoundCard extends StatelessWidget {
  const Launch2DynamicRoundCard({
    required this.state,
    required this.onOpenRewards,
    super.key,
    this.observedAt,
  });

  final Launch2DynamicPoolState state;

  /// 「我的奖励」: the instance's reward rounds.
  final VoidCallback onOpenRewards;

  /// When this device received [state].
  final DateTime? observedAt;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('launch2-dyn-round'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      // Decision 0166: the page's `.label` (was a 20 / 700 heading), the
      // armed badge at its end and 「我的奖励」 after it.
      Launch2SectionLabel(
        context.l10n.launch2_launch2DynamicPoolLaunch2DynRewardsLink,
        trailing: LoopBadge(
          state.armed
              ? context.l10n.launch2Creator_launch2ModelsActive
              : context.l10n.launch2_launch2DynamicPoolS,
          key: ValueKey<String>(
            state.armed ? 'launch2-dyn-armed' : 'launch2-dyn-idle',
          ),
          kind: state.armed ? LoopBadgeKind.launch : LoopBadgeKind.mute,
        ),
        info: Semantics(
          button: true,
          label:
              context.l10n.launch2_launch2DynamicPoolLaunch2DynRewardsLinkLabel,
          excludeSemantics: true,
          child: LoopPressable(
            key: const ValueKey<String>('launch2-dyn-rewards-link'),
            onTap: onOpenRewards,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: LoopTouch.minimum,
                minWidth: LoopTouch.minimum,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context
                          .l10n
                          .launch2_launch2DynamicPoolLaunch2DynRewardsLinkLabel,
                      // R17 (decision 0190 L23).
                      style: LoopTypography.withWeight(
                        LoopType.label,
                        FontWeight.w600,
                      ).copyWith(color: LoopColors.text2),
                    ),
                    const SizedBox(width: 2),
                    const LoopIcon(
                      'chevron',
                      size: 14,
                      color: LoopColors.text3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Decision 0169: the round's facts in one `.record-card` under the
      // `.label` (was loose key/value lines on the page).
      LoopRecordCard(
        key: const ValueKey<String>('launch2-dyn-round-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!state.armed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  launch2DynamicIdleText,
                  key: const ValueKey<String>('launch2-dyn-idle-line'),
                  style: LoopType.caption.copyWith(color: LoopColors.text2),
                ),
              ),
            for (final (key, label, value) in launch2DynamicRoundRows(state))
              LoopKeyValue(
                key: ValueKey<String>('launch2-dyn-$key'),
                label: label,
                value: value,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
          ],
        ),
      ),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-dyn-provenance'),
        sources: const <String>['LoopHook'],
        observedAt: observedAt,
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          4,
        ),
        detail:
            context.l10n.launch2_launch2DynamicPoolLaunch2DynProvenanceDetail,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// 费用累计 · the Hook's fee totals (client decision 0197)
// ---------------------------------------------------------------------------

/// The base buy fee total(s), by `buyFeeToken` (decision 0197): an S209
/// Hook 「买入基础税累计 x USD1」 (`summary.buyFeesUsd1`), an older one
/// 「x MEME」 (`summary.buyFeesMeme`); both rows when both totals hold
/// fees. [ticker] names the MEME (`$T`); without it the row says MEME.
List<(String key, String label, String value)> launch2DynamicBuyFeeRows(
  Launch2DynamicPoolState state, {
  String? ticker,
}) {
  final summary = state.summary;
  final usd1 = summary.buyFeesUsd1 ?? Decimal.zero;
  final meme = summary.buyFeesMeme;
  final usd1Hook = state.buyFeeToken == Launch2BuyFeeToken.usd1;
  final showUsd1 = usd1Hook || usd1 > Decimal.zero;
  final showMeme = !usd1Hook || meme > Decimal.zero;
  final label = LoopL10n.current.launch2_launch2DynamicPoolLabel;
  return <(String, String, String)>[
    if (showUsd1)
      ('buy-fees-usd1', label, launch2Usd1Label(usd1, maxFractionDigits: 4)),
    if (showMeme)
      (
        'buy-fees-meme',
        label,
        ticker == null || ticker.isEmpty
            ? '${launch2MemeFigure(meme)} MEME'
            : launch2MemeLabel(meme, ticker),
      ),
  ];
}

/// The fee totals' rows: the dynamic and base sell fees (USD1), then
/// [launch2DynamicBuyFeeRows].
List<(String key, String label, String value)> launch2DynamicFeeRows(
  Launch2DynamicPoolState state, {
  String? ticker,
}) {
  final summary = state.summary;
  return <(String, String, String)>[
    (
      'dynamic-fees',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicFeeRows,
      launch2Usd1Label(summary.dynamicFeesUsd1, maxFractionDigits: 4),
    ),
    (
      'sell-fees',
      LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicFeeRows2,
      launch2Usd1Label(summary.baseSellFeesUsd1, maxFractionDigits: 4),
    ),
    ...launch2DynamicBuyFeeRows(state, ticker: ticker),
  ];
}

/// 费用累计: what the Hook has taken since the pool opened, under the round
/// card on the project page and above the rounds on 外盘奖励.
class Launch2DynamicFeeSummaryCard extends StatelessWidget {
  const Launch2DynamicFeeSummaryCard({
    required this.state,
    super.key,
    this.ticker,
  });

  final Launch2DynamicPoolState state;
  final String? ticker;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('launch2-dyn-fees'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Launch2SectionLabel(
        context.l10n.launch2_launch2DynamicPoolLaunch2SectionLabel,
      ),
      LoopRecordCard(
        key: const ValueKey<String>('launch2-dyn-fees-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (key, label, value) in launch2DynamicFeeRows(
              state,
              ticker: ticker,
            ))
              LoopKeyValue(
                key: ValueKey<String>('launch2-dyn-$key'),
                label: label,
                value: value,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Decision 0159 · a LoopDynamic instance whose Hook cannot be read now (a
/// `503` with a LoopDynamic `reasonCode`, or `not_graduated` on a page that
/// already reads graduated). The pool panel is not offered: never the
/// OfficialTax panel, never the old router (§3.12).
class Launch2DynamicUnavailableBlock extends StatelessWidget {
  const Launch2DynamicUnavailableBlock({
    required this.reason,
    required this.onRetry,
    super.key,
  });

  /// What the server said, in zh-CN.
  final String reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('launch2-dyn-unavailable'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      LoopNotice.structured(
        title: context.l10n.launch2_launch2DynamicPoolTitle,
        happened: reason,
        impact: context.l10n.launch2_launch2DynamicPoolImpact,
        next: context.l10n.launch2_launch2DynamicPoolNext,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          8,
        ),
        child: LoopButton(
          key: const ValueKey<String>('launch2-dyn-unavailable-retry'),
          label: context.l10n.common_retry,
          block: true,
          onPressed: onRetry,
        ),
      ),
    ],
  );
}
