import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/features/wallet/wallet_networth_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_environment_tag.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// The wallet tab's first screen (decision 0119, 钱包 C since 0188)
// ---------------------------------------------------------------------------
//
// One total with an eye, 今日盈亏 and a net-worth sparkline that opens into a
// chart, four equal keys, the holdings split, a balance list with two actions
// per row and a short entry group. Every figure is still the server's: nothing
// here sums, converts or guesses, and a figure that was not read says so in
// one weak line instead of a block-sized card.

/// A Boolean that lives as long as the app process and no longer.
///
/// AGENTS rule 23 keeps device persistence to a short list of display keys,
/// so the wallet's own display choices below are remembered for this run
/// only: the provider is not auto-disposed, and nothing writes it anywhere.
/// (The eye is the one exception since decision 0188: it is 0175's
/// installation-scoped 「隐藏余额」, `loopBalanceVisibilityProvider`.)
final class WalletSessionFlag extends Notifier<bool> {
  WalletSessionFlag(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void toggle() => state = !state;
}

/// Whether the net-worth chart under 总资产 is open (decision 0188). Closed
/// by default; an open chart stays open for the rest of the run.
final walletNetWorthExpandedProvider =
    NotifierProvider<WalletSessionFlag, bool>(() => WalletSessionFlag(false));

/// The window the open chart shows; 7 天 by default, kept for the run.
final class WalletNetWorthRangeChoice extends Notifier<LoopNetWorthRange> {
  @override
  LoopNetWorthRange build() => LoopNetWorthRange.week;

  void choose(LoopNetWorthRange range) => state = range;
}

final walletNetWorthRangeProvider =
    NotifierProvider<WalletNetWorthRangeChoice, LoopNetWorthRange>(
      WalletNetWorthRangeChoice.new,
    );

/// What a masked amount prints.
const String walletMaskedFigure = '****';

/// A row the asset list leaves out (S259 · decision 0217): the chain read
/// answered, the balance is exactly zero and nothing is on its way in. A row
/// whose read failed is never zero and always stays.
bool walletRowIsZero(LoopAssetBalanceRow row) {
  final balance = row.balance;
  if (balance is! LoopBalanceAvailable) return false;
  if (balance.displayBalance != Decimal.zero) return false;
  final pending = row.pending;
  return pending is! LoopPendingAvailable || pending.value == Decimal.zero;
}

/// `▲5%` / `▼1.2%` / `0%` — a row's own 24h move.
String walletRowChangeText(Decimal pct) {
  final move = LoopPriceMove.of(pct);
  final magnitude = pct < Decimal.zero ? -pct : pct;
  return '${_arrow(move).trim()}'
      '${loopFormatDecimal(magnitude, maxFractionDigits: 2)}%';
}

String _arrow(LoopPriceMove move) => switch (move) {
  LoopPriceMove.up => '▲ ',
  LoopPriceMove.down => '▼ ',
  LoopPriceMove.flat || LoopPriceMove.unread => '',
};

/// A row's USD move over 24h, from its value now and the percent the price
/// moved: `value × pct / (100 + pct)`, i.e. value now − value 24h ago at the
/// same holding. `null` when the percent is −100 (no prior value to speak of).
Decimal? walletRowChangeUsd(Decimal valueUsd, Decimal pct) {
  final base = Decimal.fromInt(100) + pct;
  if (base == Decimal.zero) return null;
  return (valueUsd * pct / base).toDecimal(scaleOnInfinitePrecision: 12);
}

// ---------------------------------------------------------------------------
// 总资产 (钱包 C, decision 0188)
// ---------------------------------------------------------------------------

/// 「总资产」, the eye, the figure with `USD`, separate ¥ and address lines, one weak
/// caption, 今日盈亏, the 7-day sparkline and the chart it opens in place.
///
/// [balances] is the read the figure comes from; `null` while it has not
/// landed. [unreadText] is what the figure slot says when there is no read
/// and none is on its way — 「暂不可用」, 「还没有钱包」 — so the slot is never
/// a zero and never a dash. [walletId] is the wallet whose net-worth history
/// is read; `null` draws no history at all.
class WalletTotalHeader extends ConsumerStatefulWidget {
  const WalletTotalHeader({
    required this.keyPrefix,
    required this.balances,
    required this.loading,
    super.key,
    this.unreadText = '暂不可用',
    this.address,
    this.fullAddress,
    this.environmentTag,
    this.walletId,
  });

  final String keyPrefix;
  final LoopWalletBalances? balances;
  final bool loading;
  final String unreadText;

  /// The active wallet's truncated address, when one is active.
  final String? address;

  /// The same address in full, which the copy glyph puts on the clipboard.
  final String? fullAddress;

  /// Decision 0100: the backend environment on a non-release build.
  final String? environmentTag;

  final String? walletId;

