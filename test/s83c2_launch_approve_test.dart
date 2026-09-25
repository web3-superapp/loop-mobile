import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_approval.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s6_fixtures.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0089 · the USD1 approval in front of a Launch purchase, the
/// optional S83b intent keys, the broadcast report and two copy changes.
///
/// Every value is 测试专用, written by hand from loop-api `integration/v2` =
/// `8d99260` (`openapi/loop-api.v2.json`, `docs/frontend-v2-launch-api.md`
/// §S83b). No server has emitted the `available` shapes yet.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

// ---------------------------------------------------------------------------
// port doubles
// ---------------------------------------------------------------------------

/// A wallet boundary that records what it was handed. It never reaches Privy.
final class _RecordingWallet implements WalletSigningGateway {
  _RecordingWallet(this.result);

  final WalletHandoffResult result;
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return result;
  }
}

/// The wallet-intent port for the approval: one prepared intent (or a
/// refusal), one reported intent and a fixed intent read.
final class _ApprovalIntents implements WalletIntentsGateway {
  _ApprovalIntents({this.prepareFailure, this.reported});

  final LoopChainException? prepareFailure;
  final LoopWalletIntent? reported;

  final List<String> approvals = <String>[];
  final List<String> reports = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopWalletIntent> prepareApproval({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
  }) {
    final amount = switch (allowance) {
      LoopExactAllowanceRequest(:final amount) => 'exact:$amount',
      LoopUnlimitedAllowanceRequest() => 'unlimited',
    };
    approvals.add('$walletId|$assetId|$spenderAddress|$amount');
    final failure = prepareFailure;
    if (failure != null) return Future<LoopWalletIntent>.error(failure);
    return Future<LoopWalletIntent>.value(_approvalIntent());
  }

  @override
  Future<LoopWalletIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) {
    reports.add(txHash);
    return Future<LoopWalletIntent>.value(
      reported ?? _approvalIntent(state: 'submitted'),
    );
  }

  @override
  Future<LoopWalletIntent> loadIntent(String intentId) =>
      Future<LoopWalletIntent>.value(
        reported ?? _approvalIntent(state: 'submitted'),
      );

  Future<Never> _unused() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopSendPreflight> preflightRecipient({
    required String walletId,
    required String address,
  }) => _unused();

  @override
  Future<LoopWalletIntent> prepareSend({
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
  }) => _unused();

  @override
  Future<LoopWalletIntent> prepareRevoke({
    required String walletId,
    required String assetId,
    required String spenderAddress,
  }) => _unused();

  @override
  Future<LoopWalletIntent> prepareSwap({
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
  }) => _unused();

  @override
  Future<LoopWalletIntent> execute({
    required String intentId,
    required String authorizationSignature,
  }) => _unused();

  @override
  Future<LoopWalletIntent> cancel(String intentId) => _unused();

  @override
  Future<LoopWalletIntentPage> loadIntents({String? cursor}) => _unused();
}

// ---------------------------------------------------------------------------
// fixtures
// ---------------------------------------------------------------------------

/// 500 USD1, the amount every page test types.
const _fiveHundred = '500000000000000000000';
const _oneHundred = '100000000000000000000';
final _approveHash = '0x${'5a' * 32}';

/// `approve(<Launch contract>, 500 USD1)` on USD1, as the server builds it.
String _approveData(String raw) =>
    '0x095ea7b3'
    '${s83cContract.substring(2).padLeft(64, '0')}'
    '${BigInt.parse(raw).toRadixString(16).padLeft(64, '0')}';

/// The approval intent `POST /v2/wallet-intents/approve` answers for USD1 on
/// the Launch slot (loop-api 0077 §S83b.8): chain 97, the USD1 token as the
/// call target and the Launch contract as the spender.
Map<String, Object?> _approvalBody({
  String state = 'awaiting_signature',
  String raw = _fiveHundred,
}) {
  final body = s6ApprovalIntentBody(allowanceRaw: raw, allowanceDisplay: '500');
  body['state'] = state;
  body['chainId'] = loopLaunchTestnetChainId;
  body['walletId'] = s7WalletId;
  body['factsObservedAt'] = '2026-09-22T14:00:00.000Z';
  body['expiresAt'] = '2026-09-22T14:10:00.000Z';
  final review = body['review']! as Map<String, Object?>;
  review['asset'] = <String, Object?>{
    'assetId': '$loopLaunchTestnetChainId:$s83cUsd1',
    'address': s83cUsd1,
    'symbol': 'USD1',
    'decimals': 18,
  };
  review['spender'] = <String, Object?>{
    'address': s83cContract,
    'checksumAddress': s83cContract,
    'isContract': true,
    'isUnlimited': false,
  };
  review['decodedCall'] = <String, Object?>{
    'functionName': 'approve',
    'selector': '0x095ea7b3',
    'args': <String, Object?>{'spender': s83cContract, 'value': raw},
  };
  body['unsignedTransaction'] =
      s6UnsignedTransaction(data: _approveData(raw), to: s83cUsd1)
        ..['chainId'] = loopChainReference(loopLaunchTestnetChainId)
        ..['from'] = s83cWalletAddress;
  return body;
}

LoopWalletIntent _approvalIntent({String state = 'awaiting_signature'}) =>
    LoopV2IntentCodec.intent(_approvalBody(state: state));

