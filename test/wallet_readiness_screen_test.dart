import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  const firstAddress = '0x1111111111111111111111111111111111111111';

  group('WalletReadiness', () {
    test('projects Preview and unverified sessions without wallet access', () {
      expect(
        WalletReadiness.fromSession(const LoopSessionState.preview()).mode,
        WalletReadinessMode.preview,
      );
      expect(
        WalletReadiness.fromSession(
          const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified),
        ).mode,
        WalletReadinessMode.restricted,
      );
    });

    test('requires a wallet only for a fully verified account', () {
      final readiness = WalletReadiness.fromSession(
        const LoopSessionState(
          mode: LoopSessionMode.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:test'),
        ),
      );

      expect(readiness.mode, WalletReadinessMode.needsWallet);
      expect(readiness.canCreate, isTrue);
      expect(readiness.canCopy, isFalse);
    });

    test('exposes only a complete Ethereum address', () {
      final ready = WalletReadiness.fromSession(
        const LoopSessionState(
          mode: LoopSessionMode.authenticated,
          account: PrivyAccountSummary(
            privyUserId: 'did:privy:test',
            wallet: PrivyWalletSummary(address: firstAddress),
          ),
        ),
      );
      final invalid = WalletReadiness.fromSession(
        const LoopSessionState(
          mode: LoopSessionMode.authenticated,
          account: PrivyAccountSummary(
            privyUserId: 'did:privy:test',
            wallet: PrivyWalletSummary(address: '0x123'),
          ),
        ),
      );

      expect(ready.mode, WalletReadinessMode.ready);
      expect(ready.ethereumAddress, firstAddress);
      expect(ready.canCopy, isTrue);
      expect(invalid.mode, WalletReadinessMode.invalidAddress);
      expect(invalid.ethereumAddress, isNull);
      expect(invalid.canCopy, isFalse);
    });
  });
}
