import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 本轮状态 · the LoopDynamic round card (client decision 0157)
// ---------------------------------------------------------------------------

/// What arms a round, said while none is running.
const String launch2DynamicIdleText = '价格 5 分钟内跌超 10% 将开启动态税与买入奖励';

/// How a running round ends.
const String launch2DynamicEndText = '出现一根收盘不低于开盘的 5 分钟 K 线即结束（收涨、收平或无成交都算）';

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
    '奖金池',
    launch2Usd1Label(state.potUsd1, maxFractionDigits: 4),
  );
  if (!state.armed) return <(String, String, String)>[pot];
  return <(String, String, String)>[
    (
      'drop',
      '当前跌幅',
      // A candle that ended without a trade since: the Hook reads 0 until
      // the next swap, poke or claim closes it.
      state.rollPending ? 'K 线已结束，待结算' : launch2BpsLabel(state.currentDropBps),
    ),
    pot,
    (
      'my-weight',
      '本轮我的权重',
      viewer == null
          ? '暂无'
          : share == null
          ? launch2Usd1Label(
              viewer.currentRoundWeightUsd1,
              maxFractionDigits: 4,
            )
          : '${launch2Usd1Label(viewer.currentRoundWeightUsd1, maxFractionDigits: 4)}'
                ' · 占 ${loopFormatDecimal(share, maxFractionDigits: 2)}%',
    ),
    ('candle-end', '本根 K 线结束', loopClockLabel(state.candleEndsAt)),
    ('end', '结束条件', launch2DynamicEndText),
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
        '本轮状态',
        trailing: LoopBadge(
          state.armed ? '已激活' : '未激活',
          key: ValueKey<String>(
            state.armed ? 'launch2-dyn-armed' : 'launch2-dyn-idle',
          ),
          kind: state.armed ? LoopBadgeKind.launch : LoopBadgeKind.mute,
        ),
        info: Semantics(
          button: true,
          label: '我的奖励',
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
                      '我的奖励',
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
        padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 0, 16, 4),
        detail: '跌幅按 5 分钟 K 线计算；回购买入不计奖励权重。',
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
        title: '外盘暂不可用',
        happened: reason,
        impact: '这个项目的外盘交易与奖励暂时不能进行。',
        next: '稍后点「重试」再读一次。',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 0, 16, 8),
        child: LoopButton(
          key: const ValueKey<String>('launch2-dyn-unavailable-retry'),
          label: '重试',
          block: true,
          onPressed: onRetry,
        ),
      ),
    ],
  );
}
