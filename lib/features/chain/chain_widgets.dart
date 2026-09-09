import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
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

String loopFormatUsd(Decimal value) =>
    '\$${loopFormatDecimal(value, maxFractionDigits: 2)}';

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
    this.skeleton = LoopSkeletonType.list,
    this.rows = 3,
    this.keyPrefix = 'chain',
  });

  final LoopChainViewPhase phase;
  final LoopChainFailureKind? failureKind;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? emptyReason;
  final String permissionTitle;
  final LoopSkeletonType skeleton;
  final int rows;
  final String keyPrefix;

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
        return LoopPermissionState(
          key: ValueKey<String>('$keyPrefix-state-permission'),
          icon: 'shield',
          title: failureKind == LoopChainFailureKind.stepUpRequired
              ? '这一步需要二次验证'
              : permissionTitle,
          purpose: loopChainPermissionPurpose(failureKind),
        );
      case LoopChainViewPhase.error:
        return LoopErrorState(
          key: ValueKey<String>('$keyPrefix-state-error'),
          reason: loopChainFailureReason(failureKind),
          onRetry: onRetry,
        );
      case LoopChainViewPhase.ready:
        return const SizedBox.shrink();
    }
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
      body: '$resource只存在于本次开发预览运行中，不会写入账号，也不会调用任何服务端。',
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
String loopChainPermissionPurpose(LoopChainFailureKind? kind) =>
    kind == LoopChainFailureKind.stepUpRequired
    ? '${loopChainFailureReason(kind)}请到安全中心查看当前可用的验证方式；'
          '本页已读到的内容不受影响。'
    : '${loopChainFailureReason(kind)}所需权限与策略由服务端授予，客户端无法调整；'
          '可以换一个已获授权的账号或资产，本页已读到的内容不受影响。';

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
      title: stepUp ? '这一步需要二次验证' : title,
      purpose: loopChainPermissionPurpose(failureKind),
      settingsLabel: '前往安全中心',
      onOpenSettings: stepUp ? onOpenSecurity : null,
    );
  }
}

/// Renders one `{status: unavailable, reasonCode}` block. It never renders a
/// figure, a zero, or a fixture in place of the missing fact.
class LoopUnavailableCard extends StatelessWidget {
  const LoopUnavailableCard({
    required this.label,
    required this.reasonCode,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  LoopUnavailableCard.fact({
    required String label,
    required LoopUnavailable fact,
    Key? key,
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16),
  }) : this(
         label: label,
         reasonCode: fact.reasonCode,
         key: key,
         margin: margin,
       );

  final String label;

  /// `null` when the server stated no reason. The card then renders the
  /// neutral sentence rather than inventing a code the server never sent.
  final String? reasonCode;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: ValueKey<String>('unavailable-${reasonCode ?? 'unstated'}'),
      icon: 'warn',
      message: label,
      reason: loopReasonCodeText(reasonCode),
      margin: margin,
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
