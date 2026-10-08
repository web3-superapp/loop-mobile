import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_public_profiles.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const _id = '7d1c5f64-5717-4562-b3fc-2c963f66a001';
const _loopId = 'LOOP-7KQ2M9XA';
const _ownLoopId = 'LOOP-7HJKMNPQ';

Map<String, Object?> _profileWire() => <String, Object?>{
  'publicProfileId': _id,
  'loopId': _loopId,
  'alias': 'frog_maxi',
  'avatarRef': 'avatar:media/0c6b1f3e-6a51-4a2d-9b7e-3f1c2d4e5a6b',
  'bio': '长期持有',
  'joinedAt': '2026-09-01T00:00:00.000Z',
  'counts': <String, Object?>{
    'followers': 128,
    'following': 36,
    'communities': 4,
  },
  'relationship': <String, Object?>{
    'following': false,
    'followedBy': true,
    'friendship': 'none',
    'blocked': false,
    'blockedBy': false,
  },
  'visibility': <String, Object?>{'holdings': true, 'trades': true},
  'contractVersion': '2.0',
};

Map<String, Object?> _holdingsWire() => <String, Object?>{
  'status': 'available',
  'reasonCode': null,
  'totalUsd': '1284.52',
  'items': <Object?>[
    <String, Object?>{
      'assetId': 'eip155:56:native',
      'symbol': 'BNB',
      'name': 'BNB',
      'logoUrl': null,
      'balance': '1.2',
      'usdValue': '784.52',
    },
    <String, Object?>{
      'assetId': 'eip155:56:0x55d398326f99059ff775485246999027b3197955',
      'symbol': 'USDT',
      'name': 'Tether USD',
      'logoUrl': 'https://evil.test/logo.png',
      'balance': '500',
      'usdValue': null,
    },
  ],
  'observedAt': '2026-10-08T04:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> _tradesWire() => <String, Object?>{
  'status': 'available',
  'reasonCode': null,
  'items': <Object?>[
    <String, Object?>{
      'eventId': 'evt_1',
      'kind': 'buy',
      'assetId': 'eip155:56:native',
      'symbol': 'BNB',
      'amount': '0.4',
      'usdValue': '261.5',
      'blockTimestamp': '2026-10-08T01:00:00.000Z',
      'blockNumber': '300',
      'txHash': '0x${'a' * 64}',
    },
  ],
  'nextCursor': null,
  'contractVersion': '2.0',
};

PublicProfileRecord _record({
  ProfileFriendship friendship = ProfileFriendship.none,
  bool following = false,
  bool blocked = false,
  bool holdings = true,
  bool trades = true,
  String loopId = _loopId,
}) => PublicProfileRecord(
  publicProfileId: _id,
  loopId: loopId,
  alias: 'frog_maxi',
  avatarRef: null,
  bio: '长期持有',
  joinedAt: DateTime.utc(2026, 9),
  counts: const PublicProfileCounts(
    followers: 128,
    following: 36,
    communities: 4,
  ),
  relationship: PublicProfileRelationship(
    following: following,
    followedBy: false,
    friendship: friendship,
    blocked: blocked,
    blockedBy: false,
  ),
  visibility: PublicProfileVisibility(holdings: holdings, trades: trades),
);

final class _Profiles implements PublicProfileGateway {
  _Profiles({
    this.record,
    this.failure,
    this.holdingsAnswer,
    this.holdingsFailure,
    List<ProfileTradesPage>? tradePages,
    this.pending = false,
  }) : tradePages = tradePages ?? <ProfileTradesPage>[];

