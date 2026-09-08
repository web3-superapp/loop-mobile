import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// Sign sheet states (prototype `sign-sheet-states`).
///
/// `pending`: facts shown, confirm enabled. `simulationFailed` and
/// `policyRejected`: confirm disabled with the reason. `signing`: everything
/// disabled while the wallet signs and broadcasts. `complete`: the outcome
/// as reported by the owner (a toast alone never proves on-chain completion).
enum LoopSignSheetState {
  pending,
  simulationFailed,
  signing,
  policyRejected,
  complete,
}

/// One fact line shown before signing. The values shown here must be the
/// same values the owner puts into the payload to be signed.
@immutable
final class LoopSignFact {
  const LoopSignFact(this.label, this.value, {this.down = false});

  final String label;
  final String value;

  /// Renders the value with `.down` emphasis (failed / rejected).
  final bool down;
}

/// The single signing exit for Send, Swap, Launch purchase, approvals and
/// Bridge. Stake is not admitted until its contract decision exists.
class LoopSignSheet extends StatelessWidget {
  const LoopSignSheet({
    required this.state,
    required this.facts,
    super.key,
    this.title = '确认交易',
    this.reason,
    this.onConfirm,
    this.onCancel,
    this.onAdjustPolicy,
    this.confirmLabel = '确认签名',
    this.cancelLabel = '取消',
  });

  final LoopSignSheetState state;

  /// 操作 / 资产 / 网络 / 费用 / 模拟结果 …
  final List<LoopSignFact> facts;

  /// Prototype `#sign-title`. The showcase cards override the confirm label
  /// with the compact 「确认」 used by the inline examples.
  final String title;

  /// Human explanation for failed / rejected / complete states.
  final String? reason;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// Shown only for [LoopSignSheetState.policyRejected].
  final VoidCallback? onAdjustPolicy;
  final String confirmLabel;
  final String cancelLabel;

  bool get confirmEnabled =>
      state == LoopSignSheetState.pending && onConfirm != null;

  bool get cancelEnabled =>
      state != LoopSignSheetState.signing && onCancel != null;

  static Future<void> show(
    BuildContext context, {
    required LoopSignSheet sheet,
  }) {
    return showLoopSheet<void>(
      context,
      isDismissible: sheet.state != LoopSignSheetState.signing,
      builder: (context) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = switch (state) {
      LoopSignSheetState.simulationFailed => const Color(0x1CB8FF20),
      LoopSignSheetState.policyRejected => LoopColors.card2,
      _ => LoopColors.card,
    };
    final borderColor = switch (state) {
      LoopSignSheetState.simulationFailed ||
      LoopSignSheetState.policyRejected => Colors.transparent,
      _ => LoopColors.line,
    };
    final stateLabel = switch (state) {
      LoopSignSheetState.pending => '待确认',
      LoopSignSheetState.simulationFailed => '模拟失败',
      LoopSignSheetState.signing => '签名中',
      LoopSignSheetState.policyRejected => '被策略拒绝',
      LoopSignSheetState.complete => '已完成',
    };
    return Semantics(
      container: true,
      label: '$title · $stateLabel',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          key: ValueKey<String>('loop-sign-sheet-${state.name}'),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: background,
            borderRadius: LoopRadius.card,
            border: Border.all(color: borderColor),
            boxShadow: LoopDepth.liftCard,
          ),
          child: state == LoopSignSheetState.signing
              ? _SigningBody(cancelLabel: cancelLabel)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(title, style: theme.textTheme.titleLarge),
                        ),
                        LoopBadge(
                          stateLabel,
                          kind:
                              state == LoopSignSheetState.pending ||
                                  state == LoopSignSheetState.complete
                              ? LoopBadgeKind.up
                              : LoopBadgeKind.mute,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final fact in facts)
                      LoopKeyValue(
                        label: fact.label,
                        value: fact.value,
                        valueUp: fact.down ? false : null,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                      ),
                    if (reason != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        reason!,
                        style: LoopTypography.sora(
                          size: 11.5,
                          weight: FontWeight.w400,
                          height: 1.6,
                          color: LoopColors.text2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    LoopButtonPair(
                      padded: false,
                      children: <Widget>[
                        if (state == LoopSignSheetState.policyRejected &&
                            onAdjustPolicy != null)
                          LoopButton(label: '调整策略', onPressed: onAdjustPolicy),
                        LoopButton(
                          label:
                              state == LoopSignSheetState.complete ||
                                  state == LoopSignSheetState.policyRejected
                              ? '关闭'
                              : cancelLabel,
                          onPressed: cancelEnabled ? onCancel : null,
                        ),
                        if (state != LoopSignSheetState.complete)
                          LoopButton(
                            label: confirmLabel,
                            primary: true,
                            onPressed: confirmEnabled ? onConfirm : null,
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SigningBody extends StatelessWidget {
  const _SigningBody({required this.cancelLabel});

  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            LoopSkeletonBlock(width: 7, height: 7, radius: 4),
            SizedBox(width: 6),
            LoopSkeletonBlock(width: 7, height: 7, radius: 4),
            SizedBox(width: 6),
            LoopSkeletonBlock(width: 7, height: 7, radius: 4),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '正在签名并广播',
          textAlign: TextAlign.center,
          style: LoopTypography.sora(size: 13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '请勿关闭 App',
          textAlign: TextAlign.center,
          style: LoopTypography.sora(
            size: 11.5,
            weight: FontWeight.w400,
            color: LoopColors.text3,
          ),
        ),
        const SizedBox(height: 12),
        LoopButtonPair(
          padded: false,
          children: <Widget>[
            LoopButton(label: cancelLabel),
            const LoopButton(label: '签名中', primary: true),
          ],
        ),
      ],
    );
  }
}
