// S342 · decision 0270 · 内置 DApp 浏览器 (docs/55 §一, §三).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_bridge.dart';
import 'package:loop_mobile/features/dapp/dapp_browser_screens.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/dapp/dapp_provider_icon.dart';
import 'package:loop_mobile/features/dapp/dapp_provider_script.dart';
import 'package:loop_mobile/features/dapp/dapp_signing.dart';
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/features/wallet/deferred_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_api.dart';
import 'package:loop_mobile/integrations/backend/v2/dapp/loop_v2_dapp_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_dapp_browser_store.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s342_dapp_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_page_harness.dart';

DappBridge _bridge(
  FakeDappHost host, {
  FakeDappIntentsGateway? intents,
  FakeDappRpcReader? reader,
  Set<String>? connected,
  String chainId = s342Launch,
}) {
  final origins = connected ?? <String>{};
  return DappBridge(
    nonce: 'n0nce',
    host: host,
    intents: intents ?? FakeDappIntentsGateway(),
    reader: reader ?? FakeDappRpcReader(),
    isConnected: origins.contains,
    setConnected: (origin, {required bool connected}) async {
      if (connected) {
        origins.add(origin);
      } else {
        origins.remove(origin);
      }
    },
    chainId: chainId,
  );
}

List<Object?> _call(
  String method, [
  List<Object?> params = const <Object?>[],
  String origin = s342Origin,
  String nonce = 'n0nce',
  bool top = true,
]) => <Object?>[
  nonce,
  origin,
  top,
  jsonEncode(<String, Object?>{'method': method, 'params': params}),
];

int? _code(Map<String, Object?> answer) =>
    (answer['error'] as Map<String, Object?>?)?['code'] as int?;

