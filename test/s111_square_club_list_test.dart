import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const _otherId = '4b96a75e-6828-4a6b-8c1d-2e3f4a5b6c7d';
const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

CommunitySummary _row({
  String communityId = testCommunityId,
  String name = 'Frog Holders',
  CommunityDirectoryViewer? viewer,
  String? symbol,
  LoopMiningPowerFact? miningPower,
}) {
  final base = testCommunity(
    communityId: communityId,
    name: name,
    miningPower: miningPower,
  );
  return CommunitySummary(
    communityId: base.communityId,
    name: base.name,
    slug: base.slug,
    description: base.description,
    logoRef: base.logoRef,
    verificationStatus: base.verificationStatus,
    boundAssetKey: symbol == null ? null : _assetId,
    memberCount: base.memberCount,
    createdAt: base.createdAt,
    configVersion: base.configVersion,
    miningPower: base.miningPower,
    assetBadge: symbol == null
        ? null
        : CommunityAssetBadge(assetId: _assetId, symbol: symbol, logoUrl: null),
    viewerMembership: viewer,
  );
}

CommunityDirectoryPage _page(
  List<CommunitySummary> items, {
  CommunityDirectorySort sort = CommunityDirectorySort.members,
  String? nextCursor,
}) => CommunityDirectoryPage(
  items: items,
  nextCursor: nextCursor,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
  ordering: CommunityOrderingApplied(
    sort: sort,
    basis: const CommunityStoredBasis(),
  ),
);

FakeCommunityGateway _filtered({
  required CommunityDirectoryPage all,
  required CommunityDirectoryPage joined,
}) =>
    FakeCommunityGateway(directoryPage: all)
      ..directoryPagesByMembership[CommunityMembershipFilter.joined] = joined;

