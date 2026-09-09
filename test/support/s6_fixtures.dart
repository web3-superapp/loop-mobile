import 'dart:async';

import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

import 's5_fixtures.dart';

/// Wire and model fixtures for the step-6 money-action tests.
///
/// They are test inputs only. Every model here is produced by the real codec,
/// so a fixture that would break the frozen contract fails the test rather
/// than reaching a page.
const s6IntentId = '6a7b8c9d-0e1f-4a2b-8c3d-4e5f6a7b8c9d';
const s6OtherIntentId = '7b8c9d0e-1f2a-4b3c-8d4e-5f6a7b8c9d0e';
const s6QuoteId = '8c9d0e1f-2a3b-4c4d-8e5f-6a7b8c9d0e1f';
const s6Spender = '0x10ed43c718714eb63d5aa57b78b54704e256024e';
const s6SpenderChecksum = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const s6Recipient = '0x000000000000000000000000000000000000dead';
const s6RecipientChecksum = '0x000000000000000000000000000000000000dEaD';
const s6From = '0x8894e0a0c962cb723c1976a4421c95949be2d4e3';
const s6TxHash =
    '0x4f2a111111111111111111111111111111111111111111111111111111119c81';

/// `transfer(0x…dEaD, 10000000000000000)` — the exact call data the server
/// builds, so the review/payload cross-check has something real to verify.
const s6TransferData =
    '0xa9059cbb'
    '000000000000000000000000000000000000000000000000000000000000dead'
    '000000000000000000000000000000000000000000000000002386f26fc10000';

/// `approve(0x10ed…024e, 5000000000000000000)`.
const s6ApproveData =
    '0x095ea7b3'
    '00000000000000000000000010ed43c718714eb63d5aa57b78b54704e256024e'
    '0000000000000000000000000000000000000000000000004563918244f40000';

Map<String, Object?> s6Amount({
  String raw = '10000000000000000',
  String display = '0.01',
}) => <String, Object?>{'raw': raw, 'display': display};

Map<String, Object?> s6Asset({
  String assetId = s5WbnbAssetId,
  String symbol = 'WBNB',
}) => <String, Object?>{
  'assetId': assetId,
  'address': assetId == s5NativeAssetId
      ? null
      : assetId.substring(assetId.lastIndexOf(':') + 1),
  'symbol': symbol,
  'decimals': 18,
};

Map<String, Object?> s6Recipient_({
  bool isContract = false,
  bool isFirstRecipient = true,
}) => <String, Object?>{
  'address': s6Recipient,
  'checksumAddress': s6RecipientChecksum,
  'isContract': isContract,
  'isFirstRecipient': isFirstRecipient,
  'basis': 'indexed_erc20_transfers',
  'screening': s5Unavailable('GOPLUS_ADDRESS_SCREENING_NOT_CONFIGURED'),
};

Map<String, Object?> s6Fee() => <String, Object?>{
  'gasLimit': '41550',
  'type': 'eip1559',
  'maxFeePerGas': '50000000',
  'maxPriorityFeePerGas': '50000000',
  'gasPrice': null,
  'maximumFeeRaw': '2077500000000',
  'maximumFee': '0.0000020775',
  'observedAt': '2026-09-09T13:35:29.779Z',
};

Map<String, Object?> s6Balance() => <String, Object?>{
  'blockNumber': '120695250',
  'blockHash': s5BlockHash,
  'observedAt': '2026-09-09T13:35:28.315Z',
  'rawBalance': '882006596111096983278',
  'displayBalance': '882.006596111096983278',
  'rawNativeBalance': '87886581198398034814821',
  'gasReserveRaw': '5000000000000000',
};

Map<String, Object?> s6PriceImpact({
  String status = 'available',
  Object? value = '0.0025',
  String decision = 'allowed',
  Object? reasonCode,
}) => <String, Object?>{
  'status': status,
  'value': value,
  'decision': decision,
  'reasonCode': reasonCode,
  'marketValueUsd': '3.75',
  'estimatedOutputValueUsd': '3.74',
  'priceSource': 'dexscreener',
};

