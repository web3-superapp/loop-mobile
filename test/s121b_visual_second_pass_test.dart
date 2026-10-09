import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';

import 'support/meme_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

MemeTokenRow _row({
  String name = 'Frog',
  String symbol = 'FROG',
  String status = 'trading',
  int progressBps = 3327,
  String? change = '76.89',
}) => memePage(
  items: <Map<String, Object?>>[
    memeRowJson(
      name: name,
      symbol: symbol,
      status: status,
      progressBps: progressBps,
      change: change,
      pool: status == 'graduated'
          ? '0x7777777777777777777777777777777777777777'
          : null,
      graduatedAt: status == 'graduated' ? '2026-10-08T05:00:00.000Z' : null,
    ),
  ],
).items.single;

void main() {
  group('LoopEmptyState', () {
    testWidgets(
      'draws the illustration, the title, one sentence and the step',
      (tester) async {
        var pressed = false;
        await _pump(
          tester,
          LoopEmptyState(
            illustration: LoopIllustration.voiceRoom,
            title: '还没有人开播',
            message: '社区开播时会出现在这里',
            action: LoopButton(
              key: const ValueKey<String>('go'),
              label: '去社区看看',
              primary: true,
              onPressed: () => pressed = true,
            ),
          ),
        );
        expect(_key('loop-empty-illustration-voice-room'), findsOneWidget);
        expect(find.text('还没有人开播'), findsOneWidget);
        expect(find.text('社区开播时会出现在这里'), findsOneWidget);
        // Centred: the title's centre is the screen's centre.
        expect(
          tester.getCenter(find.text('还没有人开播')).dx,
          moreOrLessEquals(195, epsilon: 1),
        );
        await tester.tap(_key('go'));
        expect(pressed, isTrue);
      },
    );

    testWidgets('compact draws the illustration at 64', (tester) async {
      await _pump(
        tester,
        const LoopEmptyState(
          illustration: LoopIllustration.holders,
          title: '还没有持有者',
          compact: true,
        ),
      );
      expect(
        tester.getSize(_key('loop-empty-illustration-holders')),
        const Size(64, 64),
      );
    });

    test('every illustration is a registered flat line drawing', () {
      for (final illustration in LoopIllustration.values) {
        final svg = File(illustration.asset).readAsStringSync();
        expect(svg, contains('viewBox="0 0 96 96"'), reason: illustration.name);
        expect(svg, contains('stroke-width="1.7"'), reason: illustration.name);
        expect(svg.toLowerCase(), isNot(contains('gradient')));
        expect(svg.toLowerCase(), isNot(contains('<text')));
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('- assets/illustrations/'),
      );
    });
  });

  group('发射台 row', () {
    testWidgets('trading: ticker, cap, price, the 1h move and the pill', (
      tester,
    ) async {
      await _pump(tester, MemeTokenCard(row: _row()));
      expect(_key('meme-progress-fill'), findsOneWidget);
      expect(_key('meme-graduated-tag'), findsNothing);
      expect(find.text('FROG'), findsOneWidget);
      expect(find.text('市值 \$9,891'), findsOneWidget);
      expect(find.text(r'$0.0₅9891'), findsOneWidget);
      expect(find.text('+76.89% 1h'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
    });

    testWidgets('full: the pill is filled, the cap is not drawn', (
      tester,
    ) async {
      await _pump(
        tester,
        MemeTokenCard(row: _row(status: 'full', progressBps: 10000)),
      );
      expect(_key('meme-progress-fill'), findsOneWidget);
      expect(_key('meme-graduated-tag'), findsNothing);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('graduated: the pill says so', (tester) async {
      await _pump(
        tester,
        MemeTokenCard(
          row: _row(status: 'graduated', progressBps: 10000, change: null),
        ),
      );
      expect(_key('meme-graduated-tag'), findsOneWidget);
      expect(_key('meme-progress-fill'), findsNothing);
      expect(find.text('已毕业'), findsOneWidget);
      // An unreported move draws nothing rather than a dash or a zero.
      expect(_key('meme-change'), findsNothing);
    });

    testWidgets('a long ticker gives way; price and pill stay inside', (
      tester,
    ) async {
      await _pump(
        tester,
        MemeTokenCard(row: _row(symbol: 'WZPD4YLWZPD4YLWZ')),
        width: 320,
      );
      expect(tester.takeException(), isNull);
      final ticker = tester.renderObject<RenderParagraph>(
        find.text('WZPD4YLWZPD4YLWZ'),
      );
      expect(ticker.didExceedMaxLines, isTrue);
      final price = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey<String>('meme-row-price')),
      );
      expect(price.didExceedMaxLines, isFalse);
      final rowBox = tester.getRect(find.byType(MemeTokenCard));
      expect(
        tester.getRect(_key('meme-progress-fill')).left,
        greaterThan(tester.getRect(_key('meme-row-price')).right),
      );
      expect(
        tester.getRect(find.text('33%')).right,
        lessThanOrEqualTo(rowBox.right - 16),
      );
    });
  });

  group('quote row', () {
    test('folds a long run of zeros and signs a move', () {
      expect(loopFoldedZerosPrice(r'$0.000005601'), r'$0.0₅5601');
      expect(loopFoldedZerosPrice(r'$0.0123'), r'$0.0123');
      expect(loopSignedPercent(Decimal.parse('-4.32')), '-4.32%');
      expect(loopSignedPercent(Decimal.parse('1.3')), '+1.30%');
    });

    testWidgets('the pill takes the move colour on its soft ground', (
      tester,
    ) async {
      await _pump(tester, LoopChangePill(change: Decimal.parse('-4.32')));
      final box = tester.widget<Container>(_key('loop-change-pill'));
      expect((box.decoration! as BoxDecoration).color, LoopColors.fallSoft);
      expect(tester.getSize(_key('loop-change-pill')), const Size(96, 44));
    });
  });

  group('算力榜 podium', () {
    IntelRankEntry entry(int position) => IntelRankEntry(
      id: 'user-$position',
      position: position,
      leading: (size) => SizedBox.square(dimension: size),
      name: 'member$position',
      figure: '${1000 - position}',
      weight: '1.$position',
    );

    testWidgets('three places, the winner in the middle', (tester) async {
      await _pump(
        tester,
        IntelRankPodium(
          entries: <IntelRankEntry>[entry(1), entry(2), entry(3)],
        ),
      );
      final first = tester.getRect(_key('intel-rank-user-1'));
      final second = tester.getRect(_key('intel-rank-user-2'));
      final third = tester.getRect(_key('intel-rank-user-3'));
      expect(second.left, lessThan(first.left));
      expect(first.left, lessThan(third.left));
      // Decision 0123: one height for all three; the winner stands out by
      // its crown, its 56 face and its lighter card.
      expect(first.height, second.height);
      expect(second.height, third.height);
      for (final place in <int>[1, 2, 3]) {
        expect(_key('intel-rank-medal-$place'), findsOneWidget);
      }
      final medal = tester.widget<Container>(_key('intel-rank-medal-2'));
      expect((medal.decoration! as BoxDecoration).color, LoopColors.brass);
      expect(find.text('权重 1.1'), findsOneWidget);
      expect(find.textContaining('人有算力'), findsNothing);
    });

    testWidgets('from the fourth place on, a plain row', (tester) async {
      await _pump(
        tester,
        IntelRankRow(
          position: 4,
          leading: const SizedBox.square(dimension: 36),
          name: '新手村',
          weight: '0.5',
          figure: '384',
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('权重 0.5'), findsOneWidget);
      expect(find.text('算力'), findsNothing);
    });
  });

  group('community faces', () {
    test('the first sentence of a description', () {
      const face = CommunityFace(
        name: 'DeFi 早读会',
        description: '每周一起读 DeFi。欢迎新人',
      );
      expect(face.firstSentence, '每周一起读 DeFi');
      expect(const CommunityFace(name: 'x').firstSentence, isNull);
    });

    test('remembers what the home aggregate and the directory read', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final summary = CommunitySummary(
        communityId: '11111111-2222-3333-4444-555555555555',
        name: 'DeFi 早读会',
        slug: 'defi',
        description: '每周一起读 DeFi。',
        logoRef: 'avatar:preset/community-03',
        verificationStatus: CommunityVerification.verified,
        boundAssetKey: null,
        memberCount: 3,
        createdAt: DateTime.utc(2026),
        configVersion: 'v1',
      );
      container.read(communityFacesProvider.notifier).remember(
        <CommunitySummary>[summary],
      );
      expect(
        container
            .read(
              communityFacesProvider,
            )['11111111-2222-3333-4444-555555555555']
            ?.logoRef,
        'avatar:preset/community-03',
      );
    });
  });

  testWidgets('the inbox badge can be Lime', (tester) async {
    await _pump(
      tester,
      const LoopUnreadBadge(count: 4, color: LoopColors.lime),
    );
    final pill = tester.widget<Container>(_key('loop-unread-pill'));
    expect((pill.decoration! as BoxDecoration).color, LoopColors.lime);
  });

  testWidgets('a quiet chip is a dark pill, never Lime', (tester) async {
    await _pump(
      tester,
      LoopSegBar(
        labels: const <String>['全部', '社区'],
        icons: const <String>['chat', 'community'],
        selectedIndex: 0,
        onSelected: (_) {},
      ),
    );
    final materials = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(LoopSeg),
            matching: find.byType(Material),
          ),
        )
        .map((material) => material.color)
        .toList();
    expect(materials, isNot(contains(LoopColors.lime)));
    expect(materials, contains(LoopColors.line));
  });
}
