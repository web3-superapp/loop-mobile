// S355b · decision 0281: English renders of the Launch (IDO), Square and
// DApp pages at 360 wide, to read truncation, overflow and wrapping.
//
// Not a check: it writes renders to build/s355b-shots (or `LOOP_SHOTS_DIR`).
// It runs only with `--dart-define=LOOP_SHOTS=true`; a plain `flutter test`
// skips every case and writes nothing.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/dapp/dapp_browser_screens.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s342_dapp_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'build/s355b-shots',
);

/// 360 wide; three 800-high slices so a long page is read top to bottom.
const Size _tall = Size(360, 2400);
const Size _phone = Size(360, 800);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 800, dir: _dir);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Future<void> _settleArt(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Launch (IDO)
// ---------------------------------------------------------------------------

FakeLaunchGateway _launch() => FakeLaunchGateway(
  detail: S7Answer<LaunchDetail>(value: s83cDetail()),
  eligibility: S7Answer<LaunchEligibility>(value: s83cEligibility()),
  holders: S7Answer<LaunchHolders>(value: s83cHolders()),
  history: S7Answer<LaunchHistory>(value: s83cHistory()),
);

Future<void> _pumpLaunch(WidgetTester tester, Widget page) async {
  await pumpS7Page(
    tester,
    page,
    launch: _launch(),
    size: _tall,
    wallet: FakeWalletDirectory(
      activeWalletId: s7WalletId,
      wallets: [s83cWallet()],
      balances: [s83cBalances()],
    ),
  );
  await _settleArt(tester);
}

// ---------------------------------------------------------------------------
// Square
// ---------------------------------------------------------------------------

final DateTime _now = DateTime.now().toUtc();

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

SquareFeedToken _token(String symbol) => SquareFeedToken(
  kind: SquareFeedTokenKind.meme,
  memeTokenId: _uuid(symbol.hashCode.abs() % 1000 + 100),
  symbol: symbol,
  priceUsd1: Decimal.parse('0.00004173'),
  change1hPct: Decimal.parse('14.4'),
  marketCapUsd1: Decimal.parse('666700'),
);

SquareFeedPost _post(
  int n, {
  SquareFeedPostKind kind = SquareFeedPostKind.opinion,
  String? text,
  SquareFeedToken? token,
  Map<String, String> event = const <String, String>{},
  bool pinned = false,
  int minutes = 3,
}) => SquareFeedPost(
  postId: _uuid(n),
  kind: kind,
  author: kind == SquareFeedPostKind.system
      ? null
      : SquareFeedAuthor(
          publicProfileId: 'pp_author$n',
          loopId: 'LOOP-AUTHOR$n',
          alias: 'pollak',
        ),
  text: text,
  token: token,
  event: event,
  likeCount: 3,
  likedByViewer: false,
  pinned: pinned,
  createdAt: _now.subtract(Duration(minutes: minutes)),
);

List<SquareFeedPost> _feedRows() => <SquareFeedPost>[
  _post(
    1,
    kind: SquareFeedPostKind.system,
    text: 'Weekly power snapshot is out.',
    pinned: true,
    minutes: 300,
  ),
  _post(2, text: 'Bottom in.', token: _token('FROG')),
  _post(
    3,
    kind: SquareFeedPostKind.graduation,
    token: _token('MOON'),
    minutes: 42,
  ),
  _post(
    4,
    kind: SquareFeedPostKind.claim,
    token: _token('CAT'),
    event: const <String, String>{
      'amountUsd1': '12.5',
      'roundId': '2',
      'weightPct': '3.25',
    },
    minutes: 60 * 24 * 40,
  ),
  _post(
    5,
    kind: SquareFeedPostKind.buy,
    event: const <String, String>{'amountUsd1': '250'},
    token: _token('DOGE'),
    minutes: 90,
  ),
];

final class _Feed implements SquareFeedGateway {
  _Feed(this.items);

  final List<SquareFeedPost> items;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) =>
      Future<SquareFeedPage>.value(
        SquareFeedPage(
          scope: scope,
          items: items,
          nextCursor: null,
          observedAt: _now,
        ),
      );

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) =>
      Completer<SquareFeedLike>().future;
}

