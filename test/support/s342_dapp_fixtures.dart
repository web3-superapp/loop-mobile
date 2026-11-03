// S342 · decision 0270: fixtures for the in-app DApp browser. The wire shape
// follows docs/55 §二; S342-api was written in parallel, so these are the
// client's reading of that contract.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_bridge.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_codec.dart';

const s342IntentId = '6a7b8c9d-0e1f-4a2b-8c3d-4e5f6a7b8c9d';
const s342WalletId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const s342Address = '0x1111111111111111111111111111111111111111';
const s342Origin = 'https://app.example.org';
const s342Token = '0x2222222222222222222222222222222222222222';
const s342Spender = '0x3333333333333333333333333333333333333333';
const s342Launch = 'eip155:97';
const s342Mainnet = 'eip155:56';

/// `approve(spender, 2^256 - 1)`.
const String s342ApproveData =
    '0x095ea7b3'
    '0000000000000000000000003333333333333333333333333333333333333333'
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

const DappWalletIdentity s342Wallet = DappWalletIdentity(
  walletId: s342WalletId,
  address: s342Address,
);

final DappTxRequest s342TxRequest = DappTxRequest(
  to: s342Token,
  data: s342ApproveData,
  value: BigInt.zero,
);

Map<String, Object?> s342TxIntentBody({
  String chainId = s342Launch,
  List<Object?> riskFlags = const <Object?>['UNLIMITED_APPROVAL'],
  String to = s342Token,
  String data = s342ApproveData,
  String value = '0x0',
  bool signingAllowed = true,
  String state = 'awaiting_signature',
  String expiresAt = '2099-01-01T00:00:00.000Z',
  Map<String, Object?>? extraReview,
}) => <String, Object?>{
  'intentId': s342IntentId,
  'kind': 'dapp_tx',
  'state': state,
  'walletId': s342WalletId,
  'chainId': chainId,
  'origin': s342Origin,
  'review': <String, Object?>{
    'kind': 'dapp_tx',
    'origin': s342Origin,
    'to': <String, Object?>{
      'address': to,
      'isContract': true,
      'verified': true,
    },
    'value': '0',
    'decodedCall': <String, Object?>{
      'functionName': 'approve',
      'selector': '0x095ea7b3',
      'args': <String, Object?>{'spender': s342Spender, 'amount': 'unlimited'},
    },
    'riskFlags': riskFlags,
    ...?extraReview,
  },
  'reviewSha256': 'e' * 64,
  'factsObservedAt': '2026-11-03T08:00:00.000Z',
  'expiresAt': expiresAt,
  'simulation': <String, Object?>{'status': 'passed'},
  'signing': <String, Object?>{
    'mode': 'device_eth_send_transaction',
    'allowed': signingAllowed,
    'reasonCode': null,
  },
  'unsignedTransaction': <String, Object?>{
    'chainId': chainId == s342Launch ? 97 : 56,
    'from': s342Address,
    'to': to,
    'data': data,
    'value': value,
    'gas': '0xea60',
    'nonce': '0x1',
    'type': 'eip1559',
    'maxFeePerGas': '0x3b9aca00',
    'maxPriorityFeePerGas': '0x3b9aca00',
    'gasPrice': null,
  },
  'result': <String, Object?>{'transactionHash': null},
  'version': '1',
  'createdAt': '2026-11-03T08:00:00.000Z',
  'updatedAt': '2026-11-03T08:00:00.000Z',
  'contractVersion': '2.0',
};

const String s342TypedData =
    '{"types":{"EIP712Domain":[{"name":"name","type":"string"},'
    '{"name":"chainId","type":"uint256"}],"Permit":[{"name":"owner",'
    '"type":"address"},{"name":"spender","type":"address"},{"name":"value",'
    '"type":"uint256"}]},"primaryType":"Permit","domain":{"name":"Token",'
    '"chainId":97},"message":{"owner":"$s342Address","spender":"$s342Spender",'
    '"value":"1000"}}';

Map<String, Object?> s342SignIntentBody({
  String method = 'personal_sign',
  String payload = '0x68656c6c6f',
  List<Object?> riskFlags = const <Object?>[],
}) => <String, Object?>{
  'intentId': s342IntentId,
  'kind': 'dapp_sign',
  'state': 'awaiting_signature',
  'walletId': s342WalletId,
  'chainId': s342Launch,
  'origin': s342Origin,
  'review': <String, Object?>{
    'kind': 'dapp_sign',
    'origin': s342Origin,
    'message': <String, Object?>{
      'method': method,
      if (method == 'personal_sign') 'text': 'hello',
      if (method != 'personal_sign')
        'typedData': <String, Object?>{
          'primaryType': 'Permit',
          'domain': <String, Object?>{'name': 'Token', 'chainId': 97},
          'message': <String, Object?>{
            'owner': s342Address,
            'spender': s342Spender,
            'value': '1000',
          },
        },
    },
    'riskFlags': riskFlags,
  },
  'signPayload': <String, Object?>{'method': method, 'payload': payload},
  'reviewSha256': 'f' * 64,
  'expiresAt': '2099-01-01T00:00:00.000Z',
  'signing': <String, Object?>{'allowed': true, 'reasonCode': null},
  'contractVersion': '2.0',
};

