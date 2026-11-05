// S265d · 镀铬牌、领奖台、聊天磨砂板 (client decision 0224): the chrome plate
// is a bevelled, brushed, sheened brand piece; 前三名 is a podium on the wall
// with Anton places and chrome medals for faces without a picture; 聊天's
// board is a translucent Chalk 10 % over Ink 35 % fill.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_inbox_row_actions.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _pumpPlate(
  WidgetTester tester, {
  bool motion = false,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loopAmbientMotionProvider.overrideWithValue(motion)],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: Column(
              children: <Widget>[
                const SizedBox(height: 40),
                LoopChromePlate(
                  key: const ValueKey<String>('plate'),
                  mark: LoopChromePlateMark.tag,
                  child: Text(
                    '128.40',
                    style: LoopType.plateFigure.copyWith(
                      color: LoopColors.yellow,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

MiningRank _boards(MiningRankScope scope, int places) => s7MiningRank(
  scope: MiningRankScope.communities,
  ranking: MiningRankingCommunities(
    items: <MiningRankCommunityRow>[
      for (var index = 0; index < places; index += 1)
        MiningRankCommunityRow(
          position: index + 1,
          power: '${9000 - index * 1000}',
          community: MiningCommunityRef(
            communityId: 'community-${index + 1}',
            name: '社区${index + 1}',
            boundAssetId: s7CakeAssetId,
          ),
          weight: '1.5',
          participants: 30 - index,
        ),
    ],
    participants: 150,
  ),
  me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  snapshot: s7MiningSnapshot(),
);

final class _BoardMining implements MiningGateway {
  _BoardMining(this.places);

  final int places;
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(_boards(scope, places));

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

void main() {
  loopWatchGround();

  group('镀铬牌', () {
    testWidgets('a 2 px chrome bevel, a 1 px Ink line, a brushed face with '
        'the light band (the wall, fog and corner mark went in 0291)', (
      tester,
    ) async {
      await _pumpPlate(tester);
      final plate = _key('plate');
      Finder part(String key) =>
          find.descendant(of: plate, matching: _key(key));
      final edge = tester.widget<DecoratedBox>(part('loop-chrome-plate-edge'));
      final bevel =
          (edge.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(bevel.colors, LoopChromePlate.bevelColors);
      // The bevel is 2 px wide, the Ink line 1 px inside it.
      final outer = tester.getRect(part('loop-chrome-plate-edge'));
      final inner = tester.getRect(part('loop-chrome-plate-inner'));
      final face = tester.getRect(part('loop-chrome-plate-face'));
      expect(inner.left - outer.left, LoopChromePlate.edge);
      expect(face.left - inner.left, LoopChromePlate.innerLine);
      expect(
        (tester.widget<DecoratedBox>(part('loop-chrome-plate-inner')).decoration
                as BoxDecoration)
            .color,
        const Color(0x4D070809),
      );
      final brushed =
          (tester
                          .widget<DecoratedBox>(part('loop-chrome-plate-face'))
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(brushed.colors, LoopChromePlate.faceColors);
      expect(part('loop-chrome-plate-light'), findsOneWidget);
      // Decision 0291: the wall, the fog and the faded corner mark are gone.
      for (final key in <String>[
        'loop-chrome-plate-wall',
        'loop-chrome-plate-fog',
        'loop-chrome-plate-mark',
      ]) {
        expect(part(key), findsNothing, reason: key);
      }
      final light =
          (tester
                          .widget<DecoratedBox>(part('loop-chrome-plate-light'))
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(light.colors[1], const Color(0x1FF0F0F3));
      // The figure sits in the face, read against its first stop.
      expect(
        loopContrastRatio(LoopColors.yellow, LoopChromePlate.faceColors.first),
        greaterThan(4.5),
      );
      expect(
        loopContrastRatio(LoopColors.text2, LoopChromePlate.faceColors.first),
        greaterThan(4.5),
      );
    });

    testWidgets('the sheen sweeps every 6 s with motion on, never under '
        'reduced motion', (tester) async {
      await _pumpPlate(tester, motion: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_key('loop-chrome-plate-sheen'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      await _pumpPlate(tester, motion: true, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_key('loop-chrome-plate-sheen'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('前三名 · 领奖台', () {
    testWidgets('three columns (S353b · decision 0279, docs/58 §5.15): the '
        'winner in the middle at 62 in a Yellow ring under the line crown, '
        'second and third 54, 01 / 02 / 03 at 17 / 700 (01 Yellow), chrome '
        'medals for faces with no logo, the Purple glow behind', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
        mining: _BoardMining(3),
        size: const Size(390, 1400),
      );
      expect(_key('intel-rank-podium-wall'), findsOneWidget);
      expect(_key('intel-rank-podium-fog'), findsOneWidget);
      final first = tester.getRect(_key('intel-rank-community-community-1'));
      final second = tester.getRect(_key('intel-rank-community-community-2'));
      final third = tester.getRect(_key('intel-rank-community-community-3'));
      expect(second.right, lessThan(first.left));
      expect(first.right, lessThan(third.left));
      expect(tester.getSize(_key('intel-rank-face-1')), const Size(62, 62));
      expect(tester.getSize(_key('intel-rank-face-2')), const Size(54, 54));
      final ring =
          tester.widget<Container>(_key('intel-rank-ring-1')).decoration!
              as BoxDecoration;
      expect((ring.border! as Border).top.color, LoopColors.yellow);
      for (final place in <int>[1, 2, 3]) {
        final index = tester.widget<Text>(_key('intel-rank-index-$place'));
        expect(index.data, '0$place');
        expect(index.style?.fontSize, LoopType.emptyTitle.fontSize);
        expect(
          index.style?.color,
          place == 1 ? LoopColors.yellow : LoopColors.text2,
        );
        expect(_key('community-logo-chrome-community-$place'), findsOneWidget);
        expect(_key('intel-rank-medal-$place'), findsNothing);
      }
      expect(
        tester.widget<Text>(_key('intel-rank-figure-1')).style?.fontSize,
        LoopType.figureXs.fontSize,
      );
      expect(
        find.text('Weight 1.5').evaluate().length,
        greaterThanOrEqualTo(3),
      );
      // The line crown stands over the winner's face.
      final crown = tester.getRect(_key('intel-rank-crown-1'));
      final face = tester.getRect(_key('intel-rank-face-1'));
      expect(crown.width, 27);
      expect(crown.bottom, lessThanOrEqualTo(face.top));
    });

    testWidgets('one place: the other two are 「虚位以待」 under a grey crown', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
        mining: _BoardMining(1),
        size: const Size(390, 1400),
      );
      expect(_key('intel-rank-community-community-1'), findsOneWidget);
      expect(_key('intel-rank-empty-slot-2'), findsOneWidget);
      expect(_key('intel-rank-empty-slot-3'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(2));
    });
  });

  group('聊天 · 磨砂板', () {
    testWidgets('on the wall a row at rest is the page, the board is the '
        'block ground at 92 %; off the wall it keeps the page ground', (
      tester,
    ) async {
      Widget row() => ChatInboxSwipeRow(
        actions: () => const <ChatInboxRowAction>[],
        onAction: (_) {},
        child: const SizedBox(height: 72, child: Text('会话')),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                LoopBackdropScope(
                  backdrop: const SizedBox.shrink(),
                  child: KeyedSubtree(
                    key: const ValueKey<String>('on-wall'),
                    child: row(),
                  ),
                ),
                KeyedSubtree(
                  key: const ValueKey<String>('off-wall'),
                  child: row(),
                ),
              ],
            ),
          ),
        ),
      );
      Finder ground(String key) => find.descendant(
        of: _key(key),
        matching: find.byKey(const ValueKey<String>('chat-inbox-row-ground')),
      );
      // S353a · decision 0278: on the wall a row at rest is the page itself
      // (the Figma draws the list on the page ground); a pinned or sliding
      // row takes the board below.
      expect(ground('on-wall'), findsNothing);
      // S279 · decision 0237: the board is the block ground at 92 %.
      expect(loopChatBoardFill.a, closeTo(0.92, 0.01));
      expect(loopChatBoardFill.withValues(alpha: 1), LoopColors.plate);
      expect(
        tester.widget<ColoredBox>(ground('off-wall')).color,
        LoopTheme.dark.scaffoldBackgroundColor,
      );
      expect(loopChatBoardHairline, const Color(0x14F4F5F7));

      // Contrast over the darkened wall: its 99th-percentile pixel lands at
      // #161616 after the wall's own 85 % and the page wash (decision 0224).
      final over = loopCompositeOver(
        loopChatBoardFill,
        const Color(0xFF161616),
      );
      expect(loopContrastRatio(LoopColors.chalk, over), greaterThan(4.5));
      expect(loopContrastRatio(LoopColors.text2, over), greaterThan(4.5));
      // Decision 0277: the Figma's tertiary grey (`#6f717a`) is a quieter
      // ink than 0229's — it clears the 3:1 of a symbol, a time and an
      // unchosen title, not the 4.5:1 of body copy (docs/58 §9.3).
      expect(loopContrastRatio(LoopColors.text3, over), greaterThan(3.0));
    });
  });

  test('the podium face size is 62 for the winner and 54 beside it', () {
    // S353b · decision 0279 (docs/58 §5.15).
    expect(intelPodiumFaceSize(1), 62);
    expect(intelPodiumFaceSize(2), 54);
  });
}
