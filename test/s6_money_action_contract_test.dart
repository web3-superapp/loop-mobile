import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/approvals/loop_v2_approvals_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/swap/loop_v2_swap_api.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';

import 'support/s5_fixtures.dart';
import 'support/s6_fixtures.dart';

const _accessToken = 'privy-access-token';
const _idempotencyKey = '9d0e1f2a-3b4c-4d5e-8f6a-7b8c9d0e1f2a';

void main() {
  group('intent codec', () {
    test('decodes one intent with every exact figure', () {
      final intent = LoopV2IntentCodec.intent(s6IntentBody());

      expect(intent.intentId, s6IntentId);
      expect(intent.kind, LoopIntentKind.send);
      expect(intent.state, LoopIntentState.awaitingSignature);
      expect(intent.review.amount.raw, '10000000000000000');
      expect(intent.review.amount.display, '0.01');
      expect(intent.review.amount.value, Decimal.parse('0.01'));
      expect(intent.review.fee!.maximumFee, Decimal.parse('0.0000020775'));
      expect(intent.review.balance.blockNumber, BigInt.from(120695250));
      expect(intent.reviewSha256, 'c' * 64);
      expect(intent.signing.mode, LoopSigningMode.deviceEthSendTransaction);
      expect(
        intent.review.recipient!.screening.reasonCode,
        'GOPLUS_ADDRESS_SCREENING_NOT_CONFIGURED',
      );
    });

    test('an unlimited allowance is a meaning, never a parsed number', () {
      final intent = LoopV2IntentCodec.intent(
        s6ApprovalIntentBody(
          allowanceDisplay: 'unlimited',
          allowanceRaw: '11579208923731619542357098500868790785326998466564056403945758400791312963993',
          isUnlimited: true,
        ),
      );

      expect(intent.review.amount.isUnlimited, isTrue);
      expect(intent.review.amount.value, isNull);
      expect(intent.review.spender!.isUnlimited, isTrue);
    });

    test('an unknown field is an invalid payload, never a partial intent', () {
      final body = s6IntentBody()..['unexpected'] = true;

      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a review whose kind disagrees with the intent is rejected', () {
      final body = s6IntentBody();
      (body['review']! as Map<String, Object?>)['kind'] = 'approve';

      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an available price impact must carry a figure', () {
      expect(
        () => LoopV2IntentCodec.quoteView(
          s6QuoteBody(priceImpact: s6PriceImpact(value: null)),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the authorization payload is rebuilt verbatim', () {
      final intent = LoopV2IntentCodec.intent(s6SwapIntentBody());
      final payload = intent.authorizationPayload!;

      expect(payload.version, 1);
      expect(payload.method, 'POST');
      expect(payload.body['base_amount'], '5000000000000000');
      expect(payload.body['slippage_bps'], 50);
      expect(payload.headers['privy-idempotency-key'], s6IntentId);
      expect(payload.body.containsKey('fee_configuration'), isFalse);
    });

    test('an allowance that could not be read is never a zero', () {
      final inventory = LoopV2IntentCodec.approvals(
        s6ApprovalsBody(
          items: <Map<String, Object?>>[s6ApprovalRowBody(readable: false)],
        ),
      );

      final allowance = inventory.items.single.allowance;
      expect(allowance, isA<LoopAllowanceUnavailable>());
      expect(
        (allowance as LoopAllowanceUnavailable).reasonCode,
        'ALLOWANCE_READ_FAILED',
      );
    });
  });

  group('signing admission', () {
    test('only an awaiting_signature intent the server allows can sign', () {
      final now = DateTime.utc(2026, 9, 9, 13, 36);

      expect(s6Intent().canSignAt(now), isTrue);
      expect(s6Intent(state: 'prepared').canSignAt(now), isFalse);
      expect(s6Intent(signingAllowed: false).canSignAt(now), isFalse);
      expect(s6SwapIntent().canSignAt(now), isFalse);
    });

    test('an expired intent is blocked with the server vocabulary', () {
      final late = DateTime.utc(2026, 9, 9, 14);
      final intent = s6Intent();

      expect(intent.canSignAt(late), isFalse);
      expect(intent.blockedReasonAt(late), 'INTENT_EXPIRED');
    });

    test('a swap intent reports the pending provider simulation', () {
      final now = DateTime.utc(2026, 9, 9, 13, 36);

      expect(s6SwapIntent().blockedReasonAt(now), 'SIMULATION_UNAVAILABLE');
    });

    test('the call data must encode the reviewed transfer', () {
      expect(s6Intent().payloadMatchesReview, isTrue);
      expect(s6ApprovalIntent().payloadMatchesReview, isTrue);
    });

    test('a payload that pays a different address is refused', () {
      final intent = LoopV2IntentCodec.intent(
        s6IntentBody(
          unsignedTransaction: s6UnsignedTransaction(
            data:
                '0xa9059cbb'
                '000000000000000000000000000000000000000000000000000000000000beef'
                '000000000000000000000000000000000000000000000000002386f26fc10000',
          ),
        ),
      );

      expect(intent.payloadMatchesReview, isFalse);
    });

    test('a payload that moves a different amount is refused', () {
      final intent = LoopV2IntentCodec.intent(
        s6IntentBody(
          unsignedTransaction: s6UnsignedTransaction(
            data:
                '0xa9059cbb'
                '000000000000000000000000000000000000000000000000000000000000dead'
                '0000000000000000000000000000000000000000000000004563918244f40000',
          ),
        ),
      );

      expect(intent.payloadMatchesReview, isFalse);
    });

    test('a swap body that leaves the reviewed quote is refused', () {
      final body = s6SwapIntentBody();
      ((body['authorizationPayload']! as Map<String, Object?>)['body']!
              as Map<String, Object?>)['base_amount'] =
          '9000000000000000';
      final intent = LoopV2IntentCodec.intent(body);

      expect(intent.payloadMatchesReview, isFalse);
    });
  });

  group('payload cross-check', () {
    // Decision 0038 gave the Launch module its own chain slot. A money action
    // never moves with it: a send, approve, revoke or swap payload built for
    // any other chain is rejected by the transport, so it can never reach a
    // review, a sheet or a wallet.
    test('a payload built for another chain is refused', () {
      final body = s6IntentBody();
      (body['unsignedTransaction']! as Map<String, Object?>)['chainId'] = 97;

      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an intent announcing another chain is refused', () {
      final body = s6IntentBody();
      body['chainId'] = 'eip155:97';

      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an ERC-20 call with a third word is refused', () {
      final intent = LoopV2IntentCodec.intent(
        s6IntentBody(
          unsignedTransaction: s6UnsignedTransaction(
            data: '$s6TransferData${'0' * 64}',
          ),
        ),
      );

      expect(intent.payloadMatchesReview, isFalse);
    });

    test('a swap keyed to another intent is refused', () {
      final body = s6SwapIntentBody();
      ((body['authorizationPayload']! as Map<String, Object?>)['headers']!
              as Map<String, Object?>)['privy-idempotency-key'] =
          s6OtherIntentId;
      final intent = LoopV2IntentCodec.intent(body);

      expect(intent.payloadMatchesReview, isFalse);
    });

    test('a swap endpoint on another chain is refused', () {
      final body = s6SwapIntentBody();
      (((body['authorizationPayload']! as Map<String, Object?>)['body']!
                  as Map<String, Object?>)['destination']!
              as Map<String, Object?>)['caip2'] =
          'eip155:97';
      final intent = LoopV2IntentCodec.intent(body);

      expect(intent.payloadMatchesReview, isFalse);
    });

    test('the approval coverage start is part of the freshness', () {
      final inventory = LoopV2IntentCodec.approvals(s6ApprovalsBody());

      expect(
        inventory.freshness.approvalCoverageFromBlockNumber,
        BigInt.from(120600000),
      );
    });
  });

  group('policy refusals', () {
    LoopChainException refusal({
      required int statusCode,
      required String code,
      Map<String, Object?>? detailsSafe,
    }) {
      final options = RequestOptions(path: '/v2/wallet-intents/send');
      final error = s5ErrorResponse(
        options,
        statusCode: statusCode,
        code: code,
        category: statusCode == 403 ? 'authorization' : 'validation',
        userMessageKey: 'errors.policy.blocked',
      );
      (error.response!.data! as Map<String, Object?>)['detailsSafe'] =
          detailsSafe;
      return loopChainExceptionForV2(
        LoopV2Contract.mapDioFailure(
          error,
          allowedCodes: LoopV2ModuleRequest.moneyActionWriteErrors,
        ),
      );
    }

    test('the rule and its two figures survive the boundary', () {
      final failure = refusal(
        statusCode: 403,
        code: 'POLICY_BLOCKED',
        detailsSafe: <String, Object?>{
          'reasonCode': 'CANARY_CEILING_EXCEEDED',
          'exposureUsd': '750.51',
          'ceilingUsd': '20',
        },
      );

      expect(failure.kind, LoopChainFailureKind.permissionDenied);
      expect(failure.reasonCode, 'CANARY_CEILING_EXCEEDED');
      expect(failure.exposureUsd, '750.51');
      expect(failure.ceilingUsd, '20');
      expect(MoneyPolicyNotice.covers(failure), isTrue);
      final text = moneyPolicyRefusalText(failure);
      expect(text, contains('750.51'));
      expect(text, contains('本步暂不可调'));
    });

    test('a rule that compares nothing renders no figures', () {
      final failure = refusal(
        statusCode: 403,
        code: 'POLICY_BLOCKED',
        detailsSafe: <String, Object?>{
          'reasonCode': 'ASSET_NOT_IN_CANARY_ALLOWLIST',
          'exposureUsd': '750.51',
          'ceilingUsd': '20',
        },
      );

      final text = moneyPolicyRefusalText(failure);
      expect(text, contains('灰度名单'));
      expect(text, isNot(contains('750.51')));
    });

    test('each rule gets its own sentence', () {
      final seen = <String>{};
      for (final rule in const <String>[
        MoneyPolicyRule.assetNotInAllowlist,
        MoneyPolicyRule.canaryCeilingExceeded,
        MoneyPolicyRule.unlimitedExposureExceedsCeiling,
        MoneyPolicyRule.assetBlocked,
        MoneyPolicyRule.priceImpactBlocked,
        MoneyPolicyRule.nativeAssetNotApprovable,
      ]) {
        final text = moneyPolicyRefusalText(
          LoopChainException(
            LoopChainFailureKind.permissionDenied,
            reasonCode: rule,
          ),
        );
        expect(seen.add(text), isTrue, reason: rule);
      }
    });

    test('a native approval is a named refusal, not a generic error', () {
      final failure = refusal(
        statusCode: 422,
        code: 'VALIDATION_FAILED',
        detailsSafe: <String, Object?>{
          'reasonCode': 'NATIVE_ASSET_NOT_APPROVABLE',
        },
      );

      expect(failure.kind, LoopChainFailureKind.validationFailed);
      expect(MoneyPolicyNotice.covers(failure), isTrue);
      expect(moneyPolicyRefusalText(failure), contains('原生 BNB 没有授权面'));
    });

    test('an unlisted details key never reaches a page', () {
      final failure = refusal(
        statusCode: 403,
        code: 'POLICY_BLOCKED',
        detailsSafe: <String, Object?>{
          'reasonCode': 'CANARY_CEILING_EXCEEDED',
          'walletAddress': '0x00000000000000000000000000000000000000a1',
          'exposureUsd': 750.51,
        },
      );

      expect(failure.reasonCode, 'CANARY_CEILING_EXCEEDED');
      // A numeric amount is not an exact decimal string, so it is dropped
      // rather than rendered.
      expect(failure.exposureUsd, isNull);
      expect(failure.hasCeilingFigures, isFalse);
      expect(moneyPolicyRefusalText(failure), isNot(contains('750.51')));
    });

    test('a plain validation failure is not a policy refusal', () {
      final failure = refusal(statusCode: 422, code: 'VALIDATION_FAILED');

      expect(failure.reasonCode, isNull);
      expect(MoneyPolicyNotice.covers(failure), isFalse);
    });
  });

  group('wallet failure classification', () {
    test('only a recognised decline proves nothing was broadcast', () {
      expect(
        privyWalletFailureCode('User rejected the request'),
        'privy_broadcast_rejected',
      );
      expect(
        privyWalletFailureCode('Request rejected by user'),
        'privy_broadcast_rejected',
      );
      for (final message in const <String>[
        'Unexpected error',
        'PlatformException(channel-error)',
        'timeout',
        'rejected',
        '',
      ]) {
        expect(
          privyWalletFailureCode(message),
          'wallet_outcome_unknown',
          reason: message,
        );
      }
    });
  });

  group('transport', () {
    test('a prepare carries the contract headers and one key', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s6IntentBody(), statusCode: 201));
        }),
      );

      await api.prepareSend(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        assetId: s5WbnbAssetId,
        amount: '0.01',
        recipientAddress: s6RecipientChecksum,
      );

      expect(captured!.headers['authorization'], 'Bearer $_accessToken');
      expect(captured!.headers['x-loop-contract-version'], '2.0');
      expect(captured!.headers['idempotency-key'], _idempotencyKey);
      expect(captured!.data, <String, Object?>{
        'walletId': s5WalletId,
        'assetId': s5WbnbAssetId,
        'amount': '0.01',
        'recipientAddress': s6RecipientChecksum,
      });
    });

    test('a replayed key returns the original intent, not a new one', () async {
      final api = DioLoopV2WalletIntentsApi(
        s5Dio(
          (options, handler) =>
              handler.resolve(s5Response(options, s6IntentBody())),
        ),
      );

      final intent = await api.prepareSend(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        assetId: s5WbnbAssetId,
        amount: '0.01',
        recipientAddress: s6RecipientChecksum,
      );

      expect(intent.intentId, s6IntentId);
    });

    test('the preflight refuses to carry an idempotency key', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s6PreflightBody()));
        }),
      );

      await api.preflightSend(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
        address: s6RecipientChecksum,
      );

      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
    });

    test('an unlimited allowance always carries its acknowledgement', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(
              options,
              s6ApprovalIntentBody(
                allowanceDisplay: 'unlimited',
                allowanceRaw: '11579208923731619542357098500868790785326998466564056403945758400791312963993',
                isUnlimited: true,
              ),
              statusCode: 201,
            ),
          );
        }),
      );

      await api.prepareApprove(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        assetId: s5UsdtAssetId,
        spenderAddress: s6SpenderChecksum,
        allowance: const LoopUnlimitedAllowanceRequest(),
      );

      expect(captured!.data, <String, Object?>{
        'walletId': s5WalletId,
        'assetId': s5UsdtAssetId,
        'spenderAddress': s6SpenderChecksum,
        'allowance': <String, Object?>{'mode': 'unlimited'},
        'acknowledgeUnlimited': true,
      });
    });

    test('an exact allowance never asks for the unlimited path', () async {
      RequestOptions? captured;
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, s6ApprovalIntentBody(), statusCode: 201),
          );
        }),
      );

      await api.prepareApprove(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        idempotencyKey: _idempotencyKey,
        walletId: s5WalletId,
        assetId: s5UsdtAssetId,
        spenderAddress: s6SpenderChecksum,
        allowance: const LoopExactAllowanceRequest('5'),
      );

      final data = captured!.data! as Map<String, Object?>;
      expect(data['allowance'], <String, Object?>{
        'mode': 'exact',
        'amount': '5',
      });
      expect(data.containsKey('acknowledgeUnlimited'), isFalse);
    });

    test('a numeric amount never reaches the wire', () async {
      final api = DioLoopV2WalletIntentsApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, null))),
      );

      expect(
        () => api.prepareSend(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          idempotencyKey: _idempotencyKey,
          walletId: s5WalletId,
          assetId: s5WbnbAssetId,
          amount: '0.01e3',
          recipientAddress: s6RecipientChecksum,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a repeated execute projects as a locked submission', () async {
      final api = DioLoopV2WalletIntentsApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 409,
              code: 'SUBMISSION_UNKNOWN',
              category: 'conflict',
              userMessageKey: 'errors.wallet.submissionUnknown',
            ),
          ),
        ),
      );

      try {
        await api.execute(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          idempotencyKey: _idempotencyKey,
          intentId: s6IntentId,
          authorizationSignature: 'signature',
        );
        fail('expected a failure');
      } on LoopBackendFailure catch (failure) {
        expect(
          loopChainFailureKindForV2(failure),
          LoopChainFailureKind.submissionUnknown,
        );
        // A locked submission is unresolved: its key must be replayed, never
        // replaced by a second attempt.
        expect(
          loopChainOutcomeIsUnresolved(loopChainFailureKindForV2(failure)),
          isTrue,
        );
      }
    });

    test('an insufficient balance projects onto its own kind', () async {
      final api = DioLoopV2WalletIntentsApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 409,
              code: 'INSUFFICIENT_BALANCE',
              category: 'conflict',
              userMessageKey: 'errors.wallet.insufficientBalance',
            ),
          ),
        ),
      );

      try {
        await api.prepareSend(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          idempotencyKey: _idempotencyKey,
          walletId: s5WalletId,
          assetId: s5WbnbAssetId,
          amount: '0.01',
          recipientAddress: s6RecipientChecksum,
        );
        fail('expected a failure');
      } on LoopBackendFailure catch (failure) {
        expect(
          loopChainFailureKindForV2(failure),
          LoopChainFailureKind.insufficientBalance,
        );
      }
    });

    test('a slippage above the policy ceiling never leaves the client', () {
      final api = DioLoopV2SwapApi(
        s5Dio((options, handler) => handler.resolve(s5Response(options, null))),
      );

      expect(
        () => api.quote(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          walletId: s5WalletId,
          sourceAssetId: s5WbnbAssetId,
          destinationAssetId: s5UsdtAssetId,
          amount: '0.005',
          slippageBps: 301,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an approval inventory read carries the wallet id only', () async {
      RequestOptions? captured;
      final api = DioLoopV2ApprovalsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, s6ApprovalsBody()));
        }),
      );

      final inventory = await api.getApprovals(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        walletId: s5WalletId,
      );

      expect(captured!.queryParameters, <String, Object?>{
        'walletId': s5WalletId,
      });
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect(inventory.items.single.symbol, 'USDT');
    });

    test(
      'a missing indexer checkpoint is unknown, never zero approvals',
      () async {
        final api = DioLoopV2ApprovalsApi(
          s5Dio(
            (options, handler) => handler.reject(
              s5ErrorResponse(
                options,
                statusCode: 503,
                code: 'INDEXING_DELAYED',
              ),
            ),
          ),
        );

        try {
          await api.getApprovals(
            accessToken: _accessToken,
            clientVersion: s5ClientVersion,
            walletId: s5WalletId,
          );
          fail('expected a failure');
        } on LoopBackendFailure catch (failure) {
          expect(
            loopChainFailureKindForV2(failure),
            LoopChainFailureKind.indexingDelayed,
          );
        }
      },
    );
  });
}