  PublicProfileRecord? record;
  CommunityFailureKind? failure;
  ProfileHoldings? holdingsAnswer;
  CommunityFailureKind? holdingsFailure;
  final List<ProfileTradesPage> tradePages;
  final bool pending;
  final List<String> calls = <String>[];

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async {
    calls.add('load:${target.key}');
    if (pending) return Completer<PublicProfileRecord>().future;
    final kind = failure;
    if (kind != null) throw CommunityGatewayException(kind);
    return record!;
  }

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) async {
    calls.add('holdings');
    final kind = holdingsFailure;
    if (kind != null) throw CommunityGatewayException(kind);
    return holdingsAnswer!;
  }

  @override
  Future<ProfileTradesPage> trades(
    String publicProfileId, {
    String? cursor,
  }) async {
    calls.add('trades:$cursor');
    return tradePages.removeAt(0);
  }

  @override
  Future<void> removeFriend(String publicProfileId) async {
    calls.add('unfriend');
    record = _record();
  }
}

/// The production gateway: the command form is the one the page must use,
/// since the search-flow form needs a search identity cache the profile page
/// never fills.
final class _CommandFriends extends Fake implements LoopSocialFriendGateway {
  final List<String> commands = <String>[];

  @override
  FriendGatewayMode get mode => FriendGatewayMode.production;

  @override
  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    commands.add(targetProfileRef.wireValue);
    return FriendRequestSendReceipt(
      operationId: operationId,
      targetProfileRef: targetProfileRef,
      friendRequestId: '9d1c5f64-5717-4562-b3fc-2c963f66a009',
    );
  }

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) => throw StateError('the profile page must not use the search flow');
}

final class _Friends implements FriendGateway {
  _Friends({this.failure});

  final FriendGatewayFailureKind? failure;
  final List<String> sent = <String>[];

  @override
  FriendGatewayMode get mode => FriendGatewayMode.production;

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    sent.add(profileRef.wireValue);
    final kind = failure;
    if (kind != null) throw FriendGatewayException(kind);
    return FriendSearchResult(
      identity: FriendIdentity(profileRef: profileRef, alias: 'frog_maxi'),
      relationship: FriendRelationship.outgoingPending,
      friendRequestId: '9d1c5f64-5717-4562-b3fc-2c963f66a009',
    );
  }

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) => throw UnimplementedError();

  @override
  Future<List<FriendIdentity>> loadFriends() => throw UnimplementedError();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      throw UnimplementedError();
}

