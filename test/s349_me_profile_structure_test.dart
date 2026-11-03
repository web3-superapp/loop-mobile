// S349 · decision 0271 Amendment (docs/56 §四): 我的 has the structure of
// another account's page — the person, the stranger requests, 总资产 with
// 钱包管理 and five keys, then 持仓 / 交易 / 社区. The account rows are gone.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_profile_sections.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _shotDir =
    '/private/tmp/claude-501/-Users-chenyang-Documents-LOOP/'
    '6293ad8a-21d0-4c44-84aa-93724a65bef3/scratchpad';

const _joinedA = '3fa85f64-5717-4562-b3fc-2c963f66a001';
const _joinedB = '3fa85f64-5717-4562-b3fc-2c963f66a002';
const _ownedId = '3fa85f64-5717-4562-b3fc-2c963f66a011';

ProfileResource _resource() => ProfileResource(
  version: 1,
  values: ProfileValues(alias: 'Boo123133', avatarRef: null, bio: null),
  updatedAt: DateTime.utc(2026, 10, 9),
  loopId: 'LOOP-GBZM3XAT',
  profileStatus: ProfileStatus.active,
  activatedAt: DateTime.utc(2026, 10, 9, 12),
);

final class _Profile implements ProfileGateway {
  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async => _resource();

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async => _resource();
}

CommunityMembership _membership(CommunityRole role) => CommunityMembership(
  role: role,
  status: CommunityMemberStatus.active,
  joinedAt: DateTime.utc(2026, 7),
);

