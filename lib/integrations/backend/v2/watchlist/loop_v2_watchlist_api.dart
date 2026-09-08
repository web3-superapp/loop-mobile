import 'package:dio/dio.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the `watchlist` module.
///
/// The whole resource is replaced under `expectedVersion`. No `Idempotency-Key`
/// is ever sent: the server answers `400 INVALID_REQUEST` when one is present,
/// because the version is what makes the write safe to repeat.
abstract interface class LoopV2WatchlistApi {
  Future<WatchlistSnapshot> getWatchlist({
    required String accessToken,
    required String clientVersion,
  });

  Future<WatchlistSnapshot> putWatchlist({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required List<WatchlistGroup> groups,
    LoopV2WriteOrigin? origin,
  });
}

final class DioLoopV2WatchlistApi implements LoopV2WatchlistApi {
  DioLoopV2WatchlistApi(this._dio);

  static const watchlistPath = '/v2/watchlist';

  final Dio _dio;

  @override
  Future<WatchlistSnapshot> getWatchlist({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        watchlistPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _snapshot(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<WatchlistSnapshot> putWatchlist({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required List<WatchlistGroup> groups,
    LoopV2WriteOrigin? origin,
  }) async {
    if (expectedVersion < 0 || expectedVersion > watchlistMaximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (groups.length > watchlistMaxGroups) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    var total = 0;
    for (final group in groups) {
      total += group.items.length;
      if (!group.nameFitsWriteContract) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
      }
    }
    if (total > watchlistMaxItems) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        watchlistPath,
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'groups': <Object?>[
            for (final group in groups)
              <String, Object?>{
                'key': group.key,
                'name': group.name,
                'items': <Object?>[
                  for (final item in group.items)
                    <String, Object?>{'assetId': item.assetId},
                ],
              },
          ],
        },
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _snapshot(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  static WatchlistSnapshot _snapshot(Object? data) {
    final root = LoopV2Contract.strictMap(data, const <String>{
      'version',
      'updatedAt',
      'groups',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final groups = <WatchlistGroup>[];
    final seenKeys = <String>{};
    for (final raw in LoopV2ChainCodec.requireList(
      root['groups'],
      maximum: watchlistMaxGroups,
    )) {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'key',
        'name',
        'items',
      });
      final items = <WatchlistItem>[];
      final seenAssets = <String>{};
      for (final rawItem in LoopV2ChainCodec.requireList(
        map['items'],
        maximum: watchlistMaxItems,
      )) {
        final itemMap = LoopV2Contract.strictMap(rawItem, const <String>{
          'assetId',
          'asset',
          'reasonCode',
        });
        final assetId = LoopV2ChainCodec.requireAssetId(itemMap, 'assetId');
        if (!seenAssets.add(assetId)) LoopV2ChainCodec.invalid();
        final asset = LoopV2ChainCodec.assetSummary(itemMap['asset']);
        final reasonCode = LoopV2ChainCodec.optionalReasonCode(
          itemMap,
          'reasonCode',
        );
        // A row is either readable or explained; never both and never neither.
        if ((asset == null) != (reasonCode != null)) LoopV2ChainCodec.invalid();
        items.add(
          WatchlistItem(assetId: assetId, asset: asset, reasonCode: reasonCode),
        );
      }
      final key = LoopV2ChainCodec.requireString(
        map,
        'key',
        pattern: RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$'),
        maxLength: 32,
      );
      if (!seenKeys.add(key)) LoopV2ChainCodec.invalid();
      groups.add(
        WatchlistGroup(
          key: key,
          name: LoopV2ChainCodec.requireText(map, 'name', maxLength: 256),
          items: items,
        ),
      );
    }
    return WatchlistSnapshot(
      version: LoopV2ChainCodec.requireInt(root, 'version'),
      updatedAt: LoopV2ChainCodec.optionalTimestamp(root, 'updatedAt'),
      groups: groups,
    );
  }
}
