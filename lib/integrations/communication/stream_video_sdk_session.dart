import 'dart:async';

import 'package:stream_video_flutter/stream_video_flutter.dart';

/// Server-owned Stream identity returned by the future LOOP bootstrap.
///
/// [userId] is derived by the backend from LOOP's immutable internal user ID.
/// Flutter never derives it from a Privy DID, email, or wallet address.
final class StreamVideoIdentity {
  const StreamVideoIdentity({
    required this.userId,
    this.displayName,
    this.imageUrl,
  });

  final String userId;
  final String? displayName;
  final String? imageUrl;

  bool get isValid => userId.isNotEmpty && userId == userId.trim();
}

/// Narrow frontend contract for backend-owned Video identity and tokens.
///
/// An implementation may obtain a current Privy access token internally, but
/// Stream tokens never cross into widgets or application persistence.
abstract interface class StreamVideoSessionSource {
  Future<StreamVideoIdentity?> loadIdentity();

  Future<String> loadToken(String userId);
}

enum StreamVideoSessionAuthorization { authorized, unavailable }

/// Testable lifecycle surface around a principal-bound Stream Video client.
abstract interface class StreamVideoClientPort {
  String get userId;

  Future<bool> connect();

  Future<void> disconnect();

  Future<void> dispose();
}

abstract interface class StreamVideoClientFactory {
  StreamVideoClientPort create({
    required String apiKey,
    required StreamVideoIdentity identity,
    required String initialToken,
    required Future<String> Function(String userId) tokenProvider,
  });
}

/// Official Stream Video 1.4.3 client factory.
///
/// `autoConnect: false` is deliberate: construction may initialize local SDK
/// machinery and consume [initialToken], but it must not call the backend token
/// loader or open a provider connection.
final class StreamVideoSdkClientFactory implements StreamVideoClientFactory {
  const StreamVideoSdkClientFactory();

  @override
  StreamVideoClientPort create({
    required String apiKey,
    required StreamVideoIdentity identity,
    required String initialToken,
    required Future<String> Function(String userId) tokenProvider,
  }) {
    final client = StreamVideo.create(
      apiKey,
      user: User.regular(
        userId: identity.userId,
        name: _nonEmpty(identity.displayName),
        image: _nonEmpty(identity.imageUrl),
      ),
      userToken: initialToken,
      tokenLoader: tokenProvider,
      options: StreamVideoOptions(
        autoConnect: false,
        logPriority: Priority.none,
      ),
    );
    return StreamVideoSdkClientPort(client);
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }
}

final class StreamVideoSdkClientPort implements StreamVideoClientPort {
  StreamVideoSdkClientPort(this.client);

  final StreamVideo client;

  @override
  String get userId => client.currentUser.id;

  @override
  Future<bool> connect() async {
    final result = await client.connect(registerPushDevice: false);
    return result.isSuccess;
  }

  @override
  Future<void> disconnect() async {
    for (final call in List<Call>.of(client.activeCalls)) {
      try {
        await call.leave();
      } catch (_) {
        // Continue retiring the remaining calls and client transport.
      }
    }
    await client.disconnect();
  }

  @override
  Future<void> dispose() => client.dispose();
}

/// Delays official SDK construction until a verified principal has a valid
/// backend-derived Stream identity, then connects through the backend token
/// loader. Each instance is permanently bound to at most one principal.
final class StreamVideoSdkSession {
  factory StreamVideoSdkSession({
    required String apiKey,
    required StreamVideoSessionSource source,
    StreamVideoClientFactory clientFactory =
        const StreamVideoSdkClientFactory(),
    String? initialPrincipalKey,
  }) {
    return StreamVideoSdkSession._(
      _validateApiKey(apiKey),
      source,
      clientFactory,
      _normalizePrincipal(initialPrincipalKey),
    );
  }

  StreamVideoSdkSession._(
    this._apiKey,
    this._source,
    this._clientFactory,
    this._principalKey,
  ) : _boundPrincipalKey = _principalKey;

  final String _apiKey;
  final StreamVideoSessionSource _source;
  final StreamVideoClientFactory _clientFactory;

