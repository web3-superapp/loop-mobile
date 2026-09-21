import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// A first read may not be reported as an outage before it has failed.
///
/// Two pages opened on a working device were showing 「离线 · 显示缓存」 with a
/// 「重试连接」 button on their very first frame, and the manual retry always
/// worked: the read had failed once on a pooled socket the peer closed while
/// the app sat idle, which carries no server answer at all. The shared read
/// controllers now keep the loading phase through one silent re-attempt, and
/// only a read that fails again may claim the device is offline.
const _recommendation = CommunityRecommendation(
  recommendationId: '22222222-2222-4222-8222-222222222222',
  ruleVersion: 'rule:verified-members-v1',
);

CommunityHome _home() => CommunityHome(
  joined: const <JoinedCommunity>[],
  joinedTruncated: false,
  discover: <CommunitySummary>[testCommunity()],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 9, 8, 1),
  source: 'database',
  recommendation: _recommendation,
);

void main() {
  group('tx-history · first read', () {
    testWidgets('a request still in the air stays a skeleton', (tester) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(pending: true),
        ),
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('tx-history-state-loading')),
        findsOneWidget,
      );
      expect(find.byType(LoopOfflineState), findsNothing);
      expect(find.text('离线 · 显示缓存'), findsNothing);
      expect(find.text('重试连接'), findsNothing);
    });

    testWidgets('one dropped connection never becomes an outage', (
      tester,
    ) async {
      final gateway = FakeWalletReadGateway(
        activity: S5Answer<LoopWalletActivityPage>(
          value: s5Activity(),
          transientFailure: LoopChainFailureKind.offline,
        ),
      );
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: gateway,
      );

      expect(gateway.activity.resolves, 2);
      expect(find.byType(LoopOfflineState), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tx-history-state-offline')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('tx-history-folio')), findsOne);
    });

    testWidgets('a read that keeps failing does pause the page', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-history-state-offline')),
        findsOneWidget,
      );
    });
  });

  group('community-chat · first read', () {
    testWidgets('a request still in the air stays a skeleton', (tester) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(chat: testChatAvailable),
      )..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(find.byType(LoopOfflineState), findsNothing);
      expect(find.text('离线 · 显示缓存'), findsNothing);
      expect(find.text('重试连接'), findsNothing);
    });

    testWidgets('one dropped connection never becomes an outage', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(chat: testChatAvailable),
      )..transientFailure = CommunityFailureKind.offline;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      expect(gateway.reads, 2);
      expect(find.byType(LoopOfflineState), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
    });

    testWidgets('a read that keeps failing does pause the page', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(chat: testChatAvailable),
      )..failure = CommunityFailureKind.offline;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
    });
  });

  // The same dropped socket reaches the four community reads a demo opens
  // first. `unexpected` is included because Dio reports a connection the peer
  // closed mid-response as `unknown`, which never maps to `offline`.
  for (final kind in <CommunityFailureKind>[
    CommunityFailureKind.offline,
    CommunityFailureKind.unexpected,
  ]) {
    group('community reads · first read · ${kind.name}', () {
      testWidgets('the desk re-attempts once instead of pausing', (
        tester,
      ) async {
        final gateway = FakeCommunityGateway(home: _home())
          ..transientFailure = kind;
        await pumpCommunityPage(
          tester,
          const CommunityScreen(),
          community: gateway,
        );

        expect(gateway.reads, 2);
        expect(find.byType(LoopOfflineState), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
      });

      testWidgets('the community record re-attempts once', (tester) async {
        final gateway = FakeCommunityGateway(detail: testDetail())
          ..transientFailure = kind;
        await pumpCommunityPage(
          tester,
          const CommunityProfileScreen(communityId: testCommunityId),
          community: gateway,
        );

        expect(gateway.reads, 2);
        expect(find.byType(LoopOfflineState), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
      });

      testWidgets('the directory re-attempts once', (tester) async {
        final gateway = FakeCommunityGateway(
          directoryPage: CommunityDirectoryPage(
            ordering: const CommunityOrderingApplied(
              sort: CommunityDirectorySort.members,
              basis: CommunityStoredBasis(),
            ),

            items: <CommunitySummary>[testCommunity()],
            nextCursor: null,
            recommendation: _recommendation,
          ),
        )..transientFailure = kind;
        await pumpCommunityPage(
          tester,
          const CommunityDiscoverScreen(),
          community: gateway,
        );

        expect(gateway.reads, 2);
        expect(find.byType(LoopOfflineState), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
      });

      testWidgets('the member directory re-attempts once', (tester) async {
        final gateway = FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        )..transientFailure = kind;
        await pumpCommunityPage(
          tester,
          const CommunityMembersScreen(communityId: testCommunityId),
          community: gateway,
        );

        expect(gateway.reads, greaterThanOrEqualTo(2));
        expect(find.byType(LoopOfflineState), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
      });
    });
  }
}