LaunchDetail _testnetDetail() => s83cDetail(chainId: loopLaunchTestnetChainId);

LoopWalletBalances _balances({String allowance = _fiveHundred}) =>
    s83cBalances(chainId: loopLaunchTestnetChainId, allowance: allowance);

Future<void> _pump(
  WidgetTester tester, {
  FakeLaunchGateway? launch,
  FakeWalletDirectory? balances,
  _ApprovalIntents? intents,
  _RecordingWallet? wallet,
  LaunchAllowancePolling? polling,
}) => pumpS7Page(
  tester,
  LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow),
  launch:
      launch ??
      FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(value: _testnetDetail()),
      ),
  wallet:
      balances ??
      FakeWalletDirectory(
        activeWalletId: s7WalletId,
        wallets: [s83cWallet()],
        balances: [_balances()],
      ),
  meta: s7MetaSnapshot(launchEvidencePending: false),
  overrides: [
    if (intents != null)
      walletIntentsGatewayProvider.overrideWithValue(intents),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
    if (polling != null)
      launchAllowancePollingProvider.overrideWithValue(polling),
  ],
);

FakeWalletDirectory _directory({
  List<LoopWalletBalances>? balances,
  LoopChainFailureKind? failure,
  bool pending = false,
}) => FakeWalletDirectory(
  activeWalletId: s7WalletId,
  wallets: [s83cWallet()],
  balances: balances,
  balancesFailure: failure,
  balancesPending: pending,
);

Future<void> _choose(WidgetTester tester, {String amount = '500'}) async {
  await tester.tap(_key('launch-round-1'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('launch-trade-amount'), amount);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await _choose(tester);
  await scrollToS7Section(tester, _key('launch-trade-submit'));
  await tester.tap(_key('launch-trade-submit'));
  await tester.pumpAndSettle();
}

VoidCallback? _pressed(WidgetTester tester, String key) =>
    tester.widget<LoopButton>(_key(key)).onPressed;

String _noticeBody(WidgetTester tester, String key) =>
    tester.widget<LoopNotice>(_key(key)).body!;

// ---------------------------------------------------------------------------
// transport · Launch API
// ---------------------------------------------------------------------------

const _requestId = '11111111-2222-4333-8444-555555555555';
const _idempotencyKey = '66666666-7777-4888-8999-aaaaaaaaaaaa';

final class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;
  RequestOptions? seen;
  Object? sentBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    sentBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }
}

(LoopV2LaunchApi, _Adapter) _launchApi(int status, Object? body) {
  final adapter = _Adapter(statusCode: status, body: body);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
    ..httpClientAdapter = adapter;
  return (DioLoopV2LaunchApi(dio), adapter);
}

Map<String, Object?> _error(int status, String code, String reasonCode) =>
    <String, Object?>{
      'code': code,
      'category': status == 422 ? 'validation' : 'conflict',
      'retryable': false,
      'userMessageKey': 'errors.launch.intent',
      'correlationId': _requestId,
      'detailsSafe': <String, Object?>{'reasonCode': reasonCode},
      'providerReferenceSafe': null,
    };

/// The OpenAPI `201` example with every S83b optional key present.
Map<String, Object?> _intentBody({
  bool optional = true,
  String state = 'awaiting_signature',
  Object? transactionHash,
}) => <String, Object?>{
  'launchIntent': <String, Object?>{
    'launchIntentId': s83cIntentId,
    'state': state,
    'launchId': s7LaunchId,
    'projectId': s7ProjectId,
    'walletId': s7WalletId,
    'roundId': s7RoundId,
    'roundIndex': 1,
    'chainId': loopLaunchTestnetChainId,
    'contractAddress': s83cContract,
    'quoteAssetId': '$loopLaunchTestnetChainId:$s83cUsd1',
    'usd1Amount': _fiveHundred,
    'expectedTokenAmount': '50000000000000000000000',
    'minTokenAmount': '49500000000000000000000',
    'walletCumulativeUsd1': _oneHundred,
    'deadline': '2026-09-22T15:00:00.000Z',
    'eligibilityProof': <Object?>[],
    'configVersion': s83cConfigVersion,
    'stateTupleDigest': s83cDigest,
    'snapshotBlockNumber': '45000000',
    'snapshotBlockHash': s83cBlockHash,
    'payloadDigest': 'ab' * 32,
    'unsignedTransaction': <String, Object?>{
      'chainId': loopChainReference(loopLaunchTestnetChainId),
      'to': s83cContract,
      'data': '0x${'00' * 36}',
      'value': '0x0',
      if (optional) ...<String, Object?>{
        'from': s83cWalletAddress,
        'gas': '0x1d4c0',
        'nonce': '0x3',
        'type': 'legacy',
        'maxFeePerGas': null,
        'maxPriorityFeePerGas': null,
        'gasPrice': '0x3b9aca00',
      },
    },
    'expiresAt': '2026-09-22T14:05:00.000Z',
    'createdAt': '2026-09-22T14:00:00.000Z',
    if (optional) ...<String, Object?>{
      'projectAssetId': '$loopLaunchTestnetChainId:$s83cProjectToken',
      'saleId': '7',
      'walletRoundCapUsd1': _fiveHundred,
      'walletProjectCapUsd1': '1000000000000000000000',
      'transactionHash': transactionHash,
      'simulation': <String, Object?>{'status': 'passed', 'reasonCode': null},
      'policy': <String, Object?>{
        'configVersion': 'bscWriteCanaryV1',
        'canaryMaxUsd': '5',
        'valueUsd': '500',
        'priceSource': 'usd1_par',
      },
      'signing': <String, Object?>{
        'mode': 'device_eth_send_transaction',
        'allowed': state == 'awaiting_signature',
        'reasonCode': state == 'awaiting_signature'
            ? null
            : 'LAUNCH_INTENT_ALREADY_REPORTED',
      },
    },
  },
  'contractVersion': '2.0',
};