  @override
  ConsumerState<WalletTotalHeader> createState() => _WalletTotalHeaderState();
}

class _WalletTotalHeaderState extends ConsumerState<WalletTotalHeader> {
  /// Starts a history read nobody has asked for yet. The read is display
  /// only: whatever it answers, the balances below are untouched.
  LoopChainResourceState<LoopNetWorthHistory> _watchHistory(
    WalletNetWorthHistoryKey key,
  ) {
    final state = ref.watch(walletNetWorthHistoryControllerProvider(key));
    if (state.phase == LoopChainViewPhase.loading &&
        state.value == null &&
        state.mode != LoopChainGatewayMode.unavailable) {
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(
          ref
              .read(walletNetWorthHistoryControllerProvider(key).notifier)
              .load(),
        );
      });
    }
    return state;
  }

  void _toggle() => ref.read(walletNetWorthExpandedProvider.notifier).toggle();

  @override
  Widget build(BuildContext context) {
    final keyPrefix = widget.keyPrefix;
    final hidden = ref.watch(
      loopBalanceVisibilityProvider.select((visibility) => visibility.hidden),
    );
    final auxiliary = LoopGround.auxiliaryOf(context);
    final secondary = LoopGround.secondaryOf(context);
    final balances = widget.balances;
    final netWorth = balances?.netWorth;
    final figure = switch (netWorth) {
      LoopNetWorthValued(valueUsd: final value) =>
        hidden ? walletMaskedFigure : loopFormatUsd(value),
      LoopNetWorthUnavailable() => '暂不可用',
      null => widget.unreadText,
    };
    final figureIsAmount = netWorth is LoopNetWorthValued;

    // The history: its own port, its own gate. A server without it (404 /
    // 503 / a body missing its keys) draws no sparkline, no chart and no
    // 今日盈亏 — and nothing else on the page moves.
    final walletId = widget.walletId;
    final historyMode = ref.watch(
      walletNetWorthHistoryGatewayProvider.select((gateway) => gateway.mode),
    );
    final historyOn =
        walletId != null && historyMode != LoopChainGatewayMode.unavailable;
    final expanded = historyOn && ref.watch(walletNetWorthExpandedProvider);
    final range = ref.watch(walletNetWorthRangeProvider);
    final weekState = historyOn
        ? _watchHistory((walletId: walletId, range: LoopNetWorthRange.week))
        : null;
    final chartState = !expanded
        ? null
        : range == LoopNetWorthRange.week
        ? weekState
        : _watchHistory((walletId: walletId, range: range));
    final week = weekState?.value;
    final fiat = week?.fiat;
    // The 88 × 44 slot beside the total (decision 0193): the line when it
    // can be drawn, a placeholder when the history came back with fewer
    // than two snapshots, a skeleton while it is read — and nothing at all
    // when the read failed (0188: 404 / 503 draw nothing).
    final Widget? sparkSlot = week != null
        ? week.drawable
              // Decision 0224: a history that is zero all the way would be a
              // flat Yellow rule; the slot carries a short spray stroke.
              ? walletNetWorthAllZero(week)
                    ? WalletNetWorthSparkSpray(onTap: _toggle)
                    : WalletNetWorthSpark(history: week, onTap: _toggle)
              : WalletNetWorthSparkPlaceholder(onTap: _toggle)
        : weekState != null &&
              (weekState.phase == LoopChainViewPhase.loading ||
                  weekState.failureKind == null)
        ? const WalletNetWorthSparkSkeleton()
        : null;

    final caption = <String>[
      if (netWorth case LoopNetWorthValued(
        partial: true,
        unavailableCount: final count,
      ))
        '$count 项资产暂无价格，未计入',
      if (netWorth is LoopNetWorthValued)
        ?loopFactQualityMarker(netWorth.quality),
      if (netWorth case LoopNetWorthUnavailable(reasonCode: final reason))
        loopReasonCodeText(reason),
    ].join(' · ');

    final figureRow = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Flexible(
          child: Text(
            figure,
            key: ValueKey<String>('$keyPrefix-total-figure'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Decision 0224: the chrome plate's figure — Anton 40 in
            // Yellow (docs/42 §2 keeps Anton for big figures).
            style: figureIsAmount
                ? LoopType.plateFigure.copyWith(color: LoopColors.yellow)
                : LoopType.headingSm.copyWith(color: secondary),
          ),
        ),
        if (figureIsAmount) ...<Widget>[
          const SizedBox(width: 4),
          Text(
            'USD',
            key: ValueKey<String>('$keyPrefix-total-unit'),
            style: LoopType.body.copyWith(color: LoopColors.text2),
          ),
        ],
      ],
    );

    final fiatText = fiat != null && fiat.currency == 'CNY'
        ? '≈ ¥${hidden ? walletMaskedFigure : loopFormatDecimal(fiat.amount, maxFractionDigits: 2)}'
        : null;
    final fullAddress = widget.fullAddress;
    // Decision 0194: a stale rate wears the market figures' stale badge
    // right after the ¥ amount; the line's words do not change.
    final fiatStale = fiatText != null && fiat!.stale;
    final staleMarker = loopFactQualityMarker(LoopFactQuality.stale)!;
    final sublineStyle = LoopType.caption.copyWith(color: auxiliary);
    final address = widget.address;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('总资产', style: LoopType.caption.copyWith(color: secondary)),
            _HeaderGlyphButton(
              key: ValueKey<String>('$keyPrefix-eye'),
              label: hidden ? '显示金额' : '隐藏金额',
              toggled: hidden,
              onTap: () => unawaited(
                ref.read(loopBalanceVisibilityProvider.notifier).toggle(),
              ),
              child: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
                color: auxiliary,
              ),
            ),
            _HeaderGlyphButton(
              key: ValueKey<String>('$keyPrefix-info'),
              label: '总资产说明',
              onTap: () => showWalletTotalInfoSheet(
                context,
                balances: balances,
                fiat: fiat,
                history: chartState?.value ?? week,
                keyPrefix: keyPrefix,
              ),
              child: LoopIcon('info', size: 14, color: auxiliary),
            ),
            const Spacer(),
            if (widget.environmentTag case final String tag)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LoopEnvironmentTag(
                  tag,
                  key: ValueKey<String>('$keyPrefix-environment-tag'),
                ),
              ),
          ],
        ),
        if (widget.loading && netWorth == null)
          Padding(
            key: ValueKey<String>('$keyPrefix-total-loading'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: const LoopSkeletonBlock(width: 168, height: 30),
          )
        else
          figureRow,
        if (fiatText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: fiatText),
                  if (fiatStale)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: LoopBadge(
                          staleMarker,
                          key: ValueKey<String>('$keyPrefix-total-fiat-stale'),
                          kind: LoopBadgeKind.down,
                        ),
                      ),
                    ),
                ],
              ),
              key: ValueKey<String>('$keyPrefix-total-subline'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sublineStyle,
            ),
          ),
        if (address != null)
          Semantics(
            button: fullAddress != null,
            label: fullAddress == null ? address : '$address，复制钱包地址',
            excludeSemantics: true,
            child: LoopPressable(
              key: ValueKey<String>('$keyPrefix-address-copy'),
              scale: false,
              onTap: fullAddress == null
                  ? null
                  : () => unawaited(
                      LoopCopy.text(context, fullAddress, message: '钱包地址已复制'),
                    ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        address,
                        key: ValueKey<String>('$keyPrefix-address'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sublineStyle,
                      ),
                    ),
                    if (fullAddress != null) ...<Widget>[
                      const SizedBox(width: 4),
                      LoopIcon('copy', size: 12, color: auxiliary),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(
              caption,
              key: ValueKey<String>('$keyPrefix-total-caption'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LoopType.captionSm.copyWith(color: auxiliary),
            ),
          ),
        if (week != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: WalletPnlLine(
              keyPrefix: keyPrefix,
              change: week.change24h,
              hidden: hidden,
              onTap: _toggle,
            ),
          ),
      ],
    );

    return Padding(
      key: ValueKey<String>('$keyPrefix-total-header'),
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 4, 8, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: left),
              if (!expanded && sparkSlot != null)
                Padding(
                  padding: const EdgeInsets.only(top: 38, left: 10, right: 8),
                  child: sparkSlot,
                ),
            ],
          ),
          if (historyOn)
            if (expanded)
              WalletNetWorthPanel(
                state: chartState,
                range: range,
                hidden: hidden,
                onRange: (next) =>
                    ref.read(walletNetWorthRangeProvider.notifier).choose(next),
                onRetry: () => unawaited(
                  ref
                      .read(
                        walletNetWorthHistoryControllerProvider((
                          walletId: walletId,
                          range: range,
                        )).notifier,
                      )
                      .reload(),
                ),
                onCollapse: _toggle,
              )
            else
              WalletNetWorthChevron(expanded: false, onTap: _toggle),
        ],
      ),
    );
  }
}

