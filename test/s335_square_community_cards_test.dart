// S335 · decision 0264: 广场 → 社区 as one card per community.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

String _id(int index) =>
    '4b96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}';

const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

CommunitySummary _card(
  int index, {
  String? symbol,
  String? label,
  CommunityDirectoryViewer viewer = CommunityDirectoryViewer.none,
  int members = 28,
}) {
  final base = testCommunity(
    communityId: _id(index),
    name: '社区 $index',
    memberCount: members,
  );
  return CommunitySummary(
    communityId: base.communityId,
    name: base.name,
    slug: base.slug,
    description: '社区 $index 的一句简介',
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

const _member = CommunityDirectoryViewer(
  role: CommunityRole.member,
  status: null,
  pending: false,
);

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

Future<void> _pump(
  WidgetTester tester,
  FakeCommunityGateway gateway, {
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

void main() {
  loopWatchGround();

  group('S335 · community cards', () {
    testWidgets('one card per community at the 390 measures', (tester) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _card(0, label: '算力社区', viewer: _member),
            _card(1, symbol: 'DOGE'),
            _card(2),
            // A 算力社区 with its token: the mark rides in the token chip.
            _card(3, symbol: 'DOGE', label: '算力社区'),
          ]),
        ),
      );
      // No shared board, no 热门社区 banner, no 「全部社区」 heading.
      expect(_key('square-community-board'), findsNothing);
      expect(find.text('热门社区'), findsNothing);
      expect(find.text('全部社区'), findsNothing);
      // The order stays, as one quiet word over the cards, right-aligned.
      final sort = _key('square-community-sort');
      expect(sort, findsOneWidget);
      expect(find.text('成员最多'), findsOneWidget);
      final sortWord = tester.widget<Text>(find.text('成员最多'));
      expect(sortWord.style?.color, LoopColors.text3);
      // Decision 0277: meta is 12 / 500.
      expect(sortWord.style?.fontSize, LoopType.meta.fontSize);

      final first = tester.getRect(_key('square-community-card-${_id(0)}'));
      final second = tester.getRect(_key('square-community-card-${_id(1)}'));
      expect(first.left, 16);
      expect(first.right, 390 - 16);
      expect(second.top - first.bottom, 12);
      expect(tester.getRect(sort).right, lessThanOrEqualTo(390 - 16 + 8));
      expect(tester.getRect(sort).bottom, lessThanOrEqualTo(first.top));
      final card = tester.widget<Material>(
        _key('square-community-card-${_id(0)}'),
      );
      expect(card.color, LoopColors.card);
      expect(card.borderRadius, LoopRadius.shell);
      expect(LoopRadius.shellValue, 20);

      // The 60 logo, 16 inside the card, at a 14 corner.
      final logo = _key('square-community-logo-${_id(0)}');
      expect(tester.getSize(logo), const Size(60, 60));
      expect(tester.getRect(logo).left - first.left, 16);
      expect(tester.widget<CommunityLogo>(logo).radius, 14);

      // Three lines: a body1 Chalk name (decision 0277: 14 / 500), a Text2
      // description, Text3 facts.
      final name = tester.widget<Text>(_key('square-community-name-${_id(0)}'));
      expect(name.style?.fontSize, LoopType.body1.fontSize);
      expect(name.style?.fontWeight, LoopType.body1.fontWeight);
      expect(name.style?.color, LoopColors.chalk);
      expect(name.maxLines, 1);
      final description = tester.widget<Text>(
        _key('square-community-description-${_id(0)}'),
      );
      expect(description.style?.fontSize, LoopType.caption.fontSize);
      expect(description.style?.color, LoopColors.text2);
      expect(description.maxLines, 1);
      final members = tester.widget<Text>(
        _key('square-community-members-${_id(0)}'),
      );
      expect(members.data, '28 成员');
      expect(members.style?.fontSize, LoopType.meta.fontSize);
      // S350a · decision 0274: one grey step under the description.
      expect(members.style?.color, LoopColors.muted);

      // The label left the name's side for the end of the facts line.
      final meta = _key('square-community-meta-${_id(0)}');
      final label = _key('square-community-label-${_id(0)}');
      expect(find.descendant(of: meta, matching: label), findsOneWidget);
      expect(
        find.descendant(of: label, matching: find.text('算力社区')),
        findsOneWidget,
      );
      expect(tester.getSize(label).height, 20);
      final labelWord = tester.widget<Text>(
        find.descendant(of: label, matching: find.text('算力社区')),
      );
      expect(labelWord.style?.color, LoopColors.text3);
      expect(
        tester.getRect(label).left -
            tester.getRect(_key('square-community-members-${_id(0)}')).right,
        8,
      );
      expect(
        find.descendant(of: label, matching: find.byType(LoopTokenLogo)),
        findsNothing,
      );

      // The token chip: 20 high, a 16 logo and 「$DOGE」 12/600 Chalk.
      final token = _key('square-community-token-${_id(1)}');
      expect(tester.getSize(token).height, 20);
      expect(
        tester.getSize(
          find.descendant(of: token, matching: find.byType(LoopTokenLogo)),
        ),
        const Size(16, 16),
      );
      final symbol = tester.widget<Text>(
        find.descendant(of: token, matching: find.text('\$DOGE')),
      );
      expect(symbol.style?.fontSize, 12);
      expect(symbol.style?.fontWeight, FontWeight.w600);
      expect(symbol.style?.color, LoopColors.chalk);
      expect(
        tester.getRect(token).left -
            tester.getRect(_key('square-community-members-${_id(1)}')).right,
        8,
      );
      expect(_key('square-community-token-${_id(3)}'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('square-community-token-${_id(3)}'),
          matching: find.text('\$DOGE'),
        ),
        findsOneWidget,
      );
      // The bolt sits inside the chip, after the symbol; no separate label
      // and no 「算力社区」 word anywhere on the line.
      final bolted = _key('square-community-token-${_id(3)}');
      final bolt = _key('square-community-bolt-${_id(3)}');
      expect(find.descendant(of: bolted, matching: bolt), findsOneWidget);
      expect(tester.getSize(bolt), const Size(12, 12));
      expect(tester.widget<LoopIcon>(bolt).name, 'bolt');
      expect(tester.widget<LoopIcon>(bolt).color, LoopColors.yellow);
      final boltSymbol = find.descendant(
        of: bolted,
        matching: find.text('\$DOGE'),
      );
      expect(tester.getRect(bolt).left - tester.getRect(boltSymbol).right, 4);
      // 6 of padding inside the 1px edge.
      expect(tester.getRect(bolted).right - tester.getRect(bolt).right, 7);
      expect(_key('square-community-label-${_id(3)}'), findsNothing);
      expect(
        find.descendant(
          of: _key('square-community-meta-${_id(3)}'),
          matching: find.text('算力社区'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _key('square-community-meta-${_id(3)}'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == '\$DOGE，算力社区',
          ),
        ),
        findsOneWidget,
      );
      // A token without the mark carries no bolt.
      expect(_key('square-community-bolt-${_id(1)}'), findsNothing);

      // No token: members only — no chip, nothing joined by a comma or bar.
      expect(_key('square-community-token-${_id(2)}'), findsNothing);
      expect(_key('square-community-label-${_id(2)}'), findsNothing);
      expect(find.textContaining('，\$'), findsNothing);
      expect(find.textContaining('|'), findsNothing);

      // The right edge: 已加入 grey, 加入 Yellow, both 32 high and ≥ 52 wide,
      // centred on the card.
      for (final (kind, index) in <(String, int)>[('joined', 0), ('join', 1)]) {
        final pill = _key('square-community-pill-${_id(index)}');
        final size = tester.getSize(pill);
        expect(size.height, 32);
        expect(size.width, greaterThanOrEqualTo(52));
        final cardRect = tester.getRect(
          _key('square-community-card-${_id(index)}'),
        );
        expect(tester.getCenter(pill).dy, closeTo(cardRect.center.dy, 0.5));
        expect(tester.getRect(pill).right, cardRect.right - 16);
        expect(_key('square-community-$kind-${_id(index)}'), findsOneWidget);
        final fill =
            (tester.widget<Container>(pill).decoration! as BoxDecoration).color;
        expect(fill, kind == 'join' ? LoopColors.yellow : LoopColors.card2);
      }
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(1)}'),
                matching: find.text('加入'),
              ),
            )
            .style
            ?.color,
        LoopColors.ink,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(1)}'),
                matching: find.text('加入'),
              ),
            )
            .style
            ?.fontWeight,
        // Decision 0277: the label step is 14 / 500.
        LoopType.label.fontWeight,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(0)}'),
                matching: find.text('已加入'),
              ),
            )
            .style
            ?.color,
        LoopColors.text2,
      );
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });

    testWidgets('another label follows the token chip where there is room', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            _card(0, symbol: 'DOGE', label: '官方合作'),
          ]),
        ),
        size: const Size(600, 1400),
      );
      final token = _key('square-community-token-${_id(0)}');
      final label = _key('square-community-label-${_id(0)}');
      expect(tester.getRect(label).left - tester.getRect(token).right, 8);
      expect(
        find.descendant(of: label, matching: find.byType(LoopTokenLogo)),
        findsNothing,
      );
      expect(tester.getSize(label).height, 20);
      await _drain(tester);
    });

    testWidgets('a join turns 加入 into 已加入 on the card', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _page(<CommunitySummary>[
          _card(0, symbol: 'DOGE'),
          _card(1),
        ]),
        detail: testDetail(
          community: testCommunity(communityId: _id(0), memberCount: 29),
          viewer: testViewer(role: CommunityRole.member),
        ),
      );
      await _pump(tester, gateway);
      await tester.tap(_key('square-community-join-${_id(0)}'));
      await tester.pumpAndSettle();
      expect(gateway.commands.last, 'join:${_id(0)}');
      expect(_key('square-community-joined-${_id(0)}'), findsOneWidget);
      expect(_key('square-community-join-${_id(0)}'), findsNothing);
      await _drain(tester);
    });

    testWidgets('我加入的 draws the same cards', (tester) async {
      final gateway =
          FakeCommunityGateway(
              directoryPage: _page(<CommunitySummary>[_card(0), _card(1)]),
            )
            ..directoryPagesByMembership[CommunityMembershipFilter.joined] =
                _page(<CommunitySummary>[
                  _card(1, symbol: 'ETH', viewer: _member),
                ]);
      await _pump(tester, gateway);
      await tester.tap(_key('square-filter-joined'));
      await tester.pumpAndSettle();
      expect(_key('square-community-card-${_id(1)}'), findsOneWidget);
      expect(_key('square-community-card-${_id(0)}'), findsNothing);
      expect(
        tester.getSize(_key('square-community-logo-${_id(1)}')),
        const Size(60, 60),
      );
      expect(_key('square-community-token-${_id(1)}'), findsOneWidget);
      expect(_key('square-community-joined-${_id(1)}'), findsOneWidget);
      expect(find.text('我加入的社区'), findsNothing);
      expect(_key('square-community-sort'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('50 cards: built as the list scrolls, the last one reached', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[
            for (var index = 0; index < 50; index += 1)
              _card(
                index,
                symbol: index.isEven ? 'DOGE' : null,
                label: index % 5 == 0 ? '算力社区' : null,
                members: 100 - index,
              ),
          ]),
        ),
        size: const Size(390, 844),
      );
      // Only the cards near the screen are built.
      final built = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'square-community-card-',
            ),
      );
      expect(built.evaluate().length, lessThan(50));
      await tester.scrollUntilVisible(
        _key('square-community-card-${_id(49)}'),
        600,
        scrollable: find
            .descendant(
              of: _key('square-community-scroll'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(_key('square-community-card-${_id(49)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _drain(tester);
    });
  });
}
