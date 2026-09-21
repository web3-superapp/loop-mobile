import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/alerts/loop_v2_alerts_api.dart';
import 'package:loop_mobile/integrations/backend/v2/approvals/loop_v2_approvals_api.dart';
import 'package:loop_mobile/integrations/backend/v2/chain/loop_v2_chain_api.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_api.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_api.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/meta/loop_v2_about_api.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/backend/v2/settings/loop_v2_settings_api.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_social_api.dart';
import 'package:loop_mobile/integrations/backend/v2/support/loop_v2_support_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';
import 'package:loop_mobile/integrations/backend/v2/watchlist/loop_v2_watchlist_api.dart';

/// One-off device-acceptance preflight (2026-09-16).
///
/// It replays the responses captured from the real Development stack by
/// `docs/integration/preflight-2026-09-16/harness/preflight-reads.mts` into the
/// strict client decoders under `lib/integrations/backend/v2/`, so a backend
/// field the client has no branch for is found here instead of on the device.
///
/// The capture is a developer artifact, not a fixture: when the directory is
/// absent the whole suite skips, so CI never depends on a development database.
const _token = 'preflight.access.token';
const _clientVersion = '1.0.0';

String get _captureRoot =>
    Platform.environment['LOOP_PREFLIGHT_DIR'] ??
    '../docs/integration/preflight-2026-09-16/responses';

/// Replays one captured response, headers included, so the header half of the
/// contract (`cache-control: no-store`, `x-request-id`) is exercised too.
final class _ReplayAdapter implements HttpClientAdapter {
  _ReplayAdapter(this.record);

  final Map<String, Object?> record;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final rawHeaders = (record['headers'] as Map?) ?? const <String, Object?>{};
    final headers = <String, List<String>>{};
    rawHeaders.forEach((key, value) {
      final name = '$key'.toLowerCase();
      if (value is List) {
        headers[name] = value.map((e) => '$e').toList();
      } else if (value != null) {
        headers[name] = <String>['$value'];
      }
    });
    headers.putIfAbsent(
      Headers.contentTypeHeader,
      () => <String>[Headers.jsonContentType],
    );
    return ResponseBody.fromString(
      jsonEncode(record['body']),
      record['status']! as int,
      headers: headers,
    );
  }
}

Map<String, Object?>? _load(String identity, String slug) {
  final file = File('$_captureRoot/$identity/$slug.json');
  if (!file.existsSync()) return null;
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

Dio _dio(Map<String, Object?> record) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.example'));
  dio.httpClientAdapter = _ReplayAdapter(record);
  return dio;
}

typedef _Invoke = Future<Object?> Function(Dio dio, _Ids ids);

/// The path/query identifiers of the captured request, so a replay sends the
/// same arguments the capture was taken with. Several decoders cross-check the
/// requested id against the projection, so a hard-coded id would fail for a
/// reason the server never produced.
final class _Ids {
  _Ids(this.route);

  final String route;

  String _seg(int index) {
    final path = route.split('?').first;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return Uri.decodeComponent(parts[index]);
  }

  String get assetId {
    final path = route.split('?').first;
    final marker = path.contains('/market/assets/')
        ? '/market/assets/'
        : '/v2/assets/';
    final rest = path.substring(path.indexOf(marker) + marker.length);
    return Uri.decodeComponent(rest.split('/').first);
  }

  String get walletId {
    final query = Uri.splitQueryString(
      route.contains('?') ? route.split('?').last : '',
    );
    return query['walletId'] ?? _seg(2);
  }

  String get communityId => _seg(2);

  /// The directory sort the capture was taken with. The response states the
  /// order it applied and the decoder refuses one that answers a different
  /// question, so a replay has to ask the question the capture asked.
  CommunityDirectorySort get directorySort {
    final query = Uri.splitQueryString(
      route.contains('?') ? route.split('?').last : '',
    );
    final raw = query['sort'];
    if (raw == null) return CommunityDirectorySort.members;
    return CommunityDirectorySort.tryParse(raw) ??
        CommunityDirectorySort.members;
  }

  String get miningCommunityId => _seg(3);
  String get chatOperationId => _seg(3);
  String get approvalAssetId => _seg(2);
  String get launchId => _seg(2);
  String get pathId => _seg(2);
  String get launchProjectId => _seg(3);
  String get spender {
    final path = route.split('?').first.split('/');
    return Uri.decodeComponent(path[path.length - 1]);
  }
}

