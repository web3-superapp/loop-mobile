import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_link.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_profile_communities.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_public_profiles.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

/// Decision 0218 (loop-api S260): the 社区 segment reads
/// `/v2/profiles/{id}/communities`, and `/holdings` and `/trades` may merge
/// Launch-chain rows behind `PROFILE_LAUNCH2_EMIT`.

const _id = '7d1c5f64-5717-4562-b3fc-2c963f66a001';
const _instanceA = '2f6a1c3e-5b7d-4e9f-8a1b-3c5d7e9f1a2b';
const _instanceB = '3a7b2d4f-6c8e-4f0a-9b2c-4d6e8f0a2b3c';
const _communityA = '5b0c4f1e-2d3a-4b6c-8d9e-0f1a2b3c4d01';
const _communityB = '5b0c4f1e-2d3a-4b6c-8d9e-0f1a2b3c4d02';
const _launchTx =
    '0x1111111111111111111111111111111111111111111111111111111111111111';

void _refused(Object? Function() decode) =>
    expect(decode, throwsA(isA<LoopBackendFailure>()));

// --------------------------------------------------------------------------
// Wire fixtures
// --------------------------------------------------------------------------

Map<String, Object?> _communityRow({
  String id = _communityA,
  String name = '星夜社区',
  String verification = 'verified',
  Object? logoRef,
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  ...extra,
  'communityId': id,
  'name': name,
  'slug': 'star-night',
  'logoRef': logoRef,
  'memberCount': 1284,
  'verificationStatus': verification,
  'joinedAt': '2026-10-01T00:00:00.000Z',
};

Map<String, Object?> _communitiesBody({
  List<Object?>? items,
  Object? nextCursor,
}) => <String, Object?>{
  'status': 'available',
  'items':
      items ??
      <Object?>[
        _communityRow(extra: const <String, Object?>{'label': '算力社区'}),
        _communityRow(
          id: _communityB,
          name: 'Night Owls',
          verification: 'unverified',
        ),
      ],
  'nextCursor': nextCursor,
  'contractVersion': '2.0',
};

Map<String, Object?> _hiddenBody() => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': 'PROFILE_COMMUNITIES_HIDDEN',
  'contractVersion': '2.0',
};

Map<String, Object?> _assetHolding() => <String, Object?>{
  'assetId': 'eip155:56:native',
  'symbol': 'BNB',
  'name': 'BNB',
  'logoUrl': null,
  'balance': '1.2',
  'usdValue': '784.52',
};

Map<String, Object?> _launch2Holding({
  String kind = 'launch2_meme',
  String instanceId = _instanceA,
  Object? amountMeme = '1234.5',
  Object? nftCount,
  String stage = 'public',
  Object? valueUsd1 = '12.5',
}) => <String, Object?>{
  'kind': kind,
  'chainId': 'eip155:97',
  'instanceId': instanceId,
  'ticker': 'STAR',
  'name': '星夜',
  'logoUrl': null,
  'amountMeme': amountMeme,
  'nftCount': nftCount,
  'stage': stage,
  'valueUsd1': valueUsd1,
};

Map<String, Object?> _nftHolding() => _launch2Holding(
  kind: 'launch2_nft',
  instanceId: _instanceB,
  amountMeme: null,
  nftCount: 2,
  stage: 'graduated',
  valueUsd1: null,
);

Map<String, Object?> _holdingsBody({List<Object?>? items, Object? launch2}) {
  final body = <String, Object?>{
    'status': 'available',
    'reasonCode': null,
    'totalUsd': '784.52',
    'items': items ?? <Object?>[_assetHolding()],
    'observedAt': '2026-10-20T04:00:00.000Z',
    'contractVersion': '2.0',
  };
  if (launch2 != null) body['launch2'] = launch2;
  return body;
}

const _launch2Available = <String, Object?>{
  'status': 'available',
  'chainId': 'eip155:97',
  'indexerBlockNumber': '52000160',
  'headBlockNumber': null,
};

const _launch2Unavailable = <String, Object?>{
  'status': 'unavailable',
  'reasonCode': 'LAUNCH2_INDEXER_NOT_STARTED',
};

Map<String, Object?> _assetTrade() => <String, Object?>{
  'eventId': 'evt_1',
  'kind': 'buy',
  'assetId': 'eip155:56:native',
  'symbol': 'BNB',
  'amount': '0.4',
  'usdValue': '261.5',
  'blockTimestamp': '2026-10-08T01:00:00.000Z',
  'blockNumber': '300',
  'txHash': '0x${'a' * 64}',
};

