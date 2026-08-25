import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/home/home_screens.dart';

void main() {
  testWidgets('production notification page contains no fixture activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('notifications-provider-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Notifications not connected'), findsOneWidget);
    expect(find.text('ETH position risk increased'), findsNothing);
    expect(find.text(r'ETH crossed $4,600'), findsNothing);
    expect(find.text('Mentioned in Glyph Hunters'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('explicit Preview labels every local notification fixture set', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [loopSessionProvider.overrideWith(_PreviewSession.new)],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('notifications-preview-fixtures')),
      findsOneWidget,
    );
    expect(find.text('开发预览'), findsWidgets);
    expect(find.textContaining('演示数据'), findsWidgets);
    expect(find.text('ETH position risk increased'), findsNothing);
    expect(find.text(r'ETH crossed $4,600'), findsOneWidget);
    expect(find.text('Mentioned in Glyph Hunters'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('Home shows an unread-style badge only in explicit Preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey<String>('production-home-scope'),
        overrides: [
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
        ],
        child: MaterialApp(theme: LoopTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('notifications-preview-badge')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('notifications-production-icon')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey<String>('preview-home-scope'),
        overrides: [loopSessionProvider.overrideWith(_PreviewSession.new)],
        child: MaterialApp(theme: LoopTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('notifications-preview-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('notifications-production-icon')),
      findsNothing,
    );
  });
}

final class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() {
    return const LoopSessionState(mode: LoopSessionMode.authenticated);
  }
}

final class _PreviewSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.preview();
}
