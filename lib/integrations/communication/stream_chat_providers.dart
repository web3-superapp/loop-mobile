import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_repository.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

final loopStreamChatTokenRepositoryProvider =
    Provider<LoopStreamTokenRepository?>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      final apiKey = ref.watch(
        appConfigProvider.select((config) => config.streamApiKey.trim()),
      );
      if (dio == null || !DioLoopStreamTokenRepository.isValidApiKey(apiKey)) {
        return null;
      }
      return DioLoopStreamTokenRepository(dio, expectedApiKey: apiKey);
    });

final streamChatSessionSourceProvider = Provider<StreamChatSessionSource>((
  ref,
) {
  final source = _LoopBackendStreamChatSessionSource(
    bootstrapSession: ref.watch(loopBootstrapSessionProvider),
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
    repository: ref.watch(loopStreamChatTokenRepositoryProvider),
    expectedApiKey: ref.watch(
      appConfigProvider.select((config) => config.streamApiKey.trim()),
    ),
  );
  ref.onDispose(source.dispose);
  return source;
});

/// Opaque account-rotation key; never a Stream user ID.
final streamChatPrincipalKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) {
      if (!session.canUseProviderBackedFeatures) return null;
      return session.account?.privyUserId;
    }),
  );
});

/// One active, principal-bound Stream Chat client per application ProviderScope.
///
/// Client construction attaches persistence but performs no provider request.
/// A principal change rebuilds this provider so abandoned SDK initialization
/// can mutate only its retired client/persistence pair, never the next user's.
/// The client is absent when the public API key is absent (for example in the
/// explicit offline preview composition root).
final streamChatSdkSessionProvider = Provider<StreamChatSdkSession?>((ref) {
  final apiKey = ref.watch(
    appConfigProvider.select((config) => config.streamApiKey.trim()),
  );
  if (apiKey.isEmpty) return null;
  final principalKey = ref.watch(streamChatPrincipalKeyProvider);

  final session = StreamChatSdkSession.create(
    apiKey: apiKey,
    source: ref.watch(streamChatSessionSourceProvider),
    principalKey: principalKey,
  );
  ref.onDispose(() => unawaited(_disposeSessionSafely(session)));
  return session;
});

/// Authorizes the SDK only for a fully verified Privy session.
///
/// Authenticated-unverified and preview sessions explicitly clear any Stream
/// user while retaining that user's local offline history.
final streamChatAuthorizationProvider =
    FutureProvider.autoDispose<StreamSessionAuthorization>((ref) async {
      final principalKey = ref.watch(streamChatPrincipalKeyProvider);
      final streamSession = ref.watch(streamChatSdkSessionProvider);
      if (streamSession == null) {
        return StreamSessionAuthorization.unavailable;
      }
      await streamSession.authorizer.synchronizePrincipal(principalKey);
      if (principalKey == null) {
        return StreamSessionAuthorization.unavailable;
      }
      return streamSession.authorizer.authorize();
    });

Future<void> _disposeSessionSafely(StreamChatSdkSession session) async {
  try {
    await session.dispose();
  } catch (_) {
    // The retired instance remains unreachable; disposal cannot authorize it.
  }
}