final class _Case {
  const _Case(this.slug, this.decoder, this.invoke);

  final String slug;

  /// `<file>#<entry point>` — the decoder the route is supposed to land in.
  final String decoder;
  final _Invoke invoke;
}

/// Every captured instance that has a client decoder, in capture order.
List<_Case> _cases() => <_Case>[
  // ---- meta / policy (credential-free) ----
  _Case(
    'v2_meta_client-policy',
    'loop_v2_meta_repository.dart#getClientPolicy',
    (d, ids) => DioLoopV2MetaRepository.withClient(d).getClientPolicy(),
  ),
  _Case(
    'v2_meta_capabilities',
    'loop_v2_meta_repository.dart#getCapabilities',
    (d, ids) => DioLoopV2MetaRepository.withClient(d).getCapabilities(),
  ),
  _Case(
    'v2_meta_about',
    'meta/loop_v2_about_api.dart#getAbout',
    (d, ids) => DioLoopV2AboutApi(d).getAbout(),
  ),
  _Case(
    'v2_profile_avatars',
    'profile/loop_v2_profile_api.dart#getAvatars',
    (d, ids) => DioLoopV2ProfileApi(d).getAvatars(),
  ),

  // ---- account / profile / settings / security ----
  _Case(
    'v2_account_me',
    'loop_v2_session_api.dart#getAccount',
    (d, ids) =>
        DioLoopV2SessionApi(d)
            .getAccount(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_profile',
    'profile/loop_v2_profile_api.dart#getProfile',
    (d, ids) =>
        DioLoopV2ProfileApi(d)
            .getProfile(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_profile_privacy',
    'profile/loop_v2_profile_api.dart#getPrivacy',
    (d, ids) =>
        DioLoopV2ProfileApi(d)
            .getPrivacy(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_settings',
    'settings/loop_v2_settings_api.dart#getSettings',
    (d, ids) =>
        DioLoopV2SettingsApi(d)
            .getSettings(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_security_capabilities',
    'security/loop_v2_security_api.dart#getCapabilities',
    (d, ids) => DioLoopV2SecurityApi(d)
        .getCapabilities(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_security_summary',
    'security/loop_v2_security_api.dart#getSummary',
    (d, ids) =>
        DioLoopV2SecurityApi(d)
            .getSummary(accessToken: _token, clientVersion: _clientVersion),
  ),
  // Three session-id instances: an id the server has no row for (the header
  // is echoed back as `currentSessionId`), the caller's real active session,
  // and no header at all.
  _Case(
    'v2_devices',
    'security/loop_v2_security_api.dart#getDevices',
    (d, ids) => DioLoopV2SecurityApi(d).getDevices(
      accessToken: _token,
      clientVersion: _clientVersion,
      sessionId: '11111111-2222-4333-8444-555555555555',
    ),
  ),
  _Case(
    'v2_devices_realsession',
    'security/loop_v2_security_api.dart#getDevices',
    (d, ids) => DioLoopV2SecurityApi(d).getDevices(
      accessToken: _token,
      clientVersion: _clientVersion,
      sessionId: 'bd3bfe9e-eba9-4d40-a3ac-18792bf4f643',
    ),
  ),
  _Case(
    'v2_devices_nosession',
    'security/loop_v2_security_api.dart#getDevices',
    (d, ids) =>
        DioLoopV2SecurityApi(d)
            .getDevices(accessToken: _token, clientVersion: _clientVersion),
  ),

  // ---- community ----
  _Case(
    'v2_community_home',
    'community/loop_v2_community_api.dart#getHome',
    (d, ids) =>
        DioLoopV2CommunityApi(d)
            .getHome(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_communities_limit_3',
    'v2_communities_p2',
    'v2_communities_sort_newest_verification_all_membership_all_limit_5',
    'v2_communities_membership_joined_limit_5',
    'v2_communities_verification_verified_limit_5',
    'v2_communities_membership_joined_limit_10',
  ])
    _Case(slug, 'community/loop_v2_community_api.dart#listCommunities', (
      d,
      ids,
    ) {
      return DioLoopV2CommunityApi(d).listCommunities(
        accessToken: _token,
        clientVersion: _clientVersion,
        sort: ids.directorySort,
        verification: CommunityVerificationFilter.all,
        membership: CommunityMembershipFilter.all,
      );
    }),
  for (final slug in <String>[
    'v2_communities_member',
    'v2_communities_nonmember',
    'v2_communities_missing',
  ])
    _Case(
      slug,
      'community/loop_v2_community_api.dart#getCommunity',
      (d, ids) => DioLoopV2CommunityApi(d).getCommunity(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: ids.communityId,
      ),
    ),
  for (final entry in <String, CommunityMemberFilter>{
    'v2_communities_member_members': CommunityMemberFilter.all,
    'v2_communities_member_members_owner': CommunityMemberFilter.owner,
    'v2_communities_member_members_admin': CommunityMemberFilter.admin,
    'v2_communities_member_members_banned': CommunityMemberFilter.banned,
    'v2_communities_member_members_q': CommunityMemberFilter.all,
    'v2_communities_member_members_p1': CommunityMemberFilter.all,
    'v2_communities_member_members_p2': CommunityMemberFilter.all,
    'v2_communities_nonmember_members': CommunityMemberFilter.all,
    'v2_communities_nonmember_members_owner': CommunityMemberFilter.owner,
    'v2_communities_nonmember_members_admin': CommunityMemberFilter.admin,
    'v2_communities_nonmember_members_banned': CommunityMemberFilter.banned,
    'v2_communities_nonmember_members_q': CommunityMemberFilter.all,
    'v2_communities_nonmember_members_p1': CommunityMemberFilter.all,
    'v2_communities_nonmember_members_p2': CommunityMemberFilter.all,
    'v2_communities_missing_members': CommunityMemberFilter.all,
  }.entries)
    _Case(
      entry.key,
      'community/loop_v2_community_api.dart#listMembers',
      (d, ids) => DioLoopV2CommunityApi(d).listMembers(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: ids.communityId,
        role: entry.value,
      ),
    ),
  _Case(
    'v2_mining_referral_rules',
    'community/loop_v2_community_api.dart#getReferralRules',
    (d, ids) => DioLoopV2CommunityApi(d)
        .getReferralRules(accessToken: _token, clientVersion: _clientVersion),
  ),

  // ---- communication / voice rooms ----
  for (final slug in <String>[
    'v2_communities_member_voicerooms_current',
    'v2_communities_nonmember_voicerooms_current',
    'v2_communities_missing_voicerooms_current',
  ])
    _Case(
      slug,
      'communication/loop_v2_communication_api.dart#getCurrentVoiceRoom',
      (d, ids) => DioLoopV2CommunicationApi(d).getCurrentVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: ids.communityId,
      ),
    ),
  _Case(
    'v2_voicerooms_missing',
    'communication/loop_v2_communication_api.dart#getVoiceRoom',
    (d, ids) => DioLoopV2CommunicationApi(d).getVoiceRoom(
      accessToken: _token,
      clientVersion: _clientVersion,
      voiceRoomId: ids.pathId,
    ),
  ),
  _Case(
    'v2_voicerooms_missing_handraises',
    'communication/loop_v2_communication_api.dart#listHandRaises',
    (d, ids) => DioLoopV2CommunicationApi(d).listHandRaises(
      accessToken: _token,
      clientVersion: _clientVersion,
      voiceRoomId: ids.pathId,
    ),
  ),
  _Case(
    'v2_chat_operations_missing',
    'communication/loop_v2_communication_api.dart#getOperation',
    (d, ids) => DioLoopV2CommunicationApi(d).getOperation(
      accessToken: _token,
      clientVersion: _clientVersion,
      operationId: ids.chatOperationId,
    ),
  ),

  // ---- social ----
  for (final entry in <String, ConnectionDirection>{
    'v2_connections_direction_following_limit_5': ConnectionDirection.following,
    'v2_connections_direction_followers_limit_5': ConnectionDirection.followers,
  }.entries)
    _Case(
      entry.key,
      'social/loop_v2_social_api.dart#listConnections',
      (d, ids) => DioLoopV2SocialApi(d).listConnections(
        accessToken: _token,
        clientVersion: _clientVersion,
        direction: entry.value,
      ),
    ),
  for (final entry in <String, BlockKind>{
    'v2_blocks_kind_user_limit_5': BlockKind.user,
    'v2_blocks_kind_contract_limit_5': BlockKind.contract,
    'v2_blocks_kind_domain_limit_5': BlockKind.domain,
  }.entries)
    _Case(
      entry.key,
      'social/loop_v2_social_api.dart#listBlocks',
      (d, ids) => DioLoopV2SocialApi(d).listBlocks(
        accessToken: _token,
        clientVersion: _clientVersion,
        kind: entry.value,
      ),
    ),
  _Case(
    'v2_message-requests_limit_5',
    'social/loop_v2_social_api.dart#listMessageRequests',
    (d, ids) => DioLoopV2SocialApi(
      d,
    ).listMessageRequests(accessToken: _token, clientVersion: _clientVersion),
  ),

  // ---- search ----
  for (final entry in <String, SearchDomain>{
    'v2_search_domain_users_q_lo_limit_5': SearchDomain.users,
    'v2_search_users_empty': SearchDomain.users,
    'v2_search_domain_communities_q_lo_limit_5': SearchDomain.communities,
    'v2_search_communities_empty': SearchDomain.communities,
    'v2_search_communities_verified': SearchDomain.communities,
    'v2_search_domain_assets_q_lo_limit_5': SearchDomain.assets,
    'v2_search_assets_empty': SearchDomain.assets,
    'v2_search_domain_launch_q_lo_limit_5': SearchDomain.launch,
    'v2_search_launch_empty': SearchDomain.launch,
    'v2_search_domain_dapps_q_lo_limit_5': SearchDomain.dapps,
    'v2_search_dapps_empty': SearchDomain.dapps,
  }.entries)
    _Case(
      entry.key,
      'search/loop_v2_search_api.dart#search',
      (d, ids) => DioLoopV2SearchApi(d).search(
        accessToken: _token,
        clientVersion: _clientVersion,
        domain: entry.value,
        query: 'lo',
      ),
    ),

  // ---- chain / market ----
  _Case(
    'v2_chain_status',
    'chain/loop_v2_chain_api.dart#getStatus',
    (d, ids) =>
        DioLoopV2ChainApi(d)
            .getStatus(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_assets_asset0',
    'v2_assets_asset1',
    'v2_assets_asset2',
    'v2_assets_asset3',
    'v2_assets_missing',
  ])
    _Case(
      slug,
      'chain/loop_v2_chain_api.dart#getAsset',
      (d, ids) => DioLoopV2ChainApi(d).getAsset(
        accessToken: _token,
        clientVersion: _clientVersion,
        assetId: ids.assetId,
      ),
    ),
  _Case(
    'v2_market_overview',
    'market/loop_v2_market_api.dart#getOverview',
    (d, ids) =>
        DioLoopV2MarketApi(d)
            .getOverview(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_market_new-pairs',
    'market/loop_v2_market_api.dart#getNewPairs',
    (d, ids) =>
        DioLoopV2MarketApi(d)
            .getNewPairs(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_market_smart-money',
    'market/loop_v2_market_api.dart#getSmartMoney',
    (d, ids) =>
        DioLoopV2MarketApi(d)
            .getSmartMoney(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_market_assets_asset0',
    'v2_market_assets_asset1',
    'v2_market_assets_asset2',
    'v2_market_assets_asset3',
    'v2_market_assets_missing',
  ])
    _Case(
      slug,
      'market/loop_v2_market_api.dart#getAsset',
      (d, ids) => DioLoopV2MarketApi(d).getAsset(
        accessToken: _token,
        clientVersion: _clientVersion,
        assetId: ids.assetId,
      ),
    ),
  for (final entry in <String, LoopCandleInterval>{
    'v2_market_assets_asset0_candles_1h': LoopCandleInterval.oneHour,
    'v2_market_assets_asset0_candles_1d': LoopCandleInterval.oneDay,
    'v2_market_assets_asset1_candles_1h': LoopCandleInterval.oneHour,
    'v2_market_assets_asset1_candles_1d': LoopCandleInterval.oneDay,
    'v2_market_assets_asset2_candles_1h': LoopCandleInterval.oneHour,
    'v2_market_assets_asset2_candles_1d': LoopCandleInterval.oneDay,
    'v2_market_assets_asset3_candles_1h': LoopCandleInterval.oneHour,
    'v2_market_assets_asset3_candles_1d': LoopCandleInterval.oneDay,
    'v2_market_assets_missing_candles': LoopCandleInterval.oneHour,
  }.entries)
    _Case(
      entry.key,
      'market/loop_v2_market_api.dart#getCandles',
      (d, ids) => DioLoopV2MarketApi(d).getCandles(
        accessToken: _token,
        clientVersion: _clientVersion,
        assetId: ids.assetId,
        interval: entry.value,
      ),
    ),
  for (final slug in <String>[
    'v2_market_assets_asset0_trades',
    'v2_market_assets_asset1_trades',
    'v2_market_assets_asset2_trades',
    'v2_market_assets_asset3_trades',
    'v2_market_assets_missing_trades',
  ])
    _Case(
      slug,
      'market/loop_v2_market_api.dart#getTrades',
      (d, ids) => DioLoopV2MarketApi(d).getTrades(
        accessToken: _token,
        clientVersion: _clientVersion,
        assetId: ids.assetId,
      ),
    ),
  for (final slug in <String>[
    'v2_market_assets_asset0_holders',
    'v2_market_assets_asset1_holders',
    'v2_market_assets_asset2_holders',
    'v2_market_assets_asset3_holders',
    'v2_market_assets_missing_holders',
  ])
    _Case(
      slug,
      'market/loop_v2_market_api.dart#getHolders',
      (d, ids) => DioLoopV2MarketApi(d).getHolders(
        accessToken: _token,
        clientVersion: _clientVersion,
        assetId: ids.assetId,
      ),
    ),

  // ---- wallet / approvals / intents ----
  _Case(
    'v2_wallets',
    'wallet/loop_v2_wallet_api.dart#getWallets',
    (d, ids) =>
        DioLoopV2WalletApi(d)
            .getWallets(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_wallets_present_balances',
    'v2_wallets_missing_balances',
  ])
    _Case(
      slug,
      'wallet/loop_v2_wallet_api.dart#getBalances',
      (d, ids) => DioLoopV2WalletApi(d).getBalances(
        accessToken: _token,
        clientVersion: _clientVersion,
        walletId: ids.walletId,
      ),
    ),
  for (final slug in <String>[
    'v2_wallets_present_activity',
    'v2_wallets_missing_activity',
  ])
    _Case(
      slug,
      'wallet/loop_v2_wallet_api.dart#getActivity',
      (d, ids) => DioLoopV2WalletApi(d).getActivity(
        accessToken: _token,
        clientVersion: _clientVersion,
        walletId: ids.walletId,
      ),
    ),
  for (final slug in <String>[
    'v2_wallets_present_receive',
    'v2_wallets_missing_receive',
  ])
    _Case(
      slug,
      'wallet/loop_v2_wallet_api.dart#getReceive',
      (d, ids) => DioLoopV2WalletApi(d).getReceive(
        accessToken: _token,
        clientVersion: _clientVersion,
        walletId: ids.walletId,
      ),
    ),
  for (final slug in <String>[
    'v2_approvals_present',
    'v2_approvals_missing_wallet',
  ])
    _Case(
      slug,
      'approvals/loop_v2_approvals_api.dart#getApprovals',
      (d, ids) => DioLoopV2ApprovalsApi(d).getApprovals(
        accessToken: _token,
        clientVersion: _clientVersion,
        walletId: ids.walletId,
      ),
    ),
  for (final slug in <String>[
    'v2_approvals_pair',
    'v2_approvals_pair_unobserved',
  ])
    _Case(
      slug,
      'approvals/loop_v2_approvals_api.dart#getApproval',
      (d, ids) => DioLoopV2ApprovalsApi(d).getApproval(
        accessToken: _token,
        clientVersion: _clientVersion,
        walletId: ids.walletId,
        assetId: ids.approvalAssetId,
        spender: ids.spender,
      ),
    ),
  _Case(
    'v2_wallet-intents_limit_5',
    'wallet_intents/loop_v2_wallet_intents_api.dart#listIntents',
    (d, ids) =>
        DioLoopV2WalletIntentsApi(d)
            .listIntents(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_walletintents_missing',
    'wallet_intents/loop_v2_wallet_intents_api.dart#getIntent',
    (d, ids) => DioLoopV2WalletIntentsApi(d).getIntent(
      accessToken: _token,
      clientVersion: _clientVersion,
      intentId: ids.pathId,
    ),
  ),

  // ---- launch ----
  _Case(
    'v2_launch_overview',
    'launch/loop_v2_launch_api.dart#getOverview',
    (d, ids) =>
        DioLoopV2LaunchApi(d)
            .getOverview(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_launch_stake',
    'launch/loop_v2_launch_api.dart#getStake',
    (d, ids) =>
        DioLoopV2LaunchApi(d)
            .getStake(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_launch_economy',
    'launch/loop_v2_launch_api.dart#getEconomy',
    (d, ids) =>
        DioLoopV2LaunchApi(d)
            .getEconomy(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_launch_projects_limit_5',
    'v2_launch_projects_status_draft_limit_5',
    'v2_launch_projects_status_submitted_limit_5',
    'v2_launch_projects_status_in_review_limit_5',
    'v2_launch_projects_status_returned_limit_5',
    'v2_launch_projects_status_approved_limit_5',
    'v2_launch_projects_status_rejected_limit_5',
  ])
    _Case(
      slug,
      'launch/loop_v2_launch_api.dart#listProjects',
      (d, ids) =>
          DioLoopV2LaunchApi(d)
              .listProjects(accessToken: _token, clientVersion: _clientVersion),
    ),
  _Case(
    'v2_launch_projects_missing',
    'launch/loop_v2_launch_api.dart#getProject',
    (d, ids) => DioLoopV2LaunchApi(d).getProject(
      accessToken: _token,
      clientVersion: _clientVersion,
      projectId: ids.launchProjectId,
    ),
  ),
  _Case(
    'v2_launch_projects_missing_milestones',
    'launch/loop_v2_launch_api.dart#getMilestones',
    (d, ids) => DioLoopV2LaunchApi(d).getMilestones(
      accessToken: _token,
      clientVersion: _clientVersion,
      projectId: ids.launchProjectId,
    ),
  ),
  _Case(
    'v2_launches_missing',
    'launch/loop_v2_launch_api.dart#getLaunch',
    (d, ids) => DioLoopV2LaunchApi(d).getLaunch(
      accessToken: _token,
      clientVersion: _clientVersion,
      launchId: ids.launchId,
    ),
  ),
  _Case(
    'v2_launch_missing_eligibility',
    'launch/loop_v2_launch_api.dart#getEligibility',
    (d, ids) => DioLoopV2LaunchApi(d).getEligibility(
      accessToken: _token,
      clientVersion: _clientVersion,
      launchId: ids.launchId,
    ),
  ),
  _Case(
    'v2_launch_missing_holders',
    'launch/loop_v2_launch_api.dart#getHolders',
    (d, ids) => DioLoopV2LaunchApi(d).getHolders(
      accessToken: _token,
      clientVersion: _clientVersion,
      launchId: ids.launchId,
    ),
  ),
  _Case(
    'v2_launch_missing_history',
    'launch/loop_v2_launch_api.dart#getHistory',
    (d, ids) => DioLoopV2LaunchApi(d).getHistory(
      accessToken: _token,
      clientVersion: _clientVersion,
      launchId: ids.launchId,
    ),
  ),

  // ---- mining / referral ----
  _Case(
    'v2_mining_summary',
    'mining/loop_v2_mining_api.dart#getSummary',
    (d, ids) =>
        DioLoopV2MiningApi(d)
            .getSummary(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_mining_assets',
    'mining/loop_v2_mining_api.dart#getAssets',
    (d, ids) =>
        DioLoopV2MiningApi(d)
            .getAssets(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_mining_rewards',
    'mining/loop_v2_mining_api.dart#getRewards',
    (d, ids) =>
        DioLoopV2MiningApi(d)
            .getRewards(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final entry in <String, MiningRankScope>{
    'v2_mining_rank_scope_users': MiningRankScope.users,
    'v2_mining_rank_scope_communities': MiningRankScope.communities,
  }.entries)
    _Case(
      entry.key,
      'mining/loop_v2_mining_api.dart#getRank',
      (d, ids) => DioLoopV2MiningApi(d).getRank(
        accessToken: _token,
        clientVersion: _clientVersion,
        scope: entry.value,
      ),
    ),
  _Case(
    'v2_mining_rules',
    'mining/loop_v2_mining_api.dart#getRules',
    (d, ids) =>
        DioLoopV2MiningApi(d)
            .getRules(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_mining_communities_member',
    'v2_mining_communities_nonmember',
    'v2_mining_communities_missing',
  ])
    _Case(
      slug,
      'mining/loop_v2_mining_api.dart#getCommunity',
      (d, ids) => DioLoopV2MiningApi(d).getCommunity(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: ids.miningCommunityId,
      ),
    ),
  _Case(
    'v2_referral',
    'referral/loop_v2_referral_api.dart#getOverview',
    (d, ids) =>
        DioLoopV2ReferralApi(d)
            .getOverview(accessToken: _token, clientVersion: _clientVersion),
  ),

  // ---- alerts / notifications / watchlist / support ----
  _Case(
    'v2_alerts_limit_5',
    'alerts/loop_v2_alerts_api.dart#listAlerts',
    (d, ids) =>
        DioLoopV2AlertsApi(d)
            .listAlerts(accessToken: _token, clientVersion: _clientVersion),
  ),
  for (final slug in <String>[
    'v2_notifications_feed_limit_5',
    'v2_notifications_feed_p2',
  ])
    _Case(
      slug,
      'notifications/loop_v2_notifications_api.dart#getFeed',
      (d, ids) =>
          DioLoopV2NotificationsApi(d)
              .getFeed(accessToken: _token, clientVersion: _clientVersion),
    ),
  _Case(
    'v2_notification-preferences',
    'notifications/loop_v2_notifications_api.dart#getPreferences',
    (d, ids) =>
        DioLoopV2NotificationsApi(d)
            .getPreferences(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_watchlist',
    'watchlist/loop_v2_watchlist_api.dart#getWatchlist',
    (d, ids) =>
        DioLoopV2WatchlistApi(d)
            .getWatchlist(accessToken: _token, clientVersion: _clientVersion),
  ),
  _Case(
    'v2_support_tickets_limit_5',
    'support/loop_v2_support_api.dart#listTickets',
    (d, ids) =>
        DioLoopV2SupportApi(d)
            .listTickets(accessToken: _token, clientVersion: _clientVersion),
  ),
];

void main() {
  final root = Directory(_captureRoot);
  if (!root.existsSync()) {
    test('device preflight capture is absent', () {}, skip: true);
    return;
  }
  final identities =
      root
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .toList()
        ..sort();

  for (final identity in identities) {
    group('preflight replay · $identity', () {
      for (final entry in _cases()) {
        test('${entry.slug} -> ${entry.decoder}', () async {
          final record = _load(identity, entry.slug);
          if (record == null) {
            // Not every instance exists for every identity (a second page only
            // exists where the first one was full).
            // ignore: avoid_print
            print('PREFLIGHT|$identity|${entry.slug}|-|SKIP|missing capture');
            return;
          }
          final status = record['status']! as int;
          String verdict;
          String detail = '';
          try {
            await entry.invoke(_dio(record), _Ids(record['route']! as String));
            verdict = 'DECODED';
          } on LoopBackendFailure catch (failure) {
            if (failure.kind == LoopBackendFailureKind.invalidPayload) {
              verdict = 'INVALID_PAYLOAD';
              detail = 'statusCode=${failure.statusCode}';
            } else {
              verdict = 'ENVELOPE_${failure.kind.name}';
              detail = failure.code ?? '';
            }
          } catch (error) {
            verdict = 'THREW';
            detail = error.runtimeType.toString();
          }
          // ignore: avoid_print
          print(
            'PREFLIGHT|$identity|${entry.slug}|$status|$verdict|'
            '${entry.decoder}|$detail',
          );
          expect(
            verdict,
            isNot('INVALID_PAYLOAD'),
            reason:
                'HTTP $status on ${record['route']} was refused by '
                '${entry.decoder}',
          );
          expect(verdict, isNot('THREW'), reason: detail);
        });
      }
    });
  }
}
