// S355b · decision 0281: the Launch (IDO), Square and DApp copy in both
// languages, and the places where copy used to be data.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/launch/launch_chain_models.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

import 'support/s83c_fixtures.dart';

final DateTime _now = DateTime.utc(2026, 11, 4, 12);

SquareFeedPost _claim(Map<String, String> event, {String? symbol}) =>
    SquareFeedPost(
      postId: '00000000-0000-4000-8000-000000000001',
      kind: SquareFeedPostKind.claim,
      author: null,
      text: null,
      token: symbol == null
          ? null
          : SquareFeedToken(
              kind: SquareFeedTokenKind.meme,
              memeTokenId: '00000000-0000-4000-8000-000000000002',
              symbol: symbol,
              priceUsd1: Decimal.one,
              change1hPct: null,
              marketCapUsd1: null,
            ),
      event: event,
      likeCount: 0,
      likedByViewer: false,
      pinned: false,
      createdAt: _now,
    );

void main() {
  tearDown(LoopL10n.debugReset);

  group('square · the feed age past 30 days', () {
    // Midday UTC keeps the calendar day in every test-machine time zone.
    final createdAt = DateTime.utc(2026, 9, 25, 12);

    test('English reads MMM d', () {
      expect(squareFeedAgeLabel(createdAt, now: _now), 'Sep 25');
      expect(
        squareFeedAgeLabel(DateTime.utc(2026, 1, 3, 12), now: _now),
        'Jan 3',
      );
    });

    test('Chinese keeps 「M 月 D 日」', () {
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(squareFeedAgeLabel(createdAt, now: _now), '9 月 25 日');
    });

    test('the compact ages stay Latin in both languages', () {
      final age = _now.subtract(const Duration(minutes: 12));
      expect(squareFeedAgeLabel(age, now: _now), '12m');
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(squareFeedAgeLabel(age, now: _now), '12m');
      expect(squareFeedAgeLabel(_now, now: _now), '刚刚');
    });
  });

  group('square · a claim sentence is built from facts, not copy', () {
    const facts = <String, String>{
      'amountUsd1': '10.94',
      'roundId': '2',
      'weightPct': '50',
    };

    test('English puts the claim first', () {
      expect(
        squareFeedPostSentence(_claim(facts, symbol: 'MOON')),
        'Claimed 10.94 USD1 in MOON round 2, weight 50%.',
      );
      expect(
        squareFeedPostSentence(
          _claim(const <String, String>{'amountUsd1': '3'}, symbol: 'MOON'),
        ),
        'Claimed 3 USD1 in MOON.',
      );
    });

    test('Chinese keeps 「第 N 轮领到」 joined and a ticker spaced', () {
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(
        squareFeedPostSentence(_claim(facts, symbol: 'MOON')),
        '在 MOON 第 2 轮领到 10.94 USD1，权重 50%。',
      );
      expect(
        squareFeedPostSentence(
          _claim(const <String, String>{'amountUsd1': '3'}, symbol: 'MOON'),
        ),
        '在 MOON 领到 3 USD1。',
      );
    });
  });

  test('square · the operator\'s 算力社区 mark is matched in any language', () {
    expect(squareIsMiningLabel('算力社区'), isTrue);
    expect(squareIsMiningLabel('Power community'), isFalse);
    LoopL10n.use(LoopL10n.simplifiedChinese);
    expect(squareIsMiningLabel('算力社区'), isTrue);
  });

  group('launch', () {
    test('the END badge is pending from the state, not its word', () {
      expect(launchTrackEndPending(null), isTrue);
      expect(launchTrackEndBadge(null), 'Pending');
      final vesting = s83cOnChain(entitlement: LaunchEntitlementState.vesting);
      expect(launchTrackEndPending(vesting), isFalse);
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(launchTrackEndPending(null), isTrue);
      expect(launchTrackEndBadge(null), '待触发');
    });

    test('durations count in English and keep their units in Chinese', () {
      expect(launchDurationLabel(86400), '1 day');
      expect(launchDurationLabel(86400 * 90), '90 days');
      expect(launchDurationLabel(3600 * 2), '2 hours');
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(launchDurationLabel(86400 * 90), '90 天');
    });

    test('a settlement sentence swaps the purchase noun in both languages', () {
      expect(launchIntentNoun(LaunchIntentKind.claim), 'claim');
      expect(
        launchSignReasonTextFor(LaunchIntentKind.claim, 'INTENT_EXPIRED'),
        contains('this claim'),
      );
      expect(launchIntentActionLabel(LaunchIntentKind.buy), 'Buy');
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(launchIntentNoun(LaunchIntentKind.claim), '领取');
      expect(launchIntentActionLabel(LaunchIntentKind.buy), '认购');
    });

    test('the axis and sale-config keys are stable ids, not copy', () {
      expect(launchAxisIds, hasLength(launchAxisLabels.length));
      expect(launchSaleConfigIds, hasLength(s83cSaleConfig().entries.length));
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(launchAxisLabels.first, '销售状态');
      expect(launchAxisIds.first, 'sale');
    });
  });

  test('dapp · a risk flag names itself in the reader\'s language', () {
    expect(DappRiskFlag.unlimitedApproval.label, 'Unlimited approval');
    LoopL10n.use(LoopL10n.simplifiedChinese);
    expect(DappRiskFlag.unlimitedApproval.label, '无限授权');
  });
}
