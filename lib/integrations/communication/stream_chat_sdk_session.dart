import 'dart:async';

import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';

/// Server-owned Stream identity returned by the future LOOP bootstrap.
///
/// [userId] must be derived by the backend from LOOP's immutable internal user
/// ID. Flutter must never derive it from a Privy DID, email, or wallet address.
final class StreamChatIdentity {
  const StreamChatIdentity({
    required this.userId,
    this.displayName,
    this.imageUrl,
  });

  final String userId;
  final String? displayName;
  final String? imageUrl;

  bool get isValid => userId.isNotEmpty && userId == userId.trim();
}

/// Narrow frontend contract for the backend bootstrap/token provider.
///
/// Implementations may obtain a current Privy access token internally, but no
/// Privy or Stream token is exposed to widgets or persisted by LOOP code.
abstract interface class StreamChatSessionSource {
  Future<StreamChatIdentity?> loadIdentity();

  Future<String> loadToken(String userId);
}

/// Testable lifecycle surface around the official Stream Chat client.
abstract interface class StreamChatClientPort {
  String? get connectedUserId;

  Future<void> connect({
    required StreamChatIdentity identity,
    required Future<String> Function(String userId) tokenProvider,
  });

  Future<void> disconnect({required bool flushLocalPersistence});

  Future<void> dispose();
}

/// Keeps the SDK user aligned with LOOP's authenticated app principal.
///
/// [principalKey] is used only to detect logout and account switches. It must
/// never be used as, or transformed into, the Stream user ID; that identity is
/// owned by [StreamChatSessionSource].
abstract interface class StreamChatSessionLifecycle {
  Future<void> synchronizePrincipal(String? principalKey);
}

/// Official Stream Chat 10.3.0 implementation with token-provider refresh.
final class StreamChatSdkClientPort implements StreamChatClientPort {
  StreamChatSdkClientPort(this.client);

  final StreamChatClient client;

  @override
  String? get connectedUserId => client.state.currentUser?.id;

  @override
  Future<void> connect({
    required StreamChatIdentity identity,
    required Future<String> Function(String userId) tokenProvider,
  }) async {
    await client.connectUserWithProvider(
      User(
        id: identity.userId,
        name: _nonEmpty(identity.displayName),
        image: _nonEmpty(identity.imageUrl),
      ),
      tokenProvider,
    );
  }

  @override
  Future<void> disconnect({required bool flushLocalPersistence}) {
    return client.disconnectUser(flushChatPersistence: flushLocalPersistence);
  }

  @override
  Future<void> dispose() => client.dispose();

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}

/// Owns one official client, its per-user persistence, and authorization.
///
/// Construction performs no provider request and opens no Stream connection.
/// The SDK connects only when [StreamChatSdkSessionAuthorizer.authorize] gets a
/// server-derived identity and a short-lived token provider.
final class StreamChatSdkSession {
  StreamChatSdkSession._({required this.client, required this.authorizer});

  factory StreamChatSdkSession.create({
    required String apiKey,
    required StreamChatSessionSource source,
    String? principalKey,
  }) {
    if (apiKey.isEmpty || apiKey != apiKey.trim()) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must be non-empty');
    }

    final client = StreamChatClient(apiKey, logLevel: Level.OFF);
    client.chatPersistenceClient = StreamChatPersistenceClient(
      connectionMode: ConnectionMode.background,
      logLevel: Level.OFF,
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: StreamChatSdkClientPort(client),
      source: source,
      initialPrincipalKey: principalKey,
    );
    return StreamChatSdkSession._(client: client, authorizer: authorizer);
  }

  final StreamChatClient client;
  final StreamChatSdkSessionAuthorizer authorizer;

  Future<void> dispose() => authorizer.dispose();
}

