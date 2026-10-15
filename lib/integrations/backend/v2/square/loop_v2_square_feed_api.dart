import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';

/// Lenient decoder for the square timeline (decision 0177, loop-api 0143).
///
/// The envelope must be a page (an `items` list and an `observedAt`); a
/// `scope` other than the one asked for, or a cursor of the wrong shape, is
/// an invalid payload. Inside it a post that cannot be read is dropped rather
/// than refusing the page, keys the client does not know are ignored, and a
/// figure that does not parse reads as not reported (`null`), never as zero.
abstract final class LoopV2SquareFeedCodec {
  static final RegExp _idPattern = RegExp(r'^[\x21-\x7e]{1,128}$');
  static final RegExp _loopIdPattern = RegExp(r'^[\x21-\x7e]{1,64}$');
  static final RegExp _avatarRefPattern = RegExp(
    r'^avatar:(media|preset)/[A-Za-z0-9._-]{1,128}$',
  );

  /// Generous bound on a post's text in UTF-16 units: the server's limit is
  /// 500 code points, which may take up to 1000 units.
  static const int _textUnitsMax = 1000;

  static SquareFeedPage page(
    Object? raw, {
    required SquareFeedScope scope,
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = _map(raw);
    if (root == null) LoopV2ChainCodec.invalid();
    final wireScope = root['scope'];
    if (wireScope != null && wireScope != scope.wireName) {
      LoopV2ChainCodec.invalid();
    }
    final rawItems = root['items'];
    if (rawItems is! List) LoopV2ChainCodec.invalid();
    final observedAt = LoopV2ChainCodec.requireTimestamp(root, 'observedAt');
    final nextCursor = LoopV2ChainCodec.cursor(root, 'nextCursor');
    final pinned = <SquareFeedPost>[];
    final rest = <SquareFeedPost>[];
    final seen = <String>{};
    for (final item in rawItems.take(60)) {
      final read = post(item, mediaUrl: mediaUrl);
      if (read == null || !seen.add(read.postId)) continue;
      (read.pinned ? pinned : rest).add(read);
    }
    return SquareFeedPage(
      scope: scope,
      // The server lists the pinned official posts first; a page that did not
      // still draws them on top.
      items: <SquareFeedPost>[...pinned.take(3), ...rest],
      nextCursor: nextCursor,
      observedAt: observedAt,
    );
  }

  /// One post, or `null` when it cannot be read.
  static SquareFeedPost? post(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    try {
      final row = _map(raw);
      if (row == null) return null;
      final postId = row['postId'];
      if (postId is! String || !LoopV2Contract.uuidPattern.hasMatch(postId)) {
        return null;
      }
      final kind = SquareFeedPostKind.tryParse(row['kind']);
      if (kind == null) return null;
      final author = _author(row['author']);
      if (author == null && kind != SquareFeedPostKind.system) return null;
      String? text;
      if (kind == SquareFeedPostKind.opinion ||
          kind == SquareFeedPostKind.system) {
        text = _text(row['text']);
        if (text == null) return null;
      }
      final likeCount = row['likeCount'];
      final liked = row['likedByViewer'];
      if (likeCount is! int || likeCount < 0 || liked is! bool) return null;
      final createdAt = LoopV2ChainCodec.requireTimestamp(row, 'createdAt');
      return SquareFeedPost(
        postId: postId,
        kind: kind,
        author: kind == SquareFeedPostKind.system ? null : author,
        text: text,
        token: _token(row['token'], mediaUrl: mediaUrl),
        event: _event(row['event']),
        likeCount: likeCount,
        likedByViewer: liked,
        // Only LOOP's own posts can be pinned.
        pinned: kind == SquareFeedPostKind.system && row['pinned'] == true,
        createdAt: createdAt,
      );
    } on Object {
      return null;
    }
  }

  static SquareFeedLike like(Object? raw, {required String postId}) {
    final root = _map(raw);
    if (root == null || root['postId'] != postId) LoopV2ChainCodec.invalid();
    final count = root['likeCount'];
    final liked = root['likedByViewer'];
    if (count is! int || count < 0 || liked is! bool) {
      LoopV2ChainCodec.invalid();
    }
    return SquareFeedLike(
      postId: postId,
      likeCount: count,
      likedByViewer: liked,
    );
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is! Map) return null;
    return <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  static SquareFeedAuthor? _author(Object? raw) {
    final author = _map(raw);
    if (author == null) return null;
    final id = author['publicProfileId'];
    final loopId = author['loopId'];
    if (id is! String || !_idPattern.hasMatch(id)) return null;
    if (loopId is! String || !_loopIdPattern.hasMatch(loopId)) return null;
    final avatar = author['avatarRef'];
    return SquareFeedAuthor(
      publicProfileId: id,
      loopId: loopId,
      alias: _displayText(author['alias'], 64),
      avatarRef: avatar is String && _avatarRefPattern.hasMatch(avatar)
          ? avatar
          : null,
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty || normalized.length > _textUnitsMax) return null;
    return normalized;
  }

  static String? _displayText(Object? value, int maxLength) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > maxLength ||
        !LoopV2ChainCodec.displayTextPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  static SquareFeedToken? _token(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final token = _map(raw);
    if (token == null) return null;
    final kind = SquareFeedTokenKind.tryParse(token['kind']);
    final symbol = _displayText(token['symbol'], 32);
    if (kind == null || symbol == null) return null;
    final memeTokenId = _uuid(token['memeTokenId']);
    final instanceId = _uuid(token['instanceId']);
    // The id that names the token must be there; the quote is about it.
    if (kind == SquareFeedTokenKind.meme && memeTokenId == null) return null;
    if (kind == SquareFeedTokenKind.launch2 && instanceId == null) return null;
    return SquareFeedToken(
      kind: kind,
      memeTokenId: kind == SquareFeedTokenKind.meme ? memeTokenId : null,
      instanceId: kind == SquareFeedTokenKind.launch2 ? instanceId : null,
      symbol: symbol,
      logoUrl: _logo(token['logoUrl'], mediaUrl: mediaUrl),
      priceUsd1: _decimal(token['priceUsd1'], signed: false),
      change1hPct: _decimal(token['change1hPct'], signed: true),
      marketCapUsd1: _decimal(token['marketCapUsd1'], signed: false),
    );
  }

  static String? _uuid(Object? value) =>
      value is String && LoopV2Contract.uuidPattern.hasMatch(value)
      ? value
      : null;

  static Decimal? _decimal(Object? value, {required bool signed}) {
    if (value is! String || value.length > 160) return null;
    final pattern = signed
        ? LoopV2ChainCodec.signedDecimalPattern
        : LoopV2ChainCodec.unsignedDecimalPattern;
    if (!pattern.hasMatch(value)) return null;
    return Decimal.tryParse(value);
  }

  static Map<String, String> _event(Object? raw) {
    final event = _map(raw);
    if (event == null) return const <String, String>{};
    return <String, String>{
      for (final entry in event.entries.take(16))
        if (entry.value case final String value
            when value.isNotEmpty && value.length <= 200)
          entry.key: value,
    };
  }

  /// Only LOOP's own media path is loaded, and from this build's backend
  /// origin, never from the host the payload named.
  static String? _logo(
    Object? value, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    if (value is! String || value.length > 2048) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final mediaId = LoopV2MemeCodec.mediaPathPattern
        .firstMatch(uri.path)
        ?.group(1);
    return mediaId == null ? null : mediaUrl(mediaId);
  }
}

/// The square routes over the session's Dio client.
final class DioLoopV2SquareFeedApi {
  DioLoopV2SquareFeedApi(this._dio, {required this.mediaUrl});

