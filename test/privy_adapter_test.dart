import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

/// Records every wallet call so a test can assert that a refused intent never
/// reached the device at all.
final class _RecordingSigner implements PrivyDeviceSigner {
  _RecordingSigner() : hash = '0x${'ab' * 32}';

  final bool ready = true;
  final String hash;
  int sendCalls = 0;
  int signatureCalls = 0;
  Map<String, Object?>? lastTransaction;
  String? lastFrom;
  String? lastChainId;

  @override
  bool get isReady => ready;

  @override
  Future<String> sendTransaction({
    required String chainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) async {
    sendCalls += 1;
    lastChainId = chainId;
    lastFrom = fromAddress;
    lastTransaction = transaction;
    return hash;
  }

  @override
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) async {
    signatureCalls += 1;
    return 'authorization-signature';
  }
}

final class _Host implements PrivyDeviceSigningHost {
  _Host(this.deviceSigner);

  @override
  final PrivyDeviceSigner deviceSigner;
}

void main() {
  final now = DateTime.utc(2026, 9, 9, 8);
  final perpIntent = SigningIntent.perpOrder(
    revision: 'intent_core_eth_0001',
    market: 'ETH',
    direction: OrderDirection.buy,
    orderType: PerpOrderType.market,
    size: '1.25',
    leverage: 20,
    price: '4630.50',
    margin: '289.41 USDC',
    fee: '2.89 USDC',
    builderFee: '0 USDC',
    liquidationEstimate: '4410.00',
    observedAt: now,
    expiresAt: now.add(const Duration(seconds: 15)),
  );

  SigningIntent canonicalTransfer() => SigningIntent.backendCanonical(
    revision: '9a1f0b7c-2d4e-4a5b-8c9d-0e1f2a3b4c5d',
    payloadDigest: 'a' * 64,
    title: '确认发送',
    kind: IntentKind.transfer,
    chainId: loopPrimaryChainId,
    payload: const DeviceTransactionPayload(
      fromAddress: '0x1111111111111111111111111111111111111111',
      transaction: <String, Object?>{'chainId': 56, 'value': '0x0'},
    ),
    observedAt: now,
    expiresAt: now.add(const Duration(minutes: 2)),
    fields: const <IntentField>[IntentField(label: '资产', value: 'WBNB')],
  );

  test('production Privy adapter fails closed without credentials', () async {
    final signer = _RecordingSigner();
    final adapter = PrivyWalletSigningGateway(
      host: _Host(signer),
      credentialsConfigured: false,
    );

    expect(adapter.availability, WalletGatewayAvailability.unavailable);
    final result = await adapter.handoff(canonicalTransfer(), now: now);
    expect(result.accepted, isFalse);
    expect(result.code, 'privy_credentials_missing');
    expect(signer.sendCalls, 0);
  });

  test('a backend-relayed intent never reaches the device wallet', () async {
    final signer = _RecordingSigner();
    final adapter = PrivyWalletSigningGateway(
      host: _Host(signer),
      credentialsConfigured: true,
    );

    final result = await adapter.handoff(perpIntent, now: now);

    expect(result.accepted, isFalse);
    expect(result.code, 'loop_backend_required');
    expect(signer.sendCalls, 0);
  });

  test('a locally built preview intent can never reach a wallet', () async {
    final signer = _RecordingSigner();
    final adapter = PrivyWalletSigningGateway(
      host: _Host(signer),
      credentialsConfigured: true,
    );
    final preview = SigningIntent.transfer(
      revision: 'preview-transfer',
      asset: 'WBNB',
      amount: '0.1 WBNB',
      recipient: '0x0000000000000000000000000000000000000001',
      network: 'BNB Smart Chain',
      fee: 'Unavailable',
      observedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
    );

    final result = await adapter.handoff(preview, now: now);

    expect(result.accepted, isFalse);
    expect(result.code, 'canonical_intent_required');
    expect(signer.sendCalls, 0);
    expect(signer.signatureCalls, 0);
  });

  test(
    'a canonical intent is broadcast verbatim by the bound wallet',
    () async {
      final signer = _RecordingSigner();
      final adapter = PrivyWalletSigningGateway(
        host: _Host(signer),
        credentialsConfigured: true,
      );

      final result = await adapter.handoff(canonicalTransfer(), now: now);

      expect(result.accepted, isTrue);
      expect(result.value, signer.hash);
      expect(signer.sendCalls, 1);
      expect(signer.lastFrom, '0x1111111111111111111111111111111111111111');
      expect(signer.lastTransaction, <String, Object?>{
        'chainId': 56,
        'value': '0x0',
      });
    },
  );

  test('an expired canonical intent is refused before the wallet', () async {
    final signer = _RecordingSigner();
    final adapter = PrivyWalletSigningGateway(
      host: _Host(signer),
      credentialsConfigured: true,
    );

    final result = await adapter.handoff(
      canonicalTransfer(),
      now: now.add(const Duration(minutes: 5)),
    );

    expect(result.accepted, isFalse);
    expect(result.code, 'intent_stale');
    expect(signer.sendCalls, 0);
  });

  test('a session without an embedded wallet cannot sign', () async {
    final adapter = PrivyWalletSigningGateway(
      host: _Host(const UnavailablePrivyDeviceSigner()),
      credentialsConfigured: true,
    );

    expect(adapter.availability, WalletGatewayAvailability.unavailable);
    final result = await adapter.handoff(canonicalTransfer(), now: now);
    expect(result.accepted, isFalse);
    expect(result.code, 'privy_wallet_unavailable');
  });

  test(
    'fixture adapter is explicitly read-only and never claims signing',
    () async {
      const adapter = PrivyFixtureAdapter();

      expect(adapter.availability, WalletGatewayAvailability.fixtureReadOnly);
      expect(adapter.label, contains('preview'));
      expect(adapter.label, contains('signing unavailable'));
      final result = await adapter.handoff(perpIntent, now: now);
      expect(result.accepted, isFalse);
      expect(result.code, 'fixture_read_only');
    },
  );
}