final class _OwnProfile implements ProfileGateway {
  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async => ProfileResource(
    version: 1,
    values: ProfileValues(alias: 'me', avatarRef: null),
    updatedAt: DateTime.utc(2026, 9),
    loopId: _ownLoopId,
    profileStatus: ProfileStatus.active,
    activatedAt: DateTime.utc(2026, 9),
  );

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required PublicProfileGateway profiles,
  PublicProfileTarget? target = const PublicProfileById(_id),
  FakeSocialGateway? social,
  FriendGateway? friends,
  ProfileGateway? own,
  VoidCallback? onOpenSelf,
  ValueChanged<LoopPublicProfile>? onOpenDirectMessage,
  VoidCallback? onOpenFriendRequests,
  bool settle = true,
}) => pumpCommunityPage(
  tester,
  UserProfileScreen(
    target: target,
    onOpenSelf: onOpenSelf,
    onOpenDirectMessage: onOpenDirectMessage,
    onOpenFriendRequests: onOpenFriendRequests,
  ),
  social: social ?? FakeSocialGateway(),
  settle: settle,
  overrides: <Override>[
    publicProfileGatewayProvider.overrideWithValue(profiles),
    friendGatewayProvider.overrideWithValue(friends ?? _Friends()),
    if (own != null) profileGatewayProvider.overrideWithValue(own),
  ],
);

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  group('GET /v2/profiles codecs (S107 §3)', () {
    test('reads the contract example', () {
      final record = LoopV2PublicProfileCodec.profile(_profileWire());
      expect(record.publicProfileId, _id);
      expect(record.displayName, 'frog_maxi');
      expect(record.counts.followers, 128);
      expect(record.relationship.followedBy, isTrue);
      expect(record.relationship.friendship, ProfileFriendship.none);
      expect(record.visibility.holdings, isTrue);
    });

    test('refuses an extra key, a missing version, an unknown friendship', () {
      expect(
        () => LoopV2PublicProfileCodec.profile(
          _profileWire()..['walletAddress'] = '0xabc',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2PublicProfileCodec.profile(
          _profileWire()..remove('contractVersion'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      final unknown = _profileWire();
      (unknown['relationship']! as Map<String, Object?>)['friendship'] =
          'besties';
      expect(
        () => LoopV2PublicProfileCodec.profile(unknown),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('holdings: decimals stay exact and a foreign logo is dropped', () {
      final holdings = LoopV2PublicProfileCodec.holdings(_holdingsWire());
      expect(holdings.status, ProfileSectionStatus.available);
      expect(holdings.totalUsd, Decimal.parse('1284.52'));
      expect(holdings.items.first.balance, Decimal.parse('1.2'));
      expect(holdings.items.last.usdValue, isNull);
      // Not one of the hosts the client fetches artwork from.
      expect(holdings.items.last.logoUrl, isNull);
    });

    test('a hidden section carries no rows and no total', () {
      final hidden = LoopV2PublicProfileCodec.holdings(<String, Object?>{
        'status': 'hidden',
        'reasonCode': null,
        'totalUsd': null,
        'items': <Object?>[],
        'observedAt': null,
        'contractVersion': '2.0',
      });
      expect(hidden.status, ProfileSectionStatus.hidden);
      final leaking = _holdingsWire()..['status'] = 'hidden';
      expect(
        () => LoopV2PublicProfileCodec.holdings(leaking),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2PublicProfileCodec.holdings(_holdingsWire()..['extra'] = 1),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsWire()..remove('contractVersion'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('trades: the contract example, and refusals', () {
      final page = LoopV2PublicProfileCodec.trades(_tradesWire());
      expect(page.items.single.kind, ProfileTradeKind.buy);
      expect(page.items.single.amount, Decimal.parse('0.4'));
      expect(page.nextCursor, isNull);
      final badKind = _tradesWire();
      ((badKind['items']! as List<Object?>).single!
              as Map<String, Object?>)['kind'] =
          'mint';
      expect(
        () => LoopV2PublicProfileCodec.trades(badKind),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2PublicProfileCodec.trades(
          _tradesWire()..remove('contractVersion'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the delivered shape: reasonCode only when unavailable, a trade '
        'without block time names its block', () {
      final noWallet = LoopV2PublicProfileCodec.holdings(<String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'WALLET_NOT_BOUND',
        'totalUsd': null,
        'items': <Object?>[],
        'observedAt': null,
        'contractVersion': '2.0',
      });
      expect(noWallet.status, ProfileSectionStatus.unavailable);
      expect(noWallet.reasonCode, 'WALLET_NOT_BOUND');
      expect(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsWire()..['reasonCode'] = 'WALLET_NOT_BOUND',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2PublicProfileCodec.holdings(
          _holdingsWire()..remove('reasonCode'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      final untimed = _tradesWire();
      final row =
          (untimed['items']! as List<Object?>).single! as Map<String, Object?>;
      row['blockTimestamp'] = null;
      final page = LoopV2PublicProfileCodec.trades(untimed);
      expect(page.items.single.blockTimestamp, isNull);
      expect(page.items.single.blockNumber, '300');
      row.remove('blockNumber');
      expect(
        () => LoopV2PublicProfileCodec.trades(untimed),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('404 PROFILE_NOT_FOUND is not found; other 404 and 503 are '
        'unavailable', () {
      expect(
        publicProfileFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
            statusCode: 404,
            code: 'PROFILE_NOT_FOUND',
          ),
          write: false,
        ),
        CommunityFailureKind.notFound,
      );
      expect(
        publicProfileFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
            statusCode: 404,
          ),
          write: false,
        ),
        CommunityFailureKind.unavailable,
      );
      expect(
        publicProfileFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.unavailable,
            statusCode: 503,
            code: 'CAPABILITY_UNAVAILABLE',
          ),
          write: false,
        ),
        CommunityFailureKind.unavailable,
      );
    });

    test('a route the server does not mount yet is unavailable', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _StatusAdapter(404);
      await expectLater(
        DioLoopV2PublicProfileApi(dio).load(
          accessToken: 'token',
          clientVersion: '1.0.0',
          target: const PublicProfileByLoopId(_loopId),
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => publicProfileFailureKind(failure, write: false),
            'kind',
            CommunityFailureKind.unavailable,
          ),
        ),
      );
    });
  });

  group('user-profile route parameters', () {
    test('only an id or a LOOP ID names a page', () {
      expect(
        userProfileTargetFromQuery(const <String, String>{'id': _id}),
        const PublicProfileById(_id),
      );
      expect(
        userProfileTargetFromQuery(const <String, String>{
          'loopId': 'loop-7kq2m9xa',
        }),
        const PublicProfileByLoopId(_loopId),
      );
      expect(
        userProfileTargetFromQuery(const <String, String>{'id': 'frog'}),
        isNull,
      );
      expect(userProfileTargetFromQuery(const <String, String>{}), isNull);
      expect(userProfileLocation(_id), '/profile/user?id=$_id');
    });
  });

  group('user-profile page · five states', () {
    testWidgets('loading', (tester) async {
      final profiles = _Profiles(pending: true);
      await _pump(tester, profiles: profiles, settle: false);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      // A read in flight is never restarted by the frames spent waiting on
      // it (the dev build once sent one request per frame).
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(profiles.calls, <String>['load:id:$_id']);
    });

    testWidgets('not found (404 PROFILE_NOT_FOUND) is its own empty state', (
      tester,
    ) async {
      await _pump(
        tester,
        profiles: _Profiles(failure: CommunityFailureKind.notFound),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-not-found')),
        findsOneWidget,
      );
      expect(find.text('找不到这个用户'), findsOneWidget);
    });

    testWidgets('unavailable (404/503) never draws a fixture', (tester) async {
      await _pump(
        tester,
        profiles: _Profiles(failure: CommunityFailureKind.unavailable),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-unavailable')),
        findsOneWidget,
      );
      expect(find.text('frog_maxi'), findsNothing);
    });

    for (final (kind, key) in <(CommunityFailureKind, String)>[
      (CommunityFailureKind.offline, 'community-state-offline'),
      (CommunityFailureKind.permissionDenied, 'community-state-permission'),
      (CommunityFailureKind.unexpected, 'community-state-error'),
    ]) {
      testWidgets('${kind.name} reuses the shared state block', (tester) async {
        await _pump(tester, profiles: _Profiles(failure: kind));
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }

    testWidgets('a link that names nobody opens nothing', (tester) async {
      final profiles = _Profiles(record: _record());
      await _pump(tester, profiles: profiles, target: null);
      expect(
        find.byKey(const ValueKey<String>('user-profile-invalid-target')),
        findsOneWidget,
      );
      expect(profiles.calls, isEmpty);
    });
  });

  group('user-profile page · header and sections', () {
    testWidgets('ready: header, counts and the three-button action row', (
      tester,
    ) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        ),
      );
      expect(find.text('frog_maxi'), findsWidgets);
      expect(find.text(_loopId), findsOneWidget);
      expect(find.text('长期持有'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('user-profile-friend-none')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-follow')),
        findsOneWidget,
      );
      // 持仓 is the first section: the total and both rows.
      expect(find.text('\$1,284.52'), findsOneWidget);
      expect(find.text('BNB'), findsWidgets);
      expect(find.text('暂无报价'), findsOneWidget);
    });

    testWidgets('a hidden section asks nothing and says 对方未公开', (tester) async {
      final profiles = _Profiles(
        record: _record(holdings: false, trades: false),
      );
      await _pump(tester, profiles: profiles);
      expect(
        find.byKey(const ValueKey<String>('user-profile-holdings-hidden')),
        findsOneWidget,
      );
      await tester.tap(find.text('交易'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('user-profile-trades-hidden')),
        findsOneWidget,
      );
      expect(profiles.calls, isNot(contains('holdings')));
    });

    testWidgets('an unavailable section never shows a zero', (tester) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: const ProfileHoldings(
            status: ProfileSectionStatus.unavailable,
            totalUsd: null,
            items: <ProfileHolding>[],
            observedAt: null,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-holdings-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('\$0'), findsNothing);
    });

    testWidgets('WALLET_NOT_BOUND reads as no wallet, not an outage', (
      tester,
    ) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: const ProfileHoldings(
            status: ProfileSectionStatus.unavailable,
            totalUsd: null,
            items: <ProfileHolding>[],
            observedAt: null,
            reasonCode: 'WALLET_NOT_BOUND',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-holdings-no-wallet')),
        findsOneWidget,
      );
      expect(find.text('对方暂无钱包'), findsOneWidget);
      expect(find.textContaining('\$0'), findsNothing);
    });

    testWidgets('a closed holdings route reads unavailable too', (
      tester,
    ) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsFailure: CommunityFailureKind.unavailable,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-holdings-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('trades scroll in pages', (tester) async {
      final first = LoopV2PublicProfileCodec.trades(_tradesWire());
      final profiles = _Profiles(
        record: _record(),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        tradePages: <ProfileTradesPage>[
          ProfileTradesPage(
            status: ProfileSectionStatus.available,
            items: first.items,
            nextCursor: 'abc.def',
          ),
          ProfileTradesPage(
            status: ProfileSectionStatus.available,
            items: <ProfileTrade>[
              ProfileTrade(
                eventId: 'evt_2',
                kind: ProfileTradeKind.sell,
                assetId: 'eip155:56:native',
                symbol: 'BNB',
                amount: Decimal.parse('0.1'),
                usdValue: null,
                blockTimestamp: DateTime.utc(2026, 10, 7),
                txHash: '0x${'b' * 64}',
              ),
            ],
            nextCursor: null,
          ),
        ],
      );
      await _pump(tester, profiles: profiles);
      await tester.tap(find.text('交易'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('user-profile-trades-end')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        profiles.calls,
        containsAllInOrder(<String>['trades:null', 'trades:abc.def']),
      );
      expect(find.text('买入 BNB'), findsOneWidget);
      expect(find.text('卖出 BNB'), findsOneWidget);
    });

    testWidgets('the 社区 section states the count and no list', (tester) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        ),
      );
      await tester.tap(find.text('社区').last);
      await tester.pumpAndSettle();
      expect(find.text('已加入 4 个社区'), findsOneWidget);
    });
  });

  group('user-profile page · relationship actions', () {
    testWidgets('加好友 sends one request and re-reads the record', (
      tester,
    ) async {
      final friends = _Friends();
      final profiles = _Profiles(
        record: _record(),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
      );
      await _pump(tester, profiles: profiles, friends: friends);
      profiles.record = _record(friendship: ProfileFriendship.pendingOut);
      await _tap(tester, 'user-profile-friend-none');

      expect(friends.sent, <String>[_id]);
      expect(
        profiles.calls.where((call) => call.startsWith('load')),
        hasLength(2),
      );
      expect(
        find.byKey(const ValueKey<String>('user-profile-friend-pending_out')),
        findsOneWidget,
      );
      expect(find.text('好友申请已发送'), findsOneWidget);
    });

    testWidgets(
      '加好友 on the production gateway uses the command form and re-reads',
      (tester) async {
        final friends = _CommandFriends();
        final profiles = _Profiles(
          record: _record(),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        );
        await _pump(tester, profiles: profiles, friends: friends);
        profiles.record = _record(friendship: ProfileFriendship.pendingOut);
        await _tap(tester, 'user-profile-friend-none');

        expect(friends.commands, <String>[_id]);
        expect(
          profiles.calls.where((call) => call.startsWith('load')),
          hasLength(2),
        );
        expect(
          find.byKey(const ValueKey<String>('user-profile-friend-pending_out')),
          findsOneWidget,
        );
        expect(find.text('好友申请已发送'), findsOneWidget);
      },
    );

    testWidgets('a refused request says why and changes nothing', (
      tester,
    ) async {
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        ),
        friends: _Friends(failure: FriendGatewayFailureKind.permissionDenied),
      );
      await _tap(tester, 'user-profile-friend-none');
      expect(find.text('对方没有开放好友申请。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('user-profile-friend-none')),
        findsOneWidget,
      );
    });

    testWidgets('an incoming request opens 好友申请', (tester) async {
      var opened = 0;
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(friendship: ProfileFriendship.pendingIn),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        ),
        onOpenFriendRequests: () => opened += 1,
      );
      await _tap(tester, 'user-profile-friend-pending_in');
      expect(opened, 1);
    });

    testWidgets('关注 follows through the social gateway', (tester) async {
      final social = FakeSocialGateway();
      final profiles = _Profiles(
        record: _record(),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
      );
      await _pump(tester, profiles: profiles, social: social);
      profiles.record = _record(following: true);
      await _tap(tester, 'user-profile-follow');
      expect(social.commands, contains('follow:$_id:true'));
      expect(
        find.byKey(const ValueKey<String>('user-profile-unfollow')),
        findsOneWidget,
      );
    });

    testWidgets('私聊 hands the profile to the caller', (tester) async {
      LoopPublicProfile? opened;
      await _pump(
        tester,
        profiles: _Profiles(
          record: _record(),
          holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
        ),
        onOpenDirectMessage: (profile) => opened = profile,
      );
      await _tap(tester, 'user-profile-message');
      expect(opened?.publicProfileId, _id);
      expect(opened?.loopId, _loopId);
    });

    testWidgets('删除好友 confirms, deletes and re-reads', (tester) async {
      final profiles = _Profiles(
        record: _record(friendship: ProfileFriendship.friends),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
      );
      await _pump(tester, profiles: profiles);
      await _tap(tester, 'user-profile-more');
      await _tap(tester, 'user-profile-remove-friend');
      expect(find.text('删除好友？'), findsOneWidget);
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('unfriend'));
      expect(
        find.byKey(const ValueKey<String>('user-profile-friend-none')),
        findsOneWidget,
      );
    });

    testWidgets('拉黑 confirms and blocks; 举报 says it is not open', (
      tester,
    ) async {
      final social = FakeSocialGateway();
      final profiles = _Profiles(
        record: _record(),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
      );
      await _pump(tester, profiles: profiles, social: social);
      await _tap(tester, 'user-profile-more');
      expect(
        find.byKey(const ValueKey<String>('user-profile-report-unavailable')),
        findsOneWidget,
      );
      profiles.record = _record(blocked: true);
      await _tap(tester, 'user-profile-block');
      await tester.tap(find.text('拉黑').last);
      await tester.pumpAndSettle();
      expect(social.commands, contains('block:user:$_id:true'));
      expect(
        find.byKey(const ValueKey<String>('user-profile-blocked')),
        findsOneWidget,
      );
      // A blocked account's actions and sections are gone.
      expect(
        find.byKey(const ValueKey<String>('user-profile-message')),
        findsNothing,
      );
    });

    testWidgets('the viewer\'s own LOOP ID hands over to 我', (tester) async {
      var self = 0;
      final profiles = _Profiles(
        record: _record(loopId: _ownLoopId),
        holdingsAnswer: LoopV2PublicProfileCodec.holdings(_holdingsWire()),
      );
      await _pump(
        tester,
        profiles: profiles,
        own: _OwnProfile(),
        onOpenSelf: () => self += 1,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(UserProfileScreen)),
      );
      await container.read(profileControllerProvider.notifier).load();
      await tester.pumpAndSettle();
      expect(self, 1);
    });
  });
}

final class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"Route not found"}',
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
