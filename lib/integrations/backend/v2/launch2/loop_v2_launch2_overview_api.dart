import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/media/loop_v2_media.dart';

/// `GET /v2/launch2/overview` (loop-api S181, client decision 0163 second
/// phase): the live tape and the platform figures.
///
/// The read is a display extra, so the codec is forgiving where the other
/// launch2 codecs are strict: an item it cannot read is dropped, a `stats`
/// object with any unreadable figure is `null`, and only a body that is not
/// an object at all is a failure. The surfaces draw nothing on a failure.
abstract final class LoopV2Launch2OverviewCodec {
  static final RegExp _address = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _hash = RegExp(r'^0x[0-9a-fA-F]{64}$');

  /// The most tape items read from one answer.
  static const int activityLimit = 50;

  static Launch2Overview overview(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    if (raw is! Map) LoopV2ChainCodec.invalid();
    final root = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final items = root['activity'];
    final activity = <Launch2Activity>[
      if (items is List)
        for (final item in items.take(activityLimit))
          if (_activity(item, mediaUrl) case final Launch2Activity value) value,
    ];
    DateTime? observedAt;
    try {
      observedAt = LoopV2ChainCodec.optionalTimestamp(root, 'observedAt');
    } catch (_) {
      observedAt = null;
    }
    return Launch2Overview(
      activity: List<Launch2Activity>.unmodifiable(activity),
      stats: _stats(root['stats']),
      observedAt: observedAt,
    );
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is! Map) return null;
    return <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  static Launch2Activity? _activity(
    Object? raw,
    String? Function(String mediaId) mediaUrl,
  ) {
    final map = _map(raw);
    if (map == null) return null;
    try {
      final kind = Launch2ActivityKind.tryParse(map['kind']);
      if (kind == null) return null;
      final ticker = map['ticker'];
      if (ticker is! String ||
          !LoopV2Launch2Codec.tickerPattern.hasMatch(ticker)) {
        return null;
      }
      final name = map['name'];
      final actor = map['actor'];
      final amount = map['amountUsd1'];
      final hash = map['transactionHash'];
      return Launch2Activity(
        kind: kind,
        instanceId: LoopV2Launch2Codec.uuid(map, 'instanceId'),
        ticker: ticker,
        name: name is String && name.runes.length <= 64
            ? LoopV2ChainCodec.sanitizeProviderText(name)
            : ticker,
        logoUrl: LoopV2Launch2Codec.logoUrl(map, 'logoUrl', mediaUrl: mediaUrl),
        actor: actor is String && _address.hasMatch(actor)
            ? actor.toLowerCase()
            : null,
        amountUsd1:
            amount is String &&
                LoopV2Launch2Codec.amountPattern.hasMatch(amount)
            ? Decimal.parse(amount)
            : null,
        at: LoopV2ChainCodec.requireTimestamp(map, 'at'),
        transactionHash: hash is String && _hash.hasMatch(hash)
            ? hash.toLowerCase()
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Launch2Stats? _stats(Object? raw) {
    final map = _map(raw);
    if (map == null) return null;
    int count(String key) {
      final value = map[key];
      if (value is int && value >= 0) return value;
      throw const FormatException('count');
    }

    try {
      final buyback = map['buybackUsd1Total'];
      if (buyback is! String ||
          !LoopV2Launch2Codec.amountPattern.hasMatch(buyback)) {
        return null;
      }
      return Launch2Stats(
        liveCount: count('liveCount'),
        mintingCount: count('mintingCount'),
        priorityCount: count('priorityCount'),
        curveCount: count('curveCount'),
        upcomingCount: count('upcomingCount'),
        graduatedTotal: count('graduatedTotal'),
        graduatedThisWeek: count('graduatedThisWeek'),
        buybackUsd1Total: Decimal.parse(buyback),
        nftMintedTotal: count('nftMintedTotal'),
      );
    } catch (_) {
      return null;
    }
  }
}

final class DioLoopV2Launch2OverviewApi {
  DioLoopV2Launch2OverviewApi(this._dio, {required this.mediaUrl});

  static const overviewPath = '/v2/launch2/overview';

  final Dio _dio;
  final String? Function(String mediaId) mediaUrl;

  Future<Launch2Overview> getOverview({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        overviewPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2Launch2OverviewCodec.overview(
        response.data,
        mediaUrl: mediaUrl,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: DioLoopV2Launch2Api.readErrors,
      );
    }
  }
}

/// The authenticated adapter behind [Launch2OverviewGateway].
final class DioLoopV2Launch2OverviewGateway implements Launch2OverviewGateway {
  DioLoopV2Launch2OverviewGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2Launch2OverviewApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Overview> loadOverview() => executeChainRequest(
    _session,
    (accessToken) => _api.getOverview(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
    write: false,
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2Launch2OverviewApiProvider = Provider<DioLoopV2Launch2OverviewApi?>(
  (ref) {
    final dio = ref.watch(loopBackendDioProvider);
    if (dio == null) return null;
    final resolver = ref.watch(loopV2MediaUrlResolverProvider);
    return DioLoopV2Launch2OverviewApi(dio, mediaUrl: resolver.urlFor);
  },
);

final loopV2Launch2OverviewGatewayProvider = Provider<Launch2OverviewGateway>((
  ref,
) {
  final api = ref.watch(loopV2Launch2OverviewApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableLaunch2OverviewGateway();
  }
  return DioLoopV2Launch2OverviewGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});
