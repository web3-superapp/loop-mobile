// S348 · docs/56 §四 (需求方 11-03 晚): 聊天 lists community rooms and
// friends side by side in one list; 情报 · 算力 shows only the assets that
// carry power, drops 有权重的社区币, and 邀请 puts 邀请列表 / 邀请加成 side by
// side under the invite card.
//
// The shots at the end run only with `--dart-define=LOOP_SHOTS=true`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/referral_center_host.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir =
    '/private/tmp/claude-501/-Users-chenyang-Documents-LOOP/'
    '6293ad8a-21d0-4c44-84aa-93724a65bef3/scratchpad';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

// ---------------------------------------------------------------------------
// 聊天 · one query, one list
// ---------------------------------------------------------------------------

const String _me = 'me';
const String _hex = '0123456789abcdef0123456789abcdef';

/// Answers the inbox query with its scripted rows and records every read.
class _InboxClient extends StreamChatClient {
  _InboxClient() : super('key', logLevel: Level.OFF) {
    // ignore: invalid_use_of_internal_member
    state.currentUser = OwnUser(id: _me);
  }

  List<Channel> rows = const <Channel>[];
  final List<Filter?> reads = <Filter?>[];

  @override
  Stream<QueryChannelsResult> queryChannelsWithResult({
    Filter? filter,
    SortOrder<ChannelState>? channelStateSort,
    String? predefinedFilter,
    Map<String, Object?>? filterValues,
    Map<String, Object?>? sortValues,
    bool state = true,
    bool watch = true,
    bool presence = false,
    int? memberLimit,
    int? messageLimit,
    PaginationParams paginationParams = const PaginationParams(),
    bool waitForConnect = true,
  }) async* {
    reads.add(filter);
    yield QueryChannelsResult(channels: rows);
  }
}

Channel _row(
  StreamChatClient client,
  String prefix,
  int minutesAgo, {
  String hex = _hex,
}) => Channel.fromState(
  client,
  ChannelState(
    channel: ChannelModel(
      id: '$prefix$hex',
      type: 'messaging',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      lastMessageAt: DateTime.utc(
        2026,
        11,
        3,
      ).subtract(Duration(minutes: minutesAgo)),
    ),
    membership: Member(userId: _me),
  ),
);

// ---------------------------------------------------------------------------
// 情报 · 算力
// ---------------------------------------------------------------------------

/// Cake carries token and NFT power, USDT token power only, WBNB nothing.
List<MiningAssetRow> _rows() => <MiningAssetRow>[
  s7MiningAssetRow(holding: '1000', power: '3800', nftPower: '3000'),
  s7MiningAssetRow(
    assetId: s7UsdtAssetId,
    symbol: 'USDT',
    holding: '10',
    weight: '1',
    power: '10',
  ),
  s7MiningAssetRow(
    assetId: s7WbnbAssetId,
    symbol: 'WBNB',
    holding: '0',
    weight: '1',
    power: '0',
  ),
];

Future<void> _pumpPower(
  WidgetTester tester, {
  Widget page = const MiningScreen(embedded: true),
  List<MiningAssetRow>? rows,
  String assetPower = '3810',
  String nftPower = '3000',
  ReferralOverview? referral,
  ReferralInviteePage? invitees,
  Size size = const Size(390, 3200),
}) => pumpS7Page(
  tester,
  page,
  mining: FakeMiningGateway(
    summary: S7Answer<MiningSummary>(
      value: s7MiningBaselineSummary(
        assetPower: assetPower,
        nftPower: nftPower,
        power: '6810',
        networkPower: '5025001.1',
        snapshot: s7MiningSnapshot(),
      ),
    ),
    assets: S7Answer<MiningAssets>(
      value: s7MiningSettledAssets(
        included: rows ?? _rows(),
        excluded: const <MiningExcludedAsset>[
          MiningExcludedAsset(
            assetId: s7WbnbAssetId,
            symbol: 'WBNB',
            reasonCode: 'MINING_PRICE_NOT_FRESH',
          ),
        ],
      ),
    ),
  ),
  referral: FakeReferralGateway(
    overview: S7Answer<ReferralOverview>(value: referral ?? s7Referral()),
    invitees: invitees == null
        ? null
        : S7Answer<ReferralInviteePage>(value: invitees),
  ),
  size: size,
  overrides: const <Override>[],
);