/// The S252 fourteen-key row (decision 0213).
Map<String, Object?> _launch2Trade({String kind = 'launch2_curve_buy'}) =>
    <String, Object?>{
      'kind': kind,
      'chainId': 'eip155:97',
      'instanceId': _instanceA,
      'ticker': 'STAR',
      'name': '星夜',
      'logoUrl': null,
      'amountMeme': '1000',
      'amountUsd1': '10.2',
      'taxUsd1': '0.2',
      'transactionHash': _launchTx,
      'logIndex': 1,
      'blockNumber': '51999000',
      'occurredAt': '2026-10-19T08:00:00.000Z',
      'confirmations': 1124,
    };

Map<String, Object?> _tradesBody({List<Object?>? items, Object? launch2}) {
  final body = <String, Object?>{
    'status': 'available',
    'reasonCode': null,
    'items': items ?? <Object?>[_assetTrade()],
    'nextCursor': null,
    'contractVersion': '2.0',
  };
  if (launch2 != null) body['launch2'] = launch2;
  return body;
}

// --------------------------------------------------------------------------
// Page harness
// --------------------------------------------------------------------------

PublicProfileRecord _record({bool holdings = true, bool trades = true}) =>
    PublicProfileRecord(
      publicProfileId: _id,
      loopId: 'LOOP-7KQ2M9XA',
      alias: 'frog_maxi',
      avatarRef: null,
      bio: null,
      joinedAt: DateTime.utc(2026, 9),
      counts: const PublicProfileCounts(
        followers: 1,
        following: 2,
        communities: 2,
      ),
      relationship: const PublicProfileRelationship(
        following: false,
        followedBy: false,
        friendship: ProfileFriendship.none,
        blocked: false,
        blockedBy: false,
      ),
      visibility: PublicProfileVisibility(holdings: holdings, trades: trades),
    );

final class _Profiles implements PublicProfileGateway {
  _Profiles({
    this.holdingsAnswer,
    this.tradesAnswer,
    List<ProfileCommunitiesPage>? communityPages,
    this.communitiesFailure,
    this.communitiesPending = false,
  }) : communityPages = communityPages ?? <ProfileCommunitiesPage>[];

  ProfileHoldings? holdingsAnswer;
  ProfileTradesPage? tradesAnswer;
  final List<ProfileCommunitiesPage> communityPages;
  CommunityFailureKind? communitiesFailure;
  final bool communitiesPending;
  final List<String> calls = <String>[];

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async =>
      _record();

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) async {
    calls.add('holdings');
    return holdingsAnswer ?? LoopV2PublicProfileCodec.holdings(_holdingsBody());
  }

  @override
  Future<ProfileTradesPage> trades(
    String publicProfileId, {
    String? cursor,
  }) async {
    calls.add('trades:$cursor');
    return tradesAnswer ?? LoopV2PublicProfileCodec.trades(_tradesBody());
  }

  @override
  Future<ProfileCommunitiesPage> communities(
    String publicProfileId, {
    String? cursor,
  }) async {
    calls.add('communities:$cursor');
    if (communitiesPending) return Completer<ProfileCommunitiesPage>().future;
    final kind = communitiesFailure;
    if (kind != null) throw CommunityGatewayException(kind);
    return communityPages.removeAt(0);
  }

  @override
  Future<void> removeFriend(String publicProfileId) async {}
}

Future<List<String>> _pump(
  WidgetTester tester,
  _Profiles profiles, {
  bool settle = true,
}) async {
  final opened = <String>[];
  await pumpCommunityPage(
    tester,
    UserProfileScreen(
      target: const PublicProfileById(_id),
      onNavigate: opened.add,
    ),
    social: FakeSocialGateway(),
    settle: settle,
    overrides: <Override>[
      publicProfileGatewayProvider.overrideWithValue(profiles),
    ],
  );
  return opened;
}

