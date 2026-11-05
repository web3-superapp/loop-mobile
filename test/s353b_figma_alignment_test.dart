// S353b · decision 0279: MEME, 情报 · 算力 (with 邀请) and 算力榜 on the
// requester's Figma (docs/58 §5.1–§5.5, §5.14–§5.17, §5.20) — the first-level
// tab strip with counts on the MEME home, flat 71 rows with the white
// progress bar, the 35 glass trade band, the 30 「发射」, the power card, the
// filter chips under it, the invite card, and 算力榜's strip, podium and 51
// rows.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_tab_strip.dart';

import 'support/loop_ground_probe.dart';
import 'support/s269_pages.dart';
import 'support/s350b_pages.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

TextStyle _style(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!;

bool _cut(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

void main() {
  loopWatchGround();

  group('MEME home', () {
    for (final width in <double>[390, 360]) {
      testWidgets('tab strip, rows, band and 发射 @$width', (tester) async {
        await pumpS279MemeHome(tester, size: Size(width, 1400));
        await tester.tap(_key('launch2-desk-tab-live'));
        await tester.pumpAndSettle();

        // §5.2: the shared first-level strip, a count after every word, no
        // Purple ground and no splat.
        final strip = tester.widget<LoopTabStrip>(
          find.descendant(
            of: _key('launch2-desk-tabs'),
            matching: find.byType(LoopTabStrip),
          ),
        );
        expect(strip.counts, isNotNull);
        expect(strip.counts!.every((count) => count != null), isTrue);
        expect(strip.selectedIndex, 0);
        expect(_key('launch2-desk-tab-splat-live'), findsNothing);
        expect(
          tester.getSize(_key('launch2-desk-tab-live')).height,
          LoopTabStrip.cellHeight,
        );

        // §5.4: flat rows of 70 + the 1 px line, the white bar on its
        // track, the 19 stage capsule.
        final row = find.byType(Launch2BoardRow).first;
        expect(tester.getSize(row).height, Launch2BoardRow.height);
        expect(
          find.descendant(
            of: find.byType(Launch2Board).first,
            matching: find.byType(Divider),
          ),
          findsWidgets,
        );
        final bar = find.byType(Launch2ProgressBar).first;
        expect(tester.getSize(bar).height, Launch2ProgressBar.height);
        expect(
          tester.getSize(find.byType(Launch2BoardStage).first).height,
          Launch2BoardStage.height,
        );
        expect(Launch2BoardStage.height, 19);
        final pct = find.descendant(
          of: row,
          matching: find.textContaining('%'),
        );
        expect(_style(tester, pct.first).fontSize, LoopType.progress.fontSize);

        // §5.5: the glass trade band, 35 high, the shadow on.
        final band = _key('launch2-ticker-band');
        expect(tester.getSize(band).height, 35);
        final decoration =
            tester.widget<DecoratedBox>(band).decoration as BoxDecoration;
        expect(decoration.color, LoopColors.surfaceGlass);
        expect(decoration.boxShadow, LoopDepth.ticker);

        // §5.20: 发射 is 30 high at a 6 corner.
        expect(
          tester.getSize(_key('launch2-create-capsule')).height,
          LoopTouch.buttonCompact,
        );

        // 360: no word in the strip is cut.
        for (final title in strip.labels) {
          final word = find.descendant(
            of: _key('launch2-desk-tabs'),
            matching: find.text(title),
          );
          expect(_cut(tester, word), isFalse, reason: title);
        }
        await drainS269(tester);
      });
    }

    test('the banner is the Figma 162', () {
      expect(launch2DeskCampaignHeight, 162);
    });
  });

  group('情报 · 算力', () {
    testWidgets('the power card and its place', (tester) async {
      var opened = 0;
      await s350bPumpPower(
        tester,
        page: MiningScreen(embedded: true, onOpenRank: () => opened += 1),
      );
      final hero = tester.widget<Container>(_key('mining-summary-hero'));
      final ground = hero.decoration! as BoxDecoration;
      expect(ground.gradient, LoopColors.powerCardGradient);
      expect(ground.borderRadius, LoopRadius.card);
      final power = tester.widget<Text>(_key('mining-summary-hero-power'));
      expect(power.style!.fontSize, LoopType.heroFigure.fontSize);
      expect(power.style!.color, LoopColors.textPrimary);
      // S378 · decision 0302: 「My rank #12」 with the crown, the way into
      // 算力榜, at the right end of the figure row.
      expect(
        find.descendant(
          of: _key('mining-network-rank-action'),
          matching: find.text('My rank'),
        ),
        findsOneWidget,
      );
      final place = tester.widget<Text>(_key('mining-summary-hero-rank'));
      expect(place.textSpan!.toPlainText(), '#12');
      expect(_key('mining-summary-hero-crown'), findsOneWidget);
      expect(
        tester.getSize(_key('mining-network-rank-action')).height,
        greaterThanOrEqualTo(LoopTouch.minimum),
      );
      await tester.tap(_key('mining-network-rank-action'));
      expect(opened, 1);
      // S378 · decision 0302: no snapshot time at the top right.
      expect(_key('mining-summary-hero-caption'), findsNothing);
    });

    test('the place colour follows the Figma', () {
      expect(MiningRankEntry.placeColor(1), LoopColors.yellow);
      expect(MiningRankEntry.placeColor(3), LoopColors.bronze);
      expect(MiningRankEntry.placeColor(12), LoopColors.textPrimary);
    });

    testWidgets('代币 / NFT / 邀请 are filter chips', (tester) async {
      await s350bPumpPower(tester);
      final chips = tester.widget<LoopFilterChips>(_key('mining-power-tabs'));
      expect(chips.labels, <String>['Token', 'NFT', 'Invitation']);
      expect(chips.selectedIndex, 0);
      await tester.tap(
        find.descendant(
          of: _key('mining-power-tabs'),
          matching: find.text('NFT'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('mining-power-tab-nft'), findsOneWidget);
    });

    for (final width in <double>[390, 360]) {
      testWidgets('the invite card @$width', (tester) async {
        await s350bPumpPower(tester, sub: 'invite', size: Size(width, 1700));
        final card = tester.widget<Container>(_key('referral-hero'));
        final ground = card.decoration! as BoxDecoration;
        expect(ground.color, LoopColors.card);
        expect(ground.borderRadius, LoopRadius.chip);
        expect(
          _style(tester, _key('referral-invite-code')).fontSize,
          LoopType.inviteCode.fontSize,
        );
        expect(
          _style(tester, _key('referral-invite-code')).color,
          LoopColors.yellow,
        );
        expect(
          tester.getSize(_key('referral-share-link')).height,
          greaterThanOrEqualTo(LoopTouch.buttonMedium),
        );
        final share = find.descendant(
          of: _key('referral-share-link'),
          matching: find.text('Share link'),
        );
        expect(_cut(tester, share), isFalse);
        // §5.17: the three counts under the card, above the sub tabs.
        final stats = _key('referral-stats');
        expect(stats, findsOneWidget);
        expect(
          tester.getRect(stats).top,
          greaterThanOrEqualTo(tester.getRect(_key('referral-hero')).bottom),
        );
        expect(
          tester.getRect(stats).bottom,
          lessThanOrEqualTo(tester.getRect(_key('referral-tabs')).top),
        );
        for (final (slug, label, value) in <(String, String, String)>[
          ('direct', 'Direct invites', '4'),
          ('active', 'Active members', '3'),
          ('deep', 'Levels 2–5', '12'),
        ]) {
          final figure = tester.widget<Text>(_key('referral-stats-$slug'));
          expect(figure.data, value);
          expect(figure.style!.fontSize, 18);
          expect(figure.style!.fontWeight, FontWeight.w600);
          final word = find.descendant(of: stats, matching: find.text(label));
          expect(_style(tester, word).fontSize, 11);
          expect(_cut(tester, word), isFalse, reason: label);
        }
      });

      testWidgets('no counts sent: no stats card', (tester) async {
        await pumpS7Page(
          tester,
          IntelScreen(onNavigate: (_) {}, sub: 'invite'),
          mining: FakeMiningGateway(),
          referral: FakeReferralGateway(),
          size: const Size(360, 1700),
        );
        await tester.pumpAndSettle();
        expect(_key('referral-hero'), findsOneWidget);
        expect(_key('referral-stats'), findsNothing);
      });
    }
  });

  group('算力榜', () {
    for (final width in <double>[390, 360]) {
      testWidgets('strip, podium and rows @$width', (tester) async {
        await s350bPumpRank(tester, size: Size(width, 1500));
        // §5.2: the boards are the first-level strip.
        expect(tester.widget(_key('intel-rank-scope')), isA<LoopTabStrip>());
        // §5.14: the heading at 19 / 700 with 「ⓘ 实时更新」.
        expect(_key('intel-rank-live-note'), findsOneWidget);
        // §5.15: the faces 62 / 54, the line crown over the winner.
        expect(
          tester.getSize(_key('intel-rank-face-1')).width,
          intelPodiumFaceSize(1),
        );
        expect(
          tester.getSize(_key('intel-rank-face-2')).width,
          intelPodiumFaceSize(2),
        );
        expect(
          find.descendant(
            of: _key('intel-rank-crown-1'),
            matching: find.byType(SvgPicture),
          ),
          findsNothing,
        );
        expect(tester.widget(_key('intel-rank-crown-1')), isA<SvgPicture>());
        expect(
          _style(tester, _key('intel-rank-name-1')).fontSize,
          LoopType.figureSm.fontSize,
        );
        // §5.16: 51 rows, the place in a 34 column, a 36 face.
        final row = _key('intel-rank-community-community-4');
        expect(tester.getSize(row).height, intelRankRowHeight);
        expect(
          _style(
            tester,
            find.descendant(of: row, matching: _key('intel-rank-row-figure')),
          ).fontSize,
          LoopType.figureXs.fontSize,
        );
        expect(intelRankRowFaceSize, 36);
        await tester.tap(
          find.descendant(
            of: _key('intel-rank-scope'),
            matching: find.text('User'),
          ),
        );
        await tester.pumpAndSettle();
        expect(_key('intel-rank-user-1'), findsOneWidget);
      });
    }
  });
}
