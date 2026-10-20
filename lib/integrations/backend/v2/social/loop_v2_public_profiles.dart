import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_profile_communities.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';
import 'package:uuid/uuid.dart';

/// Strict codecs for the S107 §3 public-profile routes (decision 0112).
///
/// Every key is required and no other key is accepted. A section the server
/// marks `hidden` or `unavailable` carries no rows and no total: a payload
/// that says "hidden" and still lists holdings is refused, never half-shown.
abstract final class LoopV2PublicProfileCodec {
  static const profileKeys = <String>{
    'publicProfileId',
    'loopId',
    'alias',
    'avatarRef',
    'bio',
    'joinedAt',
    'counts',
    'relationship',
    'visibility',
    'contractVersion',
  };
  static const countKeys = <String>{'followers', 'following', 'communities'};
  static const relationshipKeys = <String>{
    'following',
    'followedBy',
    'friendship',
    'blocked',
    'blockedBy',
  };
  static const visibilityKeys = <String>{'holdings', 'trades'};
  static const holdingsKeys = <String>{
    'status',
    'reasonCode',
    'totalUsd',
    'items',
    'observedAt',
    'contractVersion',
  };
  static const holdingKeys = <String>{
    'assetId',
    'symbol',
    'name',
    'logoUrl',
    'balance',
    'usdValue',
  };
  static const tradesKeys = <String>{
    'status',
    'reasonCode',
    'items',
    'nextCursor',
    'contractVersion',
  };
  static const tradeKeys = <String>{
    'eventId',
    'kind',
    'assetId',
    'symbol',
    'amount',
    'usdValue',
    'blockTimestamp',
    'blockNumber',
    'txHash',
  };

  static final RegExp reasonCodePattern = RegExp(r'^[A-Z][A-Z0-9_]{0,63}$');
  static final RegExp blockNumberPattern = RegExp(r'^(0|[1-9][0-9]{0,19})$');

  static final RegExp eventIdPattern = RegExp(r'^[A-Za-z0-9:._-]{1,160}$');
  static const maximumItems = 200;

