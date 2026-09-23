import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Whether an S5 page must stop at the capability gate instead of reading.
bool loopChainCapabilityBlocks(
  LoopChainGatewayMode mode,
  LoopCapabilityProjection capability,
) => mode != LoopChainGatewayMode.preview && !capability.isAvailable;

/// Formats an exact [Decimal] for display.
///
/// Grouping and rounding happen here and nowhere else; the model keeps the
/// exact value, and no `double` is involved.
String loopFormatDecimal(
  Decimal value, {
  int maxFractionDigits = 8,
  bool group = true,
  bool signed = false,
}) {
  final negative = value < Decimal.zero;
  final absolute = negative ? -value : value;
  final rounded = absolute.round(scale: maxFractionDigits);
  var text = rounded.toString();
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = text.split('.');
  var integer = parts.first;
  if (group && integer.length > 3) {
    final buffer = StringBuffer();
    for (var index = 0; index < integer.length; index += 1) {
      if (index > 0 && (integer.length - index) % 3 == 0) buffer.write(',');
      buffer.write(integer[index]);
    }
    integer = buffer.toString();
  }
  final body = parts.length == 1 ? integer : '$integer.${parts[1]}';
  final sign = negative ? '-' : (signed ? '+' : '');
  return '$sign$body';
}

/// A server decimal string with thousands separators, when grouping cannot
/// change what the string says.
///
/// Figures the server owns print verbatim: an alert threshold, a mining power,
/// a daily output. Verbatim also meant 「900000」 and 「1000000」 — seven digits
/// a reader has to count. Grouping is display-only, so it is applied only when
/// it is provably reversible: the string is parsed exactly, re-printed with
/// every fraction digit it carried, and used only when removing the separators
/// gives back the original character for character. Anything else — a value
/// that does not parse, one with trailing zeros that would be dropped — prints
/// as it arrived.
String loopGroupedFigure(String raw) {
  if (!raw.contains(RegExp(r'[0-9]{4}'))) return raw;
  final value = Decimal.tryParse(raw);
  if (value == null) return raw;
  final dot = raw.indexOf('.');
  final grouped = loopFormatDecimal(
    value,
    maxFractionDigits: dot < 0 ? 0 : raw.length - dot - 1,
  );
  return grouped.replaceAll(',', '') == raw ? grouped : raw;
}

String loopFormatUsd(Decimal value) =>
    '\$${loopFormatDecimal(value, maxFractionDigits: 2)}';

/// Figures at or above this read as `K` / `M` / `B` / `T` in a summary slot.
/// Below it the whole-dollar form is short enough to fit (`$8,200`, `84`).
final Decimal _loopCompactFrom = Decimal.fromInt(100000);

/// The first figure that reads in `M` rather than `K`; each further suffix is
/// a thousand times this one.
final Decimal _loopCompactSecondStep = Decimal.fromInt(1000000);
final Decimal _loopCompactCarry = Decimal.fromInt(1000);
const List<String> _loopCompactSuffixes = <String>['K', 'M', 'B', 'T'];

