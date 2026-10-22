// S283 · decision 0239: the operator's free-text community label replaces
// 「已验证」 on every reader surface.
//
// The `label` key is client-first: the server sends nothing, `null`, `""` or
// a string, and the first three are all "no label" — never an invalid
// community. The shot case writes docs/integration/S283/shots/ only with
// `--dart-define=LOOP_SHOTS=true`.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_profile_communities.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const _absent = Object();

Map<String, Object?> _wireCommunity({Object? label = _absent}) =>
    <String, Object?>{
      'communityId': testCommunityId,
      'name': 'Frog Holders',
      'slug': 'frog-holders',
      'description': null,
      'logoRef': 'avatar:preset/community-03',
      'verificationStatus': 'verified',
      'boundAssetKey': null,
      'memberCount': 128,
      'createdAt': '2026-09-07T01:00:00.000Z',
      'configVersion': 'communityV1',
      if (!identical(label, _absent)) 'label': label,
    };

Map<String, Object?> _wireProfileRow({Object? label = _absent}) =>
    <String, Object?>{
      'communityId': testCommunityId,
      'name': '星夜社区',
      'slug': 'star-night',
      'logoRef': null,
      'memberCount': 1284,
      'verificationStatus': 'verified',
      'joinedAt': '2026-10-01T00:00:00.000Z',
      if (!identical(label, _absent)) 'label': label,
    };