class _HeaderGlyphButton extends StatelessWidget {
  const _HeaderGlyphButton({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
    this.toggled,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: toggled,
    label: label,
    excludeSemantics: true,
    child: LoopPressable(
      onTap: onTap,
      // 44 × 44 (audit 2026-10-09 m3): the glyph stays 36 wide in the eye,
      // the finger gets the whole square.
      child: SizedBox(
        width: LoopTouch.minimum,
        height: LoopTouch.minimum,
        child: Center(child: child),
      ),
    ),
  );
}

/// The (i) beside 总资产: what the figure is, and what it is not.
///
/// 「净值不是可用余额」 used to sit under the figure on every visit (decision
/// 0119 moves it here); it is still one tap away, with the source, the
/// observation time and the block every figure was read at.
Future<void> showWalletTotalInfoSheet(
  BuildContext context, {
  required LoopWalletBalances? balances,
  LoopNetWorthFiat? fiat,
  LoopNetWorthHistory? history,
  String keyPrefix = 'wallet',
}) {
  final netWorth = balances?.netWorth;
  final fx = fiat == null ? null : walletFxProvenanceText(fiat);
  final snapshotSource = walletNetWorthProvenance(history);
  final snapshot = balances?.snapshot;
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭总资产说明',
    builder: (sheetContext) {
      final secondary = LoopGround.secondaryOf(sheetContext);
      return SingleChildScrollView(
        key: ValueKey<String>('$keyPrefix-info-sheet'),
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // R2 (decision 0190 M14).
            const LoopSheetHeading('关于总资产'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '总资产是按当前价格对已登记资产的估值，只用于展示，不是可用余额。'
                    '能动用的数量以每个资产页的「可动用」为准。',
                    key: ValueKey<String>('$keyPrefix-not-spendable'),
                    style: LoopType.bodySm.copyWith(color: secondary),
                  ),
                  if (snapshotSource != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      snapshotSource.detail,
                      key: ValueKey<String>('$keyPrefix-info-history'),
                      style: LoopType.bodySm.copyWith(color: secondary),
                    ),
                  ],
                  // Decision 0194: where the ≈¥ beside the total came from.
                  if (fx != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      fx,
                      key: ValueKey<String>('$keyPrefix-info-fx'),
                      style: LoopType.bodySm.copyWith(color: secondary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (netWorth
                      case final LoopNetWorthValued valued) ...<Widget>[
                    LoopKeyValue(
                      label: '价格来源',
                      value: loopFactSourceLabel(valued.priceSource),
                      padding: EdgeInsets.zero,
                    ),
                    LoopKeyValue(
                      label: '观察于',
                      value: loopDateTimeLabel(valued.asOf),
                      padding: EdgeInsets.zero,
                    ),
                    if (valued.partial)
                      LoopKeyValue(
                        label: '未计入',
                        value: '${valued.unavailableCount} 项资产暂无价格',
                        padding: EdgeInsets.zero,
                      ),
                    LoopKeyValue(
                      label: '24h 变动',
                      value: switch (valued.change24h) {
                        LoopNetWorthChangeAvailable() => '按同一次价格读取计算',
                        LoopNetWorthChangeUnavailable() =>
                          '部分资产没有 24h 价格变化，暂不显示',
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ] else if (netWorth case LoopNetWorthUnavailable(
                    reasonCode: final reason,
                  ))
                    LoopKeyValue(
                      label: '总资产',
                      value: loopReasonCodeText(reason),
                      padding: EdgeInsets.zero,
                    ),
                  if (snapshot != null) ...<Widget>[
                    LoopKeyValue(
                      label: '余额区块',
                      value: loopGroupedFigure(snapshot.blockNumber.toString()),
                      padding: EdgeInsets.zero,
                    ),
                    LoopKeyValue(
                      label: '确认数',
                      value: loopGroupedFigure(
                        snapshot.confirmations.toString(),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                  // S278 · decision 0236: what stood under the chart.
                  if (snapshotSource != null) ...<Widget>[
                    LoopKeyValue(
                      key: ValueKey<String>('$keyPrefix-info-history-source'),
                      label: '净值快照来源',
                      value: snapshotSource.source,
                      padding: EdgeInsets.zero,
                    ),
                    if (snapshotSource.observedAt case final DateTime at)
                      LoopKeyValue(
                        label: '快照观察于',
                        value: loopDateTimeLabel(at),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                  if (balances != null)
                    LoopKeyValue(
                      label: '手续费保留',
                      value:
                          '${loopFormatDecimal(balances.gasReservePolicy.nativeReserve)} BNB',
                      padding: EdgeInsets.zero,
                    ),
                  const SizedBox(height: 16),
                  LoopButton(
                    label: '知道了',
                    block: true,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Four keys
// ---------------------------------------------------------------------------

/// One of the four equal keys under the total.
@immutable
final class WalletQuickAction {
  const WalletQuickAction({
    required this.label,
    required this.actionKey,
    required this.glyph,
    this.onPressed,
    this.blockedReason,
    this.primary = false,
  }) : assert(
         onPressed == null || blockedReason == null,
         'A key either runs or says why it cannot.',
       );

  final String label;
  final Key actionKey;
  final Widget Function(Color color) glyph;
  final VoidCallback? onPressed;
  final String? blockedReason;

  /// The one key that wears the solid Lime disc (decision 0171, user ruling
  /// on docs/33 M15: 兑换). The other keys sit on Card2 with a Chalk glyph,
  /// so the row keeps one full-Lime body on screen.
  final bool primary;
}

/// 接收 / 发送 / 兑换 / 扫码 — one row, four equal columns, a round glyph
/// over a label. A closed key keeps its place and says the server's sentence
/// when pressed.
class WalletQuickActions extends StatelessWidget {
  const WalletQuickActions({
    required this.actions,
    required this.onBlocked,
    super.key,
  });

  final List<WalletQuickAction> actions;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('wallet-quick-actions'),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final action in actions)
            Expanded(
              child: _QuickActionTile(action: action, onBlocked: onBlocked),
            ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onBlocked});

  final WalletQuickAction action;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    final run = action.onPressed;
    final reason = action.blockedReason;
    final enabled = run != null;
    // Decision 0212 (docs/42 附C §6): all four keys are the raised grey
    // ground with a Chalk glyph — 兑换 included, no solid Yellow — and a
    // closed key keeps its place on the quiet ground. [primary] is kept on
    // the model but no longer changes the paint.
    final ink = enabled ? LoopColors.chalk : LoopGround.auxiliaryOf(context);
    final disc = enabled ? LoopColors.card2 : LoopColors.bg2;
    final onTap = run ?? (reason == null ? null : () => onBlocked(reason));
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? action.label : '${action.label}，暂不可用',
      // The gesture below is excluded with the rest of the subtree, so the
      // tap is offered here or a screen reader could not press the key.
      onTap: onTap,
      excludeSemantics: true,
      child: LoopPressable(
        key: action.actionKey,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                key: ValueKey<String>('wallet-quick-disc-${action.label}'),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: disc,
                  borderRadius: LoopRadius.control,
                ),
                alignment: Alignment.center,
                child: action.glyph(ink),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // v3 (decision 0229): the key's word at body2, 600.
                style:
                    LoopTypography.withWeight(
                      LoopType.body2,
                      FontWeight.w600,
                    ).copyWith(
                      color: enabled
                          ? LoopGround.inkOf(context)
                          : LoopGround.auxiliaryOf(context),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 资产
// ---------------------------------------------------------------------------

/// The section title with an optional small trailing tag.
class WalletSectionHeading extends StatelessWidget {
  const WalletSectionHeading({
    required this.title,
    super.key,
    this.trailing,
    this.top = LoopSpacing.group,
  });

  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Decision 0212 (水平对齐): the trailing tag ends on the page margin.
      padding: EdgeInsets.fromLTRB(LoopSpacing.page, top, LoopSpacing.page, 2),
      child: Row(
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              // Decision 0126: a flat second-level page's section title.
              style: LoopFlat.of(context)
                  ? loopFlatSectionStyle()
                  : LoopType.headline.copyWith(
                      color: LoopGround.inkOf(context),
                    ),
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// 「产生算力」: the small tag beside 资产 that opens the mining note.
///
/// Decision 0171 (docs/33 L14): the shared mute `.badge` with an (i) glyph
/// after it, in place of the hand-made r999 outlined capsule.
class WalletPowerTag extends StatelessWidget {
  const WalletPowerTag({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = LoopGround.secondaryOf(context);
    return Semantics(
      button: true,
      label: '持仓产生算力，查看说明',
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('wallet-power-tag'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const LoopBadge('产生算力'),
                const SizedBox(width: 4),
                LoopIcon('info', size: 13, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The note the 「产生算力」 tag opens: the account's power and today's
/// estimate, read by the Mining module, and the way to the mining page.
Future<void> showWalletPowerSheet(
  BuildContext context, {
  required VoidCallback onOpenMining,
}) {
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭算力说明',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('wallet-power-sheet'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // R2 (decision 0190 M14).
          const LoopSheetHeading('持仓产生算力'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '钱包里已登记的资产会按各自的权重产生挖矿算力，算力决定每天能分到的 LOOP。'
              '社区币须加入已通过审核的绑定社区才计入。'
              '每个资产的权重与算力在挖矿页查看。',
              style: LoopType.bodySm.copyWith(
                color: LoopGround.secondaryOf(sheetContext),
              ),
            ),
          ),
          const SizedBox(height: 12),
          WalletHoldingsPowerHint(
            onOpenMining: () {
              Navigator.of(sheetContext).pop();
              onOpenMining();
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('wallet-power-sheet-close'),
              label: '知道了',
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// One asset, unboxed: Logo 36 · SYMBOL over name · amount over ≈$x · the
/// 24h move pill.
///
/// A row whose chain read failed keeps its logo and ticker and says it was not
/// read in one weak line — never `0`, never a dash.
class WalletAssetLine extends StatelessWidget {
  const WalletAssetLine({
    required this.row,
    required this.hidden,
    super.key,
    this.onTap,
    this.onRetry,
    this.recordRow = false,
  });

  final LoopAssetBalanceRow row;
  final bool hidden;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  /// The failed row stands in a list of [WalletBalanceRow]s (R4 15) rather
  /// than of quote rows (16): its ticker takes the step of the rows around it
  /// (decision 0190 H5).
  final bool recordRow;

  @override
  Widget build(BuildContext context) {
    final ink = LoopGround.inkOf(context);
    final balance = row.balance;
    final logo = LoopTokenLogo(
      assetSymbol: row.symbol,
      logoUrl: row.logoUrl,
      fallbackMonogram: row.symbol,
      size: 36,
    );
    final symbol = Text(
      row.symbol,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // H5: the same step as the healthy rows of the same list.
      style: (recordRow ? LoopType.title : LoopType.titleLg).copyWith(
        color: ink,
      ),
    );

    if (balance is LoopBalanceUnavailable) {
      return Semantics(
        key: ValueKey<String>('wallet-balance-${row.assetId}'),
        container: true,
        label: '${row.symbol}，余额读不到',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 10, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoopPressable(onTap: onTap, child: logo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LoopPressable(onTap: onTap, scale: false, child: symbol),
                    LoopInlineUnavailable(
                      key: ValueKey<String>(
                        'wallet-balance-unavailable-${row.assetId}',
                      ),
                      message:
                          '余额读不到 · ${loopReasonCodeText(balance.reasonCode)}',
                      onRetry: onRetry,
                      padding: const EdgeInsets.only(right: LoopSpacing.page),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final available = balance as LoopBalanceAvailable;
    final amount = hidden
        ? walletMaskedFigure
        : loopFormatDecimal(available.displayBalance);
    final valuation = row.valuation;
    // Derived-figure notes ride at the end of the grey line in small type
    // (decision 0123): the name stays the line, the note never pushes the
    // figures.
    final marks = <String>[
      if (valuation is LoopValuationAvailable)
        ?loopFactQualityMarker(valuation.quality),
      if (row.pending case LoopPendingAvailable(value: final value)
          when value > Decimal.zero)
        '待确认 ${hidden ? walletMaskedFigure : loopFormatDecimal(value)}',
      if (row.crossCheck.isMisaligned) '数据源尚未对齐',
    ];

    final String valueText;
    final String valueLabel;
    final Decimal? change;
    switch (valuation) {
      case LoopValuationAvailable(
        valueUsd: final value,
        change24hPct: final pct,
      ):
        valueText = '≈${hidden ? walletMaskedFigure : loopFormatUsd(value)}';
        change = pct;
        valueLabel = pct == null
            ? '估值 $valueText'
            : '估值 $valueText，24h ${walletRowChangeText(pct)}';
      case LoopValuationUnavailable():
        valueText = '暂无估值';
        change = null;
        valueLabel = '暂无估值';
    }

    // The OKX asset row (decision 0123, S121 §1.1.1 rule 1): round logo 36,
    // symbol 18 bold over the name 14 grey, amount 18 bold over the ≈ value 14 grey,
    // and the 24h move in the fixed 96 × 44 pill at the right end.
    return LoopQuoteRow(
      key: ValueKey<String>('wallet-balance-${row.assetId}'),
      leading: LoopTokenLogo(
        assetSymbol: row.symbol,
        logoUrl: row.logoUrl,
        fallbackMonogram: row.symbol,
        size: 36,
      ),
      title: row.symbol,
      // 「BNB / BNB」 says nothing twice: a name equal to the ticker gives
      // its place to the note.
      subtitle: row.name == row.symbol && marks.isNotEmpty ? null : row.name,
      subtitleMark: marks.isEmpty ? null : marks.join(' · '),
      subtitleMarkKey: ValueKey<String>('wallet-balance-mark-${row.assetId}'),
      value: amount,
      valueKey: ValueKey<String>('wallet-balance-amount-${row.assetId}'),
      // The quote row owns the secondary value's step (decision 0190 M21).
      valueCaption: Text(
        valueText,
        key: ValueKey<String>('wallet-balance-value-${row.assetId}'),
      ),
      trailing: KeyedSubtree(
        key: ValueKey<String>('wallet-balance-change-${row.assetId}'),
        child: LoopChangePill(change: change),
      ),
      onTap: onTap,
      semanticLabel: '${row.symbol}，余额 $amount，$valueLabel',
    );
  }
}

/// One row of the wallet's 「代币」 list and the figures it sorts by (S259 ·
/// decision 0217): its USD value when it has one, else its amount.
typedef WalletTokenEntry = ({Decimal? valueUsd, Decimal quantity, Widget row});

/// The 「代币」 order: valued rows by value, largest first, then every row
/// without a value by amount, largest first. Ties keep the order given.
List<WalletTokenEntry> walletSortTokenEntries(List<WalletTokenEntry> entries) {
  final indexed = <(int, WalletTokenEntry)>[
    for (var i = 0; i < entries.length; i += 1) (i, entries[i]),
  ];
  indexed.sort((a, b) {
    final av = a.$2.valueUsd;
    final bv = b.$2.valueUsd;
    if (av != null && bv == null) return -1;
    if (av == null && bv != null) return 1;
    final byValue = av != null && bv != null
        ? bv.compareTo(av)
        : b.$2.quantity.compareTo(a.$2.quantity);
    return byValue != 0 ? byValue : a.$1.compareTo(b.$1);
  });
  return <WalletTokenEntry>[for (final (_, entry) in indexed) entry];
}

/// 「代币 / NFT」 over the wallet's asset area (S259 · decision 0217): two
/// segment capsules — the chosen one solid Purple (docs/42 附C §4) — with
/// [trailing] (产生算力) at the end of the line.
class WalletAssetTabs extends StatelessWidget {
  const WalletAssetTabs({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.trailing,
  });

  static const List<String> labels = <String>['代币', 'NFT'];
  static const int tokens = 0;
  static const int nft = 1;
  static const List<String> _keys = <String>['tokens', 'nft'];

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('wallet-asset-tabs'),
    // v3 (decision 0229): the tabs stand as a section head — 36 above
    // them, and the rows keep their own 14 under.
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.sectionTop - 12,
      LoopSpacing.page,
      4,
    ),
    child: Row(
      children: <Widget>[
        for (var index = 0; index < labels.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 4),
          LoopSeg(
            key: ValueKey<String>('wallet-asset-tab-${_keys[index]}'),
            label: labels[index],
            quiet: true,
            selected: index == selectedIndex,
            capsuleHeight: LoopSegBar.capsuleHeight,
            onSelected: () => onSelected(index),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 持仓分布 (钱包 C, decision 0188)
// ---------------------------------------------------------------------------

/// One slice of the holdings split: a ticker (or 「其它」) and its share of
/// the valued rows, in percent.
typedef WalletHoldingShare = ({String label, Decimal percent});

/// The split: at most three tickers, then 「其它」 for the rest, by each row's own USD
/// valuation. `null` whenever the valuations are not complete — a balance
/// that was not read, a held row without a price, a partial or unavailable
/// total — because a split of an incomplete sum states a share no holding
/// has. Rows holding nothing take no slice.
List<WalletHoldingShare>? walletHoldingShares(LoopWalletBalances balances) {
  final netWorth = balances.netWorth;
  if (netWorth is! LoopNetWorthValued || netWorth.partial) return null;
  final valued = <({String symbol, Decimal value})>[];
  for (final row in balances.balances) {
    final balance = row.balance;
    if (balance is! LoopBalanceAvailable) return null;
    if (balance.displayBalance == Decimal.zero) continue;
    final valuation = row.valuation;
    if (valuation is! LoopValuationAvailable) return null;
    if (valuation.valueUsd <= Decimal.zero) continue;
    valued.add((symbol: row.symbol, value: valuation.valueUsd));
  }
  if (valued.isEmpty) return null;
  valued.sort((a, b) => b.value.compareTo(a.value));
  final total = valued.fold<Decimal>(
    Decimal.zero,
    (sum, entry) => sum + entry.value,
  );
  Decimal share(Decimal value) => (value * Decimal.fromInt(100) / total)
      .toDecimal(scaleOnInfinitePrecision: 6);
  final shown = valued.length > 3 ? valued.take(3).toList() : valued;
  final rest = valued
      .skip(shown.length)
      .fold<Decimal>(Decimal.zero, (sum, entry) => sum + entry.value);
  return <WalletHoldingShare>[
    for (final entry in shown)
      (label: entry.symbol, percent: share(entry.value)),
    if (rest > Decimal.zero) (label: '其它', percent: share(rest)),
  ];
}

/// The four slice colours, in order: yellow, purple, Chalk, `#4A4754`
/// (S241b: the two looplabs accents lead).
const List<Color> walletHoldingColors = <Color>[
  LoopColors.yellow,
  LoopColors.purple,
  LoopColors.chalk,
  LoopColors.line3,
];

/// 持仓分布 — one segmented bar and its legend in a record card.
class WalletHoldingsDistribution extends StatelessWidget {
  const WalletHoldingsDistribution({required this.shares, super.key});

  final List<WalletHoldingShare> shares;

  static String percentText(Decimal percent) =>
      '${loopFormatDecimal(percent, maxFractionDigits: percent < Decimal.fromInt(10) ? 1 : 0)}%';

  @override
  Widget build(BuildContext context) {
    final secondary = LoopGround.secondaryOf(context);
    final auxiliary = LoopGround.auxiliaryOf(context);
    final label = shares
        .map((entry) => '${entry.label} ${percentText(entry.percent)}')
        .join('，');
    return LoopRecordCard(
      key: const ValueKey<String>('wallet-distribution'),
      // S241b: room under the square quick keys, which had touched the card.
      margin: LoopRecordCard.defaultMargin.copyWith(top: 16),
      padding: const EdgeInsets.all(LoopSpacing.card),
      child: Semantics(
        container: true,
        label: '持仓分布，$label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('持仓分布', style: LoopType.body2.copyWith(color: secondary)),
            const SizedBox(height: 12),
            SizedBox(
              key: const ValueKey<String>('wallet-distribution-bar'),
              height: 6,
              // Stretch: a childless DecoratedBox under a Row's loose cross
              // axis collapsed to 0 high and the bar never painted.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var index = 0; index < shares.length; index++) ...[
                    if (index > 0) const SizedBox(width: 2),
                    Expanded(
                      // Basis points: the share in the bar's pixel space.
                      flex: math.max(
                        1,
                        (shares[index].percent * Decimal.fromInt(100))
                            .round()
                            .toBigInt()
                            .toInt(),
                      ),
                      child: DecoratedBox(
                        key: ValueKey<String>(
                          'wallet-distribution-segment-$index',
                        ),
                        decoration: BoxDecoration(
                          color: walletHoldingColors[index],
                          borderRadius: LoopRadius.badge,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: <Widget>[
                for (var index = 0; index < shares.length; index++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: walletHoldingColors[index],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${shares[index].label} ${percentText(shares[index].percent)}',
                        key: ValueKey<String>(
                          'wallet-distribution-legend-$index',
                        ),
                        style: LoopType.caption.copyWith(color: auxiliary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 余额 rows (钱包 C, decision 0188)
// ---------------------------------------------------------------------------

/// One of the two small actions under a balance row.
@immutable
final class WalletRowAction {
  const WalletRowAction({
    required this.label,
    required this.actionKey,
    this.onPressed,
    this.blockedReason,
  }) : assert(
         onPressed == null || blockedReason == null,
         'An action either runs or says why it cannot.',
       );

  final String label;
  final Key actionKey;
  final VoidCallback? onPressed;
  final String? blockedReason;
}

/// The two quiet chips at the end of a row (发送 / 兑换, 买入 / 卖出).
class WalletRowActions extends StatelessWidget {
  const WalletRowActions({
    required this.actions,
    required this.onBlocked,
    super.key,
  });

  final List<WalletRowAction> actions;
  final void Function(String reason) onBlocked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        for (var index = 0; index < actions.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 8),
          LoopSeg(
            key: actions[index].actionKey,
            label: actions[index].label,
            quiet: true,
            selected: false,
            onSelected: actions[index].onPressed,
            onBlocked: switch (actions[index].blockedReason) {
              final String reason => () => onBlocked(reason),
              null => null,
            },
          ),
        ],
      ],
    );
  }
}

/// One balance, 钱包 C: Logo 40 · ticker over its name (or 手续费保留 on the
/// native row) · amount over its USD value; under it the 24h move when the
/// price source reported one, and the row's two actions.
///
/// A row whose chain read failed is drawn by [WalletAssetLine] as before: its
/// logo, its ticker and one weak line — never `0`, never a dash, and no
/// action that would act on a balance nobody read.
class WalletBalanceRow extends StatelessWidget {
  const WalletBalanceRow({
    required this.row,
    required this.hidden,
    required this.actions,
    required this.onBlocked,
    super.key,
    this.gasReserve,
    this.onTap,
    this.onRetry,
  });

  final LoopAssetBalanceRow row;
  final bool hidden;
  final List<WalletRowAction> actions;
  final void Function(String reason) onBlocked;

  /// The native row's reserve, from `gasReservePolicy`.
  final Decimal? gasReserve;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final balance = row.balance;
    if (balance is! LoopBalanceAvailable) {
      return WalletAssetLine(
        row: row,
        hidden: hidden,
        onTap: onTap,
        onRetry: onRetry,
        recordRow: true,
      );
    }
    final ink = LoopGround.inkOf(context);
    final secondary = LoopGround.secondaryOf(context);
    final auxiliary = LoopGround.auxiliaryOf(context);
    final amount = hidden
        ? walletMaskedFigure
        : loopFormatDecimal(balance.displayBalance);
    final valuation = row.valuation;
    final reserve = gasReserve;
    final subtitle = row.isNative && reserve != null
        ? '手续费保留 ${loopFormatDecimal(reserve)}'
        : row.name;
    final marks = <String>[
      if (valuation is LoopValuationAvailable)
        ?loopFactQualityMarker(valuation.quality),
      if (row.pending case LoopPendingAvailable(value: final value)
          when value > Decimal.zero)
        '待确认 ${hidden ? walletMaskedFigure : loopFormatDecimal(value)}',
      if (row.crossCheck.isMisaligned) '数据源尚未对齐',
    ];

    final String valueText;
    String? changeText;
    String? changePct;
    Color? changeColour;
    switch (valuation) {
      case LoopValuationAvailable(
        valueUsd: final value,
        change24hPct: final pct,
      ):
        valueText = '≈${hidden ? walletMaskedFigure : loopFormatUsd(value)}';
        if (pct != null) {
          final usd = walletRowChangeUsd(value, pct);
          if (usd != null) {
            changeText = walletSignedUsdText(usd, pct, hidden: hidden);
            changePct = hidden ? walletMaskedFigure : loopFormatPercent(pct);
            changeColour = hidden ? secondary : LoopPriceMove.of(pct).color;
          }
        }
      case LoopValuationUnavailable():
        valueText = '暂无估值';
    }

    final top = LoopPressable(
      key: ValueKey<String>('wallet-balance-open-${row.assetId}'),
      scale: false,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          LoopTokenLogo(
            assetSymbol: row.symbol,
            logoUrl: row.logoUrl,
            fallbackMonogram: row.symbol,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  row.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // v3 (decision 0229): body1 over a caption line.
                  style: LoopType.body1.copyWith(color: ink),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    // The subtitle (手续费保留 …) gives way last.
                    Flexible(
                      flex: 3,
                      child: Text(
                        subtitle,
                        key: ValueKey<String>(
                          'wallet-balance-subtitle-${row.assetId}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LoopType.caption.copyWith(color: auxiliary),
                      ),
                    ),
                    if (marks.isNotEmpty)
                      Flexible(
                        child: Text(
                          '，${marks.join('，')}',
                          key: ValueKey<String>(
                            'wallet-balance-mark-${row.assetId}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.captionSm.copyWith(color: auxiliary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                amount,
                key: ValueKey<String>('wallet-balance-amount-${row.assetId}'),
                maxLines: 1,
                style: LoopType.figure.copyWith(color: ink),
              ),
              const SizedBox(height: 4),
              // v3 (decision 0229): the value and its 24 h move share the
              // caption line; the move no longer takes a line of its own.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    valueText,
                    key: ValueKey<String>(
                      'wallet-balance-value-${row.assetId}',
                    ),
                    maxLines: 1,
                    style: LoopType.figureSm,
                  ),
                  if (changePct != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      changePct,
                      key: ValueKey<String>(
                        'wallet-balance-change-${row.assetId}',
                      ),
                      maxLines: 1,
                      style: LoopTypography.withWeight(
                        LoopType.figureSm,
                        FontWeight.w600,
                      ).copyWith(color: changeColour!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      key: ValueKey<String>('wallet-balance-${row.assetId}'),
      container: true,
      // v3 (decision 0229): no hairline; the row's own 14 above and below.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LoopSpacing.rowMinWithSub),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            14,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                label:
                    '${row.symbol}，$subtitle，余额 $amount，估值 $valueText'
                    '${changeText == null ? '' : '，24 小时 $changeText'}',
                excludeSemantics: true,
                button: onTap != null,
                child: top,
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: WalletRowActions(
                    actions: actions,
                    onBlocked: onBlocked,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
