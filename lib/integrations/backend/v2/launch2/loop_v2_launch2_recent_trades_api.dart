import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// `GET /v2/launch2/instances/{id}/pool/recent-trades` (loop-api decision
/// 0174 §B, client decision 0240).
///
/// The values are encoded as the curve's `recentTrades`, under other names
/// (`txHash`, `at`, `wallet`), so the codec is its own. The answer is a list
/// for display: the root must read (an object with this instance, the
/// contract version and an `items` list), but an item that does not read is
/// dropped rather than refusing the others, and an unknown key is ignored.
abstract final class LoopV2Launch2RecentTradesCodec {
  /// `0x` + 64 hex, any case on the wire (lower-cased here).
  static final RegExp _hash = RegExp(r'^0x[0-9a-fA-F]{64}$');

  /// The server's mask: `0x` + 4 hex + `…` + 4 hex, lower case.
  static final RegExp walletMaskPattern = RegExp(
    '^0x[0-9a-f]{4}…[0-9a-f]{4}\$',
  );

  /// The most items one answer is read for (the route allows 50).
  static const int itemLimit = 50;

  static Launch2PublicPoolTrades recentTrades(
    Object? raw, {
    required String instanceId,
  }) {
    if (raw is! Map) LoopV2ChainCodec.invalid();
    final root = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    LoopV2ChainCodec.requireContractVersion(root);
    if (root['instanceId'] != instanceId) LoopV2ChainCodec.invalid();
    final items = root['items'];
    if (items is! List) LoopV2ChainCodec.invalid();
    DateTime? observedAt;
    try {
      observedAt = LoopV2ChainCodec.optionalTimestamp(root, 'observedAt');
    } catch (_) {
      observedAt = null;
    }
    return Launch2PublicPoolTrades(
      instanceId: instanceId,
      items: List<Launch2PublicPoolTrade>.unmodifiable(<Launch2PublicPoolTrade>[
        for (final item in items.take(itemLimit))
          if (trade(item) case final Launch2PublicPoolTrade value) value,
      ]),
      observedAt: observedAt,
    );
  }

  /// One item, or `null` when any of its fields does not read.
  static Launch2PublicPoolTrade? trade(Object? raw) {
    if (raw is! Map) return null;
    final map = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final hash = map['txHash'];
    final block = map['blockNumber'];
    final side = map['side'];
    final parsedSide = side is String ? Launch2Side.tryParse(side) : null;
    final wallet = map['wallet'];
    final meme = LoopV2Launch2Codec.lenientAmount(map, 'memeAmount');
    final usd1 = LoopV2Launch2Codec.lenientAmount(map, 'usd1Amount');
    final price = LoopV2Launch2Codec.lenientAmount(map, 'priceUsd1');
    if (hash is! String ||
        !_hash.hasMatch(hash) ||
        block is! String ||
        !LoopV2Launch2Codec.integerPattern.hasMatch(block) ||
        parsedSide == null ||
        meme == null ||
        usd1 == null ||
        price == null ||
        !(wallet == null ||
            (wallet is String && walletMaskPattern.hasMatch(wallet)))) {
      return null;
    }
    final DateTime at;
    try {
      at = LoopV2ChainCodec.requireTimestamp(map, 'at');
    } catch (_) {
      return null;
    }
    return Launch2PublicPoolTrade(
      txHash: hash.toLowerCase(),
      blockNumber: BigInt.parse(block),
      at: at,
      side: parsedSide,
      memeAmount: meme,
      usd1Amount: usd1,
      priceUsd1: price,
      wallet: wallet as String?,
    );
  }
}

final class DioLoopV2Launch2RecentTradesApi {
  DioLoopV2Launch2RecentTradesApi(this._dio);

  final Dio _dio;

  /// The route answers `429 RATE_LIMITED` past its per-visitor ceiling and
  /// never `401` (it is public).
  static const errors = DioLoopV2Launch2Api.readErrors;

  static String path(String instanceId) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(instanceId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return '${DioLoopV2Launch2Api.instancesPath}/$instanceId'
        '/pool/recent-trades';
  }

  Future<Launch2PublicPoolTrades> getRecentTrades({
    required String accessToken,
    required String clientVersion,
    required String instanceId,
    required int limit,
  }) async {
    if (limit < 1 || limit > 50) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        path(instanceId),
        queryParameters: <String, Object?>{'limit': limit.toString()},
        // The V2 read headers the route requires; the Bearer it ignores.
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateCacheableSuccess(response, statusCode: 200);
      return LoopV2Launch2RecentTradesCodec.recentTrades(
        response.data,
        instanceId: instanceId,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: errors);
    }
  }
}

/// The V2 adapter behind [Launch2RecentPoolTradesGateway]. It rides the same
/// authenticated session as the rest of the project page (the route ignores
/// the Bearer), so it is open exactly when the page's other reads are.
final class DioLoopV2Launch2RecentTradesGateway
    implements Launch2RecentPoolTradesGateway {
  DioLoopV2Launch2RecentTradesGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2Launch2RecentTradesApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PublicPoolTrades> loadRecentPoolTrades(
    String instanceId, {
    int limit = launch2RecentPoolTradesLimit,
  }) => executeChainRequest(
    _session,
    (accessToken) => _api.getRecentTrades(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
      instanceId: instanceId,
      limit: limit,
    ),
    write: false,
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2Launch2RecentTradesApiProvider =
    Provider<DioLoopV2Launch2RecentTradesApi?>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      if (dio == null) return null;
      return DioLoopV2Launch2RecentTradesApi(dio);
    });

final loopV2Launch2RecentTradesGatewayProvider =
    Provider<Launch2RecentPoolTradesGateway>((ref) {
      final api = ref.watch(loopV2Launch2RecentTradesApiProvider);
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final session = ref.watch(loopAuthenticatedSessionProvider);
      if (api == null || metadata == null || session == null) {
        return const UnavailableLaunch2RecentPoolTradesGateway();
      }
      return DioLoopV2Launch2RecentTradesGateway(
        api: api,
        clientMetadata: metadata,
        session: session,
      );
    });
