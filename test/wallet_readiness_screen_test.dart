import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/wallet_management_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_overview_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_readiness.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  const firstAddress = '0x1111111111111111111111111111111111111111';
  const secondAddress = '0x2222222222222222222222222222222222222222';

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

  testWidgets(
    'authenticated Wallet creates one embedded Ethereum wallet and publishes the exact address',
    (tester) async {
      final creation = Completer<PrivyWalletCreationResult>();
      final gateway = _WalletGateway(
        restoreSnapshot: _authenticatedSnapshot(),
        creationOperation: creation.future,
      );
      addTearDown(gateway.dispose);
      await _pump(tester, gateway, const WalletScreen());

      final create = find.widgetWithText(
        FilledButton,
        'Create embedded wallet',
      );
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.tap(create);
      await tester.pump();

      expect(gateway.creationCalls, 1);
      expect(find.text('Creating wallet…'), findsOneWidget);

      creation.complete(
        const PrivyWalletCreationResult(
          privyUserId: 'did:privy:wallet-test',
          wallet: PrivyWalletSummary(address: firstAddress),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wallet ready'), findsOneWidget);
      expect(find.text(firstAddress), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('DEMO PORTFOLIO'), findsOneWidget);
      expect(find.text('Portfolio remains 开发预览'), findsOneWidget);
      expect(find.text('Send preview'), findsOneWidget);
      expect(find.text('Swap preview'), findsOneWidget);
    },
  );

  testWidgets('existing wallet never exposes a create action', (tester) async {
    final gateway = _WalletGateway(
      restoreSnapshot: _authenticatedSnapshot(walletAddress: firstAddress),
    );
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const WalletScreen());

    expect(find.text('Wallet ready'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Create embedded wallet'),
      findsNothing,
    );
    expect(gateway.creationCalls, 0);
  });

  testWidgets('restricted Wallet never invokes wallet creation', (
    tester,
  ) async {
    final gateway = _WalletGateway(
      restoreSnapshot: const PrivySessionSnapshot(
        PrivySessionKind.authenticatedUnverified,
      ),
    );
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const WalletScreen());

    expect(find.text('Wallet requires a verified session'), findsOneWidget);
    expect(find.text('Create embedded wallet'), findsNothing);
    expect(gateway.creationCalls, 0);
  });

  testWidgets(
    'wallet creation failure stays retryable and never fabricates an address',
    (tester) async {
      final creation = Completer<PrivyWalletCreationResult>();
      final gateway = _WalletGateway(
        restoreSnapshot: _authenticatedSnapshot(),
        creationOperation: creation.future,
      );
      addTearDown(gateway.dispose);
      await _pump(tester, gateway, const WalletScreen());

      final create = find.widgetWithText(
        FilledButton,
        'Create embedded wallet',
      );
      await tester.ensureVisible(create);
      await tester.tap(create);
      creation.completeError(const PrivyGatewayException('钱包创建状态未确认，请稍后刷新重试。'));
      await tester.pumpAndSettle();

      expect(find.text('Wallet creation not confirmed'), findsOneWidget);
      expect(find.text('钱包创建状态未确认，请稍后刷新重试。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallet-ready-address')),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Create embedded wallet'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Receive copies the exact current Privy address', (tester) async {
    String? copiedText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final gateway = _WalletGateway(
      restoreSnapshot: _authenticatedSnapshot(walletAddress: firstAddress),
    );
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const ReceiveScreen());

    expect(find.text(firstAddress), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Receiving is not enabled'), findsOneWidget);
    expect(find.text('NOT A DEPOSIT QR'), findsNothing);
    expect(find.text('Arbitrum'), findsNothing);
    expect(find.text('Solana'), findsNothing);

    final copy = find.widgetWithText(
      OutlinedButton,
      'Copy full Ethereum wallet address',
    );
    await tester.tap(copy);
    await tester.pump();

    expect(copiedText, firstAddress);
    expect(find.text('Wallet address copied.'), findsOneWidget);
  });

  testWidgets('Receive disables copy when no current address exists', (
    tester,
  ) async {
    final gateway = _WalletGateway(restoreSnapshot: _authenticatedSnapshot());
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const ReceiveScreen());

    expect(find.text('No embedded wallet yet'), findsOneWidget);
    final copy = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'No wallet address to copy'),
    );
    expect(copy.onPressed, isNull);
    expect(find.text('Receiving is not enabled'), findsOneWidget);
  });

  testWidgets('Receive clipboard failure never claims success', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'clipboard_unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final gateway = _WalletGateway(
      restoreSnapshot: _authenticatedSnapshot(walletAddress: firstAddress),
    );
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const ReceiveScreen());

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Copy full Ethereum wallet address'),
    );
    await tester.pump();

    expect(
      find.text('Wallet address was not copied. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Wallet address copied.'), findsNothing);
  });

  testWidgets(
    'Receive warns when the account changes during a clipboard write',
    (tester) async {
      String? copiedText;
      final clipboardWrite = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String;
          await clipboardWrite.future;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final gateway = _WalletGateway(
        restoreSnapshot: _authenticatedSnapshot(walletAddress: firstAddress),
      );
      addTearDown(gateway.dispose);
      await _pump(tester, gateway, const ReceiveScreen());

      await tester.tap(
        find.widgetWithText(
          OutlinedButton,
          'Copy full Ethereum wallet address',
        ),
      );
      await tester.pump();
      expect(copiedText, firstAddress);

      gateway.emit(
        const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(
            privyUserId: 'did:privy:second-wallet-test',
            wallet: PrivyWalletSummary(address: secondAddress),
          ),
        ),
      );
      await tester.pump();
      clipboardWrite.complete();
      await tester.pumpAndSettle();

      expect(find.text(secondAddress), findsOneWidget);
      expect(
        find.text(
          'Wallet changed while copying. Check the address before using it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Wallet address copied.'), findsNothing);
    },
  );

  testWidgets('Manage wallets shows only the current provider wallet', (
    tester,
  ) async {
    final gateway = _WalletGateway(
      restoreSnapshot: _authenticatedSnapshot(walletAddress: firstAddress),
    );
    addTearDown(gateway.dispose);
    await _pump(tester, gateway, const WalletManagerScreen());

    expect(find.text(firstAddress), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Embedded Ethereum wallet'), findsOneWidget);
    expect(find.textContaining('Daily wallet'), findsNothing);
    expect(find.textContaining('Trading wallet'), findsNothing);
    expect(find.textContaining('0x71E4'), findsNothing);
    expect(find.textContaining('0x88C2'), findsNothing);
    expect(
      find.text('Wallet identity is not signing authority'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Manage wallets separates linked credentials from the trading wallet',
    (tester) async {
      final gateway = _WalletGateway(
        restoreSnapshot: const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(
            privyUserId: 'did:privy:wallet-test',
            wallet: PrivyWalletSummary(address: firstAddress),
            externalEvmCredentials: <PrivyExternalEvmCredentialSummary>[
              PrivyExternalEvmCredentialSummary(
                address: secondAddress,
                chainId: '1',
                walletClientType: 'metamask',
              ),
            ],
          ),
        ),
      );
      addTearDown(gateway.dispose);
      await _pump(tester, gateway, const WalletManagerScreen());

      expect(find.text(firstAddress), findsOneWidget);
      expect(find.text(secondAddress), findsOneWidget);
      expect(find.text('1 linked'), findsOneWidget);
      expect(find.textContaining('not a LOOP trading wallet'), findsOneWidget);
      expect(find.text('Additional transaction wallets'), findsOneWidget);
    },
  );
}

PrivySessionSnapshot _authenticatedSnapshot({String? walletAddress}) {
  return PrivySessionSnapshot(
    PrivySessionKind.authenticated,
    account: PrivyAccountSummary(
      privyUserId: 'did:privy:wallet-test',
      wallet: walletAddress == null
          ? null
          : PrivyWalletSummary(address: walletAddress),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  PrivyAuthGateway gateway,
  Widget child,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(theme: LoopTheme.dark, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

final class _WalletGateway implements PrivyAuthGateway {
  _WalletGateway({required this.restoreSnapshot, this.creationOperation});

  final PrivySessionSnapshot restoreSnapshot;
  final Future<PrivyWalletCreationResult>? creationOperation;
  final _session = StreamController<PrivySessionSnapshot>.broadcast();
  var creationCalls = 0;

  Future<void> dispose() => _session.close();

  void emit(PrivySessionSnapshot snapshot) => _session.add(snapshot);

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    creationCalls += 1;
    return creationOperation ??
        Future<PrivyWalletCreationResult>.value(
          PrivyWalletCreationResult(
            privyUserId: expectedPrivyUserId,
            wallet: const PrivyWalletSummary(
              address: '0x2222222222222222222222222222222222222222',
            ),
          ),
        );
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw UnsupportedError('Not used by Wallet readiness tests.');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() async => restoreSnapshot;

  @override
  Future<void> sendEmailCode(String email) {
    throw UnsupportedError('Not used by Wallet readiness tests.');
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw UnsupportedError('Not used by Wallet readiness tests.');
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _session.stream;
}
