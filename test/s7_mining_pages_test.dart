import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'package:loop_mobile/core/navigation/launch_route.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/provenance_finders.dart';

import 'package:loop_mobile/widgets/loop_inline_states.dart';

/// Every Mining figure needs an approved formula version, and there is none.
/// These tests pin the em dash, the server's own reason and the absence of
/// every ratio the prototype used to state.
List<String> _figures(WidgetTester tester) {
  final pattern = RegExp(r'(\d+(\.\d+)?×)|(\d+(\.\d+)?%)|(\$\s?\d)');
  return <String>[
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      if (text.data != null && pattern.hasMatch(text.data!)) text.data!,
  ];
}

/// Every `reasonCode` the copy table answers. A frame that has read nothing
/// may print none of their sentences.
const List<String> _reasonCodesOnTheWire = <String>[
  'LAUNCH_CONTRACT_BASELINE_PENDING',
  'LAUNCH_CONFIG_PENDING_CONFIRMATION',
  'LAUNCH_POOL_EVIDENCE_UNAVAILABLE',
  'LAUNCH_ECONOMY_CONTRACT_PENDING',
  'LAUNCH_RUNTIME_UNAVAILABLE',
  'TIER_MODE_PENDING',
  'STAKING_CONTRACT_PENDING',
  'KYB_PROVIDER_NOT_SELECTED',
  'ATTACHMENT_STORAGE_NOT_SELECTED',
  'MINING_FORMULA_BASELINE_PENDING',
  'MINING_SNAPSHOT_NOT_AVAILABLE',
  'MINING_SNAPSHOT_STALE',
  'MINING_SNAPSHOT_INCOMPLETE',
  'MINING_SNAPSHOT_PENDING',
  'MINING_PRICE_PAIR_NOT_FOUND',
  'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE',
  'MINING_ACCOUNT_NOT_IN_SNAPSHOT',
  'MINING_NETWORK_POWER_ZERO',
  'MINING_DAILY_OUTPUT_NOT_CONFIGURED',
  'MINING_RANK_NOT_RANKED',
  'MINING_RANK_NOT_APPLICABLE',
  'MINING_POWER_PRIVATE',
  'MINING_PRICE_NOT_FRESH',
  'MINING_PRICE_PROXY_NOT_DECLARED',
  'MINING_ASSET_WEIGHT_NOT_CONFIGURED',
  'COMMUNITY_ASSET_NOT_BOUND',
  'COMMUNITY_WEIGHT_AMBIGUOUS',
  'MINING_RUNTIME_UNAVAILABLE',
  'REWARD_AUTHORITY_PENDING',
  'COMMUNITY_WEIGHT_PENDING_REVIEW',
  'REFERRAL_RUNTIME_UNAVAILABLE',
  'PROFILE_ACTIVATION_REQUIRED',
];

/// The caption under the folio heading, which is the sentence the page states
/// about the one figure the hero carries.
String? _heroCaption(WidgetTester tester) => tester
    .widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary).first)
    .caption;