Future<void> _section(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey<String>('user-profile-sections')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  group('communities codec', () {
    test('available: rows, verification, cursor', () {
      final page = LoopV2ProfileCommunitiesCodec.page(
        _communitiesBody(nextCursor: 'cur.2'),
      );
      expect(page.hidden, isFalse);
      expect(page.items, hasLength(2));
      expect(
        page.items.first.verificationStatus,
        ProfileCommunityVerification.verified,
      );
      expect(page.items.first.memberCount, 1284);
      expect(page.items.last.logoRef, isNull);
      expect(page.nextCursor, 'cur.2');
    });

    test('unavailable: hidden, no rows', () {
      final page = LoopV2ProfileCommunitiesCodec.page(_hiddenBody());
      expect(page.hidden, isTrue);
      expect(page.reasonCode, 'PROFILE_COMMUNITIES_HIDDEN');
      expect(page.items, isEmpty);
    });

    test('refuses unknown keys, unknown status, bad rows, repeats', () {
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody()..['extra'] = 1,
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody()..remove('contractVersion'),
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _hiddenBody()..['items'] = <Object?>[],
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody()..['status'] = 'hidden',
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody(
            items: <Object?>[_communityRow()..['description'] = 'x'],
          ),
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody(items: <Object?>[_communityRow()..remove('slug')]),
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody(
            items: <Object?>[_communityRow(verification: 'pending')],
          ),
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody(items: <Object?>[_communityRow(), _communityRow()]),
        ),
      );
      _refused(
        () => LoopV2ProfileCommunitiesCodec.page(
          _communitiesBody(
            items: <Object?>[_communityRow(logoRef: 'https://evil.test/x')],
          ),
        ),
      );
    });
  });

  group('holdings codec · launch2', () {
    test('no launch2 key: the page reads as before', () {
      final holdings = LoopV2PublicProfileCodec.holdings(_holdingsBody());
      expect(holdings.launch2, isNull);
      expect(holdings.items, hasLength(1));
      expect(holdings.rows.single, isA<ProfileAssetHoldingRow>());
    });

    test('merged rows keep server order; meme and nft rows', () {
      final holdings = LoopV2PublicProfileCodec.holdings(
        _holdingsBody(
          items: <Object?>[_launch2Holding(), _assetHolding(), _nftHolding()],
          launch2: _launch2Available,
        ),
      );
      expect(holdings.launch2!.isAvailable, isTrue);
      expect(holdings.launch2!.chainId, 'eip155:97');
      expect(holdings.rows, hasLength(3));
      expect(holdings.items, hasLength(1));
      final meme = (holdings.rows.first as ProfileLaunch2HoldingRow).holding;
      expect(meme.kind, ProfileLaunch2HoldingKind.meme);
      expect(meme.amountMeme, Decimal.parse('1234.5'));
      expect(meme.stage, Launch2Stage.public);
      expect(meme.valueUsd1, Decimal.parse('12.5'));
      final nft = (holdings.rows.last as ProfileLaunch2HoldingRow).holding;
      expect(nft.kind, ProfileLaunch2HoldingKind.nft);
      expect(nft.nftCount, 2);
      expect(nft.valueUsd1, isNull);
      expect(nft.stage, Launch2Stage.graduated);
    });

    test('launch2 unavailable carries its reason', () {
      final holdings = LoopV2PublicProfileCodec.holdings(
        _holdingsBody(launch2: _launch2Unavailable),
      );
      expect(holdings.launch2!.isAvailable, isFalse);
      expect(
        holdings.launch2!.unavailable!.reasonCode,
        'LAUNCH2_INDEXER_NOT_STARTED',
      );
    });

    test('an unknown kind is skipped, an unknown stage is tolerated', () {
      final holdings = LoopV2PublicProfileCodec.holdings(
        _holdingsBody(
          items: <Object?>[
            _launch2Holding(kind: 'launch2_future')..['more'] = 1,
            _launch2Holding(stage: 'some_new_stage'),
          ],
        ),
      );
      expect(holdings.rows, hasLength(1));
      expect(
        (holdings.rows.single as ProfileLaunch2HoldingRow).holding.stage,
        isNull,
      );
    });

    test('refusals: unknown root key, launch2 shapes, row keys, amounts', () {
      _refused(
        () => LoopV2PublicProfileCodec.holdings(_holdingsBody()..['x'] = 1),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(
            launch2: <String, Object?>{..._launch2Available, 'extra': 1},
          ),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(launch2: const <String, Object?>{'status': 'partial'}),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding()..remove('stage')]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding()..['x'] = 1]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding()..['kind'] = 7]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding(amountMeme: null)]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding(amountMeme: '1e3')]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding(), _launch2Holding()]),
        ),
      );
      // A hidden section still carries no rows, Launch chain included.
      _refused(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsBody(items: <Object?>[_launch2Holding()])
            ..['status'] = 'hidden'
            ..['totalUsd'] = null,
        ),
      );
    });
  });

  group('trades codec · launch2', () {
    test('no launch2 key: the page reads as before', () {
      final page = LoopV2PublicProfileCodec.trades(_tradesBody());
      expect(page.launch2, isNull);
      expect(page.items.single.kind, ProfileTradeKind.buy);
      expect(page.rows.single, isA<ProfileAssetTradeRow>());
    });

    test('merged rows reuse the wallet model', () {
      final page = LoopV2PublicProfileCodec.trades(
        _tradesBody(
          items: <Object?>[_launch2Trade(), _assetTrade()],
          launch2: _launch2Available,
        ),
      );
      expect(page.rows, hasLength(2));
      expect(page.items, hasLength(1));
      final entry = (page.rows.first as ProfileLaunch2TradeRow).entry;
      expect(entry.kind, LoopWalletLaunch2ActivityKind.curveBuy);
      expect(entry.amountUsd1, Decimal.parse('10.2'));
      expect(page.rows.first.rowId, entry.entryId);
    });

    test('unavailable launch2 and an unknown kind', () {
      final page = LoopV2PublicProfileCodec.trades(
        _tradesBody(
          items: <Object?>[
            _launch2Trade(kind: 'launch2_future_kind'),
            _assetTrade(),
          ],
          launch2: _launch2Unavailable,
        ),
      );
      expect(page.rows, hasLength(1));
      expect(page.launch2!.isAvailable, isFalse);
    });

    test('refusals: unknown root key, row keys, legacy kind still strict', () {
      _refused(() => LoopV2PublicProfileCodec.trades(_tradesBody()..['x'] = 1));
      _refused(
        () => LoopV2PublicProfileCodec.trades(
          _tradesBody(items: <Object?>[_launch2Trade()..remove('taxUsd1')]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.trades(
          _tradesBody(items: <Object?>[_launch2Trade()..['x'] = 1]),
        ),
      );
      _refused(
        () => LoopV2PublicProfileCodec.trades(
          _tradesBody(items: <Object?>[_launch2Trade(), _launch2Trade()]),
        ),
      );
      // A mainnet row (it has an `eventId`) with an unknown kind is broken,
      // as it always was.
      _refused(
        () => LoopV2PublicProfileCodec.trades(
          _tradesBody(items: <Object?>[_assetTrade()..['kind'] = 'mint']),
        ),
      );
    });
  });

  group('user-profile · 社区', () {
    testWidgets('lists rows, label capsule, opens the community', (
      tester,
    ) async {
      final profiles = _Profiles(
        communityPages: <ProfileCommunitiesPage>[
          LoopV2ProfileCommunitiesCodec.page(_communitiesBody()),
        ],
      );
      final opened = await _pump(tester, profiles);
      await _section(tester, '社区');
      expect(find.text('社区列表暂未开放查看。'), findsNothing);
      expect(find.text('星夜社区'), findsOneWidget);
      expect(find.text('Night Owls'), findsOneWidget);
      expect(find.text('1,284 名成员'), findsNWidgets(2));
      // Decision 0239: the operator's label replaces 「已验证」; the row
      // without one wears nothing.
      expect(find.text('已验证'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-community-label-$_communityA'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-community-label-$_communityB'),
        ),
        findsNothing,
      );
      expect(find.text('算力社区'), findsOneWidget);
      await _tapKey(tester, 'user-profile-community-$_communityA');
      expect(opened, <String>[communityProfileLocation(_communityA)]);
    });

    testWidgets('pages on with the load-more footer', (tester) async {
      final profiles = _Profiles(
        communityPages: <ProfileCommunitiesPage>[
          LoopV2ProfileCommunitiesCodec.page(
            _communitiesBody(
              items: <Object?>[_communityRow()],
              nextCursor: 'cur.2',
            ),
          ),
          LoopV2ProfileCommunitiesCodec.page(
            _communitiesBody(
              items: <Object?>[_communityRow(id: _communityB, name: '第二页社区')],
            ),
          ),
        ],
      );
      await _pump(tester, profiles);
      await _section(tester, '社区');
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('communities:cur.2'));
      expect(find.text('第二页社区'), findsOneWidget);
    });

    testWidgets('hidden reads 对方未公开社区列表', (tester) async {
      final profiles = _Profiles(
        communityPages: <ProfileCommunitiesPage>[
          LoopV2ProfileCommunitiesCodec.page(_hiddenBody()),
        ],
      );
      await _pump(tester, profiles);
      await _section(tester, '社区');
      expect(find.text('对方未公开社区列表'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      final profiles = _Profiles(
        communityPages: <ProfileCommunitiesPage>[
          LoopV2ProfileCommunitiesCodec.page(
            _communitiesBody(items: <Object?>[]),
          ),
        ],
      );
      await _pump(tester, profiles);
      await _section(tester, '社区');
      expect(
        find.byKey(const ValueKey<String>('user-profile-communities-empty')),
        findsOneWidget,
      );
    });

    testWidgets('loading', (tester) async {
      final profiles = _Profiles(communitiesPending: true);
      await _pump(tester, profiles);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('user-profile-sections')),
          matching: find.text('社区'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('user-profile-communities-state')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(CommunityFailureKind, String)>[
      (
        CommunityFailureKind.unavailable,
        'user-profile-communities-unavailable',
      ),
      (CommunityFailureKind.offline, 'community-state-offline'),
      (CommunityFailureKind.permissionDenied, 'community-state-permission'),
      (CommunityFailureKind.unexpected, 'community-state-error'),
    ]) {
      testWidgets('${kind.name} state', (tester) async {
        final profiles = _Profiles(communitiesFailure: kind);
        await _pump(tester, profiles);
        await _section(tester, '社区');
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }
  });

  group('user-profile · 持仓 launch2', () {
    testWidgets('mixed rows, meme amount and medals, opens the project', (
      tester,
    ) async {
      final profiles = _Profiles(
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(
          _holdingsBody(
            items: <Object?>[_launch2Holding(), _assetHolding(), _nftHolding()],
            launch2: _launch2Available,
          ),
        ),
      );
      final opened = await _pump(tester, profiles);
      expect(find.text('BNB'), findsWidgets);
      expect(find.text('STAR'), findsNWidgets(2));
      expect(find.text('Launch 链，公开内盘'), findsOneWidget);
      expect(find.text('Launch 链，已毕业'), findsOneWidget);
      expect(find.text('× 2'), findsOneWidget);
      expect(find.textContaining('≈ 12.5'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
      await _tapKey(
        tester,
        'user-profile-holding-launch2:eip155:97:$_instanceA:launch2_meme',
      );
      expect(opened, <String>[Launch2Route.instance(_instanceA)]);
    });

    testWidgets('launch2 unavailable is one line above the rows', (
      tester,
    ) async {
      final profiles = _Profiles(
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(
          _holdingsBody(launch2: _launch2Unavailable),
        ),
      );
      await _pump(tester, profiles);
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-holdings-launch2-unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.text('MEME 持仓暂不可用'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('user-profile-holding-eip155:56:native'),
        ),
        findsOneWidget,
      );
    });
  });

  group('user-profile · 交易 launch2', () {
    testWidgets('mixed rows with the wallet row, opens the project', (
      tester,
    ) async {
      final page = LoopV2PublicProfileCodec.trades(
        _tradesBody(
          items: <Object?>[_launch2Trade(), _assetTrade()],
          launch2: _launch2Available,
        ),
      );
      final entry = (page.rows.first as ProfileLaunch2TradeRow).entry;
      final profiles = _Profiles(tradesAnswer: page);
      final opened = await _pump(tester, profiles);
      await _section(tester, '交易');
      expect(find.text('买入 STAR'), findsOneWidget);
      expect(find.text('买入 BNB'), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('tx-entry-${entry.entryId}')),
        findsOneWidget,
      );
      await _tapKey(tester, 'tx-entry-${entry.entryId}');
      expect(opened, <String>[Launch2Route.instance(_instanceA)]);
    });

    testWidgets('launch2 unavailable is one line above the rows', (
      tester,
    ) async {
      final profiles = _Profiles(
        tradesAnswer: LoopV2PublicProfileCodec.trades(
          _tradesBody(launch2: _launch2Unavailable),
        ),
      );
      await _pump(tester, profiles);
      await _section(tester, '交易');
      expect(find.text('MEME 记录暂不可用'), findsOneWidget);
      expect(find.text('买入 BNB'), findsOneWidget);
    });
  });
}
