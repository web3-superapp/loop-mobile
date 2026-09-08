import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

void main() {
  group('splash', () {
    testWidgets('offers the single entry action and the build version', (
      tester,
    ) async {
      var entered = false;
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'splash',
          versionLabel: 'Version 0.1.0+1',
          onNavigate: (_) => entered = true,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-splash-wordmark')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-splash-loader')),
        findsOneWidget,
      );
      expect(find.text('Version 0.1.0+1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('loop-splash-enter')));
      await tester.pump();
      expect(entered, isTrue);
    });
  });

  group('auth-wallet', () {
    testWidgets('states its unavailable reason and lists no wallet', (
      tester,
    ) async {
      await _pump(tester, const AccountSurfaceScreen.fromId('auth-wallet'));

      expect(
        find.byKey(const ValueKey<String>('external-wallet-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('external-wallet-list-unavailable')),
        findsOneWidget,
      );
      expect(find.text('MetaMask'), findsNothing);
      expect(find.text('Phantom'), findsNothing);
      expect(_enabled(tester, 'external-wallet-connect'), isFalse);
    });

    testWidgets('enables the connect action only with the capability', (
      tester,
    ) async {
      var connected = false;
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'auth-wallet',
          capabilities: const PrivyWalletCapabilities(
            canConnectExternalWallet: true,
          ),
          onPrimaryAction: () => connected = true,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('external-wallet-unavailable')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('external-wallet-connect')),
      );
      await tester.pump();
      expect(connected, isTrue);
    });
  });

  group('wallet-create', () {
    testWidgets('never fabricates progress without the capability', (
      tester,
    ) async {
      await _pump(tester, const AccountSurfaceScreen.fromId('wallet-create'));

      expect(
        find.byKey(const ValueKey<String>('wallet-create-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-create-progress')),
        findsNothing,
      );
      expect(_enabled(tester, 'wallet-create-continue'), isFalse);
      expect(find.textContaining('助记词'), findsWidgets);
    });

    testWidgets('continues to the recovery step when the wallet can be made', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-create',
          capabilities: const PrivyWalletCapabilities(
            canCreateEmbeddedWallet: true,
          ),
          onNavigate: destinations.add,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-create-continue')),
      );
      await tester.pump();
      expect(destinations, <String>['wallet-recovery']);
    });
  });

  group('wallet-recovery', () {
    testWidgets('shows every option as unavailable with a reason', (
      tester,
    ) async {
      await _pump(tester, const AccountSurfaceScreen.fromId('wallet-recovery'));

      expect(
        find.byKey(const ValueKey<String>('wallet-recovery-unavailable')),
        findsOneWidget,
      );
      expect(find.text('不可用'), findsNWidgets(5));
      expect(find.text('可用'), findsNothing);
      // Confirm cannot pretend a recovery method was chosen.
      expect(_enabled(tester, 'wallet-recovery-confirm'), isFalse);
      // Skipping stays possible and honest about the consequence.
      expect(_enabled(tester, 'wallet-recovery-later'), isTrue);
    });

    testWidgets('no mnemonic reveal, verify or import entry survives', (
      tester,
    ) async {
      await _pump(tester, const AccountSurfaceScreen.fromId('wallet-recovery'));

      // The page may say LOOP has no mnemonic; it must not offer one.
      expect(find.textContaining('查看助记词'), findsNothing);
      expect(find.textContaining('抄写'), findsNothing);
      expect(find.textContaining('验证助记词'), findsNothing);
      expect(find.textContaining('恢复短语'), findsNothing);
      expect(find.textContaining('导入'), findsNothing);
    });

    testWidgets('enables confirm once one method is really available', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-recovery',
          capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
          onNavigate: destinations.add,
        ),
      );

      expect(find.text('可用'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-recovery-confirm')),
      );
      await tester.pump();
      expect(destinations, <String>['security-setup']);
    });
  });

  group('security-setup', () {
    testWidgets('exposes no protection switch and no stored PIN claim', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          capabilities: const PrivyWalletCapabilities(
            canUsePasskey: true,
            canUseBiometrics: true,
          ),
          onNavigate: destinations.add,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('protection-setup-unavailable')),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('已开启'), findsNothing);
      // A confirmed device capability is shown as a capability only.
      expect(find.text('可用'), findsOneWidget);
      expect(find.text('不可用'), findsNWidgets(3));

      await tester.tap(
        find.byKey(const ValueKey<String>('security-setup-continue')),
      );
      await tester.pump();
      expect(destinations, <String>['loop-id-setup']);
    });
  });

  group('shared step chrome', () {
    testWidgets('every step page uses the focus layout and a progress track', (
      tester,
    ) async {
      for (final id in <String>[
        'auth-wallet',
        'wallet-create',
        'wallet-recovery',
        'security-setup',
      ]) {
        await _pump(tester, AccountSurfaceScreen.fromId(id));
        expect(
          find.byType(LoopFocusPage),
          findsOneWidget,
          reason: '$id must use the focus layout',
        );
        expect(
          find.byKey(const ValueKey<String>('identity-progress-track')),
          findsOneWidget,
          reason: '$id must show its step position',
        );
        expect(
          find.byKey(const ValueKey<String>('identity-step-copy')),
          findsOneWidget,
          reason: '$id must carry one primary narrative line',
        );
      }
    });

    testWidgets('an unknown account id fails closed', (tester) async {
      await _pump(tester, const AccountSurfaceScreen.fromId('seed-show'));

      expect(
        find.byKey(const ValueKey<String>('unknown-account-surface')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: child));
  await tester.pump();
}

bool _enabled(WidgetTester tester, String key) {
  final button = tester.widget<LoopButton>(find.byKey(ValueKey<String>(key)));
  return button.onPressed != null;
}
