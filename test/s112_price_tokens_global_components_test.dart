import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart' show loopStreamChatConfiguration;
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/integrations/communication/loop_reactions.dart';
import 'package:loop_mobile/integrations/communication/loop_stream_reaction_icon_resolver.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show StreamUnicodeEmoji;

/// Any code point a platform renders as a colour Emoji (the same ranges
/// `scripts/check_harness.py` `check_no_emoji` holds).
final _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{FE0F}\u{20E3}\u{2600}-\u{27BF}\u{2B50}\u{2B55}]',
  unicode: true,
);

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: LoopTheme.dark,
    home: Scaffold(
      backgroundColor: LoopColors.ink,
      body: Center(child: child),
    ),
  ),
);

List<Decimal> _closes(List<String> values) =>
    values.map(Decimal.parse).toList(growable: false);

void main() {
  // -------------------------------------------------------------------------
  // 1 · rise / fall
  // -------------------------------------------------------------------------
  group('S112 · 涨跌色 rise / fall（决策 0117）', () {
    test(
      'the tokens are the market green and red, outside the brand three',
      () {
        expect(LoopColors.rise, const Color(0xFF22C55E));
        expect(LoopColors.fall, const Color(0xFFEF4444));
        expect(LoopColors.riseSoft, const Color(0x2122C55E));
        expect(LoopColors.fallSoft, const Color(0x21EF4444));
        expect(LoopColors.rise, isNot(LoopColors.lime));
        expect(LoopColors.fall, isNot(LoopColors.danger));
      },
    );

    test(
      'LoopPriceMove maps up / down / flat / unread to rise / fall / muted',
      () {
        expect(LoopPriceMove.up.color, LoopColors.rise);
        expect(LoopPriceMove.down.color, LoopColors.fall);
        expect(LoopPriceMove.flat.color, LoopColors.muted);
        expect(LoopPriceMove.unread.color, LoopColors.muted);
        expect(LoopPriceMove.up.ground, LoopColors.rise);
        expect(LoopPriceMove.down.ground, LoopColors.fall);
        expect(LoopPriceMove.up.soft, LoopColors.riseSoft);
        expect(LoopPriceMove.down.soft, LoopColors.fallSoft);
        expect(LoopPriceMove.flat.soft.a, 0);
      },
    );

    test('a close series reads its direction first to last', () {
      expect(
        LoopPriceMove.ofSeries(_closes(<String>['1', '3'])),
        LoopPriceMove.up,
      );
      expect(
        LoopPriceMove.ofSeries(_closes(<String>['3', '9', '1'])),
        LoopPriceMove.down,
      );
      expect(
        LoopPriceMove.ofSeries(_closes(<String>['2', '2'])),
        LoopPriceMove.flat,
      );
      expect(
        LoopPriceMove.ofSeries(_closes(<String>['2'])),
        LoopPriceMove.unread,
      );
      expect(LoopPriceMove.ofSeries(const <Decimal>[]), LoopPriceMove.unread);
    });
  });

  // -------------------------------------------------------------------------
  // 2 · sparkline default colour
  // -------------------------------------------------------------------------
  group('S112 · sparkline 默认色按走势', () {
    Future<Color> paintedColour(WidgetTester tester, LoopSparkline line) async {
      await tester.pumpWidget(
        _host(SizedBox(width: 120, height: 40, child: line)),
      );
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey<String>('loop-sparkline-canvas')),
      );
      return (paint.painter! as LoopSparklinePainter).color;
    }

    testWidgets(
      'a rising series is rise, a falling one fall, a flat one muted',
      (tester) async {
        expect(
          await paintedColour(
            tester,
            LoopSparkline(
              closes: _closes(<String>['1', '2', '3']),
              semanticLabel: '涨',
            ),
          ),
          LoopColors.rise,
        );
        expect(
          await paintedColour(
            tester,
            LoopSparkline(
              closes: _closes(<String>['3', '2', '1']),
              semanticLabel: '跌',
            ),
          ),
          LoopColors.fall,
        );
        expect(
          await paintedColour(
            tester,
            LoopSparkline(
              closes: _closes(<String>['2', '5', '2']),
              semanticLabel: '平',
            ),
          ),
          LoopColors.muted,
        );
      },
    );

    testWidgets('a colour the caller passes wins over the series direction', (
      tester,
    ) async {
      expect(
        await paintedColour(
          tester,
          LoopSparkline(
            closes: _closes(<String>['3', '1']),
            semanticLabel: '指定色',
            color: LoopColors.chalk,
          ),
        ),
        LoopColors.chalk,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 3 · LoopInlineUnavailable
  // -------------------------------------------------------------------------
  group('S112 · LoopInlineUnavailable 三态', () {
    testWidgets('reason only: one 44px line and no action', (tester) async {
      await tester.pumpWidget(
        _host(const LoopInlineUnavailable(message: '分布暂不可用')),
      );

      expect(find.text('分布暂不可用'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-inline-unavailable-retry')),
        findsNothing,
      );
      final line = tester.getSize(
        find.byKey(const ValueKey<String>('loop-inline-unavailable')),
      );
      expect(line.height, greaterThanOrEqualTo(LoopInlineUnavailable.height));
      expect(line.height, lessThan(LoopInlineUnavailable.height + 1));
    });

    testWidgets('with retry: 「重试」 is a 44px target that calls back', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          LoopInlineUnavailable(message: '链上读取失败', onRetry: () => retried += 1),
        ),
      );

      final retry = find.byKey(
        const ValueKey<String>('loop-inline-unavailable-retry'),
      );
      expect(find.text('重试'), findsOneWidget);
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(retry).width, greaterThanOrEqualTo(44));
      await tester.tap(retry);
      expect(retried, 1);
    });

    testWidgets('retrying: 「重试中」 takes no tap', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        _host(
          LoopInlineUnavailable(
            message: '链上读取失败',
            onRetry: () => retried += 1,
            retrying: true,
          ),
        ),
      );

      expect(find.text('重试中'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-inline-unavailable-retry')),
      );
      expect(retried, 0);
    });

    testWidgets('a long reason stays on one line', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 240,
            child: LoopInlineUnavailable(message: '这一行的原因非常长，长到一行放不下也不能把行撑成两行'),
          ),
        ),
      );
      final text = tester.widget<Text>(find.textContaining('这一行的原因非常长'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  // -------------------------------------------------------------------------
  // 4 · LoopProvenanceLine
  // -------------------------------------------------------------------------
  group('S112 · LoopProvenanceLine', () {
    final now = DateTime(2026, 10, 8, 16, 30);

    testWidgets('one weak 11px line: sources, then the local clock', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LoopProvenanceLine(
            sources: const <String>['DexScreener', 'DexScreener', 'GoPlus'],
            observedAt: DateTime(2026, 10, 8, 14, 2),
            now: now,
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.text('来源 DexScreener · GoPlus · 观察于 14:02'),
      );
      expect(text.style?.fontSize, 11);
      expect(text.maxLines, 1);
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('loop-provenance-line')))
            .height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('an earlier day carries its date', (tester) async {
      await tester.pumpWidget(
        _host(
          LoopProvenanceLine(
            sources: const <String>['LOOP 链上索引'],
            observedAt: DateTime(2026, 10, 7, 9, 5),
            prefix: '公式 v3',
            now: now,
          ),
        ),
      );
      expect(
        find.text('公式 v3 · 来源 LOOP 链上索引 · 观察于 10-07 09:05'),
        findsOneWidget,
      );
    });

    testWidgets('nothing to attribute renders nothing', (tester) async {
      await tester.pumpWidget(
        _host(const LoopProvenanceLine(sources: <String>[])),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-provenance-none')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-provenance-line')),
        findsNothing,
      );
    });

    testWidgets('a tap opens the full statement and 「知道了」 closes it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          LoopProvenanceLine(
            sources: const <String>['DexScreener'],
            observedAt: DateTime(2026, 10, 8, 14, 2),
            detail: '价格每 60 秒刷新一次；读不到时显示原因，不显示 0。',
            now: now,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-provenance-line')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('loop-provenance-sheet')),
        findsOneWidget,
      );
      expect(find.text('数据来源'), findsOneWidget);
      expect(find.text('2026-10-08 14:02'), findsOneWidget);
      expect(find.text('价格每 60 秒刷新一次；读不到时显示原因，不显示 0。'), findsOneWidget);

      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('loop-provenance-sheet')),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 5 · reactions without Emoji
  // -------------------------------------------------------------------------
  group('S112 · 表情回应不渲染 Emoji', () {
    const resolver = LoopStreamReactionIconResolver();

    test('the five quick reactions are LOOP words, never Emoji', () {
      expect(resolver.defaultReactions, <String>{
        'like',
        'haha',
        'love',
        'wow',
        'sad',
      });
      final words = <String>[
        for (final type in resolver.defaultReactions)
          (resolver.resolve(type) as StreamUnicodeEmoji).emoji,
      ];
      expect(words, <String>['赞', '哈', '心', '哇', '叹']);
      for (final word in words) {
        expect(_emoji.hasMatch(word), isFalse, reason: word);
      }
    });

    test('an unknown type is 「表态」 and no type carries an Emoji code', () {
      expect(
        (resolver.resolve('fire') as StreamUnicodeEmoji).emoji,
        loopReactionFallbackLabel,
      );
      for (final type in <String>['like', 'haha', 'love', 'wow', 'sad', 'x']) {
        expect(resolver.emojiCode(type), isNull);
      }
      // The picker's 「+」 filters Stream's Emoji catalogue by this set.
      expect(resolver.supportedReactions, isEmpty);
    });

    test('the application hands Stream this resolver', () {
      expect(
        loopStreamChatConfiguration.reactionIconResolver,
        isA<LoopStreamReactionIconResolver>(),
      );
    });

    test('the Preview fixture keys its reactions by LOOP types', () {
      final keys = <String>{
        for (final message in ChatContent.groupMessages)
          ...message.reactions.keys,
      };
      expect(keys, isNotEmpty);
      for (final key in keys) {
        expect(loopReactionLabels.containsKey(key), isTrue, reason: key);
        expect(_emoji.hasMatch(key), isFalse, reason: key);
      }
    });

    testWidgets('a Preview message draws its reactions as words', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: ChatMessageTile(message: ChatContent.groupMessages.first),
          ),
        ),
      );
      expect(find.text('赞 18'), findsOneWidget);
      expect(find.text('哇 6'), findsOneWidget);
    });
  });
}
