import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';

enum PerpGatewayMode { unavailable, production }

enum PerpGatewayFailureKind {
  authentication,
  bootstrapRequired,
  walletBindingRequired,
  versionConflict,
  invalidRequest,
  unavailable,
  timeout,
  connection,
  cancelled,
  invalidData,
  unexpected,
}

final class PerpGatewayException implements Exception {
  const PerpGatewayException(this.kind, {this.requestId});

  final PerpGatewayFailureKind kind;
  final String? requestId;

  String get code => switch (kind) {
    PerpGatewayFailureKind.authentication => 'perp_authentication_required',
    PerpGatewayFailureKind.bootstrapRequired => 'perp_bootstrap_required',
    PerpGatewayFailureKind.walletBindingRequired =>
      'perp_wallet_binding_required',
    PerpGatewayFailureKind.versionConflict => 'perp_version_conflict',
    PerpGatewayFailureKind.invalidRequest => 'invalid_perp_request',
    PerpGatewayFailureKind.unavailable => 'perp_unavailable',
    PerpGatewayFailureKind.timeout => 'perp_request_timeout',
    PerpGatewayFailureKind.connection => 'perp_connection_failed',
    PerpGatewayFailureKind.cancelled => 'perp_request_cancelled',
    PerpGatewayFailureKind.invalidData => 'invalid_perp_data',
    PerpGatewayFailureKind.unexpected => 'perp_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class PerpPrivateGateway {
  PerpGatewayMode get mode;

  Future<PerpWalletBinding> getWalletBinding();

  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  });

  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  });

  Future<PerpConfig> getConfig();

  Future<PerpAccount> getAccount();

  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor});

  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor});

  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor});

  Future<PerpPage<PerpFundingEntry>> listFunding({int? limit, String? cursor});
}

/// Production-safe default until a verified principal-bound session overrides
/// this port at the application composition root.
final class UnavailablePerpPrivateGateway implements PerpPrivateGateway {
  const UnavailablePerpPrivateGateway();

  @override
  PerpGatewayMode get mode => PerpGatewayMode.unavailable;

  @override
  Future<PerpWalletBinding> getWalletBinding() => _unavailable();

  @override
  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  }) => _unavailable();

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  }) => _unavailable();

  @override
  Future<PerpConfig> getConfig() => _unavailable();

  @override
  Future<PerpAccount> getAccount() => _unavailable();

  @override
  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor}) =>
      _unavailable();

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      _unavailable();

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      _unavailable();

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => _unavailable();
}

Future<T> _unavailable<T>() => Future<T>.error(
  const PerpGatewayException(PerpGatewayFailureKind.unavailable),
);

final perpPrivateGatewayProvider = Provider<PerpPrivateGateway>(
  (ref) => const UnavailablePerpPrivateGateway(),
);
