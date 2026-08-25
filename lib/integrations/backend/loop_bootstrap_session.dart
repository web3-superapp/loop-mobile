import 'dart:async';

import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';

enum LoopBootstrapAuthorization { authorized, unavailable }

/// One in-memory LOOP backend identity owner bound to one Privy principal.
///
/// The principal key is used only to force instance rotation. It is never sent
/// to the backend or transformed into a LOOP or Stream identity.
final class LoopBootstrapSession {
  factory LoopBootstrapSession({
    required String principalKey,
    required LoopBackendAccessTokenSource accessTokens,
    required LoopBootstrapRepository repository,
  }) {
    if (principalKey.isEmpty || principalKey != principalKey.trim()) {
      throw ArgumentError('principalKey must be a non-empty canonical value');
    }
    return LoopBootstrapSession._(accessTokens, repository);
  }

  LoopBootstrapSession._(this._accessTokens, this._repository);

  final LoopBackendAccessTokenSource _accessTokens;
  final LoopBootstrapRepository _repository;
  final Completer<void> _invalidated = Completer<void>();

  Future<LoopBootstrapAuthorization>? _authorization;
  LoopBootstrapIdentity? _identity;
  var _authorized = false;
  var _disposed = false;

  LoopBootstrapIdentity? get identity => _authorized ? _identity : null;

  Future<LoopBootstrapAuthorization> authorize() {
    if (_disposed) {
      return Future<LoopBootstrapAuthorization>.value(
        LoopBootstrapAuthorization.unavailable,
      );
    }
    if (_authorized && _identity != null) {
      return Future<LoopBootstrapAuthorization>.value(
        LoopBootstrapAuthorization.authorized,
      );
    }
    final active = _authorization;
    if (active != null) return active;

    late final Future<LoopBootstrapAuthorization> operation;
    operation = _authorize(_invalidated.future).whenComplete(() {
      if (identical(_authorization, operation)) {
        _authorization = null;
      }
    });
    _authorization = operation;
    return operation;
  }

  /// Drops only the cached server-side bootstrap assertion.
  ///
  /// Provider sessions call this after an authenticated backend route proves
  /// that its bootstrap mapping no longer exists. A later explicit operation
  /// must then authorize through POST /v1/bootstrap again.
  void invalidateAuthorization() {
    if (_disposed) return;
    _authorized = false;
    _identity = null;
  }

  Future<LoopBootstrapAuthorization> _authorize(
    Future<void> invalidated,
  ) async {
    try {
      final firstToken = await _loadToken(invalidated);
      LoopBootstrapIdentity identity;
      try {
        identity = await _untilInvalidated(
          _repository.bootstrap(accessToken: firstToken),
          invalidated,
        );
      } on LoopBackendFailure catch (failure) {
        if (failure.kind != LoopBackendFailureKind.authentication ||
            failure.statusCode != 401 ||
            _disposed) {
          return LoopBootstrapAuthorization.unavailable;
        }
        final refreshedToken = await _loadToken(invalidated);
        identity = await _untilInvalidated(
          _repository.bootstrap(accessToken: refreshedToken),
          invalidated,
        );
      }

      if (_disposed) return LoopBootstrapAuthorization.unavailable;
      _identity = identity;
      _authorized = true;
      return LoopBootstrapAuthorization.authorized;
    } catch (_) {
      return LoopBootstrapAuthorization.unavailable;
    }
  }

  Future<String> _loadToken(Future<void> invalidated) async {
    final token = await _untilInvalidated(
      _accessTokens.loadAccessToken(),
      invalidated,
    );
    if (token.isEmpty || token != token.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
    return token;
  }

  Future<T> _untilInvalidated<T>(
    Future<T> operation,
    Future<void> invalidated,
  ) {
    if (_disposed) {
      return Future<T>.error(const _LoopBootstrapInvalidated());
    }
    return Future.any(<Future<T>>[
      operation,
      invalidated.then<T>((_) => throw const _LoopBootstrapInvalidated()),
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _authorized = false;
    _identity = null;
    if (!_invalidated.isCompleted) _invalidated.complete();
  }
}

final class _LoopBootstrapInvalidated implements Exception {
  const _LoopBootstrapInvalidated();
}