Future<void> _tab(WidgetTester tester, String bar, String label) async {
  await tester.tap(find.descendant(of: _key(bar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// An approved boost: L1 and L3 have something, L2 / L4 / L5 nothing.
ReferralOverview _boosted() {
  final base = s7Referral();
  return ReferralOverview(
    inviteCode: base.inviteCode,
    binding: base.binding,
    levels: base.levels,
    boost: null,
    boostAvailable: ReferralBoostAvailable(
      referralPower: '1280.5',
      nftReferralPower: '1000',
      assetReferralPower: '280.5',
      levels: <ReferralBoostLevel>[
        const ReferralBoostLevel(
          level: 1,
          effectiveMembers: 4,
          nftPower: '900',
          assetPower: '200',
        ),
        const ReferralBoostLevel(
          level: 2,
          effectiveMembers: 0,
          nftPower: '0',
          assetPower: '0',
        ),
        const ReferralBoostLevel(
          level: 3,
          effectiveMembers: 0,
          nftPower: '100',
          assetPower: '80.5',
        ),
        for (var level = 4; level <= 5; level += 1)
          ReferralBoostLevel(
            level: level,
            effectiveMembers: 0,
            nftPower: '0',
            assetPower: '0',
          ),
      ],
      epochId: '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
      hourStart: DateTime.utc(2026, 11, 3, 8),
      hourEnd: DateTime.utc(2026, 11, 3, 9),
    ),
    inviteLink: 'https://api-staging.example.com/i/LOOP-7HJKM',
    rules: base.rules,
  );
}

ReferralInviteePage _invitees() => ReferralInviteePage(
  items: <ReferralInvitee>[
    for (var index = 0; index < 4; index += 1)
      ReferralInvitee(
        publicProfileId: null,
        alias: 'member${index + 1}',
        avatarRef: null,
        boundAt: DateTime.utc(2026, 11, 2 - index, 3),
        status: index == 3
            ? ReferralInviteeStatus.pending
            : ReferralInviteeStatus.valid,
      ),
  ],
  nextCursor: null,
);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pump();
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/S348-$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  group('聊天 · one list', () {
    test('one Stream query for every conversation', () {
      final client = StreamChatClient('key', logLevel: Level.OFF);
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });
      expect(controller.runtimeType, StreamChannelListController);
      expect(
        controller.filter,
        Filter.and(<Filter>[
          Filter.equal('type', 'messaging'),
          Filter.in_('members', <Object>[_me]),
        ]),
      );
      expect(controller.channelStateSort, loopStreamInboxSort);
      expect(controller.limit, loopStreamInboxPageSize);
    });

    test(
      'community rooms and friends side by side, in Stream\'s order',
      () async {
        final client = _InboxClient();
        addTearDown(client.dispose);
        final dm = _row(client, 'loop_direct_', 1);
        final room = _row(client, 'loop_community_', 2);
        final group = _row(client, 'loop_group_', 3);
        final room2 = _row(
          client,
          'loop_community_',
          4,
          hex: 'fedcba9876543210fedcba9876543210',
        );
        client.rows = <Channel>[dm, room, group, room2];
        final controller = createLoopStreamChannelListController(
          client: client,
          userId: _me,
        );
        addTearDown(controller.dispose);
        await controller.doInitialLoad();
        expect(client.reads, hasLength(1));
        expect(controller.value.asSuccess.items, <Channel>[
          dm,
          room,
          group,
          room2,
        ]);
      },
    );

    test('a seed opens in the order it was read, not regrouped', () {
      final client = StreamChatClient('key', logLevel: Level.OFF);
      addTearDown(client.dispose);
      final dm = Channel(client, 'messaging', 'loop_direct_$_hex');
      final room = Channel(client, 'messaging', 'loop_community_$_hex');
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
        initialChannels: <Channel>[dm, room],
      );
      addTearDown(controller.dispose);
      expect(controller.value.asSuccess.items, <Channel>[dm, room]);
    });
  });

  group('情报 · 算力 · 代币 / NFT', () {
    testWidgets('代币 lists only assets above zero; nothing 未计入', (tester) async {
      await _pumpPower(tester);
      expect(_key('mining-power-tab-token'), findsOneWidget);
      expect(_key('mining-composition-token-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-composition-token-$s7UsdtAssetId'), findsOneWidget);
      expect(_key('mining-composition-token-$s7WbnbAssetId'), findsNothing);
      expect(_key('mining-composition-excluded'), findsNothing);
      expect(find.text('未计入的资产'), findsNothing);
      expect(find.text('未计入'), findsNothing);
      // 有权重的社区币 is gone.
      expect(_key('mining-open-market'), findsNothing);
      expect(find.text('有权重的社区币'), findsNothing);
    });

    testWidgets('NFT lists only assets with NFT power', (tester) async {
      await _pumpPower(tester);
      await _tab(tester, 'mining-power-tabs', 'NFT');
      expect(_key('mining-composition-nft-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-composition-nft-$s7UsdtAssetId'), findsNothing);
      expect(_key('mining-composition-nft-$s7WbnbAssetId'), findsNothing);
    });

    testWidgets('every asset at zero: one line on each tab', (tester) async {
      await _pumpPower(
        tester,
        rows: <MiningAssetRow>[s7MiningAssetRow(holding: '0', power: '0')],
        assetPower: '0',
        nftPower: '0',
      );
      expect(
        tester.widget(_key('mining-composition-token-empty')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('暂无代币算力'), findsOneWidget);
      expect(_key('mining-composition-token-$s7CakeAssetId'), findsNothing);
      await _tab(tester, 'mining-power-tabs', 'NFT');
      expect(
        tester.widget(_key('mining-composition-nft-empty')),
        isA<LoopInlineUnavailable>(),
      );
    });

    testWidgets('no split sent: the single list drops zero rows too', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(embedded: true),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(included: _rows()),
          ),
        ),
      );
      expect(_key('mining-assets-row-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-assets-row-$s7UsdtAssetId'), findsOneWidget);
      expect(_key('mining-assets-row-$s7WbnbAssetId'), findsNothing);
    });
  });

  group('情报 · 算力 · 邀请', () {
    testWidgets('邀请列表 by default; 邀请加成 beside it; 我的邀请人 last', (tester) async {
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, tab: 'power', sub: 'invite'),
        referral: _boosted(),
        invitees: _invitees(),
      );
      final bar = tester.widget<LoopSegBar>(_key('referral-tabs'));
      expect(bar.labels, <String>['邀请列表', '邀请加成']);
      expect(bar.selectedIndex, 0);
      expect(_key('referral-tab-invitees'), findsOneWidget);
      expect(_key('referral-invitee-0'), findsOneWidget);
      // 我的邀请 and the five-depth strip are gone.
      expect(_key('referral-stats'), findsNothing);
      expect(_key('referral-levels'), findsNothing);
      expect(find.text('我的邀请'), findsNothing);
      // The tabs sit under the invite card, 我的邀请人 under the tabs.
      final card = tester.getRect(_key('referral-hero'));
      final tabs = tester.getRect(_key('referral-tabs'));
      expect(tabs.top, greaterThanOrEqualTo(card.bottom));
      final inviter = find.text('我的邀请人');
      expect(inviter, findsOneWidget);
      expect(
        tester.getRect(inviter).top,
        greaterThan(tester.getRect(_key('referral-tab-invitees')).bottom - 1),
      );

      await _tab(tester, 'referral-tabs', '邀请加成');
      expect(_key('referral-tab-boost'), findsOneWidget);
      expect(_key('referral-invitee-0'), findsNothing);
      expect(find.text('我的邀请人'), findsOneWidget);
    });

    testWidgets('邀请加成: the total, then only the depths with something', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(initialTab: ReferralCenterTab.boost),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(value: _boosted()),
        ),
      );
      final total = _key('referral-boost-total');
      expect(
        find.descendant(of: total, matching: find.text('总加成')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: total, matching: find.text('1,280')),
        findsOneWidget,
      );
      expect(_key('referral-boost-level-1'), findsOneWidget);
      expect(_key('referral-boost-level-3'), findsOneWidget);
      for (final level in <int>[2, 4, 5]) {
        expect(
          _key('referral-boost-level-$level'),
          findsNothing,
          reason: 'L$level',
        );
      }
      expect(find.text('L1 · 10% · 有效成员 4 人'), findsOneWidget);
      expect(find.text('L3 · 3% · 有效成员 0 人'), findsOneWidget);
      expect(find.textContaining('USD'), findsNothing);
    });

    testWidgets('邀请加成 unapproved: only the total, as the em dash', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(initialTab: ReferralCenterTab.boost),
        referral: FakeReferralGateway(),
      );
      final total = _key('referral-boost-total');
      expect(
        find.descendant(of: total, matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('referral-boost'),
          matching: find.byType(LoopRecordRow),
        ),
        findsOneWidget,
      );
      // No sentence explains it.
      for (final gone in <String>['还没有批准', '待批准', '暂未开放']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('the deep link still lands on 邀请', (tester) async {
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, tab: 'power', sub: 'invite'),
      );
      expect(_key('mining-power-tab-invite'), findsOneWidget);
      expect(_key('referral-tabs'), findsOneWidget);
    });

    testWidgets('while the overview loads, no tab is drawn', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(pending: true),
        ),
        settle: false,
      );
      expect(_key('referral-tabs'), findsNothing);
      expect(_key('referral-boost'), findsNothing);
    });
  });

  group('shots', () {
    testWidgets('算力 · 代币', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}),
        size: const Size(390, 1400),
      );
      await _shot(tester, 'power-token');
    });

    testWidgets('邀请 · 邀请列表', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, sub: 'invite'),
        referral: _boosted(),
        invitees: _invitees(),
        size: const Size(390, 1700),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'invite-list');
    });

    testWidgets('邀请 · 邀请加成', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, sub: 'invite'),
        referral: _boosted(),
        invitees: _invitees(),
        size: const Size(390, 1500),
      );
      await _tab(tester, 'referral-tabs', '邀请加成');
      await _shot(tester, 'invite-boost');
    });

    testWidgets('邀请 · 邀请加成 未批准', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPower(
        tester,
        page: IntelScreen(onNavigate: (_) {}, sub: 'invite'),
        size: const Size(390, 1400),
      );
      await _tab(tester, 'referral-tabs', '邀请加成');
      await _shot(tester, 'invite-boost-unapproved');
    });
  });
}
