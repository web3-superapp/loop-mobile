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
    required void Function(LoopProfileLanding landing) navigate,
    required void Function(
      LoopProfileLanding landing,
      ProfileGatewayFailureKind? kind,
    )
    publish,
    // ignore: prefer_initializing_formals
  }) : _readProfile = readProfile,
       // ignore: prefer_initializing_formals
       _navigate = navigate,
       // ignore: prefer_initializing_formals
       _publish = publish;

  final Future<ProfileResource> Function() _readProfile;
  final void Function(LoopProfileLanding landing) _navigate;
  final void Function(
    LoopProfileLanding landing,
    ProfileGatewayFailureKind? kind,
  )
  _publish;

  String? _requestedPrincipal;

  void onSessionChanged(LoopSessionState? previous, LoopSessionState next) {
    if (next.mode == LoopSessionMode.signedOut ||
        next.mode == LoopSessionMode.preview) {
      _requestedPrincipal = null;
      _publish(LoopProfileLanding.community, null);
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
    unawaited(resolve());
  }

  /// Visible for the app composition and tests; safe to call again on start.
  Future<void> resolve() async {
    try {
      final resource = await _readProfile();
      final landing = loopProfileLandingFor(resource);
      _publish(landing, null);
      _navigate(landing);
    } on ProfileGatewayException catch (error) {
      final landing = loopProfileLandingForFailure(error.kind);
      _publish(landing, error.kind);
      _navigate(landing);
    } catch (_) {
      const kind = ProfileGatewayFailureKind.unexpected;
      final landing = loopProfileLandingForFailure(kind);
      _publish(landing, kind);
      _navigate(landing);
    }
  }

  String? _verifiedPrincipal(LoopSessionState session) {
    if (!session.canUseProviderBackedFeatures) return null;
    final value = session.account?.privyUserId.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
