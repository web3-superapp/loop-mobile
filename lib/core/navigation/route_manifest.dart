/// The 118-route product manifest.
///
/// Source of truth: `docs/product/routes-manifest.json` (mirror of
/// `LOOP/docs/routes-manifest.json`). The first 93 slugs were frozen
/// 2026-09-01 from the cliview.org `loop-v2.html` build (SHA-256
/// `bdbe1832…`); decision 0110 (2026-10-08) added the four v3 tabs `chat`,
/// `square`, `meme` and `intel` and re-froze the manifest; decision 0112
/// (S109a, same day) added `user-profile` and `onboarding-communities`;
/// decision 0113 (S109b, same day) added `scan` and `community-manage`;
/// decision 0120 (S117) added the four MEME curve launchpad routes;
/// decision 0138 (S135) added the five MEME v2 project-side routes.
/// decision 0139 (S136) added the MEME v2 project page.
/// decision 0241 (S287) added `notifications`, the notification centre
/// under 聊天 (113 → 114).
/// decision 0254 (S324) added `auth-email`, the e-mail step 使用邮箱登录
/// opens (114 → 115).
/// decision 0262 (S332) added `beta-feedback` and `beta-feedback-mine`, the
/// internal-test feedback form and its list (115 → 117).
/// decision 0270 (S342) added `dapp-web`, the page the in-app DApp browser
/// opens (117 → 118).
/// `test/route_manifest_test.dart`
/// asserts that this table and the JSON agree on slug, module, tab flag and
/// prototype order, and that `lib/app.dart` mounts exactly these paths.
///
/// Every slug maps to exactly one go_router path. Paths that were already
/// implemented before the manifest keep their location to avoid needless
/// migration; the retired location, when one existed, is kept in
/// [LoopRouteEntry.legacyPath] for history only and is never mounted.
library;

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// Product module of the frozen information architecture. Module `1` was
/// retired with Home; the gap is intentional and must not be filled.
enum LoopRouteModule {
  globalAccount('0-global-account'),
  community('2-community'),
  market('3-market'),
  launch('4-launch'),
  mining('5-mining'),
  wallet('6-wallet'),
  profile('7-profile'),
  system('8-system');

  const LoopRouteModule(this.manifestKey);

  /// Key used in `routes-manifest.json`.
  final String manifestKey;

  /// Human label used by the pending surface and reports.
  String get label => switch (this) {
    LoopRouteModule.globalAccount =>
      LoopL10n.current.coreNavigation_routeManifestGlobalAccount,
    LoopRouteModule.community => 'Community',
    LoopRouteModule.market => 'Market',
    LoopRouteModule.launch => 'Launch',
    LoopRouteModule.mining => 'Mining',
    LoopRouteModule.wallet => 'Wallet',
    LoopRouteModule.profile => 'Profile / LOOP ID',
    LoopRouteModule.system =>
      LoopL10n.current.coreNavigation_routeManifestSystem,
  };
}

/// Delivery status of a manifest route in the current build.
enum LoopRouteStatus {
  /// A dedicated screen is mounted at [LoopRouteEntry.path].
  implemented,

  /// Mounted with [LoopPendingSurface]; the page has not been connected yet.
  pending,

  /// Mounted as an informational unavailable surface (fail closed).
  unavailable,

  /// Mounted as a redirect to another manifest path.
  redirect,
}