  Future<StreamVideoSessionAuthorization>? _authorization;
  int? _authorizationGeneration;
  Completer<void> _generationInvalidated = Completer<void>();
  Future<void>? _disposeOperation;
  Future<void> _lifecycleTail = Future<void>.value();
  final Map<StreamVideoClientPort, Future<void>> _retirements =
      Map<StreamVideoClientPort, Future<void>>.identity();
  StreamVideoClientPort? _client;
  StreamVideoIdentity? _identity;
  String? _boundPrincipalKey;
  String? _principalKey;
  var _generation = 0;
  var _authorized = false;
  var _disposed = false;

  StreamVideoIdentity? get identity => _authorized ? _identity : null;

  /// The official client remains inside the communication/calls boundary.
  StreamVideo? get officialClient {
    final client = _client;
    if (!_authorized || client is! StreamVideoSdkClientPort) return null;
    return client.client;
  }

  Future<StreamVideoSessionAuthorization> authorize() {
    final generation = _generation;
    if (_disposed || _principalKey == null) {
      return Future<StreamVideoSessionAuthorization>.value(
        StreamVideoSessionAuthorization.unavailable,
      );
    }
    if (_authorized && _client != null) {
      return Future<StreamVideoSessionAuthorization>.value(
        StreamVideoSessionAuthorization.authorized,
      );
    }

    final active = _authorization;
    if (active != null) {
      if (_authorizationGeneration == generation) return active;
      return _authorizeAfterStaleOperation(active, generation);
    }

    final invalidated = _generationInvalidated.future;
    late final Future<StreamVideoSessionAuthorization> operation;
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

  Future<StreamVideoSessionAuthorization> _authorizeAfterStaleOperation(
    Future<StreamVideoSessionAuthorization> staleOperation,
    int generation,
  ) async {
    try {
      await staleOperation;
    } catch (_) {
      // A stale error can never authorize the current principal.
    }
    if (!_isCurrent(generation)) {
      return StreamVideoSessionAuthorization.unavailable;
    }
    return authorize();
  }

  Future<StreamVideoSessionAuthorization> _authorize(
    int generation,
    Future<void> invalidated,
  ) async {
    if (!_isCurrent(generation)) {
      return StreamVideoSessionAuthorization.unavailable;
    }

    StreamVideoIdentity? identity;
    try {
      identity = await _untilInvalidated(
        _source.loadIdentity(),
        generation: generation,
        invalidated: invalidated,
      );
    } catch (_) {
      return StreamVideoSessionAuthorization.unavailable;
    }
    if (!_isCurrent(generation) || identity == null || !identity.isValid) {
      return StreamVideoSessionAuthorization.unavailable;
    }

    final existingIdentity = _identity;
    if (existingIdentity != null &&
        existingIdentity.userId != identity.userId) {
      await _retireClient();
      return StreamVideoSessionAuthorization.unavailable;
    }

    String initialToken;
    try {
      initialToken = await _untilInvalidated(
        _source.loadToken(identity.userId),
        generation: generation,
        invalidated: invalidated,
      );
    } catch (_) {
      return StreamVideoSessionAuthorization.unavailable;
    }
    if (!_isCurrent(generation) ||
        initialToken.isEmpty ||
        initialToken != initialToken.trim()) {
      return StreamVideoSessionAuthorization.unavailable;
    }

    StreamVideoClientPort client;
    try {
      client = _clientFactory.create(
        apiKey: _apiKey,
        identity: identity,
        initialToken: initialToken,
        tokenProvider: (requestedUserId) async {
          if (!_isCurrent(generation)) {
            throw StateError('The LOOP session changed during Video auth.');
          }
          if (requestedUserId != identity!.userId) {
            throw StateError('Stream requested a different Video user token.');
          }
          final token = await _untilInvalidated(
            _source.loadToken(requestedUserId),
            generation: generation,
            invalidated: invalidated,
          );
          if (!_isCurrent(generation) ||
              token.isEmpty ||
              token != token.trim()) {
            throw StateError('Stream Video token is unavailable.');
          }
          return token;
        },
      );
    } catch (_) {
      return StreamVideoSessionAuthorization.unavailable;
    }

    if (!_isCurrent(generation) || client.userId != identity.userId) {
      await _retireSpecificClient(client);
      return StreamVideoSessionAuthorization.unavailable;
    }
    _client = client;
    _identity = identity;

    Future<bool> rawConnection;
    try {
      rawConnection = client.connect();
    } catch (_) {
      await _retireClient();
      return StreamVideoSessionAuthorization.unavailable;
    }
    unawaited(_reapRetiredConnection(rawConnection, client, generation));
    bool connected;
    try {
      connected = await _untilInvalidated(
        rawConnection,
        generation: generation,
        invalidated: invalidated,
      );
    } catch (_) {
      await _retireClient();
      return StreamVideoSessionAuthorization.unavailable;
    }

    if (!connected || !_isCurrent(generation) || !identical(_client, client)) {
      await _retireClient();
      return StreamVideoSessionAuthorization.unavailable;
    }
    _authorized = true;
    return StreamVideoSessionAuthorization.authorized;
  }

  Future<void> _reapRetiredConnection(
    Future<bool> rawConnection,
    StreamVideoClientPort client,
    int generation,
  ) async {
    try {
      await rawConnection;
    } catch (_) {
      // Failed and late connections still need retirement.
    }
    if (!_isCurrent(generation) || !identical(_client, client)) {
      final retirement = _retirements[client];
      if (retirement != null) {
        try {
          await retirement;
        } catch (_) {
          // A failed first retirement still requires one final disconnect.
        }
      }
      try {
        await client.disconnect();
      } catch (_) {
        // The client is retired and unreachable even if final reaping fails.
      }
    }
  }

  Future<void> synchronizePrincipal(String? principalKey) {
    final normalized = _normalizePrincipal(principalKey);
    if (_disposed) return Future<void>.value();

    final boundPrincipalKey = _boundPrincipalKey;
    if (boundPrincipalKey != null && normalized != boundPrincipalKey) {
      return dispose();
    }
    _boundPrincipalKey ??= normalized;
    if (normalized == _principalKey) return Future<void>.value();

    _principalKey = normalized;
    _invalidateGeneration();
    return _retireClient();
  }

  Future<void> _retireClient() {
    _authorized = false;
    _identity = null;
    final client = _client;
    _client = null;
    if (client == null) return Future<void>.value();
    return _retireSpecificClient(client);
  }

  Future<void> _retireSpecificClient(StreamVideoClientPort client) {
    final active = _retirements[client];
    if (active != null) return active;
    late final Future<void> operation;
    operation = _disposeSpecificClient(client).whenComplete(() {
      if (identical(_retirements[client], operation)) {
        _retirements.remove(client);
      }
    });
    _retirements[client] = operation;
    return operation;
  }

  Future<void> _disposeSpecificClient(StreamVideoClientPort client) async {
    try {
      await client.disconnect();
    } catch (_) {
      // Retirement remains fail-closed even if transport cleanup fails.
    }
    try {
      await client.dispose();
    } catch (_) {
      // The retired client is no longer reachable from this session.
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
      return Future<T>.error(const _StreamVideoGenerationInvalidated());
    }
    return Future.any(<Future<T>>[
      operation,
      invalidated.then<T>(
        (_) => throw const _StreamVideoGenerationInvalidated(),
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

  Future<void> dispose() {
    final active = _disposeOperation;
    if (active != null) return active;
    _disposed = true;
    _principalKey = null;
    _invalidateGeneration();
    final operation = _retireClient();
    _disposeOperation = operation;
    return operation;
  }

  static String _validateApiKey(String apiKey) {
    if (apiKey.isEmpty || apiKey != apiKey.trim()) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must be non-empty');
    }
    return apiKey;
  }

  static String? _normalizePrincipal(String? principalKey) {
    if (principalKey == null ||
        principalKey.isEmpty ||
        principalKey != principalKey.trim()) {
      return null;
    }
    return principalKey;
  }
}

final class _StreamVideoGenerationInvalidated implements Exception {
  const _StreamVideoGenerationInvalidated();
}
