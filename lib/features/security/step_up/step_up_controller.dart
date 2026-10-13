import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

@immutable
final class LoopStepUpState {
  const LoopStepUpState({
    this.principalKey,
    this.settings = const LoopStepUpSettings(),
    this.loaded = false,
    this.persisted = true,
    this.capability,
    this.busy = false,
    this.lastOutcome,
    this.systemMessage,
  });

  /// The account these choices belong to, or `null` without a session.
  final String? principalKey;
  final LoopStepUpSettings settings;

  /// The stored choice and the device capability have been read once.
  final bool loaded;

  /// The last change reached the device's storage. `false` means it holds
  /// for this run only.
  final bool persisted;

  /// What this device will authenticate with, or `null` while unread.
  final LoopDeviceAuthCapability? capability;

  /// A system prompt is up.
  final bool busy;

  /// How the last prompt ended, if one ran.
  final LoopDeviceAuthOutcome? lastOutcome;
  final String? systemMessage;

  /// The device has something to ask with.
  bool get isAvailable => capability?.isAvailable ?? false;

  /// The rule runs: the owner left it on and the device can ask. A device
  /// with no screen lock cannot be asked, so the switch cannot be on.
  bool get isActive => settings.enabled && isAvailable;

  LoopStepUpState copyWith({
    String? principalKey,
    LoopStepUpSettings? settings,
    bool? loaded,
    bool? persisted,
    LoopDeviceAuthCapability? capability,
    bool? busy,
    LoopDeviceAuthOutcome? lastOutcome,
    String? systemMessage,
    bool clearOutcome = false,
  }) => LoopStepUpState(
    principalKey: principalKey ?? this.principalKey,
    settings: settings ?? this.settings,
    loaded: loaded ?? this.loaded,
    persisted: persisted ?? this.persisted,
    capability: capability ?? this.capability,
    busy: busy ?? this.busy,
    lastOutcome: clearOutcome ? null : (lastOutcome ?? this.lastOutcome),
    systemMessage: clearOutcome ? null : (systemMessage ?? this.systemMessage),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopStepUpState &&
          other.principalKey == principalKey &&
          other.settings == settings &&
          other.loaded == loaded &&
          other.persisted == persisted &&
          other.capability == capability &&
          other.busy == busy &&
          other.lastOutcome == lastOutcome &&
          other.systemMessage == systemMessage;

  @override
  int get hashCode => Object.hash(
    principalKey,
    settings,
    loaded,
    persisted,
    capability,
    busy,
    lastOutcome,
    systemMessage,
  );
}

/// What a signing exit asks before the wallet opens.
abstract interface class LoopStepUpGuard {
  /// Whether [usd1] will be asked for, read fresh (settings and capability).
  Future<LoopStepUpPlan> plan(Decimal? usd1);

  /// Asks the device when [usd1] reaches the threshold. A verification that
  /// passed for at least [usd1] within [loopStepUpGrantWindow] is reused,
  /// so one operation that opens the wallet twice is asked once.
  Future<LoopStepUpVerdict> verify(Decimal? usd1);

  /// Ends the operation: the next signature is asked for again.
  void release();
}

@immutable
final class _LoopStepUpGrant {
  const _LoopStepUpGrant({required this.coveredUsd1, required this.until});

  final Decimal coveredUsd1;
  final DateTime until;
}

/// The owner's large-amount rule and the one prompt it runs.
///
/// The settings are per account and per device. The prompt is the device's
/// own authentication — the same one the application lock uses — and LOOP
/// stores nothing it could compare against.
final class LoopStepUpController extends Notifier<LoopStepUpState>
    implements LoopStepUpGuard {
  Future<void>? _loading;
  Future<bool>? _prompt;
  _LoopStepUpGrant? _grant;

  @override
  LoopStepUpState build() {
    final principal = ref.watch(loopAccountScopeProvider);
    _loading = null;
    _grant = null;
    return LoopStepUpState(principalKey: principal);
  }

  /// Reads the stored choice and the device capability. Single-flight.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final principal = state.principalKey;
    LoopStepUpSettings? stored;
    if (principal != null) {
      try {
        stored = await ref
            .read(loopStepUpSettingsStoreProvider)
            .read(principal);
      } on Object {
        stored = null;
      }
    }
    final capability = await _readCapability();
    if (!ref.mounted || state.principalKey != principal) return;
    state = state.copyWith(
      settings: stored ?? const LoopStepUpSettings(),
      capability: capability,
      loaded: true,
    );
  }