CommunityHome _home({
  List<JoinedCommunity>? joined,
  List<OwnedCommunity>? owned,
}) => CommunityHome(
  joined:
      joined ??
      <JoinedCommunity>[
        JoinedCommunity(
          community: testCommunity(
            communityId: _joinedA,
            name: 'Frog Holders',
            label: '官方',
          ),
          membership: _membership(CommunityRole.member),
        ),
        JoinedCommunity(
          community: testCommunity(
            communityId: _joinedB,
            name: 'Moon Cats',
            memberCount: 2048,
          ),
          membership: _membership(CommunityRole.member),
        ),
      ],
  joinedTruncated: false,
  owned:
      owned ??
      <OwnedCommunity>[
        OwnedCommunity(
          community: testCommunity(
            communityId: _ownedId,
            name: 'Builders Guild',
            verification: CommunityVerification.pending,
          ),
          membership: _membership(CommunityRole.owner),
          application: CommunityApplicationReview(
            status: CommunityVerification.pending,
            submittedAt: DateTime.utc(2026, 11, 1, 3),
            reviewedAt: null,
            rejectedReason: null,
          ),
        ),
      ],
  ownedTruncated: false,
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 11, 3, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

/// A tape long enough to scroll, ending on [nextCursor].
LoopWalletActivityPage _longTape({String? nextCursor = 'cursor-2'}) {
  final first = s5Activity().items.single;
  return s5Activity(
    nextCursor: nextCursor,
    items: <LoopWalletActivityEntry>[
      for (var i = 0; i < 30; i++)
        LoopWalletActivityEntry(
          assetId: first.assetId,
          symbol: first.symbol,
          decimals: first.decimals,
          direction: i.isEven
              ? LoopTransferDirection.incoming
              : LoopTransferDirection.outgoing,
          counterpartyAddress: first.counterpartyAddress,
          rawValue: first.rawValue,
          displayValue: first.displayValue,
          transactionHash: first.transactionHash,
          logIndex: i,
          blockNumber: first.blockNumber - BigInt.from(i * 1000),
          blockHash: first.blockHash,
          confirmations: first.confirmations,
          status: first.status,
          observedAt: DateTime.utc(2026, 9, 8).subtract(Duration(hours: i)),
        ),
    ],
  );
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<FakeWalletReadGateway> _pumpMe(
  WidgetTester tester, {
  ValueChanged<String>? onNavigate,
  LoopWalletActivityPage? activity,
  CommunityHome? home,
  LoopV2MetaSnapshot? meta,
  Size size = const Size(390, 2400),
}) async {
  final wallet = FakeWalletReadGateway(
    activity: S5Answer<LoopWalletActivityPage>(value: activity ?? s5Activity()),
  );
  await pumpS5Page(
    tester,
    WalletScreen(onNavigate: onNavigate),
    size: size,
    wallet: wallet,
    meta:
        meta ??
        s5MetaSnapshot(community: LoopV2CapabilityAvailability.available),
    overrides: [
      profileGatewayProvider.overrideWithValue(_Profile()),
      socialGatewayProvider.overrideWithValue(
        FakeSocialGateway(
          connections: const ConnectionPage(
            direction: ConnectionDirection.following,
            items: <ConnectionEntry>[],
            counts: ConnectionCounts(following: 3, followers: 12),
            nextCursor: null,
          ),
        ),
      ),
      communityGatewayProvider.overrideWithValue(
        FakeCommunityGateway(home: home ?? _home()),
      ),
    ],
  );
  return wallet;
}

Future<void> _section(WidgetTester tester, String label) async {
  final chip = find.descendant(
    of: _key('me-sections'),
    matching: find.text(label),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_shotDir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  testWidgets('person, 总资产, five keys, then 持仓 / 交易 / 社区', (tester) async {
    await _pumpMe(tester);
    double top(String key) => tester.getTopLeft(_key(key)).dy;
    expect(top('profile-identity-card'), lessThan(top('wallet-total-plate')));
    expect(top('wallet-total-plate'), lessThan(top('wallet-quick-actions')));
    expect(top('wallet-quick-actions'), lessThan(top('me-sections')));
    // The bar is the one another account's page draws.
    expect(
      find.descendant(
        of: _key('me-sections'),
        matching: find.byType(LoopSegBar),
      ),
      findsOneWidget,
    );
    final labels = <String>['持仓', '交易', '社区'];
    final xs = <double>[
      for (final label in labels)
        tester
            .getCenter(
              find.descendant(
                of: _key('me-sections'),
                matching: find.text(label),
              ),
            )
            .dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
    expect(LoopProfileSection.values.map((section) => section.label), labels);
    // 持仓 is first and open: the tokens, 代币 / NFT and 产生算力.
    expect(top('me-sections'), lessThan(top('wallet-asset-list')));
    expect(_key('wallet-power-tag'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the account rows and 邀请好友 are gone', (tester) async {
    await _pumpMe(tester);
    for (final section in <String>['持仓', '交易', '社区']) {
      await _section(tester, section);
      for (final gone in <String>[
        'me-account-entries',
        'profile-open-wallets',
        'profile-open-communities',
        'profile-open-referral',
        'profile-copy-invite-code',
        'wallet-history-action',
      ]) {
        expect(_key(gone), findsNothing, reason: '$section · $gone');
      }
      expect(find.text('邀请好友'), findsNothing);
      expect(find.text('我的钱包'), findsNothing);
    }
  });

  testWidgets('钱包管理 beside the address opens wallets', (tester) async {
    final opened = <String>[];
    await _pumpMe(tester, onNavigate: opened.add);
    final button = _key('wallet-manage-action');
    expect(
      find.descendant(of: _key('wallet-total-plate'), matching: button),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('钱包管理'), findsOneWidget);
    // On the address line, at its right end.
    expect(
      tester.getCenter(button).dy,
      moreOrLessEquals(
        tester.getCenter(_key('wallet-address-copy')).dy,
        epsilon: 4,
      ),
    );
    expect(
      tester.getCenter(button).dx,
      greaterThan(tester.getCenter(_key('wallet-address-copy')).dx),
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, <String>['/wallet/manage']);
  });

  testWidgets('five keys, each to its page', (tester) async {
    final opened = <String>[];
    await _pumpMe(
      tester,
      onNavigate: opened.add,
      meta: s5MetaSnapshot(
        community: LoopV2CapabilityAvailability.available,
        privySwap: LoopV2CapabilityAvailability.available,
        sendApprovals: LoopV2CapabilityAvailability.available,
        swapEvidencePending: false,
      ),
    );
    final keys = <(String, String, String)>[
      ('wallet-receive-entry', '接收', WalletRoute.receive(s5WalletId)),
      ('wallet-send-entry', '发送', '/wallet/send'),
      ('wallet-swap-entry', '兑换', '/wallet/swap'),
      ('wallet-pay-entry', '扫码', '/scan'),
      ('wallet-dapp-entry', 'DApp', '/wallet/dapp'),
    ];
    double? last;
    for (final (key, label, location) in keys) {
      final finder = _key(key);
      expect(
        find.descendant(of: _key('wallet-quick-actions'), matching: finder),
        findsOneWidget,
        reason: key,
      );
      expect(
        find.descendant(of: finder, matching: find.text(label)),
        findsOneWidget,
        reason: key,
      );
      final x = tester.getCenter(finder).dx;
      if (last != null) expect(x, greaterThan(last), reason: key);
      last = x;
      opened.clear();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(opened, <String>[location], reason: key);
    }
  });

  testWidgets('DApp stays when the browser is closed: the URL review', (
    tester,
  ) async {
    final opened = <String>[];
    await _pumpMe(tester, onNavigate: opened.add);
    await tester.tap(_key('wallet-dapp-entry'));
    await tester.pumpAndSettle();
    expect(opened, <String>['/wallet/dapp']);
  });

  testWidgets('交易: the tape, paged as the reader scrolls', (tester) async {
    final wallet = await _pumpMe(
      tester,
      activity: _longTape(),
      size: const Size(390, 900),
    );
    expect(wallet.activityCursors, isEmpty);
    await _section(tester, '交易');
    expect(_key('me-trades-days'), findsOneWidget);
    expect(_key('me-trades-seg-0'), findsOneWidget);
    expect(_key('wallet-asset-list'), findsNothing);
    // The first page only: the sentinel is not built until it is near.
    expect(wallet.activityCursors, <String?>[null]);
    expect(_key('me-trades-load-more'), findsNothing);
    // One scroll container: the page's own.
    await tester.scrollUntilVisible(
      _key('me-trades-load-more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(wallet.activityCursors, <String?>[null, 'cursor-2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('交易: nothing yet is one line', (tester) async {
    await _pumpMe(
      tester,
      activity: s5Activity(items: const <LoopWalletActivityEntry>[]),
    );
    await _section(tester, '交易');
    expect(_key('me-trades-empty'), findsOneWidget);
    expect(find.text('这一段没有记录'), findsOneWidget);
  });

  testWidgets('社区: joined and created, with the review state', (tester) async {
    final opened = <String>[];
    await _pumpMe(tester, onNavigate: opened.add);
    await _section(tester, '社区');
    expect(_key('me-joined-$_joinedA'), findsOneWidget);
    expect(_key('me-joined-$_joinedB'), findsOneWidget);
    expect(_key('profile-owned-$_ownedId'), findsOneWidget);
    expect(find.text('我加入的'), findsOneWidget);
    expect(find.text('我创建的'), findsOneWidget);
    expect(find.text('2,048 名成员'), findsOneWidget);
    expect(_key('wallet-asset-list'), findsNothing);
    double top(String key) => tester.getTopLeft(_key(key)).dy;
    expect(
      top('me-joined-$_joinedB'),
      lessThan(top('profile-owned-$_ownedId')),
    );
    await tester.tap(_key('me-joined-$_joinedA'));
    await tester.pumpAndSettle();
    expect(opened, <String>['/community/profile?id=$_joinedA']);
  });

  testWidgets('社区: only joined, no group labels', (tester) async {
    await _pumpMe(tester, home: _home(owned: const <OwnedCommunity>[]));
    await _section(tester, '社区');
    expect(_key('me-joined-$_joinedA'), findsOneWidget);
    expect(_key('profile-owned-communities'), findsNothing);
    expect(find.text('我加入的'), findsNothing);
  });

  testWidgets('社区: none is one line', (tester) async {
    await _pumpMe(
      tester,
      home: _home(
        joined: const <JoinedCommunity>[],
        owned: const <OwnedCommunity>[],
      ),
    );
    await _section(tester, '社区');
    expect(_key('me-communities-empty'), findsOneWidget);
    expect(find.text('还没有加入社区'), findsOneWidget);
  });

  testWidgets('wallet module closed: 社区 still reads', (tester) async {
    await _pumpMe(
      tester,
      meta: s5MetaSnapshot(
        community: LoopV2CapabilityAvailability.available,
        walletRead: LoopV2CapabilityAvailability.unavailable,
      ),
    );
    expect(_key('wallet-capability-block'), findsOneWidget);
    await _section(tester, '交易');
    expect(_key('me-trades-capability-block'), findsOneWidget);
    await _section(tester, '社区');
    expect(_key('me-joined-$_joinedA'), findsOneWidget);
  });

  for (final width in <double>[390, 360]) {
    testWidgets('no overflow at $width in any section', (tester) async {
      await _pumpMe(tester, size: Size(width, 2400));
      for (final section in <String>['持仓', '交易', '社区']) {
        await _section(tester, section);
        expect(tester.takeException(), isNull, reason: '$width · $section');
      }
    });
  }

  group('shots', () {
    testWidgets('我的 · 持仓', skip: !_shots, (tester) async {
      await _pumpMe(tester, size: const Size(390, 1500));
      await _shot(tester, 'S349-me-holdings');
    });

    testWidgets('我的 · 交易', skip: !_shots, (tester) async {
      await _pumpMe(
        tester,
        activity: _longTape(nextCursor: null),
        size: const Size(390, 1500),
      );
      await _section(tester, '交易');
      await _shot(tester, 'S349-me-trades');
    });

    testWidgets('我的 · 社区', skip: !_shots, (tester) async {
      await _pumpMe(tester, size: const Size(390, 1500));
      await _section(tester, '社区');
      await _shot(tester, 'S349-me-communities');
    });

    testWidgets('我的 · 持仓 360', skip: !_shots, (tester) async {
      await _pumpMe(tester, size: const Size(360, 1500));
      await _shot(tester, 'S349-me-holdings-360');
    });
  });
}
