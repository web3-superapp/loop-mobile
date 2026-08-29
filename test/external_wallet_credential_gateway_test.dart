import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';
import 'package:reown_appkit/reown_appkit.dart';

void main() {
  const identity = ExternalWalletIdentity(
    address: '0x1111111111111111111111111111111111111111',
    chainId: '1',
    walletClientType: 'metamask',
    walletLabel: 'MetaMask',
  );

  test('parses only canonical EVM CAIP-10 accounts', () {
    final parsed = ExternalWalletProtocol.parseCaip10(
      'eip155:11155111:0x1111111111111111111111111111111111111111',
    );

    expect(parsed?.chainId, '11155111');
    expect(parsed?.caip2, 'eip155:11155111');
    expect(
      ExternalWalletProtocol.parseCaip10(
        'solana:mainnet:0x1111111111111111111111111111111111111111',
      ),
      isNull,
    );
    expect(
      ExternalWalletProtocol.parseCaip10(
        'eip155:0:0x1111111111111111111111111111111111111111',
      ),
      isNull,
    );
    expect(ExternalWalletProtocol.parseCaip10('eip155:1:0x1234'), isNull);
  });

  test('encodes the exact UTF-8 SIWE message for personal_sign', () {
    expect(
      ExternalWalletProtocol.personalSignPayload('LOOP ✓'),
      '0x4c4f4f5020e29c93',
    );
    expect(
      ExternalWalletProtocol.isSignature(
        '0x${List<String>.filled(65, '11').join()}',
      ),
      isTrue,
    );
    expect(ExternalWalletProtocol.isSignature('1234'), isFalse);
    expect(
      ExternalWalletProtocol.isSignature(
        '0x${List<String>.filled(63, '11').join()}',
      ),
      isFalse,
    );
  });

  test('maps concrete Reown rejection installation and callback errors', () {
    expect(
      ExternalWalletProtocol.mapModalError(UserRejectedConnection()).kind,
      ExternalWalletConnectorFailure.rejected,
    );
    expect(
      ExternalWalletProtocol.mapModalError(UserRejectedRequest()).kind,
      ExternalWalletConnectorFailure.rejected,
    );
    expect(
      ExternalWalletProtocol.mapModalError(WalletNotInstalled()).kind,
      ExternalWalletConnectorFailure.notInstalled,
    );
    expect(
      ExternalWalletProtocol.mapModalError(ErrorOpeningWallet()).kind,
      ExternalWalletConnectorFailure.callback,
    );
    expect(
      ExternalWalletProtocol.mapModalError(ModalError('relay unavailable'))
          .kind,
      ExternalWalletConnectorFailure.network,
    );
  });

  test(
    'initialization timeout reuses one owner and reconnects on retry',
    () async {
      final completion = Completer<void>();
      final gate = ExternalWalletInitializationGate<_InitializationOwner>(
        timeout: const Duration(milliseconds: 1),
      );
      var creates = 0;
      var reconnects = 0;
      final owner = _InitializationOwner();

      Future<_InitializationOwner> acquire() => gate.acquire(
        create: () {
          creates += 1;
          return owner;
        },
        initialize: (_) => completion.future,
        reconnect: (_) async {
          reconnects += 1;
        },
        isReady: (value) => value.isReady,
      );

      await expectLater(
        acquire(),
        throwsA(
          isA<ExternalWalletConnectorException>().having(
            (error) => error.kind,
            'kind',
            ExternalWalletConnectorFailure.network,
          ),
        ),
      );
      expect(gate.hasRetainedOwner, isTrue);
      expect(creates, 1);

      owner.isReady = true;
      completion.complete();
      expect(await acquire(), same(owner));
      expect(creates, 1);
      expect(reconnects, 1);
      gate.release(owner);
      expect(gate.hasRetainedOwner, isFalse);
    },
  );

  testWidgets(
    'signed-out intent signs and forwards exact params to SIWE login',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      final connector = _Connector(identity);
      final privy = _PrivyCredential();
      final gateway = PrivyExternalWalletCredentialGateway(connector, privy);

      final account = await gateway.authenticate(
        context: context,
        intent: ExternalWalletCredentialIntent.login,
      );

      expect(account.privyUserId, 'did:privy:wallet-login');
      expect(connector.message, 'quant-dinger.cc wants you to sign in');
      expect(privy.loginCalls, 1);
      expect(privy.linkCalls, 0);
      expect(privy.request?.appDomain, 'quant-dinger.cc');
      expect(privy.request?.appUri, 'https://quant-dinger.cc');
      expect(privy.request?.chainId, '1');
      expect(privy.request?.walletAddress, identity.address);
      expect(privy.request?.walletClientType, 'metamask');
      expect(privy.message, connector.message);
      expect(privy.signature, _validSignature);
    },
  );

  testWidgets('authenticated intent can only link to the expected principal', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final connector = _Connector(identity);
    final privy = _PrivyCredential();
    final gateway = PrivyExternalWalletCredentialGateway(connector, privy);

    final account = await gateway.authenticate(
      context: context,
      intent: ExternalWalletCredentialIntent.link,
      expectedPrivyUserId: 'did:privy:current',
    );

    expect(account.privyUserId, 'did:privy:current');
    expect(privy.linkCalls, 1);
    expect(privy.loginCalls, 0);
    expect(privy.expectedPrincipal, 'did:privy:current');
  });

  testWidgets('link without a principal never opens the wallet connector', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final connector = _Connector(identity);
    final gateway = PrivyExternalWalletCredentialGateway(
      connector,
      _PrivyCredential(),
    );

    await expectLater(
      gateway.authenticate(
        context: context,
        intent: ExternalWalletCredentialIntent.link,
      ),
      throwsA(isA<PrivyGatewayException>()),
    );
    expect(connector.calls, 0);
  });

  testWidgets(
    'rejects a proof whose identity differs from message generation',
    (tester) async {
      final context = await _pumpContext(tester);
      final connector = _Connector(
        identity,
        proofIdentity: const ExternalWalletIdentity(
          address: '0x2222222222222222222222222222222222222222',
          chainId: '1',
          walletClientType: 'metamask',
          walletLabel: 'MetaMask',
        ),
      );
      final privy = _PrivyCredential();

      await expectLater(
        PrivyExternalWalletCredentialGateway(connector, privy).authenticate(
          context: context,
          intent: ExternalWalletCredentialIntent.login,
        ),
        throwsA(
          isA<ExternalWalletConnectorException>().having(
            (error) => error.kind,
            'kind',
            ExternalWalletConnectorFailure.invalidResponse,
          ),
        ),
      );
      expect(privy.loginCalls, 0);
      expect(privy.linkCalls, 0);
    },
  );

  testWidgets('rejects a proof whose message or signature was replaced', (
    tester,
  ) async {
    final context = await _pumpContext(tester);
    final privy = _PrivyCredential();

    await expectLater(
      PrivyExternalWalletCredentialGateway(
        _Connector(identity, proofMessage: 'replacement'),
        privy,
      ).authenticate(
        context: context,
        intent: ExternalWalletCredentialIntent.login,
      ),
      throwsA(isA<ExternalWalletConnectorException>()),
    );
    await expectLater(
      PrivyExternalWalletCredentialGateway(
        _Connector(identity, signature: '0x1234'),
        privy,
      ).authenticate(
        context: context,
        intent: ExternalWalletCredentialIntent.login,
      ),
      throwsA(isA<ExternalWalletConnectorException>()),
    );
    expect(privy.loginCalls, 0);
    expect(privy.linkCalls, 0);
  });
}