void main() {
  group('mining-community route identity', () {
    test('the panel is addressed by the opaque communityId alone', () {
      final location = MiningRoute.community(s7CommunityId);

      expect(location, '/mining/community?communityId=$s7CommunityId');
      expect(
        MiningRoute.parse(Uri.parse(location), MiningRoute.communityPath),
        s7CommunityId,
      );
      // A name, a slug or a bound address is never a route identity.
      for (final rejected in <String>[
        '/mining/community',
        '/mining/community?communityId=frog-holders',
        '/mining/community?communityId=$s7CommunityId&extra=1',
      ]) {
        expect(
          MiningRoute.parse(Uri.parse(rejected), MiningRoute.communityPath),
          isNull,
          reason: rejected,
        );
      }
    });
  });

  group('mining · the tab', () {
    testWidgets('loading shows a skeleton and no power figure', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('Pending approval'), findsNothing);
    });

    testWidgets('the loading frame states no cause it has not been told', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(pending: true),
        ),
        settle: false,
      );

      // A skeleton frame knows only that it is reading. Every sentence the
      // copy table owns belongs to a server answer, and none has arrived.
      for (final code in _reasonCodesOnTheWire) {
        expect(
          find.textContaining(launchReasonCodeText(code)),
          findsNothing,
          reason: code,
        );
      }
      expect(find.textContaining(launchReasonCodeText(null)), findsNothing);
      expect(find.textContaining('Mining formula'), findsNothing);
      expect(find.text('Loading'), findsOneWidget);
      // Nor is the absence itself settled while the read is in flight.
      expect(find.text(launchMissingHeading), findsNothing);
    });

    testWidgets('a failed read keeps its reason in the state block, not the '
        'hero', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );

      expect(find.text('Loading'), findsNothing);
      expect(find.textContaining('Mining formula'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('mining-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('a reading with no figure is not drawn as an em dash', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        overrides: <Override>[s7TokenLive()],
      );

      // S350b · decision 0275: a cell the server gave no figure for is left
      // out, not drawn as 「—」.
      for (final slug in <String>[
        'estimated-today',
        'accumulated',
        'claimable',
      ]) {
        final cell = find.byKey(ValueKey<String>('mining-summary-hero-$slug'));
        expect(cell, findsNothing, reason: slug);
      }
      // 我的算力 is the heading, and it says the absence in words.
      expect(
        find.byKey(const ValueKey<String>('mining-summary-hero-power')),
        findsOneWidget,
      );
      expect(find.textContaining(launchMissingHeading), findsWidgets);
      // S315: no notice restating the rule under the hero.
      expect(
        find.byKey(const ValueKey<String>('mining-holding-notice')),
        findsNothing,
      );
      expect(_figures(tester), isEmpty);
    });

    testWidgets('the hero says it has no number instead of drawing a dash', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      final heading = find.byKey(
        const ValueKey<String>('mining-summary-hero-power'),
      );
      expect(heading, findsOneWidget);
      // At 44px the em dash stops reading as a placeholder and becomes a
      // stray rule, so the heading states the absence in words. It is still
      // not a 0, not a fixture and not blank.
      expect(find.textContaining(launchMissingHeading), findsWidgets);
      final text = tester.widget<Text>(heading).textSpan!.toPlainText();
      expect(text, launchMissingHeading);
      // No unit follows a figure that is not there.
      expect(text.contains('H'), isFalse);
      // The cells keep the dash: only the heading changed voice.
      expect(find.text(launchMissingFigure), findsWidgets);
    });

    testWidgets('the pending formula is labelled without naming its version', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      // S344 review: the status chip left the card; the (i) says it.
      expect(
        find.byKey(const ValueKey<String>('mining-summary-hero-stamp')),
        findsNothing,
      );
      // The version says nothing a reader can act on and stays off the page.
      expect(find.textContaining('MININGFORMULAV1-DRAFT'), findsNothing);
      expect(find.textContaining('miningFormulaV1-draft'), findsNothing);
      // The (i) says the status.
      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('pending approval'), findsWidgets);
    });

    // Decision 0243: the version is in the header (i), not on the page.
    testWidgets('the pending formula version stays inside the (i)', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-formula')),
        findsNothing,
      );
      expect(find.textContaining('miningFormulaV1-draft'), findsNothing);

      await _openMiningInfo(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('mining-info-formula')),
          matching: find.textContaining(
            'Formula version pending approval miningFormulaV1-draft',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Not loaded doesn\'t mean "zero power"'),
        findsOneWidget,
      );
    });

    testWidgets('one missing baseline is explained once, not per metric', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        overrides: <Override>[s7TokenLive()],
      );

      // S315 (需求方 2026-10-27): the dashes carry no sentence under the
      // hero. Each reason is the cell's spoken label, not printed copy.
      expect(
        find.byKey(const ValueKey<String>('mining-hero-dash-reasons')),
        findsNothing,
      );
      expect(find.text('待领取：奖励发放还没有开启，暂时不能领取。'), findsNothing);
      expect(
        find.textContaining("The mining formula isn't approved yet"),
        findsNothing,
      );
      // S350b · decision 0275: a dash cell is not drawn at all.
      expect(find.bySemanticsLabel(RegExp('^待领取，')), findsNothing);
    });

    testWidgets('a shared reason names the dashes it speaks for', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
        overrides: <Override>[s7TokenLive()],
      );

      // S315: the two dashes beside a settled 今日预估 carry no printed
      // reason line; each is spoken on its own cell.
      expect(
        find.byKey(const ValueKey<String>('mining-hero-dash-reasons')),
        findsNothing,
      );
      expect(find.textContaining('累计已挖、待领取：'), findsNothing);
      // S350b · decision 0275: the two dashes are not drawn at all.
      expect(find.bySemanticsLabel(RegExp('^累计已挖，')), findsNothing);
    });

    testWidgets('a settled page states the boost alone, not a whole outage', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
      );

      // The boost is a card of its own now; a version is in effect and 我的算力
      // prints 1000 on this same page, so nothing here may claim that power,
      // output and rank are all unavailable.
      // Decision 0272: the boost is the 邀请 tab's, not a row of its own.
      expect(
        find.byKey(const ValueKey<String>('mining-open-referral')),
        findsNothing,
      );
      expect(find.text('五级邀请加成'), findsNothing);
      expect(find.textContaining('你的邀请加成在邀请中心查看'), findsNothing);
      expect(find.textContaining('当前加成 $launchMissingFigure'), findsNothing);
      expect(find.textContaining('算力、产量、排行与邀请加成都暂时不可用'), findsNothing);
    });

    testWidgets('a settled figure prints with its baseline label', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
        overrides: <Override>[s7TokenLive()],
      );

      // The number is the server's: the only display transform is a grouping
      // that can be removed to give the string back character for character.
      // It never appears without the label that says which kind of number it
      // is.
      expect(find.textContaining('1,000'), findsWidgets);
      // A placeholder budget is never a bare 1000000 on the screen.
      expect(find.text('1000000'), findsNothing);
      // The version is an identifier: it stays off the page.
      expect(find.textContaining('miningFormula-devBaseline'), findsNothing);
      // S344 review: the scope label is the (i)'s, not a chip on the card.
      await tester.tap(
        find.byKey(const ValueKey<String>('mining-rules-action')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(miningBaselineLabel), findsWidgets);
    });

    testWidgets('what a baseline means is in the source line ⓘ', (
      tester,
    ) async {
      // Decision 0121 (coordinator ruling 2026-10-09).
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
      );
      expect(find.textContaining('开发'), findsNothing);
      expect(find.text(miningBaselineDetail), findsNothing);
      // S325 · decision 0255: opened from the page's one (i).
      await openPageInfo(tester);
      expect(find.textContaining(miningBaselineDetail), findsOneWidget);
      // Decision 0146 / 0183: the drawer states the quantity basis, no price
      // (S325: 挖矿说明 and the snapshot source share one sheet, and both
      // name it).
      expect(find.textContaining('amount held × asset weight'), findsWidgets);
      expect(find.textContaining('参考价'), findsNothing);
    });

    testWidgets('POWER COMPOSITION writes quantity × weight (0146)', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[
                s7MiningAssetRow(holding: '10', power: '8'),
              ],
            ),
          ),
        ),
      );
      final row = find.byKey(
        ValueKey<String>('mining-assets-row-$s7CakeAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(row, findsOneWidget);
      expect(find.textContaining('10 × weight 0.8'), findsOneWidget);
      expect(find.textContaining(r'$2.26'), findsNothing);
    });

    testWidgets('the effective version stays inside the (i)', (tester) async {
      var rulesOpened = 0;
      await pumpS7Page(
        tester,
        MiningScreen(onOpenRules: () => rulesOpened += 1),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
        ),
      );

      expect(find.textContaining(s7BaselineVersion), findsNothing);
      expect(find.text('No local estimates'), findsNothing);
      await _openMiningInfo(tester);
      expect(find.textContaining(s7BaselineVersion), findsOneWidget);
      expect(find.text('No local estimates'), findsOneWidget);
      expect(
        find.textContaining(
          'Every number on this page comes from the latest power snapshot',
        ),
        findsOneWidget,
      );

      // The (i) still leads on to 挖矿规则.
      await tester.tap(
        find.byKey(const ValueKey<String>('mining-info-open-rules')),
      );
      await tester.pumpAndSettle();
      expect(rulesOpened, 1);
      expect(
        find.byKey(const ValueKey<String>('mining-info-sheet')),
        findsNothing,
      );
    });

    testWidgets('a baseline zero says why it is zero, not that it is missing', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureValue('0'),
              networkPower: const MiningFigureValue('0'),
              estimatedToday: const MiningDailyOutputUnavailable(
                'MINING_NETWORK_POWER_ZERO',
              ),
              formula: MiningFormulaEffective(
                configVersion: s7BaselineVersion,
                effectiveAt: DateTime.utc(2026, 9, 15, 14, 57, 37),
                scope: MiningFormulaScope.developmentBaseline,
              ),
            ),
          ),
        ),
        overrides: <Override>[s7TokenLive()],
      );

      // A settled zero is a reading, not an absence: it keeps the figure and
      // says which rule produced it.
      expect(find.textContaining('0'), findsWidgets);
      // S315: the reason a dash stands is spoken, not printed.
      expect(find.textContaining('全网算力为 0'), findsNothing);
      // 我的算力 is the settled heading, not one of the em-dash cells.
      final heading = find.byKey(
        const ValueKey<String>('mining-summary-hero-power'),
      );
      expect(tester.widget<Text>(heading).textSpan!.toPlainText(), '0 H');
    });

    testWidgets('the snapshot is absent, not zero', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.textContaining('No power snapshot has been taken yet'),
        findsNothing,
      );
      await _openMiningInfo(tester);
      // The one code that means "there is none" says so.
      expect(
        _infoSnapshotText(tester),
        contains('No power snapshot has been taken yet'),
      );
    });

    testWidgets('a repository that did not answer is not an absence of '
        'settlements', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              snapshot: const MiningSnapshotUnavailable(
                'MINING_RUNTIME_UNAVAILABLE',
              ),
            ),
          ),
        ),
      );

      await _openMiningInfo(tester);
      final text = _infoSnapshotText(tester);
      expect(text, contains('Power snapshot can\'t be loaded right now'));
      expect(text, isNot(contains('No power snapshot has been taken yet')));
      expect(
        text,
        contains(launchReasonCodeText('MINING_RUNTIME_UNAVAILABLE')),
      );
    });

    testWidgets('the capability gate stops the read', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(),
        meta: s7MetaSnapshot(mining: LoopV2CapabilityAvailability.unavailable),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-capability-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('offline and error stay distinct', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(failure: LaunchFailureKind.offline),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-state-offline')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('mining-state-error')),
        findsOneWidget,
      );
    });
  });

  group('mining-assets', () {});

  group('mining-rank', () {});

  group('mining-community', () {
    testWidgets('a reviewed weight is shown, a pending one is not', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-community-weight-pending')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('mining-community-weight-pending'),
          ),
          matching: find.byType(LoopInlineUnavailable),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('mining weight is still in review'),
        findsOneWidget,
      );
      expect(_figures(tester), isEmpty);
    });

    testWidgets('a community with nothing bound has no review to wait for', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningUnboundCommunity(),
          ),
        ),
      );

      // Nobody is reviewing this community's weight, because it has none to
      // review. Saying 审核中 would promise a review that is not happening.
      expect(
        find.byKey(
          const ValueKey<String>('mining-community-weight-not-applicable'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('mining-community-weight-not-applicable'),
          ),
          matching: find.byType(LoopInlineUnavailable),
          matchRoot: true,
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-community-weight-pending')),
        findsNothing,
      );
      expect(find.text('No weight to review'), findsOneWidget);
      expect(
        find.textContaining('mining weight is still in review'),
        findsNothing,
      );
      expect(find.textContaining("hasn't linked a token yet"), findsWidgets);
    });

    testWidgets('an approved weight renders the server value verbatim', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningCommunity(
              weight: MiningCommunityWeightApproved(
                value: '0.35',
                configVersion: 'communityWeightV1',
                reviewedAt: DateTime.utc(2026, 9, 7),
              ),
            ),
          ),
        ),
      );

      expect(find.text('0.35'), findsOneWidget);
      expect(find.textContaining('communityWeightV1'), findsNothing);
    });

    testWidgets('a settled panel prints its four figures and its settlement', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(),
          ),
        ),
      );

      final metrics = find.byKey(
        const ValueKey<String>('mining-community-metrics'),
      );
      await scrollToS7Section(tester, metrics);
      expect(metrics, findsOneWidget);
      // A settled zero keeps its figure: it is a reading, not an absence.
      expect(find.text('0'), findsWidgets);
      // The weight is why this community has a power at all, and it is on the
      // Chalk contribution card as well as in the stamp.
      expect(find.textContaining('0.8'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('mining-community-contribution')),
        findsOneWidget,
      );
      // A place the settlement did not give keeps the em dash in the strip.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('mining-community-reading')),
          matching: find.textContaining(launchMissingFigure),
        ),
        findsWidgets,
      );
      final snapshot = find.byKey(
        const ValueKey<String>('mining-community-snapshot'),
      );
      await scrollToS7Section(tester, snapshot);
      expect(find.textContaining('Block 122,037,728'), findsOneWidget);
    });

    testWidgets('a ranked community says its place, not a bare number', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(
              rank: const MiningRankPositionSettled(
                position: 7,
                power: '38200',
              ),
              participants: const MiningParticipantsCount(42),
            ),
          ),
        ),
      );

      // The place and the head count are the composite strip's two readings.
      final reading = find.byKey(
        const ValueKey<String>('mining-community-reading'),
      );
      expect(
        find.descendant(of: reading, matching: find.textContaining('Rank #7')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: reading, matching: find.textContaining('42')),
        findsOneWidget,
      );
    });

    testWidgets('the formula version stays inside the 详情', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(),
          ),
        ),
      );

      expect(find.textContaining(s7BaselineVersion), findsNothing);
      final details = find.byKey(
        const ValueKey<String>('mining-community-weight-details'),
      );
      await scrollToS7Section(tester, details);
      await tester.tap(
        find.descendant(
          of: details,
          matching: find.byKey(
            const ValueKey<String>('loop-disclosure-summary'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(s7BaselineVersion), findsOneWidget);
    });

    testWidgets('the loading frame states no cause it has not been told', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(pending: true),
        ),
        settle: false,
      );

      for (final code in _reasonCodesOnTheWire) {
        expect(
          find.textContaining(launchReasonCodeText(code)),
          findsNothing,
          reason: code,
        );
      }
      expect(find.textContaining('Mining formula'), findsNothing);
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text(launchMissingHeading), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a community with no power carries its own reason, not the '
        'formula', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningCommunity(
              communityPower: const MiningFigureUnavailable(
                'COMMUNITY_ASSET_NOT_BOUND',
              ),
            ),
          ),
        ),
      );

      expect(
        _heroCaption(tester),
        launchReasonCodeText('COMMUNITY_ASSET_NOT_BOUND'),
      );
      expect(
        find.text(launchReasonCodeText('COMMUNITY_ASSET_NOT_BOUND')),
        findsOneWidget,
      );
    });

    testWidgets('a repository that did not answer is not an absence of '
        'settlements', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningCommunity(
              snapshot: const MiningSnapshotUnavailable(
                'MINING_RUNTIME_UNAVAILABLE',
              ),
            ),
          ),
        ),
      );

      final snapshot = find.byKey(
        const ValueKey<String>('mining-community-snapshot-unavailable'),
      );
      await scrollToS7Section(tester, snapshot);
      expect(
        find.text('Power snapshot can\'t be loaded right now'),
        findsOneWidget,
      );
      expect(find.text('No power snapshot has been taken yet'), findsNothing);
      expect(
        find.text(launchReasonCodeText('MINING_RUNTIME_UNAVAILABLE')),
        findsWidgets,
      );
    });

    testWidgets('a missing communityId fails closed', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-community-state-error')),
        findsOneWidget,
      );
    });
  });

  group('mining-rules', () {
    testWidgets('the draft is labelled 待批准 without its version', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      expect(find.text('Pending approval'), findsWidgets);
      expect(find.textContaining('MININGFORMULAV1-DRAFT'), findsNothing);
      expect(find.text('Power = holdings × weight'), findsWidgets);
      expect(
        find.text('Power = holdings × reference price × weight'),
        findsNothing,
      );
      expect(
        find.textContaining('Daily output = my power ÷ network power'),
        findsOneWidget,
      );
    });

    testWidgets('weight bands carry a key and a state, never a range', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      final loop = find.byKey(
        const ValueKey<String>(
          'mining-rules-pending-miningFormulaV1-draft-weight-loop',
        ),
      );
      await scrollToS7Section(tester, loop);
      expect(loop, findsOneWidget);
      // The prototype's 1.0× and 0.1×–1.0× bands are gone.
      expect(find.textContaining('1.0×'), findsNothing);
      expect(find.textContaining('0.1×'), findsNothing);
    });

    testWidgets('deprecated price guards are parsed but not shown', (
      tester,
    ) async {
      // Decision 0147 (loop-api 0125): power is holding × weight, so the
      // still-published `priceGuardRules` is no part of the formula.
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      expect(find.text('Reference Price Guard'), findsNothing);
      for (final key in <String>[
        'mining.rules.priceGuard.twap',
        'mining.rules.priceGuard.multiPeriodMultiSource',
        'mining.rules.priceGuard.liquidityCap',
      ]) {
        expect(
          find.byKey(
            ValueKey<String>(
              'mining-rules-pending-miningFormulaV1-draft-guard-$key',
            ),
          ),
          findsNothing,
          reason: key,
        );
        expect(find.text(miningRuleKeyText(key)), findsNothing, reason: key);
      }
    });

    testWidgets('no approved version renders the baseline reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('launch-unavailable-reason-$s7FormulaPending'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining("The mining formula isn't approved yet"),
        findsWidgets,
      );
    });

    testWidgets('a weighted asset is headed by its symbol when one is read', (
      tester,
    ) async {
      // 「资产权重」 headed three of four rows with a contract address and
      // repeated the whole CAIP id underneath. The rule keys are asset ids,
      // and 算力明细 carries a symbol for the same ids.
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
          assets: S7Answer<MiningAssets>(value: s7MiningSettledAssets()),
        ),
      );

      final row = find.byKey(
        ValueKey<String>('mining-rules-approved-asset-weight-$s7UsdtAssetId'),
      );
      await scrollToS7Section(tester, row);
      expect(tester.widget<LoopRecordRow>(row).title, 'USDT');
      // The id it stands for stays on the row; it is no longer the heading.
      expect(tester.widget<LoopRecordRow>(row).subtitle, s7UsdtAssetId);
    });

    testWidgets('before the LOOP token the budget is not printed (0184)', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
        ),
        overrides: <Override>[
          miningRewardsGatewayProvider.overrideWithValue(
            S7TokenStageRewards.preToken(),
          ),
        ],
      );
      final output = find.byKey(
        const ValueKey<String>('mining-rules-approved-daily-output'),
      );
      await scrollToS7Section(tester, output);
      expect(tester.widget<LoopRecordRow>(output).trailing, isNull);
      expect(
        tester.widget<LoopRecordRow>(output).trailingCaption,
        'Published after the LOOP token launches',
      );
      expect(find.text('1,000,000'), findsNothing);
      expect(find.text('Estimated output'), findsNothing);
    });

    testWidgets('the development baseline prints its weights and its budget', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
        ),
        overrides: <Override>[s7TokenLive()],
      );

      // The version in force is said the way every other mining page says it.
      final formula = find.byKey(const ValueKey<String>('mining-formula'));
      await scrollToS7Section(tester, formula);
      expect(formula, findsOneWidget);
      expect(find.text(miningBaselineLabel), findsWidgets);

      // Every weighed asset, with the version's own figure.
      for (final assetId in <String>[
        s7NativeAssetId,
        s7CakeAssetId,
        s7UsdtAssetId,
        s7WbnbAssetId,
      ]) {
        final row = find.byKey(
          ValueKey<String>('mining-rules-approved-asset-weight-$assetId'),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: assetId);
      }

      // The pinned band prints its bounds; the placeholder budget prints with
      // the word that says it is a placeholder.
      final community = find.byKey(
        const ValueKey<String>('mining-rules-approved-weight-community'),
      );
      await scrollToS7Section(tester, community);
      expect(find.text('0.5–2'), findsOneWidget);
      final output = find.byKey(
        const ValueKey<String>('mining-rules-approved-daily-output'),
      );
      await scrollToS7Section(tester, output);
      expect(find.text('1,000,000'), findsOneWidget);
      expect(find.text('Estimated output'), findsOneWidget);

      final notice = find.byKey(
        const ValueKey<String>('mining-rules-baseline-notice'),
      );
      await scrollToS7Section(tester, notice);
      expect(notice, findsOneWidget);

      // The draft is still listed, and still 待批准.
      final draft = find.byKey(
        const ValueKey<String>(
          'mining-rules-pending-miningFormulaV1-draft-rows',
        ),
      );
      await scrollToS7Section(tester, draft);
      expect(draft, findsOneWidget);
    });

    testWidgets('a draft version prints no weight, budget or range', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      final draftPrefix = 'mining-rules-pending-miningFormulaV1-draft';
      expect(
        find.byKey(ValueKey<String>('$draftPrefix-asset-weights')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-rules-baseline-notice')),
        findsNothing,
      );
      final community = find.byKey(
        ValueKey<String>('$draftPrefix-weight-community'),
      );
      await scrollToS7Section(tester, community);
      expect(find.text('1000000'), findsNothing);
      expect(find.text(miningBaselineLabel), findsNothing);
    });

    testWidgets('an approved version silences the "no numbers" sentence', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
        ),
      );

      // The page above it prints 0.5–2 and a placeholder budget.
      expect(
        find.byKey(const ValueKey<String>('mining-rules-notice')),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Weight ranges list rule items only, with no values',
        ),
        findsNothing,
      );
    });

    testWidgets('the hero follows whether a version has been approved', (
      tester,
    ) async {
      // Approved and in force: the page's first section is 「已批准的版本」
      // with an 已批准 badge, and the hero no longer contradicts it.
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
        ),
      );
      expect(find.textContaining('还没批准的草案'), findsNothing);
      expect(
        find.text(
          'This version is approved and in effect. A draft pending approval is below.',
        ),
        findsOneWidget,
      );

      // Nothing approved yet: the draft is what the hero is showing, and it
      // says so.
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );
      expect(
        find.text(
          'No approved formula yet. The one below is a draft pending approval.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with nothing in force the sentence still stands', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      final notice = find.byKey(const ValueKey<String>('mining-rules-notice'));
      await scrollToS7Section(tester, notice);
      expect(notice, findsOneWidget);
      expect(
        find.textContaining(
          'Weight ranges list rule items only, with no values',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the referral ladder comes from the server, verbatim', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(),
      );

      for (var level = 1; level <= 5; level += 1) {
        final row = find.byKey(
          ValueKey<String>('mining-rules-referral-l$level'),
        );
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: 'L$level');
      }
      expect(find.textContaining('referralRulesV1'), findsNothing);
    });
  });

  // Decision 0057. A run that could not value a held asset is never
  // published, so the pages keep the last complete snapshot's numbers — and
  // have to say that the moment they are printing is no longer the newest.
  group('a snapshot a later run has overtaken', () {
    /// What every stale page prints, with the asset named as the composition
    /// page names it.
    final staleLine = miningStaleLine(
      attempt: s7MiningUnreadAttempt(),
      symbols: const <String, String>{s7UsdtAssetId: 'USDT'},
    );

    test(
      'the line names what stopped the next run, undated (decision 0302)',
      () {
        expect(
          staleLine,
          "Showing the last complete power snapshot · The latest snapshot didn't finish (USDT has no available quote right now)",
        );
        // Without the composition page's symbols the asset is still named by
        // the id it stands for, never by a guess.
        expect(
          miningStaleLine(attempt: s7MiningUnreadAttempt()),
          contains('0x55d3…7955 has no available quote right now'),
        );
        // A run an operator withdrew is not a run that did not finish.
        expect(
          miningStaleLine(
            attempt: s7MiningUnreadAttempt(
              status: 'invalidated',
              reasonCode: 'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE',
              unreadInputs: const <MiningUnreadInput>[],
            ),
          ),
          "Showing the last complete power snapshot · The latest snapshot was invalidated (That snapshot's data was incomplete)",
        );
        // No internal word reaches the reader.
        for (final line in <String>[
          staleLine,
          miningSnapshotAbsenceReason(
            'MINING_SNAPSHOT_INCOMPLETE',
            attempt: s7MiningUnreadAttempt(),
          ),
        ]) {
          for (final internal in <String>[
            'incomplete',
            'latestAttempt',
            'unreadInputs',
            'MINING_',
            'stale',
          ]) {
            expect(line.contains(internal), isFalse, reason: internal);
          }
        }
      },
    );

    testWidgets('the summary dates its figures and keeps them', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureValue('4482.309'),
              networkPower: const MiningFigureValue('4482.309'),
              formula: s7EffectiveFormula(),
              snapshot: s7MiningStaleSnapshot(),
            ),
          ),
        ),
      );

      // S315: the hero marks the figure 未更新 (S378 · decision 0302: without
      // dating it); the run that did not finish is in the source (i)'s sheet.
      expect(
        find.byKey(const ValueKey<String>('mining-stale-summary')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('mining-summary-hero-caption')),
            )
            .data,
        'Not updated',
      );
      // Reading nothing was never published as a zero: the figure the last
      // complete snapshot settled is still on the page.
      expect(find.textContaining('4,482'), findsWidgets);
      expect(find.textContaining('4482.309'), findsNothing);
      // S325 · decision 0255: opened from the page's one (i).
      await openPageInfo(tester);
      expect(
        find.textContaining('The latest snapshot didn\'t finish'),
        findsWidgets,
      );
    });

    testWidgets('a snapshot nothing overtook prints no line', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureValue('4.482309'),
              formula: s7EffectiveFormula(),
              snapshot: s7MiningSnapshot(),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-stale-summary')),
        findsNothing,
      );
      expect(
        find.textContaining('The latest snapshot didn\'t finish'),
        findsNothing,
      );
    });

    testWidgets('no complete snapshot is a different sentence from none at '
        'all', (tester) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureUnavailable(
                'MINING_SNAPSHOT_INCOMPLETE',
              ),
              networkPower: const MiningFigureUnavailable(
                'MINING_SNAPSHOT_INCOMPLETE',
              ),
              formula: s7EffectiveFormula(),
              snapshot: MiningSnapshotUnavailable(
                'MINING_SNAPSHOT_INCOMPLETE',
                latestAttempt: s7MiningUnreadAttempt(),
              ),
            ),
          ),
        ),
      );

      // The figures are absent, never zero.
      expect(find.text('0'), findsNothing);
      expect(find.text(launchMissingFigure), findsWidgets);
      await _openMiningInfo(tester);
      final text = _infoSnapshotText(tester);
      expect(text, contains('No complete power snapshot yet'));
      expect(text, isNot(contains('No power snapshot has been taken yet')));
      expect(text, contains("there's no complete snapshot to fall back on"));
    });

    testWidgets('a wallet no snapshot includes yet is told what happens next', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(
            value: s7MiningSummary(
              power: const MiningFigureUnavailable('MINING_SNAPSHOT_PENDING'),
              networkPower: const MiningFigureValue('4.482309'),
              formula: s7EffectiveFormula(),
              snapshot: s7MiningSnapshot(),
            ),
          ),
        ),
      );

      // S315: the hero states the absence in words and dates the snapshot;
      // what happens next is not a sentence on the page.
      final heading = find.byKey(
        const ValueKey<String>('mining-summary-hero-power'),
      );
      expect(
        tester.widget<Text>(heading).textSpan!.toPlainText(),
        launchMissingHeading,
      );
      expect(find.text('0'), findsNothing);
    });
  });

  group('wallet power hint · decision 0184', () {
    Future<void> pumpHint(WidgetTester tester, Override rewards) => pumpS7Page(
      tester,
      WalletHoldingsPowerHint(onOpenMining: () {}),
      mining: FakeMiningGateway(
        summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
      ),
      overrides: <Override>[rewards],
    );

    testWidgets('before the token the strip states power only', (tester) async {
      await pumpHint(
        tester,
        miningRewardsGatewayProvider.overrideWithValue(
          S7TokenStageRewards.preToken(),
        ),
      );
      final hint = tester.widget<LoopPowerHint>(
        find.byKey(const ValueKey<String>('wallet-power-hint')),
      );
      expect(hint.figure, startsWith('1,000 power'));
      expect(hint.figure, isNot(contains('Est. today')));
      expect(hint.figure, isNot(contains('LOOP')));
    });

    testWidgets('once the token is live it adds today\'s estimate', (
      tester,
    ) async {
      await pumpHint(tester, s7TokenLive());
      final hint = tester.widget<LoopPowerHint>(
        find.byKey(const ValueKey<String>('wallet-power-hint')),
      );
      expect(hint.figure, contains('Est. today'));
      expect(hint.figure, contains('LOOP'));
    });
  });
}

/// Decision 0243: 我的挖矿's formula version, snapshot and no-estimate rule
/// are behind the header (i).
Future<void> _openMiningInfo(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('mining-rules-action')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey<String>('mining-info-sheet')),
    findsOneWidget,
  );
}

String _infoSnapshotText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('mining-info-snapshot')),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .join('\n');
