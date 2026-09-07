import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// `.sheet` + `.veil` (chapter 5.5): bottom sheet with top-only 26px radius,
/// Line2 top edge, Ink ground with a faint Lime glow, veil rgba(5,6,4,.76),
/// max height minus both safe areas. The barrier is a real ModalBarrier
/// (background is inert) and focus returns to the opener when it closes.
Future<T?> showLoopSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String barrierLabel = '关闭弹层',
  bool isDismissible = true,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final result = await showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    barrierColor: LoopColors.veil,
    barrierLabel: barrierLabel,
    backgroundColor: Colors.transparent,
    elevation: 0,
    transitionAnimationController: reduceMotion
        ? AnimationController(
            vsync: Navigator.of(context),
            duration: Duration.zero,
          )
        : null,
    builder: (context) => LoopSheet(child: builder(context)),
  );
  // Focus restoration: the opener regains focus after the sheet closes.
  if (previousFocus != null && previousFocus.context?.mounted == true) {
    previousFocus.requestFocus();
  }
  return result;
}

/// The sheet surface itself (also usable inline for showcase pages).
class LoopSheet extends StatelessWidget {
  const LoopSheet({required this.child, super.key, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: title != null,
      label: title,
      explicitChildNodes: true,
      child: FocusScope(
        autofocus: true,
        child: Container(
          key: const ValueKey<String>('loop-sheet'),
          decoration: const BoxDecoration(
            color: LoopColors.ink,
            gradient: RadialGradient(
              center: Alignment(0, -1),
              radius: 1.1,
              colors: <Color>[Color(0x0DB8FF20), Color(0x00B8FF20)],
              stops: <double>[0, 0.64],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: LoopColors.line2)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0xD1050604),
                offset: Offset(0, -20),
                blurRadius: 60,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(title!, style: theme.textTheme.headlineMedium),
                ),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}