Map<String, Object?> s6SwapPolicy() => <String, Object?>{
  'configVersion': 'swapPolicyV1',
  'status': 'pendingProductConfirmation',
  'defaultSlippageBps': 50,
  'maximumSlippageBps': 300,
  'hardBlockPriceImpact': '0.05',
  'confirmPriceImpact': '0.01',
  'quoteTtlSeconds': 30,
};

Map<String, Object?> s6Quote({
  String expiresAt = '2026-09-09T13:36:00.000Z',
  Map<String, Object?>? priceImpact,
}) => <String, Object?>{
  'quoteId': s6QuoteId,
  'provider': 'privy',
  'amountType': 'exact_input',
  'inputAmount': s6Amount(raw: '5000000000000000', display: '0.005'),
  'estimatedOutputAmount': s6Amount(raw: '3740000', display: '3.74'),
  'minimumOutputAmount': s6Amount(raw: '3721300', display: '3.7213'),
  'slippageBps': 50,
  'gasEstimateRaw': '180000',
  'quotedAt': '2026-09-09T13:35:30.000Z',
  'expiresAt': expiresAt,
  'priceImpact': priceImpact ?? s6PriceImpact(),
  'platformFeeBps': null,
};

Map<String, Object?> s6QuoteBody({Map<String, Object?>? priceImpact}) =>
    <String, Object?>{
      'walletId': s5WalletId,
      'sourceAsset': s6Asset(),
      'destinationAsset': s6Asset(assetId: s5UsdtAssetId, symbol: 'USDT'),
      'quote': s6Quote(priceImpact: priceImpact),
      'policy': s6SwapPolicy(),
      'canary': <String, Object?>{
        'configVersion': 'bscWriteCanaryV1',
        'canaryMaxUsd': '20',
        'inputValueUsd': '3.75',
      },
      'contractVersion': '2.0',
    };

Map<String, Object?> s6PreflightBody({
  List<String> warnings = const <String>[
    'send.recipient.firstTime',
    'send.recipient.screeningUnavailable',
  ],
  bool isContract = false,
}) => <String, Object?>{
  'walletId': s5WalletId,
  'chainId': 'eip155:56',
  'recipient': s6Recipient_(isContract: isContract),
  'basis': 'indexed_erc20_transfers',
  'warnings': warnings,
  'contractVersion': '2.0',
};