/// A compact figure for a **summary slot** — today the Token Card metric cells.
///
/// The budget is measured, not guessed: a metric cell is 94.0pt wide on a
/// 390pt screen, and the 13pt mono figure fits exactly seven characters
/// (≈90.3pt) there. The eighth ellipsises, which leaves the reader with
/// neither the magnitude nor the number — that is what a full market cap
/// (`$5,412,003,118.24`) and a full liquidity figure (`$42,750.31`) both did.
/// Every form produced here stays inside seven: `$999.9K`, `$99,999`,
/// `$1,000T`, `$-2.4M`.
///
/// So: no fractional cents at any magnitude, and at or above 100,000 the
/// magnitude itself, to one decimal with a trailing `.0` dropped. The
/// threshold is applied to the **rounded** figure, because 99,999.995 prints
/// as `100,000` — eight characters — and belongs in the compact branch.
///
/// It is for summaries only. Anywhere the exact figure is the point — the fact
/// list under the card, any amount a user is about to sign — keeps
/// [loopFormatUsd] / [loopFormatDecimal], and the card's own precise values
/// stay one screenful below it.
///
/// Rounding runs on [Decimal] throughout, half away from zero; no `double` is
/// involved. A negative value places its sign where [loopFormatUsd] places it
/// (`$-2.4M`).
String loopFormatCompactFigure(
  Decimal value, {
  bool usd = true,
  bool preciseBelowOne = false,
  int significantDigits = _loopSubUnitSignificantDigits,
}) {
  final negative = value < Decimal.zero;
  final absolute = negative ? -value : value;
  if (preciseBelowOne && absolute > Decimal.zero && absolute < Decimal.one) {
    return _loopSubUnitFigure(
      absolute,
      negative: negative,
      usd: usd,
      significantDigits: significantDigits,
    );
  }
  final whole = absolute.round();
  if (whole < _loopCompactFrom) {
    if (absolute > Decimal.zero && whole == Decimal.zero) {
      // A real value rounded to `0` would read as "none at all" — for a
      // liquidity cell, as a pulled pool. It is bounded instead. An exact
      // zero still prints as zero: that one is a fact.
      final marker = negative ? '>-' : '<';
      return usd ? '$marker\$1' : '${marker}1';
    }
    final body = loopFormatDecimal(
      negative ? -whole : whole,
      maxFractionDigits: 0,
    );
    return usd ? '\$$body' : body;
  }
  var step = 1;
  while (step < _loopCompactSuffixes.length &&
      absolute >= _loopCompactSecondStep.shift(3 * (step - 1))) {
    step += 1;
  }
  var scaled = absolute.shift(-3 * step).round(scale: 1);
  // Rounding can carry across the unit: 999,950 reads `1000.0K`, which is one
  // step up. Take the step while there is one; the top unit saturates and
  // prints four digits (`$5,000T`), which is still inside the budget.
  if (scaled >= _loopCompactCarry && step < _loopCompactSuffixes.length) {
    step += 1;
    scaled = absolute.shift(-3 * step).round(scale: 1);
  }
  final body =
      '${negative ? '-' : ''}'
      '${loopFormatDecimal(scaled, maxFractionDigits: 1)}'
      '${_loopCompactSuffixes[step - 1]}';
  return usd ? '\$$body' : body;
}

/// How far below a dollar [loopFormatCompactFigure] will go before it bounds
/// the figure instead of printing it. A four.meme pool trades around 1e-6; a
/// cap this deep covers every price a BSC pool has quoted and still ends.
const int _loopSubUnitMaxScale = 18;
const int _loopSubUnitSignificantDigits = 3;

/// Three significant digits for a figure below a dollar.
///
/// The summary form rounds to whole dollars, so everything under one read as
/// 「<$1」 — on the new-pairs page that is neither the price (1e-6 for a
/// launchpad pool) nor a reason the price is missing, and the page promises
/// one or the other. Three significant digits is the shortest form that still
/// says the magnitude: `$0.0000012`, `$0.874`.
/// [significantDigits] widens that to four for the 行情 price column, which is
/// the one place a sub-dollar price is read against the row above it rather
/// than as a summary (decision 0085).
String _loopSubUnitFigure(
  Decimal absolute, {
  required bool negative,
  required bool usd,
  int significantDigits = _loopSubUnitSignificantDigits,
}) {
  var scale = 0;
  var scaled = absolute;
  // The first significant digit has to be found before three of them can be
  // kept: 0.0000012 carries none until the sixth decimal place.
  while (scaled < Decimal.one && scale < _loopSubUnitMaxScale) {
    scaled = scaled.shift(1);
    scale += 1;
  }
  final body = loopFormatDecimal(
    negative ? -absolute : absolute,
    maxFractionDigits: scale + significantDigits - 1,
  );
  if (body == '0') {
    // Smaller than this cap can print. It is still not a zero, and it is
    // still not 「<$1」: the bound says how small.
    final bound = '0.${'0' * (_loopSubUnitMaxScale - 1)}1';
    final marker = negative ? '>-' : '<';
    return usd ? '$marker\$$bound' : '$marker$bound';
  }
  return usd ? '\$$body' : body;
}

String loopFormatPercent(Decimal value) =>
    '${loopFormatDecimal(value, maxFractionDigits: 2, signed: true)}%';

/// Coarse "N 分钟前" label. It always accompanies, never replaces, the source.
String loopRelativeTime(DateTime observedAt, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final delta = reference.difference(observedAt.toUtc());
  if (delta.isNegative) return '刚刚';
  if (delta.inSeconds < 60) return '${delta.inSeconds} 秒前';
  if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
  if (delta.inHours < 24) return '${delta.inHours} 小时前';
  return '${delta.inDays} 天前';
}

