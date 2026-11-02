import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_gateway.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

import 'support/s332_beta_feedback.dart';

/// S332 联调 F2: a refusal that says the uploaded pictures are spent makes
/// the next submit upload them again; any other failure keeps them.
void main() {
  late FakeBetaFeedbackGateway gateway;
  late ProviderContainer container;

  setUp(() {
    gateway = FakeBetaFeedbackGateway();
    container = ProviderContainer(
      overrides: [
        betaFeedbackGatewayProvider.overrideWithValue(gateway),
        betaFeedbackEnvironmentSourceProvider.overrideWithValue(
          const FixedBetaFeedbackEnvironment(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  BetaFeedbackFormController form() =>
      container.read(betaFeedbackFormControllerProvider.notifier);

  Future<BetaFeedbackReceipt?> submit() => form().submit(
    category: BetaFeedbackCategory.bug,
    body: '闪退',
    origin: s332Origin,
  );

  for (final reasonCode in BetaFeedbackFormController.mediaRefusalReasonCodes) {
    test(
      'a 422 $reasonCode re-uploads every picture on the next submit',
      () async {
        final keepAlive = container.listen(
          betaFeedbackFormControllerProvider,
          (_, _) {},
        );
        addTearDown(keepAlive.close);
        form().addImages(<BetaFeedbackPickedImage>[s332Picked(), s332Picked()]);
        gateway
          ..submitFailure = LoopChainFailureKind.validationFailed
          ..submitReasonCode = reasonCode;

        expect(await submit(), isNull);
        expect(
          container.read(betaFeedbackFormControllerProvider).failureKind,
          LoopChainFailureKind.validationFailed,
        );
        expect(gateway.calls, <String>['upload:0', 'upload:1', 'submit']);

        gateway.submitFailure = null;
        expect(await submit(), isNotNull);
        expect(gateway.calls, <String>[
          'upload:0',
          'upload:1',
          'submit',
          'upload:0',
          'upload:1',
          'submit',
        ]);
        expect(
          gateway.submissions.last.mediaIds,
          isNot(gateway.submissions.first.mediaIds),
        );
      },
    );
  }

  test('another failure keeps the uploaded pictures', () async {
    final keepAlive = container.listen(
      betaFeedbackFormControllerProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);
    form().addImages(<BetaFeedbackPickedImage>[s332Picked()]);
    gateway
      ..submitFailure = LoopChainFailureKind.validationFailed
      ..submitReasonCode = 'FEEDBACK_BODY_TOO_LONG';

    await submit();
    gateway.submitFailure = null;
    await submit();
    expect(gateway.calls, <String>['upload:0', 'submit', 'submit']);
  });
}