  /// Re-reads what the device will authenticate with.
  Future<void> refreshCapability() async {
    final capability = await _readCapability();
    if (!ref.mounted) return;
    state = state.copyWith(capability: capability);
  }

  /// Turns the rule on or off, after the device proves the owner is here.
  ///
  /// On: the same prompt a large signature will show is shown now, so a rule
  /// that cannot be passed is never switched on. Off: a rule anybody holding
  /// the phone could switch off would not protect anything.
  Future<bool> setEnabled(bool enabled) async {
    await load();
    if (state.busy) return false;
    if (state.settings.enabled == enabled && (!enabled || state.isAvailable)) {
      return true;
    }
    if (!state.isAvailable) return false;
    final passed = await _ask(enabled ? '验证身份以开启大额交易二次验证' : '验证身份以关闭大额交易二次验证');
    if (!passed) return false;
    await _save(state.settings.copyWith(enabled: enabled));
    return true;
  }

  /// Saves a new threshold. Raising it lets more through unasked, so it is
  /// asked for first while the rule is on; lowering it is saved as is.
  Future<bool> setThreshold(int threshold) async {
    if (loopStepUpThresholdError(threshold) != null) return false;
    await load();
    if (state.busy) return false;
    final current = state.settings;
    if (current.thresholdUsd1 == threshold) return true;
    if (state.isActive && threshold > current.thresholdUsd1) {
      final passed = await _ask('验证身份以提高大额交易的验证金额');
      if (!passed) return false;
    }
    await _save(state.settings.copyWith(thresholdUsd1: threshold));
    return true;
  }

  Future<void> _save(LoopStepUpSettings settings) async {
    final principal = state.principalKey;
    var persisted = principal != null;
    if (principal != null) {
      try {
        await ref
            .read(loopStepUpSettingsStoreProvider)
            .write(principal, settings);
      } on Object {
        persisted = false;
      }
    }
    if (!ref.mounted) return;
    _grant = null;
    state = state.copyWith(settings: settings, persisted: persisted);
  }

  @override
  Future<LoopStepUpPlan> plan(Decimal? usd1) async {
    await load();
    await refreshCapability();
    if (!ref.mounted) return const LoopStepUpPlan.none();
    final settings = state.settings;
    return LoopStepUpPlan(
      required:
          (state.isActive || _capabilityUnknown) && settings.reaches(usd1),
      thresholdUsd1: settings.thresholdUsd1,
    );
  }

  /// The rule is on but the device's capability could not be read (decision
  /// 0158). That is "not known", never "nothing to ask with": an amount that
  /// reaches the threshold fails closed instead of opening the wallet unasked.
  bool get _capabilityUnknown =>
      state.settings.enabled &&
      state.capability?.unavailableReason ==
          LoopDeviceAuthUnavailableReason.unknown;

  @override
  Future<LoopStepUpVerdict> verify(Decimal? usd1) async {
    final plan = await this.plan(usd1);
    if (!plan.required || usd1 == null) return LoopStepUpVerdict.notRequired;
    if (_capabilityUnknown) return LoopStepUpVerdict.failed;
    final now = ref.read(loopAppLockClockProvider)();
    final grant = _grant;
    if (grant != null &&
        now.isBefore(grant.until) &&
        usd1 <= grant.coveredUsd1) {
      return LoopStepUpVerdict.passed;
    }
    final passed = await _ask('验证身份以签名这笔大额交易');
    if (!ref.mounted) return LoopStepUpVerdict.failed;
    if (passed) {
      _grant = _LoopStepUpGrant(
        coveredUsd1: usd1,
        until: ref.read(loopAppLockClockProvider)().add(loopStepUpGrantWindow),
      );
      return LoopStepUpVerdict.passed;
    }
    return state.lastOutcome == LoopDeviceAuthOutcome.canceled
        ? LoopStepUpVerdict.cancelled
        : LoopStepUpVerdict.failed;
  }