/// The intent resource every prepare, report, execute and read answers with.
Map<String, Object?> s6IntentBody({
  String kind = 'send',
  String state = 'awaiting_signature',
  String simulationStatus = 'passed',
  Object? simulationReason,
  String simulationSource = 'rpc_call',
  bool signingAllowed = true,
  Object? signingReason,
  String signingMode = 'device_eth_send_transaction',
  String expiresAt = '2026-09-09T13:37:30.323Z',
  Object? unsignedTransaction = _unset,
  Object? authorizationPayload,
  Object? decodedCall = _unset,
  Object? recipient = _unset,
  Object? spender,
  Object? amount,
  Object? swap,
  Object? result,
  Object? policy,
  String intentId = s6IntentId,
}) => <String, Object?>{
  'intentId': intentId,
  'kind': kind,
  'state': state,
  'walletId': s5WalletId,
  'chainId': 'eip155:56',
  'review': <String, Object?>{
    'kind': kind,
    'asset': s6Asset(),
    'amount': amount ?? s6Amount(),
    'recipient': identical(recipient, _unset)
        ? (kind == 'send' ? s6Recipient_() : null)
        : recipient,
    'spender': spender,
    'decodedCall': identical(decodedCall, _unset)
        ? <String, Object?>{
            'functionName': 'transfer',
            'selector': '0xa9059cbb',
            'args': <String, Object?>{
              'to': s6Recipient,
              'value': '10000000000000000',
            },
          }
        : decodedCall,
    'fee': s6Fee(),
    'balance': s6Balance(),
    'swap': swap,
  },
  'reviewSha256': 'c' * 64,
  'factsObservedAt': '2026-09-09T13:35:30.323Z',
  'expiresAt': expiresAt,
  'simulation': <String, Object?>{
    'status': simulationStatus,
    'source': simulationSource,
    'observedAt': '2026-09-09T13:35:28.987Z',
    'reasonCode': simulationReason,
  },
  'policy':
      policy ??
      <String, Object?>{
        'configVersion': 'bscWriteCanaryV1',
        'canaryMaxUsd': '20',
        'exposureBasis': 'amount',
        'exposureRaw': '10000000000000000',
        'exposureBlockNumber': '120695250',
        'valueUsd': '7.50014',
        'priceSource': 'dexscreener',
        'priceFetchedAt': '2026-09-09T13:35:27.916Z',
      },
  'signing': <String, Object?>{
    'mode': signingMode,
    'allowed': signingAllowed,
    'reasonCode': signingReason,
  },
  'unsignedTransaction': identical(unsignedTransaction, _unset)
      ? s6UnsignedTransaction()
      : unsignedTransaction,
  'authorizationPayload': authorizationPayload,
  'result':
      result ??
      <String, Object?>{
        'transactionHash': null,
        'providerActionId': null,
        'reasonCode': null,
        'receipt': null,
      },
  'version': '1',
  'createdAt': '2026-09-09T13:35:30.323Z',
  'updatedAt': '2026-09-09T13:35:30.323Z',
  'contractVersion': '2.0',
};

const Object _unset = Object();

Map<String, Object?> s6UnsignedTransaction({
  String data = s6TransferData,
  String to = '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
  String value = '0x0',
}) => <String, Object?>{
  'chainId': 56,
  'from': s6From,
  'to': to,
  'data': data,
  'value': value,
  'gas': '0xa24e',
  'nonce': '0x360f772',
  'type': 'eip1559',
  'maxFeePerGas': '0x2faf080',
  'maxPriorityFeePerGas': '0x2faf080',
  'gasPrice': null,
};

Map<String, Object?> s6AuthorizationPayload() => <String, Object?>{
  'version': 1,
  'method': 'POST',
  'url': 'https://api.privy.io/v1/wallets/abc/swap',
  'body': <String, Object?>{
    'base_amount': '5000000000000000',
    'source': <String, Object?>{
      'asset_address': '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
      'caip2': 'eip155:56',
    },
    'destination': <String, Object?>{
      'asset_address': '0x55d398326f99059ff775485246999027b3197955',
      'caip2': 'eip155:56',
    },
    'amount_type': 'exact_input',
    'slippage_bps': 50,
  },
  'headers': <String, Object?>{
    'privy-app-id': 'privy-app',
    'privy-idempotency-key': s6IntentId,
    'privy-request-expiry': '1789000000000',
  },
};

/// The swap intent the backend produces today: no provider simulation, so it
/// stays `prepared` and can never be signed.
Map<String, Object?> s6SwapIntentBody({String state = 'prepared'}) =>
    s6IntentBody(
      kind: 'swap',
      state: state,
      simulationStatus: 'unavailable',
      simulationSource: 'provider_quote',
      simulationReason: 'SWAP_SIMULATION_PROVIDER_PENDING',
      signingAllowed: false,
      signingReason: 'SIMULATION_UNAVAILABLE',
      signingMode: 'privy_authorization_signature',
      unsignedTransaction: null,
      authorizationPayload: s6AuthorizationPayload(),
      decodedCall: null,
      recipient: null,
      amount: s6Amount(raw: '5000000000000000', display: '0.005'),
      swap: <String, Object?>{
        'destinationAsset': s6Asset(assetId: s5UsdtAssetId, symbol: 'USDT'),
        'quote': s6Quote(),
        'policy': s6SwapPolicy(),
      },
    );

