import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/wallet_management_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  const walletAddress = '0x3333333333333333333333333333333333333333';

  testWidgets(
    'DApp preview uses only the current wallet identity and typed domain',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(walletAddress: walletAddress),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const DappBrowserScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(walletAddress), findsOneWidget);
      expect(find.textContaining('0x71E4'), findsNothing);
      expect(find.text('Wallet injection'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'typed.example');
      await tester.pump();

      expect(find.text('typed.example'), findsWidgets);
      expect(
        find.text(
          'The typed domain is not trusted, opened, resolved, or connected to a wallet.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsNothing);
    },
  );

  testWidgets('DApp preview never invents a wallet for a verified account', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const DappBrowserScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current wallet identity'), findsOneWidget);
    expect(find.textContaining('0x'), findsNothing);
    expect(find.textContaining('Selected wallet'), findsNothing);
  });

  testWidgets(
    'DApp preview drops stale wallet identity when the session changes',
    (tester) async {
      const firstAddress = '0x4444444444444444444444444444444444444444';
      const secondAddress = '0x5555555555555555555555555555555555555555';
      final gateway = _SessionChangingPrivyGateway(
        restoreSnapshot: _authenticatedSnapshot(
          principal: 'did:privy:first',
          walletAddress: firstAddress,
        ),
      );
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const DappBrowserScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(firstAddress), findsOneWidget);

      gateway.emit(
        _authenticatedSnapshot(
          principal: 'did:privy:second',
          walletAddress: secondAddress,
        ),
      );
      await tester.pump();
      expect(find.text(firstAddress), findsNothing);
      expect(find.text(secondAddress), findsOneWidget);

      gateway.emit(
        const PrivySessionSnapshot(PrivySessionKind.authenticatedUnverified),
      );
      await tester.pump();
      expect(find.text(secondAddress), findsNothing);
      expect(find.text('Unavailable'), findsWidgets);

      gateway.emit(
        const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
      );
      await tester.pump();
      expect(find.text(firstAddress), findsNothing);
      expect(find.text(secondAddress), findsNothing);
    },
  );
}

PrivySessionSnapshot _authenticatedSnapshot({
  required String principal,
  required String walletAddress,
}) {
  return PrivySessionSnapshot(
    PrivySessionKind.authenticated,
    account: PrivyAccountSummary(
      privyUserId: principal,
      wallet: PrivyWalletSummary(address: walletAddress),
    ),
  );
}

final class _SessionChangingPrivyGateway implements PrivyAuthGateway {
  _SessionChangingPrivyGateway({required this.restoreSnapshot});

  final PrivySessionSnapshot restoreSnapshot;
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast(
    sync: true,
  );

  Future<void> dispose() => _snapshots.close();

  void emit(PrivySessionSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<PrivySessionSnapshot> restoreSession() async => restoreSnapshot;

  @override
  Stream<PrivySessionSnapshot> watchSession() => _snapshots.stream;

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    throw UnsupportedError('Not used by DApp preview tests.');
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw UnsupportedError('Not used by DApp preview tests.');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) {
    throw UnsupportedError('Not used by DApp preview tests.');
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw UnsupportedError('Not used by DApp preview tests.');
  }
}