Future<LaunchPurchasePrepared> _prepare(LoopV2LaunchApi api) =>
    api.postPurchaseIntent(
      accessToken: 'token',
      clientVersion: '1.4.0',
      idempotencyKey: _idempotencyKey,
      launchId: s7LaunchId,
      walletId: s7WalletId,
      roundId: s7RoundId,
      payAmount: '500',
    );

Future<LaunchPurchaseIntent> _report(LoopV2LaunchApi api, String hash) =>
    api.postPurchaseBroadcastReport(
      accessToken: 'token',
      clientVersion: '1.4.0',
      idempotencyKey: _idempotencyKey,
      launchId: s7LaunchId,
      launchIntentId: s83cIntentId,
      txHash: hash,
    );

Matcher _invalidPayload() => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

// ---------------------------------------------------------------------------
// transport · wallet balances
// ---------------------------------------------------------------------------

Map<String, Object?> _launchChainWire({Object? usd1 = _absent}) =>
    <String, Object?>{
      'chainId': loopLaunchTestnetChainId,
      'availability': 'available',
      'reasonCode': null,
      'nativeBalance': <String, Object?>{
        'assetId': '$loopLaunchTestnetChainId:native',
        'symbol': 'tBNB',
        'logo': <String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'TOKEN_LOGO_CHAIN_UNSUPPORTED',
        },
        'decimals': 18,
        'rawValue': '2500000000000000000',
        'displayBalance': '2.5',
        'availableBalance': '2.5',
        'spendableBalance': '2.495',
        'gasReserve': '0.005',
        'snapshot': <String, Object?>{
          'blockNumber': '52000000',
          'blockHash': s5BlockHash,
          'observedAt': '2026-09-09T10:45:05.000Z',
          'confirmations': 5,
        },
      },
      if (!identical(usd1, _absent)) 'usd1': usd1,
    };

const Object _absent = Object();

Future<LoopWalletBalances> _readBalances(Map<String, Object?> body) =>
    DioLoopV2WalletApi(
      s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
    ).getBalances(
      accessToken: 'token',
      clientVersion: s5ClientVersion,
      walletId: s5WalletId,
    );