Map<String, Object?> s6ApprovalIntentBody({
  String allowanceDisplay = '5',
  String allowanceRaw = '5000000000000000000',
  bool isUnlimited = false,
}) => s6IntentBody(
  kind: 'approve',
  amount: s6Amount(raw: allowanceRaw, display: allowanceDisplay),
  recipient: null,
  spender: <String, Object?>{
    'address': s6Spender,
    'checksumAddress': s6SpenderChecksum,
    'isContract': true,
    'isUnlimited': isUnlimited,
  },
  decodedCall: <String, Object?>{
    'functionName': 'approve',
    'selector': '0x095ea7b3',
    'args': <String, Object?>{'spender': s6Spender, 'value': allowanceRaw},
  },
  unsignedTransaction: s6UnsignedTransaction(data: s6ApproveData),
);

Map<String, Object?> s6ApprovalRowBody({
  bool unlimited = false,
  bool readable = true,
}) => <String, Object?>{
  'assetId': s5UsdtAssetId,
  'symbol': 'USDT',
  'decimals': 18,
  'spender': <String, Object?>{
    'address': s6Spender,
    'checksumAddress': s6SpenderChecksum,
  },
  'allowance': readable
      ? <String, Object?>{
          'status': 'available',
          'rawValue': unlimited
              ? '11579208923731619542357098500868790785326998466564056403945758400791312963993'
              : '5000000000000000000',
          'displayValue': unlimited ? 'unlimited' : '5',
          'isUnlimited': unlimited,
          'blockNumber': '120695250',
          'blockHash': s5BlockHash,
          'observedAt': '2026-09-09T13:35:28.315Z',
        }
      : s5Unavailable('ALLOWANCE_READ_FAILED'),
  'lastApproval': <String, Object?>{
    'transactionHash': s5TxHash,
    'blockNumber': '120600000',
    'rawValue': '5000000000000000000',
    'observedAt': '2026-09-08T13:35:28.315Z',
  },
  'riskFacts': s5Unavailable('GOPLUS_APPROVAL_FACTS_NOT_CONFIGURED'),
};

Map<String, Object?> s6ApprovalsBody({
  List<Map<String, Object?>>? items,
  int activeCount = 1,
  int unlimitedCount = 0,
}) => <String, Object?>{
  'walletId': s5WalletId,
  'items': items ?? <Map<String, Object?>>[s6ApprovalRowBody()],
  'summary': <String, Object?>{
    'activeCount': activeCount,
    'unlimitedCount': unlimitedCount,
  },
  'freshness': <String, Object?>{
    'indexerBlockNumber': '120695200',
    'approvalCoverageFromBlockNumber': '120600000',
    'headBlockNumber': '120695250',
    'observedAt': '2026-09-09T13:35:28.315Z',
  },
  'contractVersion': '2.0',
};

// ---------------------------------------------------------------------------
// model fixtures (decoded by the real codec)
// ---------------------------------------------------------------------------

LoopWalletIntent s6Intent({
  String kind = 'send',
  String state = 'awaiting_signature',
  String simulationStatus = 'passed',
  bool signingAllowed = true,
  Object? signingReason,
  String expiresAt = '2026-09-09T13:37:30.323Z',
  Object? result,
  String intentId = s6IntentId,
}) => LoopV2IntentCodec.intent(
  s6IntentBody(
    kind: kind,
    state: state,
    simulationStatus: simulationStatus,
    signingAllowed: signingAllowed,
    signingReason: signingReason,
    expiresAt: expiresAt,
    result: result,
    intentId: intentId,
  ),
);

LoopWalletIntent s6SwapIntent({String state = 'prepared'}) =>
    LoopV2IntentCodec.intent(s6SwapIntentBody(state: state));

LoopWalletIntent s6ApprovalIntent({bool isUnlimited = false}) =>
    LoopV2IntentCodec.intent(
      s6ApprovalIntentBody(
        isUnlimited: isUnlimited,
        allowanceDisplay: isUnlimited ? 'unlimited' : '5',
      ),
    );