/// "来源 DexScreener · 观察于 4 分钟前" — the sentence every fact carries.
String loopFactProvenance(LoopFact fact, {DateTime? now}) {
  final source = fact.source;
  final fetchedAt = fact.fetchedAt;
  if (source == null) return '来源未标注';
  final label = '来源 ${loopFactSourceLabel(source)}';
  if (fetchedAt == null) return label;
  return '$label · 观察于 ${loopRelativeTime(fetchedAt, now: now)}';
}

/// The one place the reviewed states are rendered for an S5 block.
class LoopChainStateBlock extends StatelessWidget {
  const LoopChainStateBlock({
    required this.phase,
    required this.failureKind,
    super.key,
    this.onRetry,
    this.emptyMessage = '这里还没有内容',
    this.emptyReason,
    this.permissionTitle = '当前账号没有权限',
    this.onOpenSecurity,
    this.skeleton = LoopSkeletonType.list,
    this.rows = 3,
    this.keyPrefix = 'chain',
    this.refreshing = false,
  });

  final LoopChainViewPhase phase;
  final LoopChainFailureKind? failureKind;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? emptyReason;
  final String permissionTitle;

  /// Only the step-up branch uses it: step-up is not delivered, so the security
  /// centre is the one destination that could ever change the answer.
  final VoidCallback? onOpenSecurity;
  final LoopSkeletonType skeleton;
  final int rows;
  final String keyPrefix;

  /// `LoopChainResourceState.refreshing`: a re-read over data the page already
  /// shows. The block marks it instead of covering the data with a skeleton.
  final bool refreshing;

  /// How long a rate-limited read holds its retry. Short enough to be a pause
  /// rather than a lock-out, long enough that a second tap is a second ask.
  static const rateLimitCooldown = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case LoopChainViewPhase.loading:
        return LoopSkeleton(
          key: ValueKey<String>('$keyPrefix-state-loading'),
          type: skeleton,
          rows: rows,
        );
      case LoopChainViewPhase.empty:
        return LoopEmpty(
          key: ValueKey<String>('$keyPrefix-state-empty'),
          message: emptyMessage,
          reason: emptyReason,
        );
      case LoopChainViewPhase.offline:
        return LoopOfflineState(
          key: ValueKey<String>('$keyPrefix-state-offline'),
          onRetry: onRetry,
          pausedActions: const <String>['刷新', '切换钱包', '保存自选', '价格提醒'],
        );
      case LoopChainViewPhase.unavailable:
        return LoopEmpty(
          key: ValueKey<String>('$keyPrefix-state-unavailable'),
          icon: 'warn',
          message: '该内容当前不可用',
          reason: loopChainFailureReason(failureKind),
        );
      case LoopChainViewPhase.permission:
        final stepUp = failureKind == LoopChainFailureKind.stepUpRequired;
        return LoopPermissionState(
          key: ValueKey<String>('$keyPrefix-state-permission'),
          icon: 'shield',
          // The server answered; the block never offers a retry.
          denied: true,
          title: stepUp
              ? '这一步需要二次验证'
              : failureKind == LoopChainFailureKind.regionBlocked
              ? '当前地区不能执行此操作'
              : permissionTitle,
          purpose: loopChainPermissionPurpose(failureKind),
          settingsLabel: '前往安全中心',
          onOpenSettings: stepUp ? onOpenSecurity : null,
        );
      case LoopChainViewPhase.error:
        // `429` is the server saying the asks are coming too fast. A retry
        // that is tappable the instant the card appears earns another `429`,
        // which is how three taps in a row on 网络与 RPC produced three
        // identical screens. The button stays, visibly, and comes back after
        // the cool-down.
        if (failureKind == LoopChainFailureKind.rateLimited &&
            onRetry != null) {
          return _LoopChainCoolingRetry(
            key: ValueKey<String>('$keyPrefix-state-error'),
            reason: loopChainFailureReason(failureKind),
            onRetry: onRetry!,
          );
        }
        return LoopErrorState(
          key: ValueKey<String>('$keyPrefix-state-error'),
          reason: loopChainFailureReason(failureKind),
          onRetry: onRetry,
        );
      case LoopChainViewPhase.ready:
        return LoopUpdatingBadge(
          key: ValueKey<String>('$keyPrefix-state-updating'),
          visible: refreshing,
        );
    }
  }
}

