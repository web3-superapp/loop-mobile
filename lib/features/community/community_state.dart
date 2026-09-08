import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// The reviewed page states for an S3 surface. `permission` covers both a
/// refused governance action and a missing LOOP ID activation: in both cases
/// the account is known but not entitled, which is not a service outage.
enum CommunityViewPhase {
  loading,
  ready,
  empty,
  error,
  offline,
  unavailable,
  permission,
}

CommunityViewPhase communityPhaseForFailure(CommunityFailureKind? kind) =>
    switch (kind) {
      CommunityFailureKind.offline => CommunityViewPhase.offline,
      CommunityFailureKind.unavailable => CommunityViewPhase.unavailable,
      CommunityFailureKind.permissionDenied ||
      CommunityFailureKind.activationRequired => CommunityViewPhase.permission,
      null => CommunityViewPhase.empty,
      _ => CommunityViewPhase.error,
    };

/// One loaded resource plus the honest phase for the page that renders it.
@immutable
final class CommunityResourceState<T> {
  const CommunityResourceState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.busy = false,
  });

  factory CommunityResourceState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return CommunityResourceState<T>(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final T? value;
  final CommunityFailureKind? failureKind;

  /// A write is in flight. The page keeps rendering the last server truth and
  /// only disables its actions.
  final bool busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  bool get isReady => phase == CommunityViewPhase.ready && value != null;

  CommunityResourceState<T> loading() => CommunityResourceState<T>(
    mode: mode,
    phase: value == null
        ? CommunityViewPhase.loading
        : CommunityViewPhase.ready,
    value: value,
    busy: busy,
  );

  CommunityResourceState<T> ready(T next) => CommunityResourceState<T>(
    mode: mode,
    phase: CommunityViewPhase.ready,
    value: next,
  );

  CommunityResourceState<T> failed(CommunityFailureKind kind) =>
      CommunityResourceState<T>(
        mode: mode,
        phase: value == null
            ? communityPhaseForFailure(kind)
            : CommunityViewPhase.ready,
        value: value,
        failureKind: kind,
      );

  CommunityResourceState<T> working(bool next) => CommunityResourceState<T>(
    mode: mode,
    phase: phase,
    value: value,
    failureKind: next ? null : failureKind,
    busy: next,
  );
}
