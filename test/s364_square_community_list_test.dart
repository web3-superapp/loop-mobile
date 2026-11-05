// S364 · decision 0288: 广场 → 社区 without 全部 / 我加入的; the order beside
// the search field with 加入优先; the label always on the facts line; 入驻 on
// the 广场 title row.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/features/square/square_screen.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int index) =>
    '5c96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}';

const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

const _member = CommunityDirectoryViewer(
  role: CommunityRole.member,
  status: null,
  pending: false,
);

CommunitySummary _card(
  int index, {
  String? symbol,
  String? label,
  CommunityDirectoryViewer viewer = CommunityDirectoryViewer.none,
  int members = 28,
}) {
  final base = testCommunity(
    communityId: _id(index),
    name: 'Club $index',
    memberCount: members,
  );
  return CommunitySummary(
    communityId: base.communityId,
    name: base.name,
    slug: base.slug,
    description: 'Club $index in one line',
    logoRef: 'avatar:preset/community-0${index % 9 + 1}',
    verificationStatus: base.verificationStatus,
    boundAssetKey: symbol == null ? null : _assetId,
    memberCount: base.memberCount,
    createdAt: base.createdAt,
    configVersion: base.configVersion,
    assetBadge: symbol == null
        ? null
        : CommunityAssetBadge(assetId: _assetId, symbol: symbol, logoUrl: null),
    viewerMembership: viewer,
    label: label,
  );
}

CommunityDirectoryPage _page(
  List<CommunitySummary> items, {
  String? nextCursor,
}) => CommunityDirectoryPage(
  items: items,
  nextCursor: nextCursor,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
  ordering: const CommunityOrderingApplied(
    sort: CommunityDirectorySort.members,
    basis: CommunityStoredBasis(),
  ),
);

/// A directory that answers by membership and cursor, so 加入优先's two reads
/// and their pages can be walked. Each read is also logged with its
/// verification filter.
FakeCommunityGateway _paged({
  required Map<String?, CommunityDirectoryPage> joined,
  required Map<String?, CommunityDirectoryPage> all,
  List<String>? log,
}) =>
    FakeCommunityGateway()
      ..directoryPageFor = (membership, verification, cursor) {
        log?.add('${membership.wireName}:${verification.wireName}:$cursor');
        return (membership == CommunityMembershipFilter.joined
            ? joined
            : all)[cursor];
      };

