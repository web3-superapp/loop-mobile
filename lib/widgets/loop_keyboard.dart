import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'package:loop_mobile/widgets/loop_pages.dart';

/// Decision 0234 · every input's keyboard can be put away.
///
/// Three paths, all installed once for the whole App (the `MaterialApp`
/// builder in `app.dart`, which sits above the root navigator, so pages,
/// bottom sheets and dialogs are all inside it):
///
/// 1. **Tap outside.** A pointer down anywhere that is not inside the focused
///    field's own tap region (the field, its decoration's prefix / suffix such
///    as a MAX key, its selection toolbar, and anything wrapped in
///    [LoopKeepsKeyboard]) clears the focus. Flutter's own default on touch
///    devices is to keep it; this scope overrides that one intent
///    ([EditableTextTapOutsideIntent]) and nothing else, so the tap itself
///    still reaches whatever was under the finger.
/// 2. **Drag.** `LoopScrollBehavior.getKeyboardDismissBehavior` answers
///    `onDrag`, so every [ScrollView] and [SingleChildScrollView] that does
///    not choose for itself puts the keyboard away when the reader drags it.
///    Stream's message list passes its own value and keeps it.
/// 3. **完成.** On iOS a number or phone pad has no return key; while one is
///    up, a [LoopKeyboardDoneBar] sits on the keyboard's top edge. The
///    insets below this scope grow by the bar's height, so a resizing
///    Scaffold, a sheet padded by the insets, and the field's own
///    show-on-screen all keep their content above the bar.
///
/// A [LoopFocusPage] with `keyboardAccessory: true` draws its own bar
/// (decision 0091); this scope steps aside for a field inside one.
class LoopKeyboardScope extends StatefulWidget {
  const LoopKeyboardScope({required this.child, super.key});

  final Widget child;

  @override
  State<LoopKeyboardScope> createState() => _LoopKeyboardScopeState();
}

class _LoopKeyboardScopeState extends State<LoopKeyboardScope> {
  /// Whether the focused field wants the 完成 bar, read after a frame.
  bool _numberPad = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleCheck);
    super.dispose();
  }

  /// The focused node's element can be mid-rebuild (or about to be
  /// unmounted) when the focus moves, and looking up its ancestors then is
  /// unsafe; the tree is stable once the frame has finished.
  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _checkScheduled = false;
        if (!mounted) return;
        final next = _wantsBar();
        if (next != _numberPad) setState(() => _numberPad = next);
      })
      ..scheduleFrame();
  }

  static bool _wantsBar() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null || !context.mounted) return false;
    final field = context.findAncestorWidgetOfExactType<EditableText>();
    if (field == null || field.readOnly) return false;
    if (!loopKeyboardLacksReturnKey(field.keyboardType)) return false;
    final page = context.findAncestorWidgetOfExactType<LoopFocusPage>();
    return page == null || !page.keyboardAccessory;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bar = keyboard > 0 && _numberPad;
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent: _LoopTapOutsideAction(),
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MediaQuery(
            data: bar
                ? media.copyWith(
                    viewInsets: media.viewInsets.copyWith(
                      bottom: keyboard + LoopKeyboardDoneBar.height,
                    ),
                  )
                : media,
            child: widget.child,
          ),
          if (bar)
            Positioned(
              key: const ValueKey<String>('loop-keyboard-scope-bar'),
              left: 0,
              right: 0,
              bottom: keyboard,
              child: const LoopKeepsKeyboard(
                child: Material(
                  type: MaterialType.transparency,
                  child: LoopKeyboardDoneBar(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Whether [type] opens a keyboard with no return key on iOS: the number pad,
/// the decimal pad and the phone pad.
bool loopKeyboardLacksReturnKey(TextInputType type) =>
    type.index == TextInputType.number.index ||
    type.index == TextInputType.phone.index;

/// The tap-outside rule for every field: the focus goes, on every pointer.
class _LoopTapOutsideAction
    extends ContextAction<EditableTextTapOutsideIntent> {
  @override
  void invoke(EditableTextTapOutsideIntent intent, [BuildContext? context]) {
    intent.focusNode.unfocus();
  }
}

/// Marks a control that belongs with the field being typed into, so tapping
/// it does not put the keyboard away: a composer's send key, a trade panel's
/// MAX or side switch, a field's preset chips, the 完成 bar itself.
///
/// It joins the text fields' shared tap region ([TextFieldTapRegion]); it
/// does not take the tap, which still reaches [child].
class LoopKeepsKeyboard extends StatelessWidget {
  const LoopKeepsKeyboard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(child: child);
}