LoopSwapQuoteView s6QuoteView({Map<String, Object?>? priceImpact}) =>
    LoopV2IntentCodec.quoteView(s6QuoteBody(priceImpact: priceImpact));

LoopSendPreflight s6Preflight({
  List<String> warnings = const <String>[
    'send.recipient.firstTime',
    'send.recipient.screeningUnavailable',
  ],
  bool isContract = false,
}) => LoopV2IntentCodec.preflight(
  s6PreflightBody(warnings: warnings, isContract: isContract),
);

LoopApprovalInventory s6Approvals({
  List<Map<String, Object?>>? items,
  int activeCount = 1,
  int unlimitedCount = 0,
}) => LoopV2IntentCodec.approvals(
  s6ApprovalsBody(
    items: items,
    activeCount: activeCount,
    unlimitedCount: unlimitedCount,
  ),
);

// ---------------------------------------------------------------------------
// port doubles
// ---------------------------------------------------------------------------

final class FakeWalletIntentsGateway implements WalletIntentsGateway {
  FakeWalletIntentsGateway({
    this.preflight,
    this.prepared,
    this.reported,
    this.pageItems = const <LoopWalletIntent>[],
    this.failure,
    this.prepareFailure,
    this.reportFailure,
    this.mode = LoopChainGatewayMode.production,
    this.pending = false,
    this.preflightPending = false,
    this.preparePending = false,
  });

  final LoopSendPreflight? preflight;
  final LoopWalletIntent? prepared;
  final LoopWalletIntent? reported;
  final List<LoopWalletIntent> pageItems;

  /// Applies to the intent read.
  final LoopChainFailureKind? failure;

  /// Applies to every prepare.
  final LoopChainFailureKind? prepareFailure;

  /// Applies to the broadcast report and to execute.
  final LoopChainFailureKind? reportFailure;

  /// Holds the intent read open, so a page's loading state can be observed.
  final bool pending;

  /// Holds the recipient preflight open (`send-to` step 2).
  final bool preflightPending;

  /// Holds every prepare open (`send-confirm`, `approval-guard`, `swap`).
  final bool preparePending;

  @override
  final LoopChainGatewayMode mode;

  int prepareCalls = 0;
  int reportCalls = 0;
  int executeCalls = 0;
  int cancelCalls = 0;
  int intentReads = 0;
  final List<String> reportedHashes = <String>[];
  final List<String> signatures = <String>[];
  final List<LoopAllowanceRequest> allowances = <LoopAllowanceRequest>[];
  final List<bool> priceImpactConfirmations = <bool>[];

  Future<LoopWalletIntent> _prepared() {
    prepareCalls += 1;
    if (preparePending) return Completer<LoopWalletIntent>().future;
    final kind = prepareFailure;
    if (kind != null) {
      return Future<LoopWalletIntent>.error(LoopChainException(kind));
    }
    return Future<LoopWalletIntent>.value(prepared ?? s6Intent());
  }

  @override
  Future<LoopSendPreflight> preflightRecipient({
    required String walletId,
    required String address,
  }) {
    if (preflightPending) return Completer<LoopSendPreflight>().future;
    final kind = failure;
    if (kind != null) {
      return Future<LoopSendPreflight>.error(LoopChainException(kind));
    }
    return Future<LoopSendPreflight>.value(preflight ?? s6Preflight());
  }

  @override
  Future<LoopWalletIntent> prepareSend({
    required String walletId,
    required String assetId,
    required String amount,
    required String recipientAddress,
  }) => _prepared();

  @override
  Future<LoopWalletIntent> prepareApproval({
    required String walletId,
    required String assetId,
    required String spenderAddress,
    required LoopAllowanceRequest allowance,
  }) {
    allowances.add(allowance);
    return _prepared();
  }

  @override
  Future<LoopWalletIntent> prepareRevoke({
    required String walletId,
    required String assetId,
    required String spenderAddress,
  }) => _prepared();

