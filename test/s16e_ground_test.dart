import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

import 'support/loop_ground_probe.dart';

/// The grounds this application actually paints, and the colour of each.
///
/// A widget is only ever wrong *relative to one of these*, so the catalogue
/// below renders each shared surface on every one of them rather than on the
/// Ink page alone — which is the ground on which none of these bugs is
/// visible.
const _grounds = <String, Color>{
  'Ink page': LoopColors.ink,
  'Chalk card': LoopColors.chalk,
  'Lime ledger': LoopColors.lime,
};

Widget _ground(String name, Widget child) {
  final body = switch (name) {
    'Chalk card' => LoopChalkCard(child: child),
    'Lime ledger' => LoopLedgerCard(child: child),
    _ => Padding(padding: const EdgeInsets.all(12), child: child),
  };
  return MaterialApp(
    theme: LoopTheme.dark,
    home: Scaffold(
      backgroundColor: LoopColors.ink,
      body: SingleChildScrollView(child: body),
    ),
  );
}

/// The shared primitives a page may put on any ground.
///
/// Every entry is a widget whose whole job is to be carried around: a
/// placeholder, a state strip, a control, an identity tile. They are the ones
/// that travel, so they are the ones that have to hold on all three grounds.
final _catalogue = <String, Widget Function()>{
  'skeleton block': () => const LoopSkeletonBlock(height: 30, width: 120),
  'skeleton card': () => const LoopSkeleton(type: LoopSkeletonType.card),
  'skeleton list': () =>
      const LoopSkeleton(type: LoopSkeletonType.list, rows: 1),
  'state strip': () => const LoopEmpty(message: '二维码不可用', reason: '这一项暂时读不到。'),
  'state strip with a next step': () => LoopEmpty(
    message: '资料暂时读不到',
    reason: '稍后再试。',
    action: LoopButton(label: '重试', onPressed: () {}),
  ),
  'secondary button': () => LoopButton(label: '返回聊天', onPressed: () {}),
  'primary button': () =>
      LoopButton(label: '生成长图', primary: true, onPressed: () {}),
  'neutral badge': () => const LoopBadge('未配置'),
  'avatar fallback': () =>
      const LoopProfileAvatar(avatarRef: null, alias: 'cy'),
  'token logo fallback': () =>
      const LoopTokenLogo(assetSymbol: 'ZZZTEST', fallbackMonogram: 'ZZ'),
  'identity tile fallback': () => const LoopIdentityAvatar(
    atlas: LoopIdentityAtlas.people,
    slot: 'not-a-slot',
    fallbackMonogram: 'CY',
  ),
};

const _tokenCardModel = LoopTokenCardModel(
  symbol: 'ZZZ',
  identifier: '0x0000…0000',
  price: r'$1.00',
  metrics: <LoopTokenMetric>[
    LoopTokenMetric('市值', r'$1'),
    LoopTokenMetric('持有人', '2'),
  ],
  communityLine: '社区里有 2 条相关讨论',
  riskFacts: <LoopTokenRiskFact>[
    LoopTokenRiskFact(fact: '合约未开源', source: 'GoPlus', observedLabel: '2 分钟前'),
  ],
);

