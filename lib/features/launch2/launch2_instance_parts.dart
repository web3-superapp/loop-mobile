import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

// ---------------------------------------------------------------------------
// S285 · decision 0240: the project page's compact head, price area, holding
// strip, LoopDynamic status strip, tab bar and the public pool trade rows.
// ---------------------------------------------------------------------------

/// Whether the head's ticker carries the accent: the stage takes orders,
/// mints, or trades in the official pool (decision 0166). Every waiting or
/// held stage is stated in Chalk.
bool launch2InstanceHeadingLit(Launch2Stage stage) => switch (stage) {
  Launch2Stage.nftSale ||
  Launch2Stage.priority ||
  Launch2Stage.public ||
  Launch2Stage.graduated => true,
  Launch2Stage.upcoming ||
  Launch2Stage.snapshotPending ||
  Launch2Stage.closedNoHolders ||
  Launch2Stage.paused => false,
};

/// The words before the stage capsule's countdown (decision 0166).
String launch2InstanceStampPrefix(Launch2Stage stage) =>
    stage == Launch2Stage.upcoming ? '距铸造 ' : '剩 ';

/// The project page's head (decision 0240, was decision 0166's folio card):
/// one line and a half — the logo, the ticker and the name, the token
/// address with its copy key under them, and the stage capsule at the end
/// carrying the countdown when the stage has one. Only the capsule redraws
/// every second.
class Launch2InstanceHead extends StatelessWidget {
  const Launch2InstanceHead({
    required this.detail,
    required this.onCopy,
    required this.onElapsed,
    super.key = const ValueKey<String>('launch2-instance-folio'),
  });

