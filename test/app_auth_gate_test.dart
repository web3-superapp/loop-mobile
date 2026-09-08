import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  test('production session controller rejects direct preview entry', () {
    final container = ProviderContainer(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const UnconfiguredPrivyAuthGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final entered = container.read(loopSessionProvider.notifier).enterPreview();

    expect(entered, isFalse);
    expect(container.read(loopSessionProvider).isPreview, isFalse);
  });

  testWidgets('signed-out users see real auth boundary before product routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const UnconfiguredPrivyAuthGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到 LOOP'), findsOneWidget);
    expect(find.text('登录配置不完整'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('enter-development-preview-button')),
      findsNothing,
    );
    expect(find.text('进入开发预览'), findsNothing);
  });

  testWidgets('signing out shows a non-interactive authentication boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    final backendGate = Completer<LoopBackendLogoutResult>();
    final exit = container
        .read(loopSessionProvider.notifier)
        .exit(revokeBackend: (_) => backendGate.future);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey<String>('privy-signing-out-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('privy-email-field')), findsNothing);
    expect(
      find.byKey(const ValueKey('privy-google-login-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsNothing,
    );

    // Advancing beyond the removed outer 20-second timeout must not detach
    // the still-running backend revocation or reopen the login controls.
    await tester.pump(const Duration(seconds: 21));
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.signingOut,
    );
    expect(
      find.byKey(const ValueKey<String>('privy-signing-out-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('privy-email-field')), findsNothing);

    backendGate.complete(LoopBackendLogoutResult.confirmed);
    await exit;
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到 LOOP'), findsOneWidget);
  });

  testWidgets('explicit offline composition can enter and leave preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const UnconfiguredPrivyAuthGateway(),
          ),
          developmentPreviewEnabledProvider.overrideWithValue(true),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final previewButton = find.byKey(
      const ValueKey<String>('enter-development-preview-button'),
    );
    expect(find.text('进入开发预览'), findsOneWidget);
    await tester.ensureVisible(previewButton);
    await tester.pump();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsOneWidget,
    );
    expect(find.text('社区内容源待连接'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('community-profile-action')),
    );
    await tester.pumpAndSettle();
    final signOut = find.byKey(const ValueKey<String>('profile-sign-out'));
    await tester.scrollUntilVisible(signOut, 240);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.text('欢迎来到 LOOP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsNothing,
    );
  });
}