/// Localized page name for a manifest [slug] (decision 0281); an unknown
/// slug falls back to the slug itself.
String loopRouteTitle(String slug) => switch (slug) {
  'splash' => LoopL10n.current.coreNavigation_routeSplash,
  'auth' => LoopL10n.current.coreNavigation_routeAuth,
  'auth-otp' => LoopL10n.current.coreNavigation_routeAuthOtp,
  'auth-wallet' => LoopL10n.current.coreNavigation_routeAuthWallet,
  'wallet-create' => LoopL10n.current.coreNavigation_routeWalletCreate,
  'wallet-recovery' => LoopL10n.current.coreNavigation_routeWalletRecovery,
  'security-setup' => LoopL10n.current.coreNavigation_routeSecuritySetup,
  'loop-id-setup' => LoopL10n.current.coreNavigation_routeLoopIdSetup,
  'force-update' => LoopL10n.current.coreNavigation_routeForceUpdate,
  'region-blocked' => LoopL10n.current.coreNavigation_routeRegionBlocked,
  'onboarding-communities' =>
    LoopL10n.current.coreNavigation_routeOnboardingCommunities,
  'auth-email' => LoopL10n.current.coreNavigation_routeAuthEmail,
  'search' => LoopL10n.current.coreNavigation_routeSearch,
  'community' => LoopL10n.current.coreNavigation_routeCommunity,
  'community-discover' =>
    LoopL10n.current.coreNavigation_routeCommunityDiscover,
  'community-profile' => LoopL10n.current.coreNavigation_routeCommunityProfile,
  'community-chat' => LoopL10n.current.coreNavigation_routeCommunityChat,
  'community-ai' => 'Community AI',
  'community-members' => LoopL10n.current.coreNavigation_routeCommunityMembers,
  'voiceroom' => LoopL10n.current.common_voiceRooms,
  'voiceroom-full' => LoopL10n.current.coreNavigation_routeVoiceroomFull,
  'dm' => LoopL10n.current.common_directMessage,
  'dm-requests' => LoopL10n.current.common_messageRequests,
  'group' => LoopL10n.current.coreNavigation_routeGroup,
  'group-info' => LoopL10n.current.coreNavigation_routeGroupInfo,
  'chat-search' => LoopL10n.current.coreNavigation_routeChatSearch,
  'chat-forward' => LoopL10n.current.coreNavigation_routeChatForward,
  'chat-merge-preview' => LoopL10n.current.coreNavigation_routeChatMergePreview,
  'chat' => LoopL10n.current.coreNavigation_routeChat,
  'square' => LoopL10n.current.coreNavigation_routeSquare,
  'scan' => LoopL10n.current.common_scan,
  'community-manage' => LoopL10n.current.coreNavigation_routeCommunityManage,
  'notifications' => LoopL10n.current.coreNavigation_routeNotifications,
  'market' => LoopL10n.current.coreNavigation_routeMarket,
  'token' => LoopL10n.current.coreNavigation_routeToken,
  'chart-full' => LoopL10n.current.coreNavigation_routeChartFull,
  'token-holders' => LoopL10n.current.coreNavigation_routeTokenHolders,
  'token-trades' => LoopL10n.current.coreNavigation_routeTokenTrades,
  'watchlist-edit' => LoopL10n.current.coreNavigation_routeWatchlistEdit,
  'alerts' => LoopL10n.current.common_priceAlerts,
  'new-pairs' => LoopL10n.current.coreNavigation_routeNewPairs,
  'smart-money' => LoopL10n.current.coreNavigation_routeSmartMoney,
  'intel' => LoopL10n.current.coreNavigation_routeIntel,
  'launch' => LoopL10n.current.coreNavigation_routeLaunch,
  'launch-detail' => LoopL10n.current.coreNavigation_routeLaunchDetail,
  'launch-tier' => LoopL10n.current.coreNavigation_routeLaunchTier,
  'loop-stake' => LoopL10n.current.coreNavigation_routeLoopStake,
  'launch-trade' => LoopL10n.current.coreNavigation_routeLaunchTrade,
  'launch-holders' => LoopL10n.current.coreNavigation_routeLaunchHolders,
  'launch-graduation' => LoopL10n.current.coreNavigation_routeLaunchGraduation,
  'launch-history' => LoopL10n.current.coreNavigation_routeLaunchHistory,
  'launch-rounds' => LoopL10n.current.coreNavigation_routeLaunchRounds,
  'loop-economy' => LoopL10n.current.coreNavigation_routeLoopEconomy,
  'launch-apply' => LoopL10n.current.coreNavigation_routeLaunchApply,
  'meme' => 'MEME Tab',
  'meme-create' => LoopL10n.current.coreNavigation_routeMemeCreate,
  'meme-token' => LoopL10n.current.coreNavigation_routeMemeToken,
  'meme-token-holders' => LoopL10n.current.coreNavigation_routeMemeTokenHolders,
  'meme-token-trades' => LoopL10n.current.coreNavigation_routeMemeTokenTrades,
  'launch2-create' => LoopL10n.current.coreNavigation_routeLaunch2Create,
  'launch2-projects' => LoopL10n.current.coreNavigation_routeLaunch2Projects,
  'launch2-project' => LoopL10n.current.coreNavigation_routeLaunch2Project,
  'launch2-project-sign' =>
    LoopL10n.current.coreNavigation_routeLaunch2ProjectSign,
  'launch2-project-deployment' =>
    LoopL10n.current.coreNavigation_routeLaunch2ProjectDeployment,
  'launch2-instance' => LoopL10n.current.coreNavigation_routeLaunch2Instance,
  'launch2-dynamic-rewards' =>
    LoopL10n.current.coreNavigation_routeLaunch2DynamicRewards,
  'launch2-nft' => LoopL10n.current.coreNavigation_routeLaunch2Nft,
  'mining' => LoopL10n.current.coreNavigation_routeMining,
  'mining-assets' => LoopL10n.current.coreNavigation_routeMiningAssets,
  'mining-rewards' => LoopL10n.current.coreNavigation_routeMiningRewards,
  'mining-rank' => LoopL10n.current.coreNavigation_routeMiningRank,
  'mining-community' => LoopL10n.current.coreNavigation_routeMiningCommunity,
  'mining-rules' => LoopL10n.current.coreNavigation_routeMiningRules,
  'wallet' => LoopL10n.current.coreNavigation_routeWallet,
  'networth' => LoopL10n.current.coreNavigation_routeNetworth,
  'pay' => LoopL10n.current.coreNavigation_routePay,
  'asset' => LoopL10n.current.coreNavigation_routeAsset,
  'send' => LoopL10n.current.coreNavigation_routeSend,
  'send-to' => LoopL10n.current.coreNavigation_routeSendTo,
  'send-confirm' => LoopL10n.current.coreNavigation_routeSendConfirm,
  'receive' => LoopL10n.current.common_receive,
  'swap' => 'Swap',
  'swap-route' => LoopL10n.current.coreNavigation_routeSwapRoute,
  'bridge' => LoopL10n.current.common_bridge,
  'bridge-status' => LoopL10n.current.coreNavigation_routeBridgeStatus,
  'tx-result' => LoopL10n.current.coreNavigation_routeTxResult,
  'tx-history' => LoopL10n.current.coreNavigation_routeTxHistory,
  'wallets' => LoopL10n.current.coreNavigation_routeWallets,
  'dapp' => LoopL10n.current.coreNavigation_routeDapp,
  'dapp-web' => LoopL10n.current.coreNavigation_routeDappWeb,
  'approval-guard' => LoopL10n.current.coreNavigation_routeApprovalGuard,
  'approvals' => LoopL10n.current.common_tokenApprovals,
  'networks' => LoopL10n.current.coreNavigation_routeNetworks,
  'profile' => LoopL10n.current.coreNavigation_routeProfile,
  'profile-edit' => LoopL10n.current.coreNavigation_routeProfileEdit,
  'privacy' => LoopL10n.current.coreNavigation_routePrivacy,
  'security' => LoopL10n.current.common_securityCenter,
  'devices' => LoopL10n.current.coreNavigation_routeDevices,
  'key-export' => LoopL10n.current.coreNavigation_routeKeyExport,
  'social-recovery' => LoopL10n.current.coreNavigation_routeSocialRecovery,
  'notif-settings' => LoopL10n.current.common_notificationSettings,
  'connections' => LoopL10n.current.coreNavigation_routeConnections,
  'referral' => LoopL10n.current.coreNavigation_routeReferral,
  'blocklist' => LoopL10n.current.common_blockList,
  'settings' => LoopL10n.current.coreNavigation_routeSettings,
  'about' => LoopL10n.current.coreNavigation_routeAbout,
  'support' => LoopL10n.current.coreNavigation_routeSupport,
  'user-profile' => LoopL10n.current.coreNavigation_routeUserProfile,
  'beta-feedback' => LoopL10n.current.coreNavigation_routeBetaFeedback,
  'beta-feedback-mine' => LoopL10n.current.coreNavigation_routeBetaFeedbackMine,
  'offline' => LoopL10n.current.coreNavigation_routeOffline,
  'server-error' => LoopL10n.current.coreNavigation_routeServerError,
  'maintenance' => LoopL10n.current.coreNavigation_routeMaintenance,
  'permission-notice' => LoopL10n.current.coreNavigation_routePermissionNotice,
  'toast-states' => LoopL10n.current.coreNavigation_routeToastStates,
  'skeleton-states' => LoopL10n.current.coreNavigation_routeSkeletonStates,
  'token-card-states' => LoopL10n.current.coreNavigation_routeTokenCardStates,
  'sign-sheet-states' => LoopL10n.current.coreNavigation_routeSignSheetStates,
  _ => slug,
};

