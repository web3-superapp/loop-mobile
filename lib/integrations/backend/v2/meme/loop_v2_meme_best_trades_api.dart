import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/meme/meme_best_trades.dart';
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
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_api.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';

/// Lenient decoder for `GET /v2/meme/best-trades` (decision 0176, loop-api
/// 0142).
///
/// The envelope must be the board (an `items` list and an `observedAt`);
/// anything else is an invalid payload and the strip is not drawn. Inside it
/// a row that cannot be read is dropped rather than refusing the board, and
/// keys the client does not know are ignored: the strip is a shortcut, never
/// a fact another page relies on.
abstract final class LoopV2MemeBestTradesCodec {
  static final RegExp _loopIdPattern = RegExp(r'^[\x21-\x7e]{1,64}$');
  static final RegExp _avatarRefPattern = RegExp(
    r'^avatar:(media|preset)/[A-Za-z0-9._-]{1,128}$',
  );

  static MemeBestTradesBoard board(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    if (raw is! Map) LoopV2ChainCodec.invalid();
    final root = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final window = root['window'];
    if (window != null && window != '7d') LoopV2ChainCodec.invalid();
    final rawItems = root['items'];
    if (rawItems is! List) LoopV2ChainCodec.invalid();
    final observedAt = LoopV2ChainCodec.requireTimestamp(root, 'observedAt');
    final items = <MemeBestTrade>[];
    final seen = <String>{};
    for (final item in rawItems) {
      final trade = _trade(item, mediaUrl: mediaUrl);
      if (trade == null) continue;
      // One card per (user, token): a repeated pair is a payload error the
      // strip absorbs by keeping the first.
      if (!seen.add('${trade.publicProfileId}:${trade.memeTokenId}')) continue;
      items.add(trade);
      if (items.length == MemeBestTradesBoard.limit) break;
    }
    items.sort((a, b) => a.rank.compareTo(b.rank));
    return MemeBestTradesBoard(items: items, observedAt: observedAt);
  }

  static MemeBestTrade? _trade(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    try {
      if (raw is! Map || raw['user'] is! Map || raw['token'] is! Map) {
        return null;
      }
      final row = Map<String, Object?>.from(raw);
      final user = Map<String, Object?>.from(raw['user'] as Map);
      final token = Map<String, Object?>.from(raw['token'] as Map);
      final rank = LoopV2ChainCodec.requireInt(row, 'rank', minimum: 1);
      final userId = user['userId'];
      if (userId is! String ||
          userId.isEmpty ||
          userId.length > 128 ||
          !_loopIdPattern.hasMatch(userId)) {
        return null;
      }
      final loopId = LoopV2ChainCodec.requireString(
        user,
        'loopId',
        pattern: _loopIdPattern,
        maxLength: 64,
      );
      final alias = _optionalDisplayText(user['alias']);
      final avatar = user['avatar'];
      final avatarRef = avatar is String && _avatarRefPattern.hasMatch(avatar)
          ? avatar
          : null;
      final memeTokenId = token['memeTokenId'];
      if (memeTokenId is! String ||
          !LoopV2Contract.uuidV4Pattern.hasMatch(memeTokenId)) {
        return null;
      }
      final symbol = LoopV2ChainCodec.requireSymbol(token, 'symbol');
      final realized = LoopV2ChainCodec.requireDecimal(row, 'realizedUsd1');
      if (realized.sign <= 0) return null;
      return MemeBestTrade(
        rank: rank,
        publicProfileId: userId,
        loopId: loopId,
        alias: alias,
        avatarRef: avatarRef,
        memeTokenId: memeTokenId,
        symbol: symbol,
        logoUrl: _logo(token['logoUrl'], mediaUrl: mediaUrl),
        realizedUsd1: realized,
      );
    } on Object {
      return null;
    }
  }

  static String? _optionalDisplayText(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 64 ||
        !LoopV2ChainCodec.displayTextPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  /// Only LOOP's own media path is loaded, and from this build's backend
  /// origin, never from the host the payload named.
  static String? _logo(
    Object? value, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    if (value is! String || value.length > 512) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final mediaId = LoopV2MemeCodec.mediaPathPattern
        .firstMatch(uri.path)
        ?.group(1);
    return mediaId == null ? null : mediaUrl(mediaId);
  }
}

/// `GET /v2/meme/best-trades?window=7d` over the session's Dio client.
final class DioLoopV2MemeBestTradesApi {
  DioLoopV2MemeBestTradesApi(this._dio, {required this.mediaUrl});

  static const path = '/v2/meme/best-trades';

  final Dio _dio;
  final String? Function(String mediaId) mediaUrl;

  Future<MemeBestTradesBoard> getWeekly({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: const <String, Object?>{'window': '7d'},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2MemeBestTradesCodec.board(response.data, mediaUrl: mediaUrl);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: DioLoopV2MemeApi.readErrors,
      );
    }
  }
}

final class DioLoopV2MemeBestTradesGateway implements MemeBestTradesGateway {
  DioLoopV2MemeBestTradesGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2MemeBestTradesApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MemeBestTradesBoard> loadWeekly() => executeChainRequest(
    _session,
    (accessToken) => _api.getWeekly(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
    write: false,
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or session keeps the port at its unavailable default.
final loopV2MemeBestTradesGatewayProvider = Provider<MemeBestTradesGateway>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailableMemeBestTradesGateway();
  }
  final resolver = ref.watch(loopV2MediaUrlResolverProvider);
  return DioLoopV2MemeBestTradesGateway(
    api: DioLoopV2MemeBestTradesApi(dio, mediaUrl: resolver.urlFor),
    clientMetadata: metadata,
    session: session,
  );
});
