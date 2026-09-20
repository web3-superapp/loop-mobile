import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:loop_mobile/app/session/wallet_provisioning_controller.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';

/// What the 02 page is allowed to say about the embedded wallet.
enum LoopWalletCreationPhase {
  /// Nothing can be observed: there is no wallet directory to read and Privy
  /// has reported nothing. The page claims no progress at all.
  unavailable,

  /// A wallet is being made, or is being looked for, right now.
  working,

  /// A wallet was observed for this account — by Privy on this device, by the
  /// server's wallet directory, or both.
  observed,

  /// The look-up ran out of time without seeing a wallet. Nothing failed and
  /// nothing is claimed; the owner may carry on.
  timedOut,
}

/// The single wallet fact set the 02 page renders.
///
/// Every flag is an observation. None of them is inferred from the page being
/// open, from a capability, or from how long the owner has waited.
@immutable
final class LoopWalletCreationFacts {
  const LoopWalletCreationFacts({
    required this.phase,
    this.recoveryEnrolled = false,
    this.loopIdActivated = false,
    this.canContinue = true,
    this.providerMessage,
  });

  /// The catalog default outside the opening sequence: no wallet capability
  /// was confirmed, so the page may neither show progress nor move on.
  const LoopWalletCreationFacts.capabilityUnconfirmed()
    : phase = LoopWalletCreationPhase.unavailable,
      recoveryEnrolled = false,
      loopIdActivated = false,
      canContinue = false,
      providerMessage = null;

  final LoopWalletCreationPhase phase;

  /// Step 03 recorded a recovery method the owner actually chose. Skipping,
  /// and a step 03 where nothing was available, both leave it false.
  final bool recoveryEnrolled;

  /// The server reports the profile as active, which is what binds the LOOP
  /// ID. Inside the sequence that is only true after step 05.
  final bool loopIdActivated;

  /// Whether the step's own action may run. Inside the sequence it stays true
  /// even while the wallet is unseen: login has already succeeded and a
  /// wallet that has not appeared yet may not hold the owner here.
  final bool canContinue;

  /// The provider's own sentence for a failed creation attempt, or `null`.
  final String? providerMessage;

  bool get walletObserved => phase == LoopWalletCreationPhase.observed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopWalletCreationFacts &&
          other.phase == phase &&
          other.recoveryEnrolled == recoveryEnrolled &&
          other.loopIdActivated == loopIdActivated &&
          other.canContinue == canContinue &&
          other.providerMessage == providerMessage;

  @override
  int get hashCode => Object.hash(
    phase,
    recoveryEnrolled,
    loopIdActivated,
    canContinue,
    providerMessage,
  );
}

/// What the wallet-directory watch has seen this run.
@immutable
final class LoopEmbeddedWalletWatch {
  const LoopEmbeddedWalletWatch({
    required this.running,
    required this.observed,
    required this.timedOut,
    this.attempts = 0,
    this.unavailable = false,
  });

  const LoopEmbeddedWalletWatch.idle()
    : running = false,
      observed = false,
      timedOut = false,
      attempts = 0,
      unavailable = false;

  final bool running;

  /// The directory answered and it contained an embedded wallet.
  final bool observed;

  /// Every attempt was spent without the directory reporting one.
  final bool timedOut;

  /// How many reads have been answered or refused so far. Reported so a test
  /// and a log can see the poll actually ran; no page prints it.
  final int attempts;

  /// There is no wallet directory to read at all.
  final bool unavailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopEmbeddedWalletWatch &&
          other.running == running &&
          other.observed == observed &&
          other.timedOut == timedOut &&
          other.attempts == attempts &&
          other.unavailable == unavailable;

  @override
  int get hashCode =>
      Object.hash(running, observed, timedOut, attempts, unavailable);
}