@immutable
final class LoopRouteEntry {
  const LoopRouteEntry({
    required this.slug,
    required this.path,
    required this.module,
    required this.prototypeOrder,
    required this.step,
    required this.status,
    this.tab = false,
    this.legacyPath,
  });

  /// Prototype hash, e.g. `community-members` for `loop-v2.html#community-members`.
  final String slug;

  /// The unique go_router location for this slug.
  final String path;

  final LoopRouteModule module;

  /// Page name from the handover appendix (01 document, chapter 13), in the
  /// current App language (decision 0281).
  String get title => loopRouteTitle(slug);

  /// Position inside the frozen prototype.
  final int prototypeOrder;

  /// Implementation step that owns the page (`LOOP/docs/01-实施方案.md`).
  final int step;

  final LoopRouteStatus status;

  /// Whether this route is one of the five primary destinations.
  final bool tab;

  /// A previously mounted location for the same page. History only.
  final String? legacyPath;

  /// Prototype section id used for restoration (`<section id="scr-<slug>">`).
  String get prototypeSectionId => 'scr-$slug';
}

abstract final class LoopRouteManifest {
  static const String frozenAt = '2026-10-08';
  static const String source = 'https://cliview.org/loop-v2.html';

  /// The frozen prototype the first 93 slugs were restored from.
  static const String prototypeSha256 =
      'bdbe183286c2d77c0de7f731818d5a8da9702ef08ed9a558a5189609c8b33c1a';

