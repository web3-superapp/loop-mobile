import 'dart:async';

import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';

/// Principal-bound Stream token loader shared by the Chat and Video adapters.
///
/// Tokens are returned directly to the official SDK loader and are never
/// cached or persisted by LOOP. One 401 may refresh the current Privy access
/// token. One `bootstrap_required` response may re-establish the same
/// server-derived identity before retrying.
final class LoopStreamTokenSession {
  factory LoopStreamTokenSession({
    required String principalKey,
    required LoopBootstrapSession bootstrapSession,
    required LoopBackendAccessTokenSource accessTokens,
    required LoopStreamTokenRepository repository,
  }) {
    if (principalKey.isEmpty || principalKey != principalKey.trim()) {
      throw ArgumentError('principalKey must be a non-empty canonical value');
    }
    return LoopStreamTokenSession._(bootstrapSession, accessTokens, repository);
  }

  LoopStreamTokenSession._(
    this._bootstrapSession,
    this._accessTokens,
    this._repository,
  );

  final LoopBootstrapSession _bootstrapSession;
  final LoopBackendAccessTokenSource _accessTokens;
  final LoopStreamTokenRepository _repository;
  final Completer<void> _invalidated = Completer<void>();
  var _disposed = false;

  Future<String> loadToken({
    required LoopStreamTokenProduct product,
    required String expectedStreamUserId,
  }) async {
    final invalidated = _invalidated.future;
    await _requireExpectedIdentity(expectedStreamUserId, invalidated);

    var refreshedAuthentication = false;
    var repeatedBootstrap = false;
    while (!_disposed) {
      final accessToken = await _loadAccessToken(invalidated);
      try {
        final credential = await _untilInvalidated(
          _repository.issue(
            product: product,
            expectedStreamUserId: expectedStreamUserId,
            accessToken: accessToken,
          ),
          invalidated,
        );
        return credential.token;
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
        if (!requiresBootstrap) rethrow;
        _bootstrapSession.invalidateAuthorization();
        if (repeatedBootstrap) rethrow;

        repeatedBootstrap = true;
        await _requireExpectedIdentity(expectedStreamUserId, invalidated);
      }
    }
    throw const LoopBackendFailure(LoopBackendFailureKind.unavailable);
  }

  Future<void> _requireExpectedIdentity(
    String expectedStreamUserId,
    Future<void> invalidated,
  ) async {
    final authorization = await _untilInvalidated(
      _bootstrapSession.authorize(),
      invalidated,
    );
    final identity = _bootstrapSession.identity;
    if (authorization != LoopBootstrapAuthorization.authorized ||
        identity == null ||
        identity.streamUserId != expectedStreamUserId) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
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
    } on _LoopStreamTokenSessionInvalidated {
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
      return Future<T>.error(const _LoopStreamTokenSessionInvalidated());
    }
    return Future.any(<Future<T>>[
      operation,
      invalidated.then<T>(
        (_) => throw const _LoopStreamTokenSessionInvalidated(),
      ),
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_invalidated.isCompleted) _invalidated.complete();
  }
}

final class _LoopStreamTokenSessionInvalidated implements Exception {
  const _LoopStreamTokenSessionInvalidated();
}
