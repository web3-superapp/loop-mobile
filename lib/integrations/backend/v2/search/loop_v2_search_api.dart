import 'package:dio/dio.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict V2 transport for the `search` module.
abstract interface class LoopV2SearchApi {
  Future<SearchPage> search({
    required String accessToken,
    required String clientVersion,
    required SearchDomain domain,
    required String query,
    String? cursor,
  });
}

final class DioLoopV2SearchApi implements LoopV2SearchApi {
  DioLoopV2SearchApi(this._dio);

  static const searchPath = '/v2/search';

  /// Normalised prefix bounds enforced by the server; checked here so an
  /// obviously invalid query never leaves the device or spends the quota.
  static const minimumQueryRunes = 2;
  static const maximumQueryRunes = 40;

  final Dio _dio;

  final _controlCharacters = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
    unicode: true,
  );

  bool acceptsQuery(String query) {
    final trimmed = query.trim();
    final runes = trimmed.runes.length;
    return runes >= minimumQueryRunes &&
        runes <= maximumQueryRunes &&
        !_controlCharacters.hasMatch(trimmed);
  }

  @override
  Future<SearchPage> search({
    required String accessToken,
    required String clientVersion,
    required SearchDomain domain,
    required String query,
    String? cursor,
  }) async {
    final trimmed = query.trim();
    if (!acceptsQuery(trimmed)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
            !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        searchPath,
        queryParameters: <String, Object?>{
          'domain': domain.wireName,
          'q': trimmed,
          'cursor': ?cursor,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'domain',
        'status',
        'reasonCode',
        'results',
        'nextCursor',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      if (root['domain'] != domain.wireName) LoopV2ProjectionCodec.invalid();
      final status = root['status'];
      if (status != 'available' && status != 'unavailable') {
        LoopV2ProjectionCodec.invalid();
      }
      final available = status == 'available';
      final reasonCode = LoopV2ProjectionCodec.optionalPattern(
        root,
        'reasonCode',
        LoopV2Contract.reasonCodePattern,
      );
      if (available != (reasonCode == null)) LoopV2ProjectionCodec.invalid();
      final results = <SearchResult>[];
      for (final raw in LoopV2ProjectionCodec.requireList(
        root['results'],
        maximum: 20,
      )) {
        final item = LoopV2Contract.strictMap(raw, const <String>{
          'resultType',
          'stableId',
          'displaySnapshot',
          'destination',
        });
        final rawType = item['resultType'];
        if (rawType is! String) LoopV2ProjectionCodec.invalid();
        final resultType = SearchResultType.tryParse(rawType);
        if (resultType == null) LoopV2ProjectionCodec.invalid();
        final snapshot = LoopV2Contract.strictMap(
          item['displaySnapshot'],
          const <String>{
            'title',
            'subtitle',
            'avatarRef',
            // Required on every domain since backend decision 0072 (token
            // logos): the asset rows carry a logo projection and the user and
            // community rows carry `null`. This adapter admits the key so a
            // search page still reads; the projection itself, its host
            // allow-list and its monogram fallback belong to the token-logo
            // work, which owns every surface that draws one. Reading half of
            // it here would be a second, weaker copy of that rule.
            'logo',
            'memberCount',
            'verificationStatus',
          },
        );
        // `assetDetail` is the one destination that carries a parameter; the
        // other two must not carry one, so a row that tried to hand an
        // `assetId` to a profile destination is refused rather than opened.
        final destination = LoopV2Contract.strictMapWithOptional(
          item['destination'],
          const <String>{'kind'},
          const <String>{'assetId'},
        );
        final rawKind = destination['kind'];
        if (rawKind is! String) LoopV2ProjectionCodec.invalid();
        final rawAssetId = destination['assetId'];
        final SearchDestination target;
        switch (rawKind) {
          case SearchDestination.publicProfileKind:
            if (destination.containsKey('assetId')) {
              LoopV2ProjectionCodec.invalid();
            }
            target = const SearchPublicProfileDestination();
          case SearchDestination.communityProfileKind:
            if (destination.containsKey('assetId')) {
              LoopV2ProjectionCodec.invalid();
            }
            target = const SearchCommunityProfileDestination();
          case SearchDestination.assetDetailKind:
            if (rawAssetId is! String ||
                !MarketAssetRoute.isCanonical(rawAssetId)) {
              LoopV2ProjectionCodec.invalid();
            }
            target = SearchAssetDestination(rawAssetId);
          default:
            LoopV2ProjectionCodec.invalid();
        }
        final memberCount = snapshot['memberCount'];
        if (memberCount != null && (memberCount is! int || memberCount < 0)) {
          LoopV2ProjectionCodec.invalid();
        }
        final verification = snapshot['verificationStatus'];
        if (verification != null &&
            verification != 'pending' &&
            verification != 'verified' &&
            verification != 'rejected') {
          LoopV2ProjectionCodec.invalid();
        }
        // An account and a community are named by an opaque UUID; a registry
        // asset is named by its CAIP id, which is the registry's own stable
        // key (decision 0033). Both are server identities, and neither is a
        // display string.
        final stableId = item['stableId'];
        if (stableId is! String) LoopV2ProjectionCodec.invalid();
        final stableIdIsCanonical = resultType == SearchResultType.asset
            ? MarketAssetRoute.isCanonical(stableId)
            : LoopV2Contract.uuidPattern.hasMatch(stableId);
        if (!stableIdIsCanonical) LoopV2ProjectionCodec.invalid();
        results.add(
          SearchResult(
            resultType: resultType,
            stableId: stableId,
            title: LoopV2ProjectionCodec.requireText(snapshot, 'title'),
            subtitle: LoopV2ProjectionCodec.optionalText(snapshot, 'subtitle'),
            avatarRef: LoopV2ProjectionCodec.optionalPattern(
              snapshot,
              'avatarRef',
              LoopV2ProjectionCodec.avatarRefPattern,
            ),
            memberCount: memberCount as int?,
            verificationStatus: verification as String?,
            destination: target,
          ),
        );
      }
      if (!available && results.isNotEmpty) LoopV2ProjectionCodec.invalid();
      return SearchPage(
        domain: domain,
        available: available,
        reasonCode: reasonCode,
        results: List<SearchResult>.unmodifiable(results),
        nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.searchErrors,
      );
    }
  }
}
