import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/meme/meme_signing.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';

/// Decision 0158 · review findings that are pure copy decisions.
///
/// The other findings are tested beside the behaviour they change:
/// F1 / F6 in `s154_large_amount_step_up_test.dart`, F2 in
/// `s160_security_current_projection_test.dart`, F3 / F4 / F9 in
/// `s156_testnet_faucet_test.dart`, F8 in
/// `s109a_onboarding_communities_test.dart`, the support answer in
/// `s8_settings_about_support_test.dart`.
void main() {
  group('F7 · a step-up stop after the approval went out', () {
    test('MEME v2 says the approval went out and the trade did not', () {
      for (final code in <String>[
        loopStepUpCancelledCode,
        loopStepUpFailedCode,
      ]) {
        expect(
          launch2SignReasonText(code, approvalSent: true),
          '授权已发出，交易未发起。',
          reason: code,
        );
      }
      // Without an approval nothing changed, as before.
      expect(launch2SignReasonText(loopStepUpCancelledCode), '已取消，没有发生任何变化。');
      expect(launch2SignReasonText(loopStepUpFailedCode), '身份验证没有通过，没有发生任何变化。');
      // Other refusals keep their own sentence.
      expect(
        launch2SignReasonText('INTENT_EXPIRED', approvalSent: true),
        launch2SignReasonText('INTENT_EXPIRED'),
      );
    });

    test('MEME says the approval went out and the trade did not', () {
      for (final code in <String>[
        loopStepUpCancelledCode,
        loopStepUpFailedCode,
      ]) {
        expect(
          memeSignReasonText(code, approvalSent: true),
          loopStepUpAfterApprovalText,
          reason: code,
        );
      }
      expect(memeSignReasonText(loopStepUpCancelledCode), '已取消，没有发生任何变化。');
    });
  });
}