/// Establishes the official SDK session before a production bridge operation.
///
/// Authorization is single-flight, retires on a different principal, preserves
/// persistence without flushing, and fails closed on missing provider inputs.
final class StreamChatSdkSessionAuthorizer
    implements StreamSessionAuthorizer, StreamChatSessionLifecycle {
  factory StreamChatSdkSessionAuthorizer({
    required StreamChatClientPort client,
    required StreamChatSessionSource source,
    String? initialPrincipalKey,
  }) {
    final principalKey = _normalizePrincipal(initialPrincipalKey);
    return StreamChatSdkSessionAuthorizer._(client, source, principalKey);
  }

  StreamChatSdkSessionAuthorizer._(
    this._client,
    this._source,
    this._principalKey,
  ) : _boundPrincipalKey = _principalKey;

  final StreamChatClientPort _client;
  final StreamChatSessionSource _source;

  Future<void> _lifecycleTail = Future<void>.value();
  Future<StreamSessionAuthorization>? _authorization;
  int? _authorizationGeneration;
  Completer<void> _generationInvalidated = Completer<void>();
  Future<void>? _disposeOperation;
  String? _boundPrincipalKey;
  String? _principalKey;
  String? _streamUserId;
  var _generation = 0;
  bool _disposed = false;

  @override
  Future<StreamSessionAuthorization> authorize() {
    final generation = _generation;
    if (_disposed || _principalKey == null) {
      return Future<StreamSessionAuthorization>.value(
        StreamSessionAuthorization.unavailable,
      );
    }

    final active = _authorization;
    if (active != null) {
      if (_authorizationGeneration == generation) {
        return active;
      }

      // Generation invalidation makes stale identity/token I/O unwind. A retry
      // for this same bound principal waits for its SDK cleanup so two Stream
      // connections can never race on this client.
      return _authorizeAfterStaleOperation(active, generation);
    }

    final invalidated = _generationInvalidated.future;
    late final Future<StreamSessionAuthorization> operation;
    operation = _enqueue(() => _authorize(generation, invalidated))
        .whenComplete(() {
          if (identical(_authorization, operation)) {
            _authorization = null;
            _authorizationGeneration = null;
          }
        });
    _authorization = operation;
    _authorizationGeneration = generation;
    return operation;
  }

  Future<StreamSessionAuthorization> _authorizeAfterStaleOperation(
    Future<StreamSessionAuthorization> staleOperation,
    int generation,
  ) async {
    try {
      await staleOperation;
    } catch (_) {
      // Authorization is fail-closed; a stale error cannot authorize anyone.
    }
    if (!_isCurrent(generation)) {
      return StreamSessionAuthorization.unavailable;
    }
    return authorize();
  }

  Future<StreamSessionAuthorization> _authorize(
    int generation,
    Future<void> invalidated,
  ) async {
    if (!_isCurrent(generation)) {
      return StreamSessionAuthorization.unavailable;
    }

    StreamChatIdentity? identity;
    try {
      identity = await _untilInvalidated(
        _source.loadIdentity(),
        generation: generation,
        invalidated: invalidated,
      );
    } catch (_) {
      return StreamSessionAuthorization.unavailable;
    }

    if (!_isCurrent(generation)) {
      return StreamSessionAuthorization.unavailable;
    }
    if (identity == null || !identity.isValid) {
      await _disconnectConnectedUser();
      return StreamSessionAuthorization.unavailable;
    }

    final streamUserId = _streamUserId;
    if (streamUserId != null && streamUserId != identity.userId) {
      await _disconnectIgnoringFailure();
      return StreamSessionAuthorization.unavailable;
    }

    if (_client.connectedUserId == identity.userId) {
      _streamUserId ??= identity.userId;
      return StreamSessionAuthorization.authorized;
    }

    if (_client.connectedUserId != null) {
      final disconnected = await _disconnectConnectedUser();
      if (!disconnected) return StreamSessionAuthorization.unavailable;
      if (!_isCurrent(generation)) {
        return StreamSessionAuthorization.unavailable;
      }
    }

    try {
      final rawConnection = _client.connect(
        identity: identity,
        tokenProvider: (requestedUserId) async {
          if (!_isCurrent(generation)) {
            throw StateError('The LOOP session changed during authorization.');
          }
          if (requestedUserId != identity!.userId) {
            throw StateError('Stream requested a different user token.');
          }
          final token = await _untilInvalidated(
            _source.loadToken(requestedUserId),
            generation: generation,
            invalidated: invalidated,
          );
          if (!_isCurrent(generation)) {
            throw StateError('The LOOP session changed during token refresh.');
          }
          if (token.isEmpty || token != token.trim()) {
            throw StateError('Stream token is unavailable.');
          }
          return token;
        },
      );
      // Stream initialization is not fully cancellable. If its raw Future
      // finishes after logout, retirement, or disposal, disconnect the old
      // client again so it cannot remain online or keep persistence open.
      unawaited(_reapRetiredConnection(rawConnection, generation));
      await _untilInvalidated(
        rawConnection,
        generation: generation,
        invalidated: invalidated,
      );
    } catch (_) {
      // This cleanup is part of the stale operation. Any same-bound retry waits
      // for it, even if the SDK's original websocket Future never completes
      // after disconnect. A different principal uses a separate client.
      await _disconnectIgnoringFailure();
      return StreamSessionAuthorization.unavailable;
    }

    if (!_isCurrent(generation) || _client.connectedUserId != identity.userId) {
      await _disconnectIgnoringFailure();
      return StreamSessionAuthorization.unavailable;
    }
    _streamUserId = identity.userId;
    return StreamSessionAuthorization.authorized;
  }

  Future<void> _reapRetiredConnection(
    Future<void> rawConnection,
    int generation,
  ) async {
    try {
      await rawConnection;
    } catch (_) {
      // A failed retired attempt still needs cleanup if it touched SDK state.
    }
    if (!_isCurrent(generation)) {
      await _disconnectIgnoringFailure();
    }
  }

  @override
  Future<void> synchronizePrincipal(String? principalKey) {
    final normalized = _normalizePrincipal(principalKey);
    if (_disposed) {
      return Future<void>.value();
    }

    final boundPrincipalKey = _boundPrincipalKey;
    if (boundPrincipalKey != null && normalized != boundPrincipalKey) {
      // A Stream client/persistence pair is principal-bound. The provider must
      // rotate the whole session for logout or another account; reusing this
      // instance could let abandoned initialization affect a later session.
      return dispose();
    }
    _boundPrincipalKey ??= normalized;
    if (normalized == _principalKey) return Future<void>.value();

    // Invalidating the generation happens synchronously, before any in-flight
    // connection can resume and report itself as authorized.
    final previousPrincipal = _principalKey;
    _principalKey = normalized;
    _invalidateGeneration();
    if (previousPrincipal == null && normalized != null) {
      return Future<void>.value();
    }
    // Cleanup deliberately bypasses the authorization queue. A backend
    // identity/token request is external I/O and may never return; logout and
    // account switching must still attempt to close the old SDK user now.
    return _disconnectIgnoringFailure();
  }

  /// Retires this principal-bound client without deleting offline history.
  Future<void> clearSession() => dispose();

  Future<bool> _disconnectConnectedUser() async {
    if (_client.connectedUserId == null) return true;
    try {
      await _client.disconnect(flushLocalPersistence: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _disconnectIgnoringFailure() async {
    try {
      await _client.disconnect(flushLocalPersistence: false);
    } catch (_) {
      // Authorization still fails closed; cleanup failure is never success.
    }
  }

  bool _isCurrent(int generation) {
    return !_disposed && _principalKey != null && generation == _generation;
  }

  Future<T> _untilInvalidated<T>(
    Future<T> operation, {
    required int generation,
    required Future<void> invalidated,
  }) {
    if (!_isCurrent(generation)) {
      return Future<T>.error(const _StreamSessionGenerationInvalidated());
    }
    return Future.any(<Future<T>>[
      operation,
      invalidated.then<T>(
        (_) => throw const _StreamSessionGenerationInvalidated(),
      ),
    ]);
  }

  void _invalidateGeneration() {
    _generation += 1;
    final invalidated = _generationInvalidated;
    _generationInvalidated = Completer<void>();
    if (!invalidated.isCompleted) invalidated.complete();
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final ready = _lifecycleTail.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    final result = ready.then((_) => operation());
    _lifecycleTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static String? _normalizePrincipal(String? principalKey) {
    if (principalKey == null ||
        principalKey.isEmpty ||
        principalKey != principalKey.trim()) {
      return null;
    }
    return principalKey;
  }

  Future<void> dispose() {
    final activeDispose = _disposeOperation;
    if (activeDispose != null) return activeDispose;
    _disposed = true;
    _principalKey = null;
    _invalidateGeneration();
    // Disposal also bypasses potentially stuck authorization I/O.
    final operation = _client.dispose();
    _disposeOperation = operation;
    return operation;
  }
}

final class _StreamSessionGenerationInvalidated implements Exception {
  const _StreamSessionGenerationInvalidated();
}
