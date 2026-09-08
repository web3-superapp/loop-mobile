import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/home/home_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

const _verifiedWalletSession = LoopSessionState(
  mode: LoopSessionMode.authenticated,
  account: PrivyAccountSummary(
    privyUserId: 'did:privy:home-truth',
    wallet: PrivyWalletSummary(
      address: '0x1111111111111111111111111111111111111111',
    ),
  ),
);

void main() {
  testWidgets('production B1 contains no portfolio or activity fixtures', (
    tester,
  ) async {
    await _pumpSurface(
      tester,
      const HomeScreen(),
      session: _verifiedWalletSession,
    );

    expect(
      find.byKey(const ValueKey<String>('home-production-truth-boundary')),
      findsOneWidget,
    );
    expect(find.text('Portfolio data not connected'), findsOneWidget);
    expect(find.text('Wallet identity available'), findsOneWidget);
    expect(find.text('Activity not connected'), findsOneWidget);
    expect(find.text('Audio Room'), findsOneWidget);

    for (final fixture in <String>[
      '开发预览',
      '演示数据',
      r'$46,806.55',
      '+2.6% today',
      '3 watchlist moves',
      '18 unread',
      'Wallet ready',
      'Glyph Hunters',
      'ETH Macro Room',
      'ETH moved above your alert',
      'One approval can spend your USDC',
    ]) {
      expect(find.textContaining(fixture), findsNothing, reason: fixture);
    }
  });

  testWidgets(
    'restricted B1 never upgrades cached identity into wallet facts',
    (tester) async {
      await _pumpSurface(
        tester,
        const HomeScreen(),
        session: const LoopSessionState(
          mode: LoopSessionMode.authenticatedUnverified,
        ),
      );

      expect(
        find.text('Portfolio unavailable in restricted session'),
        findsOneWidget,
      );
      expect(find.text('Wallet identity available'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    },
  );

  testWidgets('verified B1 without a wallet stays unavailable', (tester) async {
    await _pumpSurface(
      tester,
      const HomeScreen(),
      session: const LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:no-wallet'),
      ),
    );

    expect(find.text('No wallet identity'), findsOneWidget);
    expect(find.text('Wallet identity available'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('invalid B1 wallet identity never implies portfolio facts', (
    tester,
  ) async {
    await _pumpSurface(
      tester,
      const HomeScreen(),
      session: const LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: PrivyAccountSummary(
          privyUserId: 'did:privy:invalid-wallet',
          wallet: PrivyWalletSummary(address: '0x1234'),
        ),
      ),
    );

    expect(find.text('Wallet identity invalid'), findsOneWidget);
    expect(find.text('Wallet identity available'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('explicit Preview B1 keeps every fixture visibly labelled', (
    tester,
  ) async {
    await _pumpSurface(
      tester,
      const HomeScreen(),
      session: const LoopSessionState.preview(),
    );

    expect(
      find.byKey(const ValueKey<String>('home-preview-fixtures')),
      findsOneWidget,
    );
    expect(find.textContaining('开发预览'), findsWidgets);
    expect(find.textContaining('演示数据'), findsWidgets);
    expect(find.text(r'$46,806.55'), findsOneWidget);
    expect(find.text('3 watchlist moves'), findsOneWidget);
    expect(find.text('18 unread'), findsOneWidget);
    expect(find.text('Wallet ready'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-production-truth-boundary')),
      findsNothing,
    );
  });

  testWidgets('B1 remains scrollable at 200 percent text', (tester) async {
    for (final session in <LoopSessionState>[
      _verifiedWalletSession,
      const LoopSessionState.preview(),
    ]) {
      for (final size in <Size>[const Size(390, 844), const Size(844, 390)]) {
        await _pumpSurface(
          tester,
          const HomeScreen(),
          session: session,
          size: size,
          textScaler: const TextScaler.linear(2),
        );
        if (session.isPreview) {
          expect(find.text('DISCOVER'), findsOneWidget);
          expect(find.text('DISCUSS'), findsOneWidget);
          expect(find.text('EXECUTE'), findsOneWidget);
        }

        final contentEnd = session.isPreview
            ? find.text('One approval can spend your USDC')
            : find.byKey(
                const ValueKey<String>('home-production-activity-unavailable'),
              );
        final verticalScrollable = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .first;
        await tester.scrollUntilVisible(
          contentEnd,
          500,
          scrollable: verticalScrollable,
        );
        await tester.pumpAndSettle();
        expect(contentEnd, findsOneWidget);

        final exception = tester.takeException();
        final diagnostics = exception is FlutterError
            ? exception.diagnostics
                  .map((node) => node.toStringDeep())
                  .join('\n')
            : '$exception';
        expect(exception, isNull, reason: 'B1 · $size\n$diagnostics');
      }
    }
  });
}

Future<void> _pumpSurface(
  WidgetTester tester,
  Widget surface, {
  required LoopSessionState session,
  Size size = const Size(800, 1600),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        loopSessionProvider.overrideWith(() => _FixedSession(session)),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: surface,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FixedSession extends LoopSessionController {
  _FixedSession(this.fixedState);

  final LoopSessionState fixedState;

  @override
  LoopSessionState build() => fixedState;
}
