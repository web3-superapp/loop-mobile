/// The 93-route product manifest.
///
/// Source of truth: `docs/product/routes-manifest.json` (mirror of
/// `LOOP/docs/routes-manifest.json`, frozen 2026-09-01 from the cliview.org
/// `loop-v2.html` build, SHA-256 `bdbe1832…`). `test/route_manifest_test.dart`
/// asserts that this table and the JSON agree on slug, module, tab flag and
/// prototype order, and that `lib/app.dart` mounts exactly these paths.
///
/// Every slug maps to exactly one go_router path. Paths that were already
/// implemented before the manifest keep their location to avoid needless
/// migration; the retired location, when one existed, is kept in
/// [LoopRouteEntry.legacyPath] for history only and is never mounted.
library;

import 'package:flutter/foundation.dart';

/// Product module of the frozen information architecture. Module `1` was
/// retired with Home; the gap is intentional and must not be filled.
enum LoopRouteModule {
  globalAccount('0-global-account', '全局与账户'),
  community('2-community', 'Community'),
  market('3-market', 'Market'),
  launch('4-launch', 'Launch'),
  mining('5-mining', 'Mining'),
  wallet('6-wallet', 'Wallet'),
  profile('7-profile', 'Profile / LOOP ID'),
  system('8-system', '系统态与组件');

  const LoopRouteModule(this.manifestKey, this.label);

  /// Key used in `routes-manifest.json`.
  final String manifestKey;

