import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/account/onboarding_communities.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_live_voice_rooms.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// Strict codec for `GET /v2/communities/recommended` (S107 §4).
///
/// Each item is the community summary every directory row carries (with its
/// `memberCount` and `boundAssetKey`). `defaultSelectedIds` must name items
/// of the same answer, at most five, each once.
abstract final class LoopV2RecommendedCommunitiesCodec {
  static const rootKeys = <String>{
    'items',
    'defaultSelectedIds',
    'contractVersion',
  };
  static const maximumItems = 50;
  static const maximumDefaults = 5;

  static RecommendedCommunities decode(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, rootKeys);
    LoopV2ProjectionCodec.requireContractVersion(root);
    final items = <CommunitySummary>[
      for (final item in LoopV2ProjectionCodec.requireList(
        root['items'],
        maximum: maximumItems,
      ))
        LoopV2ProjectionCodec.community(item),
    ];
    final ids = <String>{for (final item in items) item.communityId};
    if (ids.length != items.length) LoopV2ProjectionCodec.invalid();
    final defaults = LoopV2ProjectionCodec.requireList(
      root['defaultSelectedIds'],
      maximum: maximumDefaults,
    );
    final selected = <String>[];
    for (final value in defaults) {
      if (value is! String ||
          !ids.contains(value) ||
          selected.contains(value)) {
        LoopV2ProjectionCodec.invalid();
      }
      selected.add(value);
    }
    return RecommendedCommunities(
      items: List<CommunitySummary>.unmodifiable(items),
      defaultSelectedIds: List<String>.unmodifiable(selected),
    );
  }
}

final class DioLoopV2RecommendedCommunitiesApi {
  DioLoopV2RecommendedCommunitiesApi(this._dio);

  static const path = '/v2/communities/recommended';

  final Dio _dio;

  Future<RecommendedCommunities> load({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2RecommendedCommunitiesCodec.decode(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.readErrors,
      );
    }
  }
}

/// `404` (route not served yet) and `503` (closed) are both unavailable —
/// the page then offers 跳过 and nothing else, never a made-up list.
final class DioLoopV2RecommendedCommunitiesGateway
    implements RecommendedCommunitiesGateway {
  DioLoopV2RecommendedCommunitiesGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2RecommendedCommunitiesApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<RecommendedCommunities> load() async {
    try {
      return await _session.execute(
        (accessToken) => _api.load(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
        ),
      );
    } on LoopBackendFailure catch (failure) {
      throw CommunityGatewayException(
        liveVoiceRoomFailureKind(failure),
        reasonCode: failure.detailsSafe?.reasonCode,
      );
    } on CommunityGatewayException {
      rethrow;
    } catch (_) {
      throw const CommunityGatewayException(CommunityFailureKind.unexpected);
    }
  }
}

final loopV2RecommendedCommunitiesGatewayProvider =
    Provider<RecommendedCommunitiesGateway>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final session = ref.watch(loopAuthenticatedSessionProvider);
      if (dio == null || metadata == null || session == null) {
        return const UnavailableRecommendedCommunitiesGateway();
      }
      return DioLoopV2RecommendedCommunitiesGateway(
        api: DioLoopV2RecommendedCommunitiesApi(dio),
        clientMetadata: metadata,
        session: session,
      );
    });