Future<void> _pump(
  WidgetTester tester,
  FakeCommunityGateway gateway, {
  ValueChanged<String>? onOpenCommunity,
  VoidCallback? onOpenSearch,
  bool settle = true,
}) => pumpCommunityPage(
  tester,
  SquareCommunityList(
    onOpenCommunity: onOpenCommunity ?? (_) {},
    onOpenSearch: onOpenSearch ?? () {},
  ),
  community: gateway,
  settle: settle,
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

/// The chip line scrolls sideways; a chip past the edge is brought in first.
Future<void> _tapChip(WidgetTester tester, String key) async {
  final chip = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String key) =>
    tester.widget<LoopSeg>(find.byKey(ValueKey<String>(key))).selected;

void main() {
  loopWatchGround();

  group('S111 · compact head and search entry', () {
    testWidgets('no DISCOVERY DESK card; one rule line and 规则 opens the '
        'rules', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(directoryPage: _page(<CommunitySummary>[_row()])),
      );
      expect(find.text('DISCOVERY DESK'), findsNothing);
      expect(find.textContaining('已载入'), findsNothing);
      expect(find.text(squareCommunityRuleLine), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('square-community-rules')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('square-community-rules-sheet')),
        findsOneWidget,
      );
      expect(find.text('RULE · rule:verified-members-v1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('square-community-apply')),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('the search entry opens search', (tester) async {
      var opened = 0;
      await _pump(
        tester,
        FakeCommunityGateway(directoryPage: _page(<CommunitySummary>[_row()])),
        onOpenSearch: () => opened += 1,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('square-community-search')),
      );
      await tester.pump();
      expect(opened, 1);
      await _drain(tester);
    });
  });

  group('S111 · chips', () {
    testWidgets('the chips stay pinned while the head and rows scroll', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            for (var index = 0; index < 30; index += 1)
              _row(
                communityId:
                    '20000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
                name: 'Club $index',
              ),
          ]),
        ),
      );
      final chips = find.byKey(
        const ValueKey<String>('square-community-chips'),
      );
      final before = tester.getTopLeft(chips).dy;
      await tester.drag(
        find.byKey(const ValueKey<String>('square-community-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text(squareCommunityRuleLine).hitTestable(), findsNothing);
      expect(chips.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(chips).dy, lessThan(before));
      await _drain(tester);
    });

    testWidgets('the two groups are each exclusive and combine in the '
        'request', (tester) async {
      final gateway =
          _filtered(
              all: _page(<CommunitySummary>[_row()]),
              joined: _page(<CommunitySummary>[
                _row(viewer: _member),
              ], sort: CommunityDirectorySort.newest),
            )
            ..directoryPagesBySort[CommunityDirectorySort.newest] = _page(
              <CommunitySummary>[_row()],
              sort: CommunityDirectorySort.newest,
            );
      await _pump(tester, gateway);
      expect(gateway.commands.last, 'list:members:all:null');
      expect(_selected(tester, 'square-filter-all'), isTrue);
      expect(_selected(tester, 'square-filter-joined'), isFalse);
      expect(_selected(tester, 'square-sort-members'), isTrue);

      await _tapChip(tester, 'square-sort-newest');
      expect(gateway.commands.last, 'list:newest:all:null');
      expect(_selected(tester, 'square-sort-newest'), isTrue);
      expect(_selected(tester, 'square-sort-members'), isFalse);
      expect(_selected(tester, 'square-filter-all'), isTrue);

      await _tapChip(tester, 'square-filter-joined');
      // 我加入的 keeps the chosen order.
      expect(gateway.commands.last, 'list:newest:joined:null');
      expect(_selected(tester, 'square-filter-joined'), isTrue);
      expect(_selected(tester, 'square-filter-all'), isFalse);
      expect(_selected(tester, 'square-sort-newest'), isTrue);

      await _tapChip(tester, 'square-filter-all');
      expect(gateway.commands.last, 'list:newest:all:null');
      await _drain(tester);
    });

    testWidgets('我加入的 with nothing joined says so and goes back to 全部', (
      tester,
    ) async {
      final gateway = _filtered(
        all: _page(<CommunitySummary>[_row()]),
        joined: _page(const <CommunitySummary>[]),
      );
      await _pump(tester, gateway);
      await _tapChip(tester, 'square-filter-joined');
      expect(
        find.byKey(const ValueKey<String>('square-community-joined-empty')),
        findsOneWidget,
      );
      expect(find.text('还没有加入社区'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('square-community-joined-empty-all')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.last, 'list:members:all:null');
      expect(find.text('Frog Holders'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('S111 · rows', () {
    testWidgets('the right edge follows viewerMembership', (tester) async {
      const ids = <String>[
        '10000000-0000-4000-8000-000000000001',
        '10000000-0000-4000-8000-000000000002',
        '10000000-0000-4000-8000-000000000003',
        '10000000-0000-4000-8000-000000000004',
        '10000000-0000-4000-8000-000000000005',
        '10000000-0000-4000-8000-000000000006',
        '10000000-0000-4000-8000-000000000007',
      ];
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _row(communityId: ids[0], viewer: CommunityDirectoryViewer.none),
            _row(communityId: ids[1], viewer: _member),
            _row(
              communityId: ids[2],
              viewer: const CommunityDirectoryViewer(
                role: CommunityRole.admin,
                status: CommunityMemberStatus.active,
                pending: false,
              ),
            ),
            _row(
              communityId: ids[3],
              viewer: const CommunityDirectoryViewer(
                role: CommunityRole.owner,
                status: CommunityMemberStatus.active,
                pending: true,
              ),
            ),
            _row(
              communityId: ids[4],
              viewer: const CommunityDirectoryViewer(
                role: CommunityRole.member,
                status: CommunityMemberStatus.banned,
                pending: false,
              ),
            ),
            // An older API: no block, no capsule.
            _row(communityId: ids[5]),
            _row(
              communityId: ids[6],
              viewer: const CommunityDirectoryViewer(
                role: null,
                status: null,
                pending: true,
              ),
            ),
          ]),
        ),
      );
      Finder capsule(String kind, String id) =>
          find.byKey(ValueKey<String>('square-community-$kind-$id'));
      expect(capsule('join', ids[0]), findsOneWidget);
      expect(capsule('joined', ids[1]), findsOneWidget);
      expect(capsule('joined', ids[2]), findsOneWidget);
      expect(capsule('mine', ids[3]), findsOneWidget);
      for (final kind in <String>['join', 'joined', 'mine', 'pending']) {
        expect(capsule(kind, ids[4]), findsNothing);
        expect(capsule(kind, ids[5]), findsNothing);
      }
      expect(capsule('pending', ids[6]), findsOneWidget);
      expect(find.text('加入'), findsOneWidget);
      expect(find.text('已加入'), findsNWidgets(2));
      expect(find.text('我的'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the second line is members and the token, or the ranked '
        'fact', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _row(symbol: 'FROG'),
            _row(communityId: _otherId, name: 'Builders Guild'),
          ]),
        ),
      );
      expect(find.text('128 成员 · \$FROG'), findsOneWidget);
      expect(find.text('128 成员'), findsOneWidget);
      expect(find.text('已验证'), findsNWidgets(2));

      final opened = <String>[];
      await _drain(tester);
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _row(
              symbol: 'FROG',
              miningPower: testSettledCommunityMiningPower(power: '1234'),
            ),
          ], sort: CommunityDirectorySort.miningPower),
        ),
        onOpenCommunity: opened.add,
      );
      await _tapChip(tester, 'square-sort-power');
      expect(find.textContaining('128 成员 · 算力 '), findsOneWidget);
      expect(find.textContaining('\$FROG'), findsNothing);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('square-community-open-$testCommunityId'),
        ),
      );
      expect(opened, <String>[testCommunityId]);
      await _drain(tester);
    });
  });

  group('S111 · inline join', () {
    testWidgets('a confirmed join turns 加入 into 已加入 in place, with no '
        'confirmation sheet', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _page(<CommunitySummary>[
          _row(viewer: CommunityDirectoryViewer.none),
        ]),
        detail: testDetail(
          community: testCommunity(memberCount: 129),
          viewer: testViewer(role: CommunityRole.member),
        ),
      );
      await _pump(tester, gateway);
      final reads = gateway.commands.length;
      await tester.tap(
        find.byKey(
          const ValueKey<String>('square-community-join-$testCommunityId'),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('community-membership-sheet')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.sublist(reads), <String>[
        'join:$testCommunityId',
      ]);
      expect(
        find.byKey(
          const ValueKey<String>('square-community-joined-$testCommunityId'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('square-community-join-$testCommunityId'),
        ),
        findsNothing,
      );
      expect(find.text('129 成员'), findsOneWidget);
      expect(find.text('已加入'), findsWidgets);
      await _drain(tester);
    });

    testWidgets('a refused join keeps 加入 and says why', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _page(<CommunitySummary>[
          _row(viewer: CommunityDirectoryViewer.none),
        ]),
        writeFailure: CommunityFailureKind.permissionDenied,
      );
      await _pump(tester, gateway);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('square-community-join-$testCommunityId'),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.last, 'join:$testCommunityId');
      expect(
        find.byKey(
          const ValueKey<String>('square-community-join-$testCommunityId'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          communityFailureReason(CommunityFailureKind.permissionDenied),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });
  });

  group('S111 · page states', () {
    testWidgets('loading', (tester) async {
      final gateway = FakeCommunityGateway(directoryPage: _page(const []))
        ..pending = true;
      await _pump(tester, gateway, settle: false);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('square-community-state')),
        findsOneWidget,
      );
      expect(find.text(squareCommunityRuleLine), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('empty', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(directoryPage: _page(const <CommunitySummary>[])),
      );
      expect(find.text('没有符合条件的社区'), findsOneWidget);
      await _drain(tester);
    });

    for (final kind in <CommunityFailureKind>[
      CommunityFailureKind.offline,
      CommunityFailureKind.unexpected,
      CommunityFailureKind.permissionDenied,
      CommunityFailureKind.unavailable,
    ]) {
      testWidgets('failure ${kind.name}', (tester) async {
        await _pump(
          tester,
          FakeCommunityGateway(
            directoryPage: _page(<CommunitySummary>[_row()]),
            failure: kind,
          ),
        );
        expect(
          find.byKey(const ValueKey<String>('square-community-state')),
          findsOneWidget,
        );
        expect(find.text('Frog Holders'), findsNothing);
        await _drain(tester);
      });
    }

    testWidgets('the last page ends in 没有更多社区; a next page is read on '
        'scroll', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _page(<CommunitySummary>[_row()], nextCursor: 'abc.def'),
      )..readDelay = const Duration(milliseconds: 50);
      await _pump(tester, gateway, settle: false);
      // Page one is in the air with its cursor; the next page is the last.
      gateway.directoryPage = _page(<CommunitySummary>[
        _row(communityId: _otherId, name: 'Builders Guild'),
      ]);
      await tester.pumpAndSettle();
      expect(
        gateway.commands.where((c) => c.startsWith('list:')).toList(),
        <String>['list:members:all:null', 'list:members:all:abc.def'],
      );
      expect(find.text('Builders Guild'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('square-community-end')),
        findsOneWidget,
      );
      expect(find.text('没有更多社区'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('S111 · directory row codec', () {
    Map<String, Object?> wire({
      Object? viewer,
      Object? asset,
      bool tail = true,
    }) => <String, Object?>{
      'communityId': testCommunityId,
      'name': 'Frog Holders',
      'slug': 'frog-holders',
      'description': null,
      'logoRef': null,
      'verificationStatus': 'verified',
      'boundAssetKey': _assetId,
      'memberCount': 128,
      'createdAt': '2026-06-01T00:00:00.000Z',
      'configVersion': 'communityV1',
      if (tail) 'viewerMembership': viewer,
      if (tail) 'boundAsset': asset,
    };

    test('reads viewerMembership and the three-field boundAsset', () {
      final row = LoopV2ProjectionCodec.communityRow(
        wire(
          viewer: <String, Object?>{
            'role': 'member',
            'status': 'active',
            'pending': false,
          },
          asset: <String, Object?>{
            'assetId': _assetId,
            'symbol': 'FROG',
            'logoUrl': 'https://cdn.example.com/frog.png',
          },
        ),
        sort: CommunityDirectorySort.members,
      );
      expect(row.viewerMembership?.role, CommunityRole.member);
      expect(row.viewerMembership?.status, CommunityMemberStatus.active);
      expect(row.viewerMembership?.pending, isFalse);
      expect(row.assetBadge?.symbol, 'FROG');
      expect(row.assetSymbol, 'FROG');
      // A row never states a pool.
      expect(row.boundAsset, isNull);
    });

    test('no relation, and boundAsset null', () {
      final row = LoopV2ProjectionCodec.communityRow(
        wire(
          viewer: <String, Object?>{
            'role': null,
            'status': null,
            'pending': false,
          },
          asset: null,
        ),
        sort: CommunityDirectorySort.members,
      );
      expect(row.viewerMembership?.role, isNull);
      expect(row.viewerMembership?.status, isNull);
      expect(row.assetBadge, isNull);
      expect(
        squareMembershipAction(row.viewerMembership),
        SquareMembershipAction.join,
      );
    });

    test('an API without the tails reads with no relation stated', () {
      final row = LoopV2ProjectionCodec.communityRow(
        wire(tail: false),
        sort: CommunityDirectorySort.members,
      );
      expect(row.viewerMembership, isNull);
      expect(row.assetBadge, isNull);
      expect(
        squareMembershipAction(row.viewerMembership),
        SquareMembershipAction.none,
      );
    });

    test('an unknown role or a non-boolean pending is refused', () {
      expect(
        () => LoopV2ProjectionCodec.communityRow(
          wire(
            viewer: <String, Object?>{
              'role': 'moderator',
              'status': 'active',
              'pending': false,
            },
            asset: null,
          ),
          sort: CommunityDirectorySort.members,
        ),
        throwsA(anything),
      );
      expect(
        () => LoopV2ProjectionCodec.communityRow(
          wire(
            viewer: <String, Object?>{
              'role': null,
              'status': null,
              'pending': 'no',
            },
            asset: null,
          ),
          sort: CommunityDirectorySort.members,
        ),
        throwsA(anything),
      );
    });
  });
}

const _member = CommunityDirectoryViewer(
  role: CommunityRole.member,
  status: CommunityMemberStatus.active,
  pending: false,
);
