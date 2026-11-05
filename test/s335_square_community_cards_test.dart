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
import 'support/loop_shots.dart';

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
  // S355b: English copy under the box-per-glyph test font runs about twice
  // its device width; the cards are measured with the App's own faces.
  setUpAll(loopLoadShotFonts);

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
      expect(find.text('Most members'), findsOneWidget);
      final sortWord = tester.widget<Text>(find.text('Most members'));
      // S353a · decision 0278: 「成员最多」 in textSecondary.
      expect(sortWord.style?.color, LoopColors.textSecondary);
      // Decision 0277: meta is 12 / 500.
      expect(sortWord.style?.fontSize, LoopType.meta.fontSize);

      final first = tester.getRect(_key('square-community-card-${_id(0)}'));
      final second = tester.getRect(_key('square-community-card-${_id(1)}'));
      // S353a · decision 0278 (docs/58 §5.8): rows on the page in the 20
      // gutter, 86 high, back to back, a hairline under each.
      expect(first.left, 20);
      expect(first.right, 390 - 20);
      expect(first.height, 86);
      expect(second.top - first.bottom, 0);
      expect(tester.getRect(sort).right, lessThanOrEqualTo(390 - 20 + 8));
      expect(tester.getRect(sort).bottom, lessThanOrEqualTo(first.top));
      final card = tester.widget<Material>(
        _key('square-community-card-${_id(0)}'),
      );
      expect(card.type, MaterialType.transparency);
      expect(
        card.shape,
        const Border(bottom: BorderSide(color: LoopColors.divider)),
      );

      // The 56 logo on the gutter at a 12 corner.
      final logo = _key('square-community-logo-${_id(0)}');
      expect(tester.getSize(logo), const Size(56, 56));
      expect(tester.getRect(logo).left - first.left, 0);
      expect(tester.widget<CommunityLogo>(logo).radius, 12);

      // Three lines: a rowTitle Chalk name (decision 0301: 16 / 500), a Text2
      // description, Text3 facts.
      final name = tester.widget<Text>(_key('square-community-name-${_id(0)}'));
      expect(name.style?.fontSize, LoopType.rowTitle.fontSize);
      expect(name.style?.fontWeight, LoopType.rowTitle.fontWeight);
      expect(name.style?.color, LoopColors.textPrimary);
      expect(name.maxLines, 1);
      final description = tester.widget<Text>(
        _key('square-community-description-${_id(0)}'),
      );
      expect(description.style?.fontSize, LoopType.caption.fontSize);
      expect(description.style?.color, LoopColors.textSecondary);
      expect(description.maxLines, 1);
      final members = tester.widget<Text>(
        _key('square-community-members-${_id(0)}'),
      );
      // S353a: the people mark and the number, 10 / 400 textSecondary.
      expect(members.data, '28');
      expect(members.style?.fontSize, LoopType.metaSm.fontSize);
      expect(members.style?.color, LoopColors.textSecondary);

      // The label left the name's side for the end of the facts line.
      final meta = _key('square-community-meta-${_id(0)}');
      final label = _key('square-community-label-${_id(0)}');
      expect(find.descendant(of: meta, matching: label), findsOneWidget);
      expect(
        find.descendant(of: label, matching: find.text('算力社区')),
        findsOneWidget,
      );
      expect(tester.getSize(label).height, 16);
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

      // The token chip (S353a): 16 high, a 10 logo and 「$DOGE」 10 / 400.
      final token = _key('square-community-token-${_id(1)}');
      expect(tester.getSize(token).height, 16);
      expect(
        tester.getSize(
          find.descendant(of: token, matching: find.byType(LoopTokenLogo)),
        ),
        const Size(10, 10),
      );
      final symbol = tester.widget<Text>(
        find.descendant(of: token, matching: find.text('\$DOGE')),
      );
      expect(symbol.style?.fontSize, 10);
      expect(symbol.style?.fontWeight, FontWeight.w400);
      expect(symbol.style?.color, LoopColors.textSecondary);
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
      expect(tester.getSize(bolt), const Size(10, 10));
      expect(tester.widget<LoopIcon>(bolt).name, 'bolt');
      expect(tester.widget<LoopIcon>(bolt).color, LoopColors.yellow);
      final boltSymbol = find.descendant(
        of: bolted,
        matching: find.text('\$DOGE'),
      );
      expect(tester.getRect(bolt).left - tester.getRect(boltSymbol).right, 4);
      // 5 of padding inside the 1px edge.
      expect(tester.getRect(bolted).right - tester.getRect(bolt).right, 6);
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
                widget is Semantics &&
                widget.properties.label == '\$DOGE, 算力社区',
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

      // The right edge (S353a · docs/58 §5.20): the 54 × 28 key on white
      // 8 %, 加入 Yellow, 已加入 textSecondary, centred on the row.
      for (final (kind, index) in <(String, int)>[('joined', 0), ('join', 1)]) {
        final pill = _key('square-community-pill-${_id(index)}');
        final size = tester.getSize(pill);
        expect(size.height, 28);
        expect(size.width, greaterThanOrEqualTo(54));
        final cardRect = tester.getRect(
          _key('square-community-card-${_id(index)}'),
        );
        expect(tester.getCenter(pill).dy, closeTo(cardRect.center.dy, 0.5));
        expect(tester.getRect(pill).right, cardRect.right);
        expect(_key('square-community-$kind-${_id(index)}'), findsOneWidget);
        final fill =
            (tester.widget<Container>(pill).decoration! as BoxDecoration).color;
        expect(fill, LoopColors.buttonGhost);
      }
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(1)}'),
                matching: find.text('Join'),
              ),
            )
            .style
            ?.color,
        LoopColors.yellow,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(1)}'),
                matching: find.text('Join'),
              ),
            )
            .style
            ?.fontWeight,
        // docs/58 §5.8: 12 / 600.
        LoopType.buttonXs.fontWeight,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _key('square-community-pill-${_id(0)}'),
                matching: find.text('Joined'),
              ),
            )
            .style
            ?.color,
        LoopColors.textSecondary,
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
      expect(tester.getSize(label).height, 16);
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

    // S364 · decision 0288: 我加入的 is now the order 加入优先.
    testWidgets('加入优先 draws the same cards', (tester) async {
      final gateway =
          FakeCommunityGateway(
              directoryPage: _page(<CommunitySummary>[_card(0), _card(1)]),
            )
            ..directoryPagesByMembership[CommunityMembershipFilter.joined] =
                _page(<CommunitySummary>[
                  _card(1, symbol: 'ETH', viewer: _member),
                ]);
      await _pump(tester, gateway);
      await tester.tap(_key('square-community-sort'));
      await tester.pumpAndSettle();
      await tester.tap(_key('square-sort-joinedFirst'));
      await tester.pumpAndSettle();
      expect(_key('square-community-card-${_id(1)}'), findsOneWidget);
      expect(_key('square-community-card-${_id(0)}'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('square-community-card-${_id(1)}')).dy,
        lessThan(tester.getTopLeft(_key('square-community-card-${_id(0)}')).dy),
      );
      expect(
        tester.getSize(_key('square-community-logo-${_id(1)}')),
        const Size(56, 56),
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