  /// SHA-256 of the manifest's own canonical content (`sha256Basis` in the
  /// JSON); `scripts/check_harness.py` recomputes it.
  static const String sha256 =
      '88752f588ba92029eeb73d93337f668792f8fa6da3f816537469218516383d8a';

  /// Post-login and illegal-route landing slug (v3, decision 0110; MEME
  /// since decision 0221).
  static const String defaultSlug = 'meme';
  static const String defaultPath = '/meme';

  /// The five primary destinations in their fixed order (v3, decision 0110).
  /// The four destinations they replaced — `community`, `mining`, `launch`
  /// and `market` — stay mounted as ordinary pages.
  static const List<String> tabSlugs = <String>[
    'chat',
    'square',
    'meme',
    'intel',
    'wallet',
  ];

  /// Compatibility redirects for installed clients. These are the only
  /// retired locations that stay mounted, and only as redirects.
  static const Map<String, String> compatibilityRedirects = <String, String>{
    '/home': '/meme',
    '/launchpad': '/launch',
  };

  /// Retired locations the product still knowingly emits until their
  /// replacement lands; the router records them as `info`, not `error`.
  /// `/notifications`: the notification router's system-notice intent stays on
  /// the legacy location until step 5 (D14) delivers the in-context notice.
  /// `/profile/social-privacy`: the V1 social-privacy resource was retired by
  /// the V2 privacy resource (step 2); the location stays recorded as info
  /// until the remaining chat surfaces stop linking to it.
  /// `/profile/friends` and `/chat/friends/add`: the V1 friend list and the
  /// alias search were folded into `search` + `connections` in step 3; the
  /// two locations stay recorded as info while installed clients may still
  /// emit them.
  /// `/chat/friends/requests` and `/chat/channel/:cid/alias`: step 4 folded
  /// the V1 friend-request page into `dm-requests` and the CID-addressed
  /// alias entry into `group-info`, which resolves the LOOP group itself.
  static const List<String> informationalRetiredPaths = <String>[
    '/notifications',
    '/profile/social-privacy',
    '/profile/friends',
    '/chat/friends/add',
    '/chat/friends/requests',
    '/chat/channel/:cid/alias',
  ];

  static final RegExp _retiredChannelAliasPattern = RegExp(
    r'^/chat/channel/[^/]+/alias$',
  );

  /// Whether one concrete unmatched location is a known retirement rather
  /// than an error. The parameterised `/chat/channel/:cid/alias` entry can
  /// never match a concrete path literally, so it is matched by shape.
  static bool isInformationalRetiredPath(String? path) {
    if (path == null) return false;
    return informationalRetiredPaths.contains(path) ||
        _retiredChannelAliasPattern.hasMatch(path);
  }

  /// Retired locations that must never be mounted again. Each resolves to the
  /// unmatched handler, is recorded in [LoopRoutingErrorLog] and lands on
  /// [defaultPath].
  static const List<String> retiredPaths = <String>[
    '/onboarding',
    '/notifications',
    '/onramp',
    '/pay/receive',
    '/pay/confirm',
    '/auth/wallet/seed',
    '/auth/wallet/seed/verify',
    '/auth/wallet/import',
    '/auth/profile',
    '/profile/recovery',
    '/profile/copy',
    '/profile/rewards',
    '/home/net-worth',
    '/home/security',
    '/perp',
    '/perp/trade',
    '/perp/confirm',
    '/perp/positions',
    '/perp/position',
    '/perp/orders',
    '/perp/history',
    '/perp/account',
    '/perp/transfer',
    '/perp/deposit',
    '/perp/funding',
    '/perp/risk',
    '/chat/meeting',
    '/wallet/transaction',
    // Step 6 moved `approval-guard` under `/wallet` and retired the local
    // signing review with the Preview intents that fed it.
    '/preview/approval',
    '/preview/signing-review',
    '/wallet/dapps',
    '/wallet/protection',
    '/launchpad/list',
    '/launchpad/detail',
    '/launchpad/apply',
    '/inventory',
  ];

