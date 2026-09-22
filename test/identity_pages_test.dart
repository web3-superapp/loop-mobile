import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  group('splash', () {
    testWidgets('is the wordmark, the brand loader and one entry action', (
      tester,
    ) async {
      var entered = false;
      await _pump(
        tester,
        AccountSurfaceScreen.fromId(
          'splash',
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
      // `#scr-splash` carries no build version; the prototype's frame is the
      // mark, the line and the CTA (audit 2026-09-20 §C.1).
      expect(find.textContaining('Version'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('loop-splash-enter')));
      await tester.pump();
      expect(entered, isTrue);
    });

    testWidgets('the rail keeps sweeping for as long as the account is being '
        'prepared', (tester) async {
      await _pump(
        tester,
        const AccountSurfaceScreen.fromId(
          'splash',
          splashPhase: LoopSplashPhase.preparingAccount,
        ),
      );

      expect(find.text('正在准备你的账号…'), findsOneWidget);
      expect(_loader(tester).isSweeping, isTrue);

      // The complaint this answers: a mark that finishes once looks like a
      // frozen App while a slow read is still running. Long past the single
      // pass the prototype animates, the band is still moving and still in a
      // different place than it was a frame earlier.
      await tester.pump(const Duration(seconds: 12));
      expect(_loader(tester).isSweeping, isTrue);
      final before = tester.getTopLeft(_band);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(_band), isNot(before));
    });

    testWidgets('the rail stops and states the reason once the wait ends', (
      tester,
    ) async {
      await _pump(
        tester,
        const AccountSurfaceScreen.fromId(
          'splash',
          splashPhase: LoopSplashPhase.accountUnavailable,
          splashUnavailableReason: '资料服务当前不可用，没有任何修改被保存。',
        ),
      );

      expect(_loader(tester).isSweeping, isFalse);
      expect(_band, findsNothing);
      expect(find.text('正在准备你的账号…'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-splash-unavailable')),
        findsOneWidget,
      );
      expect(find.text('资料服务当前不可用，没有任何修改被保存。'), findsOneWidget);
      // Nothing on this page leads anywhere while the account is unknown.
      expect(
        find.byKey(const ValueKey<String>('loop-splash-enter')),
        findsNothing,
      );
    });

    testWidgets(
      'a device that asked for less motion still waits, and says so',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AccountSurfaceScreen.fromId(
              'splash',
              splashPhase: LoopSplashPhase.preparingAccount,
            ),
          ),
        );
        await tester.pump();

        expect(_loader(tester).isSweeping, isFalse);
        // The movement is gone; the sentence and the spoken label are not.
        expect(find.text('正在准备你的账号…'), findsOneWidget);
        expect(
          tester
              .widget<Semantics>(
                find
                    .descendant(
                      of: find.byKey(
                        const ValueKey<String>('loop-splash-loader'),
                      ),
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .label,
          'LOOP 正在加载',
        );
      },
    );
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
      await _tap(tester, 'external-wallet-connect');
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

      await _tap(tester, 'wallet-create-continue');
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
      // Passkey and 恢复密码; the two disclosure rows stay collapsed and
      // 自动恢复 is not an option at all — it is already in force.
      expect(find.text('不可用'), findsNWidgets(2));
      expect(find.text('可用'), findsNothing);
      expect(find.text('已选'), findsNothing);
      expect(find.text('已启用'), findsOneWidget);
      // Nothing to enrol is not a reason to trap the owner on the step: both
      // actions continue, and neither claims an enrolment (F2).
      expect(_enabled(tester, 'wallet-recovery-confirm'), isTrue);
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

    testWidgets(
      'only an available method can be selected, and it is optional',
      (tester) async {
        final destinations = <String>[];
        final decisions = <WalletRecoveryMethod?>[];
        await _pump(
          tester,
          AccountSurfaceScreen.fromId(
            'wallet-recovery',
            capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
            onNavigate: destinations.add,
            onRecoveryDecision: decisions.add,
          ),
        );

        expect(find.text('可用'), findsOneWidget);
        expect(find.text('已选'), findsNothing);

        // The enabled row reports; it is not a choice to make.
        await _tap(tester, 'recovery-cloud');
        expect(find.text('已选'), findsNothing);

        await _tap(tester, 'recovery-passkey');
        expect(find.text('已选'), findsOneWidget);

        await _tap(tester, 'wallet-recovery-confirm');
        expect(decisions, <WalletRecoveryMethod?>[
          WalletRecoveryMethod.passkey,
        ]);
        expect(destinations, <String>['security-setup']);
      },
    );

    testWidgets('a loading or failed capability read blocks every option', (
      tester,
    ) async {
      await _pump(
        tester,
        const WalletRecoveryScreen(
          capabilities: PrivyWalletCapabilities(canUsePasskey: true),
          onContinue: _noop,
          loading: true,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-recovery-loading')),
        findsOneWidget,
      );
      expect(find.text('可用'), findsNothing);

      await _pump(
        tester,
        const WalletRecoveryScreen(
          capabilities: PrivyWalletCapabilities(canUsePasskey: true),
          onContinue: _noop,
          failureReason: '能力清单暂时读不到。',
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-recovery-error')),
        findsOneWidget,
      );
      expect(_enabled(tester, 'wallet-recovery-confirm'), isFalse);
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
      // Nothing is on: this tree composed no device lock, and a Privy
      // capability is never an enabled protection.
      expect(find.textContaining('已开启'), findsNothing);
      expect(find.text('可用'), findsNothing);
      expect(find.text('不可用'), findsNWidgets(3));

      await _tap(tester, 'security-setup-continue');
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

final Finder _band = find.byKey(
  const ValueKey<String>('loop-brand-loader-band'),
);

LoopBrandLoaderState _loader(WidgetTester tester) =>
    tester.state<LoopBrandLoaderState>(find.byType(LoopBrandLoader));

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: child));
  await tester.pump();
}

void _noop() {}

/// A step page lays its action out in the body's flow, so a control may sit
/// below the fold on a 390x844 screen before it is reached.
Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) {
  final button = tester.widget<LoopButton>(find.byKey(ValueKey<String>(key)));
  return button.onPressed != null;
}
