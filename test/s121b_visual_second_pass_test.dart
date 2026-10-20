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
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
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

  group('发射台 row · 列表 A (decision 0173)', () {
    final observed = DateTime.utc(2026, 10, 8, 3, 0, 5);

    testWidgets('trading: tile, ticker + age, volume · name, cap and bar', (
      tester,
    ) async {
      await _pump(tester, MemeTokenCard(row: _row(), now: observed));
      expect(find.text('FROG'), findsOneWidget);
      // Created 00:00, observed 03:00:05.
      expect(find.text('3 小时'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('meme-row-age')).style!.color,
        // Decision 0212: a quiet Text3 figure, Purple is for selection.
        LoopColors.text3,
      );
      expect(find.text('\$1,980 交易量 · Frog'), findsOneWidget);
      expect(find.text('市值 \$9,891'), findsOneWidget);
      final cap = tester.widget<Text>(_key('meme-row-cap'));
      // Decision 0190 H4: the quote-row value, figureMd 17/600.
      expect(cap.style!.fontSize, LoopType.figureMd.fontSize);
      expect(cap.style!.fontWeight, LoopType.figureMd.fontWeight);
      // The 56 px `.bar` and the Lime percentage beside it.
      expect(tester.getSize(_key('meme-row-progress')), const Size(56, 6));
      expect(find.byType(LoopProgressBar), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      final label = tester.widget<Text>(_key('meme-progress-label'));
      expect(label.style!.color, LoopColors.lime);
      // Decision 0190 H4: the quote-row secondary step, figureSm 12.
      expect(label.style!.fontSize, LoopType.figureSm.fontSize);
      expect(
        tester.getRect(_key('meme-progress-label')).left,
        greaterThan(tester.getRect(_key('meme-row-progress')).right),
      );
      // The row no longer prints the price or the trading move.
      expect(_key('meme-row-price'), findsNothing);
      expect(_key('meme-change'), findsNothing);
      expect(_key('meme-graduated-tag'), findsNothing);
      // The 44 tile with the r15 corner.
      final logo = tester.widget<MemeLogo>(find.byType(MemeLogo));
      expect(logo.size, 44);
      expect(logo.radius, LoopRadius.tileValue);
      // 14 + 44 + 14 and a hairline; the text column may make it a little
      // shorter at the 1.5 leading (decision 0211), never taller.
      expect(
        tester.getSize(find.byType(MemeTokenCard)).height,
        inInclusiveRange(14 + 44 + 14 + 1, memeCardHeight + 1.5),
      );
    });

    testWidgets('full: the bar is filled to 100%', (tester) async {
      await _pump(
        tester,
        MemeTokenCard(
          row: _row(status: 'full', progressBps: 10000),
          now: observed,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
      final fill = tester.getSize(
        find
            .descendant(
              of: _key('meme-row-progress'),
              matching: find.byType(FractionallySizedBox),
            )
            .first,
      );
      expect(fill.width, moreOrLessEquals(56, epsilon: 0.5));
      expect(_key('meme-graduated-tag'), findsNothing);
    });

    testWidgets('graduated: the 已毕业 badge and the 1h move in price colour', (
      tester,
    ) async {
      await _pump(
        tester,
        MemeTokenCard(
          row: _row(status: 'graduated', progressBps: 10000, change: '8.20'),
          now: observed,
        ),
      );
      final badge = tester.widget<LoopBadge>(_key('meme-graduated-tag'));
      expect(badge.kind, LoopBadgeKind.launch);
      expect(find.text('已毕业'), findsOneWidget);
      expect(_key('meme-row-age'), findsNothing);
      expect(_key('meme-row-progress'), findsNothing);
      expect(find.text('市值 \$9,891'), findsOneWidget);
      expect(find.text('+8.20% 1h'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('meme-change')).style!.color,
        LoopPriceMove.up.color,
      );

      await _pump(
        tester,
        MemeTokenCard(
          row: _row(status: 'graduated', progressBps: 10000, change: null),
          now: observed,
        ),
      );
      // An unreported move draws nothing rather than a dash or a zero.
      expect(_key('meme-change'), findsNothing);
      expect(_key('meme-graduated-tag'), findsOneWidget);
    });

    testWidgets('missing volume, launch time and cap: name only, the reason', (
      tester,
    ) async {
      final bare = memePage(
        items: <Map<String, Object?>>[
          memeRowJson(listingFields: false, price: null, cap: null),
        ],
      ).items.single;
      expect(bare.volume24hUsd1, isNull);
      expect(bare.createdAt, isNull);
      await _pump(tester, MemeTokenCard(row: bare, now: observed));
      expect(tester.takeException(), isNull);
      expect(find.text('Frog'), findsOneWidget);
      expect(_key('meme-row-age'), findsNothing);
      expect(find.textContaining('交易量'), findsNothing);
      expect(_key('meme-row-cap'), findsNothing);
      expect(find.text('价格暂时读不到'), findsOneWidget);
      expect(_key('meme-row-progress'), findsOneWidget);

      // Sent as null, or malformed, reads the same: not a bad row.
      final nulled = memePage(
        items: <Map<String, Object?>>[
          memeRowJson(volume: null, createdAt: null),
          memeRowJson(id: memeTokenIdB, volume: 'lots', createdAt: 'yesterday'),
        ],
      ).items;
      for (final row in nulled) {
        expect(row.volume24hUsd1, isNull);
        expect(row.createdAt, isNull);
      }
    });

    test('ages read in minutes, hours, then days', () {
      final launched = DateTime.utc(2026, 10, 1);
      String at(Duration age) => memeAgeLabel(launched, now: launched.add(age));
      expect(at(const Duration(seconds: 20)), '刚刚');
      expect(at(const Duration(minutes: 11)), '11 分钟');
      expect(at(const Duration(hours: 12, minutes: 5)), '12 小时');
      expect(at(const Duration(days: 1, hours: 3)), '1 天');
      expect(at(const Duration(days: 10)), '10 天');
      expect(at(const Duration(minutes: -5)), '刚刚');
    });

    testWidgets('a long ticker gives way; cap and bar stay inside', (
      tester,
    ) async {
      await _pump(
        tester,
        MemeTokenCard(
          row: _row(symbol: 'WZPD4YLWZPD4YLWZ'),
          now: observed,
        ),
        width: 320,
      );
      expect(tester.takeException(), isNull);
      final ticker = tester.renderObject<RenderParagraph>(
        find.text('WZPD4YLWZPD4YLWZ'),
      );
      expect(ticker.didExceedMaxLines, isTrue);
      final rowBox = tester.getRect(find.byType(MemeTokenCard));
      expect(
        tester.getRect(_key('meme-row-cap')).left,
        greaterThan(tester.getRect(find.text('WZPD4YLWZPD4YLWZ')).right),
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
      // its crown and its 56 face. Decision 0182: each is a record card.
      expect(first.height, second.height);
      expect(second.height, third.height);
      for (final place in <int>[1, 2, 3]) {
        expect(_key('intel-rank-medal-$place'), findsOneWidget);
      }
      final medal = tester.widget<Container>(_key('intel-rank-medal-2'));
      expect((medal.decoration! as BoxDecoration).color, LoopColors.brass);
      expect((medal.decoration! as BoxDecoration).shape, BoxShape.circle);
      expect(find.byType(LoopRecordCard), findsNWidgets(3));
      expect(find.text('权重 1.1'), findsOneWidget);
      expect(find.textContaining('人有算力'), findsNothing);
    });

    testWidgets('from the fourth place on, a plain row', (tester) async {
      await _pump(
        tester,
        IntelRankRow(
          position: 4,
          leading: const SizedBox.square(dimension: 40),
          name: '新手村',
          weight: '0.5',
          caption: '9 人有算力',
          figure: '384',
          share: 0.25,
        ),
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('权重 0.5'), findsOneWidget);
      expect(find.text('9 人有算力'), findsOneWidget);
      expect(find.text('算力'), findsNothing);
      // Decision 0182: the figure's share of the leader's, a 64 px bar.
      final bar = tester.widget<LoopProgressBar>(find.byType(LoopProgressBar));
      expect(bar.value, 0.25);
      expect(tester.getSize(find.byType(LoopProgressBar)).width, 64);
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
    expect(materials, contains(LoopColors.purpleSelected));
  });
}