  final Launch2InstanceDetail detail;
  final VoidCallback onCopy;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final next = row.nextChangeAt;
    final lit = launch2InstanceHeadingLit(row.stage);
    final stage = launch2InstanceStageLabel(detail);
    Widget capsule(String? countdown) =>
        _StageCapsule(stage: stage, countdown: countdown, lit: lit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        4,
      ),
      child: Row(
        children: <Widget>[
          MemeLogo(
            symbol: row.ticker,
            imageUrl: row.logoUrl,
            identity: detail.instanceId,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        launch2HeroTicker(row.ticker),
                        key: const ValueKey<String>('launch2-head-ticker'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.headline.copyWith(
                          color: lit ? LoopColors.yellow : LoopColors.chalk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        row.name,
                        key: const ValueKey<String>('launch2-head-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.caption.copyWith(
                          color: LoopColors.text2,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 28,
                  child: Row(
                    key: const ValueKey<String>('launch2-identity'),
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          launch2ShortAddress(row.memeAddress),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.codeSm.copyWith(
                            color: LoopColors.text2,
                          ),
                        ),
                      ),
                      // 44 dp of touch around a 28 dp line.
                      SizedBox(
                        width: LoopTouch.minimum,
                        child: OverflowBox(
                          maxHeight: LoopTouch.minimum,
                          child: LoopIconButton(
                            key: const ValueKey<String>('launch2-copy-address'),
                            icon: 'copy',
                            label: '复制代币地址',
                            color: LoopColors.text2,
                            onPressed: onCopy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (next == null)
            capsule(null)
          else
            KeyedSubtree(
              key: const ValueKey<String>('launch2-countdown'),
              child: Launch2CountdownBuilder(
                target: next,
                onElapsed: onElapsed,
                builder: (context, text) =>
                    capsule('${launch2InstanceStampPrefix(row.stage)}$text'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageCapsule extends StatelessWidget {
  const _StageCapsule({
    required this.stage,
    required this.countdown,
    required this.lit,
  });

  final String stage;
  final String? countdown;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final style = LoopTypography.withWeight(
      LoopType.caption,
      FontWeight.w600,
    ).copyWith(color: lit ? LoopColors.purpleInk : LoopColors.text2);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 136),
      child: DecoratedBox(
        key: const ValueKey<String>('launch2-stage-capsule'),
        decoration: BoxDecoration(
          color: lit ? LoopColors.purpleCapsule : LoopColors.plateRaised,
          borderRadius: LoopRadius.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              if (countdown case final String text)
                Text(
                  text,
                  key: const ValueKey<String>('launch2-stage-countdown'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureSm.copyWith(
                    color: lit ? LoopColors.purpleInk : LoopColors.text2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The price area's figure (decision 0240): 「当前价（USD1）」 over the price
/// in a large figure, and one quiet line beside it ([aside], e.g. the 24 h
/// volume or the share sold). [price] `null` says so instead of a zero.
class Launch2PriceHeader extends StatelessWidget {
  const Launch2PriceHeader({
    required this.price,
    required this.priceKey,
    super.key,
    this.aside,
    this.emptyText = '暂无成交价',
  });

  final Decimal? price;
  final String priceKey;
  final String? aside;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final figure = price;
    return Padding(
      key: const ValueKey<String>('launch2-price-area'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        8,
        LoopSpacing.page,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '当前价（USD1）',
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  figure == null ? emptyText : launch2PriceLabel(figure),
                  key: ValueKey<String>(priceKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figure == null
                      ? LoopType.body2.copyWith(color: LoopColors.text2)
                      : LoopType.statFigure,
                ),
              ),
              if (aside case final String line) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  line,
                  key: const ValueKey<String>('launch2-price-aside'),
                  maxLines: 1,
                  style: LoopType.figureSm.copyWith(color: LoopColors.text2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// `(price − avg) / avg` in percent, or `null` when either is missing or
/// the average is not positive (decision 0240).
Decimal? launch2PnlPercent({required Decimal? price, required Decimal? avg}) {
  if (price == null || avg == null || avg <= Decimal.zero) return null;
  return ((price - avg) / avg).toDecimal(scaleOnInfinitePrecision: 8) *
      Decimal.fromInt(100);
}

/// A signed figure: `+1.23` / `-1.23` / `0`.
String launch2SignedFigure(Decimal value, {int maxFractionDigits = 2}) {
  final text = loopFormatDecimal(
    value.abs(),
    maxFractionDigits: maxFractionDigits,
  );
  if (value > Decimal.zero) return '+$text';
  if (value < Decimal.zero) return '-$text';
  return text;
}

/// The rise / fall colour of a signed figure; Text2 at zero.
Color launch2SignedColor(Decimal value) => value > Decimal.zero
    ? LoopColors.rise
    : value < Decimal.zero
    ? LoopColors.fall
    : LoopColors.text2;

/// The 盈亏 cell's words: the server's unrealized profit, then the percent
/// against the average cost, or `null` when there is neither.
String? launch2PnlText({required Decimal? amount, required Decimal? percent}) {
  final parts = <String>[
    if (amount != null) '${launch2SignedFigure(amount)} USD1',
    if (percent != null) '${launch2SignedFigure(percent)}%',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// 我的持仓 under the K line (decision 0240): what the wallet holds, its
/// value, the average cost and the profit. Drawn only with a holding; a
/// server without the cost keys leaves the quantity (and the value when
/// sent) alone.
class Launch2HoldingStrip extends StatelessWidget {
  const Launch2HoldingStrip({
    required this.quantity,
    required this.ticker,
    required this.cost,
    super.key = const ValueKey<String>('launch2-holding'),
    this.valueUsd1,
    this.price,
    this.quantityKey = 'launch2-holding-quantity',
  });

  final Decimal quantity;
  final String ticker;
  final Decimal? valueUsd1;

  /// The page's current price, for the percent.
  final Decimal? price;
  final Launch2CostBasis cost;
  final String quantityKey;

  @override
  Widget build(BuildContext context) {
    final avg = cost.avgCostUsd1;
    final percent = launch2PnlPercent(price: price, avg: avg);
    final pnl = cost.unrealizedPnlUsd1;
    final pnlText = launch2PnlText(amount: pnl, percent: percent);
    final pnlSign = pnl ?? percent;
    final partial = cost.coverage == Launch2CostCoverage.partial;
    final realized = cost.realizedPnlUsd1;
    final showInfo = pnlText != null && (partial || realized != null);
    final cells = <Widget>[
      _HoldingCell(
        label: '持仓',
        value: launch2MemeLabel(quantity, ticker),
        valueKey: quantityKey,
      ),
      if (valueUsd1 case final Decimal value)
        _HoldingCell(
          label: '估值',
          value: launch2Usd1Label(value),
          valueKey: 'launch2-holding-value',
        ),
      if (avg != null)
        _HoldingCell(
          label: '成本价',
          value: launch2PriceLabel(avg),
          valueKey: 'launch2-holding-avg-cost',
        ),
      if (pnlText != null)
        _HoldingCell(
          label: '盈亏',
          value: pnlText,
          valueKey: 'launch2-holding-pnl',
          color: pnlSign == null ? null : launch2SignedColor(pnlSign),
          info: showInfo
              ? LoopInfoButton(
                  key: const ValueKey<String>('launch2-holding-pnl-info'),
                  title: '持仓盈亏',
                  sheetKey: 'launch2-holding-pnl-sheet',
                  notes: <LoopInfoNote>[
                    if (partial)
                      const LoopInfoNote(
                        key: ValueKey<String>('launch2-holding-partial-note'),
                        title: '部分持仓无成本记录',
                        body: '部分持仓为链上转入，无成本记录；成本价与盈亏只按有成本记录的部分计算。',
                      ),
                    if (realized != null)
                      LoopInfoNote(
                        key: const ValueKey<String>(
                          'launch2-holding-realized-note',
                        ),
                        title: '已实现盈亏',
                        body: '${launch2SignedFigure(realized)} USD1',
                      ),
                  ],
                )
              : null,
        ),
    ];
    return LoopRecordCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '我的持仓',
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 6),
          Wrap(
            runSpacing: 8,
            children: <Widget>[
              for (final cell in cells)
                FractionallySizedBox(widthFactor: 0.5, child: cell),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldingCell extends StatelessWidget {
  const _HoldingCell({
    required this.label,
    required this.value,
    required this.valueKey,
    this.color,
    this.info,
  });

  final String label;
  final String value;
  final String valueKey;
  final Color? color;
  final Widget? info;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 20,
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  style: LoopType.caption.copyWith(color: LoopColors.text3),
                ),
              ),
              if (info case final Widget button)
                SizedBox(
                  width: LoopTouch.minimum,
                  child: OverflowBox(
                    maxHeight: LoopTouch.minimum,
                    child: button,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          key: ValueKey<String>(valueKey),
          maxLines: 2,
          style: LoopType.figureSm.copyWith(color: color ?? LoopColors.chalk),
        ),
      ],
    ),
  );
}

/// 本轮状态 as one line under the K line (decision 0240): the armed badge,
/// the drop and the pot; a tap opens the whole round card in a sheet.
class Launch2DynamicStatusStrip extends StatelessWidget {
  const Launch2DynamicStatusStrip({
    required this.state,
    required this.onOpenRewards,
    super.key = const ValueKey<String>('launch2-dyn-strip'),
    this.observedAt,
  });

  final Launch2DynamicPoolState state;
  final VoidCallback onOpenRewards;
  final DateTime? observedAt;

  String get _line {
    final pot = '奖金池 ${launch2Usd1Label(state.potUsd1, maxFractionDigits: 4)}';
    if (!state.armed) return pot;
    final drop = state.rollPending
        ? 'K 线已结束，待结算'
        : '跌幅 ${launch2BpsLabel(state.currentDropBps)}';
    return '$drop · $pot';
  }

  Future<void> _open(BuildContext context) => showLoopSheet<void>(
    context,
    builder: (sheet) => Launch2DynamicRoundCard(
      state: state,
      observedAt: observedAt,
      onOpenRewards: () {
        Navigator.of(sheet).pop();
        onOpenRewards();
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      LoopSpacing.rowGap,
    ),
    child: Semantics(
      button: true,
      label: '本轮状态，${state.armed ? '已激活' : '未激活'}，$_line',
      excludeSemantics: true,
      child: LoopPressable(
        onTap: () => unawaited(_open(context)),
        child: Container(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: LoopColors.plate,
            borderRadius: LoopRadius.pill,
          ),
          child: Row(
            children: <Widget>[
              Text(
                '本轮状态',
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 8),
              LoopBadge(
                state.armed ? '已激活' : '未激活',
                key: ValueKey<String>(
                  state.armed
                      ? 'launch2-dyn-strip-armed'
                      : 'launch2-dyn-strip-idle',
                ),
                kind: state.armed ? LoopBadgeKind.launch : LoopBadgeKind.mute,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _line,
                  key: const ValueKey<String>('launch2-dyn-strip-line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: LoopType.figureSm.copyWith(color: LoopColors.chalk),
                ),
              ),
              const SizedBox(width: 4),
              const LoopIcon('chevron', size: 14, color: LoopColors.text3),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The tabs under the price area (decision 0240).
enum Launch2InstanceTab {
  trades('成交'),
  info('信息'),
  buyback('回购');

  const Launch2InstanceTab(this.title);

  final String title;
}

/// The page's tab bar: S279's pill bar (decision 0237) without the index
/// and the count — the chosen tab solid Purple with white words, the others
/// on the block ground.
class Launch2InstanceTabs extends StatelessWidget {
  const Launch2InstanceTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key = const ValueKey<String>('launch2-instance-tabs'),
  });

  final List<Launch2InstanceTab> tabs;
  final Launch2InstanceTab selected;
  final ValueChanged<Launch2InstanceTab> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      8,
      LoopSpacing.page,
      LoopSpacing.rowGap,
    ),
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.pill,
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: <Widget>[
              for (final tab in tabs)
                Expanded(
                  child: _InstanceTab(
                    tab: tab,
                    on: tab == selected,
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InstanceTab extends StatelessWidget {
  const _InstanceTab({
    required this.tab,
    required this.on,
    required this.onTap,
  });

  final Launch2InstanceTab tab;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: tab.title,
    excludeSemantics: true,
    child: LoopPressable(
      key: ValueKey<String>('launch2-tab-${tab.name}'),
      onTap: onTap,
      scale: false,
      child: Container(
        height: LoopTouch.minimum,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? LoopColors.purple : const Color(0x00000000),
          borderRadius: LoopRadius.pill,
        ),
        child: Text(
          tab.title,
          maxLines: 1,
          style: LoopType.button.copyWith(
            color: on ? LoopColors.onPurple : LoopColors.text2,
          ),
        ),
      ),
    ),
  );
}

/// `MM-DD HH:mm:ss` in local time: a trade's time in the 成交 list.
String launch2TradeTimeLabel(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// One public official-pool trade (decision 0240): the side in its rise /
/// fall colour and the masked trader (「匿名」 when the server could not
/// attribute it) over the time and the price; the USD1 amount over the MEME
/// amount on the right. The trader is never a link (the server sends no
/// full address).
class Launch2PublicTradeRow extends StatelessWidget {
  const Launch2PublicTradeRow({
    required this.trade,
    required this.ticker,
    super.key,
  });

  final Launch2PublicPoolTrade trade;
  final String ticker;

  @override
  Widget build(BuildContext context) {
    final buy = trade.side == Launch2Side.buy;
    final memeLine = ticker.trim().isEmpty
        ? launch2MemeCompact(trade.memeAmount)
        : '${launch2MemeCompact(trade.memeAmount)} ${loopTickerLabel(ticker)}';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: 9,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: buy ? '买入' : '卖出',
                        style:
                            LoopTypography.withWeight(
                              LoopType.body2,
                              FontWeight.w600,
                            ).copyWith(
                              color: buy ? LoopColors.rise : LoopColors.fall,
                            ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: trade.wallet ?? '匿名',
                        style:
                            (trade.wallet == null
                                    ? LoopType.body2
                                    : LoopType.codeSm)
                                .copyWith(color: LoopColors.text2),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${launch2TradeTimeLabel(trade.at)} · '
                  '价格 ${launch2PriceLabel(trade.priceUsd1)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption.copyWith(color: LoopColors.text3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                launch2Usd1Label(trade.usd1Amount),
                maxLines: 1,
                style: LoopType.figureBody,
              ),
              const SizedBox(height: 2),
              Text(memeLine, maxLines: 1, style: LoopType.figureSm),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「只看我的」: a 44 dp switch row at the top of the 成交 tab.
class Launch2MineOnlyToggle extends StatelessWidget {
  const Launch2MineOnlyToggle({
    required this.value,
    required this.onChanged,
    required this.title,
    super.key = const ValueKey<String>('launch2-trades-mine-only'),
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// What the list under it is, at the row's start.
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            key: const ValueKey<String>('launch2-trades-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopType.label.copyWith(color: LoopColors.text2),
          ),
        ),
        Semantics(
          button: true,
          toggled: value,
          label: '只看我的',
          excludeSemantics: true,
          child: LoopPressable(
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: LoopTouch.minimum,
                minWidth: LoopTouch.minimum,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: value ? LoopColors.purple : LoopColors.plateRaised,
                      borderRadius: LoopRadius.badge,
                    ),
                    alignment: Alignment.center,
                    child: value
                        ? const LoopIcon(
                            'check',
                            size: 12,
                            color: LoopColors.onPurple,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '只看我的',
                    style: LoopType.label.copyWith(
                      color: value ? LoopColors.chalk : LoopColors.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The two keys of the fixed trade bar (decision 0240): 买入 on the accent,
/// 卖出 secondary. A key with no action is drawn disabled; the reason is the
/// bar's own line above it.
class Launch2TradeKeys extends StatelessWidget {
  const Launch2TradeKeys({
    required this.onBuy,
    required this.onSell,
    super.key = const ValueKey<String>('launch2-trade-keys'),
  });

  final VoidCallback? onBuy;
  final VoidCallback? onSell;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: LoopButton(
          key: const ValueKey<String>('launch2-bar-buy'),
          label: '买入',
          primary: true,
          block: true,
          onPressed: onBuy,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: LoopButton(
          key: const ValueKey<String>('launch2-bar-sell'),
          label: '卖出',
          block: true,
          onPressed: onSell,
        ),
      ),
    ],
  );
}

/// Decision 0240 (with decision 0234's 拖动收起): a vertical drag that
/// starts anywhere in the trade sheet puts the keyboard away, whether the
/// sheet's own scroll view moves or the sheet itself is dragged. It reads raw
/// pointer moves, so it never takes part in the gesture arena: taps, the
/// sheet's drag and the scroll all behave as before.
class Launch2DragUnfocus extends StatefulWidget {
  const Launch2DragUnfocus({required this.child, super.key});

  final Widget child;

  @override
  State<Launch2DragUnfocus> createState() => _Launch2DragUnfocusState();
}

class _Launch2DragUnfocusState extends State<Launch2DragUnfocus> {
  final Map<int, Offset> _downs = <int, Offset>{};

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => _downs[event.pointer] = event.position,
    onPointerMove: (event) {
      final down = _downs[event.pointer];
      if (down == null) return;
      if ((event.position.dy - down.dy).abs() > kTouchSlop) {
        _downs.remove(event.pointer);
        FocusManager.instance.primaryFocus?.unfocus();
      }
    },
    onPointerUp: (event) => _downs.remove(event.pointer),
    onPointerCancel: (event) => _downs.remove(event.pointer),
    child: widget.child,
  );
}