  static const feedPath = '/v2/square/feed';
  static const postsPath = '/v2/square/posts';

  /// The write catalogue as OpenAPI lists it for the square commands: the
  /// rate limit and the activation precondition are refusals, not payloads.
  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'PROFILE_ACTIVATION_REQUIRED',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;
  final String? Function(String mediaId) mediaUrl;

  Future<SquareFeedPage> getFeed({
    required String accessToken,
    required String clientVersion,
    required SquareFeedScope scope,
    String? cursor,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        feedPath,
        queryParameters: <String, Object?>{
          'scope': scope.wireName,
          'cursor': ?cursor,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2SquareFeedCodec.page(
        response.data,
        scope: scope,
        mediaUrl: mediaUrl,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }

  Future<SquareFeedPost> createPost({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String text,
    SquareFeedTokenRef? tokenRef,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        postsPath,
        data: <String, Object?>{
          'text': text,
          if (tokenRef != null)
            'tokenRef': <String, Object?>{
              'kind': tokenRef.kind.wireName,
              'id': tokenRef.id,
            },
        },
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      // 201 for the first write, 200 for a replay of the same key and text.
      final status = response.statusCode == 200 ? 200 : 201;
      LoopV2Contract.validateSuccess(response, statusCode: status);
      final root = response.data;
      final post = root is Map
          ? LoopV2SquareFeedCodec.post(root['post'], mediaUrl: mediaUrl)
          : null;
      if (post == null) LoopV2ChainCodec.invalid();
      return post;
    } on DioException catch (error) {
      throw _refusal(error);
    }
  }

  Future<void> deletePost({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String postId,
  }) async {
    try {
      final response = await _dio.delete<Object?>(
        '$postsPath/${_requireId(postId)}',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 204);
    } on DioException catch (error) {
      throw _refusal(error);
    }
  }

  Future<SquareFeedLike> setLike({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String postId,
    required bool liked,
  }) async {
    final path = '$postsPath/${_requireId(postId)}/like';
    final options = LoopV2ModuleRequest.writeOptions(
      accessToken,
      clientVersion,
      idempotencyKey,
    );
    try {
      final response = liked
          ? await _dio.put<Object?>(path, options: options)
          : await _dio.delete<Object?>(path, options: options);
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2SquareFeedCodec.like(response.data, postId: postId);
    } on DioException catch (error) {
      throw _refusal(error);
    }
  }

  static String _requireId(String postId) {
    if (!LoopV2Contract.uuidPattern.hasMatch(postId)) {
      throw const LoopChainException(LoopChainFailureKind.notFound);
    }
    return postId;
  }

  /// `409 PROFILE_ACTIVATION_REQUIRED` has no feature kind of its own; it is
  /// carried as its rule so the composer can say what to do.
  static Object _refusal(DioException error) {
    final failure = LoopV2Contract.mapDioFailure(
      error,
      allowedCodes: writeErrors,
    );
    if (failure.code == 'PROFILE_ACTIVATION_REQUIRED') {
      return const LoopChainException(
        LoopChainFailureKind.permissionDenied,
        reasonCode: 'PROFILE_ACTIVATION_REQUIRED',
      );
    }
    return failure;
  }
}

final class DioLoopV2SquareFeedGateway implements SquareFeedGateway {
  DioLoopV2SquareFeedGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    String Function()? newIdempotencyKey,
  }) : _newKey = newIdempotencyKey ?? squareFeedIdempotencyKey;

  final DioLoopV2SquareFeedApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final String Function() _newKey;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) =>
      executeChainRequest(
        _session,
        (accessToken) => _api.getFeed(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          scope: scope,
          cursor: cursor,
        ),
        write: false,
      );

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) => executeChainRequest(
    _session,
    (accessToken) => _api.createPost(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
      idempotencyKey: idempotencyKey,
      text: text,
      tokenRef: tokenRef,
    ),
    write: true,
  );

  @override
  Future<void> deletePost(String postId) {
    // Deleting twice is answered 204 again, so one key per attempt is safe.
    final key = _newKey();
    return executeChainRequest(
      _session,
      (accessToken) => _api.deletePost(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        idempotencyKey: key,
        postId: postId,
      ),
      write: true,
    );
  }

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) {
    // The like itself is the dedupe on the server; the key is required and
    // never reused across taps.
    final key = _newKey();
    return executeChainRequest(
      _session,
      (accessToken) => _api.setLike(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        idempotencyKey: key,
        postId: postId,
        liked: liked,
      ),
      write: true,
    );
  }
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or session keeps the port at its unavailable default.
final loopV2SquareFeedGatewayProvider = Provider<SquareFeedGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailableSquareFeedGateway();
  }
  final resolver = ref.watch(loopV2MediaUrlResolverProvider);
  return DioLoopV2SquareFeedGateway(
    api: DioLoopV2SquareFeedApi(dio, mediaUrl: resolver.urlFor),
    clientMetadata: metadata,
    session: session,
  );
});
