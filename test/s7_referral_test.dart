import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';

import 'support/referral_center_host.dart';

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
        const ReferralCenterHost(),
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
        const ReferralCenterHost(),
        referral: FakeReferralGateway(),
      );

      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      final copy = tester.widget<LoopIconButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-copy-code')),
          matching: find.byType(LoopIconButton),
        ),
      );
      expect(copy.onPressed, isNotNull);
    });

    testWidgets('the (i) names each level once, without status counts', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(),
      );

      // Decision 0243: the per-level counts and the totals are in the (i).
      expect(find.textContaining('3 pending verification'), findsNothing);
      await _openInfo(tester);
      for (var level = 1; level <= 5; level += 1) {
        final row = find.byKey(ValueKey<String>('referral-level-$level'));
        expect(row, findsOneWidget, reason: 'L$level');
      }
      // S293b: the per-status counts are not repeated in the (i); the
      // totals in 「关系怎样成立」 are.
      expect(find.textContaining('Pending wallet link'), findsNothing);
      expect(find.textContaining('Pending mining'), findsNothing);
      expect(
        find.text('People I invited directly and verified'),
        findsOneWidget,
      );
      expect(
        find.textContaining('L1 · People I invited directly'),
        findsNothing,
      );
      expect(find.textContaining('0 active'), findsOneWidget);
      expect(find.textContaining('3 pending verification'), findsOneWidget);
    });

    // S348: the five-depth strip under the invite card is gone; the depths
    // are 邀请加成's rows.
    testWidgets('no level strip under the invite card', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(),
        size: const Size(390, 2600),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-levels')),
        findsNothing,
      );
      expect(find.text('L1 · 10%'), findsNothing);
    });

    // S239 (decision 0214): the decoded center keys are drawn — the available
    // boost replaces the unavailable card, and the link is offered.
    testWidgets('an available boost and the invite link are drawn', (
      tester,
    ) async {
      final base = s7Referral();
      await pumpS7Page(
        tester,
        const ReferralCenterHost(initialTab: ReferralCenterTab.boost),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: ReferralOverview(
              inviteCode: base.inviteCode,
              binding: base.binding,
              levels: base.levels,
              boost: null,
              boostAvailable: ReferralBoostAvailable(
                referralPower: '12.5',
                nftReferralPower: '10',
                assetReferralPower: '2.5',
                levels: <ReferralBoostLevel>[
                  for (var level = 1; level <= 5; level += 1)
                    ReferralBoostLevel(
                      level: level,
                      effectiveMembers: 0,
                      nftPower: '0',
                      assetPower: '0',
                    ),
                ],
                epochId: '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
                hourStart: DateTime.utc(2026, 10, 19, 8),
                hourEnd: DateTime.utc(2026, 10, 19, 9),
              ),
              inviteLink: 'https://api.example.com/i/LOOP-7HJKM',
              stats: ReferralStats(
                directCount: 3,
                validCount: 0,
                level2to5Count: 0,
                validAsOf: DateTime.utc(2026, 10, 19, 9),
              ),
              rules: base.rules,
            ),
          ),
        ),
      );

      expect(find.text('LOOP-7HJKM'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('launch-unavailable-邀请加成')),
        findsNothing,
      );
      final boost = find.byKey(const ValueKey<String>('referral-boost'));
      await scrollToS7Section(tester, boost);
      expect(find.text('12'), findsOneWidget);
      // S348: every depth is empty, so no depth row is drawn.
      for (var level = 1; level <= 5; level += 1) {
        expect(
          find.byKey(ValueKey<String>('referral-boost-level-$level')),
          findsNothing,
        );
      }
      // Decision 0235: the link is one line, middle-elided, keeping the code
      // it ends with.
      final link = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-invite-link')),
          matching: find.byType(Text),
        ),
      );
      expect(link.data, endsWith('LOOP-7HJKM'));
      expect(link.maxLines, 1);
    });

    testWidgets('an unapproved boost is left out, not explained', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(initialTab: ReferralCenterTab.boost),
        referral: FakeReferralGateway(),
      );

      // S348 (需求方不要说明性文案): until the boost is approved 邀请加成
      // is the total as the em dash, and nothing else.
      expect(
        find.byKey(const ValueKey<String>('launch-unavailable-邀请加成')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('referral-boost-total')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      for (var level = 1; level <= 5; level += 1) {
        expect(
          find.byKey(ValueKey<String>('referral-boost-level-$level')),
          findsNothing,
        );
      }
      expect(find.textContaining('还没有批准邀请加成'), findsNothing);
      expect(
        find.textContaining("The mining formula isn't approved yet"),
        findsNothing,
      );
      // The prototype's final boost figure never returns.
      expect(find.textContaining('2,840'), findsNothing);
      expect(find.textContaining('182 位'), findsNothing);
    });

    testWidgets('the claim entry appears only while the window is open', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(),
      );
      expect(
        find.byKey(const ValueKey<String>('referral-claim')),
        findsOneWidget,
      );

      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
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
      // Decision 0243: the button stays, disabled, with one line saying why.
      _expectClaimDisabled(tester);
      expect(
        find.byKey(const ValueKey<String>('referral-claim-closed')),
        findsOneWidget,
      );
      expect(
        find.text(
          'You can\'t bind an invite code right now. Refresh and try again later',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an unactivated account has no window at all', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
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
      expect(find.textContaining('Activate your LOOP ID'), findsOneWidget);
      _expectClaimDisabled(tester);
    });

    testWidgets('a bound account shows depth and state, never an identity', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
        referral: FakeReferralGateway(
          overview: S7Answer<ReferralOverview>(
            value: s7Referral(binding: s7BoundBinding()),
          ),
        ),
      );

      final bound = find.byKey(const ValueKey<String>('referral-bound-row'));
      await scrollToS7Section(tester, bound);
      expect(bound, findsOneWidget);
      expect(find.textContaining('Depth L1'), findsOneWidget);
      expect(find.textContaining('Pending mining'), findsWidgets);
      _expectClaimDisabled(tester);
      expect(
        find.byKey(const ValueKey<String>('referral-claim-bound-note')),
        findsOneWidget,
      );
    });

    testWidgets('offline and error stay distinct', (tester) async {
      await pumpS7Page(
        tester,
        const ReferralCenterHost(),
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
        const ReferralCenterHost(),
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
        const ReferralCenterHost(),
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
      // Decision 0243: the disclaimer is said once, in the (i).
      expect(
        find.textContaining("It isn't income, commission or a rebate"),
        findsNothing,
      );
      await _openInfo(tester);
      expect(
        find.textContaining("It isn't income, commission or a rebate"),
        findsOneWidget,
      );
    });
  });

  group('claim', () {
    testWidgets('a valid code reaches the gateway and the binding is shown', (
      tester,
    ) async {
      final gateway = FakeReferralGateway();
      await pumpS7Page(tester, const ReferralCenterHost(), referral: gateway);

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
      await pumpS7Page(tester, const ReferralCenterHost(), referral: gateway);

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
      expect(find.textContaining('Invalid invite code format'), findsOneWidget);
    });

    testWidgets('each refusal code gets its own next step', (tester) async {
      final cases = <LaunchFailureKind, String>{
        LaunchFailureKind.activationRequired:
            'Activate your LOOP ID before binding an invite code',
        LaunchFailureKind.policyBlocked:
            "You can't bind an invite code right now",
        LaunchFailureKind.notFound: "This invite code doesn't exist",
        LaunchFailureKind.validationFailed: "you can't invite yourself",
        LaunchFailureKind.stale: 'This account already has an inviter',
      };
      for (final entry in cases.entries) {
        final gateway = FakeReferralGateway(claimFailure: entry.key);
        await pumpS7Page(tester, const ReferralCenterHost(), referral: gateway);

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

Future<void> _openInfo(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const ValueKey<String>('referral-explain-action')),
  );
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey<String>('referral-explain-sheet')),
    findsOneWidget,
  );
}

void _expectClaimDisabled(WidgetTester tester) {
  final claim = find.byKey(const ValueKey<String>('referral-claim'));
  expect(claim, findsOneWidget);
  expect(tester.widget<LoopButton>(claim).onPressed, isNull);
}
