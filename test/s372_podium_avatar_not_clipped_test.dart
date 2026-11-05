// S372 · 算力榜领奖台头像不被名次卡盖住 (decision 0296): TF 68 showed the
// three faces' lower parts cut off by the blocks 01 / 02 / 03, because the
// block was raised under the face and painted after it. The face is now
// painted over its block: whole, inside the podium, overlapping the block
// top by no more than the Figma's 16 (docs/58 §5.15: a 62 face at y 354
// over the middle block at y 400).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_title_doodle.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The Figma's overlap of the winner's face into its block.
const double _figmaOverlap = 16;

MiningRank _board(int places, {bool longNames = false}) => s7MiningRank(
  scope: MiningRankScope.communities,
  ranking: MiningRankingCommunities(
    items: <MiningRankCommunityRow>[
      for (var index = 0; index < places; index += 1)
        MiningRankCommunityRow(
          position: index + 1,
          power: '${9000 - index * 1000}',
          community: MiningCommunityRef(
            communityId: 'community-${index + 1}',
            name: longNames
                ? 'An Extremely Long Community Name Number ${index + 1} '
                      '一个非常非常长的社区名字'
                : '社区${index + 1}',
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
  _BoardMining(this.places, {this.longNames = false});

  final int places;
  final bool longNames;
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(_board(places, longNames: longNames));

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

RenderObject _decorated(WidgetTester tester, Finder of) => tester.renderObject(
  find
      .descendant(of: of, matching: find.byType(DecoratedBox), matchRoot: true)
      .first,
);

/// The render path a tap at [point] would walk, topmost first.
List<HitTestTarget> _hits(WidgetTester tester, Offset point) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, point, tester.view.viewId);
  return <HitTestTarget>[for (final entry in result.path) entry.target];
}

/// [ring] (the face with its ring) and [block] for one podium place: the
/// ring whole inside the podium, over the block by at most the Figma's 16,
/// and drawn on top — a tap where the two meet lands on the ring.
void _expectFaceOverBlock(
  WidgetTester tester, {
  required Finder ring,
  required Finder block,
  required String reason,
}) {
  final podium = tester.getRect(_key('intel-rank-podium'));
  final face = tester.getRect(ring);
  final card = tester.getRect(block);
  final screen = Offset.zero & tester.view.physicalSize;
  expect(podium.contains(face.topLeft), isTrue, reason: reason);
  expect(podium.contains(face.bottomRight), isTrue, reason: reason);
  expect(screen.contains(face.topLeft), isTrue, reason: reason);
  expect(screen.contains(face.bottomRight), isTrue, reason: reason);
  // The face stands on the block: a light overlap, never more than the
  // Figma's.
  final overlap = face.bottom - card.top;
  expect(overlap, greaterThan(0), reason: reason);
  expect(overlap, lessThanOrEqualTo(_figmaOverlap), reason: reason);
  expect(face.left, greaterThanOrEqualTo(card.left), reason: reason);
  expect(face.right, lessThanOrEqualTo(card.right), reason: reason);
  // Where the two meet, the face is on top.
  final meet = Offset(face.center.dx, (face.bottom + card.top) / 2);
  final hits = _hits(tester, meet);
  final ringBox = _decorated(tester, ring);
  final blockBox = _decorated(tester, block);
  expect(hits, contains(ringBox), reason: reason);
  final blockAt = hits.indexOf(blockBox);
  if (blockAt >= 0) {
    expect(hits.indexOf(ringBox), lessThan(blockAt), reason: reason);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int places = 3,
  bool longNames = false,
}) async {
  await pumpS7Page(
    tester,
    IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
    mining: _BoardMining(places, longNames: longNames),
    size: Size(width, 1400),
  );
}

void main() {
  for (final width in <double>[390, 360]) {
    testWidgets('$width wide: the three faces are whole, inside the podium, '
        'over their blocks by no more than the Figma\'s 16', (tester) async {
      await _pump(tester, width: width);
      for (final place in <int>[1, 2, 3]) {
        _expectFaceOverBlock(
          tester,
          ring: _key('intel-rank-ring-$place'),
          block: _key('intel-rank-block-$place'),
          reason: 'place $place at $width',
        );
        // The sizes and the ring stay as they were (62 / 54 in a 2 ring 2 out).
        expect(
          tester.getSize(_key('intel-rank-face-$place')),
          Size.square(intelPodiumFaceSize(place)),
        );
        expect(
          tester.getSize(_key('intel-rank-ring-$place')),
          Size.square(intelPodiumRingExtent(place)),
        );
      }
      // The crown still stands over the winner's face.
      expect(
        tester.getRect(_key('intel-rank-crown-1')).bottom,
        lessThanOrEqualTo(tester.getRect(_key('intel-rank-ring-1')).top),
      );
      // The index sits in the block, under the face.
      for (final place in <int>[1, 2, 3]) {
        final card = tester.getRect(_key('intel-rank-block-$place'));
        final index = tester.getRect(_key('intel-rank-index-$place'));
        expect(card.contains(index.center), isTrue);
      }
    });

    testWidgets('$width wide: long names leave the faces where they are', (
      tester,
    ) async {
      await _pump(tester, width: width);
      final short = <int, Rect>{
        for (final place in <int>[1, 2, 3])
          place: tester.getRect(_key('intel-rank-ring-$place')),
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, width: width, longNames: true);
      for (final place in <int>[1, 2, 3]) {
        expect(
          tester.getRect(_key('intel-rank-ring-$place')).size,
          short[place]!.size,
        );
        expect(
          tester.getRect(_key('intel-rank-ring-$place')).center.dx,
          moreOrLessEquals(short[place]!.center.dx, epsilon: 0.01),
        );
        _expectFaceOverBlock(
          tester,
          ring: _key('intel-rank-ring-$place'),
          block: _key('intel-rank-block-$place'),
          reason: 'long name, place $place at $width',
        );
      }
    });

    testWidgets('$width wide: an empty place\'s 52 ring is over its block '
        'too', (tester) async {
      await _pump(tester, width: width, places: 1);
      for (final place in <int>[2, 3]) {
        expect(
          tester.getSize(_key('intel-rank-empty-ring-$place')),
          const Size.square(52),
        );
        _expectFaceOverBlock(
          tester,
          ring: _key('intel-rank-empty-ring-$place'),
          block: _key('intel-rank-empty-block-$place'),
          reason: 'empty place $place at $width',
        );
      }
    });
  }

  // S372 · decision 0296, the requester 11-05 16:52: MEME's Yellow
  // 「发射 / Launch」 wears the tab bar's own MEME rocket (the line glyph,
  // docs/58 §8) and the glyph with the word sits centred both ways, 6 apart;
  // the button stays 30 high at a 6 corner (§9.4).
  for (final locale in <String>['zh', 'en']) {
    testWidgets('$locale: 发射 wears the tab bar\'s MEME rocket, glyph and '
        'word centred in the button', (tester) async {
      LoopL10n.use(
        locale == 'zh' ? LoopL10n.simplifiedChinese : LoopL10n.english,
      );
      addTearDown(() => LoopL10n.use(LoopL10n.english));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: Center(child: Launch2LaunchCapsule(onPressed: () {})),
            ),
          ),
        ),
      );
      await tester.pump();

      final glyph = tester.widget<SvgPicture>(
        _key('launch2-create-capsule-glyph'),
      );
      expect(
        (glyph.bytesLoader as SvgAssetLoader).assetName,
        LoopFigmaAssets.nav('meme', active: false),
      );
      expect(
        glyph.colorFilter,
        const ColorFilter.mode(LoopColors.onYellow, BlendMode.srcIn),
      );

      final button = tester.getRect(_key('launch2-create-capsule'));
      final icon = tester.getRect(_key('launch2-create-capsule-glyph'));
      final word = tester.getRect(_key('launch2-create-capsule-word'));
      expect(
        tester.widget<Text>(_key('launch2-create-capsule-word')).data,
        locale == 'zh' ? '发射' : 'Launch',
      );
      expect(button.height, LoopTouch.buttonCompact);
      expect(
        (tester.widget<Container>(_key('launch2-create-capsule')).decoration!
                as BoxDecoration)
            .borderRadius,
        LoopRadius.compactButton,
      );
      expect(icon.size, const Size.square(Launch2LaunchCapsule.glyphSize));
      // 6 from the glyph to the word.
      expect(word.left - icon.right, moreOrLessEquals(6, epsilon: 0.01));
      // Each centre line on the button's, within 1.
      expect(icon.center.dy, moreOrLessEquals(button.center.dy, epsilon: 1));
      expect(word.center.dy, moreOrLessEquals(button.center.dy, epsilon: 1));
      final pair = icon.expandToInclude(word);
      expect(pair.center.dx, moreOrLessEquals(button.center.dx, epsilon: 1));
      expect(pair.center.dy, moreOrLessEquals(button.center.dy, epsilon: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