DappIntent s342TxIntent({
  List<Object?> riskFlags = const <Object?>['UNLIMITED_APPROVAL'],
}) => LoopV2DappCodec.intent(s342TxIntentBody(riskFlags: riskFlags));

DappIntent s342SignIntent({
  String method = 'personal_sign',
  String payload = '0x68656c6c6f',
}) => LoopV2DappCodec.intent(
  s342SignIntentBody(method: method, payload: payload),
);

/// Records every prepare and report; answers with the fixture intents.
final class FakeDappIntentsGateway implements DappIntentsGateway {
  FakeDappIntentsGateway({this.failure, this.txIntent, this.signIntent});

  final LoopChainException? failure;
  DappIntent? txIntent;
  DappIntent? signIntent;

  final List<Map<String, Object?>> prepared = <Map<String, Object?>>[];
  final List<String> reports = <String>[];
  final List<String> cancelled = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<DappIntent> prepareTx({
    required String walletId,
    required String chainId,
    required String origin,
    required DappTxRequest tx,
  }) async {
    prepared.add(<String, Object?>{
      'kind': 'tx',
      'walletId': walletId,
      'chainId': chainId,
      'origin': origin,
      'tx': tx.toWire(),
    });
    if (failure != null) throw failure!;
    return txIntent ?? s342TxIntent();
  }

  @override
  Future<DappIntent> prepareSign({
    required String walletId,
    required String chainId,
    required String origin,
    required DappSignRequest request,
  }) async {
    prepared.add(<String, Object?>{
      'kind': 'sign',
      'walletId': walletId,
      'chainId': chainId,
      'origin': origin,
      'method': request.method,
      'payload': request.payload,
    });
    if (failure != null) throw failure!;
    return signIntent ??
        s342SignIntent(method: request.method, payload: request.payload);
  }

  @override
  Future<DappIntent> reportBroadcast({
    required String intentId,
    required String txHash,
  }) async {
    reports.add('broadcast:$txHash');
    return s342TxIntent();
  }

  @override
  Future<DappIntent> reportSignature({
    required String intentId,
    required String signature,
  }) async {
    reports.add('signature:$signature');
    return s342SignIntent();
  }

  @override
  Future<void> cancel({required String intentId}) async {
    cancelled.add(intentId);
  }
}

final class FakeDappRpcReader implements DappRpcReader {
  final List<String> calls = <String>[];

  @override
  Future<Object?> read({
    required String chainId,
    required String method,
    required List<Object?> params,
  }) async {
    calls.add('$chainId:$method');
    return '0x10';
  }
}

/// A scripted bridge host.
final class FakeDappHost implements DappBridgeHost {
  FakeDappHost({
    this.topOrigin = s342Origin,
    this.wallet = s342Wallet,
    this.agree = true,
    this.outcome = const DappSignOutcome(
      status: DappSignStatus.produced,
      reasonCode: 'REPORTED',
      value: '0xabc',
      reported: true,
    ),
  });

  @override
  String? topOrigin;

  @override
  DappWalletIdentity? wallet;

  bool agree;
  DappSignOutcome outcome;

  int connectionPrompts = 0;
  final List<DappIntent> confirmed = <DappIntent>[];
  final List<String> toasts = <String>[];
  final List<(String, Object?)> events = <(String, Object?)>[];
  final List<String> chains = <String>[];

  @override
  Future<bool> confirmConnection({
    required String origin,
    required DappWalletIdentity wallet,
  }) async {
    connectionPrompts += 1;
    return agree;
  }

  @override
  Future<DappSignOutcome> confirmIntent({
    required DappIntent intent,
    required DappWalletIdentity wallet,
    DappTxRequest? tx,
    DappSignRequest? sign,
  }) async {
    confirmed.add(intent);
    return outcome;
  }

  @override
  void toast(String message) => toasts.add(message);

  @override
  Future<void> emit(String event, Object? data) async =>
      events.add((event, data));

  @override
  void chainChanged(String chainId) => chains.add(chainId);
}

/// The WebView double: records the config and the controller calls.
final class FakeDappWebViewFactory implements DappWebViewFactory {
  DappWebViewConfig? config;
  final FakeDappWebViewController controller = FakeDappWebViewController();

  @override
  bool get available => true;

  @override
  Widget build(DappWebViewConfig config) {
    this.config = config;
    return _FakeWebView(config: config, controller: controller);
  }
}