final class _LoopBackendStreamChatSessionSource
    implements StreamChatSessionSource {
  _LoopBackendStreamChatSessionSource({
    required this._bootstrapSession,
    required this._accessTokens,
    required this._repository,
    required this._expectedApiKey,
  });

  final LoopBootstrapSession? _bootstrapSession;
  final LoopBackendAccessTokenSource _accessTokens;
  final LoopStreamTokenRepository? _repository;
  final String _expectedApiKey;
  final _LoopStreamChatInvalidationSignal _invalidation =
      _LoopStreamChatInvalidationSignal();

  Future<String>? _tokenOperation;
  String? _tokenUserId;
  var _disposed = false;

  @override
  Future<StreamChatIdentity?> loadIdentity() async {
    final session = _bootstrapSession;
    if (_disposed || session == null) return null;
    final authorization = await _completeOnlyWhileActive(session.authorize());
    if (authorization != LoopBootstrapAuthorization.authorized) {
      return null;
    }
    final identity = session.identity;
    if (identity == null) return null;
    return StreamChatIdentity(userId: identity.streamUserId);
  }

  @override
  Future<String> loadToken(String userId) {
    if (_disposed) {
      return Future<String>.error(
        const LoopBackendFailure(LoopBackendFailureKind.cancelled),
      );
    }
    final active = _tokenOperation;
    if (active != null) {
      if (_tokenUserId == userId) return active;
      return Future<String>.error(
        const LoopBackendFailure(LoopBackendFailureKind.invalidRequest),
      );
    }

    late final Future<String> operation;
    operation = _loadToken(userId).whenComplete(() {
      if (identical(_tokenOperation, operation)) {
        _tokenOperation = null;
        _tokenUserId = null;
      }
    });
    _tokenOperation = operation;
    _tokenUserId = userId;
    return operation;
  }

  Future<String> _loadToken(String requestedUserId) async {
    final session = _bootstrapSession;
    final repository = _repository;
    if (session == null || repository == null) {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        code: 'stream_token_contract_unavailable',
      );
    }

    await _authorizeAndRequireMatchingIdentity(session, requestedUserId);
    var accessToken = await _loadAccessToken();
    var retriedAuthentication = false;
    var retriedBootstrap = false;

    while (true) {
      try {
        _requireCachedMatchingIdentity(session, requestedUserId);
        final issued = await _completeOnlyWhileActive(
          repository.issueChatToken(accessToken: accessToken),
        );
        _requireCachedMatchingIdentity(session, requestedUserId);
        if (issued.apiKey != _expectedApiKey ||
            issued.userId != requestedUserId) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        return issued.token;
      } on LoopBackendFailure catch (failure) {
        if (!retriedAuthentication &&
            failure.kind == LoopBackendFailureKind.authentication &&
            failure.statusCode == 401) {
          retriedAuthentication = true;
          accessToken = await _loadAccessToken();
          continue;
        }
        if (failure.statusCode == 409 && failure.code == 'bootstrap_required') {
          session.invalidateAuthorization();
          if (retriedBootstrap) rethrow;
          retriedBootstrap = true;
          await _authorizeAndRequireMatchingIdentity(session, requestedUserId);
          accessToken = await _loadAccessToken();
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _authorizeAndRequireMatchingIdentity(
    LoopBootstrapSession session,
    String requestedUserId,
  ) async {
    final authorization = await _completeOnlyWhileActive(session.authorize());
    if (authorization != LoopBootstrapAuthorization.authorized) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
    _requireCachedMatchingIdentity(session, requestedUserId);
  }

  void _requireCachedMatchingIdentity(
    LoopBootstrapSession session,
    String requestedUserId,
  ) {
    if (_disposed || session.identity?.streamUserId != requestedUserId) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  Future<String> _loadAccessToken() async {
    try {
      final token = await _completeOnlyWhileActive(
        _accessTokens.loadAccessToken(),
      );
      if (token.isEmpty || token != token.trim()) {
        throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
      }
      return token;
    } on _LoopStreamChatSourceInvalidated {
      rethrow;
    } on LoopBackendFailure {
      rethrow;
    } catch (_) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  Future<T> _completeOnlyWhileActive<T>(Future<T> operation) {
    if (_disposed) {
      return Future<T>.error(const _LoopStreamChatSourceInvalidated());
    }
    return _raceWithLoopStreamChatInvalidation(operation, _invalidation);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _tokenOperation = null;
    _tokenUserId = null;
    _invalidation.invalidate();
  }
}

final class _LoopStreamChatSourceInvalidated implements Exception {
  const _LoopStreamChatSourceInvalidated();
}

final class _LoopStreamChatInvalidationSignal {
  final StreamController<void> _controller = StreamController<void>.broadcast(
    sync: true,
  );

  var _invalidated = false;

  bool get isInvalidated => _invalidated;

  Stream<void> get events => _controller.stream;

  void invalidate() {
    if (_invalidated) return;
    _invalidated = true;
    _controller.add(null);
    unawaited(_controller.close());
  }
}

Future<T> _raceWithLoopStreamChatInvalidation<T>(
  Future<T> operation,
  _LoopStreamChatInvalidationSignal invalidation,
) {
  if (invalidation.isInvalidated) {
    return Future<T>.error(const _LoopStreamChatSourceInvalidated());
  }

  final result = Completer<T>();
  var settled = false;
  late final StreamSubscription<void> subscription;
  subscription = invalidation.events.listen((_) {
    if (settled) return;
    settled = true;
    result.completeError(const _LoopStreamChatSourceInvalidated());
    unawaited(_cancelLoopStreamSubscription(subscription));
  });

  if (invalidation.isInvalidated) {
    settled = true;
    result.completeError(const _LoopStreamChatSourceInvalidated());
    unawaited(_cancelLoopStreamSubscription(subscription));
  }

  unawaited(
    operation.then<void>(
      (value) {
        if (settled) return;
        settled = true;
        unawaited(_cancelLoopStreamSubscription(subscription));
        if (invalidation.isInvalidated) {
          result.completeError(const _LoopStreamChatSourceInvalidated());
          return;
        }
        result.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (settled) return;
        settled = true;
        unawaited(_cancelLoopStreamSubscription(subscription));
        if (invalidation.isInvalidated) {
          result.completeError(const _LoopStreamChatSourceInvalidated());
          return;
        }
        result.completeError(error, stackTrace);
      },
    ),
  );
  return result.future;
}

Future<void> _cancelLoopStreamSubscription(
  StreamSubscription<void> subscription,
) async {
  try {
    await subscription.cancel();
  } catch (_) {
    // Cancellation only detaches a one-shot invalidation listener.
  }
}
