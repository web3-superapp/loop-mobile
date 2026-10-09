import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_environment_tag.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// The wallet tab's OKX-style first screen (decision 0119)
// ---------------------------------------------------------------------------
//
// One total with an eye and a 24h line, four equal keys, an unboxed asset
// list and a short entry group. Every figure is still the server's: nothing
// here sums, converts or guesses, and a figure that was not read says so in
// one weak line instead of a block-sized card.

/// A Boolean that lives as long as the app process and no longer.
///
/// AGENTS rule 23 keeps device persistence to `reduceMotion` alone, so the
/// two wallet display choices below are remembered for this run only: the
/// provider is not auto-disposed, and nothing writes it anywhere.
final class WalletSessionFlag extends Notifier<bool> {
  WalletSessionFlag(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void toggle() => state = !state;
}

/// Whether the wallet's amounts are masked (the eye beside 总资产).
final walletAmountsHiddenProvider = NotifierProvider<WalletSessionFlag, bool>(
  () => WalletSessionFlag(false),
);

/// Whether rows holding exactly zero are folded away. On by default.
final walletHideZeroBalancesProvider =
    NotifierProvider<WalletSessionFlag, bool>(() => WalletSessionFlag(true));

/// What a masked amount prints.
const String walletMaskedFigure = '****';

/// A row the zero-balance switch may fold: the chain read answered, the
/// balance is exactly zero and nothing is on its way in. A row whose read
/// failed is never zero and is never folded.
bool walletRowIsZero(LoopAssetBalanceRow row) {
  final balance = row.balance;
  if (balance is! LoopBalanceAvailable) return false;
  if (balance.displayBalance != Decimal.zero) return false;
  final pending = row.pending;
  return pending is! LoopPendingAvailable || pending.value == Decimal.zero;
}

/// `▲ $302.52 (+5%) · 24h` — the total's 24h line, as text.
///
/// The arrow and the colour come from [LoopPriceMove]; a flat total has
/// neither.
String walletChangeText(LoopNetWorthChangeAvailable change) {
  final move = LoopPriceMove.of(change.usd);
  final usd = change.usd < Decimal.zero ? -change.usd : change.usd;
  return '${_arrow(move)}${loopFormatUsd(usd)} '
      '(${loopFormatPercent(change.pct)}) · 24h';
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

// ---------------------------------------------------------------------------
// 总资产
// ---------------------------------------------------------------------------

/// 「总资产」, the eye, the figure, the 24h line and one weak caption.
///
/// [balances] is the read the figure comes from; `null` while it has not
/// landed. [unreadText] is what the figure slot says when there is no read
/// and none is on its way — 「暂不可用」, 「还没有钱包」 — so the slot is never
/// a zero and never a dash.
class WalletTotalHeader extends ConsumerWidget {
  const WalletTotalHeader({
    required this.keyPrefix,
    required this.balances,
    required this.loading,
    super.key,
    this.unreadText = '暂不可用',
    this.address,
    this.environmentTag,
  });

  final String keyPrefix;
  final LoopWalletBalances? balances;
  final bool loading;
  final String unreadText;

  /// The active wallet's truncated address, when one is active.
  final String? address;

  /// Decision 0100: the backend environment on a non-release build.
  final String? environmentTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(walletAmountsHiddenProvider);
    final ink = LoopGround.inkOf(context);
    final auxiliary = LoopGround.auxiliaryOf(context);
    final secondary = LoopGround.secondaryOf(context);
    final netWorth = balances?.netWorth;
    final figure = switch (netWorth) {
      LoopNetWorthValued(valueUsd: final value) =>
        hidden ? walletMaskedFigure : loopFormatUsd(value),
      LoopNetWorthUnavailable() => '暂不可用',
      null => unreadText,
    };
    final figureIsAmount = netWorth is LoopNetWorthValued;
    final caption = <String>[
      ?address,
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

    // Decision 0133 (audit m9): no chevron to 净值明细. That page repeated
    // this header and the asset list below it; the (i) carries the rest.
    final figureText = Text(
      figure,
      key: ValueKey<String>('$keyPrefix-total-figure'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: figureIsAmount
          ? LoopType.figureXl.copyWith(color: ink)
          : LoopType.headingSm.copyWith(color: secondary),
    );

    return Padding(
      key: ValueKey<String>('$keyPrefix-total-header'),
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 4, 8, 6),
      child: Column(
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
                onTap: () =>
                    ref.read(walletAmountsHiddenProvider.notifier).toggle(),
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
                  keyPrefix: keyPrefix,
                ),
                child: LoopIcon('info', size: 14, color: auxiliary),
              ),
              const Spacer(),
              if (environmentTag case final String tag)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LoopEnvironmentTag(
                    tag,
                    key: ValueKey<String>('$keyPrefix-environment-tag'),
                  ),
                ),
            ],
          ),
          if (loading && netWorth == null)
            Padding(
              key: ValueKey<String>('$keyPrefix-total-loading'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const LoopSkeletonBlock(width: 168, height: 30),
            )
          else
            figureText,
          WalletChangeLine(
            keyPrefix: keyPrefix,
            netWorth: netWorth,
            hidden: hidden,
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
        ],
      ),
    );
  }
}

