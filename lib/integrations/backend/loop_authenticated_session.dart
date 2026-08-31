import 'dart:async';

import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';

typedef LoopAuthenticatedRequest<T> = Future<T> Function(String accessToken);

/// Principal-bound executor for authenticated LOOP backend requests.
///
/// It performs no generic transport retry. One proven 401 may obtain the
/// current Privy access token again, and one `bootstrap_required` response may
/// re-establish the same server mapping. Command repositories must keep their
/// own idempotency key and operation reconciliation semantics.
final class LoopAuthenticatedSession {
  factory LoopAuthenticatedSession({
    required String principalKey,
    required LoopBootstrapSession bootstrapSession,
    required LoopBackendAccessTokenSource accessTokens,
  }) {
    if (principalKey.isEmpty || principalKey != principalKey.trim()) {
      throw ArgumentError('principalKey must be a non-empty canonical value');
    }
    return LoopAuthenticatedSession._(bootstrapSession, accessTokens);
  }

  LoopAuthenticatedSession._(this._bootstrapSession, this._accessTokens);

  final LoopBootstrapSession _bootstrapSession;
  final LoopBackendAccessTokenSource _accessTokens;
  final Completer<void> _invalidated = Completer<void>();
  var _disposed = false;

  Future<T> execute<T>(LoopAuthenticatedRequest<T> request) async {
    final invalidated = _invalidated.future;
    await _requireBootstrap(invalidated);

    var refreshedAuthentication = false;
    var repeatedBootstrap = false;
    while (!_disposed) {
      final accessToken = await _loadAccessToken(invalidated);
      try {
        return await _untilInvalidated(request(accessToken), invalidated);
      } on LoopBackendFailure catch (failure) {
        final mayRefreshAuthentication =
            !refreshedAuthentication &&
            failure.kind == LoopBackendFailureKind.authentication &&
            failure.statusCode == 401;
        if (mayRefreshAuthentication) {
          refreshedAuthentication = true;
          continue;
        }

        final requiresBootstrap =
            failure.statusCode == 409 && failure.code == 'bootstrap_required';
        if (!requiresBootstrap || repeatedBootstrap) rethrow;
        repeatedBootstrap = true;
        _bootstrapSession.invalidateAuthorization();
        await _requireBootstrap(invalidated);
      }
    }
    throw const LoopBackendFailure(LoopBackendFailureKind.unavailable);
  }

  Future<void> _requireBootstrap(Future<void> invalidated) async {
    final result = await _untilInvalidated(
      _bootstrapSession.authorize(),
      invalidated,
    );
    if (result != LoopBootstrapAuthorization.authorized ||
        _bootstrapSession.identity == null) {
      throw const LoopBackendFailure(LoopBackendFailureKind.unavailable);
    }
  }

  Future<String> _loadAccessToken(Future<void> invalidated) async {
    try {
      final token = await _untilInvalidated(
        _accessTokens.loadAccessToken(),
        invalidated,
      );
      if (token.isEmpty || token != token.trim()) {
        throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
      }
      return token;
    } on _LoopAuthenticatedSessionInvalidated {
      rethrow;
    } on LoopBackendFailure {
      rethrow;
    } catch (_) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  Future<T> _untilInvalidated<T>(
    Future<T> operation,
    Future<void> invalidated,
  ) {
    if (_disposed) {
      return Future<T>.error(const _LoopAuthenticatedSessionInvalidated());
    }
    return Future.any(<Future<T>>[
      operation,
      invalidated.then<T>(
        (_) => throw const _LoopAuthenticatedSessionInvalidated(),
      ),
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_invalidated.isCompleted) _invalidated.complete();
  }
}

final class _LoopAuthenticatedSessionInvalidated implements Exception {
  const _LoopAuthenticatedSessionInvalidated();
}
