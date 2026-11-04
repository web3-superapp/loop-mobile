import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_figma_glyph.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/features/wallet/wallet_networth_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
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

/// Whether the net-worth chart under 总资产 is open (decision 0188, restored
/// by decision 0259 over 0257's always-open chart). Closed by default; an
/// open chart stays open for the rest of the run, and nothing is persisted.
final walletNetWorthExpandedProvider =
    NotifierProvider<WalletSessionFlag, bool>(() => WalletSessionFlag(false));

/// The window the chart shows; 7 天 by default, kept for the run.
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

/// The grey line under the net worth, on 钱包 and on 我 alike (S334 ·
/// decision 0263): the unpriced count, the figure's quality, or the reason
/// it is unavailable. Empty when there is nothing to say.
String walletNetWorthCaption(LoopNetWorth? netWorth) => <String>[
  if (netWorth case LoopNetWorthValued(
    partial: true,
    unavailableCount: final count,
  ))
    LoopL10n.current.wallet_homeWalletRowChangeUsd(count),
  if (netWorth is LoopNetWorthValued) ?loopFactQualityMarker(netWorth.quality),
  if (netWorth case LoopNetWorthUnavailable(reasonCode: final reason))
    loopReasonCodeText(reason),
].join(' · ');

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
    this.unreadText,
    this.address,
    this.fullAddress,
    this.environmentTag,
    this.walletId,
    this.addressTrailing,
  });

  final String keyPrefix;
  final LoopWalletBalances? balances;
  final bool loading;
  final String? unreadText;

  /// The active wallet's truncated address, when one is active.
  final String? address;

  /// The same address in full, which the copy glyph puts on the clipboard.
  final String? fullAddress;

  /// Decision 0100: the backend environment on a non-release build.
  final String? environmentTag;

  final String? walletId;

  /// Drawn right after the address and its copy glyph (S349: 钱包管理),
  /// whether or not a wallet is active.
  final Widget? addressTrailing;

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

  /// The truncated address with its copy glyph; a tap copies it in full.
  Widget _addressLine(
    BuildContext context, {
    required String address,
    required String? fullAddress,
    required TextStyle sublineStyle,
    required Color auxiliary,
  }) {
    final keyPrefix = widget.keyPrefix;
    return Semantics(
      button: fullAddress != null,
      label: fullAddress == null
          ? address
          : context.l10n.wallet_homeLabel(address),
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>('$keyPrefix-address-copy'),
        scale: false,
        onTap: fullAddress == null
            ? null
            : () => unawaited(
                LoopCopy.text(
                  context,
                  fullAddress,
                  message: context.l10n.wallet_homeMessage,
                ),
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
                // §5.10: gap 7, the copy glyph 16.
                const SizedBox(width: 7),
                WalletFigmaGlyph(
                  WalletFigmaGlyph.copy,
                  size: 16,
                  color: auxiliary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The 今日盈亏 line opens and closes the chart (decision 0259).
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
      LoopNetWorthUnavailable() => context.l10n.wallet_homeUnreadText,
      null => widget.unreadText ?? context.l10n.wallet_homeUnreadText,
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
    // Decision 0259: a closed chart reads nothing beyond the week 今日盈亏
    // needs.
    final chartState = !expanded
        ? null
        : range == LoopNetWorthRange.week
        ? weekState
        : _watchHistory((walletId: walletId, range: range));
    final week = weekState?.value;
    final fiat = week?.fiat;

    final caption = walletNetWorthCaption(netWorth);

    // S353c · decision 0280 (docs/58 §5.10): the figure is Inter 40 / 700
    // in white, no unit after it — the `$` already says USD. It scales down
    // rather than cut a long figure short.
    final figureRow = Align(
      alignment: AlignmentDirectional.centerStart,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          figure,
          key: ValueKey<String>('$keyPrefix-total-figure'),
          maxLines: 1,
          style: figureIsAmount
              ? LoopType.plateFigure.copyWith(color: LoopColors.textPrimary)
              : LoopType.headingSm.copyWith(color: secondary),
        ),
      ),
    );

    final fiatText = fiat != null && fiat.currency == 'CNY'
        ? '≈ ¥${hidden ? walletMaskedFigure : loopFormatDecimal(fiat.amount, maxFractionDigits: 2)}'
        : null;
    final fullAddress = widget.fullAddress;
    // Decision 0194: a stale rate wears the market figures' stale badge
    // right after the ¥ amount; the line's words do not change.
    final fiatStale = fiatText != null && fiat!.stale;
    final staleMarker = loopFactQualityMarker(LoopFactQuality.stale)!;
    // §5.10: 「总资产」, the ¥ line and the address are 14 / 400 secondary.
    final sublineStyle = LoopType.body2Sm.copyWith(
      color: LoopColors.textSecondary,
    );
    final address = widget.address;

    final fiatLine = fiatText == null
        ? null
        : Text.rich(
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
          );

    // §5.10: the yellow trend at the right of the figure, the week the
    // server stored; a tap opens the chart as the 今日盈亏 line does. No
    // history, no trend — never a drawn-in shape.
    final trend = historyOn && (week?.drawable ?? false)
        ? Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: WalletNetWorthTrend(
              key: ValueKey<String>('$keyPrefix-networth-trend'),
              history: week!,
              expanded: expanded,
              onTap: _toggle,
            ),
          )
        : null;

    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      context.l10n.wallet_homeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sublineStyle,
                    ),
                  ),
                  _HeaderGlyphButton(
                    key: ValueKey<String>('$keyPrefix-eye'),
                    label: hidden
                        ? context.l10n.wallet_homeLabel2
                        : context.l10n.wallet_homeLabel3,
                    toggled: hidden,
                    onTap: () => unawaited(
                      ref.read(loopBalanceVisibilityProvider.notifier).toggle(),
                    ),
                    child: hidden
                        ? Icon(
                            Icons.visibility_off_outlined,
                            size: 19,
                            color: LoopColors.textSecondary,
                          )
                        : const WalletFigmaGlyph(
                            WalletFigmaGlyph.eye,
                            size: 19,
                            color: LoopColors.textSecondary,
                          ),
                  ),
                  if (widget.environmentTag case final String tag)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
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
                  child: const LoopSkeletonBlock(width: 168, height: 38),
                )
              else
                figureRow,
            ],
          ),
        ),
        ?trend,
      ],
    );

    return Padding(
      key: ValueKey<String>('$keyPrefix-total-header'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          head,
          // §5.10: 「≈ ¥0.00 | 今日盈亏 —」 is one line. With a history the
          // whole line opens the chart (decision 0259); without one the ¥
          // amount stands alone.
          if (historyOn)
            WalletPnlLine(
              keyPrefix: keyPrefix,
              change: week?.change24h,
              hasHistory: week != null,
              hidden: hidden,
              expanded: expanded,
              onTap: _toggle,
              leading: fiatLine,
              leadingText: fiatText,
              // The stale badge after the ¥ amount, with its 6 before it.
              leadingExtra: fiatStale ? 48 : 0,
            )
          else if (fiatLine != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: fiatLine),
          // S349: the address, its copy glyph, then 管理 right after them.
          if (address != null || widget.addressTrailing != null)
            Row(
              children: <Widget>[
                if (address != null)
                  Flexible(
                    child: _addressLine(
                      context,
                      address: address,
                      fullAddress: fullAddress,
                      sublineStyle: sublineStyle,
                      auxiliary: LoopColors.textSecondary,
                    ),
                  ),
                if (address != null && widget.addressTrailing != null)
                  const SizedBox(width: 12),
                ?widget.addressTrailing,
              ],
            ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: Text(
                caption,
                key: ValueKey<String>('$keyPrefix-total-caption'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption.copyWith(color: auxiliary),
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: WalletNetWorthPanel(
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
              ),
            ),
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
      // 44 × 44 (audit 2026-10-09 m3): the finger gets the whole square.
      // S353c (docs/58 §5.10): the glyph sits 8 after the word before it,
      // at the square's leading edge.
      child: SizedBox(
        width: LoopTouch.minimum,
        height: LoopTouch.minimum,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: child,
          ),
        ),
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
    barrierLabel: context.l10n.wallet_homeBarrierLabel,
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
            LoopSheetHeading(context.l10n.wallet_homeLoopSheetHeading),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    context.l10n.wallet_homeShowWalletTotalInfoSheet,
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
                      label: context.l10n.wallet_homeLabel4,
                      value: loopFactSourceLabel(valued.priceSource),
                      padding: EdgeInsets.zero,
                    ),
                    LoopKeyValue(
                      label: context.l10n.wallet_homeLabel5,
                      value: loopDateTimeLabel(valued.asOf),
                      padding: EdgeInsets.zero,
                    ),
                    if (valued.partial)
                      LoopKeyValue(
                        label: context.l10n.wallet_homeLabel6,
                        value: context.l10n.wallet_homeValue(
                          valued.unavailableCount,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    LoopKeyValue(
                      label: context.l10n.wallet_homeLabel7,
                      value: switch (valued.change24h) {
                        LoopNetWorthChangeAvailable() =>
                          context.l10n.wallet_homeLoopNetWorthChangeAvailable,
                        LoopNetWorthChangeUnavailable() =>
                          context.l10n.wallet_homeLoopNetWorthChangeUnavailable,
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ] else if (netWorth case LoopNetWorthUnavailable(
                    reasonCode: final reason,
                  ))
                    LoopKeyValue(
                      label: context.l10n.wallet_homeText,
                      value: loopReasonCodeText(reason),
                      padding: EdgeInsets.zero,
                    ),
                  if (snapshot != null) ...<Widget>[
                    LoopKeyValue(
                      label: context.l10n.wallet_homeLabel8,
                      value: loopGroupedFigure(snapshot.blockNumber.toString()),
                      padding: EdgeInsets.zero,
                    ),
                    LoopKeyValue(
                      label: context
                          .l10n
                          .wallet_txResultTxResultConfirmationsLabel,
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
                      label: context.l10n.wallet_homeLabel9,
                      value: snapshotSource.source,
                      padding: EdgeInsets.zero,
                    ),
                    if (snapshotSource.observedAt case final DateTime at)
                      LoopKeyValue(
                        label: context.l10n.wallet_homeLabel10,
                        value: loopDateTimeLabel(at),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                  if (balances != null)
                    LoopKeyValue(
                      label: context.l10n.wallet_homeLabel11,
                      value:
                          '${loopFormatDecimal(balances.gasReservePolicy.nativeReserve)} BNB',
                      padding: EdgeInsets.zero,
                    ),
                  const SizedBox(height: 16),
                  LoopButton(
                    label: context.l10n.common_gotIt,
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

/// The disc's key id: the action key's own id (`wallet-receive-entry` →
/// `receive`), never the label (decision 0281).
String _discId(WalletQuickAction action) => switch (action.actionKey) {
  ValueKey<String>(:final value) =>
    value.replaceFirst('wallet-', '').replaceFirst(RegExp(r'-entry$'), ''),
  _ => action.label,
};

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

/// 接收 / 发送 / 兑换 / 扫码 / DApp — one row of equal keys (S353c ·
/// decision 0280, docs/58 §5.11): a 24 line glyph over a 14 / 500 word, no
/// ground, a 1 × 28 rule between two keys. A closed key keeps its place,
/// dimmed, and says the server's sentence when pressed.
class WalletQuickActions extends StatelessWidget {
  const WalletQuickActions({
    required this.actions,
    required this.onBlocked,
    super.key,
  });

  final List<WalletQuickAction> actions;
  final void Function(String reason) onBlocked;

  /// The glyph's side (§5.11).
  static const double glyphSize = 24;

  /// The rule between two keys: 1 × 28, `dividerSolid` (§5.11).
  static const Size ruleSize = Size(1, 28);

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('wallet-quick-actions'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        18,
        LoopSpacing.page,
        6,
      ),
      // Top-aligned, so a word that takes a second line never moves its
      // glyph; the rules sit level with the glyphs and single-line words.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  key: ValueKey<String>('wallet-quick-rule-$index'),
                  width: ruleSize.width,
                  height: ruleSize.height,
                  color: LoopColors.dividerSolid,
                ),
              ),
            Expanded(
              child: _QuickActionTile(
                action: actions[index],
                onBlocked: onBlocked,
              ),
            ),
          ],
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
    // §5.11: the glyph and the word in the primary text colour; a closed key
    // keeps its place in the tertiary colour. [primary] is kept on the model
    // but no longer changes the paint (decision 0212).
    final ink = enabled ? LoopColors.textPrimary : LoopColors.textTertiary;
    final onTap = run ?? (reason == null ? null : () => onBlocked(reason));
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled
          ? action.label
          : context.l10n.wallet_homeLabel12(action.label),
      // The gesture below is excluded with the rest of the subtree, so the
      // tap is offered here or a screen reader could not press the key.
      onTap: onTap,
      excludeSemantics: true,
      child: LoopPressable(
        key: action.actionKey,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                key: ValueKey<String>('wallet-quick-disc-${_discId(action)}'),
                dimension: WalletQuickActions.glyphSize,
                child: Center(child: action.glyph(ink)),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                // A long word takes a second line rather than an ellipsis.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: LoopType.label.copyWith(color: ink),
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

/// 「产生算力」 at the right of 「代币 / NFT」, opening 情报 · 算力.
///
/// S353c · decision 0280 (docs/58 §5.3): the frame's word, 12 / 500
/// secondary, with the (i) 16 after it — no badge ground.
class WalletPowerTag extends StatelessWidget {
  const WalletPowerTag({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.wallet_homeWalletPowerTagLabel,
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('wallet-power-tag'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  context.l10n.wallet_homeLoopBadge,
                  key: const ValueKey<String>('wallet-power-tag-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.meta.copyWith(
                    color: LoopColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const WalletFigmaGlyph(
                WalletFigmaGlyph.info,
                size: 16,
                color: LoopColors.textSecondary,
              ),
            ],
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
    barrierLabel: context.l10n.wallet_homeWalletPowerSheetBarrierLabel,
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('wallet-power-sheet'),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // R2 (decision 0190 M14).
          LoopSheetHeading(context.l10n.wallet_homeLoopSheetHeading2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.wallet_homeShowWalletPowerSheet,
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
              label: context.l10n.common_gotIt,
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
        label: context.l10n.wallet_homeLabel13(row.symbol),
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
                      message: context.l10n.wallet_homeMessage2(
                        loopReasonCodeText(balance.reasonCode),
                      ),
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
        context.l10n.wallet_homeIf(
          hidden ? walletMaskedFigure : loopFormatDecimal(value),
        ),
      if (row.crossCheck.isMisaligned) context.l10n.wallet_homeIf2,
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
            ? context.l10n.wallet_homeSwitch(valueText)
            : context.l10n.wallet_homeS(valueText, walletRowChangeText(pct));
      case LoopValuationUnavailable():
        valueText = context.l10n.wallet_homeValueText;
        change = null;
        valueLabel = context.l10n.wallet_homeValueText;
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
      semanticLabel: context.l10n.wallet_homeSemanticLabel(
        amount,
        row.symbol,
        valueLabel,
      ),
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
///
/// S350c · decision 0276: a filter under 持仓, one step below the page's
/// own 持仓 / 交易 / 社区 tabs — the framed chip at [filterHeight] with the
/// label-sized word, 16 under the tabs.
class WalletAssetTabs extends StatelessWidget {
  const WalletAssetTabs({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.trailing,
  });

  static List<String> get labels => <String>[
    LoopL10n.current.common_token,
    'NFT',
  ];
  static const int tokens = 0;
  static const int nft = 1;
  static const List<String> _keys = <String>['tokens', 'nft'];

  /// The drawn height of a filter chip under the profile tabs (S350c;
  /// decision 0277: the Figma's 54 × 32 chip, [LoopFilterChips]).
  static const double filterHeight = LoopTouch.chipHeight;

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey<String>('wallet-asset-tabs'),
    // S350c: 16 under the profile tabs — the chip's own room above its
    // face makes up the rest — and the rows keep their own 14 under.
    padding: EdgeInsets.fromLTRB(
      0,
      LoopSpacing.segmentGap - (LoopTouch.minimum - filterHeight) / 2,
      0,
      4,
    ),
    child: LoopFilterChips(
      labels: labels,
      keys: <Key>[
        for (final key in _keys) ValueKey<String>('wallet-asset-tab-$key'),
      ],
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      trailing: trailing,
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
    if (rest > Decimal.zero)
      (label: LoopL10n.current.wallet_homeLabel14, percent: share(rest)),
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
        .join(context.l10n.common_listSeparator);
    return LoopRecordCard(
      key: const ValueKey<String>('wallet-distribution'),
      // S241b: room under the square quick keys, which had touched the card.
      margin: LoopRecordCard.defaultMargin.copyWith(top: 16),
      padding: const EdgeInsets.all(LoopSpacing.card),
      child: Semantics(
        container: true,
        label: context.l10n.wallet_homeWalletDistributionBarLabel(label),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              context.l10n.wallet_homeBuild,
              style: LoopType.body2.copyWith(color: secondary),
            ),
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
    final amount = hidden
        ? walletMaskedFigure
        : loopFormatDecimal(balance.displayBalance);
    final valuation = row.valuation;
    // S343 · decision 0271: the second line is the asset's name; the gas
    // reserve is stated on the asset's own page.
    final subtitle = row.name;
    final marks = <String>[
      if (valuation is LoopValuationAvailable)
        ?loopFactQualityMarker(valuation.quality),
      if (row.pending case LoopPendingAvailable(value: final value)
          when value > Decimal.zero)
        context.l10n.wallet_homeIf(
          hidden ? walletMaskedFigure : loopFormatDecimal(value),
        ),
      if (row.crossCheck.isMisaligned) context.l10n.wallet_homeIf2,
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
        valueText = context.l10n.wallet_homeValueText;
    }

    // S353c · decision 0280 (docs/58 §5.13): avatar 36, the symbol 14 / 500
    // over a 12 / 300 line, the amount 14 / 600 over the 12 / 300 value.
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
            size: LoopRowHeight.holdingsAvatar,
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
                  style: LoopType.body1.copyWith(color: ink, height: 1.25),
                ),
                const SizedBox(height: 4),
                // S343 · decision 0271: one short fact — the data quality
                // note when there is one, else the asset's name.
                Text(
                  marks.isEmpty
                      ? subtitle
                      : marks.join(context.l10n.common_listSeparator),
                  key: ValueKey<String>(
                    marks.isEmpty
                        ? 'wallet-balance-subtitle-${row.assetId}'
                        : 'wallet-balance-mark-${row.assetId}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption.copyWith(color: secondary),
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
                style: LoopType.figureSm.copyWith(color: ink, height: 1.25),
              ),
              const SizedBox(height: 4),
              // v3 (decision 0229): the value and its 24 h move share the
              // caption line.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    valueText,
                    key: ValueKey<String>(
                      'wallet-balance-value-${row.assetId}',
                    ),
                    maxLines: 1,
                    style: LoopType.caption.copyWith(color: secondary),
                  ),
                  if (changePct != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      changePct,
                      key: ValueKey<String>(
                        'wallet-balance-change-${row.assetId}',
                      ),
                      maxLines: 1,
                      style: LoopType.caption.copyWith(color: changeColour!),
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
      // §9.4: a holdings row draws no divider; 6 above and below, 51 tall.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              key: ValueKey<String>('wallet-balance-head-${row.assetId}'),
              constraints: const BoxConstraints(
                minHeight: LoopRowHeight.holdings,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Semantics(
                    label: context.l10n.wallet_homeLabel15(
                      amount,
                      changeText == null
                          ? ''
                          : context.l10n.wallet_homeSX(changeText),
                      subtitle,
                      row.symbol,
                      valueText,
                    ),
                    excludeSemantics: true,
                    button: onTap != null,
                    child: top,
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WalletRowActions(actions: actions, onBlocked: onBlocked),
              ),
          ],
        ),
      ),
    );
  }
}

/// 钱包管理 right after the address (S349). S353c · decision 0280 (docs/58
/// §5.20): the frame's dark secondary button — white 8 %, r8, the wallet
/// glyph and 「管理」 in Yellow 13 / 600, 28 tall. The finger target stays
/// [LoopTouch.minimum] tall.
class WalletManagePill extends StatelessWidget {
  const WalletManagePill({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.wallet_homeLabel16,
      excludeSemantics: true,
      onTap: onPressed,
      child: LoopPressable(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: LoopColors.buttonGhost,
                borderRadius: LoopRadius.button,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const WalletFigmaGlyph(
                    WalletFigmaGlyph.wallet,
                    size: 14,
                    color: LoopColors.yellow,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.wallet_homeBuild2,
                    maxLines: 1,
                    style: LoopType.buttonSm.copyWith(color: LoopColors.yellow),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