void main() {
  loopWatchGround();

  group('provider script', () {
    final script = dappProviderScript(
      nonce: 'abc123',
      chainIdHex: '0x61',
      providerUuid: '11111111-1111-4111-8111-111111111111',
    );

    test('EIP-1193 provider: isLoop, never MetaMask, top frame only', () {
      expect(script, contains('isLoop: true'));
      expect(script, contains('isMetaMask: false'));
      expect(script, contains('window.top !== window.self'));
      expect(script, contains('"abc123"'));
      expect(script, contains('"0x61"'));
      expect(script, contains('"loopEthereum"'));
      for (final event in <String>[
        'accountsChanged',
        'chainChanged',
        'connect',
      ]) {
        expect(script, contains(event));
      }
    });

    test('EIP-6963 announce with LOOP, its rdns and a data URI icon', () {
      expect(script, contains('eip6963:announceProvider'));
      expect(script, contains('eip6963:requestProvider'));
      expect(script, contains('"LOOP"'));
      expect(script, contains('"cc.quant-dinger.loop"'));
      expect(dappProviderIconDataUri, startsWith('data:image/png;base64,'));
      expect(script, contains(dappProviderIconDataUri));
      expect(script, isNot(contains('__LOOP_')));
    });

    test('an emitted event names the page nonce', () {
      final emit = DappBridgeProtocol.emitScript(
        'abc123',
        'chainChanged',
        '0x38',
      );
      expect(emit, contains('__loopEmit_abc123'));
      expect(emit, contains('"chainChanged"'));
    });
  });

  group('bridge origin check', () {
    test('a wrong nonce, an iframe or another origin is refused', () async {
      final host = FakeDappHost();
      final bridge = _bridge(host);
      expect(
        _code(
          await bridge.handle(_call('eth_chainId', const [], s342Origin, 'x')),
        ),
        DappRpcErrorCode.unauthorized,
      );
      expect(
        _code(
          await bridge.handle(
            _call('eth_chainId', const [], s342Origin, 'n0nce', false),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
      expect(
        _code(
          await bridge.handle(
            _call('eth_chainId', const [], 'https://evil.example'),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
      expect(bridge.refusedFrames, 3);
      final ok = await bridge.handle(_call('eth_chainId'));
      expect(ok, <String, Object?>{'ok': true, 'result': '0x61'});
    });

    test('no page loaded, or a non-https top page, admits nothing', () async {
      final bridge = _bridge(FakeDappHost(topOrigin: null));
      expect(
        _code(await bridge.handle(_call('eth_chainId'))),
        DappRpcErrorCode.unauthorized,
      );
      final http = _bridge(FakeDappHost(topOrigin: 'http://app.example.org'));
      expect(
        _code(
          await http.handle(
            _call('eth_chainId', const [], 'http://app.example.org'),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
    });
  });

  group('method routing', () {
    test('chain id, net version, accounts before connecting', () async {
      final bridge = _bridge(FakeDappHost());
      expect((await bridge.handle(_call('eth_chainId')))['result'], '0x61');
      expect((await bridge.handle(_call('net_version')))['result'], '97');
      expect(
        (await bridge.handle(_call('eth_accounts')))['result'],
        const <String>[],
      );
    });

    test(
      'eth_requestAccounts asks once and is remembered per origin',
      () async {
        final host = FakeDappHost();
        final origins = <String>{};
        final bridge = _bridge(host, connected: origins);
        final first = await bridge.handle(_call('eth_requestAccounts'));
        expect(first['result'], <String>[s342Address]);
        expect(origins, <String>{s342Origin});
        final second = await bridge.handle(_call('eth_requestAccounts'));
        expect(second['result'], <String>[s342Address]);
        expect(host.connectionPrompts, 1);
        expect((await bridge.handle(_call('eth_accounts')))['result'], <String>[
          s342Address,
        ]);
        expect(host.events.first.$1, 'accountsChanged');
      },
    );

    test('a declined connection is 4001 and remembers nothing', () async {
      final origins = <String>{};
      final bridge = _bridge(FakeDappHost(agree: false), connected: origins);
      expect(
        _code(await bridge.handle(_call('eth_requestAccounts'))),
        DappRpcErrorCode.userRejected,
      );
      expect(origins, isEmpty);
    });

    test('disconnect forgets the origin and tells the page', () async {
      final host = FakeDappHost();
      final origins = <String>{s342Origin};
      final bridge = _bridge(host, connected: origins);
      await bridge.disconnect(s342Origin);
      expect(origins, isEmpty);
      expect(host.events.map((event) => event.$1), <String>[
        'accountsChanged',
        'disconnect',
      ]);
      expect(
        (await bridge.handle(_call('eth_accounts')))['result'],
        const <String>[],
      );
    });

    test('wallet_switchEthereumChain: 56 and 97 only, else 4902', () async {
      final host = FakeDappHost();
      final bridge = _bridge(host);
      final switched = await bridge.handle(
        _call('wallet_switchEthereumChain', <Object?>[
          <String, Object?>{'chainId': '0x38'},
        ]),
      );
      expect(switched, <String, Object?>{'ok': true, 'result': null});
      expect(bridge.chainId, s342Mainnet);
      expect(host.chains, <String>[s342Mainnet]);
      expect(host.events.single, ('chainChanged', '0x38'));
      expect(
        _code(
          await bridge.handle(
            _call('wallet_switchEthereumChain', <Object?>[
              <String, Object?>{'chainId': '0x1'},
            ]),
          ),
        ),
        DappRpcErrorCode.unrecognizedChain,
      );
    });

    test(
      'eth_sign, eth_signTransaction and unknown methods are 4200',
      () async {
        final bridge = _bridge(FakeDappHost(), connected: <String>{s342Origin});
        for (final method in <String>[
          'eth_sign',
          'eth_signTransaction',
          'wallet_addEthereumChain',
          'eth_coinbase',
        ]) {
          expect(
            _code(await bridge.handle(_call(method))),
            DappRpcErrorCode.unsupportedMethod,
            reason: method,
          );
        }
      },
    );

    test(
      'read methods go through the read channel on the page chain',
      () async {
        final reader = FakeDappRpcReader();
        final bridge = _bridge(FakeDappHost(), reader: reader);
        final answer = await bridge.handle(
          _call('eth_getBalance', <Object?>[s342Address, 'latest']),
        );
        expect(answer['result'], '0x10');
        expect(reader.calls, <String>['$s342Launch:eth_getBalance']);
      },
    );

    test(
      'signing on BSC Mainnet is 4100 with the toast, nothing prepared',
      () async {
        final host = FakeDappHost();
        final intents = FakeDappIntentsGateway();
        final bridge = _bridge(
          host,
          intents: intents,
          connected: <String>{s342Origin},
          chainId: s342Mainnet,
        );
        for (final call in <List<Object?>>[
          _call('eth_sendTransaction', <Object?>[
            <String, Object?>{'to': s342Token, 'data': '0x'},
          ]),
          _call('personal_sign', <Object?>['0x68656c6c6f', s342Address]),
          _call('eth_signTypedData_v4', <Object?>[s342Address, s342TypedData]),
        ]) {
          expect(
            _code(await bridge.handle(call)),
            DappRpcErrorCode.unauthorized,
          );
        }
        expect(host.toasts, List<String>.filled(3, '暂不支持在这个网络签名'));
        expect(intents.prepared, isEmpty);
      },
    );

    test('signing before connecting is 4100', () async {
      final intents = FakeDappIntentsGateway();
      final bridge = _bridge(FakeDappHost(), intents: intents);
      expect(
        _code(
          await bridge.handle(
            _call('personal_sign', <Object?>['0x68656c6c6f', s342Address]),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
      expect(intents.prepared, isEmpty);
    });

    test(
      'eth_sendTransaction prepares a dapp-tx and returns the hash',
      () async {
        final host = FakeDappHost();
        final intents = FakeDappIntentsGateway();
        final bridge = _bridge(
          host,
          intents: intents,
          connected: <String>{s342Origin},
        );
        final answer = await bridge.handle(
          _call('eth_sendTransaction', <Object?>[
            <String, Object?>{
              'from': s342Address,
              'to': s342Token.toUpperCase().replaceFirst('0X', '0x'),
              'data': s342ApproveData,
              'value': '0x0',
            },
          ]),
        );
        expect(answer, <String, Object?>{'ok': true, 'result': '0xabc'});
        expect(intents.prepared.single, <String, Object?>{
          'kind': 'tx',
          'walletId': s342WalletId,
          'chainId': s342Launch,
          'origin': s342Origin,
          'tx': <String, Object?>{
            'to': s342Token,
            'data': s342ApproveData,
            'value': '0x0',
          },
        });
        expect(host.confirmed.single.kind, DappIntentKind.transaction);
      },
    );

    test('a transaction from another account is 4100', () async {
      final bridge = _bridge(FakeDappHost(), connected: <String>{s342Origin});
      expect(
        _code(
          await bridge.handle(
            _call('eth_sendTransaction', <Object?>[
              <String, Object?>{'from': s342Spender, 'to': s342Token},
            ]),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
    });

    test('personal_sign and typed data prepare a dapp-sign', () async {
      final intents = FakeDappIntentsGateway();
      final bridge = _bridge(
        FakeDappHost(),
        intents: intents,
        connected: <String>{s342Origin},
      );
      await bridge.handle(
        _call('personal_sign', <Object?>['0x68656c6c6f', s342Address]),
      );
      await bridge.handle(
        _call('eth_signTypedData_v4', <Object?>[s342Address, s342TypedData]),
      );
      expect(intents.prepared.map((p) => p['method']), <String>[
        'personal_sign',
        'eth_signTypedData_v4',
      ]);
      expect(intents.prepared.last['payload'], s342TypedData);
    });

    test('the owner declining the sheet is 4001', () async {
      final bridge = _bridge(
        FakeDappHost(outcome: const DappSignOutcome.rejected()),
        connected: <String>{s342Origin},
      );
      expect(
        _code(
          await bridge.handle(
            _call('personal_sign', <Object?>['0x68656c6c6f', s342Address]),
          ),
        ),
        DappRpcErrorCode.userRejected,
      );
    });

    test('a server CHAIN_SIGNING_DISABLED is 4100 with the toast', () async {
      final host = FakeDappHost();
      final bridge = _bridge(
        host,
        intents: FakeDappIntentsGateway(
          failure: const LoopChainException(
            LoopChainFailureKind.chainMismatch,
            reasonCode: 'CHAIN_SIGNING_DISABLED',
          ),
        ),
        connected: <String>{s342Origin},
      );
      expect(
        _code(
          await bridge.handle(
            _call('personal_sign', <Object?>['0x68656c6c6f', s342Address]),
          ),
        ),
        DappRpcErrorCode.unauthorized,
      );
      expect(host.toasts, <String>['暂不支持在这个网络签名']);
    });
  });

  group('codec', () {
    test('dapp_tx: review, decoded call, risk flags, payload', () {
      final intent = LoopV2DappCodec.intent(
        s342TxIntentBody(
          riskFlags: <Object?>[
            'UNLIMITED_APPROVAL',
            'UNVERIFIED_CONTRACT',
            'A_LATER_RULE',
          ],
        ),
      );
      expect(intent.kind, DappIntentKind.transaction);
      expect(intent.origin, s342Origin);
      expect(intent.riskFlags, <DappRiskFlag>[
        DappRiskFlag.unlimitedApproval,
        DappRiskFlag.unverifiedContract,
      ]);
      expect(intent.txReview!.decodedCall!.functionName, 'approve');
      expect(intent.unsignedTransaction!.chainId, 97);
      expect(intent.matchesTx(s342TxRequest, fromAddress: s342Address), isTrue);
    });

    test('dapp_tx whose payload names another target does not match', () {
      final intent = LoopV2DappCodec.intent(s342TxIntentBody(to: s342Spender));
      expect(
        intent.matchesTx(s342TxRequest, fromAddress: s342Address),
        isFalse,
      );
    });

    test('dapp_sign: message, typed data tree, permit flag', () {
      final text = s342SignIntent();
      expect(text.signReview!.text, 'hello');
      expect(
        text.matchesSign(
          const DappSignRequest(
            method: 'personal_sign',
            payload: '0x68656c6c6f',
          ),
        ),
        isTrue,
      );
      final typed = LoopV2DappCodec.intent(
        s342SignIntentBody(
          method: 'eth_signTypedData_v4',
          payload: s342TypedData,
          riskFlags: <Object?>['PERMIT_SIGNATURE'],
        ),
      );
      expect(typed.signReview!.typedData!['primaryType'], 'Permit');
      expect(typed.riskFlags, <DappRiskFlag>[DappRiskFlag.permitSignature]);
      // The same typed data, re-spaced, still matches.
      final respaced = jsonEncode(jsonDecode(s342TypedData));
      expect(
        typed.matchesSign(
          DappSignRequest(method: 'eth_signTypedData_v4', payload: respaced),
        ),
        isTrue,
      );
    });

    test('a review without an origin or a known chain is invalid', () {
      final body = s342TxIntentBody()..remove('origin');
      (body['review']! as Map<String, Object?>).remove('origin');
      expect(
        () => LoopV2DappCodec.intent(body),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2DappCodec.intent(s342TxIntentBody(chainId: 'eip155:1')),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the S342-api draft shape: review.dapp and signatureRequest', () {
      final tx = LoopV2DappCodec.intent(s342ApiTxBody());
      expect(tx.origin, s342Origin);
      expect(tx.txReview!.toVerified, isFalse);
      expect(tx.riskFlags, <DappRiskFlag>[
        DappRiskFlag.unlimitedApproval,
        DappRiskFlag.unverifiedContract,
      ]);
      expect(tx.matchesTx(s342TxRequest, fromAddress: s342Address), isTrue);

      final sign = LoopV2DappCodec.intent(s342ApiSignBody());
      expect(sign.signMethod, 'eth_signTypedData_v4');
      expect(sign.signPayload, s342TypedData);
      expect(sign.signReview!.typedData!['primaryType'], 'Permit');
      expect(
        (sign.signReview!.typedData!['message']! as Map)['spender'],
        s342Spender,
      );
      expect(
        sign.matchesSign(
          const DappSignRequest(
            method: 'eth_signTypedData_v4',
            payload: s342TypedData,
          ),
        ),
        isTrue,
      );
    });

    test('the intent list reads DApp rows leniently', () {
      final page = LoopV2IntentCodec.intentPage(<String, Object?>{
        'items': <Object?>[
          s342TxIntentBody(),
          <String, Object?>{'kind': 'dapp_sign', 'broken': true},
          <String, Object?>{'kind': 'a_later_kind'},
        ],
        'nextCursor': null,
        'contractVersion': '2.0',
      });
      expect(page.items, isEmpty);
      expect(page.dappIntents.single.kind, DappIntentKind.transaction);
    });
  });

  group('transport', () {
    test('dapp-tx and dapp-sign request bodies', () async {
      final bodies = <String, Object?>{};
      final api = DioLoopV2DappApi(
        s5Dio((options, handler) {
          bodies[options.path] = options.data;
          expect(
            options.headers['Idempotency-Key'],
            '7c9e6679-7425-40de-944b-e07fc1f90ae7',
          );
          handler.resolve(
            s5Response(
              options,
              options.path.endsWith('dapp-tx')
                  ? s342TxIntentBody()
                  : s342SignIntentBody(),
              statusCode: 201,
            ),
          );
        }),
      );
      await api.prepareTx(
        accessToken: 'token',
        clientVersion: s5ClientVersion,
        idempotencyKey: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        walletId: s342WalletId,
        chainId: s342Launch,
        origin: s342Origin,
        tx: s342TxRequest,
      );
      await api.prepareSign(
        accessToken: 'token',
        clientVersion: s5ClientVersion,
        idempotencyKey: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
        walletId: s342WalletId,
        chainId: s342Launch,
        origin: s342Origin,
        request: const DappSignRequest(
          method: 'personal_sign',
          payload: '0x68656c6c6f',
        ),
      );
      expect(bodies[DioLoopV2DappApi.dappTxPath], <String, Object?>{
        'walletId': s342WalletId,
        'chainId': s342Launch,
        'origin': s342Origin,
        'tx': <String, Object?>{
          'to': s342Token,
          'data': s342ApproveData,
          'value': '0x0',
        },
      });
      expect(bodies[DioLoopV2DappApi.dappSignPath], <String, Object?>{
        'walletId': s342WalletId,
        'chainId': s342Launch,
        'origin': s342Origin,
        'method': 'personal_sign',
        'payload': '0x68656c6c6f',
      });
    });
  });

  group('read channel', () {
    test('rpc-read carries the method and hands a node error back', () async {
      final bodies = <Object?>[];
      final api = DioLoopV2DappApi(
        s5Dio((options, handler) {
          bodies.add(options.data);
          expect(options.headers.containsKey('Idempotency-Key'), isFalse);
          final call = options.data! as Map<String, Object?>;
          handler.resolve(
            s5Response(options, <String, Object?>{
              'chainId': call['chainId'],
              'method': call['method'],
              'result': call['method'] == 'eth_call' ? null : '0x10',
              'error': call['method'] == 'eth_call'
                  ? <String, Object?>{
                      'code': 3,
                      'message': 'execution reverted',
                      'data': '0x',
                    }
                  : null,
              'contractVersion': '2.0',
            }),
          );
        }),
      );
      final balance = await api.rpcRead(
        accessToken: 'token',
        clientVersion: s5ClientVersion,
        chainId: s342Launch,
        method: 'eth_getBalance',
        params: const <Object?>[s342Address, 'latest'],
      );
      expect(balance, '0x10');
      await expectLater(
        api.rpcRead(
          accessToken: 'token',
          clientVersion: s5ClientVersion,
          chainId: s342Launch,
          method: 'eth_call',
          params: const <Object?>[],
        ),
        throwsA(isA<DappRpcError>().having((e) => e.code, 'code', 3)),
      );
      expect(bodies.first, <String, Object?>{
        'chainId': s342Launch,
        'method': 'eth_getBalance',
        'params': <Object?>[s342Address, 'latest'],
      });
    });
  });

  group('signing exit', () {
    test('DApp kinds are never permitted on BSC Mainnet', () {
      final intent = SigningIntent.backendCanonical(
        revision: s342IntentId,
        payloadDigest: 'e' * 64,
        title: 't',
        kind: IntentKind.dappTransaction,
        chainId: s342Mainnet,
        payload: const MessageSignaturePayload(
          fromAddress: s342Address,
          method: 'personal_sign',
          payload: '0x00',
        ),
        observedAt: DateTime.utc(2026),
        expiresAt: DateTime.utc(2099),
        fields: const <IntentField>[],
      );
      expect(intent.chainIsPermitted, isFalse);
    });

    test('a matching intent is signed, reported and handed back', () async {
      final wallet = RecordingSigningGateway();
      final intents = FakeDappIntentsGateway();
      final signer = DappSigner(wallet: wallet, intents: intents);
      final outcome = await signer.sign(
        s342TxIntent(),
        fromAddress: s342Address,
        now: DateTime.utc(2026, 11, 3),
        tx: s342TxRequest,
      );
      expect(outcome.status, DappSignStatus.produced);
      expect(outcome.value, wallet.value);
      expect(intents.reports, <String>['broadcast:${wallet.value}']);
      final handed = wallet.handoffs.single;
      expect(handed.kind, IntentKind.dappTransaction);
      expect(handed.payload, isA<DeviceTransactionPayload>());
    });

    test(
      'a payload that differs from the page request never reaches the wallet',
      () async {
        final wallet = RecordingSigningGateway();
        final signer = DappSigner(
          wallet: wallet,
          intents: FakeDappIntentsGateway(),
        );
        final outcome = await signer.sign(
          LoopV2DappCodec.intent(s342TxIntentBody(value: '0x1')),
          fromAddress: s342Address,
          now: DateTime.utc(2026, 11, 3),
          tx: s342TxRequest,
        );
        expect(outcome.reasonCode, 'REVIEW_PAYLOAD_MISMATCH');
        expect(wallet.handoffs, isEmpty);
      },
    );

    test(
      'a message is signed through the message payload and reported',
      () async {
        final wallet = RecordingSigningGateway(value: '0x${'1' * 130}');
        final intents = FakeDappIntentsGateway();
        final outcome = await DappSigner(wallet: wallet, intents: intents).sign(
          s342SignIntent(),
          fromAddress: s342Address,
          now: DateTime.utc(2026, 11, 3),
          sign: const DappSignRequest(
            method: 'personal_sign',
            payload: '0x68656c6c6f',
          ),
        );
        expect(outcome.status, DappSignStatus.produced);
        final payload =
            wallet.handoffs.single.payload! as MessageSignaturePayload;
        expect(payload.method, 'personal_sign');
        expect(payload.payload, '0x68656c6c6f');
        expect(intents.reports.single, startsWith('signature:'));
      },
    );
  });

  group('confirmation sheet', () {
    Future<void> pumpSheet(WidgetTester tester, DappIntent intent) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          builder: (context, child) => LoopToastHost(child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DappIntentSheet(
                intent: intent,
                signer: DappSigner(
                  wallet: RecordingSigningGateway(),
                  intents: FakeDappIntentsGateway(),
                ),
                fromAddress: s342Address,
                tx: s342TxRequest,
                clock: () => DateTime.utc(2026, 11, 3),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the risk strip stands only when the server named a risk', (
      tester,
    ) async {
      await pumpSheet(tester, s342TxIntent());
      expect(
        find.byKey(const ValueKey<String>('dapp-risk-strip')),
        findsOneWidget,
      );
      expect(find.text('无限授权'), findsOneWidget);
      expect(find.text(s342Origin), findsOneWidget);
      expect(find.text('approve'), findsOneWidget);
      expect(find.text(s342Token), findsOneWidget);

      await pumpSheet(tester, s342TxIntent(riskFlags: const <Object?>[]));
      expect(
        find.byKey(const ValueKey<String>('dapp-risk-strip')),
        findsNothing,
      );
    });

    testWidgets('typed data renders as a tree', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: DappMessageView(
              review: s342SignIntent(
                method: 'eth_signTypedData_v4',
                payload: s342TypedData,
              ).signReview!,
            ),
          ),
        ),
      );
      expect(find.textContaining('primaryType'), findsOneWidget);
      expect(find.textContaining('spender'), findsOneWidget);
    });
  });

  group('entry and connection sheet', () {
    for (final open in <bool>[true, false]) {
      testWidgets('the wallet row reads ${open ? 'DApp 浏览器' : 'DApp 网址核对'}', (
        tester,
      ) async {
        await pumpS5Page(
          tester,
          const WalletScreen(),
          wallet: FakeWalletReadGateway(),
          meta: s5MetaSnapshot(
            dappBrowser: open
                ? LoopV2CapabilityAvailability.available
                : LoopV2CapabilityAvailability.unavailable,
          ),
        );
        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('wallet-dapp-entry')),
        );
        expect(find.text(open ? 'DApp 浏览器' : 'DApp 网址核对'), findsOneWidget);
      });
    }

    testWidgets('connect sheet: site, address, 连接 / 取消', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  answer = await showDappConnectSheet(
                    context,
                    origin: s342Origin,
                    address: s342Address,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(s342Origin), findsOneWidget);
      expect(find.text('0x1111…1111'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-connect-confirm')),
      );
      await tester.pumpAndSettle();
      expect(answer, isTrue);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-connect-cancel')),
      );
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });
  });

  group('local lists', () {
    test(
      'recents keep 20, newest first; bookmarks toggle; persisted',
      () async {
        final storage = <String, String>{};
        final store = SharedPreferencesDappBrowserStore.forTesting(
          (key) async => storage[key],
          (key, value) async => storage[key] = value,
        );
        var state = await store.read();
        for (var index = 0; index < 25; index++) {
          state = state.visited(
            DappPageEntry(url: 'https://site$index.example/', title: 'S$index'),
          );
        }
        state = state.visited(
          const DappPageEntry(url: 'https://site3.example/', title: 'S3'),
        );
        state = state
            .toggledBookmark(
              const DappPageEntry(url: 'https://a.example/', title: 'A'),
            )
            .withConnection(s342Origin, on: true);
        await store.write(state);
        final read = await store.read();
        expect(read.recents, hasLength(20));
        expect(read.recents.first.url, 'https://site3.example/');
        expect(read.isBookmarked('https://a.example/'), isTrue);
        expect(read.isConnected(s342Origin), isTrue);
        expect(read.toggledBookmark(read.bookmarks.single).bookmarks, isEmpty);
        expect(
          read.withConnection(s342Origin, on: false).connectedOrigins,
          isEmpty,
        );
      },
    );

    test('an unreadable or http entry is dropped, never an error', () {
      expect(DappBrowserLocalState.decode('{not json').recents, isEmpty);
      final state = DappBrowserLocalState.decode(
        jsonEncode(<String, Object?>{
          'v': 1,
          'recents': <Object?>[
            <String, Object?>{'url': 'http://plain.example/', 'title': 'x'},
            <String, Object?>{'url': 'https://ok.example/', 'title': 'ok'},
          ],
          'connections': <Object?>['http://plain.example', s342Origin],
        }),
      );
      expect(state.recents.single.url, 'https://ok.example/');
      expect(state.connectedOrigins, <String>{s342Origin});
    });
  });

  group('pages', () {
    Future<void> pumpPage(
      WidgetTester tester,
      Widget page, {
      bool browser = true,
      DappWebViewFactory? factory,
      DappBrowserStore? store,
      FakeDappIntentsGateway? intents,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      loopArmGroundProbe(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopV2MetaSnapshotProvider.overrideWith(
              (ref) async => s5MetaSnapshot(
                dappBrowser: browser
                    ? LoopV2CapabilityAvailability.available
                    : LoopV2CapabilityAvailability.unavailable,
              ),
            ),
            dappWebViewFactoryProvider.overrideWithValue(
              factory ?? FakeDappWebViewFactory(),
            ),
            dappBrowserStoreProvider.overrideWithValue(
              store ?? MemoryDappBrowserStore(),
            ),
            dappIntentsGatewayProvider.overrideWithValue(
              intents ?? FakeDappIntentsGateway(),
            ),
            walletReadGatewayProvider.overrideWithValue(
              FakeWalletReadGateway(),
            ),
            walletSigningGatewayProvider.overrideWithValue(
              RecordingSigningGateway(),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: page,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dappBrowser unavailable keeps the URL review page', (
      tester,
    ) async {
      await pumpPage(tester, const DappEntryScreen(), browser: false);
      expect(find.byType(DappReviewScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dapp-browser-home')),
        findsNothing,
      );
    });

    testWidgets('no WebView in this build keeps the URL review page', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const DappEntryScreen(),
        factory: const UnavailableDappWebViewFactory(),
      );
      expect(find.byType(DappReviewScreen), findsOneWidget);
    });

    testWidgets('home: empty, http refused, flagged asks, plain opens', (
      tester,
    ) async {
      final opened = <DappOpenRequest>[];
      await pumpPage(tester, DappEntryScreen(onOpen: opened.add));
      expect(
        find.byKey(const ValueKey<String>('dapp-browser-home')),
        findsOneWidget,
      );
      expect(find.text('DApp 浏览器'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('dapp-browser-empty')),
        findsOneWidget,
      );

      final field = find.byKey(
        const ValueKey<String>('dapp-browser-address-field'),
      );
      await tester.enterText(field, 'http://plain.example');
      await tester.tap(find.byKey(const ValueKey<String>('dapp-browser-go')));
      await tester.pumpAndSettle();
      expect(find.text('这个网址不能打开'), findsOneWidget);
      expect(opened, isEmpty);

      await tester.enterText(field, 'https://app.example.org:8443/swap');
      await tester.tap(find.byKey(const ValueKey<String>('dapp-browser-go')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dapp-findings-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-findings-open')),
      );
      await tester.pumpAndSettle();
      expect(opened.single.acknowledged, isTrue);

      await tester.enterText(field, 'app.example.org/#/swap');
      await tester.tap(find.byKey(const ValueKey<String>('dapp-browser-go')));
      await tester.pumpAndSettle();
      expect(opened.last.url.toString(), 'https://app.example.org/#/swap');
      expect(opened.last.acknowledged, isFalse);
    });

    testWidgets('home lists bookmarks and recents from the store', (
      tester,
    ) async {
      final store = MemoryDappBrowserStore(
        DappBrowserLocalState(
          recents: const <DappPageEntry>[
            DappPageEntry(url: 'https://r.example/', title: 'Recent'),
          ],
          bookmarks: const <DappPageEntry>[
            DappPageEntry(url: 'https://b.example/', title: 'Saved'),
          ],
        ),
      );
      await pumpPage(tester, const DappEntryScreen(), store: store);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('最近访问'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-browser-clear-recents')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsNothing);
      expect((await store.read()).recents, isEmpty);
    });

    testWidgets('the page: host, lock, chain, bridge, menu and visit record', (
      tester,
    ) async {
      final factory = FakeDappWebViewFactory();
      final store = MemoryDappBrowserStore();
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(url: Uri.parse('$s342Origin/swap')),
        ),
        factory: factory,
        store: store,
      );
      expect(
        find.byKey(const ValueKey<String>('fake-webview')),
        findsOneWidget,
      );
      expect(find.text('app.example.org'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('dapp-web-lock')),
        findsOneWidget,
      );
      expect(find.text(DappChains.label(s342Launch)), findsOneWidget);
      final config = factory.config!;
      expect(config.documentStartScript, contains('isLoop: true'));
      expect(
        config.shouldAllowNavigation(Uri.parse('http://x.example/')),
        isFalse,
      );
      expect(
        config.shouldAllowNavigation(Uri.parse('https://x.example/')),
        isTrue,
      );
      await tester.pumpAndSettle();

      // The script's nonce is the only one the bridge admits.
      final nonce = RegExp(r'var NONCE = "([0-9a-f]+)"')
          .firstMatch(config.documentStartScript)!
          .group(1)!;
      final answer = await config.onBridgeCall(
        _call('eth_chainId', const [], s342Origin, nonce),
      );
      expect((answer! as Map<String, Object?>)['result'], '0x61');

      expect((await store.read()).recents.single.title, 'Example DApp');

      await tester.tap(find.byKey(const ValueKey<String>('dapp-web-address')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dapp-url-full')),
        findsOneWidget,
      );
      expect(find.text('来源一致'), findsOneWidget);
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('dapp-web-chain')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-chain-eip155:56')),
      );
      await tester.pumpAndSettle();
      expect(find.text('BSC 主网'), findsOneWidget);
      expect(factory.controller.scripts.last, contains('chainChanged'));

      await tester.tap(find.byKey(const ValueKey<String>('dapp-web-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dapp-menu-disconnect')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-menu-bookmark')),
      );
      await tester.pumpAndSettle();
      expect((await store.read()).isBookmarked('$s342Origin/swap'), isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('dapp-web-reload')));
      await tester.pump();
      expect(factory.controller.calls, contains('reload'));
    });

    testWidgets('blocked URL, offline, error and unavailable states', (
      tester,
    ) async {
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(
            url: Uri.parse('https://user:pw@a.example/'),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('dapp-web-blocked')),
        findsOneWidget,
      );

      final factory = FakeDappWebViewFactory();
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(url: Uri.parse(s342Origin)),
        ),
        factory: factory,
      );
      factory.config!.onLoadFailed(DappLoadFailure.offline);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dapp-web-offline')),
        findsOneWidget,
      );
      factory.config!.onLoadFailed(DappLoadFailure.error);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('dapp-web-error')),
        findsOneWidget,
      );
    });

    testWidgets('dappBrowser closed: the page is unavailable', (tester) async {
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(url: Uri.parse(s342Origin)),
        ),
        browser: false,
      );
      expect(
        find.byKey(const ValueKey<String>('dapp-web-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('a flagged URL opened without acknowledgement shows findings', (
      tester,
    ) async {
      await pumpPage(
        tester,
        DappBrowserPage(
          key: UniqueKey(),
          request: DappOpenRequest(
            url: Uri.parse('https://app.example.org:8443/'),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('dapp-web-findings')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('fake-webview')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('dapp-web-findings-open')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('fake-webview')),
        findsOneWidget,
      );
    });
  });
}