const _validSignature =
    '0x1111111111111111111111111111111111111111111111111111111111111111'
    '111111111111111111111111111111111111111111111111111111111111111111';

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    ),
  );
  return context;
}

class _Connector implements ExternalWalletConnector {
  _Connector(
    this.identity, {
    this.proofIdentity,
    this.proofMessage,
    this.signature = _validSignature,
  });

  final ExternalWalletIdentity identity;
  final ExternalWalletIdentity? proofIdentity;
  final String? proofMessage;
  final String signature;
  var calls = 0;
  String? message;

  @override
  Future<ExternalWalletProof> connectAndSign({
    required BuildContext context,
    required Future<String> Function(ExternalWalletIdentity identity)
    createMessage,
  }) async {
    calls += 1;
    message = await createMessage(identity);
    return ExternalWalletProof(
      identity: proofIdentity ?? identity,
      message: proofMessage ?? message!,
      signature: signature,
    );
  }
}

class _InitializationOwner {
  bool isReady = false;
}

class _PrivyCredential implements PrivyCredentialGateway {
  PrivySiweRequest? request;
  String? message;
  String? signature;
  String? expectedPrincipal;
  var loginCalls = 0;
  var linkCalls = 0;

  @override
  Future<String> generateSiweMessage(PrivySiweRequest value) async {
    request = value;
    return 'quant-dinger.cc wants you to sign in';
  }

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) async {
    linkCalls += 1;
    this.request = request;
    this.message = message;
    this.signature = signature;
    expectedPrincipal = expectedPrivyUserId;
    return PrivyAccountSummary(privyUserId: expectedPrivyUserId);
  }

  @override
  Future<PrivyAccountSummary> loginWithOAuth(PrivyOAuthLoginProvider provider) {
    throw UnimplementedError();
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) async {
    loginCalls += 1;
    this.request = request;
    this.message = message;
    this.signature = signature;
    return const PrivyAccountSummary(privyUserId: 'did:privy:wallet-login');
  }
}
