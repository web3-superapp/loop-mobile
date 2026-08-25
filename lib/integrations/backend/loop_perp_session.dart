import 'dart:async';

import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_repository.dart';

/// One private-Perp request owner bound to a fully verified Privy principal.
///
/// It stores no access token. Every operation gates on the existing LOOP
/// bootstrap and obtains a current token for that immediate backend request.
final class LoopPerpSession implements PerpPrivateGateway {
  factory LoopPerpSession({
    required String principalKey,
    required LoopBootstrapSession bootstrapSession,
    required LoopBackendAccessTokenSource accessTokens,
    required LoopPerpRepository repository,
  }) {
    if (principalKey.isEmpty || principalKey != principalKey.trim()) {
      throw ArgumentError('principalKey must be a non-empty canonical value');
    }
    return LoopPerpSession._(bootstrapSession, accessTokens, repository);
  }

  LoopPerpSession._(
    this._bootstrapSession,
    this._accessTokens,
    this._repository,
  );

  final LoopBootstrapSession _bootstrapSession;
  final LoopBackendAccessTokenSource _accessTokens;
  final LoopPerpRepository _repository;
  final Completer<void> _invalidated = Completer<void>();

  var _disposed = false;

  @override
  PerpGatewayMode get mode => PerpGatewayMode.production;

  @override
  Future<PerpWalletBinding> getWalletBinding() => _execute(
    (accessToken) => _repository.getWalletBinding(accessToken: accessToken),
  );

  @override
  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  }) => _execute(
    (accessToken) => _repository.bindWallet(
      accessToken: accessToken,
      expectedBindingVersion: expectedBindingVersion,
    ),
  );

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  }) => _execute(
    (accessToken) => _repository.unbindWallet(
      accessToken: accessToken,
      expectedBindingVersion: expectedBindingVersion,
    ),
  );

  @override
  Future<PerpConfig> getConfig() => _execute(
    (accessToken) => _repository.getConfig(accessToken: accessToken),
  );

  @override
  Future<PerpAccount> getAccount() => _execute(
    (accessToken) => _repository.getAccount(accessToken: accessToken),
  );

  @override
  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor}) =>
      _execute(
        (accessToken) => _repository.listPositions(
          accessToken: accessToken,
          limit: limit,
          cursor: cursor,
        ),
      );

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      _execute(
        (accessToken) => _repository.listOrders(
          accessToken: accessToken,
          limit: limit,
          cursor: cursor,
        ),
      );

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      _execute(
        (accessToken) => _repository.listFills(
          accessToken: accessToken,
          limit: limit,
          cursor: cursor,
        ),
      );

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => _execute(
    (accessToken) => _repository.listFunding(
      accessToken: accessToken,
      limit: limit,
      cursor: cursor,
    ),
  );

  Future<T> _execute<T>(Future<T> Function(String accessToken) request) async {
    if (_disposed) {
      throw const PerpGatewayException(PerpGatewayFailureKind.cancelled);
    }

    try {
      final authorization = await _untilInvalidated(
        _bootstrapSession.authorize(),
      );
      if (authorization != LoopBootstrapAuthorization.authorized) {
        throw const PerpGatewayException(PerpGatewayFailureKind.unavailable);
      }

      final firstToken = await _loadToken();
      try {
        return await _untilInvalidated(request(firstToken));
      } on LoopBackendFailure catch (failure) {
        if (failure.kind != LoopBackendFailureKind.authentication ||
            failure.statusCode != 401 ||
            _disposed) {
          throw _mapAndInvalidate(failure);
        }
      }

      final refreshedToken = await _loadToken();
      try {
        return await _untilInvalidated(request(refreshedToken));
      } on LoopBackendFailure catch (failure) {
        throw _mapAndInvalidate(failure);
      }
    } on _LoopPerpInvalidated {
      throw const PerpGatewayException(PerpGatewayFailureKind.cancelled);
    } on PerpGatewayException {
      rethrow;
    } catch (_) {
      throw const PerpGatewayException(PerpGatewayFailureKind.unexpected);
    }
  }

  Future<String> _loadToken() async {
    try {
      final token = await _untilInvalidated(_accessTokens.loadAccessToken());
      if (token.isEmpty || token != token.trim()) {
        throw const PerpGatewayException(PerpGatewayFailureKind.authentication);
      }
      return token;
    } on _LoopPerpInvalidated {
      rethrow;
    } on PerpGatewayException {
      rethrow;
    } catch (_) {
      throw const PerpGatewayException(PerpGatewayFailureKind.authentication);
    }
  }

  Future<T> _untilInvalidated<T>(Future<T> operation) {
    if (_disposed) return Future<T>.error(const _LoopPerpInvalidated());
    return Future.any(<Future<T>>[
      operation,
      _invalidated.future.then<T>((_) => throw const _LoopPerpInvalidated()),
    ]);
  }

  PerpGatewayException _mapFailure(LoopBackendFailure failure) {
    final kind = switch (failure.code) {
      'bootstrap_required' => PerpGatewayFailureKind.bootstrapRequired,
      'wallet_binding_required' => PerpGatewayFailureKind.walletBindingRequired,
      'version_conflict' => PerpGatewayFailureKind.versionConflict,
      'invalid_request' => PerpGatewayFailureKind.invalidRequest,
      'request_timeout' => PerpGatewayFailureKind.timeout,
      _ => switch (failure.kind) {
        LoopBackendFailureKind.invalidConfiguration =>
          PerpGatewayFailureKind.unavailable,
        LoopBackendFailureKind.authentication =>
          PerpGatewayFailureKind.authentication,
        LoopBackendFailureKind.invalidRequest =>
          PerpGatewayFailureKind.invalidRequest,
        LoopBackendFailureKind.unavailable =>
          PerpGatewayFailureKind.unavailable,
        LoopBackendFailureKind.timeout => PerpGatewayFailureKind.timeout,
        LoopBackendFailureKind.connection => PerpGatewayFailureKind.connection,
        LoopBackendFailureKind.cancelled => PerpGatewayFailureKind.cancelled,
        LoopBackendFailureKind.invalidPayload =>
          PerpGatewayFailureKind.invalidData,
        LoopBackendFailureKind.unexpected => PerpGatewayFailureKind.unexpected,
      },
    };
    return PerpGatewayException(kind, requestId: failure.requestId);
  }

  PerpGatewayException _mapAndInvalidate(LoopBackendFailure failure) {
    final mapped = _mapFailure(failure);
    if (mapped.kind == PerpGatewayFailureKind.bootstrapRequired) {
      _bootstrapSession.invalidateAuthorization();
    }
    return mapped;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_invalidated.isCompleted) _invalidated.complete();
  }
}

final class _LoopPerpInvalidated implements Exception {
  const _LoopPerpInvalidated();
}
