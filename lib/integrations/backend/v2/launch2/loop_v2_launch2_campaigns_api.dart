import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
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

/// `GET /v2/launch2/campaigns` (loop-api S183, client decision 0165): the
/// operations campaign cards of the launch desk.
///
/// A display extra, so the codec forgives like the overview's: an item it
/// cannot read is dropped whole, a cover it does not accept is no cover, and
/// only a body that is not an object with an `items` list is a failure —
/// which the desk shows as no campaign at all.
abstract final class LoopV2Launch2CampaignsCodec {
  /// The server sends at most ten.
  static const int itemLimit = 10;

  /// Generous ceilings over the console's own (24 / 60 / 8): a longer text
  /// is not something this client was built to lay out, so the item drops.
  static const int titleMax = 48;
  static const int subtitleMax = 120;
  static const int ctaMax = 16;
  static const int linkMax = 1024;

  static Launch2Campaigns campaigns(
    Object? raw, {
    required String? Function(String mediaId) mediaUrl,
  }) {
    final root = _map(raw);
    if (root == null) LoopV2ChainCodec.invalid();
    final items = root['items'];
    if (items is! List) LoopV2ChainCodec.invalid();
    final seen = <String>{};
    final read = <Launch2DeskCampaign>[];
    for (final item in items) {
      if (read.length >= itemLimit) break;
      final campaign = _campaign(item, mediaUrl);
      if (campaign == null || !seen.add(campaign.campaignId)) continue;
      read.add(campaign);
    }
    DateTime? observedAt;
    try {
      observedAt = LoopV2ChainCodec.optionalTimestamp(root, 'observedAt');
    } catch (_) {
      observedAt = null;
    }
    return Launch2Campaigns(
      items: List<Launch2DeskCampaign>.unmodifiable(read),
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

  static String? _text(Object? value, int max) {
    if (value is! String) return null;
    final text = LoopV2ChainCodec.sanitizeProviderText(value);
    if (text.isEmpty || text.runes.length > max) return null;
    return text;
  }

  static Launch2DeskCampaign? _campaign(
    Object? raw,
    String? Function(String mediaId) mediaUrl,
  ) {
    final map = _map(raw);
    if (map == null) return null;
    try {
      final id = map['campaignId'];
      if (id is! String || id.isEmpty || id.length > 128) return null;
      final title = _text(map['title'], titleMax);
      if (title == null) return null;
      // `null` or blank is no subtitle; anything else must read.
      final rawSubtitle = map['subtitle'];
      String? subtitle;
      if (rawSubtitle != null) {
        if (rawSubtitle is! String) return null;
        final text = LoopV2ChainCodec.sanitizeProviderText(rawSubtitle);
        if (text.runes.length > subtitleMax) return null;
        subtitle = text.isEmpty ? null : text;
      }
      final startsAt = LoopV2ChainCodec.requireTimestamp(map, 'startsAt');
      final endsAt = LoopV2ChainCodec.requireTimestamp(map, 'endsAt');
      if (!endsAt.isAfter(startsAt)) return null;
      final link = _map(map['link']);
      if (link == null) return null;
      final kind = Launch2CampaignLinkKind.tryParse(link['kind']);
      final value = link['value'];
      if (kind == null ||
          value is! String ||
          value.isEmpty ||
          value.length > linkMax) {
        return null;
      }
      final pinned = map['pinned'];
      final sortOrder = map['sortOrder'];
      final state = Launch2CampaignState.tryParse(map['state']);
      if (pinned is! bool || sortOrder is! int || state == null) return null;
      final cta = map['ctaLabel'];
      if (cta != null && cta is! String) return null;
      return Launch2DeskCampaign(
        campaignId: id,
        title: title,
        subtitle: subtitle,
        coverUrl: _cover(map, mediaUrl),
        startsAt: startsAt,
        endsAt: endsAt,
        ctaLabel: _text(cta, ctaMax) ?? launch2CampaignDefaultCta,
        link: Launch2CampaignLink(kind: kind, value: value),
        pinned: pinned,
        sortOrder: sortOrder,
        state: state,
      );
    } catch (_) {
      return null;
    }
  }

  /// The cover through the same acceptance as every launch2 picture (a
  /// LOOP media address or an accepted logo host); anything else is none.
  static String? _cover(
    Map<String, Object?> map,
    String? Function(String mediaId) mediaUrl,
  ) {
    try {
      return LoopV2Launch2Codec.logoUrl(map, 'coverUrl', mediaUrl: mediaUrl);
    } catch (_) {
      return null;
    }
  }
}

final class DioLoopV2Launch2CampaignsApi {
  DioLoopV2Launch2CampaignsApi(this._dio, {required this.mediaUrl});

  static const campaignsPath = '/v2/launch2/campaigns';

  final Dio _dio;
  final String? Function(String mediaId) mediaUrl;

  Future<Launch2Campaigns> getCampaigns({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        campaignsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return LoopV2Launch2CampaignsCodec.campaigns(
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

/// The authenticated adapter behind [Launch2CampaignsGateway].
final class DioLoopV2Launch2CampaignsGateway
    implements Launch2CampaignsGateway {
  DioLoopV2Launch2CampaignsGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final DioLoopV2Launch2CampaignsApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Campaigns> loadCampaigns() => executeChainRequest(
    _session,
    (accessToken) => _api.getCampaigns(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
    write: false,
  );
}

/// Reading a provider issues no request; a missing Dio client, client
/// metadata or authenticated session keeps the port at its fail-closed
/// default.
final loopV2Launch2CampaignsApiProvider =
    Provider<DioLoopV2Launch2CampaignsApi?>((ref) {
      final dio = ref.watch(loopBackendDioProvider);
      if (dio == null) return null;
      final resolver = ref.watch(loopV2MediaUrlResolverProvider);
      return DioLoopV2Launch2CampaignsApi(dio, mediaUrl: resolver.urlFor);
    });

final loopV2Launch2CampaignsGatewayProvider = Provider<Launch2CampaignsGateway>(
  (ref) {
    final api = ref.watch(loopV2Launch2CampaignsApiProvider);
    final metadata = ref.watch(loopV2ClientMetadataProvider);
    final session = ref.watch(loopAuthenticatedSessionProvider);
    if (api == null || metadata == null || session == null) {
      return const UnavailableLaunch2CampaignsGateway();
    }
    return DioLoopV2Launch2CampaignsGateway(
      api: api,
      clientMetadata: metadata,
      session: session,
    );
  },
);