CommunityDirectoryPage _page(List<CommunitySummary> items) =>
    CommunityDirectoryPage(
      items: items,
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

const _ids = <String>[
  '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  '4bb85f64-5717-4562-b3fc-2c963f66afb7',
  '5cc85f64-5717-4562-b3fc-2c963f66afc8',
  '6dd85f64-5717-4562-b3fc-2c963f66afd9',
];

List<CommunitySummary> _squareRows() => <CommunitySummary>[
  testCommunity(communityId: _ids[0], name: '算力先锋', label: '算力社区'),
  testCommunity(communityId: _ids[1], name: 'Builders Guild', memberCount: 42),
  testCommunity(
    communityId: _ids[2],
    name: '一个名字特别特别长的社区会被省略号截断',
    label: '这是一个超过十二个字的很长的运营标签文字',
  ),
  testCommunity(
    communityId: _ids[3],
    name: '审核中的社区',
    verification: CommunityVerification.pending,
    memberCount: 3,
  ),
];

Future<void> _pumpSquare(WidgetTester tester) => pumpCommunityPage(
  tester,
  SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
  community: FakeCommunityGateway(directoryPage: _page(_squareRows())),
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  loopWatchGround();

  group('S283 · wire', () {
    test('community: a label string is kept, trimmed', () {
      final c = LoopV2ProjectionCodec.community(
        _wireCommunity(label: '  算力社区 '),
      );
      expect(c.label, '算力社区');
    });

    test('community: absent, null, empty, blank, non-string are no label', () {
      for (final label in <Object?>[_absent, null, '', '   ', 7, true]) {
        final c = LoopV2ProjectionCodec.community(_wireCommunity(label: label));
        expect(c.label, isNull, reason: 'label: $label');
        expect(c.verificationStatus, CommunityVerification.verified);
      }
    });

    test('directory row: with, without and null label all read', () {
      for (final (label, expected) in <(Object?, String?)>[
        ('精选社区', '精选社区'),
        (_absent, null),
        (null, null),
      ]) {
        final row = LoopV2ProjectionCodec.communityRow(
          _wireCommunity(label: label),
          sort: CommunityDirectorySort.members,
        );
        expect(row.label, expected);
      }
    });

    test('a join keeps the label', () {
      final joined = testCommunity(label: '算力社区').withJoin(
        viewer: const CommunityDirectoryViewer(
          role: CommunityRole.member,
          status: CommunityMemberStatus.active,
          pending: false,
        ),
        memberCount: 129,
      );
      expect(joined.label, '算力社区');
    });

    test('profile community row: with, without and null label all read', () {
      for (final (label, expected) in <(Object?, String?)>[
        ('算力社区', '算力社区'),
        (_absent, null),
        (null, null),
        ('', null),
      ]) {
        final row = LoopV2ProfileCommunitiesCodec.row(
          _wireProfileRow(label: label),
        );
        expect(row.label, expected);
      }
    });

    test('an unknown key next to label is still refused', () {
      expect(
        () => LoopV2ProjectionCodec.community(
          _wireCommunity(label: 'x')..['badge'] = 'y',
        ),
        throwsA(anything),
      );
    });

    test('a search community snapshot tolerates the label key', () async {
      for (final label in <Object?>[_absent, null, '算力社区']) {
        final api = DioLoopV2SearchApi(
          Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) => handler.resolve(
                  Response<Object?>(
                    requestOptions: options,
                    statusCode: 200,
                    headers: Headers.fromMap(<String, List<String>>{
                      'cache-control': <String>['no-store'],
                      'x-request-id': <String>[
                        '11111111-1111-4111-8111-111111111111',
                      ],
                    }),
                    data: <String, Object?>{
                      'domain': 'communities',
                      'status': 'available',
                      'reasonCode': null,
                      'results': <Object?>[
                        <String, Object?>{
                          'resultType': 'community',
                          'stableId': testCommunityId,
                          'displaySnapshot': <String, Object?>{
                            'title': 'Frog Holders',
                            'subtitle': 'frog-holders',
                            'avatarRef': 'avatar:preset/community-03',
                            'logo': null,
                            'memberCount': 128,
                            'verificationStatus': 'verified',
                            if (!identical(label, _absent)) 'label': label,
                          },
                          'destination': <String, Object?>{
                            'kind': 'communityProfile',
                          },
                        },
                      ],
                      'nextCursor': null,
                      'contractVersion': '2.0',
                    },
                  ),
                ),
              ),
            ),
        );
        final page = await api.search(
          accessToken: 'token',
          clientVersion: '0.1.0+1',
          domain: SearchDomain.communities,
          query: 'frog',
        );
        expect(page.results, hasLength(1), reason: 'label: $label');
      }
    });
  });

  group('S283 · display', () {
    test('at most 12 characters, the rest is an ellipsis', () {
      expect(communityLabelDisplay('算力社区'), '算力社区');
      expect(communityLabelDisplay('一二三四五六七八九十十一'), '一二三四五六七八九十十一');
      expect(communityLabelDisplay('一二三四五六七八九十十一十二'), '一二三四五六七八九十十一…');
    });

    testWidgets('directory row: label after the count, or the count alone', (
      tester,
    ) async {
      final labelled = communityDirectoryRow(
        community: testCommunity(memberCount: 312, label: '精选社区'),
        onTap: () {},
      );
      expect(labelled.subtitle, '312 名成员 · 精选社区');
      final plain = communityDirectoryRow(
        community: testCommunity(memberCount: 312),
        onTap: () {},
      );
      expect(plain.subtitle, '312 名成员');
      final pending = communityDirectoryRow(
        community: testCommunity(
          memberCount: 312,
          verification: CommunityVerification.pending,
        ),
        onTap: () {},
      );
      // A visitor is never told the review state.
      expect(pending.subtitle, '312 名成员');
    });

    testWidgets('square: a labelled row wears the label, the others nothing', (
      tester,
    ) async {
      await _pumpSquare(tester);
      expect(find.text('已验证'), findsNothing);
      expect(find.text('审核中'), findsNothing);
      expect(_key('square-community-label-${_ids[0]}'), findsOneWidget);
      expect(find.text('算力社区'), findsOneWidget);
      expect(_key('square-community-label-${_ids[1]}'), findsNothing);
      expect(_key('square-community-label-${_ids[3]}'), findsNothing);

      // The long label is cut to 12 and never pushes the name out.
      expect(find.text('这是一个超过十二个字的很…'), findsOneWidget);
      final row = tester.getRect(_key('square-community-open-${_ids[2]}'));
      final badge = tester.getRect(_key('square-community-label-${_ids[2]}'));
      expect(badge.right, lessThanOrEqualTo(row.right));
      final name = tester.getRect(find.text('一个名字特别特别长的社区会被省略号截断'));
      expect(name.width, greaterThan(badge.width));
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });

    testWidgets('community home: a visitor sees the label, never the review', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(label: '算力社区'),
            viewer: testViewer(role: CommunityRole.member),
          ),
        ),
      );
      expect(_key('community-profile-label'), findsOneWidget);
      expect(find.text('算力社区'), findsOneWidget);
      expect(find.text('已验证'), findsNothing);
      expect(_key('community-profile-owner-review'), findsNothing);
    });

    testWidgets('community home: no label, no mark', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: null)),
        ),
      );
      expect(_key('community-profile-label'), findsNothing);
      expect(find.text('已验证'), findsNothing);
    });

    testWidgets('community home: a pending review is the owner\'s alone', (
      tester,
    ) async {
      final pending = testCommunity(
        verification: CommunityVerification.pending,
      );
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: pending,
            viewer: testViewer(role: null),
          ),
        ),
      );
      expect(_key('community-profile-owner-review'), findsNothing);
      expect(find.text('审核中'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail(community: pending)),
      );
      expect(_key('community-profile-owner-review'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('community-profile-owner-review'),
          matching: find.text('审核中'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('square shot', skip: !_shots, (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpSquare(tester);
      await loopShot(
        tester,
        'square-community-labels',
        dir: 'docs/integration/S283/shots',
      );
      await _drain(tester);
    });
  });
}
