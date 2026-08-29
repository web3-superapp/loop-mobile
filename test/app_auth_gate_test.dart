import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

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

    expect(find.text('Welcome to LOOP'), findsOneWidget);
    expect(find.text('Login configuration incomplete'), findsOneWidget);
    expect(find.text('Home overview'), findsNothing);
    expect(find.text('Enter development preview'), findsNothing);
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

    final previewButton = find.text('Enter development preview');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('Home overview'), findsOneWidget);
    expect(find.text('开发预览'), findsWidgets);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sign out of LOOP'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to LOOP'), findsOneWidget);
    expect(find.text('Home overview'), findsNothing);
  });
}
