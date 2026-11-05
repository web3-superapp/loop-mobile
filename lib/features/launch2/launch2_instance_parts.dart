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
import 'package:loop_mobile/features/launch2/launch2_secondary_metrics.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

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
    stage == Launch2Stage.upcoming
    ? LoopL10n.current.launch2_launch2AtmosphereCountdown
    : LoopL10n.current.launch2_launch2AtmosphereCountdown2;

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
            // S370a · decision 0293: a token's face, 44 round (§9.4).
            size: Launch2SecondaryMetrics.tokenFace,
            radius: Launch2SecondaryMetrics.tokenFace / 2,
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
                            label: context
                                .l10n
                                .launch2_launch2InstancePartsLaunch2CopyAddressLabel,
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

  /// S370a · decision 0293: the home board's stage capsule (docs/58 §4 /
  /// §9.4 阶段胶囊 r4, 11 / 400) — Yellow on its soft ground while it takes
  /// orders, Text2 on white 8 % otherwise; no longer a Purple pill.
  static const BorderRadius radius = LoopRadius.stage;

  @override
  Widget build(BuildContext context) {
    final ink = lit ? LoopColors.yellow : LoopColors.text2;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 136),
      child: DecoratedBox(
        key: const ValueKey<String>('launch2-stage-capsule'),
        decoration: BoxDecoration(
          color: lit ? LoopColors.yellowSoft : LoopColors.white8,
          borderRadius: radius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                stage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.stageTag.copyWith(color: ink),
              ),
              if (countdown case final String text) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  text,
                  key: const ValueKey<String>('launch2-stage-countdown'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureXs.copyWith(color: ink),
                ),
              ],
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
    this.emptyText,
  });

  final Decimal? price;
  final String priceKey;
  final String? aside;

  /// `null` reads 「暂无成交价」.
  final String? emptyText;

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
            context.l10n.launch2_launch2InstancePartsBuild,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  figure == null
                      ? (emptyText ??
                            context.l10n.launch2_launch2InstancePartsEmptyText)
                      : launch2PriceLabel(figure),
                  key: ValueKey<String>(priceKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: figure == null
                      ? LoopType.body2.copyWith(color: LoopColors.text2)
                      // S370a · decision 0293: the page's one key figure at
                      // the power card's 30 / 700 (docs/58 §9.2, 类推).
                      : LoopType.heroFigure,
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
        label: context.l10n.common_holdings,
        value: launch2MemeLabel(quantity, ticker),
        valueKey: quantityKey,
      ),
      if (valueUsd1 case final Decimal value)
        _HoldingCell(
          label: context.l10n.launch2_launch2InstancePartsLabel,
          value: launch2Usd1Label(value),
          valueKey: 'launch2-holding-value',
        ),
      if (avg != null)
        _HoldingCell(
          label: context.l10n.launch2_launch2InstancePartsLabel2,
          value: launch2PriceLabel(avg),
          valueKey: 'launch2-holding-avg-cost',
        ),
      if (pnlText != null)
        _HoldingCell(
          label: context
              .l10n
              .launch2_launch2InstancePartsLaunch2HoldingPnlInfoLabel,
          value: pnlText,
          valueKey: 'launch2-holding-pnl',
          color: pnlSign == null ? null : launch2SignedColor(pnlSign),
          info: showInfo
              ? LoopInfoButton(
                  key: const ValueKey<String>('launch2-holding-pnl-info'),
                  title: context
                      .l10n
                      .launch2_launch2InstancePartsLaunch2HoldingPnlInfoTitle,
                  sheetKey: 'launch2-holding-pnl-sheet',
                  notes: <LoopInfoNote>[
                    if (partial)
                      LoopInfoNote(
                        key: ValueKey<String>('launch2-holding-partial-note'),
                        title: context
                            .l10n
                            .launch2_launch2InstancePartsLaunch2HoldingPartialNoteTitle,
                        body: context
                            .l10n
                            .launch2_launch2InstancePartsLaunch2HoldingPartialNoteBody,
                      ),
                    if (realized != null)
                      LoopInfoNote(
                        key: const ValueKey<String>(
                          'launch2-holding-realized-note',
                        ),
                        title: context
                            .l10n
                            .launch2_launch2InstancePartsLaunch2HoldingRealizedNoteTitle,
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
            context.l10n.launch2_launch2InstancePartsBuild2,
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
    final pot = LoopL10n.current.launch2_launch2InstancePartsPot(
      launch2Usd1Label(state.potUsd1, maxFractionDigits: 4),
    );
    if (!state.armed) return pot;
    final drop = state.rollPending
        ? LoopL10n.current.launch2_launch2DynamicPoolLaunch2DynamicRoundRows3
        : LoopL10n.current.launch2_launch2InstancePartsS(
            launch2BpsLabel(state.currentDropBps),
          );
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
      label: context.l10n.launch2_launch2InstancePartsLaunch2DynStripLineLabel(
        _line,
        state.armed
            ? context.l10n.launch2_launch2DynamicPoolLoopBadge
            : context.l10n.launch2_launch2DynamicPoolS,
      ),
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
                context.l10n.launch2_launch2DynamicPoolLaunch2DynRewardsLink,
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 8),
              LoopBadge(
                state.armed
                    ? context.l10n.launch2Creator_launch2ModelsActive
                    : context.l10n.launch2_launch2DynamicPoolS,
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
  trades(),
  info(),
  buyback();

  const Launch2InstanceTab();

  String get title => switch (this) {
    Launch2InstanceTab.trades =>
      LoopL10n.current.launch2_launch2InstancePartsTrades,

    Launch2InstanceTab.info =>
      LoopL10n.current.launch2_launch2InstancePartsInfo,

    Launch2InstanceTab.buyback =>
      LoopL10n.current.launch2_launch2InstancePartsBuyback,
  };
}

/// The page's tab bar. S370a · decision 0293 (docs/58 §9.4): the
/// first-level text tabs — the chosen one white 16 / 600 over a 2 px Yellow
/// line across its cell, the others Text2, a 1 px white 10 % rule across —
/// in place of S279's Purple pill bar (decision 0237). 16 to the list.
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

  /// The strip to the tab's first line (docs/58 §9.4 tab 条 → 列表 16).
  static const double listGap = LoopSpacing.segmentGap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: listGap),
    child: Semantics(
      container: true,
      explicitChildNodes: true,
      child: LoopTabStrip(
        labels: <String>[for (final tab in tabs) tab.title],
        keys: <Key>[
          for (final tab in tabs) ValueKey<String>('launch2-tab-${tab.name}'),
        ],
        selectedIndex: tabs.indexOf(selected).clamp(0, tabs.length - 1),
        onSelected: (index) => onSelected(tabs[index]),
        scaleDownLabels: true,
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
    // S370a · decision 0293: a holding / leaderboard row (docs/58 §9.4,
    // 类推) — 51 high, 6 above and below, body1 over caption, the amount at
    // 14 / 600 over its caption, no line.
    return Container(
      constraints: const BoxConstraints(
        minHeight: Launch2SecondaryMetrics.recordRow,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LoopSpacing.page,
        vertical: Launch2SecondaryMetrics.recordInset,
      ),
      alignment: AlignmentDirectional.centerStart,
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
                        text: buy
                            ? context.l10n.common_buy
                            : context.l10n.common_sell,
                        style:
                            LoopTypography.withWeight(
                              LoopType.body1,
                              FontWeight.w600,
                            ).copyWith(
                              color: buy ? LoopColors.rise : LoopColors.fall,
                            ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text:
                            trade.wallet ??
                            context.l10n.launch2_launch2InstancePartsText,
                        style:
                            (trade.wallet == null
                                    ? LoopType.body1
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
                  context.l10n.launch2_launch2InstancePartsBuild3(
                    launch2PriceLabel(trade.priceUsd1),
                    launch2TradeTimeLabel(trade.at),
                  ),
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
                style: LoopType.figureSm.copyWith(color: LoopColors.chalk),
              ),
              const SizedBox(height: 2),
              Text(memeLine, maxLines: 1, style: LoopType.caption),
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
          label: context.l10n.launch2_launch2InstancePartsLabel3,
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
                      borderRadius: LoopRadius.tag,
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
                    context.l10n.launch2_launch2InstancePartsLabel3,
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
          label: context.l10n.common_buy,
          primary: true,
          block: true,
          onPressed: onBuy,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: LoopButton(
          key: const ValueKey<String>('launch2-bar-sell'),
          label: context.l10n.common_sell,
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
