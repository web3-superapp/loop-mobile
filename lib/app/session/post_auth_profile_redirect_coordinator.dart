import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

/// Where a newly verified session lands once the public profile is known.
enum LoopProfileLanding {
  /// `profileStatus == pending`: the one-time activation has not run.
  loopIdSetup,

  /// `profileStatus == active`.
  community,

  /// The profile could not be read. Login is never blocked by it; the owner
  /// enters Community read-only with a visible unavailable notice and the
  /// check runs again on the next start.
  communityUnavailable,
}

/// Pure decision for a successfully read profile.
LoopProfileLanding loopProfileLandingFor(ProfileResource resource) =>
    switch (resource.profileStatus) {
      ProfileStatus.pending => LoopProfileLanding.loopIdSetup,
      ProfileStatus.active => LoopProfileLanding.community,
    };

/// Pure decision for a failed read. Every failure lands in Community; the kind
/// only changes the notice, never the gate.
LoopProfileLanding loopProfileLandingForFailure(
  ProfileGatewayFailureKind kind,
) => LoopProfileLanding.communityUnavailable;

/// Whether reading the profile again could answer something else.
///
/// A transport fault, an unavailable service and an unfinished account
/// initialisation are all states a later read can leave behind. A policy
/// answer is not: the server knows the owner and refused, and asking the same
/// question again cannot change that — offering 重试 there would promise a
/// change that nothing on this device can produce. Written as a switch so a
/// kind added to the gateway has to be classified rather than defaulting to
/// "ask again".
bool loopProfileRecheckCanHelp(ProfileGatewayFailureKind? kind) =>
    switch (kind) {
      null ||
      ProfileGatewayFailureKind.unavailable ||
      ProfileGatewayFailureKind.offline ||
      ProfileGatewayFailureKind.bootstrapRequired ||
      ProfileGatewayFailureKind.unexpected => true,
      ProfileGatewayFailureKind.permissionDenied ||
      ProfileGatewayFailureKind.regionBlocked ||
      ProfileGatewayFailureKind.stepUpRequired ||
      ProfileGatewayFailureKind.versionConflict ||
      ProfileGatewayFailureKind.idempotencyConflict ||
      ProfileGatewayFailureKind.validationFailed ||
      ProfileGatewayFailureKind.aliasReserved ||
      ProfileGatewayFailureKind.aliasBlocked ||
      ProfileGatewayFailureKind.invalidData => false,
    };

/// Whether a verified session has to wait on the launch page.
///
/// Once a credential is accepted there is exactly one thing left to learn
/// before LOOP knows where the owner belongs: whether the server already
/// calls the account active. Until `GET /v2/profile` answers, no product
/// surface may be drawn — a Community frame here is a guess, and a pending
/// account was shown that guess for a frame before being pulled into 02
/// (device report 2026-09-21 · F1). Holding on the launch page instead makes
/// the wait look like the App still opening, which is what it is.
///
/// Sessions LOOP never reads a profile for are never held: the Development
/// Preview and a credential Privy accepted but has not verified have no
/// answer coming, so waiting for one would never end.
bool loopPostAuthHoldsAtLaunch({
  required LoopSessionState session,
  required LoopProfileLandingState landing,
}) => session.canUseProviderBackedFeatures && landing.isUnknown;

/// How long one `GET /v2/profile` read may take before the owner stops
/// waiting for it.
///
/// The launch page waits on this read, so the read needs an end. Fifteen
/// seconds is longer than the transport's own ceilings and short enough that
/// a dead service does not look like a frozen App; running out is reported as
/// the service being unavailable and never as an answer about the account.
const loopPostAuthProfileReadCeiling = Duration(seconds: 15);

@immutable
final class LoopProfileLandingState {
  const LoopProfileLandingState({
    this.landing,
    this.failureKind,
    this.rechecking = false,
    this.dismissed = false,
  });

  const LoopProfileLandingState.unknown()
    : landing = null,
      failureKind = null,
      rechecking = false,
      dismissed = false;

  final LoopProfileLanding? landing;
  final ProfileGatewayFailureKind? failureKind;

