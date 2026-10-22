// S277 · decision 0235: the self-review shots of 我的邀请 and the scanner's
// invite result.
//
// Not a check: it writes 390-wide renders to docs/integration/S277/shots/ so
// the regrouped invite block can be read by eye. It runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case
// and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = 'docs/integration/S277/shots';

ReferralOverview _overview({String? link, ReferralStats? stats}) {
  final base = s7Referral();
  return ReferralOverview(
    inviteCode: base.inviteCode,
    binding: base.binding,
    levels: base.levels,
    boost: base.boost,
    boostAvailable: null,
    inviteLink: link,
    stats: stats,
    rules: base.rules,
  );
}

final ReferralStats _stats = ReferralStats(
  directCount: 0,
  validCount: 0,
  level2to5Count: 0,
  validAsOf: DateTime.utc(2026, 10, 22, 9),
);

void main() {
  loopWatchGround();

  // The link's middle ellipsis is measured when it builds; load the fonts
  // first (a throw-away frame under .dart_tool) so the first shot is measured
  // in the real faces, not the test font.
  testWidgets('warm fonts', skip: !_shots, (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await loopShot(tester, 'warm', dir: '.dart_tool/s277_shots');
  });

  testWidgets('情报 · 我的邀请', skip: !_shots, (tester) async {
    await pumpS7Page(
      tester,
      IntelRankBoard(onNavigate: (_) {}),
      size: const Size(390, 900),
      mining: FakeMiningGateway(),
      referral: FakeReferralGateway(
        overview: S7Answer(
          value: _overview(
            link: 'https://api-staging.quant-dinger.cc/i/LOOP-7HJKM',
            stats: _stats,
          ),
        ),
      ),
    );
    await tester.tap(find.text('邀请中心'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('intel-referral-open')),
    );
    await tester.pumpAndSettle();
    await loopShot(tester, 'intel-referral-center', dir: _dir);
  });

  testWidgets('邀请中心 · top', skip: !_shots, (tester) async {
    await pumpS7Page(
      tester,
      const ReferralScreen(),
      size: const Size(390, 1300),
      referral: FakeReferralGateway(
        overview: S7Answer(
          value: _overview(
            link: 'https://api-staging.quant-dinger.cc/i/LOOP-7HJKM',
            stats: _stats,
          ),
        ),
      ),
    );
    await loopShot(tester, 'referral-page', slice: 1300, dir: _dir);
  });

  testWidgets('邀请中心 · no link yet', skip: !_shots, (tester) async {
    await pumpS7Page(
      tester,
      const ReferralScreen(),
      size: const Size(390, 1300),
      referral: FakeReferralGateway(overview: S7Answer(value: _overview())),
    );
    await loopShot(tester, 'referral-page-no-link', slice: 1300, dir: _dir);
  });
}