/// A rate-limited read's error card: the retry is held for
/// [LoopChainStateBlock.rateLimitCooldown] before it may be taken.
///
/// The card is rebuilt from scratch on every new failure — the block renders a
/// skeleton in between — so each refusal starts its own cool-down.
class _LoopChainCoolingRetry extends StatefulWidget {
  const _LoopChainCoolingRetry({
    required this.reason,
    required this.onRetry,
    super.key,
  });

  final String reason;
  final VoidCallback onRetry;

  @override
  State<_LoopChainCoolingRetry> createState() => _LoopChainCoolingRetryState();
}

class _LoopChainCoolingRetryState extends State<_LoopChainCoolingRetry> {
  Timer? _timer;
  bool _cooling = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(LoopChainStateBlock.rateLimitCooldown, () {
      if (mounted) setState(() => _cooling = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoopErrorState(
      reason: widget.reason,
      onRetry: widget.onRetry,
      retryEnabled: !_cooling,
      retryLabel: _cooling ? '稍后重试' : '重试',
    );
  }
}

/// Visible Preview truth label for a chain-backed page.
///
/// Reads and writes made under a Preview adapter stay in the running process:
/// they never reach an account, a provider or a chain. Production and
/// unavailable modes render nothing, so the label can never appear outside
/// Preview.
class LoopChainPreviewNotice extends StatelessWidget {
  const LoopChainPreviewNotice({
    required this.mode,
    required this.resource,
    super.key,
  });

  final LoopChainGatewayMode mode;
  final String resource;

  @override
  Widget build(BuildContext context) {
    if (mode != LoopChainGatewayMode.preview) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('chain-preview-notice'),
      icon: 'info',
      tone: LoopNoticeTone.warn,
      title: '演示数据',
      body: '$resource只存在于这次开发预览里，不会写入账号，也不会上传。',
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    );
  }
}

/// `开发预览` eyebrow for a Preview-backed chain page.
String? loopChainPreviewKicker(LoopChainGatewayMode mode) =>
    mode == LoopChainGatewayMode.preview ? '开发预览' : null;

/// The sentence a refused read or write renders.
///
/// It states the rule, what did not happen, and the one alternative that
/// actually exists. It never offers a setting the product has not delivered.
String loopChainPermissionPurpose(LoopChainFailureKind? kind) => switch (kind) {
  LoopChainFailureKind.stepUpRequired =>
    '${loopChainFailureReason(kind)}请到安全中心查看当前可用的验证方式；'
        '本页已读到的内容不受影响。',
  // A jurisdiction rule is not an account one, so no alternative account or
  // asset is offered — there is none.
  LoopChainFailureKind.regionBlocked =>
    '${loopChainFailureReason(kind)}本页已读到的内容不受影响。',
  _ =>
    '${loopChainFailureReason(kind)}这项权限不能在应用里自行调整；'
        '可以换一个已获授权的账号或资产，本页已读到的内容不受影响。',
};

/// The block a page renders when the server refused a **command** it issued
/// from an already-loaded page.
///
/// [LoopChainStateBlock] covers a refused read; this covers a refused write,
/// where the page keeps rendering the resource it already read. A refusal is
/// not an error: the request arrived, was understood and was answered "no".
/// Offering a retry would claim the answer might change, so the block names
/// the rule instead and — for a step-up — points at the security centre, the
/// only place that could ever change it.
class LoopChainCommandPermission extends StatelessWidget {
  const LoopChainCommandPermission({
    required this.blockKey,
    required this.failureKind,
    required this.title,
    super.key,
    this.onOpenSecurity,
  });

  /// True when this failure is a server refusal rather than a fault.
  static bool covers(LoopChainFailureKind? kind) =>
      kind == LoopChainFailureKind.permissionDenied ||
      kind == LoopChainFailureKind.regionBlocked ||
      kind == LoopChainFailureKind.stepUpRequired;

  final String blockKey;
  final LoopChainFailureKind? failureKind;
  final String title;
  final VoidCallback? onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    final stepUp = failureKind == LoopChainFailureKind.stepUpRequired;
    return LoopPermissionState(
      key: ValueKey<String>(blockKey),
      icon: 'shield',
      denied: true,
      title: stepUp
          ? '这一步需要二次验证'
          : failureKind == LoopChainFailureKind.regionBlocked
          ? '当前地区不能执行此操作'
          : title,
      purpose: loopChainPermissionPurpose(failureKind),
      settingsLabel: '前往安全中心',
      onOpenSettings: stepUp ? onOpenSecurity : null,
    );
  }
}