  /// Implemented entry points that have no slug in the frozen manifest but
  /// are still reachable from mounted product code (the Stream channel deep
  /// link, group creation and the group-Alias editor, and guarded chat
  /// component previews). They stay mounted until the owning step folds them
  /// into a
  /// manifest page; the manifest test lists them explicitly so nothing else
  /// can hide here. `/chat/channel/:cid` is a redirect only: it resolves a
  /// server-issued CID onto `community-chat`, `dm` or `group`.
  static const List<String> supplementaryPaths = <String>[
    '/chat/channel/:cid',
    '/chat/groups/create',
    '/chat/groups/:groupId/alias',
    '/preview/contract-facts',
    '/preview/asset-message',
    '/preview/token-card',
  ];

  static const List<LoopRouteEntry> entries = <LoopRouteEntry>[
    // 0-global-account · 全局与账户 (12)
    LoopRouteEntry(
      slug: 'splash',
      path: '/splash',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 0,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth',
      path: '/auth',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 1,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth-otp',
      path: '/auth/otp',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 2,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth-wallet',
      path: '/auth/wallet',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 3,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallet-create',
      path: '/auth/wallet/create',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 4,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallet-recovery',
      path: '/auth/wallet/backup',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 5,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'security-setup',
      path: '/auth/security',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 6,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-id-setup',
      path: '/auth/loop-id',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 7,
      step: 2,
      status: LoopRouteStatus.implemented,
      legacyPath: '/auth/profile',
    ),
    LoopRouteEntry(
      slug: 'force-update',
      path: '/system/update',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 8,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'region-blocked',
      path: '/system/region',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 9,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    // S109a (decision 0112): the one page after registration — recommended
    // communities, five ticked, every joined chat muted.
    LoopRouteEntry(
      slug: 'onboarding-communities',
      path: '/auth/communities',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 105,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    // S324 (decision 0254, UX-002): 使用邮箱登录 is its own step between
    // `auth` and `auth-otp`.
    LoopRouteEntry(
      slug: 'auth-email',
      path: '/auth/email',
      module: LoopRouteModule.globalAccount,
      prototypeOrder: 128,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    // 2-community · Community (21)
    LoopRouteEntry(
      slug: 'search',
      path: '/search',
      module: LoopRouteModule.community,
      prototypeOrder: 11,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community',
      path: '/community',
      module: LoopRouteModule.community,
      prototypeOrder: 13,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-discover',
      path: '/community/discover',
      module: LoopRouteModule.community,
      prototypeOrder: 14,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-profile',
      path: '/community/profile',
      module: LoopRouteModule.community,
      prototypeOrder: 15,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-chat',
      path: '/community/chat',
      module: LoopRouteModule.community,
      prototypeOrder: 16,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-ai',
      path: '/community/ai',
      module: LoopRouteModule.community,
      prototypeOrder: 17,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-members',
      path: '/community/members',
      module: LoopRouteModule.community,
      prototypeOrder: 18,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'voiceroom',
      path: '/chat/voice',
      module: LoopRouteModule.community,
      prototypeOrder: 19,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'voiceroom-full',
      path: '/chat/voice/full',
      module: LoopRouteModule.community,
      prototypeOrder: 20,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dm',
      path: '/chat/dm',
      module: LoopRouteModule.community,
      prototypeOrder: 21,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dm-requests',
      path: '/chat/requests',
      module: LoopRouteModule.community,
      prototypeOrder: 22,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'group',
      path: '/chat/group',
      module: LoopRouteModule.community,
      prototypeOrder: 23,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'group-info',
      path: '/chat/group-info',
      module: LoopRouteModule.community,
      prototypeOrder: 24,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-search',
      path: '/chat/search',
      module: LoopRouteModule.community,
      prototypeOrder: 25,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-forward',
      path: '/chat/forward',
      module: LoopRouteModule.community,
      prototypeOrder: 90,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-merge-preview',
      path: '/chat/merge-preview',
      module: LoopRouteModule.community,
      prototypeOrder: 91,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat',
      path: '/chat',
      module: LoopRouteModule.community,
      prototypeOrder: 100,
      step: 3,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'square',
      path: '/square',
      module: LoopRouteModule.community,
      prototypeOrder: 101,
      step: 3,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    // S109b (decision 0113): the QR scanner opened from 聊天 ＋, and the
    // community manage center opened from the record's 管理 action.
    LoopRouteEntry(
      slug: 'scan',
      path: '/scan',
      module: LoopRouteModule.community,
      prototypeOrder: 106,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-manage',
      path: '/community/manage',
      module: LoopRouteModule.community,
      prototypeOrder: 107,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    // S287 (decision 0241): 通知中心, a child page of 聊天. It is not the
    // retired `/notifications` Home-era centre, which stays retired.
    LoopRouteEntry(
      slug: 'notifications',
      path: '/chat/notifications',
      module: LoopRouteModule.community,
      prototypeOrder: 127,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    // 3-market · Market (10)
    LoopRouteEntry(
      slug: 'market',
      path: '/market',
      module: LoopRouteModule.market,
      prototypeOrder: 26,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token',
      path: '/market/token',
      module: LoopRouteModule.market,
      prototypeOrder: 27,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chart-full',
      path: '/market/chart',
      module: LoopRouteModule.market,
      prototypeOrder: 28,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-holders',
      path: '/market/holders',
      module: LoopRouteModule.market,
      prototypeOrder: 29,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-trades',
      path: '/market/trades',
      module: LoopRouteModule.market,
      prototypeOrder: 30,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'watchlist-edit',
      path: '/market/watchlist',
      module: LoopRouteModule.market,
      prototypeOrder: 31,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'alerts',
      path: '/market/alerts',
      module: LoopRouteModule.market,
      prototypeOrder: 32,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'new-pairs',
      path: '/market/new',
      module: LoopRouteModule.market,
      prototypeOrder: 33,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'smart-money',
      path: '/market/smart-money',
      module: LoopRouteModule.market,
      prototypeOrder: 34,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'intel',
      path: '/intel',
      module: LoopRouteModule.market,
      prototypeOrder: 103,
      step: 5,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    // 4-launch · Launch (17)
    LoopRouteEntry(
      slug: 'launch',
      path: '/launch',
      module: LoopRouteModule.launch,
      prototypeOrder: 35,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-detail',
      path: '/launch/detail',
      module: LoopRouteModule.launch,
      prototypeOrder: 36,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-tier',
      path: '/launch/tier',
      module: LoopRouteModule.launch,
      prototypeOrder: 37,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-stake',
      path: '/launch/loop-stake',
      module: LoopRouteModule.launch,
      prototypeOrder: 38,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-trade',
      path: '/launch/trade',
      module: LoopRouteModule.launch,
      prototypeOrder: 39,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-holders',
      path: '/launch/holders',
      module: LoopRouteModule.launch,
      prototypeOrder: 40,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-graduation',
      path: '/launch/graduation',
      module: LoopRouteModule.launch,
      prototypeOrder: 41,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-history',
      path: '/launch/history',
      module: LoopRouteModule.launch,
      prototypeOrder: 42,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-rounds',
      path: '/launch/rounds',
      module: LoopRouteModule.launch,
      prototypeOrder: 43,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-economy',
      path: '/launch/loop-economy',
      module: LoopRouteModule.launch,
      prototypeOrder: 44,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-apply',
      path: '/launch/apply',
      module: LoopRouteModule.launch,
      prototypeOrder: 45,
      step: 7,
      status: LoopRouteStatus.implemented,
      legacyPath: '/launchpad/apply',
    ),
    LoopRouteEntry(
      slug: 'meme',
      path: '/meme',
      module: LoopRouteModule.launch,
      prototypeOrder: 102,
      step: 7,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    // S117 (decision 0120): the MEME curve launchpad's create flow, token
    // page and the token's two full lists.
    LoopRouteEntry(
      slug: 'meme-create',
      path: '/meme/create',
      module: LoopRouteModule.launch,
      prototypeOrder: 108,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'meme-token',
      path: '/meme/token',
      module: LoopRouteModule.launch,
      prototypeOrder: 109,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'meme-token-holders',
      path: '/meme/token/holders',
      module: LoopRouteModule.launch,
      prototypeOrder: 110,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'meme-token-trades',
      path: '/meme/token/trades',
      module: LoopRouteModule.launch,
      prototypeOrder: 111,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // S135 (decision 0138): the MEME v2 project side — 资料 → 审核 →
    // 签名 → 部署 → 激活.
    LoopRouteEntry(
      slug: 'launch2-create',
      path: '/launch2/create',
      module: LoopRouteModule.launch,
      prototypeOrder: 120,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch2-projects',
      path: '/launch2/projects/mine',
      module: LoopRouteModule.launch,
      prototypeOrder: 121,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch2-project',
      path: '/launch2/project',
      module: LoopRouteModule.launch,
      prototypeOrder: 122,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch2-project-sign',
      path: '/launch2/project/sign',
      module: LoopRouteModule.launch,
      prototypeOrder: 123,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch2-project-deployment',
      path: '/launch2/project/deployment',
      module: LoopRouteModule.launch,
      prototypeOrder: 124,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // S136 (decision 0139): the MEME v2 project page, one page for every
    // stage of an instance.
    LoopRouteEntry(
      slug: 'launch2-instance',
      path: '/launch2/instance',
      module: LoopRouteModule.launch,
      prototypeOrder: 112,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // S168 (decision 0157): 外盘奖励 of one LoopDynamic instance.
    LoopRouteEntry(
      slug: 'launch2-dynamic-rewards',
      path: '/launch2/dynamic-rewards',
      module: LoopRouteModule.launch,
      prototypeOrder: 125,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // S180 (decision 0163): 共识勋章, one instance's NFT mint page.
    LoopRouteEntry(
      slug: 'launch2-nft',
      path: '/launch2/nft',
      module: LoopRouteModule.launch,
      prototypeOrder: 126,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // 5-mining · Mining (6)
    LoopRouteEntry(
      slug: 'mining',
      path: '/mining',
      module: LoopRouteModule.mining,
      prototypeOrder: 46,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-assets',
      path: '/mining/assets',
      module: LoopRouteModule.mining,
      prototypeOrder: 47,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rewards',
      path: '/mining/rewards',
      module: LoopRouteModule.mining,
      prototypeOrder: 48,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rank',
      path: '/mining/rank',
      module: LoopRouteModule.mining,
      prototypeOrder: 49,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-community',
      path: '/mining/community',
      module: LoopRouteModule.mining,
      prototypeOrder: 50,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rules',
      path: '/mining/rules',
      module: LoopRouteModule.mining,
      prototypeOrder: 51,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // 6-wallet · Wallet (19)
    LoopRouteEntry(
      slug: 'wallet',
      path: '/wallet',
      module: LoopRouteModule.wallet,
      prototypeOrder: 52,
      step: 5,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'networth',
      path: '/wallet/networth',
      module: LoopRouteModule.wallet,
      prototypeOrder: 10,
      step: 5,
      status: LoopRouteStatus.implemented,
      legacyPath: '/home/net-worth',
    ),
    LoopRouteEntry(
      slug: 'pay',
      path: '/pay',
      module: LoopRouteModule.wallet,
      prototypeOrder: 12,
      step: 8,
      status: LoopRouteStatus.unavailable,
    ),
    LoopRouteEntry(
      slug: 'asset',
      path: '/wallet/asset',
      module: LoopRouteModule.wallet,
      prototypeOrder: 53,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send',
      path: '/wallet/send',
      module: LoopRouteModule.wallet,
      prototypeOrder: 54,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send-to',
      path: '/wallet/send/to',
      module: LoopRouteModule.wallet,
      prototypeOrder: 55,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send-confirm',
      path: '/wallet/send/confirm',
      module: LoopRouteModule.wallet,
      prototypeOrder: 56,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'receive',
      path: '/wallet/receive',
      module: LoopRouteModule.wallet,
      prototypeOrder: 57,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'swap',
      path: '/wallet/swap',
      module: LoopRouteModule.wallet,
      prototypeOrder: 58,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'swap-route',
      path: '/wallet/swap/route',
      module: LoopRouteModule.wallet,
      prototypeOrder: 59,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'bridge',
      path: '/wallet/bridge',
      module: LoopRouteModule.wallet,
      prototypeOrder: 60,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'bridge-status',
      path: '/wallet/bridge/status',
      module: LoopRouteModule.wallet,
      prototypeOrder: 61,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'tx-result',
      path: '/wallet/tx/result',
      module: LoopRouteModule.wallet,
      prototypeOrder: 62,
      step: 6,
      status: LoopRouteStatus.implemented,
      legacyPath: '/wallet/transaction',
    ),
    LoopRouteEntry(
      slug: 'tx-history',
      path: '/wallet/history',
      module: LoopRouteModule.wallet,
      prototypeOrder: 63,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallets',
      path: '/wallet/manage',
      module: LoopRouteModule.wallet,
      prototypeOrder: 64,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dapp',
      path: '/wallet/dapp',
      module: LoopRouteModule.wallet,
      prototypeOrder: 65,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dapp-web',
      path: '/wallet/dapp/web',
      module: LoopRouteModule.wallet,
      prototypeOrder: 131,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'approval-guard',
      path: '/wallet/approval-guard',
      module: LoopRouteModule.wallet,
      prototypeOrder: 66,
      step: 6,
      status: LoopRouteStatus.implemented,
      legacyPath: '/preview/approval',
    ),
    LoopRouteEntry(
      slug: 'approvals',
      path: '/wallet/approvals',
      module: LoopRouteModule.wallet,
      prototypeOrder: 67,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'networks',
      path: '/wallet/networks',
      module: LoopRouteModule.wallet,
      prototypeOrder: 68,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    // 7-profile · Profile / LOOP ID (17)
    LoopRouteEntry(
      slug: 'profile',
      path: '/profile',
      module: LoopRouteModule.profile,
      prototypeOrder: 69,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'profile-edit',
      path: '/profile/edit',
      module: LoopRouteModule.profile,
      prototypeOrder: 70,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'privacy',
      path: '/profile/privacy',
      module: LoopRouteModule.profile,
      prototypeOrder: 71,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'security',
      path: '/profile/security',
      module: LoopRouteModule.profile,
      prototypeOrder: 72,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'devices',
      path: '/profile/devices',
      module: LoopRouteModule.profile,
      prototypeOrder: 73,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'key-export',
      path: '/profile/key-export',
      module: LoopRouteModule.profile,
      prototypeOrder: 74,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'social-recovery',
      path: '/profile/social-recovery',
      module: LoopRouteModule.profile,
      prototypeOrder: 75,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'notif-settings',
      path: '/profile/notifications',
      module: LoopRouteModule.profile,
      prototypeOrder: 76,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'connections',
      path: '/profile/connections',
      module: LoopRouteModule.profile,
      prototypeOrder: 77,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'referral',
      path: '/profile/referral',
      module: LoopRouteModule.profile,
      prototypeOrder: 92,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'blocklist',
      path: '/profile/blocked',
      module: LoopRouteModule.profile,
      prototypeOrder: 78,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'settings',
      path: '/profile/settings',
      module: LoopRouteModule.profile,
      prototypeOrder: 79,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'about',
      path: '/profile/about',
      module: LoopRouteModule.profile,
      prototypeOrder: 80,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'support',
      path: '/profile/help',
      module: LoopRouteModule.profile,
      prototypeOrder: 81,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    // S109a (decision 0112): another account's profile — `?id=` or, from a
    // `/u/{loopId}` link, `?loopId=`.
    LoopRouteEntry(
      slug: 'user-profile',
      path: '/profile/user',
      module: LoopRouteModule.profile,
      prototypeOrder: 104,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    // S332 (decision 0262): the internal-test feedback form, opened from the
    // floating 意见反馈 entry inside the five-tab shell, and the account's
    // own feedback list. Both stay closed unless `LOOP_BETA_FEEDBACK` is on.
    LoopRouteEntry(
      slug: 'beta-feedback',
      path: '/beta-feedback',
      module: LoopRouteModule.profile,
      prototypeOrder: 129,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'beta-feedback-mine',
      path: '/beta-feedback/mine',
      module: LoopRouteModule.profile,
      prototypeOrder: 130,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    // 8-system · 系统态与组件 (8)
    LoopRouteEntry(
      slug: 'offline',
      path: '/system/offline',
      module: LoopRouteModule.system,
      prototypeOrder: 82,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'server-error',
      path: '/system/error',
      module: LoopRouteModule.system,
      prototypeOrder: 83,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'maintenance',
      path: '/system/maintenance',
      module: LoopRouteModule.system,
      prototypeOrder: 84,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'permission-notice',
      path: '/system/permission',
      module: LoopRouteModule.system,
      prototypeOrder: 85,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'toast-states',
      path: '/preview/toast',
      module: LoopRouteModule.system,
      prototypeOrder: 86,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'skeleton-states',
      path: '/preview/loading',
      module: LoopRouteModule.system,
      prototypeOrder: 87,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-card-states',
      path: '/system/token-card',
      module: LoopRouteModule.system,
      prototypeOrder: 88,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'sign-sheet-states',
      path: '/system/sign-sheet',
      module: LoopRouteModule.system,
      prototypeOrder: 89,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
  ];

  static final Map<String, LoopRouteEntry> _bySlug = <String, LoopRouteEntry>{
    for (final entry in entries) entry.slug: entry,
  };

  static final Map<String, LoopRouteEntry> _byPath = <String, LoopRouteEntry>{
    for (final entry in entries) entry.path: entry,
  };

  static LoopRouteEntry bySlug(String slug) {
    final entry = _bySlug[slug];
    if (entry == null) {
      throw ArgumentError.value(slug, 'slug', 'Unknown manifest slug');
    }
    return entry;
  }

  static LoopRouteEntry? byPath(String path) => _byPath[path];

  /// go_router location for [slug].
  static String pathFor(String slug) => bySlug(slug).path;

  static List<LoopRouteEntry> get tabEntries =>
      tabSlugs.map(bySlug).toList(growable: false);

  static List<String> get tabPaths =>
      tabEntries.map((entry) => entry.path).toList(growable: false);

  static List<LoopRouteEntry> forModule(LoopRouteModule module) =>
      entries.where((entry) => entry.module == module).toList(growable: false);

  static List<LoopRouteEntry> withStatus(LoopRouteStatus status) =>
      entries.where((entry) => entry.status == status).toList(growable: false);

  static bool isTabPath(String path) => tabPaths.contains(path);
}
