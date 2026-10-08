import 'dart:async';

import 'package:flutter/widgets.dart';

/// What the microphone control of a mounted call says and whether it can be
/// pressed, published for a control that lives outside the call view
/// (decision 0115: the room page's fixed bottom bar).
///
/// The call view still decides everything — which command a press runs, what
/// a refusal says, when the one Speak of a call is spent. The bar only draws
/// what it is handed and hands the press back.
@immutable
final class VoiceMicrophoneControl {
  const VoiceMicrophoneControl({
    required this.label,
    required this.open,
    required this.busy,
    required this.enabled,
  });

  /// `静音`, `取消静音`, `重新发言`, `仅收听` …
  final String label;

  /// The microphone is open in the call right now.
  final bool open;

  /// A command is in flight.
  final bool busy;

  /// A press would run a command.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceMicrophoneControl &&
          other.label == label &&
          other.open == open &&
          other.busy == busy &&
          other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, open, busy, enabled);
}

/// The one thread between a call view's microphone and a control drawn
/// elsewhere on the same page.
///
/// The view publishes after the frame that read the call; a view that goes
/// away withdraws what it published, so the bar never presses a control that
/// is no longer mounted.
final class VoiceMicrophoneBridge extends ChangeNotifier {
  VoiceMicrophoneControl? _control;
  VoidCallback? _press;
  Object? _owner;

  VoiceMicrophoneControl? get control => _control;

  void publish(
    Object owner,
    VoiceMicrophoneControl control,
    VoidCallback? onPressed,
  ) {
    _owner = owner;
    _press = onPressed;
    if (_control == control) return;
    _control = control;
    notifyListeners();
  }

  /// Takes the control back, but only when [owner] is the view that put it
  /// there: a replaced view cannot clear the one that took its place.
  ///
  /// A view withdraws from its `dispose`, while the tree is locked, so the
  /// bar is told a microtask later rather than asked to rebuild mid-teardown.
  void withdraw(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _press = null;
    if (_control == null) return;
    _control = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void press() {
    if (_control?.enabled ?? false) _press?.call();
  }
}

/// How the room page wants the call view drawn (decision 0115).
///
/// Without one of these above it the call view keeps the layout it always
/// had. The room page asks for no participant grid — who is on the
/// microphone is the page's own host and speaker sections — and, on the main
/// room view, for the microphone to be handed to [microphone] instead of
/// being drawn beside the output control.
class VoiceMediaPresentation extends InheritedWidget {
  const VoiceMediaPresentation({
    required super.child,
    super.key,
    this.microphone,
    this.showsParticipants = false,
  });

  /// Where the microphone control is drawn instead, or null to keep it in
  /// the call view's own control row (together with its hang-up).
  final VoiceMicrophoneBridge? microphone;

  /// Whether the call view draws its own participant tiles and head count.
  final bool showsParticipants;

  static VoiceMediaPresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceMediaPresentation>();

  @override
  bool updateShouldNotify(VoiceMediaPresentation oldWidget) =>
      !identical(microphone, oldWidget.microphone) ||
      showsParticipants != oldWidget.showsParticipants;
}