/// Renders one `{status: unavailable, reasonCode}` block. It never renders a
/// figure, a zero, or a fixture in place of the missing fact.
///
/// It is an inline strip, like every other state block since decision 0071:
/// one glyph, what is missing, why, and — when there is one — the single step
/// that could change the answer.
class LoopUnavailableCard extends StatelessWidget {
  const LoopUnavailableCard({
    required this.label,
    required this.reasonCode,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.action,
  });

  LoopUnavailableCard.fact({
    required String label,
    required LoopUnavailable fact,
    Key? key,
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16),
    Widget? action,
  }) : this(
         label: label,
         reasonCode: fact.reasonCode,
         key: key,
         margin: margin,
         action: action,
       );

  final String label;

  /// `null` when the server stated no reason. The card then renders the
  /// neutral sentence rather than inventing a code the server never sent.
  final String? reasonCode;
  final EdgeInsets margin;

  /// The one next step, when one exists. A block with no next step shows none.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: ValueKey<String>('unavailable-${reasonCode ?? 'unstated'}'),
      icon: 'warn',
      message: label,
      reason: loopReasonCodeText(reasonCode),
      margin: margin,
      action: action,
    );
  }
}

/// The whole-page counterpart of [LoopUnavailableCard].
///
/// A capability gate closes the page, not a block inside it, so it renders a
/// [LoopPageBlock] in the room the page scaffold hands it (`block:`) instead
/// of the inline strip a section uses.
///
/// It keeps two answers apart that used to share one sentence:
///
/// * the capability read did not get through, so LOOP was never reached and
///   there is no server reason to render. The next step belongs to the user:
///   change network and try again.
/// * LOOP answered and closed the capability, naming its own `reasonCode`.
///   Nothing on the device can change that, so the page renders the server's
///   sentence and offers no network advice — "wait" is the honest next step.
///
/// The client never invents a `reasonCode` for the first case; an unreachable
/// gate ignores [fallbackReasonCode] entirely.
class LoopCapabilityPageBlock extends StatelessWidget {
  const LoopCapabilityPageBlock({
    required this.title,
    super.key,
    this.reasonCode,
    this.unreachable = false,
    this.action,
  });

  /// Reads both facts off one projection.
  LoopCapabilityPageBlock.of({
    required String title,
    required LoopCapabilityProjection capability,
    Key? key,
    String? fallbackReasonCode,
    Widget? action,
  }) : this(
         title: title,
         reasonCode: capability.reasonCode ?? fallbackReasonCode,
         unreachable: capability.unreachable,
         action: action,
         key: key,
       );

  /// What the user cannot do on this page. Ignored while [unreachable], where
  /// the page cannot honestly name the capability that failed.
  final String title;

  /// The server's own rule name, when the server answered.
  final String? reasonCode;

  /// The capability read did not get through: LOOP itself was not reached.
  final bool unreachable;

  /// At most one next step.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (unreachable) return LoopPageBlock.unreachable(action: action);
    return LoopPageBlock(
      title: title,
      message: loopReasonCodeText(reasonCode),
      action: action,
    );
  }
}

/// The same capability gate, as a strip inside a page that keeps its shape.
///
/// A deferred capability is not a page with nothing on it. The prototype's
/// action pages keep their primary, their group headings and the room their
/// content will take, and state the reason inside that shape (visual audit
/// 2026-09-20, item 4). Use this where the page still has something to show —
/// a heading, a figure box, a group — and [LoopCapabilityPageBlock] only where
/// the page genuinely has nothing at all.
class LoopCapabilityBlockCard extends StatelessWidget {
  const LoopCapabilityBlockCard({
    required this.label,
    required this.capability,
    super.key,
    this.fallbackReasonCode,
  });

  /// What the reader cannot do here.
  final String label;
  final LoopCapabilityProjection capability;

  /// The rule to name when the server closed the gate without naming one. It
  /// is ignored for an unreachable gate, which has no server reason at all.
  final String? fallbackReasonCode;

