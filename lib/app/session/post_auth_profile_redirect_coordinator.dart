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

@immutable
final class LoopProfileLandingState {
  const LoopProfileLandingState({this.landing, this.failureKind});

  const LoopProfileLandingState.unknown() : landing = null, failureKind = null;

  final LoopProfileLanding? landing;
  final ProfileGatewayFailureKind? failureKind;

  bool get isUnavailable => landing == LoopProfileLanding.communityUnavailable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopProfileLandingState &&
          other.landing == landing &&
          other.failureKind == failureKind;

  @override
  int get hashCode => Object.hash(landing, failureKind);
}

final class LoopProfileLandingController
    extends Notifier<LoopProfileLandingState> {
  @override
  LoopProfileLandingState build() => const LoopProfileLandingState.unknown();

  void publish(LoopProfileLanding landing, {ProfileGatewayFailureKind? kind}) {
    state = LoopProfileLandingState(landing: landing, failureKind: kind);
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
