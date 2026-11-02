import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_round_key.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart' show FakeMarketReadGateway, S5Answer;

/// S336 · decision 0265: the community record carries no standing
/// explanation — the voice key says why on tap, the bound token without a
/// quote is its name, the power is a figure, 退出社区 is one line.
void main() {
  const notLive = '该社区当前没有进行中的语音房。';
  final voiceKey = find.byKey(
    const ValueKey<String>('community-profile-open-voice'),
  );

  Future<void> pumpProfile(
    WidgetTester tester, {
    CommunityRole role = CommunityRole.member,
    CommunityVoiceSection voice = testVoiceUnavailable,
    ValueChanged<String>? onOpenVoiceRoom,
    CommunitySummary? community,
    LoopMiningPowerFact? miningPower,
    List<Override> overrides = const <Override>[],
  }) => pumpCommunityPage(
    tester,
    CommunityProfileScreen(
      communityId: testCommunityId,
      onOpenVoiceRoom: onOpenVoiceRoom,
    ),
    community: FakeCommunityGateway(
      detail: testDetail(
        community: community,
        viewer: testViewer(role: role),
        voice: voice,
        miningPower: miningPower,
      ),
    ),
    overrides: overrides,
  );

  group('语音房 key', () {
    testWidgets('no live room: no standing line, the tap says it once', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpProfile(tester, onOpenVoiceRoom: opened.add);
      await scrollToCommunitySection(tester, voiceKey);

      expect(find.text(notLive), findsNothing);
      expect(find.textContaining('没有进行中的语音房'), findsNothing);
      final key = tester.widget<LoopRoundKey>(voiceKey);
      expect(key.label, '语音房');
      expect(key.onPressed, isNull);
      expect(key.onBlocked, isNotNull);

      await tester.tap(voiceKey);
      await tester.pump();
      expect(find.text(notLive), findsOneWidget);
      expect(opened, isEmpty);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('no channel: the 进群聊 key says so on tap, nothing stands '
        'under the row', (tester) async {
      const noChannel = '该社区还没有官方群频道。';
      final chatKey = find.byKey(
        const ValueKey<String>('community-profile-open-chat'),
      );
      await pumpProfile(tester);
      await scrollToCommunitySection(tester, chatKey);

      expect(
        find.byKey(const ValueKey<String>('community-profile-action-reasons')),
        findsNothing,
      );
      expect(find.text(noChannel), findsNothing);
      final key = tester.widget<LoopRoundKey>(chatKey);
      expect(key.onPressed, isNull);
      expect(key.onBlocked, isNotNull);

      await tester.tap(chatKey);
      await tester.pump();
      expect(find.text(noChannel), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a live room is still entered on tap', (tester) async {
      final opened = <String>[];
      await pumpProfile(
        tester,
        voice: testVoiceLive,
        onOpenVoiceRoom: opened.add,
      );
      await scrollToCommunitySection(tester, voiceKey);
      expect(tester.widget<LoopRoundKey>(voiceKey).onPressed, isNotNull);
      await tester.tap(voiceKey);
      await tester.pump();
      expect(opened, <String>[testCommunityId]);
      expect(find.text(notLive), findsNothing);
    });
  });

  group('绑定代币 row', () {
    final row = find.byKey(const ValueKey<String>('community-bound-asset'));
    final community = testCommunity(boundAssetKey: s5WbnbAssetId);

    Future<void> pumpQuoted(
      WidgetTester tester,
      FakeMarketReadGateway market,
    ) => pumpProfile(
      tester,
      community: community,
      overrides: <Override>[
        marketReadGatewayProvider.overrideWithValue(market),
      ],
    );

    testWidgets('without a quote: the token name, no price, no pill', (
      tester,
    ) async {
      await pumpQuoted(
        tester,
        FakeMarketReadGateway(
          asset: S5Answer(
            value: s5Detail(
              price: const LoopFact.unavailable('MARKET_PRICE_UNAVAILABLE'),
              priceChange24h: const LoopFact.unavailable(
                'MARKET_FACT_NOT_REPORTED',
              ),
            ),
          ),
        ),
      );
      await scrollToCommunitySection(tester, row);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: row, matching: find.text('Wrapped BNB')),
        findsOneWidget,
      );
      for (final text in <String>['行情读取中', '暂无价格', '未报告', '24h']) {
        expect(
          find.descendant(of: row, matching: find.text(text)),
          findsNothing,
          reason: text,
        );
      }
      expect(
        find.descendant(of: row, matching: find.textContaining(r'$')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey<String>('loop-change-pill')),
        ),
        findsNothing,
      );
    });

    testWidgets('with a quote: the price, 24h and the change pill', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenToken: opened.add,
        ),
        community: FakeCommunityGateway(
          detail: testDetail(community: community),
        ),
        overrides: <Override>[
          marketReadGatewayProvider.overrideWithValue(FakeMarketReadGateway()),
        ],
      );
      await scrollToCommunitySection(tester, row);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-bound-asset-price')),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text('24h')), findsOne);
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey<String>('loop-change-pill')),
        ),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pump();
      expect(opened, <String>[s5WbnbAssetId]);
    });
  });

  testWidgets('社区总算力 is the figure alone; 退出社区 has no 身份 line', (tester) async {
    await pumpProfile(tester, miningPower: testSettledCommunityMiningPower());
    final power = find.byKey(const ValueKey<String>('community-mining-power'));
    await scrollToCommunitySection(tester, power);
    expect(find.textContaining(miningBaselineLabel), findsNothing);

    final leave = find.byKey(const ValueKey<String>('community-leave-action'));
    await scrollToCommunitySection(tester, leave);
    expect(
      find.descendant(of: leave, matching: find.text('退出社区')),
      findsOneWidget,
    );
    expect(find.textContaining('我的身份'), findsNothing);
  });

  testWidgets('an owner\'s inert 退出社区 has no 身份 line either', (tester) async {
    await pumpProfile(tester, role: CommunityRole.owner);
    final row = find.byKey(
      const ValueKey<String>('community-owner-cannot-leave'),
    );
    await scrollToCommunitySection(tester, row);
    expect(find.textContaining('我的身份'), findsNothing);
  });
}