Future<void> _pump(
  WidgetTester tester,
  CommunityGateway gateway, {
  Size size = const Size(390, 1400),
}) => pumpCommunityPage(
  tester,
  SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
  community: gateway,
  size: size,
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

List<String> _ids(List<CommunitySummary> items) => <String>[
  for (final item in items) item.communityId,
];

void main() {
  loopWatchGround();
  setUpAll(loopLoadShotFonts);

  group('S364 · the pinned line', () {
    testWidgets('no 全部 / 我加入的; the order sits right of the search field', (
      tester,
    ) async {
      for (final width in <double>[390, 360]) {
        await _pump(
          tester,
          FakeCommunityGateway(
            directoryPage: _page(<CommunitySummary>[_card(0)]),
          ),
          size: Size(width, 900),
        );
        expect(_key('square-filter-all'), findsNothing);
        expect(_key('square-filter-joined'), findsNothing);
        expect(_key('square-community-chips'), findsNothing);
        expect(find.text('Joined'), findsNothing);
        final search = tester.getRect(_key('square-community-search'));
        final sort = tester.getRect(_key('square-community-sort'));
        // One line: same middle, the order after the field, both 44 tall.
        expect(sort.center.dy, search.center.dy, reason: '$width');
        expect(sort.left, greaterThanOrEqualTo(search.right));
        expect(sort.height, squareCommunityControlHeight);
        // Exactly one order control: the old line over the cards is gone.
        expect(_key('square-community-sort'), findsOneWidget);
        // The first card starts under the pinned line.
        final card = tester.getRect(_key('square-community-card-${_id(0)}'));
        expect(card.top, greaterThanOrEqualTo(sort.bottom));
        expect(card.top - sort.bottom, lessThan(24), reason: '$width');
        expect(tester.takeException(), isNull);
        await _drain(tester);
      }
    });

    testWidgets('the order sheet lists 加入优先 first, then 成员最多', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[_card(0)]),
        ),
      );
      expect(find.text('Most members'), findsOneWidget);
      await tester.tap(_key('square-community-sort'));
      await tester.pumpAndSettle();
      final order = <String>[
        'square-sort-joinedFirst',
        'square-sort-members',
        'square-sort-power',
        'square-sort-discussion',
        'square-sort-newest',
      ];
      for (var index = 1; index < order.length; index += 1) {
        expect(
          tester.getTopLeft(_key(order[index])).dy,
          greaterThan(tester.getTopLeft(_key(order[index - 1])).dy),
          reason: order[index],
        );
      }
      expect(find.text('Joined first'), findsOneWidget);
      await tester.tap(_key('square-sort-joinedFirst'));
      await tester.pumpAndSettle();
      // The chosen order is the word on the line.
      expect(
        find.descendant(
          of: _key('square-community-sort'),
          matching: find.text('Joined first'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });
  });

  group('S364 · 加入优先', () {
    test(
      'joined first by members, then the rest; deduped across pages',
      () async {
        final log = <String>[];
        final gateway = _paged(
          joined: <String?, CommunityDirectoryPage>{
            null: _page(<CommunitySummary>[
              _card(1, viewer: _member, members: 50),
              _card(2, viewer: _member, members: 40),
            ], nextCursor: 'j2'),
            'j2': _page(<CommunitySummary>[
              _card(3, viewer: _member, members: 9),
            ]),
          },
          all: <String?, CommunityDirectoryPage>{
            null: _page(<CommunitySummary>[
              _card(10, members: 900),
              _card(1, viewer: _member, members: 50),
              _card(11, members: 30),
            ], nextCursor: 'd2'),
            'd2': _page(<CommunitySummary>[
              _card(12, members: 20),
              _card(3, viewer: _member, members: 9),
              _card(13, members: 2),
            ]),
          },
          log: log,
        );
        final container = ProviderContainer(
          overrides: [communityGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        final visit = container.listen(
          communityDiscoverControllerProvider,
          (_, _) {},
        );
        addTearDown(visit.close);
        final controller = container.read(
          communityDiscoverControllerProvider.notifier,
        );
        CommunityDiscoverState read() =>
            container.read(communityDiscoverControllerProvider);

        await controller.selectJoinedFirst();
        expect(read().joinedFirst, isTrue);
        expect(read().sort, CommunityDirectorySort.members);
        expect(read().membership, CommunityMembershipFilter.all);
        expect(
          CommunityDiscoverSegment.ofState(read()),
          CommunityDiscoverSegment.joinedFirst,
        );
        // The old 我加入的 question (all verification states), by members.
        expect(gateway.commands.last, 'list:members:joined:null');
        expect(_ids(read().items), <String>[_id(1), _id(2)]);
        expect(read().nextCursor, isNotNull);

        // The joined read ends; the directory's first page rides along.
        await controller.loadMore();
        expect(gateway.commands.sublist(gateway.commands.length - 2), <String>[
          'list:members:joined:j2',
          'list:members:all:null',
        ]);
        expect(_ids(read().items), <String>[
          _id(1),
          _id(2),
          _id(3),
          _id(10),
          _id(11),
        ]);

        // Directory pages go on; a joined row it repeats is not drawn twice.
        await controller.loadMore();
        expect(gateway.commands.last, 'list:members:all:d2');
        expect(_ids(read().items), <String>[
          _id(1),
          _id(2),
          _id(3),
          _id(10),
          _id(11),
          _id(12),
          _id(13),
        ]);
        expect(read().nextCursor, isNull);
        expect(read().phase, CommunityViewPhase.ready);
        // The joined read asks every verification state (a reader's own
        // community under review included); the directory asks verified ones.
        expect(log, <String>[
          'joined:all:null',
          'joined:all:j2',
          'all:verified:null',
          'all:verified:d2',
        ]);

        // Another order leaves 加入优先 and asks the server's own order.
        await controller.selectSort(CommunityDirectorySort.members);
        expect(read().joinedFirst, isFalse);
        expect(gateway.commands.last, 'list:members:all:null');
        expect(_ids(read().items), <String>[_id(10), _id(1), _id(11)]);
      },
    );

    test('nothing joined: page one is the directory, not empty', () async {
      final gateway = _paged(
        joined: <String?, CommunityDirectoryPage>{
          null: _page(const <CommunitySummary>[]),
        },
        all: <String?, CommunityDirectoryPage>{
          null: _page(<CommunitySummary>[_card(10), _card(11)]),
        },
      );
      final container = ProviderContainer(
        overrides: [communityGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final visit = container.listen(
        communityDiscoverControllerProvider,
        (_, _) {},
      );
      addTearDown(visit.close);
      await container
          .read(communityDiscoverControllerProvider.notifier)
          .selectJoinedFirst();
      final state = container.read(communityDiscoverControllerProvider);
      expect(state.phase, CommunityViewPhase.ready);
      expect(_ids(state.items), <String>[_id(10), _id(11)]);
      expect(state.nextCursor, isNull);
    });

    testWidgets('the joined rows come first on the page', (tester) async {
      final gateway = _paged(
        joined: <String?, CommunityDirectoryPage>{
          null: _page(<CommunitySummary>[_card(2, viewer: _member)]),
        },
        all: <String?, CommunityDirectoryPage>{
          null: _page(<CommunitySummary>[
            _card(1, members: 99),
            _card(2, viewer: _member),
          ]),
        },
      );
      await _pump(tester, gateway);
      await tester.tap(_key('square-community-sort'));
      await tester.pumpAndSettle();
      await tester.tap(_key('square-sort-joinedFirst'));
      await tester.pumpAndSettle();
      final joined = tester.getTopLeft(_key('square-community-card-${_id(2)}'));
      final other = tester.getTopLeft(_key('square-community-card-${_id(1)}'));
      expect(joined.dy, lessThan(other.dy));
      expect(_key('square-community-card-${_id(2)}'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('membership=joined (我的 → 全部已加入的社区) lands on 加入优先', (
      tester,
    ) async {
      // The old destination and its parameter are kept.
      expect(
        profileDestinationPath('community-joined'),
        '/community/discover?membership=joined',
      );
      final gateway = _paged(
        joined: <String?, CommunityDirectoryPage>{
          null: _page(<CommunitySummary>[_card(2, viewer: _member)]),
        },
        all: <String?, CommunityDirectoryPage>{
          null: _page(<CommunitySummary>[_card(1), _card(2, viewer: _member)]),
        },
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(joinedOnly: true),
        community: gateway,
      );
      expect(gateway.commands, <String>[
        'list:members:joined:null',
        'list:members:all:null',
      ]);
      expect(find.text('Joined first'), findsOneWidget);
      expect(find.text('Joined communities'), findsNothing);
      // The arrival is applied once: another order is the reader's.
      await tester.tap(_key('discover-seg-members'));
      await tester.pumpAndSettle();
      expect(gateway.commands.last, 'list:members:all:null');
      expect(gateway.commands.length, 3);
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.commands.length, 3);
      await _drain(tester);
    });
  });

  group('S364 · the label is always drawn', () {
    const longSymbol = '猫猫啦咯啦咯啦咯啦咯';
    for (final width in <double>[390, 360, 320]) {
      testWidgets('a long token symbol does not push 新锐社区 off at $width', (
        tester,
      ) async {
        await _pump(
          tester,
          FakeCommunityGateway(
            directoryPage: _page(<CommunitySummary>[
              _card(0, symbol: longSymbol, label: '新锐社区', members: 12345),
            ]),
          ),
          size: Size(width, 900),
        );
        final id = _id(0);
        final label = _key('square-community-label-$id');
        expect(label, findsOneWidget, reason: '$width');
        expect(
          find.descendant(of: label, matching: find.text('新锐社区')),
          findsOneWidget,
        );
        final meta = tester.getRect(_key('square-community-meta-$id'));
        final chip = tester.getRect(label);
        expect(chip.right, lessThanOrEqualTo(meta.right + 0.01));
        // The label is drawn whole: its word is not cut.
        final word = find.descendant(of: label, matching: find.text('新锐社区'));
        final painted = tester.renderObject<RenderParagraph>(word);
        expect(painted.didExceedMaxLines, isFalse, reason: '$width');
        // At most 45 % of the line.
        expect(chip.width, lessThanOrEqualTo(meta.width * 0.45 + 0.01));
        // The token gives way first: cut or left off, never past the line.
        final token = _key('square-community-token-$id');
        if (token.evaluate().isNotEmpty) {
          expect(
            tester.getRect(token).right,
            lessThanOrEqualTo(chip.left + 0.01),
          );
        }
        expect(tester.takeException(), isNull);
        await _drain(tester);
      });
    }

    testWidgets('a 算力社区 keeps its bolt in the token chip', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _card(0, symbol: 'DOGE', label: '算力社区'),
          ]),
        ),
      );
      final id = _id(0);
      expect(_key('square-community-bolt-$id'), findsOneWidget);
      expect(_key('square-community-label-$id'), findsNothing);
      await _drain(tester);
    });

    testWidgets('a short token and a label both fit whole', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _card(0, symbol: 'DOGE', label: '新锐社区'),
          ]),
        ),
      );
      final id = _id(0);
      final token = find.descendant(
        of: _key('square-community-token-$id'),
        matching: find.text(r'$DOGE'),
      );
      expect(token, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(token).didExceedMaxLines,
        isFalse,
      );
      expect(_key('square-community-label-$id'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('S364 · 入驻 on the 广场 title row', () {
    testWidgets('only on 社区, and it opens the rules and 申请入驻', (tester) async {
      await pumpCommunityPage(
        tester,
        SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
        community: FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[_card(0)]),
        ),
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final entry = _key('square-community-apply-entry');
      expect(entry, findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      // On the title row: level with the segment words, at the right.
      final segment = tester.getRect(_key('square-segment-0'));
      final rect = tester.getRect(entry);
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(rect.top, lessThan(segment.bottom));
      expect(rect.left, greaterThan(segment.right));
      // No 「发现社区 / 规则与入驻」 line in the page.
      expect(find.text('Discover communities'), findsNothing);
      expect(find.text('Rules and listing'), findsNothing);

      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(_key('square-community-rules-sheet'), findsOneWidget);
      expect(_key('square-community-apply'), findsOneWidget);
      Navigator.of(tester.element(_key('square-community-rules-sheet'))).pop();
      await tester.pumpAndSettle();

      // 语音房: no 入驻.
      await tester.tap(_key('square-segment-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(entry, findsNothing);
      await _drain(tester);
    });
  });
}