  /// A second read of the profile is running. It is the read itself that is
  /// reported, never a guess at how it will answer: the unavailable fact stays
  /// exactly as it was until a real answer replaces it.
  final bool rechecking;

  /// The owner put the notice away for this run. It hides the notice and
  /// changes nothing else — the profile is still unread, every surface that
  /// depends on it still says so, and the next published answer brings the
  /// notice back if it is still unavailable.
  final bool dismissed;

  /// `GET /v2/profile` has not answered for this account yet.
  ///
  /// It is the only state in which LOOP does not know where the owner
  /// belongs, and it is what the launch gate waits on: a Community frame
  /// drawn here would be a guess that the account is active, and a pending
  /// account saw exactly that guess before being pulled into 02 (device
  /// report 2026-09-21 · F1).
  bool get isUnknown => landing == null;

  bool get isUnavailable => landing == LoopProfileLanding.communityUnavailable;

  /// Whether the owner should be shown the unavailable notice right now.
  bool get shouldWarn => isUnavailable && !dismissed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopProfileLandingState &&
          other.landing == landing &&
          other.failureKind == failureKind &&
          other.rechecking == rechecking &&
          other.dismissed == dismissed;

  @override
  int get hashCode => Object.hash(landing, failureKind, rechecking, dismissed);
}

final class LoopProfileLandingController
    extends Notifier<LoopProfileLandingState> {
  /// The re-read, handed over by the application composition that owns the
  /// coordinator. Absent in a tree that never installed one, where the notice
  /// simply offers no retry.
  Future<void> Function()? _recheck;

  @override
  LoopProfileLandingState build() => const LoopProfileLandingState.unknown();

  /// Registers the re-read the owner may ask for. Called once by the
  /// composition; the controller never constructs a gateway of its own.
  void bindRecheck(Future<void> Function() recheck) => _recheck = recheck;

  /// A published landing is an answer: it clears both the running mark and a
  /// dismissal, because a notice the owner put away was about the previous
  /// answer, not this one.
  void publish(LoopProfileLanding landing, {ProfileGatewayFailureKind? kind}) {
    state = LoopProfileLandingState(landing: landing, failureKind: kind);
  }

  /// Reads `GET /v2/profile` again after a failed one.
  ///
  /// Only an unavailable landing may be re-read: a profile that *was* read
  /// needs nothing, and a run with no re-read registered has nothing to offer.
  /// It is single-flight, and it publishes nothing itself — the answer arrives
  /// through [publish], so a retry can never announce a profile it did not
  /// actually read.
  Future<void> recheck() async {
    final recheck = _recheck;
    if (recheck == null ||
        state.rechecking ||
        !state.isUnavailable ||
        !loopProfileRecheckCanHelp(state.failureKind)) {
      return;
    }
    state = LoopProfileLandingState(
      landing: state.landing,
      failureKind: state.failureKind,
      rechecking: true,
    );
    try {
      await recheck();
    } on Object {
      // The coordinator publishes every outcome, including its failures.
    }
    if (!ref.mounted || !state.rechecking) return;
    state = LoopProfileLandingState(
      landing: state.landing,
      failureKind: state.failureKind,
    );
  }

  /// Puts the notice away for this run. It is never a claim about the profile.
  void dismiss() {
    if (!state.isUnavailable || state.dismissed) return;
    state = LoopProfileLandingState(
      landing: state.landing,
      failureKind: state.failureKind,
      dismissed: true,
    );
  }

  void reset() => state = const LoopProfileLandingState.unknown();
}

final loopProfileLandingProvider =
    NotifierProvider<LoopProfileLandingController, LoopProfileLandingState>(
      LoopProfileLandingController.new,
    );

/// Reads `GET /v2/profile` once per newly accepted verified principal and
/// decides the landing route.
///
/// The read runs through the authenticated session, which already waits for
/// bootstrap authorization, so no separate bootstrap ordering is needed here.
/// A failure never rejects or rolls back login.
class PostAuthProfileRedirectCoordinator {
  PostAuthProfileRedirectCoordinator({
    required Future<ProfileResource> Function() readProfile,
    required Future<void> Function(LoopProfileLanding landing) prepare,
    required void Function(LoopProfileLanding landing) navigate,
    required void Function(
      LoopProfileLanding? landing,
      ProfileGatewayFailureKind? kind,
    )
    publish,
    this.readCeiling = loopPostAuthProfileReadCeiling,
    // ignore: prefer_initializing_formals
  }) : _readProfile = readProfile,
       // ignore: prefer_initializing_formals
       _prepare = prepare,
       // ignore: prefer_initializing_formals
       _navigate = navigate,
       // ignore: prefer_initializing_formals
       _publish = publish;

