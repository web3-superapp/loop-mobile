import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9, 13, 36);

  group('the intent handed to the wallet', () {
    test('carries the server digest and the verbatim transaction', () {
      final intent = s6Intent();
      final signing = MoneyActionSigner.toSigningIntent(intent)!;

      expect(signing.origin, IntentOrigin.backendCanonical);
      expect(signing.revision, intent.intentId);
      expect(signing.payloadDigest, intent.reviewSha256);
      expect(signing.allowsWalletHandoff, isTrue);
      final payload = signing.payload! as DeviceTransactionPayload;
      expect(payload.fromAddress, s6From);
      expect(payload.transaction['data'], s6TransferData);
      expect(payload.transaction.keys.toList(), <String>[
        'chainId',
        'from',
        'to',
        'data',
        'value',
        'gas',
        'nonce',
        'type',
        'maxFeePerGas',
        'maxPriorityFeePerGas',
        'gasPrice',
      ]);
    });

    test('shows exactly the values the payload encodes', () {
      final intent = s6Intent();
      final signing = MoneyActionSigner.toSigningIntent(intent)!;
      final shown = <String, String>{
        for (final field in signing.fields) field.label: field.value,
      };

      expect(shown['数量'], '0.01 WBNB');
      expect(shown['收款方'], s6RecipientChecksum);
      expect(shown['最高网络费'], '0.0000020775 BNB');
      expect(shown['模拟结果'], '预执行通过（eth_call）');
      // The same object produced both halves, so the review and the payload
      // cannot describe different calls.
      expect(intent.payloadMatchesReview, isTrue);
    });

    test('a swap authorizes rather than broadcasts', () {
      final signing = MoneyActionSigner.toSigningIntent(s6SwapIntent())!;
      final payload = signing.payload! as AuthorizationSignaturePayload;

      expect(payload.method, 'POST');
      expect(payload.body['base_amount'], '5000000000000000');
      expect(payload.headers['privy-idempotency-key'], s6IntentId);
    });

    test('an intent without a payload never becomes a signing intent', () {
      final intent = LoopV2IntentCodec.intent(
        s6IntentBody(unsignedTransaction: null),
      );

      expect(MoneyActionSigner.toSigningIntent(intent), isNull);
    });
  });

  group('the signing exit', () {
    test(
      'reports the wallet hash to the server and returns its state',
      () async {
        final intents = FakeWalletIntentsGateway(
          reported: s6Intent(state: 'submitted'),
        );
        final wallet = RecordingSigningGateway();
        final signer = MoneyActionSigner(intents: intents, wallet: wallet);

        final outcome = await signer.sign(s6Intent(), now: now);

        expect(outcome.status, MoneySignStatus.submitted);
        expect(outcome.intent!.state, LoopIntentState.submitted);
        expect(intents.reportCalls, 1);
        expect(intents.reportedHashes.single, wallet.value);
        expect(intents.executeCalls, 0);
      },
    );

    test('a swap hands the signature to execute, never a hash', () async {
      final intents = FakeWalletIntentsGateway(
        reported: s6Intent(state: 'submitted'),
      );
      final wallet = RecordingSigningGateway(value: 'authorization-signature');
      final signer = MoneyActionSigner(intents: intents, wallet: wallet);

      // The server only allows a swap once a provider simulation exists; the
      // fixture grants that so the execute path itself can be exercised.
      final swap = LoopV2IntentCodec.intent(
        s6SwapIntentBody(state: 'awaiting_signature')
          ..['signing'] = <String, Object?>{
            'mode': 'privy_authorization_signature',
            'allowed': true,
            'reasonCode': null,
          },
      );

      final outcome = await signer.sign(swap, now: now);

      expect(outcome.status, MoneySignStatus.submitted);
      expect(intents.executeCalls, 1);
      expect(intents.signatures.single, 'authorization-signature');
      expect(intents.reportCalls, 0);
    });

    test(
      'a swap the server has not cleared never reaches the wallet',
      () async {
        final intents = FakeWalletIntentsGateway();
        final wallet = RecordingSigningGateway();
        final signer = MoneyActionSigner(intents: intents, wallet: wallet);

        final outcome = await signer.sign(s6SwapIntent(), now: now);

        expect(outcome.status, MoneySignStatus.refused);
        expect(outcome.reasonCode, 'SIMULATION_UNAVAILABLE');
        expect(wallet.handoffs, isEmpty);
        expect(intents.executeCalls, 0);
      },
    );

    test('an expired intent never reaches the wallet', () async {
      final intents = FakeWalletIntentsGateway();
      final wallet = RecordingSigningGateway();
      final signer = MoneyActionSigner(intents: intents, wallet: wallet);

      final outcome = await signer.sign(
        s6Intent(),
        now: DateTime.utc(2026, 9, 9, 14),
      );

      expect(outcome.status, MoneySignStatus.refused);
      expect(outcome.reasonCode, 'INTENT_EXPIRED');
      expect(wallet.handoffs, isEmpty);
    });

    test('a payload that leaves the review never reaches the wallet', () async {
      final intents = FakeWalletIntentsGateway();
      final wallet = RecordingSigningGateway();
      final signer = MoneyActionSigner(intents: intents, wallet: wallet);
      final tampered = LoopV2IntentCodec.intent(
        s6IntentBody(
          unsignedTransaction: s6UnsignedTransaction(
            data:
                '0xa9059cbb'
                '000000000000000000000000000000000000000000000000000000000000beef'
                '000000000000000000000000000000000000000000000000002386f26fc10000',
          ),
        ),
      );

      final outcome = await signer.sign(tampered, now: now);

      expect(outcome.status, MoneySignStatus.refused);
      expect(outcome.reasonCode, 'REVIEW_PAYLOAD_MISMATCH');
      expect(wallet.handoffs, isEmpty);
      expect(intents.reportCalls, 0);
    });

    test('a refused wallet submits nothing', () async {
      final intents = FakeWalletIntentsGateway();
      final wallet = RecordingSigningGateway(
        accepted: false,
        code: 'privy_broadcast_rejected',
      );
      final signer = MoneyActionSigner(intents: intents, wallet: wallet);

      final outcome = await signer.sign(s6Intent(), now: now);

      expect(outcome.status, MoneySignStatus.walletRejected);
      expect(intents.reportCalls, 0);
      expect(outcome.intent, isNull);
    });

    test('an unreadable wallet outcome locks instead of retrying', () async {
      final intents = FakeWalletIntentsGateway();
      final wallet = RecordingSigningGateway(
        accepted: false,
        code: 'wallet_outcome_unknown',
      );
      final signer = MoneyActionSigner(intents: intents, wallet: wallet);

      final outcome = await signer.sign(s6Intent(), now: now);

      expect(outcome.status, MoneySignStatus.locked);
      expect(intents.reportCalls, 0);
    });

    test('a server answer of unknown locks the intent', () async {
      final intents = FakeWalletIntentsGateway(
        reported: s6Intent(
          state: 'unknown',
          result: <String, Object?>{
            'transactionHash': null,
            'providerActionId': null,
            'reasonCode': 'PROVIDER_RESULT_AMBIGUOUS',
            'receipt': null,
          },
        ),
      );
      final signer = MoneyActionSigner(
        intents: intents,
        wallet: RecordingSigningGateway(),
      );

      final outcome = await signer.sign(s6Intent(), now: now);

      expect(outcome.status, MoneySignStatus.locked);
      expect(outcome.intent!.state, LoopIntentState.unknown);
      expect(outcome.reasonCode, 'PROVIDER_RESULT_AMBIGUOUS');
    });

    test(
      'an unresolved report locks rather than inviting a new signature',
      () async {
        final intents = FakeWalletIntentsGateway(
          reportFailure: LoopChainFailureKind.outcomeUnknown,
        );
        final wallet = RecordingSigningGateway();
        final signer = MoneyActionSigner(intents: intents, wallet: wallet);

        final outcome = await signer.sign(s6Intent(), now: now);

        expect(outcome.status, MoneySignStatus.locked);
        expect(wallet.handoffs, hasLength(1));
      },
    );
  });
}