/// Polls the wallet directory until this account's embedded wallet appears.
///
/// Privy creates the wallet on the device and the server learns about it
/// separately; on a real first login that gap has been observed at about 90
/// seconds. So the page asks the directory again every [pollInterval] for at
/// most [maximumAttempts] reads, and says what it saw — never what it hopes.
/// Running out of attempts is not a failure and never blocks the sequence.
final class LoopEmbeddedWalletWatchController
    extends Notifier<LoopEmbeddedWalletWatch> {
  static const Duration pollInterval = Duration(seconds: 2);

  /// 30 × 2s = the 60 seconds the step is allowed to wait.
  static const int maximumAttempts = 30;

  Future<void>? _watch;

  @override
  LoopEmbeddedWalletWatch build() => const LoopEmbeddedWalletWatch.idle();

  /// Starts the watch once. A second call joins the running one, and a watch
  /// that already saw a wallet is never restarted.
  Future<void> start() {
    if (state.observed) return Future<void>.value();
    final active = _watch;
    if (active != null) return active;
    late final Future<void> watch;
    watch = _run().whenComplete(() {
      if (identical(_watch, watch)) _watch = null;
    });
    _watch = watch;
    return watch;
  }

  Future<void> _run() async {
    final gateway = ref.read(walletReadGatewayProvider);
    if (gateway.mode == LoopChainGatewayMode.unavailable) {
      state = const LoopEmbeddedWalletWatch(
        running: false,
        observed: false,
        timedOut: false,
        unavailable: true,
      );
      return;
    }
    state = const LoopEmbeddedWalletWatch(
      running: true,
      observed: false,
      timedOut: false,
    );
    for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
      var seen = false;
      try {
        final directory = await ref
            .read(walletReadGatewayProvider)
            .loadWallets();
        seen = directory.embedded.isNotEmpty;
      } on Object {
        // A refused or broken read is not "no wallet". The watch keeps its
        // unseen state and asks again on the next tick.
        seen = false;
      }
      if (!ref.mounted) return;
      if (seen) {
        state = LoopEmbeddedWalletWatch(
          running: false,
          observed: true,
          timedOut: false,
          attempts: attempt,
        );
        return;
      }
      if (attempt == maximumAttempts) {
        state = LoopEmbeddedWalletWatch(
          running: false,
          observed: false,
          timedOut: true,
          attempts: attempt,
        );
        return;
      }
      state = LoopEmbeddedWalletWatch(
        running: true,
        observed: false,
        timedOut: false,
        attempts: attempt,
      );
      await Future<void>.delayed(pollInterval);
      if (!ref.mounted) return;
    }
  }
}

final loopEmbeddedWalletWatchProvider =
    NotifierProvider<
      LoopEmbeddedWalletWatchController,
      LoopEmbeddedWalletWatch
    >(LoopEmbeddedWalletWatchController.new);

/// Joins every wallet observation this run holds into the 02 page's facts.
final loopWalletCreationFactsProvider = Provider<LoopWalletCreationFacts>((
  ref,
) {
  final watch = ref.watch(loopEmbeddedWalletWatchProvider);
  final provisioning = ref.watch(loopWalletProvisioningProvider);
  // Privy answering with a wallet on this device is a first-hand observation
  // and is accepted without waiting for the server's projection of it.
  final privyWallet = ref.watch(
    loopSessionProvider.select(
      (session) =>
          session.canUseProviderBackedFeatures &&
          session.account?.wallet != null,
    ),
  );
  final sequence = ref.watch(loopOnboardingSequenceProvider);

  final observed =
      watch.observed ||
      privyWallet ||
      provisioning.stage == LoopWalletProvisioningStage.created;
  final phase = observed
      ? LoopWalletCreationPhase.observed
      : watch.timedOut
      ? LoopWalletCreationPhase.timedOut
      : watch.running || provisioning.isCreating
      ? LoopWalletCreationPhase.working
      : watch.unavailable
      ? LoopWalletCreationPhase.unavailable
      : LoopWalletCreationPhase.working;

  return LoopWalletCreationFacts(
    phase: phase,
    recoveryEnrolled: sequence.enrolledRecoveryMethod != null,
    // The sequence only runs while the server calls the profile pending, so
    // the LOOP ID is provably not bound yet while this page is on screen.
    loopIdActivated: false,
    providerMessage: provisioning.stage == LoopWalletProvisioningStage.failed
        ? provisioning.errorMessage
        : null,
  );
});