  final Future<ProfileResource> Function() _readProfile;

  /// Brings the rest of the application into the state a decided landing
  /// implies, before the landing is published.
  ///
  /// The launch gate opens on the published landing, so everything the gate
  /// then reads has to be true already: for a pending profile that is the
  /// opening sequence's position, which comes from device storage and is
  /// therefore not instant. Preparing first is what keeps the owner on the
  /// launch page for the whole wait instead of passing through step 02 on
  /// the way to step 04.
  final Future<void> Function(LoopProfileLanding landing) _prepare;

  final void Function(LoopProfileLanding landing) _navigate;

  /// Publishes the decided landing, or `null` for "nothing is known yet".
  ///
  /// `null` is published the moment a new account starts being read, so the
  /// previous account's answer can never be mistaken for this one's.
  final void Function(
    LoopProfileLanding? landing,
    ProfileGatewayFailureKind? kind,
  )
  _publish;

  /// How long one read may take before it counts as unavailable.
  final Duration readCeiling;

  String? _requestedPrincipal;

  void onSessionChanged(LoopSessionState? previous, LoopSessionState next) {
    if (next.mode == LoopSessionMode.signedOut ||
        next.mode == LoopSessionMode.preview) {
      _requestedPrincipal = null;
      // Leaving the account drops its answer rather than replacing it with
      // Community: signed out, LOOP knows nothing about any profile, and the
      // next account must not inherit this one's landing.
      _publish(null, null);
      return;
    }
    final principal = _verifiedPrincipal(next);
    if (principal == null) return;
    final previousPrincipal = previous == null
        ? null
        : _verifiedPrincipal(previous);
    if (previousPrincipal == principal || _requestedPrincipal == principal) {
      return;
    }
    _requestedPrincipal = principal;
    // The gate closes here, synchronously, before anything can route on a
    // landing that belongs to the session this one replaced.
    _publish(null, null);
    unawaited(resolve());
  }

  /// Visible for the app composition and tests; safe to call again on start.
  ///
  /// The order is deliberate and is the whole of F1: read, prepare, publish,
  /// navigate. Publishing is what opens the launch gate, so it comes after
  /// the state that gate reads, and before the navigation that gate would
  /// otherwise bounce back to the launch page.
  Future<void> resolve() async {
    final LoopProfileLanding landing;
    ProfileGatewayFailureKind? kind;
    try {
      landing = loopProfileLandingFor(
        await _readProfile().timeout(readCeiling),
      );
    } on ProfileGatewayException catch (error) {
      kind = error.kind;
      return _land(loopProfileLandingForFailure(kind), kind);
    } on TimeoutException {
      // A read that never answers is not an answer. It is reported as the
      // service being unavailable, which is what the owner can act on: the
      // notice offers the read again instead of leaving them on a launch
      // page that waits forever.
      kind = ProfileGatewayFailureKind.unavailable;
      return _land(loopProfileLandingForFailure(kind), kind);
    } catch (_) {
      kind = ProfileGatewayFailureKind.unexpected;
      return _land(loopProfileLandingForFailure(kind), kind);
    }
    return _land(landing, null);
  }

  Future<void> _land(
    LoopProfileLanding landing,
    ProfileGatewayFailureKind? kind,
  ) async {
    try {
      await _prepare(landing);
    } on Object {
      // Preparing is a convenience for the gate, never a condition of it. A
      // position that could not be read still lands the owner somewhere.
    }
    _publish(landing, kind);
    _navigate(landing);
  }

  String? _verifiedPrincipal(LoopSessionState session) {
    if (!session.canUseProviderBackedFeatures) return null;
    final value = session.account?.privyUserId.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
