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
import 'package:loop_mobile/features/intel/intel_screen.dart';
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
        'the wall, the fog, the light band and the faded corner mark', (
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
        const Color(0x4D09090B),
      );
      final brushed =
          (tester
                          .widget<DecoratedBox>(part('loop-chrome-plate-face'))
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(brushed.colors, LoopChromePlate.faceColors);
      for (final key in <String>[
        'loop-chrome-plate-wall',
        'loop-chrome-plate-fog',
        'loop-chrome-plate-light',
        'loop-chrome-plate-mark',
      ]) {
        expect(part(key), findsOneWidget, reason: key);
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
    testWidgets('three columns on the wall: the winner in the middle at 72 in '
        'a chrome ring, 01 / 02 / 03 in Anton, chrome medals for faces with '
        'no logo, the winner\'s figure Yellow', (tester) async {
      await pumpS7Page(
        tester,
        IntelScreen(onNavigate: (_) {}),
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
      expect(tester.getSize(_key('intel-rank-face-1')), const Size(72, 72));
      expect(tester.getSize(_key('intel-rank-face-2')), const Size(56, 56));
      expect(_key('intel-rank-ring-1'), findsOneWidget);
      for (final place in <int>[1, 2, 3]) {
        expect(
          find.descendant(
            of: _key('intel-rank-index-$place'),
            matching: find.text('0$place'),
          ),
          findsOneWidget,
        );
        final index = tester.widget<Text>(
          find.descendant(
            of: _key('intel-rank-index-$place'),
            matching: find.text('0$place'),
          ),
        );
        expect(index.style?.fontFamily, LoopType.sectionIndex.fontFamily);
        expect(index.style?.color, LoopColors.yellow);
        expect(_key('community-logo-chrome-community-$place'), findsOneWidget);
        expect(_key('intel-rank-medal-$place'), findsNothing);
      }
      expect(
        tester.widget<Text>(_key('intel-rank-figure-1')).style?.color,
        LoopColors.yellow,
      );
      expect(
        tester.widget<Text>(_key('intel-rank-figure-2')).style?.color,
        LoopColors.chalk,
      );
      expect(find.text('权重 1.5').evaluate().length, greaterThanOrEqualTo(3));
      // The crown is wider than half the winner's face and sits on its top.
      final crown = tester.getRect(_key('intel-rank-crown-1'));
      final face = tester.getRect(_key('intel-rank-face-1'));
      expect(crown.width, moreOrLessEquals(72 * 0.7));
      expect(crown.top, lessThan(face.top));
      expect(crown.bottom, greaterThan(face.top));
    });

    testWidgets('one place: the other two are 「虚位以待」 under a grey crown', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelScreen(onNavigate: (_) {}),
        mining: _BoardMining(1),
        size: const Size(390, 1400),
      );
      expect(_key('intel-rank-community-community-1'), findsOneWidget);
      expect(_key('intel-rank-empty-slot-2'), findsOneWidget);
      expect(_key('intel-rank-empty-slot-3'), findsOneWidget);
      expect(find.text('虚位以待'), findsNWidgets(2));
    });
  });

  group('聊天 · 磨砂板', () {
    testWidgets('on the wall a row is the block ground at 92 %, the wall '
        'only just showing through; off the wall it keeps the page ground', (
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
      Color ground(String key) => tester
          .widget<Material>(
            find
                .descendant(of: _key(key), matching: find.byType(Material))
                .first,
          )
          .color!;
      expect(ground('on-wall'), loopChatBoardFill);
      expect(ground('on-wall').a, lessThan(1));
      // S279 · decision 0237: the board is the block ground at 92 %.
      expect(loopChatBoardFill.a, closeTo(0.92, 0.01));
      expect(loopChatBoardFill.withValues(alpha: 1), LoopColors.plate);
      expect(ground('off-wall'), LoopTheme.dark.scaffoldBackgroundColor);
      expect(loopChatBoardHairline, const Color(0x14F2F2F4));

      // Contrast over the darkened wall: its 99th-percentile pixel lands at
      // #161616 after the wall's own 85 % and the page wash (decision 0224).
      final over = loopCompositeOver(
        loopChatBoardFill,
        const Color(0xFF161616),
      );
      expect(loopContrastRatio(LoopColors.chalk, over), greaterThan(4.5));
      expect(loopContrastRatio(LoopColors.text2, over), greaterThan(4.5));
      expect(loopContrastRatio(LoopColors.text3, over), greaterThan(4.5));
    });
  });

  test('the podium face size is 72 for the winner and 56 beside it', () {
    expect(intelPodiumFaceSize(1), 72);
    expect(intelPodiumFaceSize(2), 56);
  });
}
