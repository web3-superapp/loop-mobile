import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';

/// Feature-facing port for the `alerts` half of the notifications module.
abstract interface class AlertsGateway {
  LoopChainGatewayMode get mode;

  Future<LoopAlertPage> listAlerts({String? cursor});

  /// Creating carries one canonical `Idempotency-Key` per logical draft.
  Future<LoopPriceAlert> createAlert(LoopAlertDraft draft);

  /// Editing is a version CAS and carries no idempotency key.
  Future<LoopPriceAlert> updateAlert({
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
  });

  Future<void> deleteAlert({
    required String alertId,
    required int expectedVersion,
  });
}

final class UnavailableAlertsGateway implements AlertsGateway {
  const UnavailableAlertsGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopAlertPage> listAlerts({String? cursor}) => _unavailable();

  @override
  Future<LoopPriceAlert> createAlert(LoopAlertDraft draft) => _unavailable();

  @override
  Future<LoopPriceAlert> updateAlert({
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
  }) => _unavailable();

  @override
  Future<void> deleteAlert({
    required String alertId,
    required int expectedVersion,
  }) => _unavailable();
}

final alertsGatewayProvider = Provider<AlertsGateway>(
  (ref) => const UnavailableAlertsGateway(),
);
