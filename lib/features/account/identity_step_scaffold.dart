import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// UX-002 (decision 0254): a sign-in step page.
///
/// The step bar is the first thing on the page — equal segments across the
/// top, the back control under it on the left and `1/5` on the right — then
/// the big title, one line under it, the step's own content and the one
/// action that moves on, directly under the content. The bar no longer sits
/// between the title and the content, where it split the page in two.
class IdentityStepScaffold extends StatelessWidget {
  const IdentityStepScaffold({
    required this.title,
    required this.body,
    super.key,
    this.step,
    this.total,
    this.progressLabel,
    this.onBack,
    this.subtitle,
    this.primaryAction,
  });

  final String title;

  /// The step's own content, under the title.
  final List<Widget> body;

  /// Where this page is in the opening; both `null` on a page that is not
  /// one of its numbered steps (the e-mail entry is the way in, not a step).
  final int? step;
  final int? total;

  /// The step's name, for the spoken label of the bar.
  final String? progressLabel;

  final VoidCallback? onBack;

  /// One line under the title. A widget, so it can carry a text link.
  final Widget? subtitle;

  /// The one action that moves on, directly under [body].
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final current = step;
    final count = total;
    final back = onBack;
    final line = subtitle;
    final action = primaryAction;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: loopChildPageBottomInset(context) + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (current != null && count != null)
                IdentityStepBar(
                  step: current,
                  total: count,
                  label: progressLabel ?? title,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LoopSpacing.page - 6,
                  6,
                  LoopSpacing.page,
                  0,
                ),
                child: SizedBox(
                  height: LoopTouch.minimum,
                  child: Row(
                    children: <Widget>[
                      if (back != null)
                        LoopIconButton(
                          key: const ValueKey<String>('loop-topbar-back'),
                          icon: 'back',
                          label: '返回',
                          onPressed: back,
                        ),
                      const Spacer(),
                      if (current != null && count != null)
                        ExcludeSemantics(
                          child: Text(
                            '$current/$count',
                            key: const ValueKey<String>('identity-step-count'),
                            style: LoopType.figureSm.copyWith(
                              color: LoopColors.text2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  14,
                  LoopSpacing.page,
                  0,
                ),
                child: Semantics(
                  header: true,
                  child: Text(title, style: LoopType.stepTitle),
                ),
              ),
              if (line != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LoopSpacing.page,
                    8,
                    LoopSpacing.page,
                    0,
                  ),
                  child: line,
                ),
              const SizedBox(height: 24),
              ...body,
              if (action != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LoopSpacing.page,
                    24,
                    LoopSpacing.page,
                    0,
                  ),
                  child: action,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The step bar: [total] equal segments, the first [step] of them Yellow.
class IdentityStepBar extends StatelessWidget {
  const IdentityStepBar({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '流程第 $step 步，共 $total 步：$label',
      child: ExcludeSemantics(
        child: Padding(
          key: const ValueKey<String>('identity-step-bar'),
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            10,
            LoopSpacing.page,
            0,
          ),
          child: Row(
            children: <Widget>[
              for (var index = 0; index < total; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index < step
                          ? LoopColors.yellow
                          : LoopColors.line2,
                      borderRadius: LoopRadius.pill,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