class _FakeWebView extends StatefulWidget {
  const _FakeWebView({required this.config, required this.controller});

  final DappWebViewConfig config;
  final FakeDappWebViewController controller;

  @override
  State<_FakeWebView> createState() => _FakeWebViewState();
}

class _FakeWebViewState extends State<_FakeWebView> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      widget.config.onCreated(widget.controller);
      widget.config.onUrlChanged(widget.config.initialUrl);
      widget.config.onTitleChanged('Example DApp');
      widget.config.onProgress(1);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey<String>('fake-webview'));
}

final class FakeDappWebViewController implements DappWebViewController {
  final List<String> calls = <String>[];
  final List<String> scripts = <String>[];

  @override
  Future<bool> canGoBack() async => false;

  @override
  Future<bool> canGoForward() async => false;

  @override
  Future<void> evaluate(String source) async => scripts.add(source);

  @override
  Future<void> goBack() async => calls.add('back');

  @override
  Future<void> goForward() async => calls.add('forward');

  @override
  Future<void> load(Uri url) async => calls.add('load:$url');

  @override
  Future<void> reload() async => calls.add('reload');
}

/// The S342-api draft shape (openapi 2026-11-03): the DApp facts nested under
/// `review.dapp`, the signing request in `signatureRequest`.
Map<String, Object?> s342ApiSignBody() => <String, Object?>{
  'intentId': s342IntentId,
  'kind': 'dapp_sign',
  'state': 'awaiting_signature',
  'walletId': s342WalletId,
  'chainId': s342Launch,
  'review': <String, Object?>{
    'kind': 'dapp_sign',
    'asset': null,
    'amount': null,
    'recipient': null,
    'spender': null,
    'decodedCall': null,
    'fee': null,
    'balance': null,
    'swap': null,
    'dapp': <String, Object?>{
      'origin': s342Origin,
      'method': 'eth_signTypedData_v4',
      'to': null,
      'value': null,
      'decodedCall': null,
      'counterparty': null,
      'message': null,
      'typedData': <String, Object?>{
        'primaryType': 'Permit',
        'domain': <String, Object?>{
          'name': 'Token',
          'version': null,
          'chainId': '97',
          'verifyingContract': null,
          'salt': null,
        },
        'fields': <Object?>[
          <String, Object?>{
            'path': 'spender',
            'type': 'address',
            'value': s342Spender,
            'truncated': false,
          },
          <String, Object?>{
            'path': 'value',
            'type': 'uint256',
            'value': '1000',
            'truncated': false,
          },
        ],
        'fieldsTruncated': false,
      },
      'riskFlags': <Object?>['PERMIT_SIGNATURE'],
    },
  },
  'reviewSha256': 'a' * 64,
  'factsObservedAt': '2026-11-03T08:00:00.000Z',
  'expiresAt': '2099-01-01T00:00:00.000Z',
  'simulation': <String, Object?>{'status': 'unavailable'},
  'policy': null,
  'signing': <String, Object?>{
    'mode': 'device_sign_typed_data_v4',
    'allowed': true,
    'reasonCode': null,
  },
  'unsignedTransaction': null,
  'authorizationPayload': null,
  'signatureRequest': <String, Object?>{
    'method': 'eth_signTypedData_v4',
    'params': <Object?>[s342Address, s342TypedData],
  },
  'result': <String, Object?>{
    'transactionHash': null,
    'providerActionId': null,
    'reasonCode': null,
    'receipt': null,
  },
  'version': '1',
  'createdAt': '2026-11-03T08:00:00.000Z',
  'updatedAt': '2026-11-03T08:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> s342ApiTxBody() {
  final body = s342TxIntentBody();
  final review = body['review']! as Map<String, Object?>;
  body['review'] = <String, Object?>{
    'kind': 'dapp_tx',
    'asset': null,
    'amount': null,
    'recipient': null,
    'spender': null,
    'decodedCall': null,
    'fee': null,
    'balance': null,
    'swap': null,
    'dapp': <String, Object?>{
      'origin': s342Origin,
      'method': 'eth_sendTransaction',
      'to': <String, Object?>{
        'address': s342Token,
        'checksumAddress': s342Token,
        'isContract': true,
        'isVerified': false,
        'knownContract': null,
      },
      'value': <String, Object?>{'raw': '0', 'display': '0'},
      'decodedCall': <String, Object?>{
        'functionName': 'approve',
        'selector': '0x095ea7b3',
        'standard': 'erc20',
        'args': review['decodedCall'] is Map
            ? (review['decodedCall']! as Map<String, Object?>)['args']
            : <String, Object?>{},
        'dataLength': 68,
      },
      'counterparty': null,
      'message': null,
      'typedData': null,
      'riskFlags': <Object?>['UNLIMITED_APPROVAL', 'UNVERIFIED_CONTRACT'],
    },
  };
  body.remove('origin');
  return body;
}