  @override
  Widget build(BuildContext context) {
    if (capability.unreachable) {
      return LoopEmpty(
        key: const ValueKey<String>('capability-unreachable'),
        icon: 'offline',
        message: label,
        reason: loopChainFailureReason(LoopChainFailureKind.offline),
      );
    }
    return LoopUnavailableCard(
      label: label,
      reasonCode: capability.reasonCode ?? fallbackReasonCode,
    );
  }
}

/// One rendered market fact: the figure, its quality marker and its source.
///
/// An unavailable fact renders its explanation, never `0` and never `—`.
class LoopFactLine extends StatelessWidget {
  const LoopFactLine({
    required this.label,
    required this.fact,
    super.key,
    this.formatter,
    this.now,
    this.emphasize = false,
  });

  final String label;
  final LoopFact fact;

  /// Formats the exact value. Defaults to grouped decimal text.
  final String Function(Decimal value)? formatter;
  final DateTime? now;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final value = fact.value;
    final theme = Theme.of(context);
    if (value == null) {
      return Padding(
        key: ValueKey<String>('fact-$label-unavailable'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: LoopMono.label),
            const SizedBox(height: 4),
            Text(
              loopReasonCodeText(fact.reasonCode),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      );
    }
    final marker = loopFactQualityMarker(fact.quality);
    return Padding(
      key: ValueKey<String>('fact-$label'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: LoopMono.label),
          const SizedBox(height: 4),
          Text(
            (formatter ?? loopFormatDecimal)(value),
            style: emphasize ? LoopMono.headline : LoopMono.value,
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              if (marker != null) ...<Widget>[
                LoopBadge(
                  marker,
                  kind: fact.quality == LoopFactQuality.stale
                      ? LoopBadgeKind.down
                      : LoopBadgeKind.mute,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  loopFactProvenance(fact, now: now),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact provenance footer for a whole block.
class LoopProvenanceFooter extends StatelessWidget {
  const LoopProvenanceFooter({
    required this.text,
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 4, 16, 12),
  });

  final String text;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Text(
        text,
        key: const ValueKey<String>('provenance-footer'),
        style: LoopMono.stamp.copyWith(color: LoopColors.text3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// launch chain slot (decision 0038)
// ---------------------------------------------------------------------------

/// The "BSC 测试网" badge.
///
/// It states which chain the surface is bound to. It never disables anything,
/// never carries a warning tone, and never appears on a surface bound to the
/// primary chain: Market, Watchlist, Swap and Send can never render it,
/// because their chain id is a constant.
class LoopTestnetBadge extends StatelessWidget {
  const LoopTestnetBadge({super.key, this.onLedger = false});

  final bool onLedger;

  @override
  Widget build(BuildContext context) => LoopBadge(
    key: const ValueKey<String>('loop-testnet-badge'),
    loopTestnetBadgeLabel,
    onLedger: onLedger,
  );
}

/// The one-time explanation that accompanies the badge.
///
/// It is shown once per run across every Launch surface, it is dismissible,
/// and it blocks nothing: closing it leaves every action exactly as it was.
/// Pass [visible] the single fact that decides it — the published chain id is
/// the testnet — never a guess of the client's own.
class LoopTestnetNotice extends ConsumerWidget {
  const LoopTestnetNotice({
    required this.visible,
    super.key,
    this.margin = const EdgeInsets.fromLTRB(16, 14, 16, 0),
    this.compact = false,
  });

  final bool visible;
  final EdgeInsets margin;

  /// Whether the notice states the chain in one line.
  ///
  /// The four-sentence body belongs on the surface a signature is prepared
  /// on. On the Launch catalogue it cost the first screen: the audit
  /// (2026-09-21 §H.2) found the segment chips pushed below the fold by this
  /// card plus the chain row above it. The compact form keeps the same title,
  /// the same dismiss control and the same provider, and drops the body.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!visible || ref.watch(loopTestnetNoticeDismissedProvider)) {
      return const SizedBox.shrink();
    }
    return LoopNotice(
      key: const ValueKey<String>('loop-testnet-notice'),
      icon: 'info',
      title: loopTestnetNoticeTitle,
      body: compact ? null : loopTestnetNoticeBody,
      margin: margin,
      trailing: LoopIconButton(
        key: const ValueKey<String>('loop-testnet-notice-dismiss'),
        icon: 'close',
        label: '关闭测试网说明',
        onPressed: () =>
            ref.read(loopTestnetNoticeDismissedProvider.notifier).dismiss(),
      ),
    );
  }
}