  @override
  Future<LoopWalletIntent> prepareSwap({
    required String walletId,
    required String quoteId,
    required bool confirmPriceImpact,
  }) {
    priceImpactConfirmations.add(confirmPriceImpact);
    return _prepared();
  }

  @override
  Future<LoopWalletIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) {
    reportCalls += 1;
    reportedHashes.add(txHash);
    final kind = reportFailure;
    if (kind != null) {
      return Future<LoopWalletIntent>.error(LoopChainException(kind));
    }
    return Future<LoopWalletIntent>.value(
      reported ?? s6Intent(state: 'submitted'),
    );
  }

  @override
  Future<LoopWalletIntent> execute({
    required String intentId,
    required String authorizationSignature,
  }) {
    executeCalls += 1;
    signatures.add(authorizationSignature);
    final kind = reportFailure;
    if (kind != null) {
      return Future<LoopWalletIntent>.error(LoopChainException(kind));
    }
    return Future<LoopWalletIntent>.value(
      reported ?? s6Intent(state: 'submitted'),
    );
  }

  @override
  Future<LoopWalletIntent> cancel(String intentId) {
    cancelCalls += 1;
    return Future<LoopWalletIntent>.value(s6Intent(state: 'cancelled'));
  }

  @override
  Future<LoopWalletIntent> loadIntent(String intentId) {
    intentReads += 1;
    if (pending) return Completer<LoopWalletIntent>().future;
    final kind = failure;
    if (kind != null) {
      return Future<LoopWalletIntent>.error(LoopChainException(kind));
    }
    return Future<LoopWalletIntent>.value(reported ?? s6Intent());
  }

  @override
  Future<LoopWalletIntentPage> loadIntents({String? cursor}) =>
      Future<LoopWalletIntentPage>.value(
        LoopWalletIntentPage(items: pageItems, nextCursor: null),
      );
}

final class FakeSwapQuoteGateway implements SwapQuoteGateway {
  FakeSwapQuoteGateway({
    this.quote,
    this.failure,
    this.pending = false,
    this.mode = LoopChainGatewayMode.production,
  });

  final LoopSwapQuoteView? quote;
  final LoopChainFailureKind? failure;

  /// Holds the quote open, so the page's own "报价中" state can be observed.
  final bool pending;

  @override
  final LoopChainGatewayMode mode;

  int quoteCalls = 0;
  final List<int?> slippages = <int?>[];

  @override
  Future<LoopSwapQuoteView> loadQuote({
    required String walletId,
    required String sourceAssetId,
    required String destinationAssetId,
    required String amount,
    int? slippageBps,
  }) {
    quoteCalls += 1;
    slippages.add(slippageBps);
    if (pending) return Completer<LoopSwapQuoteView>().future;
    final kind = failure;
    if (kind != null) {
      return Future<LoopSwapQuoteView>.error(LoopChainException(kind));
    }
    return Future<LoopSwapQuoteView>.value(quote ?? s6QuoteView());
  }
}

final class FakeApprovalsGateway implements ApprovalsGateway {
  FakeApprovalsGateway({
    this.inventory,
    this.failure,
    this.pending = false,
    this.mode = LoopChainGatewayMode.production,
  });

  final LoopApprovalInventory? inventory;
  final LoopChainFailureKind? failure;
  final bool pending;

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopApprovalInventory> loadApprovals(String walletId) {
    if (pending) return Completer<LoopApprovalInventory>().future;
    final kind = failure;
    if (kind != null) {
      return Future<LoopApprovalInventory>.error(LoopChainException(kind));
    }
    return Future<LoopApprovalInventory>.value(inventory ?? s6Approvals());
  }

  @override
  Future<LoopApprovalRow> loadApproval({
    required String walletId,
    required String assetId,
    required String spender,
  }) => Future<LoopApprovalRow>.value(
    LoopV2IntentCodec.approvalRow(s6ApprovalRowBody()),
  );
}
