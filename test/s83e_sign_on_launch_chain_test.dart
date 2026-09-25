import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:privy_flutter/privy_flutter.dart';
// The SDK provider logs through a static logger that `Privy(...)` normally
// initializes; these tests drive the real provider without constructing Privy.
// ignore: implementation_imports
import 'package:privy_flutter/src/logging/logger_service.dart';
// ignore: implementation_imports
import 'package:privy_flutter/src/logging/real_privy_logger.dart';

/// Decision 0090: the device signs a Launch intent on the published Launch
/// slot, and nothing else off the primary chain.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LoggerService.initializeLogger(
    RealPrivyLogger(level: PrivyLogLevel.none, appId: 'loop-test'),
  );

  const walletAddress = '0x1111111111111111111111111111111111111111';
  const launchpad = '0x2b26fc1300311476cc3032bcfbcfb6cb1d953396';
  const usd1 = '0x17d554fd27345940e21d1d7328d038bd4049ce2b';
  final hash = '0x${'ab' * 32}';
  final now = DateTime.utc(2026, 9, 25, 8);

  /// The loop-api `UnsignedTransaction` shape, exactly as the server sends it.
  Map<String, Object?> serverTransaction({
    required int chainId,
    String to = launchpad,
    String type = 'eip1559',
  }) => <String, Object?>{
    'chainId': chainId,
    'from': walletAddress,
    'to': to,
    'data': '0x095ea7b3${'00' * 64}',
    'value': '0x0',
    'gas': '0x186a0',
    'nonce': '0x3',
    'type': type,
    'maxFeePerGas': type == 'eip1559' ? '0x3b9aca00' : null,
    'maxPriorityFeePerGas': type == 'eip1559' ? '0x3b9aca00' : null,
    'gasPrice': type == 'legacy' ? '0x3b9aca00' : null,
  };

  group('the admission matrix (kind x chain)', () {
    const launchKinds = <IntentKind>{
      IntentKind.launchApproval,
      IntentKind.launchPurchase,
    };

    String? admit(
      IntentKind kind,
      String chainId, {
      required String? launchChainId,
      Object? transactionChainId,
    }) => privyChainRefusal(
      kind: kind,
      chainId: chainId,
      launchChainId: launchChainId,
      transaction: <String, Object?>{
        'chainId':
            transactionChainId ??
            (loopKnownChainIds.contains(chainId)
                ? loopChainReference(chainId)
                : 1),
      },
    );

    test('every kind signs on the primary chain, published slot or not', () {
      for (final kind in IntentKind.values) {
        for (final slot in <String?>[
          null,
          loopPrimaryChainId,
          loopLaunchTestnetChainId,
        ]) {
          expect(
            admit(kind, loopPrimaryChainId, launchChainId: slot),
            isNull,
            reason: '$kind on the primary chain with slot $slot',
          );
        }
      }
    });

    test('a Launch approval and purchase sign on the published slot', () {
      for (final kind in launchKinds) {
        expect(
          admit(
            kind,
            loopLaunchTestnetChainId,
            launchChainId: loopLaunchTestnetChainId,
          ),
          isNull,
          reason: '$kind on the published Launch slot',
        );
      }
    });

    test('send, approval, swap and perp are refused on the Launch slot', () {
      for (final kind in IntentKind.values.where(
        (kind) => !launchKinds.contains(kind),
      )) {
        expect(
          admit(
            kind,
            loopLaunchTestnetChainId,
            launchChainId: loopLaunchTestnetChainId,
          ),
          'privy_chain_switch_unsupported',
          reason: '$kind must never be signed on the Launch testnet',
        );
      }
    });

    test('an omitted launchChain means the slot is the primary chain', () {
      for (final kind in launchKinds) {
        expect(
          admit(kind, loopLaunchTestnetChainId, launchChainId: null),
          'privy_chain_switch_unsupported',
        );
        expect(
          admit(
            kind,
            loopLaunchTestnetChainId,
            launchChainId: loopPrimaryChainId,
          ),
          'privy_chain_switch_unsupported',
        );
      }
    });

    test('an unknown chain is refused for every kind', () {
      for (final kind in IntentKind.values) {
        expect(
          admit(kind, 'eip155:1', launchChainId: 'eip155:1'),
          'privy_chain_mismatch',
        );
      }
    });

    test('a payload chain that disagrees with the intent is refused', () {
      for (final kind in launchKinds) {
        expect(
          admit(
            kind,
            loopLaunchTestnetChainId,
            launchChainId: loopLaunchTestnetChainId,
            transactionChainId: 56,
          ),
          'privy_chain_mismatch',
        );
        expect(
          admit(
            kind,
            loopPrimaryChainId,
            launchChainId: loopLaunchTestnetChainId,
            transactionChainId: 97,
          ),
          'privy_chain_mismatch',
        );
        // A string reference is not the published integer: refused, never
        // coerced.
        expect(
          admit(
            kind,
            loopLaunchTestnetChainId,
            launchChainId: loopLaunchTestnetChainId,
            transactionChainId: '0x61',
          ),
          'privy_chain_mismatch',
        );
      }
    });

    test('a payload without a chainId is refused, not sent to mainnet', () {
      expect(
        privyChainRefusal(
          kind: IntentKind.launchPurchase,
          chainId: loopLaunchTestnetChainId,
          launchChainId: loopLaunchTestnetChainId,
          transaction: const <String, Object?>{'to': launchpad},
        ),
        'privy_chain_mismatch',
      );
    });
  });

  group('the Privy spelling of the server payload', () {
    test('only gas, type and null keys are respelled; no value changes', () {
      final decoded = jsonDecode(
        privyTransactionJson(serverTransaction(chainId: 97)),
      ) as Map<String, Object?>;

      expect(decoded, <String, Object?>{
        'chainId': 97,
        'from': walletAddress,
        'to': launchpad,
        'data': '0x095ea7b3${'00' * 64}',
        'value': '0x0',
        'gasLimit': '0x186a0',
        'nonce': '0x3',
        'type': 2,
        'maxFeePerGas': '0x3b9aca00',
        'maxPriorityFeePerGas': '0x3b9aca00',
      });
    });

    test('a legacy payload is type 0 and keeps its gasPrice', () {
      final decoded = jsonDecode(
        privyTransactionJson(serverTransaction(chainId: 56, type: 'legacy')),
      ) as Map<String, Object?>;

      expect(decoded['type'], 0);
      expect(decoded['gasPrice'], '0x3b9aca00');
      expect(decoded.containsKey('maxFeePerGas'), isFalse);
      expect(decoded.containsKey('gas'), isFalse);
    });

    test('an unknown type or a doubled gas limit is refused', () {
      expect(
        () => privyTransactionJson(serverTransaction(chainId: 97, type: 'x')),
        throwsA(
          isA<PrivySigningException>().having(
            (failure) => failure.code,
            'code',
            'privy_payload_unencodable',
          ),
        ),
      );
      expect(
        () => privyTransactionJson(
          serverTransaction(chainId: 97)..['gasLimit'] = '0x1',
        ),
        throwsA(
          isA<PrivySigningException>().having(
            (failure) => failure.code,
            'code',
            'privy_payload_unencodable',
          ),
        ),
      );
    });
  });

  group('the SDK call itself', () {
    late List<MethodCall> calls;
    late Object? Function(MethodCall call) answer;

    setUp(() {
      calls = <MethodCall>[];
      answer = (call) => <String, Object?>{
        'method': 'eth_sendTransaction',
        'data': hash,
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('privy_flutter'), (
            call,
          ) async {
            calls.add(call);
            final reply = answer(call);
            if (reply is PlatformException) throw reply;
            return reply;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('privy_flutter'), null);
    });

    SdkPrivyDeviceSigner signer() => SdkPrivyDeviceSigner(
      _FakePrivyUser(<EmbeddedEthereumWallet>[
        EmbeddedEthereumWallet(address: walletAddress, hdWalletIndex: 0),
      ]),
    );

    Map<String, Object?> sentTransaction(MethodCall call) {
      final arguments = call.arguments as Map<Object?, Object?>;
      final params = arguments['params']! as List<Object?>;
      expect(params, hasLength(1));
      expect(params.single, isA<String>());
      return jsonDecode(params.single! as String) as Map<String, Object?>;
    }

    test('a Launch approval on the published slot is one eth_sendTransaction '
        'whose own chainId is 97, and nothing else', () async {
      final result = await signer().sendTransaction(
        kind: IntentKind.launchApproval,
        chainId: loopLaunchTestnetChainId,
        launchChainId: loopLaunchTestnetChainId,
        fromAddress: walletAddress,
        transaction: serverTransaction(chainId: 97, to: usd1),
      );

      expect(result, hash);
      expect(calls.map((call) => call.method), <String>['ethSendRpcRequest']);
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['method'], 'eth_sendTransaction');
      expect(arguments['walletAddress'], walletAddress);
      final sent = sentTransaction(calls.single);
      expect(sent['chainId'], 97);
      expect(sent['to'], usd1);
    });

    test(
      'the chain is the payload\'s own, so nothing carries over: a purchase '
      'on 97 then a send on 56 each reach the SDK with their own chainId',
      () async {
        final device = signer();
        await device.sendTransaction(
          kind: IntentKind.launchPurchase,
          chainId: loopLaunchTestnetChainId,
          launchChainId: loopLaunchTestnetChainId,
          fromAddress: walletAddress,
          transaction: serverTransaction(chainId: 97),
        );
        await device.sendTransaction(
          kind: IntentKind.transfer,
          chainId: loopPrimaryChainId,
          launchChainId: loopLaunchTestnetChainId,
          fromAddress: walletAddress,
          transaction: serverTransaction(chainId: 56, to: usd1),
        );

        // No chain-selection call exists in privy_flutter 0.10.1, and none is
        // made: the only traffic is the two broadcasts.
        expect(calls.map((call) => call.method), <String>[
          'ethSendRpcRequest',
          'ethSendRpcRequest',
        ]);
        expect(sentTransaction(calls[0])['chainId'], 97);
        expect(sentTransaction(calls[1])['chainId'], 56);
      },
    );

    test('a refused chain never reaches the SDK', () async {
      for (final (kind, launchChainId) in <(IntentKind, String?)>[
        (IntentKind.launchPurchase, null),
        (IntentKind.launchApproval, loopPrimaryChainId),
        (IntentKind.transfer, loopLaunchTestnetChainId),
        (IntentKind.approval, loopLaunchTestnetChainId),
        (IntentKind.swap, loopLaunchTestnetChainId),
      ]) {
        await expectLater(
          signer().sendTransaction(
            kind: kind,
            chainId: loopLaunchTestnetChainId,
            launchChainId: launchChainId,
            fromAddress: walletAddress,
            transaction: serverTransaction(chainId: 97),
          ),
          throwsA(
            isA<PrivySigningException>().having(
              (failure) => failure.code,
              'code',
              'privy_chain_switch_unsupported',
            ),
          ),
          reason: '$kind with slot $launchChainId',
        );
      }
      expect(calls, isEmpty);
    });

    test(
      'an SDK failure on the Launch slot stays an unknown outcome',
      () async {
        // A provider error after the call left the device cannot prove nothing
        // was broadcast, so it locks exactly as it does on the primary chain.
        answer = (call) => PlatformException(
          code: 'RPC_REQUEST_FAILED',
          message: 'This chain is unsupported.',
        );

        await expectLater(
          signer().sendTransaction(
            kind: IntentKind.launchPurchase,
            chainId: loopLaunchTestnetChainId,
            launchChainId: loopLaunchTestnetChainId,
            fromAddress: walletAddress,
            transaction: serverTransaction(chainId: 97),
          ),
          throwsA(
            isA<PrivySigningException>().having(
              (failure) => failure.code,
              'code',
              'wallet_outcome_unknown',
            ),
          ),
        );
        expect(calls, hasLength(1));
      },
    );

    test('an owner decline on the Launch slot is a plain rejection', () async {
      answer = (call) => PlatformException(
        code: 'RPC_REQUEST_FAILED',
        message: 'User rejected the request',
      );

      await expectLater(
        signer().sendTransaction(
          kind: IntentKind.launchApproval,
          chainId: loopLaunchTestnetChainId,
          launchChainId: loopLaunchTestnetChainId,
          fromAddress: walletAddress,
          transaction: serverTransaction(chainId: 97, to: usd1),
        ),
        throwsA(
          isA<PrivySigningException>().having(
            (failure) => failure.code,
            'code',
            'privy_broadcast_rejected',
          ),
        ),
      );
    });
  });

  group('the signing exit reads the Launch slot', () {
    SigningIntent intent(IntentKind kind, String chainId) =>
        SigningIntent.backendCanonical(
          revision: 'intent_s83e_0001',
          payloadDigest: 'sha256:${'cd' * 32}',
          title: '确认认购',
          kind: kind,
          chainId: chainId,
          payload: DeviceTransactionPayload(
            fromAddress: walletAddress,
            transaction: serverTransaction(
              chainId: loopChainReference(chainId),
            ),
          ),
          observedAt: now,
          expiresAt: now.add(const Duration(minutes: 5)),
          fields: const <IntentField>[],
        );

    test('a primary-chain send never waits on chain/status', () async {
      final device = _RecordingSigner();
      var reads = 0;
      final gateway = PrivyWalletSigningGateway(
        host: _Host(device),
        credentialsConfigured: true,
        readLaunchChain: () async {
          reads += 1;
          return loopLaunchTestnetChainId;
        },
      );

      final result = await gateway.handoff(
        intent(IntentKind.transfer, loopPrimaryChainId),
        now: now,
      );

      expect(result.accepted, isTrue);
      expect(reads, 0);
      expect(device.lastKind, IntentKind.transfer);
      expect(device.lastLaunchChainId, isNull);
    });

    test('a Launch intent carries the published slot to the device', () async {
      final device = _RecordingSigner();
      final gateway = PrivyWalletSigningGateway(
        host: _Host(device),
        credentialsConfigured: true,
        readLaunchChain: () async => loopLaunchTestnetChainId,
      );

      final result = await gateway.handoff(
        intent(IntentKind.launchApproval, loopLaunchTestnetChainId),
        now: now,
      );

      expect(result.accepted, isTrue);
      expect(device.lastKind, IntentKind.launchApproval);
      expect(device.lastChainId, loopLaunchTestnetChainId);
      expect(device.lastLaunchChainId, loopLaunchTestnetChainId);
    });

    test('an unreadable chain/status publishes no slot', () async {
      final device = _RecordingSigner();
      final gateway = PrivyWalletSigningGateway(
        host: _Host(device),
        credentialsConfigured: true,
        readLaunchChain: () async => throw StateError('offline'),
      );

      await gateway.handoff(
        intent(IntentKind.launchPurchase, loopLaunchTestnetChainId),
        now: now,
      );

      expect(device.lastLaunchChainId, isNull);
    });

    test('end to end: the real device signer behind the exit', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('privy_flutter'), (
            call,
          ) async {
            calls.add(call);
            return <String, Object?>{
              'method': 'eth_sendTransaction',
              'data': hash,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('privy_flutter'),
              null,
            ),
      );
      final device = SdkPrivyDeviceSigner(
        _FakePrivyUser(<EmbeddedEthereumWallet>[
          EmbeddedEthereumWallet(address: walletAddress, hdWalletIndex: 0),
        ]),
      );

      final published =
          await PrivyWalletSigningGateway(
            host: _Host(device),
            credentialsConfigured: true,
            readLaunchChain: () async => loopLaunchTestnetChainId,
          ).handoff(
            intent(IntentKind.launchPurchase, loopLaunchTestnetChainId),
            now: now,
          );
      final omitted =
          await PrivyWalletSigningGateway(
            host: _Host(device),
            credentialsConfigured: true,
            readLaunchChain: () async => null,
          ).handoff(
            intent(IntentKind.launchPurchase, loopLaunchTestnetChainId),
            now: now,
          );

      expect(published.accepted, isTrue);
      expect(published.value, hash);
      expect(omitted.accepted, isFalse);
      expect(omitted.code, 'privy_chain_switch_unsupported');
      expect(calls, hasLength(1));
    });
  });
}

final class _FakePrivyUser implements PrivyUser {
  _FakePrivyUser(this.embeddedEthereumWallets);

  @override
  final List<EmbeddedEthereumWallet> embeddedEthereumWallets;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _RecordingSigner implements PrivyDeviceSigner {
  IntentKind? lastKind;
  String? lastChainId;
  String? lastLaunchChainId;

  @override
  bool get isReady => true;

  @override
  Future<String> sendTransaction({
    required IntentKind kind,
    required String chainId,
    required String? launchChainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) async {
    lastKind = kind;
    lastChainId = chainId;
    lastLaunchChainId = launchChainId;
    return '0x${'ab' * 32}';
  }

  @override
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) async => 'authorization-signature';
}

final class _Host implements PrivyDeviceSigningHost {
  _Host(this.deviceSigner);

  @override
  final PrivyDeviceSigner deviceSigner;
}