  static PublicProfileRecord profile(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, profileKeys);
    LoopV2ProjectionCodec.requireContractVersion(map);
    final counts = LoopV2Contract.strictMap(map['counts'], countKeys);
    final relationship = LoopV2Contract.strictMap(
      map['relationship'],
      relationshipKeys,
    );
    final visibility = LoopV2Contract.strictMap(
      map['visibility'],
      visibilityKeys,
    );
    final friendship = ProfileFriendship.tryParse(relationship['friendship']);
    if (friendship == null) LoopV2ProjectionCodec.invalid();
    final bio = LoopV2ProjectionCodec.optionalText(map, 'bio');
    if (bio != null && bio.runes.length > 160) LoopV2ProjectionCodec.invalid();
    final alias = LoopV2ProjectionCodec.optionalText(map, 'alias');
    if (alias != null && alias.runes.length > 40) {
      LoopV2ProjectionCodec.invalid();
    }
    return PublicProfileRecord(
      publicProfileId: LoopV2Contract.requiredString(
        map,
        'publicProfileId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      loopId: LoopV2Contract.requiredString(
        map,
        'loopId',
        pattern: LoopV2ProjectionCodec.loopIdPattern,
      ),
      alias: alias,
      avatarRef: LoopV2ProjectionCodec.optionalPattern(
        map,
        'avatarRef',
        LoopV2ProjectionCodec.avatarRefPattern,
      ),
      bio: bio,
      joinedAt: LoopV2ProjectionCodec.requireTimestamp(map, 'joinedAt'),
      counts: PublicProfileCounts(
        followers: LoopV2ProjectionCodec.requireCount(counts, 'followers'),
        following: LoopV2ProjectionCodec.requireCount(counts, 'following'),
        communities: LoopV2ProjectionCodec.requireCount(counts, 'communities'),
      ),
      relationship: PublicProfileRelationship(
        following: LoopV2ProjectionCodec.requireBool(relationship, 'following'),
        followedBy: LoopV2ProjectionCodec.requireBool(
          relationship,
          'followedBy',
        ),
        friendship: friendship,
        blocked: LoopV2ProjectionCodec.requireBool(relationship, 'blocked'),
        blockedBy: LoopV2ProjectionCodec.requireBool(relationship, 'blockedBy'),
      ),
      visibility: PublicProfileVisibility(
        holdings: LoopV2ProjectionCodec.requireBool(visibility, 'holdings'),
        trades: LoopV2ProjectionCodec.requireBool(visibility, 'trades'),
      ),
    );
  }

  /// Decision 0218 (loop-api S260): `launch2` is the one optional root key
  /// of `/holdings` and `/trades`; every other key stays exactly as before.
  static const launch2OptionalKeys = <String>{'launch2'};

  static const launch2HoldingKeys = <String>{
    'kind',
    'chainId',
    'instanceId',
    'ticker',
    'name',
    'logoUrl',
    'amountMeme',
    'nftCount',
    'stage',
    'valueUsd1',
  };

  /// The fourteen keys of a Launch-chain trade row: the wallet activity row
  /// of loop-api 0167 §C / client decision 0213, unchanged.
  static const launch2TradeKeys = <String>{
    'kind',
    'chainId',
    'instanceId',
    'ticker',
    'name',
    'logoUrl',
    'amountMeme',
    'amountUsd1',
    'taxUsd1',
    'transactionHash',
    'logIndex',
    'blockNumber',
    'occurredAt',
    'confirmations',
  };

  static String? _noMedia(String mediaId) => null;

  static ProfileHoldings holdings(
    Object? raw, {
    Uri? origin,
    String? Function(String mediaId) mediaUrl = _noMedia,
  }) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      holdingsKeys,
      launch2OptionalKeys,
    );
    LoopV2ProjectionCodec.requireContractVersion(map);
    final launch2 = map.containsKey('launch2')
        ? launch2Leg(map['launch2'])
        : null;
    final status = ProfileSectionStatus.tryParse(map['status']);
    if (status == null) LoopV2ProjectionCodec.invalid();
    final items = LoopV2ProjectionCodec.requireList(
      map['items'],
      maximum: maximumItems,
    );
    final totalUsd = _optionalDecimal(map, 'totalUsd');
    final observedAt = map['observedAt'] == null
        ? null
        : LoopV2ProjectionCodec.requireTimestamp(map, 'observedAt');
    if (status != ProfileSectionStatus.available &&
        (items.isNotEmpty || totalUsd != null)) {
      LoopV2ProjectionCodec.invalid();
    }
    if (status == ProfileSectionStatus.available && observedAt == null) {
      LoopV2ProjectionCodec.invalid();
    }
    final reasonCode = _reasonCode(map, status);
    final rows = <ProfileHoldingRow>[];
    final ids = <String>{};
    for (final item in items) {
      // A row with a `kind` key is a Launch-chain holding; a row without one
      // is the mainnet holding it always was. A kind this build does not
      // know is skipped, so a later kind never closes the section.
      if (item is Map && item.containsKey('kind')) {
        final kind = item['kind'];
        if (kind is! String) LoopV2ProjectionCodec.invalid();
        final parsed = ProfileLaunch2HoldingKind.tryParse(kind);
        if (parsed == null) continue;
        final row = launch2Holding(item, parsed, mediaUrl: mediaUrl);
        if (!ids.add(row.rowId)) LoopV2ProjectionCodec.invalid();
        rows.add(ProfileLaunch2HoldingRow(row));
        continue;
      }
      final row = holding(item, origin: origin);
      if (!ids.add(row.assetId)) LoopV2ProjectionCodec.invalid();
      rows.add(ProfileAssetHoldingRow(row));
    }
    return ProfileHoldings(
      status: status,
      totalUsd: totalUsd,
      rows: rows,
      observedAt: observedAt,
      reasonCode: reasonCode,
      launch2: launch2,
    );
  }

  /// The root `launch2` block: four keys when merged, two when not. The same
  /// two shapes as the wallet activity page (copied from
  /// `loop_v2_wallet_api.dart` `_launch2Leg`, decision 0213).
  static LoopWalletLaunch2Leg launch2Leg(Object? raw) {
    if (raw is! Map) LoopV2ProjectionCodec.invalid();
    switch (raw['status']) {
      case 'available':
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'status',
          'chainId',
          'indexerBlockNumber',
          'headBlockNumber',
        });
        return LoopWalletLaunch2Leg.available(
          chainId: LoopV2ChainCodec.requireString(
            map,
            'chainId',
            pattern: LoopV2ChainCodec.chainIdPattern,
            maxLength: 17,
          ),
          indexerBlockNumber: LoopV2ChainCodec.requireBlockNumber(
            map,
            'indexerBlockNumber',
          ),
          headBlockNumber: LoopV2ChainCodec.optionalBlockNumber(
            map,
            'headBlockNumber',
          ),
        );
      case 'unavailable':
        return LoopWalletLaunch2Leg.unavailable(
          LoopV2ChainCodec.unavailable(raw),
        );
      default:
        LoopV2ProjectionCodec.invalid();
    }
  }

  static Decimal? _optionalLaunch2Amount(
    Map<String, Object?> map,
    String key,
  ) => map[key] == null ? null : LoopV2Launch2Codec.amount(map, key);

  static String _launch2ChainId(Map<String, Object?> map) =>
      LoopV2ChainCodec.requireString(
        map,
        'chainId',
        pattern: LoopV2ChainCodec.chainIdPattern,
        maxLength: 17,
      );

  static String _launch2Ticker(Map<String, Object?> map) =>
      LoopV2ChainCodec.requireSymbol(map, 'ticker', maxLength: 160);

  static String _launch2Name(Map<String, Object?> map) =>
      LoopV2ChainCodec.providerText(map, 'name', minLength: 1, maxLength: 64);

  /// One Launch-chain holding: all ten keys, exactly. A MEME row states its
  /// amount, a medal row its count; a row that states neither is refused.
  static ProfileLaunch2Holding launch2Holding(
    Object? raw,
    ProfileLaunch2HoldingKind kind, {
    String? Function(String mediaId) mediaUrl = _noMedia,
  }) {
    final map = LoopV2Contract.strictMap(raw, launch2HoldingKeys);
    final rawStage = map['stage'];
    if (rawStage is! String || rawStage.isEmpty || rawStage.length > 32) {
      LoopV2ProjectionCodec.invalid();
    }
    final amountMeme = _optionalLaunch2Amount(map, 'amountMeme');
    final nftCount = LoopV2ChainCodec.optionalInt(map, 'nftCount', minimum: 0);
    switch (kind) {
      case ProfileLaunch2HoldingKind.meme:
        if (amountMeme == null) LoopV2ProjectionCodec.invalid();
      case ProfileLaunch2HoldingKind.nft:
        if (nftCount == null) LoopV2ProjectionCodec.invalid();
    }
    return ProfileLaunch2Holding(
      kind: kind,
      chainId: _launch2ChainId(map),
      instanceId: LoopV2Launch2Codec.uuid(map, 'instanceId'),
      ticker: _launch2Ticker(map),
      name: _launch2Name(map),
      logoUrl: LoopV2Launch2Codec.logoUrl(map, 'logoUrl', mediaUrl: mediaUrl),
      amountMeme: amountMeme,
      nftCount: nftCount,
      // A stage this build has no word for is not a broken row: the row
      // then names the chain alone.
      stage: Launch2Stage.tryParse(rawStage),
      valueUsd1: _optionalLaunch2Amount(map, 'valueUsd1'),
    );
  }

  /// One Launch-chain trade row: all fourteen keys, exactly. Copied from
  /// `loop_v2_wallet_api.dart` `_launch2Entry` (decision 0213) so the row is
  /// the wallet's own model.
  static LoopWalletLaunch2ActivityEntry launch2Trade(
    Object? raw,
    LoopWalletLaunch2ActivityKind kind, {
    String? Function(String mediaId) mediaUrl = _noMedia,
  }) {
    final map = LoopV2Contract.strictMap(raw, launch2TradeKeys);
    return LoopWalletLaunch2ActivityEntry(
      kind: kind,
      chainId: _launch2ChainId(map),
      instanceId: LoopV2Launch2Codec.uuid(map, 'instanceId'),
      ticker: _launch2Ticker(map),
      name: _launch2Name(map),
      logoUrl: LoopV2Launch2Codec.logoUrl(map, 'logoUrl', mediaUrl: mediaUrl),
      amountMeme: _optionalLaunch2Amount(map, 'amountMeme'),
      amountUsd1: _optionalLaunch2Amount(map, 'amountUsd1'),
      taxUsd1: _optionalLaunch2Amount(map, 'taxUsd1'),
      transactionHash: LoopV2ChainCodec.requireString(
        map,
        'transactionHash',
        pattern: LoopV2ChainCodec.hashPattern,
        maxLength: 66,
      ),
      logIndex: LoopV2ChainCodec.requireInt(map, 'logIndex'),
      blockNumber: LoopV2ChainCodec.requireBlockNumber(map, 'blockNumber'),
      occurredAt: LoopV2ChainCodec.requireTimestamp(map, 'occurredAt'),
      confirmations: LoopV2ChainCodec.optionalInt(
        map,
        'confirmations',
        minimum: 0,
      ),
    );
  }

  static ProfileHolding holding(Object? raw, {Uri? origin}) {
    final map = LoopV2Contract.strictMap(raw, holdingKeys);
    return ProfileHolding(
      assetId: LoopV2Contract.requiredString(
        map,
        'assetId',
        pattern: LoopV2ChainCodec.assetIdPattern,
      ),
      symbol: _symbol(map),
      name: LoopV2ProjectionCodec.requireText(map, 'name'),
      logoUrl: _logoUrl(map['logoUrl'], origin),
      balance: _decimal(map, 'balance'),
      usdValue: _optionalDecimal(map, 'usdValue'),
    );
  }

  static ProfileTradesPage trades(
    Object? raw, {
    String? Function(String mediaId) mediaUrl = _noMedia,
  }) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      tradesKeys,
      launch2OptionalKeys,
    );
    LoopV2ProjectionCodec.requireContractVersion(map);
    final launch2 = map.containsKey('launch2')
        ? launch2Leg(map['launch2'])
        : null;
    final status = ProfileSectionStatus.tryParse(map['status']);
    if (status == null) LoopV2ProjectionCodec.invalid();
    final items = LoopV2ProjectionCodec.requireList(
      map['items'],
      maximum: maximumItems,
    );
    final cursor = LoopV2ProjectionCodec.cursor(map, 'nextCursor');
    if (status != ProfileSectionStatus.available &&
        (items.isNotEmpty || cursor != null)) {
      LoopV2ProjectionCodec.invalid();
    }
    final reasonCode = _reasonCode(map, status);
    final rows = <ProfileTradeRow>[];
    final ids = <String>{};
    for (final item in items) {
      // The mainnet trade row has its own `kind` (buy / sell / transfer_*)
      // and always an `eventId`; the Launch-chain row has no `eventId`. So a
      // row with an `eventId` is decoded as it always was — an unknown kind
      // there is still a broken row — and any other row with a `kind` is a
      // Launch-chain fact, skipped when its kind is not one this build knows.
      if (item is Map &&
          !item.containsKey('eventId') &&
          item.containsKey('kind')) {
        final kind = item['kind'];
        if (kind is! String) LoopV2ProjectionCodec.invalid();
        final parsed = LoopWalletLaunch2ActivityKind.tryParse(kind);
        if (parsed == null) continue;
        final row = ProfileLaunch2TradeRow(
          launch2Trade(item, parsed, mediaUrl: mediaUrl),
        );
        if (!ids.add(row.rowId)) LoopV2ProjectionCodec.invalid();
        rows.add(row);
        continue;
      }
      final row = ProfileAssetTradeRow(trade(item));
      if (!ids.add(row.rowId)) LoopV2ProjectionCodec.invalid();
      rows.add(row);
    }
    return ProfileTradesPage(
      status: status,
      rows: rows,
      nextCursor: cursor,
      reasonCode: reasonCode,
      launch2: launch2,
    );
  }

  static ProfileTrade trade(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, tradeKeys);
    final kind = ProfileTradeKind.tryParse(map['kind']);
    if (kind == null) LoopV2ProjectionCodec.invalid();
    return ProfileTrade(
      eventId: LoopV2Contract.requiredString(
        map,
        'eventId',
        pattern: eventIdPattern,
      ),
      kind: kind,
      assetId: LoopV2Contract.requiredString(
        map,
        'assetId',
        pattern: LoopV2ChainCodec.assetIdPattern,
      ),
      symbol: _symbol(map),
      amount: _decimal(map, 'amount'),
      usdValue: _optionalDecimal(map, 'usdValue'),
      blockTimestamp: map['blockTimestamp'] == null
          ? null
          : LoopV2ProjectionCodec.requireTimestamp(map, 'blockTimestamp'),
      blockNumber: LoopV2Contract.requiredString(
        map,
        'blockNumber',
        pattern: blockNumberPattern,
      ),
      txHash: LoopV2Contract.requiredString(
        map,
        'txHash',
        pattern: LoopV2ChainCodec.hashPattern,
      ),
    );
  }

  /// `reasonCode` is present on every holdings/trades body and non-null only
  /// when the section is `unavailable` (backend decision 0095).
  static String? _reasonCode(
    Map<String, Object?> map,
    ProfileSectionStatus status,
  ) {
    final value = map['reasonCode'];
    if (value == null) return null;
    if (status != ProfileSectionStatus.unavailable ||
        value is! String ||
        !reasonCodePattern.hasMatch(value)) {
      LoopV2ProjectionCodec.invalid();
    }
    return value;
  }

  static String _symbol(Map<String, Object?> map) {
    return LoopV2ProjectionCodec.requireSymbol(map, 'symbol', maxLength: 32);
  }

  static Decimal _decimal(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String ||
        value.length > 120 ||
        !LoopV2ChainCodec.unsignedDecimalPattern.hasMatch(value)) {
      LoopV2ProjectionCodec.invalid();
    }
    return Decimal.parse(value);
  }

  static Decimal? _optionalDecimal(Map<String, Object?> map, String key) =>
      map[key] == null ? null : _decimal(map, key);

  /// A logo the client may fetch, or `null` (the monogram). An address it
  /// will not fetch is not a broken payload: the row simply has no picture.
  /// The backend's own image proxy may be named by its path alone.
  static String? _logoUrl(Object? raw, Uri? origin) {
    if (raw == null) return null;
    if (raw is! String || raw.length > 2048) LoopV2ProjectionCodec.invalid();
    var uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.hasScheme && origin != null) uri = origin.resolveUri(uri);
    return LoopV2ChainCodec.isAcceptedLogoUrl(uri) ? uri.toString() : null;
  }
}