LoopV2MetaSnapshot _feedMeta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.squareFeed)
            LoopV2Capability(
              id: capability.id,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

String _cid(int index) =>
    '4b96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}';

const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

CommunitySummary _community(
  int index,
  String name,
  String description, {
  String? symbol,
  CommunityDirectoryViewer viewer = CommunityDirectoryViewer.none,
  int members = 28,
}) => CommunitySummary(
  communityId: _cid(index),
  name: name,
  slug: 'c$index',
  description: description,
  logoRef: 'avatar:preset/community-0${index % 9 + 1}',
  verificationStatus: CommunityVerification.verified,
  boundAssetKey: symbol == null ? null : _assetId,
  memberCount: members,
  createdAt: DateTime.utc(2026, 6),
  configVersion: 'communityV1',
  assetBadge: symbol == null
      ? null
      : CommunityAssetBadge(assetId: _assetId, symbol: symbol, logoUrl: null),
  viewerMembership: viewer,
  label: null,
);

CommunityDirectoryPage _directory() => CommunityDirectoryPage(
  items: <CommunitySummary>[
    _community(
      0,
      'Meme Observatory',
      'Data only, no shilling.',
      symbol: 'DOGE',
      viewer: const CommunityDirectoryViewer(
        role: CommunityRole.member,
        status: null,
        pending: false,
      ),
      members: 1280,
    ),
    _community(1, 'DeFi Morning Read', 'Ten minutes a day.', members: 1),
    _community(2, 'Frog Holders', 'Home of frog holders', symbol: 'FROG'),
  ],
  nextCursor: null,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
  ordering: const CommunityOrderingApplied(
    sort: CommunityDirectorySort.members,
    basis: CommunityStoredBasis(),
  ),
);

// ---------------------------------------------------------------------------
// DApp
// ---------------------------------------------------------------------------

Future<void> _pumpDapp(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _phone;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => s5MetaSnapshot(
            dappBrowser: LoopV2CapabilityAvailability.available,
          ),
        ),
        dappWebViewFactoryProvider.overrideWithValue(FakeDappWebViewFactory()),
        loopAccountScopeProvider.overrideWithValue(s342Account),
        dappBrowserStoreProvider.overrideWithValue(
          MemoryDappBrowserStore(<String, DappBrowserLocalState>{
            s342Account: DappBrowserLocalState(
              recents: const <DappPageEntry>[
                DappPageEntry(
                  url: 'https://pancakeswap.finance/swap',
                  title: 'PancakeSwap',
                ),
                DappPageEntry(url: 'https://venus.io/', title: ''),
              ],
              bookmarks: const <DappPageEntry>[
                DappPageEntry(
                  url: 'https://pancakeswap.finance/',
                  title: 'PancakeSwap',
                ),
              ],
            ),
          }),
        ),
        dappIntentsGatewayProvider.overrideWithValue(FakeDappIntentsGateway()),
        walletReadGatewayProvider.overrideWithValue(FakeWalletReadGateway()),
        walletSigningGatewayProvider.overrideWithValue(
          RecordingSigningGateway(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  for (final (name, page) in <(String, Widget)>[
    ('launch-catalogue', const LaunchScreen()),
    ('launch-detail', LaunchDetailScreen(launchId: s7LaunchId, clock: s83cNow)),
    ('launch-rounds', const LaunchRoundsScreen(launchId: s7LaunchId)),
    ('launch-graduation', const LaunchGraduationScreen(launchId: s7LaunchId)),
    ('launch-tier', const LaunchTierScreen(launchId: s7LaunchId)),
    ('launch-holders', const LaunchHoldersScreen(launchId: s7LaunchId)),
    ('launch-history', const LaunchHistoryScreen(launchId: s7LaunchId)),
    ('launch-trade', LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow)),
    ('launch-apply', const LaunchApplyScreen()),
    ('launch-economy', const LoopEconomyScreen()),
    ('launch-stake', const LoopStakeScreen()),
  ]) {
    testWidgets(name, skip: !_shots, (tester) async {
      await _pumpLaunch(tester, page);
      await _shot(tester, 's355b-$name');
      await _drain(tester);
    });
  }

  testWidgets('square-feed', skip: !_shots, (tester) async {
    await pumpS7Page(
      tester,
      SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
      meta: _feedMeta(),
      size: _tall,
      overrides: <Override>[
        squareFeedGatewayProvider.overrideWithValue(_Feed(_feedRows())),
      ],
    );
    await tester.tap(find.byKey(const ValueKey<String>('square-segment-0')));
    await tester.pumpAndSettle();
    await _settleArt(tester);
    await _shot(tester, 's355b-square-feed');
    await _drain(tester);
  });

  testWidgets('square-communities', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
      size: _phone,
      community: FakeCommunityGateway(directoryPage: _directory()),
    );
    await _settleArt(tester);
    await _shot(tester, 's355b-square-communities');
    await _drain(tester);
  });

  testWidgets('square-voice-rooms', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
      size: _phone,
      community: FakeCommunityGateway(directoryPage: _directory()),
    );
    await tester.tap(find.byKey(const ValueKey<String>('square-segment-1')));
    await tester.pumpAndSettle();
    await _settleArt(tester);
    await _shot(tester, 's355b-square-voice-rooms');
    await _drain(tester);
  });

  testWidgets('dapp-home', skip: !_shots, (tester) async {
    await _pumpDapp(tester, const DappEntryScreen());
    await _shot(tester, 's355b-dapp-home');
  });

  testWidgets('dapp-web', skip: !_shots, (tester) async {
    await _pumpDapp(
      tester,
      DappBrowserPage(
        request: DappOpenRequest(url: Uri.parse('$s342Origin/swap')),
      ),
    );
    await _shot(tester, 's355b-dapp-web');
  });
}