void main() {
  group('every shared surface survives every ground', () {
    for (final entry in _catalogue.entries) {
      for (final ground in _grounds.entries) {
        testWidgets('${entry.key} on the ${ground.key}', (tester) async {
          await tester.pumpWidget(_ground(ground.key, entry.value()));
          await tester.pump();

          loopExpectVisibleOnGround(
            tester,
            subtree: find.byType(SingleChildScrollView),
            ground: LoopColors.ink,
          );
        });
      }
    }
  });

  group('the Ink page renders the tokens themselves', () {
    testWidgets('a derived colour on Ink is the token it stands for', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ground('Ink page', LoopButton(label: '重试', onPressed: () {})),
      );
      await tester.pump();

      final decoration = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((box) => box.color != null);
      // `LoopGround` reads each weight off the token it replaces, so the dark
      // rendering is unchanged to the byte.
      expect(decoration.color!.toARGB32(), LoopColors.card2.toARGB32());
      expect(
        decoration.border!.top.color.toARGB32(),
        LoopColors.line2.toARGB32(),
      );
      expect(
        tester.widget<Text>(find.text('重试')).style!.color!.toARGB32(),
        LoopColors.chalk.toARGB32(),
      );
    });

    testWidgets('a neutral badge on Ink is Card2 and Text2', (tester) async {
      await tester.pumpWidget(_ground('Ink page', const LoopBadge('未配置')));
      await tester.pump();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(LoopBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (container.decoration! as BoxDecoration).color!.toARGB32(),
        LoopColors.card2.toARGB32(),
      );
      expect(
        tester.widget<Text>(find.text('未配置')).style!.color!.toARGB32(),
        LoopColors.text2.toARGB32(),
      );
    });

    testWidgets('a card skeleton on Ink is Card and Line', (tester) async {
      await tester.pumpWidget(
        _ground('Ink page', const LoopSkeleton(type: LoopSkeletonType.card)),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-skeleton-card')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color!.toARGB32(), LoopColors.card.toARGB32());
      expect(
        decoration.border!.top.color.toARGB32(),
        LoopColors.line.toARGB32(),
      );
    });
  });

  group('a light folio declares the ground it paints', () {
    for (final variant in LoopFolioVariant.values) {
      testWidgets('the ${variant.name} folio hands its ink to `trailing`', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              backgroundColor: LoopColors.ink,
              body: SingleChildScrollView(
                child: LoopFolioPrimary(
                  heading: r'$1.00',
                  kicker: 'TOKEN FACTS',
                  caption: '每个数字都标注出处和时间。',
                  variant: variant,
                  // Exactly the slot that shipped broken: a monogram fallback
                  // derives from the ambient ink, and the Lime and Chalk
                  // folios used to hand it the page's Chalk.
                  trailing: const LoopTokenLogo(
                    assetSymbol: 'ZZZTEST',
                    fallbackMonogram: 'ZZ',
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        loopExpectVisibleOnGround(
          tester,
          subtree: find.byType(SingleChildScrollView),
          ground: LoopColors.ink,
        );
        // Pinned by value as well as by contrast: the fallback disc used to be
        // Chalk at 10% with Chalk letters in it, which on Lime is a 44px hole.
        final expected = switch (variant) {
          LoopFolioVariant.lime || LoopFolioVariant.chalk => LoopColors.ink,
          LoopFolioVariant.quiet => LoopColors.chalk,
        };
        final disc = tester.widget<Container>(
          find.byKey(const ValueKey<String>('loop-asset-monogram')),
        );
        expect(
          (disc.decoration! as BoxDecoration).color!.toARGB32(),
          expected.withValues(alpha: LoopColors.card2.a).toARGB32(),
        );
        expect(
          tester.widget<Text>(find.text('ZZ')).style!.color!.toARGB32(),
          expected.toARGB32(),
        );
      });
    }

    testWidgets('the quiet folio is unchanged on the Ink page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: LoopFolioPrimary(heading: '钱包', kicker: 'WALLET LEDGER'),
          ),
        ),
      );
      await tester.pump();

      // The quiet folio always drew its own copy in Chalk and faded it with an
      // `Opacity` layer; declaring the ground did not move it.
      expect(
        tester
            .widget<Text>(find.text('WALLET LEDGER'))
            .style!
            .color!
            .toARGB32(),
        LoopColors.chalk.toARGB32(),
      );
      expect(
        tester.widget<Text>(find.text('钱包')).style!.color!.toARGB32(),
        LoopColors.lime.toARGB32(),
      );
    });
  });

  group('the Chalk Token Card is a Chalk card', () {
    testWidgets('nothing in it is painted Chalk on Chalk', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: SingleChildScrollView(
              child: LoopTokenCard(
                state: LoopTokenCardState.risk,
                model: _tokenCardModel,
                chalk: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      loopExpectVisibleOnGround(
        tester,
        subtree: find.byType(LoopTokenCard),
        ground: LoopColors.ink,
      );
    });

    testWidgets('the Graphite card is unchanged', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: SingleChildScrollView(
              child: LoopTokenCard(
                state: LoopTokenCardState.risk,
                model: _tokenCardModel,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final riskBar = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-token-card-risk-facts')),
      );
      final decoration = riskBar.decoration! as BoxDecoration;
      expect(decoration.color!.toARGB32(), LoopColors.card2.toARGB32());
      expect(
        decoration.border!.top.color.toARGB32(),
        LoopColors.line.toARGB32(),
      );
    });
  });

  group('the probe itself states the rule it enforces', () {
    test('a soft token on its own ground moves nothing', () {
      expect(loopGroundDelta(LoopColors.card2, LoopColors.chalk), lessThan(1));
      expect(loopGroundDelta(LoopColors.line, LoopColors.chalk), lessThan(1));
      // The same tokens on the Ink page are exactly what they were drawn for.
      expect(
        loopGroundDelta(LoopColors.card2, LoopColors.ink),
        greaterThan(20),
      );
      expect(
        loopContrastRatio(LoopColors.chalk, LoopColors.ink),
        greaterThan(15),
      );
      expect(
        loopContrastRatio(LoopColors.chalk, LoopColors.chalk),
        lessThan(1.01),
      );
    });
  });
}
