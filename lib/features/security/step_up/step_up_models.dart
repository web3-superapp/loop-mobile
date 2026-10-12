import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

// ---------------------------------------------------------------------------
// Large-amount step-up (decision 0152)
// ---------------------------------------------------------------------------
//
// A signature whose USD1 value reaches the owner's threshold is preceded by
// the device's own authentication — the same face, fingerprint or screen-lock
// passcode the application lock asks for. It is entirely on the device: no
// request, no header and no response changes, and the server never learns
// that it ran. The rule lives at the signing exit, so every money action
// passes through it; what each feature contributes is only the USD1 value of
// its own intent.

/// The default threshold, in whole USD1.
const int loopStepUpDefaultThresholdUsd1 = 1000;

/// The smallest threshold an owner may set, in whole USD1.
const int loopStepUpMinThresholdUsd1 = 1;

/// The largest threshold an owner may set, in whole USD1.
const int loopStepUpMaxThresholdUsd1 = 1000000;

/// The presets the threshold sheet offers.
const List<int> loopStepUpThresholdPresets = <int>[500, 1000, 5000];

/// How long one passed verification covers the rest of the same operation.
///
/// An operation may open the wallet more than once — an approval and then the
/// trade, or a trade re-quoted after its approval (decision 0148). One prompt
/// covers all of it, and nothing larger than what was verified. The cover is
/// also released when the signing sheet closes, so it never outlives the
/// confirmation that asked for it.
const Duration loopStepUpGrantWindow = Duration(minutes: 2);

/// The refusal a wallet handoff returns when the owner cancelled the step-up.
const String loopStepUpCancelledCode = 'step_up_cancelled';

/// The refusal a wallet handoff returns when the device did not pass the
/// owner (a wrong face, too many attempts, a platform error).
const String loopStepUpFailedCode = 'step_up_failed';

/// Whether [reasonCode] is one of the two step-up refusals. Both mean that
/// nothing was signed and nothing was submitted.
bool loopStepUpStopped(String? reasonCode) =>
    reasonCode == loopStepUpCancelledCode || reasonCode == loopStepUpFailedCode;

/// The failure kind a caller receives for a step-up refusal, or `null` when
/// [reasonCode] is not one.
LoopChainFailureKind? loopStepUpFailureKind(String? reasonCode) =>
    loopStepUpStopped(reasonCode) ? LoopChainFailureKind.stepUpCancelled : null;

/// The one sentence a signing sheet shows after a step-up refusal, or `null`
/// when [reasonCode] is not one.
String? loopStepUpReasonText(String? reasonCode) => switch (reasonCode) {
  loopStepUpCancelledCode => '已取消，没有发生任何变化。',
  loopStepUpFailedCode => '身份验证没有通过，没有发生任何变化。',
  _ => null,
};

/// One USD1 amount in whole and fractional units, from an 18-decimal integer.
Decimal loopStepUpUsd1FromAtomic(BigInt atomic, {int decimals = 18}) =>
    Decimal.fromBigInt(atomic).shift(-decimals);

/// One USD1 amount from an exact decimal string, or `null` when it is not one.
Decimal? loopStepUpUsd1FromDecimalString(String? value) {
  if (value == null) return null;
  final parsed = Decimal.tryParse(value.trim());
  if (parsed == null || parsed < Decimal.zero) return null;
  return parsed;
}

/// The owner's two choices: whether the step-up runs, and from which amount.
@immutable
final class LoopStepUpSettings {
  const LoopStepUpSettings({
    this.enabled = true,
    this.thresholdUsd1 = loopStepUpDefaultThresholdUsd1,
  });

  /// On unless the owner turned it off (decision 0152: default on).
  final bool enabled;

  /// Whole USD1, within [loopStepUpMinThresholdUsd1] and
  /// [loopStepUpMaxThresholdUsd1].
  final int thresholdUsd1;

  LoopStepUpSettings copyWith({bool? enabled, int? thresholdUsd1}) =>
      LoopStepUpSettings(
        enabled: enabled ?? this.enabled,
        thresholdUsd1: thresholdUsd1 ?? this.thresholdUsd1,
      );

  /// The stored form: `1:1000` or `0:1000`.
  String encode() => '${enabled ? 1 : 0}:$thresholdUsd1';

  /// Reads [encode]'s form. Anything else — another build's value, a
  /// threshold out of range — is "nothing stored", which is the default:
  /// on, at 1000.
  static LoopStepUpSettings? tryDecode(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^([01]):([0-9]{1,7})$').firstMatch(value);
    if (match == null) return null;
    final threshold = int.parse(match.group(2)!);
    if (loopStepUpThresholdError(threshold) != null) return null;
    return LoopStepUpSettings(
      enabled: match.group(1) == '1',
      thresholdUsd1: threshold,
    );
  }

