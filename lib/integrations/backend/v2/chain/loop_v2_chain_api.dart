import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the `chain` module (loop-api decision 0033).
///
/// Reads only. Every response is parsed against the frozen key set, so an
/// unknown field is an invalid payload rather than a partially trusted view.
abstract interface class LoopV2ChainApi {
  Future<LoopChainStatus> getStatus({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopChainAssetView> getAsset({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  });
}

final class DioLoopV2ChainApi implements LoopV2ChainApi {
  DioLoopV2ChainApi(this._dio);

  static const statusPath = '/v2/chain/status';
  static const assetsPath = '/v2/assets';

  final Dio _dio;

  static String _requireAssetId(String value) {
    if (!LoopV2ChainCodec.assetIdPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  @override
  Future<LoopChainStatus> getStatus({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        statusPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMapWithOptional(
        response.data,
        const <String>{
          'chain',
          'rpc',
          'indexer',
          'registry',
          'contractVersion',
        },
        // Present only while the Launch chain slot differs from the primary
        // chain (decision 0038). Absent is the ordinary case and means "the
        // Launch module runs on the primary chain".
        const <String>{'launchChain'},
      );
      LoopV2ChainCodec.requireContractVersion(root);

      final chain = LoopV2Contract.strictMap(root['chain'], const <String>{
        'chainId',
        'name',
        'reference',
        'nativeAssetId',
        'confirmations',
        'reorgDepthBlocks',
      });
      final rpc = LoopV2Contract.strictMap(root['rpc'], const <String>{
        'status',
        'reasonCode',
        'verification',
        'head',
        'endpoints',
      });
      final registry = LoopV2Contract.strictMap(
        root['registry'],
        const <String>{'readableAssetCount', 'registeredPoolCount'},
      );

      final rawStatus = rpc['status'];
      if (rawStatus != 'available' && rawStatus != 'unavailable') {
        LoopV2ChainCodec.invalid();
      }
      final verification = LoopV2ChainCodec.requireVerification(
        rpc,
        'verification',
      );

      LoopChainHead? head;
      if (rpc['head'] != null) {
        final headMap = LoopV2Contract.strictMap(rpc['head'], const <String>{
          'blockNumber',
          'blockHash',
          'observedAt',
        });
        head = LoopChainHead(
          blockNumber: LoopV2ChainCodec.requireBlockNumber(
            headMap,
            'blockNumber',
          ),
          blockHash: LoopV2ChainCodec.requireString(
            headMap,
            'blockHash',
            pattern: LoopV2ChainCodec.hashPattern,
            maxLength: 66,
          ),
          observedAt: LoopV2ChainCodec.requireTimestamp(headMap, 'observedAt'),
        );
      }

      final endpoints = <LoopRpcEndpointHealth>[];
      final seenRefs = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        rpc['endpoints'],
        maximum: 16,
      )) {
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'endpointRef',
          'status',
          'latencyMs',
          'blockNumber',
          'blockLagBlocks',
          'chainVerification',
          'observedAt',
        });
        final rawEndpointStatus = map['status'];
        if (rawEndpointStatus is! String) LoopV2ChainCodec.invalid();
        final endpointStatus = LoopEndpointStatus.tryParse(rawEndpointStatus);
        if (endpointStatus == null) LoopV2ChainCodec.invalid();
        final endpointRef = LoopV2ChainCodec.requireString(
          map,
          'endpointRef',
          pattern: LoopV2ChainCodec.endpointRefPattern,
          maxLength: 16,
        );
        if (!seenRefs.add(endpointRef)) LoopV2ChainCodec.invalid();
        endpoints.add(
          LoopRpcEndpointHealth(
            endpointRef: endpointRef,
            status: endpointStatus,
            latencyMs: LoopV2ChainCodec.optionalInt(
              map,
              'latencyMs',
              minimum: 0,
            ),
            blockNumber: LoopV2ChainCodec.optionalBlockNumber(
              map,
              'blockNumber',
            ),
            blockLagBlocks: LoopV2ChainCodec.optionalInt(map, 'blockLagBlocks'),
            chainVerification: LoopV2ChainCodec.requireVerification(
              map,
              'chainVerification',
            ),
            observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
          ),
        );
      }

      final lanes = <LoopIndexerLaneStatus>[];
      final seenLanes = <LoopIndexerLane>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['indexer'],
        maximum: 8,
      )) {
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'lane',
          'status',
          'reasonCode',
          'lastBlockNumber',
          'lastBlockHash',
          'lagBlocks',
          'reorgCount',
          'updatedAt',
        });
        final rawLane = map['lane'];
        if (rawLane is! String) LoopV2ChainCodec.invalid();
        final lane = LoopIndexerLane.tryParse(rawLane);
        if (lane == null || !seenLanes.add(lane)) LoopV2ChainCodec.invalid();
        final laneStatus = map['status'];
        if (laneStatus != 'available' && laneStatus != 'unavailable') {
          LoopV2ChainCodec.invalid();
        }
        lanes.add(
          LoopIndexerLaneStatus(
            lane: lane,
            available: laneStatus == 'available',
            reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
            lastBlockNumber: LoopV2ChainCodec.optionalBlockNumber(
              map,
              'lastBlockNumber',
            ),
            lastBlockHash: LoopV2ChainCodec.optionalString(
              map,
              'lastBlockHash',
              pattern: LoopV2ChainCodec.hashPattern,
              maxLength: 66,
            ),
            lagBlocks: LoopV2ChainCodec.optionalInt(map, 'lagBlocks'),
            reorgCount: LoopV2ChainCodec.optionalInt(
              map,
              'reorgCount',
              minimum: 0,
            ),
            updatedAt: LoopV2ChainCodec.optionalTimestamp(map, 'updatedAt'),
          ),
        );
      }

      // The primary chain must stay `eip155:56`: `chain`, `rpc`, `indexer` and
      // `registry` never describe anything else, whatever the Launch slot is.
      if (chain['chainId'] != loopPrimaryChainId) LoopV2ChainCodec.invalid();
      final launchChain = LoopV2ChainCodec.optionalLaunchChain(
        root,
        'launchChain',
      );

      return LoopChainStatus(
        chain: LoopChainInfo(
          chainId: LoopV2ChainCodec.requireKnownChainId(chain, 'chainId'),
          name: LoopV2ChainCodec.requireText(chain, 'name', maxLength: 64),
          reference: LoopV2ChainCodec.requireInt(
            chain,
            'reference',
            minimum: 1,
          ),
          nativeAssetId: LoopV2ChainCodec.requireAssetId(
            chain,
            'nativeAssetId',
          ),
          confirmations: LoopV2ChainCodec.requireInt(
            chain,
            'confirmations',
            minimum: 1,
          ),
          reorgDepthBlocks: LoopV2ChainCodec.requireInt(
            chain,
            'reorgDepthBlocks',
            minimum: 1,
          ),
        ),
        rpc: LoopRpcHealth(
          available: rawStatus == 'available',
          reasonCode: LoopV2ChainCodec.optionalReasonCode(rpc, 'reasonCode'),
          verification: verification,
          head: head,
          endpoints: List<LoopRpcEndpointHealth>.unmodifiable(endpoints),
        ),
        indexer: List<LoopIndexerLaneStatus>.unmodifiable(lanes),
        registry: LoopRegistryCounts(
          readableAssetCount: LoopV2ChainCodec.requireInt(
            registry,
            'readableAssetCount',
          ),
          registeredPoolCount: LoopV2ChainCodec.requireInt(
            registry,
            'registeredPoolCount',
          ),
        ),
        launchChain: launchChain,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopChainAssetView> getAsset({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$assetsPath/${Uri.encodeComponent(_requireAssetId(assetId))}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'asset',
        'capability',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      return LoopChainAssetView(
        asset: LoopV2ChainCodec.chainAsset(root['asset']),
        capability: LoopV2ChainCodec.assetCapability(root['capability']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }
}
