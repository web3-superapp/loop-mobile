import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// Where one step of a signing trip is.
enum LoopSignStepStatus { waiting, active, refreshing, done, failed, unknown }

/// One step of [LoopSignStepStrip].
@immutable
final class LoopSignStep {
  const LoopSignStep({
    required this.id,
    required this.label,
    required this.status,
    required this.caption,
    this.waitingCaption = '待签名',
  });

  /// Keys the step as `<keyPrefix>-step-<id>-<status>`.
  final String id;
  final String label;
  final LoopSignStepStatus status;

  /// What the step says now, in the owner's words.
  final String caption;

  /// What a step that is next, and not yet started, says after 「下一步，」.
  final String waitingCaption;
}

/// 「1 授权 → 2 买入」 above a signing sheet: which prompt is open, which is
/// done, which comes next (decisions 0145, 0149). Decision 0152 adds an
/// optional leading 「验证身份」 step for the large-amount step-up; the strip
/// itself only draws what it is given.
class LoopSignStepStrip extends StatelessWidget {
  const LoopSignStepStrip({
    required this.steps,
    super.key,
    this.keyPrefix = 'loop-sign',
  });

  final List<LoopSignStep> steps;
  final String keyPrefix;

  /// The first step not started whose every predecessor is done is next.
  int? get _nextIndex {
    for (var index = 0; index < steps.length; index += 1) {
      final status = steps[index].status;
      if (status == LoopSignStepStatus.done) continue;
      return status == LoopSignStepStatus.waiting ? index : null;
    }
    return null;
  }

  Widget _step(int index, LoopSignStep step, {required bool next}) {
    final status = step.status;
    final later = status == LoopSignStepStatus.waiting && !next;
    final lit =
        status == LoopSignStepStatus.active ||
        status == LoopSignStepStatus.refreshing ||
        status == LoopSignStepStatus.done;
    final warn =
        status == LoopSignStepStatus.failed ||
        status == LoopSignStepStatus.unknown;
    final number = '${index + 1}';
    return Expanded(
      child: KeyedSubtree(
        key: ValueKey<String>('$keyPrefix-step-${step.id}-${status.name}'),
        child: Semantics(
          label: '第 $number 步 ${step.label}，${step.caption}',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit
                        ? LoopColors.lime
                        : next
                        ? LoopColors.card2
                        : LoopColors.card,
                    border: Border.all(
                      color: warn
                          ? LoopColors.warning
                          : next
                          ? LoopColors.chalk
                          : LoopColors.line,
                      width: next ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    number,
                    style: LoopTypography.label(
                      12,
                      weight: FontWeight.w700,
                      color: lit
                          ? LoopColors.ink
                          : next
                          ? LoopColors.chalk
                          : LoopColors.text2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.label,
                        style: LoopTypography.title(
                          14,
                          color: later ? LoopColors.text2 : LoopColors.chalk,
                        ),
                      ),
                      Text(
                        // Decision 0149: the caption agrees with the ring.
                        next && status == LoopSignStepStatus.waiting
                            ? '下一步，${step.waitingCaption}'
                            : step.caption,
                        style: LoopType.caption.copyWith(
                          color: warn
                              ? LoopColors.warning
                              : later
                              ? LoopColors.text3
                              : LoopColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextIndex;
    return Padding(
      key: ValueKey<String>('$keyPrefix-steps'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < steps.length; index += 1) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            _step(index, steps[index], next: index == next),
          ],
        ],
      ),
    );
  }
}