void main() {
  loopWatchGround();

  group('balances · launchChain.usd1 is read strictly', () {
    test('an old response without usd1 decodes exactly as before', () async {
      final old = await _readBalances(
        s5BalancesBody()..['launchChain'] = _launchChainWire(),
      );
      final slot = old.launchChain!;
      expect(slot.usd1, isNull);
      expect(slot.chainId, loopLaunchTestnetChainId);
      expect(slot.available, isTrue);
      expect(slot.nativeBalance!.rawValue, '2500000000000000000');
      expect(old.balances.single.assetId, s5NativeAssetId);
      // No Launch block at all is still no Launch block.
      expect((await _readBalances(s5BalancesBody())).launchChain, isNull);
    });

    test('usd1 carries the balance and the allowance verbatim', () async {
      final read = await _readBalances(
        s5BalancesBody()
          ..['launchChain'] = _launchChainWire(
            usd1: <String, Object?>{
              'balance': '7000000000000000000',
              'allowance': '5000000000000000000',
            },
          ),
      );
      expect(read.launchChain!.usd1!.balance, '7000000000000000000');
      expect(read.launchChain!.usd1!.allowance, '5000000000000000000');
    });

    test('null, a lone half, a number or an extra key is refused', () {
      for (final usd1 in <Object?>[
        null,
        <String, Object?>{'balance': '1'},
        <String, Object?>{'balance': '1', 'allowance': 5},
        <String, Object?>{'balance': '1', 'allowance': '01'},
        <String, Object?>{'balance': '1', 'allowance': '1', 'block': '9'},
      ]) {
        expect(
          () => _readBalances(
            s5BalancesBody()..['launchChain'] = _launchChainWire(usd1: usd1),
          ),
          _invalidPayload(),
          reason: '$usd1',
        );
      }
    });
  });

  group('purchase intent · the optional S83b keys', () {
    test('every optional key decodes to the OpenAPI shape', () async {
      final (api, _) = _launchApi(201, _intentBody());
      final intent = (await _prepare(api)).intent;
      expect(intent.walletRoundCapUsd1, _fiveHundred);
      expect(intent.walletProjectCapUsd1, '1000000000000000000000');
      expect(intent.saleId, '7');
      expect(
        intent.projectAssetId,
        '$loopLaunchTestnetChainId:$s83cProjectToken',
      );
      expect(intent.transactionHash, isNull);
      expect(intent.simulation!.status, LaunchSimulationStatus.passed);
      expect(intent.policy!.valueUsd, '500');
      expect(intent.signing!.allowed, isTrue);
      expect(intent.canSignAt(s83cNow()), isTrue);
    });

    test('the transaction keys reach the wallet exactly as sent', () async {
      final (api, _) = _launchApi(201, _intentBody());
      final wire = (await _prepare(api)).intent.unsignedTransaction.toWire();
      expect(wire, <String, Object?>{
        'chainId': 97,
        'to': s83cContract,
        'data': '0x${'00' * 36}',
        'value': '0x0',
        'from': s83cWalletAddress,
        'gas': '0x1d4c0',
        'nonce': '0x3',
        'type': 'legacy',
        'maxFeePerGas': null,
        'maxPriorityFeePerGas': null,
        'gasPrice': '0x3b9aca00',
      });
      // Absent stays absent: nothing is added to an S83a-shaped call.
      final (bare, _) = _launchApi(201, _intentBody(optional: false));
      expect(
        (await _prepare(bare)).intent.unsignedTransaction.toWire().keys,
        <String>['chainId', 'to', 'data', 'value'],
      );
    });

    test('an optional key off its schema is refused', () {
      void refuses(void Function(Map<String, Object?> intent) change) {
        final body = _intentBody();
        change(body['launchIntent']! as Map<String, Object?>);
        final (api, _) = _launchApi(201, body);
        expect(() => _prepare(api), _invalidPayload());
      }

      refuses((intent) => intent['walletRoundCapUsd1'] = 500);
      refuses((intent) => intent['saleId'] = '07');
      refuses(
        (intent) => intent['simulation'] = <String, Object?>{
          'status': 'passed',
          'reasonCode': null,
          'gas': '1',
        },
      );
      refuses(
        (intent) => (intent['signing']! as Map<String, Object?>)['mode'] =
            'privy_authorization_signature',
      );
      refuses(
        (intent) =>
            (intent['unsignedTransaction']! as Map<String, Object?>)['gas'] =
                '0x01',
      );
      refuses(
        (intent) =>
            (intent['unsignedTransaction']! as Map<String, Object?>)['type'] =
                'eip2930',
      );
      refuses((intent) => intent['transactionHash'] = '0x12');
    });

    test('the server permission closes signing on its own', () async {
      final body = _intentBody();
      (((body['launchIntent']! as Map<String, Object?>)['signing'])!
            as Map<String, Object?>)
        ..['allowed'] = false
        ..['reasonCode'] = 'LAUNCH_SIMULATION_REVERTED';
      final (api, _) = _launchApi(201, body);
      final intent = (await _prepare(api)).intent;
      expect(intent.canSignAt(s83cNow()), isFalse);
      expect(
        LaunchPurchaseSigner.refusalBeforeWallet(
          intent,
          fromAddress: s83cWalletAddress,
          now: s83cNow(),
        ),
        'LAUNCH_SIMULATION_REVERTED',
      );
    });

    test('a call built for another wallet is refused before signing', () {
      final intent = s83cIntent(
        transactionOptional: const <String, Object?>{
          'from': '0x5555555555555555555555555555555555555555',
        },
      );
      expect(
        LaunchPurchaseSigner.refusalBeforeWallet(
          intent,
          fromAddress: s83cWalletAddress,
          now: s83cNow(),
        ),
        'LAUNCH_WALLET_ADDRESS_MISMATCH',
      );
    });

    test('the three funding refusals keep their reason codes', () async {
      for (final code in launchFundingReasonCodes) {
        final (api, _) = _launchApi(
          409,
          _error(409, 'INSUFFICIENT_BALANCE', code),
        );
        await expectLater(
          _prepare(api),
          throwsA(
            isA<LoopBackendFailure>()
                .having((f) => f.code, 'code', 'INSUFFICIENT_BALANCE')
                .having((f) => f.detailsSafe?.reasonCode, 'reason', code)
                .having(
                  (f) => launchFailureKindForV2(f, write: true),
                  'kind',
                  LaunchFailureKind.insufficientBalance,
                ),
          ),
        );
      }
    });
  });

  group('broadcast report · transport', () {
    final hash = s83cTxHash;

    test(
      'a report posts the hash and reads back the submitted intent',
      () async {
        final (api, adapter) = _launchApi(
          200,
          _intentBody(state: 'submitted', transactionHash: hash),
        );
        final intent = await _report(api, hash);
        expect(
          adapter.seen!.path,
          '/v2/launch/$s7LaunchId/intents/$s83cIntentId/broadcast-report',
        );
        expect(adapter.seen!.headers['idempotency-key'], _idempotencyKey);
        expect(adapter.sentBody, <String, Object?>{'txHash': hash});
        expect(intent.state, LaunchIntentState.submitted);
        expect(intent.transactionHash, hash);
        expect(intent.canSignAt(s83cNow()), isFalse);
      },
    );

    test('an answer about another hash is not an answer', () {
      final (api, _) = _launchApi(
        200,
        _intentBody(state: 'submitted', transactionHash: '0x${'77' * 32}'),
      );
      expect(() => _report(api, hash), _invalidPayload());
    });

    test('the four refusals keep their reason codes', () async {
      for (final (status, code, reason) in <(int, String, String)>[
        (409, 'DATA_STALE', 'LAUNCH_INTENT_ALREADY_REPORTED'),
        (409, 'DATA_STALE', 'LAUNCH_INTENT_NOT_SIGNABLE'),
        (409, 'DATA_STALE', 'LAUNCH_INTENT_EXPIRED'),
        (422, 'VALIDATION_FAILED', 'LAUNCH_TX_PAYLOAD_MISMATCH'),
      ]) {
        final (api, _) = _launchApi(status, _error(status, code, reason));
        await expectLater(
          _report(api, hash),
          throwsA(
            isA<LoopBackendFailure>()
                .having((f) => f.code, 'code', code)
                .having((f) => f.detailsSafe?.reasonCode, 'reason', reason),
          ),
        );
      }
    });
  });

  group('wallet intents · the Launch USD1 approval', () {
    test('an approve on the Launch slot decodes and matches its review', () {
      final intent = _approvalIntent();
      expect(intent.chainId, loopLaunchTestnetChainId);
      expect(intent.unsignedTransaction!.chainId, 97);
      expect(intent.payloadMatchesReview, isTrue);
      final signing = MoneyActionSigner.toSigningIntent(intent)!;
      expect(signing.kind, IntentKind.launchApproval);
      expect(signing.chainIsPermitted, isTrue);
    });

    test('a send on the Launch slot is still refused', () {
      final body = s6IntentBody()..['chainId'] = loopLaunchTestnetChainId;
      (body['unsignedTransaction']! as Map<String, Object?>)['chainId'] = 97;
      expect(
        () => LoopV2IntentCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a payload or an asset on another chain is refused', () {
      final primaryPayload = _approvalBody();
      (primaryPayload['unsignedTransaction']!
              as Map<String, Object?>)['chainId'] =
          56;
      expect(
        () => LoopV2IntentCodec.intent(primaryPayload),
        throwsA(isA<LoopBackendFailure>()),
      );
      final primaryAsset = _approvalBody();
      ((primaryAsset['review']! as Map<String, Object?>)['asset']!
              as Map<String, Object?>)['assetId'] =
          'eip155:56:$s83cUsd1';
      expect(
        () => LoopV2IntentCodec.intent(primaryAsset),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a wallet approval kind never leaves the primary chain', () {
      SigningIntent approval(IntentKind kind) => SigningIntent.backendCanonical(
        revision: s6IntentId,
        payloadDigest: 'a' * 64,
        title: '确认授权',
        kind: kind,
        chainId: loopLaunchTestnetChainId,
        payload: const DeviceTransactionPayload(
          fromAddress: s83cWalletAddress,
          transaction: <String, Object?>{'chainId': 97},
        ),
        observedAt: DateTime.utc(2026, 9, 22, 14),
        expiresAt: DateTime.utc(2026, 9, 22, 14, 5),
        fields: const <IntentField>[],
      );
      expect(approval(IntentKind.approval).chainIsPermitted, isFalse);
      expect(approval(IntentKind.launchApproval).chainIsPermitted, isTrue);
    });

    test('an amount is exact base units with at most 18 decimals', () {
      expect(launchUsd1Units('500'), BigInt.parse(_fiveHundred));
      expect(launchUsd1Units('0.5'), BigInt.parse('500000000000000000'));
      expect(
        launchUsd1Units('1.000000000000000001'),
        BigInt.parse(s83cOne) + BigInt.one,
      );
      expect(launchUsd1Units('1.0000000000000000001'), isNull);
      expect(launchUsd1Units('0'), isNull);
      expect(launchUsd1Units('01'), isNull);
      expect(launchUsd1Units(null), isNull);
    });
  });

  group('launch-trade · the approval gate', () {
    testWidgets('loading · the allowance is being read', (tester) async {
      await _pump(tester, balances: _directory(pending: true));
      await _choose(tester);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '正在读取授权状态',
      );
      expect(_pressed(tester, 'launch-trade-submit'), isNull);
      expect(_key('launch-trade-approve'), findsNothing);
    });

    testWidgets('empty · a missing usd1 is 授权状态未读取 and closes buying', (
      tester,
    ) async {
      final directory = _directory(
        balances: [
          s83cBalances(chainId: loopLaunchTestnetChainId, usd1: false),
          _balances(),
        ],
      );
      await _pump(tester, balances: directory);
      await _choose(tester);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权状态未读取',
      );
      expect(_pressed(tester, 'launch-trade-submit'), isNull);
      expect(find.textContaining('授权额度 未读取'), findsOneWidget);
      expect(find.textContaining('授权状态未读取，本页不猜测'), findsOneWidget);

      // Re-reading is the only way forward; nothing is guessed meanwhile.
      await scrollToS7Section(tester, _key('launch-trade-allowance-reread'));
      await tester.tap(_key('launch-trade-allowance-reread'));
      await tester.pumpAndSettle();
      expect(_key('launch-trade-allowance-notice'), findsNothing);
      expect(_pressed(tester, 'launch-trade-submit'), isNotNull);
    });

    testWidgets('a Launch block for another chain is not this reading', (
      tester,
    ) async {
      await _pump(tester, balances: _directory(balances: [s83cBalances()]));
      await _choose(tester);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权状态未读取',
      );
      expect(_pressed(tester, 'launch-trade-submit'), isNull);
    });

    for (final (failure, phrase) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.readFailed, '这一页暂时读不到'),
      (LoopChainFailureKind.offline, '设备已离线'),
      (LoopChainFailureKind.permissionDenied, '没有执行这个操作的权限'),
    ]) {
      testWidgets('${failure.name} · the read failure is stated, never zero', (
        tester,
      ) async {
        await _pump(tester, balances: _directory(failure: failure));
        await _choose(tester);
        final body = _noticeBody(tester, 'launch-trade-allowance-notice');
        expect(body, contains(phrase));
        expect(body, contains('授权额度读到之前不能购买'));
        expect(_pressed(tester, 'launch-trade-submit'), isNull);
        expect(find.textContaining('授权额度 0'), findsNothing);
      });
    }

    testWidgets('an allowance below the amount turns the action into approve', (
      tester,
    ) async {
      await _pump(
        tester,
        balances: _directory(balances: [_balances(allowance: _oneHundred)]),
      );
      await _choose(tester);
      expect(_key('launch-trade-submit'), findsNothing);
      expect(
        tester.widget<LoopButton>(_key('launch-trade-approve')).label,
        '先授权 USD1',
      );
      final body = _noticeBody(tester, 'launch-trade-allowance-notice');
      expect(body, contains('当前授权 100 USD1'));
      expect(body, contains('本次需要 500 USD1'));
      expect(body, contains('不是无限额度'));
      // A smaller amount the allowance covers is a purchase again.
      await tester.enterText(_key('launch-trade-amount'), '100');
      await tester.pumpAndSettle();
      expect(_key('launch-trade-approve'), findsNothing);
      expect(_pressed(tester, 'launch-trade-submit'), isNotNull);
    });

    testWidgets(
      'approve signs the exact amount, polls, then opens the purchase',
      (tester) async {
        final intents = _ApprovalIntents();
        final wallet = _RecordingWallet(
          WalletHandoffResult(
            accepted: true,
            code: 'wallet_accepted',
            value: _approveHash,
          ),
        );
        final directory = _directory(
          balances: [
            _balances(allowance: _oneHundred),
            _balances(allowance: _oneHundred),
            _balances(),
          ],
        );
        await _pump(
          tester,
          balances: directory,
          intents: intents,
          wallet: wallet,
          polling: const LaunchAllowancePolling(interval: Duration(seconds: 1)),
        );
        await _choose(tester);
        await scrollToS7Section(tester, _key('launch-trade-approve'));
        await tester.tap(_key('launch-trade-approve'));
        await tester.pumpAndSettle();

        // The existing approval intent, for this amount and no more, on the
        // Launch slot, with the Launch contract as the spender.
        expect(intents.approvals, <String>[
          '$s7WalletId|$loopLaunchTestnetChainId:$s83cUsd1|'
              '$s83cContract|exact:500',
        ]);
        expect(_key('money-sign-sheet'), findsOneWidget);
        expect(find.text(loopTestnetBadgeLabel), findsWidgets);

        await tester.tap(find.text('确认签名'));
        await tester.pumpAndSettle();
        final handed = wallet.handed.single;
        expect(handed.kind, IntentKind.launchApproval);
        expect(handed.chainId, loopLaunchTestnetChainId);
        expect(intents.reports, <String>[_approveHash]);
        // The shared sheet says what happened: a broadcast.
        expect(find.text('已广播'), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        // First read after the broadcast: still short, so the page waits.
        expect(
          tester
              .widget<LoopNotice>(_key('launch-trade-allowance-notice'))
              .title,
          '等待授权到账',
        );
        expect(_pressed(tester, 'launch-trade-approve'), isNull);
        expect(
          tester.widget<TextField>(_key('launch-trade-amount')).enabled,
          isFalse,
        );

        // The next read sees the allowance and the purchase opens.
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(directory.balanceReads, 3);
        expect(_key('launch-trade-approve'), findsNothing);
        expect(_pressed(tester, 'launch-trade-submit'), isNotNull);
        expect(find.textContaining('授权额度 500 USD1'), findsOneWidget);
      },
    );

    testWidgets('a broadcast approval that never lands times out honestly', (
      tester,
    ) async {
      final directory = _directory(
        balances: [
          _balances(allowance: _oneHundred),
          _balances(allowance: _oneHundred),
          _balances(allowance: _oneHundred),
          _balances(allowance: _oneHundred),
          _balances(),
        ],
      );
      await _pump(
        tester,
        balances: directory,
        intents: _ApprovalIntents(),
        wallet: _RecordingWallet(
          WalletHandoffResult(accepted: true, code: 'ok', value: _approveHash),
        ),
        polling: const LaunchAllowancePolling(
          interval: Duration(seconds: 1),
          maxAttempts: 2,
        ),
      );
      await _choose(tester);
      await scrollToS7Section(tester, _key('launch-trade-approve'));
      await tester.tap(_key('launch-trade-approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权额度还没有更新',
      );
      // No second approval is offered while the first may still land.
      expect(_pressed(tester, 'launch-trade-approve'), isNull);
      await scrollToS7Section(tester, _key('launch-trade-allowance-reread'));
      await tester.tap(_key('launch-trade-allowance-reread'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_pressed(tester, 'launch-trade-submit'), isNotNull);
    });

    testWidgets('an approval the chain reverted is stated, and may retry', (
      tester,
    ) async {
      await _pump(
        tester,
        balances: _directory(balances: [_balances(allowance: '0')]),
        intents: _ApprovalIntents(reported: _approvalIntent(state: 'reverted')),
        wallet: _RecordingWallet(
          WalletHandoffResult(accepted: true, code: 'ok', value: _approveHash),
        ),
      );
      await _choose(tester);
      await scrollToS7Section(tester, _key('launch-trade-approve'));
      await tester.tap(_key('launch-trade-approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权没有生效',
      );
      expect(_pressed(tester, 'launch-trade-approve'), isNotNull);
      expect(_key('launch-trade-submit'), findsNothing);
    });

    testWidgets('permission · a refused approval names its rule', (
      tester,
    ) async {
      final intents = _ApprovalIntents(
        prepareFailure: const LoopChainException(
          LoopChainFailureKind.permissionDenied,
          reasonCode: 'CANARY_CEILING_EXCEEDED',
          exposureUsd: '500',
          ceilingUsd: '5',
        ),
      );
      await _pump(
        tester,
        balances: _directory(balances: [_balances(allowance: '0')]),
        intents: intents,
      );
      await _choose(tester);
      await scrollToS7Section(tester, _key('launch-trade-approve'));
      await tester.tap(_key('launch-trade-approve'));
      await tester.pumpAndSettle();
      expect(_key('money-sign-sheet'), findsNothing);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权没有准备成功',
      );
      expect(
        _noticeBody(tester, 'launch-trade-allowance-notice'),
        contains('单笔金额上限'),
      );
      // A refusal submitted nothing, so the approval may be asked again.
      expect(_pressed(tester, 'launch-trade-approve'), isNotNull);
    });

    testWidgets('error · a wallet refusal submits nothing and may retry', (
      tester,
    ) async {
      final intents = _ApprovalIntents();
      await _pump(
        tester,
        balances: _directory(balances: [_balances(allowance: '0')]),
        intents: intents,
        wallet: _RecordingWallet(
          const WalletHandoffResult.rejected('privy_chain_switch_unsupported'),
        ),
      );
      await _choose(tester);
      await scrollToS7Section(tester, _key('launch-trade-approve'));
      await tester.tap(_key('launch-trade-approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(intents.reports, isEmpty);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-allowance-notice')).title,
        '授权没有签名',
      );
      expect(_pressed(tester, 'launch-trade-approve'), isNotNull);
    });
  });

  group('launch-trade · the three funding refusals', () {
    Future<FakeWalletDirectory> refuse(WidgetTester tester, String code) async {
      final directory = _directory(balances: [_balances()]);
      await _pump(
        tester,
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: _testnetDetail()),
          intentFailure: LaunchFailureKind.insufficientBalance,
          intentReasonCode: code,
        ),
        balances: directory,
        intents: _ApprovalIntents(),
      );
      await _submit(tester);
      return directory;
    }

    testWidgets('allowance · the server wins and the action is approve', (
      tester,
    ) async {
      final directory = await refuse(tester, launchAllowanceInsufficientCode);
      expect(
        _noticeBody(tester, 'launch-trade-refusal'),
        contains('USD1 授权额度不足以支付这次认购'),
      );
      // The balances were re-read, and even a reading that says "enough" is
      // older than the server's answer: approval comes first.
      expect(directory.balanceReads, greaterThan(1));
      expect(_key('launch-trade-submit'), findsNothing);
      expect(_pressed(tester, 'launch-trade-approve'), isNotNull);
      expect(
        _key('launch-trade-funding-$launchAllowanceInsufficientCode'),
        findsNothing,
      );
    });

    testWidgets('balance · says USD1 is short and re-reads the balance', (
      tester,
    ) async {
      final directory = await refuse(tester, launchBalanceInsufficientCode);
      expect(
        _noticeBody(tester, 'launch-trade-refusal'),
        contains('USD1 余额不足'),
      );
      final guidance = _key(
        'launch-trade-funding-$launchBalanceInsufficientCode',
      );
      expect(guidance, findsOneWidget);
      expect(
        find.descendant(
          of: guidance,
          matching: find.textContaining('USD1 余额 900 USD1'),
        ),
        findsOneWidget,
      );
      final before = directory.balanceReads;
      await scrollToS7Section(tester, _key('launch-trade-funding-reread'));
      await tester.tap(_key('launch-trade-funding-reread'));
      await tester.pumpAndSettle();
      expect(directory.balanceReads, before + 1);
    });

    testWidgets('gas · says the network fee is short, with the native read', (
      tester,
    ) async {
      await refuse(tester, launchGasInsufficientCode);
      expect(_noticeBody(tester, 'launch-trade-refusal'), contains('不足以支付网络费'));
      final guidance = _key('launch-trade-funding-$launchGasInsufficientCode');
      expect(
        find.descendant(
          of: guidance,
          matching: find.textContaining('网络费余额 2.5 tBNB'),
        ),
        findsOneWidget,
      );
    });

    test('each funding refusal has its own sentence', () {
      final texts = <String>{
        for (final code in launchFundingReasonCodes)
          launchPurchaseRefusalText(
            LaunchFailureKind.insufficientBalance,
            code,
          ),
      };
      expect(texts, hasLength(3));
      for (final code in launchFundingReasonCodes) {
        expect(launchUnexplainedReasonCode(code), isNull);
      }
    });
  });

  group('launch-trade · the broadcast report', () {
    Future<(FakeLaunchGateway, _RecordingWallet)> signWith(
      WidgetTester tester, {
      LaunchPurchaseIntent? reported,
      LaunchFailureKind? failure,
      String? reason,
    }) async {
      final gateway = FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(value: _testnetDetail()),
        prepared: LaunchPurchasePrepared(
          intent: s83cIntent(
            chainId: loopLaunchTestnetChainId,
            walletRoundCapUsd1: _fiveHundred,
          ),
        ),
        reported: reported,
        reportFailure: failure,
        reportReasonCode: reason,
      );
      final wallet = _RecordingWallet(
        WalletHandoffResult(accepted: true, code: 'ok', value: s83cTxHash),
      );
      await _pump(tester, launch: gateway, wallet: wallet);
      await _submit(tester);
      // Both the paid-so-far and the server's round cap are shown before
      // signing.
      expect(
        tester.widget<LoopRecordRow>(_key('launch-review-钱包已累计')).trailing,
        '0 USD1',
      );
      expect(
        tester.widget<LoopRecordRow>(_key('launch-review-本轮钱包上限')).trailing,
        '500 USD1',
      );
      await scrollToS7Section(tester, _key('launch-trade-sign'));
      await tester.tap(_key('launch-trade-sign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      return (gateway, wallet);
    }

    testWidgets('a recorded broadcast shows the server state, not success', (
      tester,
    ) async {
      final (gateway, _) = await signWith(
        tester,
        reported: s83cIntent(
          chainId: loopLaunchTestnetChainId,
          state: LaunchIntentState.submitted,
          transactionHash: s83cTxHash,
        ),
      );
      expect(gateway.reports, <String>['$s83cIntentId:$s83cTxHash']);
      expect(find.text('已广播'), findsOneWidget);
      expect(find.text('已完成'), findsNothing);
      expect(find.textContaining('广播不代表已成交'), findsWidgets);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-locked')).title,
        '已广播 · 已提交，等待链上索引',
      );
      expect(_key('launch-trade-report-retry'), findsNothing);
      expect(_key('launch-trade-sign'), findsNothing);
      expect(find.textContaining('成功'), findsNothing);
    });

    for (final (code, phrase) in <(String, String)>[
      ('LAUNCH_INTENT_ALREADY_REPORTED', '已经上报过另一笔交易'),
      ('LAUNCH_INTENT_NOT_SIGNABLE', '不再接受这笔认购的上报'),
      ('LAUNCH_INTENT_EXPIRED', '链上暂时还看不到这笔交易'),
      ('LAUNCH_TX_PAYLOAD_MISMATCH', '与签名时复核的认购内容不一致'),
    ]) {
      testWidgets('$code · a refused report stays locked with its sentence', (
        tester,
      ) async {
        await signWith(tester, failure: LaunchFailureKind.stale, reason: code);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        final body = _noticeBody(tester, 'launch-trade-locked');
        expect(body, contains(phrase));
        expect(body, contains('不要重复签名'));
        expect(body, isNot(contains(code)));
        // The server's answer is final for this intent: no re-report, and
        // never a second signature.
        expect(_key('launch-trade-report-retry'), findsNothing);
        expect(_key('launch-trade-sign'), findsNothing);
      });
    }

    testWidgets('a report that did not land can be sent again, same hash', (
      tester,
    ) async {
      final (gateway, _) = await signWith(
        tester,
        failure: LaunchFailureKind.offline,
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(_noticeBody(tester, 'launch-trade-locked'), contains('可以稍后重新上报'));
      await scrollToS7Section(tester, _key('launch-trade-report-retry'));
      await tester.tap(_key('launch-trade-report-retry'));
      await tester.pumpAndSettle();
      expect(gateway.reports, <String>[
        '$s83cIntentId:$s83cTxHash',
        '$s83cIntentId:$s83cTxHash',
      ]);
      expect(_key('launch-trade-sign'), findsNothing);
    });

    test('history-side states read as the server states them', () {
      expect(LaunchIntentState.submitted.label, '已提交，等待链上索引');
      expect(LaunchIntentState.confirmed.label, '已确认');
      expect(LaunchIntentState.reverted.label, '链上已回滚');
      expect(LaunchIntentState.expired.label, '已过期');
    });
  });

  group('copy', () {
    testWidgets('launch-holders counts participants, not holders', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchHoldersScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          holders: S7Answer<LaunchHolders>(value: s83cHolders()),
        ),
      );
      expect(find.text('1,842 位参与者'), findsOneWidget);
      expect(find.textContaining('位持有人'), findsNothing);
      expect(find.textContaining('不是当前持币人数'), findsOneWidget);
    });

    testWidgets('the shared sign sheet says 已广播 after a broadcast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopSignSheet(
              state: LoopSignSheetState.complete,
              facts: <LoopSignFact>[],
              reason: '广播不代表已成交。',
            ),
          ),
        ),
      );
      expect(find.text('已广播'), findsOneWidget);
      expect(find.text('已完成'), findsNothing);
      expect(find.text('广播不代表已成交。'), findsOneWidget);
    });
  });
}