/// Transport for the four routes. Reading the provider issues no request.
final class DioLoopV2PublicProfileApi {
  DioLoopV2PublicProfileApi(
    this._dio, {
    this._uuid = const Uuid(),
    String? Function(String mediaId)? mediaUrl,
  }) : _mediaUrl = mediaUrl ?? _noMedia;

  static String? _noMedia(String mediaId) => null;

  static const profilesPath = '/v2/profiles';
  static const byLoopIdPath = '/v2/profiles/by-loop-id';
  static const friendsPath = '/v2/friends';

  /// The read catalogue plus `404 PROFILE_NOT_FOUND` (S107 §3).
  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND', 'PROFILE_NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND', 'PROFILE_NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'PROFILE_ACTIVATION_REQUIRED',
      'VERSION_CONFLICT',
    },
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;
  final Uuid _uuid;

  /// Resolves this backend's own media path, so a Launch-chain logo served
  /// from it passes the logo rule (decision 0213 §4).
  final String? Function(String mediaId) _mediaUrl;

  Uri? get _origin => Uri.tryParse(_dio.options.baseUrl);

  Future<PublicProfileRecord> load({
    required String accessToken,
    required String clientVersion,
    required PublicProfileTarget target,
  }) async {
    final path = switch (target) {
      PublicProfileById(:final publicProfileId) =>
        '$profilesPath/${_uuidSegment(publicProfileId)}',
      PublicProfileByLoopId(:final loopId) =>
        '$byLoopIdPath/${_loopIdSegment(loopId)}',
    };
    try {
      final response = await _dio.get<Object?>(
        path,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2PublicProfileCodec.profile(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<ProfileHoldings> holdings({
    required String accessToken,
    required String clientVersion,
    required String publicProfileId,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        '$profilesPath/${_uuidSegment(publicProfileId)}/holdings',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2PublicProfileCodec.holdings(
        response.data,
        origin: _origin,
        mediaUrl: _mediaUrl,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<ProfileTradesPage> trades({
    required String accessToken,
    required String clientVersion,
    required String publicProfileId,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
            !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        '$profilesPath/${_uuidSegment(publicProfileId)}/trades',
        queryParameters: <String, Object?>{
          'cursor': ?cursor,
          if (cursor == null) 'limit': 20,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2PublicProfileCodec.trades(
        response.data,
        mediaUrl: _mediaUrl,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  /// `GET /v2/profiles/{id}/communities` (decision 0218, loop-api S260).
  Future<ProfileCommunitiesPage> communities({
    required String accessToken,
    required String clientVersion,
    required String publicProfileId,
    String? cursor,
  }) async {
    if (cursor != null &&
        (cursor.length < 3 ||
            cursor.length > LoopV2ProjectionCodec.maximumCursorLength ||
            !LoopV2ProjectionCodec.cursorPattern.hasMatch(cursor))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        '$profilesPath/${_uuidSegment(publicProfileId)}/communities',
        queryParameters: <String, Object?>{
          'cursor': ?cursor,
          if (cursor == null) 'limit': 20,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2ProfileCommunitiesCodec.page(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: readErrors);
    }
  }

  Future<void> removeFriend({
    required String accessToken,
    required String clientVersion,
    required String publicProfileId,
  }) async {
    try {
      final response = await _dio.delete<Object?>(
        '$friendsPath/${_uuidSegment(publicProfileId)}',
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          _uuid.v4(),
        ),
      );
      final status = response.statusCode;
      if (status != 200 && status != 204) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }

  static String _uuidSegment(String value) {
    if (!LoopV2Contract.uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static String _loopIdSegment(String value) {
    if (!LoopV2ProjectionCodec.loopIdPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }
}

/// How a public-profile failure reads to the page.
///
/// `404 PROFILE_NOT_FOUND` is the server saying "no such account for you";
/// any other `404` is a route this server does not serve yet, and `503` a
/// closed capability — both are "unavailable", never an empty profile.
CommunityFailureKind publicProfileFailureKind(
  LoopBackendFailure failure, {
  required bool write,
}) {
  final status = failure.statusCode;
  if (status == 404) {
    return failure.code == 'PROFILE_NOT_FOUND'
        ? CommunityFailureKind.notFound
        : CommunityFailureKind.unavailable;
  }
  if (status == 503) return CommunityFailureKind.unavailable;
  return communityFailureKindForV2(failure, write: write);
}

final class DioLoopV2PublicProfileGateway implements PublicProfileGateway {
  DioLoopV2PublicProfileGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2PublicProfileApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  Future<T> _run<T>(
    Future<T> Function(String accessToken) call, {
    bool write = false,
  }) async {
    try {
      return await _session.execute(call);
    } on LoopBackendFailure catch (failure) {
      throw CommunityGatewayException(
        publicProfileFailureKind(failure, write: write),
        reasonCode: failure.detailsSafe?.reasonCode,
      );
    } on CommunityGatewayException {
      rethrow;
    } catch (_) {
      throw const CommunityGatewayException(CommunityFailureKind.unexpected);
    }
  }

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) => _run(
    (token) => _api.load(
      accessToken: token,
      clientVersion: _clientMetadata.clientVersion,
      target: target,
    ),
  );

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) => _run(
    (token) => _api.holdings(
      accessToken: token,
      clientVersion: _clientMetadata.clientVersion,
      publicProfileId: publicProfileId,
    ),
  );

  @override
  Future<ProfileTradesPage> trades(String publicProfileId, {String? cursor}) =>
      _run(
        (token) => _api.trades(
          accessToken: token,
          clientVersion: _clientMetadata.clientVersion,
          publicProfileId: publicProfileId,
          cursor: cursor,
        ),
      );

  @override
  Future<ProfileCommunitiesPage> communities(
    String publicProfileId, {
    String? cursor,
  }) => _run(
    (token) => _api.communities(
      accessToken: token,
      clientVersion: _clientMetadata.clientVersion,
      publicProfileId: publicProfileId,
      cursor: cursor,
    ),
  );

  @override
  Future<void> removeFriend(String publicProfileId) => _run(
    (token) => _api.removeFriend(
      accessToken: token,
      clientVersion: _clientMetadata.clientVersion,
      publicProfileId: publicProfileId,
    ),
    write: true,
  );
}

final loopV2PublicProfileGatewayProvider = Provider<PublicProfileGateway>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailablePublicProfileGateway();
  }
  return DioLoopV2PublicProfileGateway(
    api: DioLoopV2PublicProfileApi(
      dio,
      mediaUrl: ref.watch(loopV2MediaUrlResolverProvider).urlFor,
    ),
    clientMetadata: metadata,
    session: session,
  );
});
