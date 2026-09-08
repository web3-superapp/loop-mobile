import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';

/// `security` · `GET /v2/security/summary`.
final class SecuritySummaryController
    extends LoopChainReadController<LoopSecuritySummary> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(securityGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopSecuritySummary> fetch() =>
      ref.read(securityGatewayProvider).loadSummary();
}

final securitySummaryControllerProvider =
    NotifierProvider<
      SecuritySummaryController,
      LoopChainResourceState<LoopSecuritySummary>
    >(SecuritySummaryController.new);

/// `security` / `key-export` / `social-recovery` · the six unavailable methods.
final class SecurityCapabilitiesController
    extends LoopChainReadController<LoopSecurityCapabilities> {
  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(securityGatewayProvider.select((gateway) => gateway.mode));

  @override
  Future<LoopSecurityCapabilities> fetch() =>
      ref.read(securityGatewayProvider).loadCapabilities();
}

final securityCapabilitiesControllerProvider =
    NotifierProvider<
      SecurityCapabilitiesController,
      LoopChainResourceState<LoopSecurityCapabilities>
    >(SecurityCapabilitiesController.new);

/// What the last revoke command actually achieved.
///
/// It exists so the page can state the audit-only effect verbatim instead of
/// announcing that the other device was signed out.
@immutable
final class DeviceRevokeOutcome {
  const DeviceRevokeOutcome({
    required this.sessionId,
    required this.revokedAt,
    required this.providerAccessTerminated,
  });

  final String sessionId;
  final DateTime revokedAt;
  final bool providerAccessTerminated;
}

@immutable
final class DevicesState {
  const DevicesState({
    required this.resource,
    this.commandFailureKind,
    this.outcome,
  });

  final LoopChainResourceState<LoopDeviceDirectory> resource;

  /// The failure of the last revoke, kept apart from the list's own failure so
  /// a refused command never blanks a list that did load.
  final LoopChainFailureKind? commandFailureKind;
  final DeviceRevokeOutcome? outcome;

  bool get busy => resource.busy;

  DevicesState copyWith({
    LoopChainResourceState<LoopDeviceDirectory>? resource,
    LoopChainFailureKind? commandFailureKind,
    DeviceRevokeOutcome? outcome,
    bool clearCommand = false,
  }) => DevicesState(
    resource: resource ?? this.resource,
    commandFailureKind: clearCommand
        ? null
        : (commandFailureKind ?? this.commandFailureKind),
    outcome: clearCommand ? null : (outcome ?? this.outcome),
  );
}

/// `devices` · the list plus the single-session revoke command.
final class DevicesController extends Notifier<DevicesState>
    with LoopChainSingleFlight {
  @override
  DevicesState build() {
    nextGeneration();
    final mode = ref.watch(
      securityGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return DevicesState(
      resource: LoopChainResourceState<LoopDeviceDirectory>.initial(mode),
    );
  }

  Future<void> load() {
    if (state.resource.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.copyWith(resource: state.resource.loading());
    try {
      final directory = await ref.read(securityGatewayProvider).loadDevices();
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.ready(directory));
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(resource: state.resource.failed(error.kind));
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.copyWith(
        resource: state.resource.failed(LoopChainFailureKind.unexpected),
      );
    }
  });

  /// Revokes one other session and reloads the list.
  ///
  /// Returns `true` only when the server confirmed the audit projection. It
  /// never means the other device lost provider access.
  Future<bool> revoke(String sessionId) async {
    if (state.busy) return false;
    state = state.copyWith(
      resource: state.resource.working(true),
      clearCommand: true,
    );
    try {
      final result = await ref
          .read(securityGatewayProvider)
          .revokeDevice(sessionId);
      state = state.copyWith(
        resource: state.resource.working(false),
        outcome: DeviceRevokeOutcome(
          sessionId: result.sessionId,
          revokedAt: result.revokedAt,
          providerAccessTerminated: result.providerAccessTerminated,
        ),
      );
      await reload();
      return true;
    } on LoopChainException catch (error) {
      state = state.copyWith(
        resource: state.resource.working(false),
        commandFailureKind: error.kind,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        resource: state.resource.working(false),
        commandFailureKind: LoopChainFailureKind.unexpected,
      );
      return false;
    }
  }
}

final devicesControllerProvider =
    NotifierProvider<DevicesController, DevicesState>(DevicesController.new);