/// The 24h line under the total, in its three states.
///
/// A figure: `▲ $x (x%) · 24h` in rise / fall. No figure because a valued row
/// had no 24h number: one weak 「24h 变动暂不可用」. No net worth at all:
/// nothing.
class WalletChangeLine extends StatelessWidget {
  const WalletChangeLine({
    required this.keyPrefix,
    required this.netWorth,
    required this.hidden,
    super.key,
  });

  final String keyPrefix;
  final LoopNetWorth? netWorth;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final valued = netWorth;
    if (valued is! LoopNetWorthValued) return const SizedBox.shrink();
    final auxiliary = LoopGround.auxiliaryOf(context);
    switch (valued.change24h) {
      case LoopNetWorthChangeUnavailable():
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '24h 变动暂不可用',
            key: ValueKey<String>('$keyPrefix-change24h-unavailable'),
            style: LoopType.caption.copyWith(color: auxiliary),
          ),
        );
      case final LoopNetWorthChangeAvailable change:
        final move = LoopPriceMove.of(change.usd);
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            hidden ? '$walletMaskedFigure · 24h' : walletChangeText(change),
            key: ValueKey<String>('$keyPrefix-change24h'),
            style: LoopType.figureSm.copyWith(
              color: hidden ? auxiliary : move.color,
            ),
          ),
        );
    }
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
  String keyPrefix = 'wallet',
}) {
  final netWorth = balances?.netWorth;
  final snapshot = balances?.snapshot;
  return showLoopSheet<void>(
    context,
    barrierLabel: '关闭总资产说明',
    builder: (sheetContext) {
      final secondary = LoopGround.secondaryOf(sheetContext);
      return Padding(
        key: ValueKey<String>('$keyPrefix-info-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('关于总资产', style: LoopType.headingSm),
            const SizedBox(height: 10),
            Text(
              '总资产是按当前价格对已登记资产的估值，只用于展示，不是可用余额。'
              '能动用的数量以每个资产页的「可动用」为准。',
              key: ValueKey<String>('$keyPrefix-not-spendable'),
              style: LoopType.bodySm.copyWith(color: secondary),
            ),
            const SizedBox(height: 12),
            if (netWorth case final LoopNetWorthValued valued) ...<Widget>[
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
                  LoopNetWorthChangeUnavailable() => '部分资产没有 24h 价格变化，暂不显示',
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
                value: loopGroupedFigure(snapshot.confirmations.toString()),
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
  }) : assert(
         onPressed == null || blockedReason == null,
         'A key either runs or says why it cannot.',
       );

  final String label;
  final Key actionKey;
  final Widget Function(Color color) glyph;
  final VoidCallback? onPressed;
  final String? blockedReason;
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
    // OKX round action keys (decision 0122): a 56 solid Lime disc with an
    // Ink glyph; a closed key keeps its place on the quiet card ground.
    final ink = enabled ? LoopColors.ink : LoopGround.auxiliaryOf(context);
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: enabled ? LoopColors.lime : LoopGround.fillOf(context),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: action.glyph(ink),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopTypography.title(
                  13,
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
      padding: EdgeInsets.fromLTRB(LoopSpacing.page, top, 8, 2),
      child: Row(
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              // Decision 0126: a flat second-level page's section title.
              style: LoopFlat.of(context)
                  ? loopFlatSectionStyle()
                  : LoopType.titleLg.copyWith(color: LoopGround.inkOf(context)),
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: LoopGround.edgeOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '产生算力',
                    style: LoopType.captionSm.copyWith(color: secondary),
                  ),
                  const SizedBox(width: 3),
                  LoopIcon('info', size: 11, color: secondary),
                ],
              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('持仓产生算力', style: LoopType.headingSm),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '钱包里已登记的资产会按各自的权重产生挖矿算力，算力决定每天能分到的 LOOP。'
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
  });

  final LoopAssetBalanceRow row;
  final bool hidden;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

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
      style: LoopType.title.copyWith(color: ink),
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
      valueCaption: Text(
        valueText,
        key: ValueKey<String>('wallet-balance-value-${row.assetId}'),
        style: LoopTypography.figure(14, color: LoopColors.text2),
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

/// 「隐藏零余额资产」 — one line of text under the list that folds or shows
/// the zero rows (decision 0123, OKX's text switch): folded it offers
/// 「显示 N 项零余额资产」, open it offers 「隐藏零余额资产」.
class WalletZeroBalanceToggle extends StatelessWidget {
  const WalletZeroBalanceToggle({
    required this.hideZero,
    required this.zeroCount,
    required this.onToggle,
    super.key,
  });

  final bool hideZero;
  final int zeroCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final secondary = LoopGround.secondaryOf(context);
    final label = hideZero ? '显示 $zeroCount 项零余额资产' : '隐藏零余额资产';
    return Semantics(
      button: true,
      toggled: hideZero,
      label: '隐藏零余额资产，$zeroCount 项',
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('wallet-zero-toggle'),
        scale: false,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  key: const ValueKey<String>('wallet-zero-toggle-label'),
                  style: LoopTypography.body(14, color: secondary),
                ),
                const SizedBox(width: 4),
                RotatedBox(
                  // The chevron points the way the list will move.
                  quarterTurns: hideZero ? 1 : 3,
                  child: LoopIcon('chevron', size: 14, color: secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
