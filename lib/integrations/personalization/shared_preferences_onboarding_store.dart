import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadString = Future<String?> Function(String key);
typedef _WriteString = Future<void> Function(String key, String value);
typedef _Remove = Future<void> Function(String key);

/// Device-local storage for the opening sequence position only.
///
/// The key is partitioned by [LoopV2OwnerPartition], the same opaque
/// per-account value the V2 session journal uses, so one account's position
/// is never read for another and the raw Privy principal never reaches
/// SharedPreferences. The value is a step name and carries no account data,
/// no credential and no claim that anything was enrolled.
class SharedPreferencesLoopOnboardingProgressStore
    implements LoopOnboardingProgressStore {
  factory SharedPreferencesLoopOnboardingProgressStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopOnboardingProgressStore.forTesting(
      preferences.getString,
      preferences.setString,
      preferences.remove,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopOnboardingProgressStore.forTesting(
    this._readString,
    this._writeString,
    this._remove,
  );

  static const String keyPrefix = 'loop.onboarding.v1.step.';

  final _ReadString _readString;
  final _WriteString _writeString;
  final _Remove _remove;

  static String keyFor(String partitionKey) => '$keyPrefix$partitionKey';

  @override
  Future<LoopOnboardingStep?> read(String partitionKey) async {
    try {
      // A value written by an older or newer build that this one does not
      // know is read as "no position", never as step 02 by accident.
      return LoopOnboardingStep.tryParse(
        await _readString(keyFor(partitionKey)),
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String partitionKey, LoopOnboardingStep step) async {
    try {
      await _writeString(keyFor(partitionKey), step.name);
    } on Object {
      // The position is a convenience; losing it costs one restart at 02.
    }
  }

  @override
  Future<void> clear(String partitionKey) async {
    try {
      await _remove(keyFor(partitionKey));
    } on Object {
      // An active account never enters the sequence again, so a leftover
      // position cannot put anybody back into it.
    }
  }
}