  @override
  void release() => _grant = null;

  /// One system prompt. Single-flight: a second caller waits for the first
  /// and reads its answer instead of stacking prompts.
  Future<bool> _ask(String reason) {
    final running = _prompt;
    if (running != null) return running;
    final prompt = _run(reason).whenComplete(() => _prompt = null);
    _prompt = prompt;
    return prompt;
  }

  Future<bool> _run(String reason) async {
    state = state.copyWith(busy: true, clearOutcome: true);
    LoopDeviceAuthResult result;
    try {
      result = await ref
          .read(loopDeviceAuthenticatorProvider)
          .authenticate(reason: reason);
    } on Object catch (error) {
      result = LoopDeviceAuthResult(
        LoopDeviceAuthOutcome.error,
        systemMessage: error.toString(),
      );
    }
    if (!ref.mounted) return false;
    state = state.copyWith(
      busy: false,
      lastOutcome: result.outcome,
      systemMessage: result.systemMessage,
      capability: result.outcome == LoopDeviceAuthOutcome.unavailable
          ? const LoopDeviceAuthCapability.unavailable(
              LoopDeviceAuthUnavailableReason.noCredentialSet,
            )
          : null,
    );
    return result.succeeded;
  }

  Future<LoopDeviceAuthCapability> _readCapability() async {
    try {
      return await ref.read(loopDeviceAuthenticatorProvider).readCapability();
    } on Object {
      return const LoopDeviceAuthCapability.unavailable(
        LoopDeviceAuthUnavailableReason.unknown,
      );
    }
  }
}

final loopStepUpProvider =
    NotifierProvider<LoopStepUpController, LoopStepUpState>(
      LoopStepUpController.new,
    );

/// The signing exit with the large-amount step-up in front of it.
///
/// Every money action reaches the wallet through here. An intent that the
/// exit would refuse anyway is passed straight on, so the owner is never
/// asked to verify for something that cannot be signed. An intent whose
/// [SigningIntent.stepUpUsd1] reaches the threshold is signed only after
/// the device passed the owner; a cancelled or failed prompt returns
/// [loopStepUpCancelledCode] / [loopStepUpFailedCode] and the wallet is never
/// opened.
final class LoopStepUpWalletSigningGateway implements WalletSigningGateway {
  const LoopStepUpWalletSigningGateway({
    required this.inner,
    required this.guard,
  });

  final WalletSigningGateway inner;
  final LoopStepUpGuard guard;

  @override
  WalletGatewayAvailability get availability => inner.availability;

  @override
  String get label => inner.label;

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    if (walletHandoffRefusal(intent, now: now) != null) {
      return inner.handoff(intent, now: now);
    }
    final LoopStepUpVerdict verdict;
    try {
      verdict = await guard.verify(intent.stepUpUsd1);
    } on Object {
      return const WalletHandoffResult.rejected(loopStepUpFailedCode);
    }
    final refusal = verdict.refusalCode;
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return inner.handoff(intent, now: now);
  }
}

/// The step-up in front of [wallet], or `null` when this exit has none (a
/// test double, or a composition that installed no rule).
LoopStepUpGuard? loopStepUpGuardOf(WalletSigningGateway wallet) =>
    wallet is LoopStepUpWalletSigningGateway ? wallet.guard : null;

/// The signing exit every feature signer uses: [walletSigningGatewayProvider]
/// behind the large-amount step-up.
final loopGuardedWalletSigningGatewayProvider = Provider<WalletSigningGateway>(
  (ref) => LoopStepUpWalletSigningGateway(
    inner: ref.watch(walletSigningGatewayProvider),
    guard: ref.watch(loopStepUpProvider.notifier),
  ),
);
