import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Installation-independent display preferences for the current app run.
///
/// This state deliberately makes no persistence claim. A future durable store
/// needs a separate platform-storage decision and migration contract.
@immutable
class LoopDisplayPreferences {
  const LoopDisplayPreferences({this.reduceMotion = false});

  final bool reduceMotion;

  LoopDisplayPreferences copyWith({bool? reduceMotion}) {
    return LoopDisplayPreferences(
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

class LoopDisplayPreferencesController
    extends Notifier<LoopDisplayPreferences> {
  @override
  LoopDisplayPreferences build() => const LoopDisplayPreferences();

  void setReduceMotion(bool value) {
    if (state.reduceMotion == value) return;
    state = state.copyWith(reduceMotion: value);
  }
}

final loopDisplayPreferencesProvider =
    NotifierProvider<LoopDisplayPreferencesController, LoopDisplayPreferences>(
      LoopDisplayPreferencesController.new,
    );