  /// Human label used by the pending surface and reports.
  final String label;
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

@immutable
final class LoopRouteEntry {
  const LoopRouteEntry({
    required this.slug,
    required this.path,
    required this.module,
    required this.title,
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

  /// Page name from the handover appendix (01 document, chapter 13).
  final String title;

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
  static const String frozenAt = '2026-09-01';
  static const String source = 'https://cliview.org/loop-v2.html';
  static const String sha256 =
      'bdbe183286c2d77c0de7f731818d5a8da9702ef08ed9a558a5189609c8b33c1a';

  /// Post-login and illegal-route landing slug.
  static const String defaultSlug = 'community';
  static const String defaultPath = '/community';

  /// The five primary destinations in their fixed order.
  static const List<String> tabSlugs = <String>[
    'community',
    'mining',
    'launch',
    'market',
    'wallet',
  ];

  /// Compatibility redirects for installed clients. These are the only
  /// retired locations that stay mounted, and only as redirects.
  static const Map<String, String> compatibilityRedirects = <String, String>{
    '/home': '/community',
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
    '/chat',
    '/chat/channel/:cid',
    '/chat/groups/create',
    '/chat/groups/:groupId/alias',
    '/preview/contract-facts',
    '/preview/asset-message',
    '/preview/token-card',
  ];

  static const List<LoopRouteEntry> entries = <LoopRouteEntry>[
    // 0-global-account · 全局与账户 (10)
    LoopRouteEntry(
      slug: 'splash',
      path: '/splash',
      module: LoopRouteModule.globalAccount,
      title: '启动闪屏',
      prototypeOrder: 0,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth',
      path: '/auth',
      module: LoopRouteModule.globalAccount,
      title: 'Privy 登录',
      prototypeOrder: 1,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth-otp',
      path: '/auth/otp',
      module: LoopRouteModule.globalAccount,
      title: '邮箱验证码',
      prototypeOrder: 2,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'auth-wallet',
      path: '/auth/wallet',
      module: LoopRouteModule.globalAccount,
      title: '连接外部钱包',
      prototypeOrder: 3,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallet-create',
      path: '/auth/wallet/create',
      module: LoopRouteModule.globalAccount,
      title: '钱包生成中',
      prototypeOrder: 4,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallet-recovery',
      path: '/auth/wallet/backup',
      module: LoopRouteModule.globalAccount,
      title: '恢复方式设置',
      prototypeOrder: 5,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'security-setup',
      path: '/auth/security',
      module: LoopRouteModule.globalAccount,
      title: 'MFA 与应用锁',
      prototypeOrder: 6,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-id-setup',
      path: '/auth/loop-id',
      module: LoopRouteModule.globalAccount,
      title: '生成 LOOP ID',
      prototypeOrder: 7,
      step: 2,
      status: LoopRouteStatus.implemented,
      legacyPath: '/auth/profile',
    ),
    LoopRouteEntry(
      slug: 'force-update',
      path: '/system/update',
      module: LoopRouteModule.globalAccount,
      title: '强制更新',
      prototypeOrder: 8,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'region-blocked',
      path: '/system/region',
      module: LoopRouteModule.globalAccount,
      title: '地区限制',
      prototypeOrder: 9,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    // 2-community · Community (16)
    LoopRouteEntry(
      slug: 'search',
      path: '/search',
      module: LoopRouteModule.community,
      title: '全局搜索',
      prototypeOrder: 11,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community',
      path: '/community',
      module: LoopRouteModule.community,
      title: '社区 Tab',
      prototypeOrder: 13,
      step: 3,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'community-discover',
      path: '/community/discover',
      module: LoopRouteModule.community,
      title: '发现社区',
      prototypeOrder: 14,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-profile',
      path: '/community/profile',
      module: LoopRouteModule.community,
      title: '社区主页',
      prototypeOrder: 15,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-chat',
      path: '/community/chat',
      module: LoopRouteModule.community,
      title: '社区大群',
      prototypeOrder: 16,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-ai',
      path: '/community/ai',
      module: LoopRouteModule.community,
      title: 'Community AI',
      prototypeOrder: 17,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'community-members',
      path: '/community/members',
      module: LoopRouteModule.community,
      title: '成员与权限',
      prototypeOrder: 18,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'voiceroom',
      path: '/chat/voice',
      module: LoopRouteModule.community,
      title: '语音房',
      prototypeOrder: 19,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'voiceroom-full',
      path: '/chat/voice/full',
      module: LoopRouteModule.community,
      title: '语音房完整视图',
      prototypeOrder: 20,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dm',
      path: '/chat/dm',
      module: LoopRouteModule.community,
      title: '私聊',
      prototypeOrder: 21,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dm-requests',
      path: '/chat/requests',
      module: LoopRouteModule.community,
      title: '陌生人请求',
      prototypeOrder: 22,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'group',
      path: '/chat/group',
      module: LoopRouteModule.community,
      title: '普通群聊',
      prototypeOrder: 23,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'group-info',
      path: '/chat/group-info',
      module: LoopRouteModule.community,
      title: '群信息',
      prototypeOrder: 24,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-search',
      path: '/chat/search',
      module: LoopRouteModule.community,
      title: '消息搜索',
      prototypeOrder: 25,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-forward',
      path: '/chat/forward',
      module: LoopRouteModule.community,
      title: '转发消息',
      prototypeOrder: 90,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chat-merge-preview',
      path: '/chat/merge-preview',
      module: LoopRouteModule.community,
      title: '合并转发预览',
      prototypeOrder: 91,
      step: 4,
      status: LoopRouteStatus.implemented,
    ),
    // 3-market · Market (9)
    LoopRouteEntry(
      slug: 'market',
      path: '/market',
      module: LoopRouteModule.market,
      title: '行情列表',
      prototypeOrder: 26,
      step: 5,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'token',
      path: '/market/token',
      module: LoopRouteModule.market,
      title: 'Token 详情',
      prototypeOrder: 27,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'chart-full',
      path: '/market/chart',
      module: LoopRouteModule.market,
      title: '全屏 K 线',
      prototypeOrder: 28,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-holders',
      path: '/market/holders',
      module: LoopRouteModule.market,
      title: '持有人分布',
      prototypeOrder: 29,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-trades',
      path: '/market/trades',
      module: LoopRouteModule.market,
      title: '交易活动',
      prototypeOrder: 30,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'watchlist-edit',
      path: '/market/watchlist',
      module: LoopRouteModule.market,
      title: '自选管理',
      prototypeOrder: 31,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'alerts',
      path: '/market/alerts',
      module: LoopRouteModule.market,
      title: '价格提醒',
      prototypeOrder: 32,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'new-pairs',
      path: '/market/new',
      module: LoopRouteModule.market,
      title: '新币发现',
      prototypeOrder: 33,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'smart-money',
      path: '/market/smart-money',
      module: LoopRouteModule.market,
      title: '聪明钱追踪',
      prototypeOrder: 34,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    // 4-launch · Launch (11)
    LoopRouteEntry(
      slug: 'launch',
      path: '/launch',
      module: LoopRouteModule.launch,
      title: 'Launch 列表',
      prototypeOrder: 35,
      step: 7,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'launch-detail',
      path: '/launch/detail',
      module: LoopRouteModule.launch,
      title: '项目详情',
      prototypeOrder: 36,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-tier',
      path: '/launch/tier',
      module: LoopRouteModule.launch,
      title: '我的资格',
      prototypeOrder: 37,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-stake',
      path: '/launch/loop-stake',
      module: LoopRouteModule.launch,
      title: 'LOOP 质押',
      prototypeOrder: 38,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-trade',
      path: '/launch/trade',
      module: LoopRouteModule.launch,
      title: 'Launch 认购',
      prototypeOrder: 39,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-holders',
      path: '/launch/holders',
      module: LoopRouteModule.launch,
      title: '内盘持有人',
      prototypeOrder: 40,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-graduation',
      path: '/launch/graduation',
      module: LoopRouteModule.launch,
      title: '毕业与迁移',
      prototypeOrder: 41,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-history',
      path: '/launch/history',
      module: LoopRouteModule.launch,
      title: '参与记录',
      prototypeOrder: 42,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-rounds',
      path: '/launch/rounds',
      module: LoopRouteModule.launch,
      title: '销售轮次规则',
      prototypeOrder: 43,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'loop-economy',
      path: '/launch/loop-economy',
      module: LoopRouteModule.launch,
      title: '生态经济面板',
      prototypeOrder: 44,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'launch-apply',
      path: '/launch/apply',
      module: LoopRouteModule.launch,
      title: '申请发射',
      prototypeOrder: 45,
      step: 7,
      status: LoopRouteStatus.implemented,
      legacyPath: '/launchpad/apply',
    ),
    // 5-mining · Mining (6)
    LoopRouteEntry(
      slug: 'mining',
      path: '/mining',
      module: LoopRouteModule.mining,
      title: '我的挖矿',
      prototypeOrder: 46,
      step: 7,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'mining-assets',
      path: '/mining/assets',
      module: LoopRouteModule.mining,
      title: '算力明细',
      prototypeOrder: 47,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rewards',
      path: '/mining/rewards',
      module: LoopRouteModule.mining,
      title: '奖励与领取',
      prototypeOrder: 48,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rank',
      path: '/mining/rank',
      module: LoopRouteModule.mining,
      title: '排行榜',
      prototypeOrder: 49,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-community',
      path: '/mining/community',
      module: LoopRouteModule.mining,
      title: '社区挖矿面板',
      prototypeOrder: 50,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'mining-rules',
      path: '/mining/rules',
      module: LoopRouteModule.mining,
      title: '权重与价格保护',
      prototypeOrder: 51,
      step: 7,
      status: LoopRouteStatus.implemented,
    ),
    // 6-wallet · Wallet (19)
    LoopRouteEntry(
      slug: 'wallet',
      path: '/wallet',
      module: LoopRouteModule.wallet,
      title: '钱包总览',
      prototypeOrder: 52,
      step: 5,
      status: LoopRouteStatus.implemented,
      tab: true,
    ),
    LoopRouteEntry(
      slug: 'networth',
      path: '/wallet/networth',
      module: LoopRouteModule.wallet,
      title: '净值明细',
      prototypeOrder: 10,
      step: 5,
      status: LoopRouteStatus.implemented,
      legacyPath: '/home/net-worth',
    ),
    LoopRouteEntry(
      slug: 'pay',
      path: '/pay',
      module: LoopRouteModule.wallet,
      title: 'Pay 入口',
      prototypeOrder: 12,
      step: 8,
      status: LoopRouteStatus.unavailable,
    ),
    LoopRouteEntry(
      slug: 'asset',
      path: '/wallet/asset',
      module: LoopRouteModule.wallet,
      title: '资产详情',
      prototypeOrder: 53,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send',
      path: '/wallet/send',
      module: LoopRouteModule.wallet,
      title: '发送-选资产',
      prototypeOrder: 54,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send-to',
      path: '/wallet/send/to',
      module: LoopRouteModule.wallet,
      title: '发送-收款方',
      prototypeOrder: 55,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'send-confirm',
      path: '/wallet/send/confirm',
      module: LoopRouteModule.wallet,
      title: '发送-确认',
      prototypeOrder: 56,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'receive',
      path: '/wallet/receive',
      module: LoopRouteModule.wallet,
      title: '接收',
      prototypeOrder: 57,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'swap',
      path: '/wallet/swap',
      module: LoopRouteModule.wallet,
      title: 'Swap',
      prototypeOrder: 58,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'swap-route',
      path: '/wallet/swap/route',
      module: LoopRouteModule.wallet,
      title: '报价与费用',
      prototypeOrder: 59,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'bridge',
      path: '/wallet/bridge',
      module: LoopRouteModule.wallet,
      title: '跨链',
      prototypeOrder: 60,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'bridge-status',
      path: '/wallet/bridge/status',
      module: LoopRouteModule.wallet,
      title: '跨链进度',
      prototypeOrder: 61,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'tx-result',
      path: '/wallet/tx/result',
      module: LoopRouteModule.wallet,
      title: '交易结果',
      prototypeOrder: 62,
      step: 6,
      status: LoopRouteStatus.implemented,
      legacyPath: '/wallet/transaction',
    ),
    LoopRouteEntry(
      slug: 'tx-history',
      path: '/wallet/history',
      module: LoopRouteModule.wallet,
      title: '交易历史',
      prototypeOrder: 63,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'wallets',
      path: '/wallet/manage',
      module: LoopRouteModule.wallet,
      title: '多钱包管理',
      prototypeOrder: 64,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'dapp',
      path: '/wallet/dapp',
      module: LoopRouteModule.wallet,
      title: 'DApp 浏览器',
      prototypeOrder: 65,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'approval-guard',
      path: '/wallet/approval-guard',
      module: LoopRouteModule.wallet,
      title: '授权拦截',
      prototypeOrder: 66,
      step: 6,
      status: LoopRouteStatus.implemented,
      legacyPath: '/preview/approval',
    ),
    LoopRouteEntry(
      slug: 'approvals',
      path: '/wallet/approvals',
      module: LoopRouteModule.wallet,
      title: '授权盘点',
      prototypeOrder: 67,
      step: 6,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'networks',
      path: '/wallet/networks',
      module: LoopRouteModule.wallet,
      title: '网络与 RPC',
      prototypeOrder: 68,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    // 7-profile · Profile / LOOP ID (14)
    LoopRouteEntry(
      slug: 'profile',
      path: '/profile',
      module: LoopRouteModule.profile,
      title: 'LOOP ID 主页',
      prototypeOrder: 69,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'profile-edit',
      path: '/profile/edit',
      module: LoopRouteModule.profile,
      title: '编辑资料',
      prototypeOrder: 70,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'privacy',
      path: '/profile/privacy',
      module: LoopRouteModule.profile,
      title: '隐私中心',
      prototypeOrder: 71,
      step: 2,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'security',
      path: '/profile/security',
      module: LoopRouteModule.profile,
      title: '安全中心',
      prototypeOrder: 72,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'devices',
      path: '/profile/devices',
      module: LoopRouteModule.profile,
      title: '设备管理',
      prototypeOrder: 73,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'key-export',
      path: '/profile/key-export',
      module: LoopRouteModule.profile,
      title: '私钥导出',
      prototypeOrder: 74,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'social-recovery',
      path: '/profile/social-recovery',
      module: LoopRouteModule.profile,
      title: '社交恢复',
      prototypeOrder: 75,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'notif-settings',
      path: '/profile/notifications',
      module: LoopRouteModule.profile,
      title: '通知设置',
      prototypeOrder: 76,
      step: 5,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'connections',
      path: '/profile/connections',
      module: LoopRouteModule.profile,
      title: '关注与粉丝',
      prototypeOrder: 77,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'referral',
      path: '/profile/referral',
      module: LoopRouteModule.profile,
      title: '邀请关系与加成',
      prototypeOrder: 92,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'blocklist',
      path: '/profile/blocked',
      module: LoopRouteModule.profile,
      title: '屏蔽名单',
      prototypeOrder: 78,
      step: 3,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'settings',
      path: '/profile/settings',
      module: LoopRouteModule.profile,
      title: '通用设置',
      prototypeOrder: 79,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'about',
      path: '/profile/about',
      module: LoopRouteModule.profile,
      title: '关于与法务',
      prototypeOrder: 80,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'support',
      path: '/profile/help',
      module: LoopRouteModule.profile,
      title: '帮助与客服',
      prototypeOrder: 81,
      step: 8,
      status: LoopRouteStatus.implemented,
    ),
    // 8-system · 系统态与组件 (8)
    LoopRouteEntry(
      slug: 'offline',
      path: '/system/offline',
      module: LoopRouteModule.system,
      title: '无网络',
      prototypeOrder: 82,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'server-error',
      path: '/system/error',
      module: LoopRouteModule.system,
      title: '服务出错',
      prototypeOrder: 83,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'maintenance',
      path: '/system/maintenance',
      module: LoopRouteModule.system,
      title: '系统维护',
      prototypeOrder: 84,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'permission-notice',
      path: '/system/permission',
      module: LoopRouteModule.system,
      title: '权限申请说明',
      prototypeOrder: 85,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'toast-states',
      path: '/preview/toast',
      module: LoopRouteModule.system,
      title: 'Toast 三态',
      prototypeOrder: 86,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'skeleton-states',
      path: '/preview/loading',
      module: LoopRouteModule.system,
      title: '骨架屏三类',
      prototypeOrder: 87,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'token-card-states',
      path: '/system/token-card',
      module: LoopRouteModule.system,
      title: 'Token Card 五态',
      prototypeOrder: 88,
      step: 1,
      status: LoopRouteStatus.implemented,
    ),
    LoopRouteEntry(
      slug: 'sign-sheet-states',
      path: '/system/sign-sheet',
      module: LoopRouteModule.system,
      title: '签名弹层四态',
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
