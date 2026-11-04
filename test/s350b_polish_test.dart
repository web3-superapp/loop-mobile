// S350b · decision 0275: the polish round on 情报 · 算力, 算力榜 and the MEME
// home — one hero with 全网 inside it and the place as the way into 算力榜,
// no 「—」 cells, 代币 first, 邀请's sub tabs a level down, the podium's
// names never smaller than the rows', the MEME banner's words clear of the
// hand and its empty desk without a sentence, and a row's name never cut for
// its ticker.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

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

  group('情报 · 算力 · the hero', () {
    testWidgets('全网 inside 我的总算力; the place opens 算力榜', (tester) async {
      var rank = 0;
      await s350bPumpPower(
        tester,
        page: MiningScreen(embedded: true, onOpenRank: () => rank += 1),
      );
      final hero = _key('mining-summary-hero');
      expect(hero, findsOneWidget);
      expect(
        find.descendant(of: hero, matching: _key('mining-network-card')),
        findsOneWidget,
      );
      expect(_key('mining-network-card'), findsOneWidget);
      // The place and the crown are the way in.
      // S353b · decision 0279 (docs/58 §5.14): 「Current rank #12」 with the
      // number set apart; the place reads the same aloud.
      expect(
        tester
            .widget<Text>(_key('mining-summary-hero-rank'))
            .textSpan!
            .toPlainText(),
        '#12',
      );
      expect(
        find.descendant(
          of: _key('mining-network-rank-action'),
          matching: _key('mining-summary-hero-rank'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(_key('mining-network-rank-action')).height,
        greaterThanOrEqualTo(LoopTouch.minimum),
      );
      await tester.tap(_key('mining-network-rank-action'));
      expect(rank, 1);
      // My power leads at the power card's 30 / 700 white (S353b); 全网 is a
      // step down.
      final power = tester.widget<Text>(_key('mining-summary-hero-power'));
      expect(power.style!.fontSize, LoopType.heroFigure.fontSize);
      expect(power.style!.color, LoopColors.textPrimary);
      final network = tester.widget<Text>(_key('mining-network-total'));
      expect(network.style!.fontSize, LoopType.figure.fontSize);
      expect(network.style!.color, LoopColors.chalk);
      // No 「—」 cell: 有效邀请 was not read.
      expect(_key('mining-summary-hero-active-invites'), findsNothing);
      expect(
        find.descendant(of: hero, matching: find.text(launchMissingFigure)),
        findsNothing,
      );
      expect(_key('mining-summary-hero-last-hour-power'), findsOneWidget);
    });

    testWidgets('before 我的总算力 is read, 全网 stands on its own', (tester) async {
      for (final answer in <S7Answer<MiningSummary>>[
        S7Answer<MiningSummary>(pending: true),
        S7Answer<MiningSummary>(failure: LaunchFailureKind.offline),
        S7Answer<MiningSummary>(failure: LaunchFailureKind.unavailable),
        S7Answer<MiningSummary>(failure: LaunchFailureKind.unexpected),
      ]) {
        await pumpS7Page(
          tester,
          const MiningScreen(embedded: true),
          mining: FakeMiningGateway(summary: answer),
          settle: answer.pending != true,
        );
        expect(_key('mining-summary-hero'), findsNothing);
        expect(_key('mining-network-card'), findsOneWidget);
        expect(_key('mining-network-rank-action'), findsOneWidget);
        expect(_key('mining-power-tabs'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('nothing counted: one hero, one line under the tabs', (
      tester,
    ) async {
      await s350bPumpPower(tester, empty: true);
      expect(_key('mining-summary-hero'), findsOneWidget);
      expect(_key('mining-network-split'), findsNothing);
      expect(_key('mining-composition-empty'), findsOneWidget);
      expect(find.text(launchMissingFigure), findsNothing);
    });

    testWidgets('代币 / NFT / 邀请, 代币 chosen', (tester) async {
      await s350bPumpPower(tester);
      // S353b · decision 0279 (docs/58 §5.3): the shared filter chips.
      final bar = tester.widget<LoopFilterChips>(_key('mining-power-tabs'));
      expect(bar.labels, <String>['Token', 'NFT', 'Invitation']);
      expect(bar.selectedIndex, 0);
      expect(_key('mining-power-tab-token'), findsOneWidget);
    });
  });

  group('情报 · 算力 · 邀请', () {
    for (final width in <double>[390, 360]) {
      testWidgets('the sub tabs are a level down; share holds a line @$width', (
        tester,
      ) async {
        await s350bPumpPower(tester, sub: 'invite', size: Size(width, 1700));
        final tabs = _key('referral-tabs');
        expect(tester.widget(tabs), isA<ReferralSubTabs>());
        expect(
          find.descendant(of: tabs, matching: find.byType(LoopSegBar)),
          findsNothing,
        );
        // The filter step (decision 0277): the shared Figma filter chips,
        // 54 × 32 — the same chip every filter row draws now.
        final chips = tester.widgetList<LoopFilterChip>(
          find.descendant(of: tabs, matching: find.byType(LoopFilterChip)),
        );
        expect(chips.map((chip) => chip.label), <String>[
          'Invite list',
          'Invite boost',
        ]);
        expect(ReferralSubTabs.filterHeight, LoopTouch.chipHeight);
        expect(LoopSegBar.capsuleHeight, LoopTouch.chipHeight);
        expect(chips.first.selected, isTrue);
        // 分享邀请链接 on one line.
        final share = find.descendant(
          of: _key('referral-share-link'),
          matching: find.text('Share link'),
        );
        expect(_cut(tester, share), isFalse);
        expect(
          tester.getSize(share).height,
          lessThan(LoopType.button.fontSize! * 2),
        );

        await s350bSubTab(tester, 'Invite boost');
        expect(_key('referral-tab-boost'), findsOneWidget);
      });
    }
  });

  group('算力榜', () {
    testWidgets('a podium name is never smaller than a row name', (
      tester,
    ) async {
      await s350bPumpRank(tester);
      final podium = _style(tester, _key('intel-rank-name-1'));
      final row = _style(
        tester,
        find.descendant(
          of: _key('intel-rank-community-community-4'),
          matching: find.text('社区4'),
        ),
      );
      expect(podium.fontSize, greaterThanOrEqualTo(row.fontSize!));
      final figure = _style(tester, _key('intel-rank-figure-1'));
      final rowFigure = _style(
        tester,
        find.descendant(
          of: _key('intel-rank-community-community-4'),
          matching: _key('intel-rank-row-figure'),
        ),
      );
      // S353b · decision 0279 (docs/58 §5.15 / §5.16): both 13 / 600.
      expect(figure.fontSize, greaterThanOrEqualTo(rowFigure.fontSize!));
      // The place column is a step under the name.
      final place = _style(
        tester,
        find.descendant(
          of: _key('intel-rank-community-community-4'),
          matching: _key('intel-rank-row-position'),
        ),
      );
      expect(place.fontSize, lessThan(row.fontSize!));
    });
  });

  group('MEME', () {
    test('the banner words stop short of the hand', () {
      expect(Launch2BannerBackdrop.textWidthFor(350), 170);
      expect(Launch2BannerBackdrop.textWidthFor(320), 140);
      expect(
        Launch2BannerBackdrop.textWidthFor(600),
        Launch2BannerBackdrop.textWidth,
      );
      expect(
        Launch2BannerBackdrop.textWidthFor(200),
        Launch2BannerBackdrop.textMinWidth,
      );
    });

    for (final width in <double>[390, 360]) {
      testWidgets('a row keeps its whole name; the ticker gives way @$width', (
        tester,
      ) async {
        await pumpS279MemeHome(tester, size: Size(width, 1400));
        await tester.tap(_key('launch2-desk-tab-live'));
        await tester.pumpAndSettle();
        final name = find.text('Frog Launch');
        expect(name, findsOneWidget);
        expect(_cut(tester, name), isFalse);
        // 「25%」 is the bar's grey reading, under the name and the price.
        final pct = find.text('25%');
        expect(_style(tester, pct).color, LoopColors.text2);
        // S353b · decision 0279 (docs/58 §5.4): the bar's reading 10 / 300.
        expect(_style(tester, pct).fontWeight, LoopType.progress.fontWeight);
        await drainS269(tester);
      });
    }

    for (final width in <double>[350, 320]) {
      testWidgets('the empty desk: the fact, no sentence, never cut @$width', (
        tester,
      ) async {
        await pumpS7Page(
          tester,
          Center(
            child: SizedBox(
              key: const ValueKey<String>('s350b-desk'),
              width: width,
              height: launch2DeskCampaignHeight,
              child: const Launch2DeskFolio(row: null, chainId: 'eip155:56'),
            ),
          ),
          size: Size(width + 40, 400),
        );
        final title = _key('launch2-desk-event-title');
        expect(tester.widget<Text>(title).data, 'No launches in progress');
        expect(_cut(tester, title), isFalse);
        expect(_key('launch2-desk-event-caption'), findsNothing);
        expect(find.textContaining('会出现在这里'), findsNothing);
        final card = tester.getRect(_key('s350b-desk'));
        expect(
          tester.getRect(title).right,
          lessThanOrEqualTo(
            card.left +
                Launch2BannerBackdrop.textLeft +
                Launch2BannerBackdrop.textWidthFor(width) +
                0.5,
          ),
        );
      });
    }
  });
}
