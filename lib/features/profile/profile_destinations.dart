import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';

/// 情报 · 算力 (S343 · decision 0271): where 我的's 产生算力 tag opens.
const String loopIntelPowerLocation = '/intel?tab=power';

/// 情报 · 算力 · 邀请 (S343 · decision 0271): where 我的's 邀请好友 row opens.
const String loopIntelInviteLocation = '/intel?tab=power&sub=invite';

/// Prefix of the one profile destination that carries a parameter.
const String _communityRecordDestination = 'community-profile:';

/// Where one profile destination id opens. Copy permissions live inside
/// Privacy, seed backup is replaced by the manifest `key-export` page; none of
/// the retired ids reaches a dead route. 我 is the 我的 tab since S343
/// (decision 0271), so `profile` and anything unknown land there.
String profileDestinationPath(String id) => switch (id) {
  'profile' => LoopRouteManifest.pathFor('wallet'),
  // `community-profile:<communityId>`: one created community's own record.
  // The 我创建的 group hands the id over rather than a page-less destination,
  // because `community-profile` addresses exactly one community and this is
  // the only place that knows which.
  final String scoped when scoped.startsWith(_communityRecordDestination) =>
    '${LoopRouteManifest.pathFor('community-profile')}?id='
        '${Uri.encodeQueryComponent(scoped.substring(_communityRecordDestination.length))}',
  // `/profile/friends` and `/chat/friends/add` were folded into `search`
  // and `connections` in step 3; step 4 folded the V1 request inbox into the
  // `dm-requests` page, so the profile row now opens that manifest slug.
  'friend-requests' => LoopRouteManifest.pathFor('dm-requests'),
  'wallets' => LoopRouteManifest.pathFor('wallets'),
  'wallet' => LoopRouteManifest.pathFor('wallet'),
  'meme' => LoopRouteManifest.pathFor('meme'),
  'dapp' => LoopRouteManifest.pathFor('dapp'),
  'invite' => loopIntelInviteLocation,
  final String launch2
      when launch2.startsWith('${Launch2Route.instancePath}?') ||
          launch2.startsWith('${Launch2Route.nftPath}?') =>
    launch2,
  'community-discover' => LoopRouteManifest.pathFor('community-discover'),
  // Not a route of its own: the same manifest page narrowed to the owner's
  // memberships, which is what 我加入的社区 opens once the aggregate reports
  // any.
  'community-joined' =>
    '${LoopRouteManifest.pathFor('community-discover')}?membership=joined',
  'launch-history' => LoopRouteManifest.pathFor('launch-history'),
  'launch-tier' => LoopRouteManifest.pathFor('launch-tier'),
  'profile-edit' => LoopRouteManifest.pathFor('profile-edit'),
  'privacy' => LoopRouteManifest.pathFor('privacy'),
  'social-privacy' => LoopRouteManifest.pathFor('privacy'),
  'copytrade-perms' => LoopRouteManifest.pathFor('privacy'),
  'security' => LoopRouteManifest.pathFor('security'),
  'devices' => LoopRouteManifest.pathFor('devices'),
  'key-export' => LoopRouteManifest.pathFor('key-export'),
  'social-recovery' => LoopRouteManifest.pathFor('social-recovery'),
  'networks' => LoopRouteManifest.pathFor('networks'),
  'notif-settings' => LoopRouteManifest.pathFor('notif-settings'),
  'notifications' => LoopRouteManifest.pathFor('notifications'),
  'connections' => LoopRouteManifest.pathFor('connections'),
  'blocklist' => LoopRouteManifest.pathFor('blocklist'),
  'settings' => LoopRouteManifest.pathFor('settings'),
  'about' => LoopRouteManifest.pathFor('about'),
  'support' => LoopRouteManifest.pathFor('support'),
  'mining' => LoopRouteManifest.pathFor('mining'),
  'mining-assets' => LoopRouteManifest.pathFor('mining-assets'),
  'mining-rewards' => LoopRouteManifest.pathFor('mining-rewards'),
  'mining-rules' => LoopRouteManifest.pathFor('mining-rules'),
  'referral' => LoopRouteManifest.pathFor('referral'),
  'scan' => LoopRouteManifest.pathFor('scan'),
  _ => LoopRouteManifest.pathFor('wallet'),
};
