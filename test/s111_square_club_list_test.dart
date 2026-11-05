import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

import 'package:loop_mobile/widgets/loop_inline_states.dart';

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

/// UX-013: the order is 「全部社区」's own dropdown, read from its label.
String _sortLabel(WidgetTester tester) => tester
    .widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('square-community-sort')),
            matching: find.byType(Semantics),
          )
          .first,
    )
    .properties
    .label!
    .replaceFirst('Sort, ', '');

Future<void> _chooseSort(WidgetTester tester, String key) async {
  await _tapChip(tester, 'square-community-sort');
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pumpAndSettle();
}

void main() {
  // S355b: English copy under the box-per-glyph test font runs about twice
  // its device width; the cards are measured with the App's own faces.
  setUpAll(loopLoadShotFonts);
  loopWatchGround();

  group('S111 · compact head and search entry', () {
    testWidgets('no DISCOVERY DESK card, no heading line; 入驻 opens the '
        'rules', (tester) async {
      await pumpCommunityPage(
        tester,
        Column(
          children: <Widget>[
            SquareCommunityApplyEntry(onOpenCommunity: (_) {}),
            Expanded(
              child: SquareCommunityList(
                onOpenCommunity: (_) {},
                onOpenSearch: () {},
              ),
            ),
          ],
        ),
        community: FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[_row()]),
        ),
      );
      expect(find.text('DISCOVERY DESK'), findsNothing);
      expect(find.textContaining('已载入'), findsNothing);
      // S364 · decision 0288: no 「发现社区 / 规则与入驻 ›」 line.
      expect(find.text('Discover communities'), findsNothing);
      expect(find.text('Rules and listing'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('square-community-rules')),
        findsNothing,
      );
      expect(find.text(squareCommunityRuleLine), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('square-community-apply-entry')),
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
    testWidgets('the controls stay pinned while the rows scroll', (
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
      // S364 · decision 0288: the search field and the order are the
      // pinned line, and nothing scrolls away above them.
      final chips = find.byKey(
        const ValueKey<String>('square-community-controls'),
      );
      final before = tester.getTopLeft(chips).dy;
      await tester.drag(
        find.byKey(const ValueKey<String>('square-community-scroll')),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.text('Club 0').hitTestable(), findsNothing);
      expect(chips.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(chips).dy, before);
      await _drain(tester);
    });

    testWidgets('no 全部 / 我加入的; the order alone asks the whole '
        'directory', (tester) async {
      final gateway =
          FakeCommunityGateway(directoryPage: _page(<CommunitySummary>[_row()]))
            ..directoryPagesBySort[CommunityDirectorySort.newest] = _page(
              <CommunitySummary>[_row()],
              sort: CommunityDirectorySort.newest,
            );
      await _pump(tester, gateway);
      expect(gateway.commands.last, 'list:members:all:null');
      // S364 · decision 0288: the two chips are gone.
      expect(
        find.byKey(const ValueKey<String>('square-filter-all')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('square-filter-joined')),
        findsNothing,
      );
      expect(find.byType(LoopFilterChip), findsNothing);
      expect(_sortLabel(tester), 'Most members');

      await _chooseSort(tester, 'square-sort-newest');
      expect(gateway.commands.last, 'list:newest:all:null');
      expect(_sortLabel(tester), 'Newest');
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
      // S335 (decision 0264): no 热门社区 banner repeats a row any more.
      expect(find.text('Join'), findsOneWidget);
      // 已加入 and the 我加入的 chip are both 「Joined」 in English (glossary).\n      expect(find.text('Joined'), findsNWidgets(3));
      expect(find.text('Mine'), findsOneWidget);
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
      // S335 (decision 0264): members and the token are two pieces, the
      // token a chip with its logo; nothing joins them into one sentence.
      // S353a · decision 0278: the count is the people mark and the number.
      expect(find.text('128'), findsNWidgets(2));
      final chip = find.byKey(
        const ValueKey<String>('square-community-token-$testCommunityId'),
      );
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text('\$FROG')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: chip, matching: find.byType(LoopTokenLogo)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('square-community-token-$_otherId')),
        findsNothing,
      );
      expect(find.textContaining('，\$'), findsNothing);
      expect(find.textContaining('|'), findsNothing);
      // Decision 0239: neither row carries a label, so neither wears a mark.
      expect(find.text('已验证'), findsNothing);

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
      await _chooseSort(tester, 'square-sort-power');
      expect(find.text('128'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('square-community-ranked-$testCommunityId'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Power '), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('square-community-meta-$testCommunityId'),
          ),
          matching: find.textContaining('，'),
        ),
        findsNothing,
      );

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
      expect(find.text('129'), findsOneWidget);
      expect(find.text('Joined'), findsWidgets);
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
      expect(find.text('Discover communities'), findsNothing);
      await _drain(tester);
    });

    testWidgets('empty', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(directoryPage: _page(const <CommunitySummary>[])),
      );
      expect(find.text('No matching communities'), findsOneWidget);
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

    testWidgets('the last page ends on space, not 没有更多社区 (decision 0123); '
        'a next page is read on scroll', (tester) async {
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
      expect(find.text('没有更多社区'), findsNothing);
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

  testWidgets('an order the server could not apply is one inline line', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(
      directoryPage: const CommunityDirectoryPage(
        items: <CommunitySummary>[],
        nextCursor: null,
        recommendation: CommunityRecommendation(
          recommendationId: '22222222-2222-4222-8222-222222222222',
          ruleVersion: 'rule:verified-members-v1',
        ),
        ordering: CommunityOrderingUnavailable(
          sort: CommunityDirectorySort.members,
          reasonCode: 'COMMUNITY_ACTIVITY_NOT_OBSERVED',
        ),
      ),
    );
    await _pump(tester, gateway);

    // Decision 0183: the line, and under it the order the page can apply.
    final block = find.byKey(
      const ValueKey<String>('square-community-ordering-unavailable'),
    );
    expect(block, findsOneWidget);
    expect(
      find.descendant(of: block, matching: find.byType(LoopInlineUnavailable)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('square-community-ordering-back')),
      findsOneWidget,
    );
    await _drain(tester);
  });
}

const _member = CommunityDirectoryViewer(
  role: CommunityRole.member,
  status: CommunityMemberStatus.active,
  pending: false,
);