  /// Whether [usd1] reaches this threshold. Exact: `Decimal` compares the
  /// value the intent carried against the whole-USD1 threshold, never a
  /// double. Equal is reached.
  bool reaches(Decimal? usd1) =>
      usd1 != null && usd1 >= Decimal.fromInt(thresholdUsd1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopStepUpSettings &&
          other.enabled == enabled &&
          other.thresholdUsd1 == thresholdUsd1;

  @override
  int get hashCode => Object.hash(enabled, thresholdUsd1);
}

/// Why [threshold] cannot be saved, or `null` when it can.
String? loopStepUpThresholdError(int? threshold) {
  if (threshold == null) return '请输入整数金额';
  if (threshold < loopStepUpMinThresholdUsd1 ||
      threshold > loopStepUpMaxThresholdUsd1) {
    return '金额需在 1 到 1,000,000 USD1 之间';
  }
  return null;
}

/// Reads what the owner typed. Only digits, optionally grouped with commas,
/// are a whole USD1 amount; a decimal point, a sign or anything else is not.
int? loopStepUpParseThreshold(String input) {
  final text = input.trim().replaceAll(',', '');
  if (text.isEmpty || !RegExp(r'^[0-9]{1,8}$').hasMatch(text)) return null;
  return int.parse(text);
}

/// `1000` → `1,000`.
String loopStepUpThresholdLabel(int threshold) {
  final digits = threshold.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// The row's subtitle.
String loopStepUpSubtitle(int threshold) =>
    '达到 ${loopStepUpThresholdLabel(threshold)} USD1 时再验一次身份';

/// What one signing sheet will ask before the wallet opens.
@immutable
final class LoopStepUpPlan {
  const LoopStepUpPlan({required this.required, required this.thresholdUsd1});

  const LoopStepUpPlan.none()
    : required = false,
      thresholdUsd1 = loopStepUpDefaultThresholdUsd1;

  /// The device will be asked before the wallet opens.
  final bool required;
  final int thresholdUsd1;
}

/// How one step-up ended.
enum LoopStepUpVerdict {
  /// The amount is below the threshold, unknown, or the rule is off (or the
  /// device has nothing to ask with). The wallet opens as it always did.
  notRequired,

  /// The device passed the owner, now or within the same operation.
  passed,

  /// The owner said "not now". Nothing was signed.
  cancelled,

  /// The device did not pass the owner. Nothing was signed.
  failed;

  bool get allowsSigning => this == notRequired || this == passed;

  /// The wallet refusal for a stopped step-up, or `null`.
  String? get refusalCode => switch (this) {
    LoopStepUpVerdict.cancelled => loopStepUpCancelledCode,
    LoopStepUpVerdict.failed => loopStepUpFailedCode,
    _ => null,
  };
}

/// Where the owner's choice is kept, per account.
///
/// [principalKey] is the session's opaque account key; the implementation
/// derives its own partition from it so one account's choice is never read
/// for another and the raw principal never reaches storage.
abstract interface class LoopStepUpSettingsStore {
  Future<LoopStepUpSettings?> read(String principalKey);

  Future<void> write(String principalKey, LoopStepUpSettings settings);
}

/// The default: nothing is remembered, every start is the default.
final class UnavailableLoopStepUpSettingsStore
    implements LoopStepUpSettingsStore {
  const UnavailableLoopStepUpSettingsStore();

  @override
  Future<LoopStepUpSettings?> read(String principalKey) async => null;

  @override
  Future<void> write(String principalKey, LoopStepUpSettings settings) async =>
      throw UnsupportedError('step_up_store_unavailable');
}

final class InMemoryLoopStepUpSettingsStore implements LoopStepUpSettingsStore {
  InMemoryLoopStepUpSettingsStore([Map<String, LoopStepUpSettings>? initial])
    : values = <String, LoopStepUpSettings>{...?initial};

  final Map<String, LoopStepUpSettings> values;

  @override
  Future<LoopStepUpSettings?> read(String principalKey) async =>
      values[principalKey];

  @override
  Future<void> write(String principalKey, LoopStepUpSettings settings) async =>
      values[principalKey] = settings;
}

final loopStepUpSettingsStoreProvider = Provider<LoopStepUpSettingsStore>(
  (ref) => const UnavailableLoopStepUpSettingsStore(),
);
