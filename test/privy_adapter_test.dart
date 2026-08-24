import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/privy_fixture_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

void main() {
  final now = DateTime.utc(2026, 8, 24, 8);
  final intent = SigningIntent.perpOrder(
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

  test('production Privy adapter fails closed without credentials', () async {
    final adapter = PrivyProductionAdapter(appId: '', appClientId: '');

    expect(adapter.availability, WalletGatewayAvailability.unavailable);
    final result = await adapter.handoff(intent, now: now);
    expect(result.accepted, isFalse);
    expect(result.code, 'privy_credentials_missing');
  });

  test('public credentials never enable client Perp signing', () async {
    const adapter = PrivyProductionAdapter(
      appId: 'public-app-id',
      appClientId: 'public-client-id',
    );

    expect(adapter.availability, WalletGatewayAvailability.unavailable);
    final result = await adapter.handoff(intent, now: now);
    expect(result.accepted, isFalse);
    expect(result.code, 'loop_backend_required');
  });

  test('locally built transfers cannot reach Privy handoff', () async {
    const adapter = PrivyProductionAdapter(
      appId: 'public-app-id',
      appClientId: 'public-client-id',
    );
    final transfer = SigningIntent.transfer(
      revision: 'preview-transfer',
      asset: 'ETH',
      amount: '0.1 ETH',
      recipient: '0x0000000000000000000000000000000000000001',
      network: 'Ethereum',
      fee: 'Unavailable',
      observedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
    );

    final result = await adapter.handoff(transfer, now: now);

    expect(result.accepted, isFalse);
    expect(result.code, 'canonical_intent_required');
  });

  test(
    'fixture adapter is explicitly read-only and never claims signing',
    () async {
      const adapter = PrivyFixtureAdapter();

      expect(adapter.availability, WalletGatewayAvailability.fixtureReadOnly);
      expect(adapter.label, contains('preview'));
      expect(adapter.label, contains('signing unavailable'));
      final result = await adapter.handoff(intent, now: now);
      expect(result.accepted, isFalse);
      expect(result.code, 'fixture_read_only');
    },
  );
}
