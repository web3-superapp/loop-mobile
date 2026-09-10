import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The referral page reads `GET /v2/referral`. It shows an invite code, counts
/// grouped by the server's validation state, and an unavailable boost — never
/// a commission, a payout or a downline income.
void main() {
  group('normalisation', () {
    test('the server-accepted variants all normalise to one code', () {
      for (final raw in <String>[
        'LOOP-7HJKM',
        'loop-7hjkm',
        '7hjkm',
        ' LOOP-7HJKM ',
      ]) {
        expect(normaliseReferralInviteCode(raw), 'LOOP-7HJKM', reason: raw);
        expect(isReferralInviteCodeShaped(raw), isTrue, reason: raw);
      }
    });

    test('Crockford substitutions are applied before the request', () {
      // I and L become 1; O becomes 0. The server does the same, so a typed
      // code is not rejected locally for a substitution it would accept.
      expect(normaliseReferralInviteCode('loop-7hjko'), 'LOOP-7HJK0');
      expect(normaliseReferralInviteCode('loop-7hjkl'), 'LOOP-7HJK1');
    });

    test('an obviously malformed code is refused before the request', () {
      for (final raw in <String>['', 'LOOP-', 'LOOP-123', 'LOOP-1234567']) {
        expect(isReferralInviteCodeShaped(raw), isFalse, reason: raw);
      }
    });
  });

  group('referral · the page', () {
    testWidgets('loading shows a skeleton and no count', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('有效关系'), findsNothing);
    });

    testWidgets('the invite code is shown and can be copied', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );

      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      final copy = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('referral-copy-code')),
      );
      expect(copy.onPressed, isNotNull);
    });

    testWidgets('each level is counted by the server validation state', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );

      for (var level = 1; level <= 5; level += 1) {
        final row = find.byKey(ValueKey<String>('referral-level-$level'));
        await scrollToS7Section(tester, row);
        expect(row, findsOneWidget, reason: 'L$level');
      }
      // L1 has two pending-wallet and one pending-mining edge, zero valid.
      expect(find.textContaining('待绑定钱包 2'), findsOneWidget);
      expect(find.textContaining('待挖矿生效 1'), findsOneWidget);
      expect(find.textContaining('0 个有效关系'), findsOneWidget);
      expect(find.textContaining('3 个待验证'), findsOneWidget);
    });

    testWidgets('the boost stays unavailable with the formula reason', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );

      final boost = find.byKey(
        const ValueKey<String>('launch-unavailable-Mining Power 加成'),
      );
      await scrollToS7Section(tester, boost);
      expect(boost, findsOneWidget);
      expect(find.textContaining('挖矿公式还没有批准'), findsWidgets);
      // The prototype's final boost figure never returns.
      expect(find.textContaining('2,840'), findsNothing);
      expect(find.textContaining('182 位'), findsNothing);
    });

    testWidgets('the claim entry appears only while the window is open', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-claim')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: s7Referral(
              binding: ReferralBinding(
                isBound: false,
                inviter: null,
                claimWindow: ReferralClaimWindowTimed(
                  isOpen: false,
                  activatedAt: DateTime.utc(2026, 8, 20),
                  closesAt: DateTime.utc(2026, 8, 27),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-claim')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('referral-claim-closed')),
        findsOneWidget,
      );
    });

    testWidgets('an unactivated account has no window at all', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: s7Referral(
              binding: const ReferralBinding(
                isBound: false,
                inviter: null,
                claimWindow: ReferralClaimWindowUnavailable(
                  'PROFILE_ACTIVATION_REQUIRED',
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('referral-claim-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('需要先完成 LOOP ID 激活'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('referral-claim')),
        findsNothing,
      );
    });

    testWidgets('a bound account shows depth and state, never an identity', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: s7Referral(binding: s7BoundBinding()),
          ),
        ),
      );

      final bound = find.byKey(const ValueKey<String>('referral-bound-row'));
      await scrollToS7Section(tester, bound);
      expect(bound, findsOneWidget);
      expect(find.textContaining('深度 L1'), findsOneWidget);
      expect(find.textContaining('待挖矿生效'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('referral-claim')),
        findsNothing,
      );
    });

    testWidgets('the capability gate stops the read', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
        meta: s7MetaSnapshot(
          referral: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('referral-capability-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('offline and error stay distinct', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            failure: LaunchFailureKind.offline,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-state-offline')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            failure: LaunchFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('the page never uses commission language', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralScreen(),
        referral: FakeReferralGateway(),
      );

      // The words only ever appear inside the disclaimer that denies them.
      for (final forbidden in <String>['分红', '下线收入', '返利', '提现']) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final data = text.data;
        if (data == null) continue;
        if (data.contains('返佣') || data.contains('佣金')) {
          expect(data, contains('不是'), reason: data);
        }
      }
      expect(find.textContaining('不是收入、佣金或返佣'), findsWidgets);
    });
  });

  group('claim', () {
    testWidgets('a valid code reaches the gateway and the binding is shown', (
      tester,
    ) async {
      final gateway = FakeReferralGateway();
      await pumpS7Page(tester, const ReferralScreen(), referral: gateway);

      await _openClaim(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('referral-claim-input')),
        'loop-7hjkm',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('referral-claim-submit')),
      );
      await tester.pumpAndSettle();

      // Normalised before it left the device.
      expect(gateway.claims, <String>['LOOP-7HJKM']);
      expect(
        find.byKey(const ValueKey<String>('referral-claim-success')),
        findsOneWidget,
      );
    });

    testWidgets('a malformed code never spends the single attempt', (
      tester,
    ) async {
      final gateway = FakeReferralGateway();
      await pumpS7Page(tester, const ReferralScreen(), referral: gateway);

      await _openClaim(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('referral-claim-input')),
        'nope',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('referral-claim-submit')),
      );
      await tester.pumpAndSettle();

      expect(gateway.claims, isEmpty);
      expect(find.textContaining('邀请码格式不对'), findsOneWidget);
    });

    testWidgets('each refusal code gets its own next step', (tester) async {
      final cases = <LaunchFailureKind, String>{
        LaunchFailureKind.activationRequired: '需要先完成 LOOP ID 激活才能绑定邀请码',
        LaunchFailureKind.policyBlocked: '绑定窗口已经关闭',
        LaunchFailureKind.notFound: '这个邀请码不存在',
        LaunchFailureKind.validationFailed: '不能邀请自己',
        LaunchFailureKind.stale: '已经绑定过邀请人',
      };
      for (final entry in cases.entries) {
        final gateway = FakeReferralGateway(claimFailure: entry.key);
        await pumpS7Page(tester, const ReferralScreen(), referral: gateway);

        await _openClaim(tester);
        await tester.enterText(
          find.byKey(const ValueKey<String>('referral-claim-input')),
          'LOOP-7HJKM',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('referral-claim-submit')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('referral-claim-failure')),
          findsOneWidget,
          reason: entry.key.name,
        );
        expect(
          find.textContaining(entry.value),
          findsOneWidget,
          reason: entry.key.name,
        );
        // A refusal never blanks the invite code that did load.
        expect(find.text('LOOP-7HJKM'), findsWidgets, reason: entry.key.name);
        expect(
          find.byKey(const ValueKey<String>('referral-claim-success')),
          findsNothing,
          reason: entry.key.name,
        );
      }
    });

    test('the five documented codes each have distinct copy', () {
      final messages = <String>{
        referralClaimFailureReason(LaunchFailureKind.activationRequired),
        referralClaimFailureReason(LaunchFailureKind.policyBlocked),
        referralClaimFailureReason(LaunchFailureKind.notFound),
        referralClaimFailureReason(LaunchFailureKind.validationFailed),
        referralClaimFailureReason(LaunchFailureKind.stale),
      };
      expect(messages, hasLength(5));
    });
  });
}

Future<void> _openClaim(WidgetTester tester) async {
  final claim = find.byKey(const ValueKey<String>('referral-claim'));
  await scrollToS7Section(tester, claim);
  await tester.tap(claim);
  await tester.pumpAndSettle();
}
