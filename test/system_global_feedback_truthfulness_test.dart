import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

const _legacyFeedbackClaims = <String>[
  'Short, specific feedback',
  'Notices state exactly what happened and preserve a clear next action.',
  'Notification preferences saved.',
  'Market prices may be delayed.',
  'The order status could not be confirmed.',
  'This action requires the production app host.',
];

const _feedbackCases =
    <
      ({
        LoopNoticeKind kind,
        String message,
        String semanticLabel,
        IconData icon,
      })
    >[
      (
        kind: LoopNoticeKind.success,
        message: 'Exact success observation.',
        semanticLabel: 'Success. Exact success observation.',
        icon: Icons.check_circle_outline_rounded,
      ),
      (
        kind: LoopNoticeKind.warning,
        message: 'Exact warning observation.',
        semanticLabel: 'Warning. Exact warning observation.',
        icon: Icons.warning_amber_rounded,
      ),
      (
        kind: LoopNoticeKind.error,
        message: 'Exact error observation.',
        semanticLabel: 'Error. Exact error observation.',
        icon: Icons.error_outline_rounded,
      ),
    ];

void main() {
  testWidgets('production I7 route stays unknown without feature feedback', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/preview/toast');
    await tester.pumpAndSettle();

    expect(find.text('Feedback context unavailable'), findsOneWidget);
    expect(find.byType(LoopGlobalNotice), findsNothing);
    expect(find.byTooltip('Dismiss'), findsNothing);
    for (final claim in _legacyFeedbackClaims) {
      expect(find.text(claim), findsNothing);
    }

    await tester.tap(find.text('Return to LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('naked I7 never invents feedback or consumes exact actions', (
    tester,
  ) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        onRetry: () => fail('generic retry must not authorize I7'),
        onPrimaryAction: () => fail('generic primary must not authorize I7'),
        onFeedbackAction: () => fail('action requires exact feedback'),
        onFeedbackDismiss: () => fail('dismiss requires exact feedback'),
        onSecondaryAction: () => returns += 1,
      ),
    );

    expect(find.text('Feedback context unavailable'), findsOneWidget);
    expect(find.text('Review'), findsNothing);
    expect(find.byTooltip('Dismiss'), findsNothing);
    for (final item in _feedbackCases) {
      expect(find.text(item.message), findsNothing);
    }

    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
  });

  testWidgets('I7 fails closed for empty or whitespace-only messages', (
    tester,
  ) async {
    for (final message in <String>['', '   ', '\n\t']) {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'toast',
          globalFeedback: LoopGlobalFeedback(
            kind: LoopNoticeKind.success,
            message: message,
            actionLabel: 'Review',
          ),
          onFeedbackAction: () => fail('invalid feedback cannot act'),
          onFeedbackDismiss: () => fail('invalid feedback cannot dismiss'),
        ),
      );

      expect(find.text('Feedback context unavailable'), findsOneWidget);
      expect(find.byType(LoopGlobalNotice), findsNothing);
      expect(find.text('Review'), findsNothing);
      expect(find.byTooltip('Dismiss'), findsNothing);
    }
  });

  testWidgets('I7 hides empty or whitespace-only action labels at runtime', (
    tester,
  ) async {
    for (final actionLabel in <String>['', '   ', '\n\t']) {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'toast',
          globalFeedback: LoopGlobalFeedback(
            kind: LoopNoticeKind.warning,
            message: 'Exact warning observation.',
            actionLabel: actionLabel,
          ),
          onFeedbackAction: () => fail('invalid label cannot act'),
        ),
      );

      expect(find.text('Exact warning observation.'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    }
  });

  testWidgets('I7 renders only the explicit success warning or error', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final item in _feedbackCases) {
        await _pump(
          tester,
          SystemSurfaceScreen.fromId(
            'toast',
            globalFeedback: LoopGlobalFeedback(
              kind: item.kind,
              message: item.message,
            ),
          ),
        );

        expect(find.text('Feature feedback'), findsOneWidget);
        expect(find.text(item.message), findsOneWidget);
        expect(find.byIcon(item.icon), findsOneWidget);
        expect(find.text('Feedback context unavailable'), findsNothing);
        for (final other in _feedbackCases) {
          if (other.kind == item.kind) continue;
          expect(find.text(other.message), findsNothing);
          expect(find.byIcon(other.icon), findsNothing);
        }
        for (final claim in _legacyFeedbackClaims) {
          expect(find.text(claim), findsNothing);
        }

        final noticeSemantics = tester.getSemantics(
          find.byType(LoopGlobalNotice),
        );
        expect(noticeSemantics.label, item.semanticLabel);
        expect(noticeSemantics.flagsCollection.isLiveRegion, isTrue);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('I7 action requires both exact label and dedicated callback', (
    tester,
  ) async {
    var actions = 0;
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: LoopGlobalFeedback(
          kind: LoopNoticeKind.warning,
          message: 'Exact warning observation.',
          actionLabel: 'Review',
        ),
      ),
    );
    expect(find.text('Review'), findsNothing);

    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.warning,
          message: 'Exact warning observation.',
        ),
        onFeedbackAction: () => actions += 1,
      ),
    );
    expect(find.text('Review'), findsNothing);

    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.warning,
          message: 'Exact warning observation.',
          actionLabel: 'Review',
        ),
        onFeedbackAction: () => actions += 1,
      ),
    );
    await tester.tap(find.text('Review'));
    expect(actions, 1);
  });

  testWidgets('I7 dismiss is independent and uses its dedicated callback', (
    tester,
  ) async {
    var dismissals = 0;
    await _pump(
      tester,
      const SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: LoopGlobalFeedback(
          kind: LoopNoticeKind.success,
          message: 'Exact success observation.',
        ),
      ),
    );
    expect(find.byTooltip('Dismiss'), findsNothing);

    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.success,
          message: 'Exact success observation.',
        ),
        onFeedbackDismiss: () => dismissals += 1,
      ),
    );
    await tester.tap(find.byTooltip('Dismiss'));
    expect(dismissals, 1);
  });

  testWidgets('explicit I7 feedback ignores generic system actions', (
    tester,
  ) async {
    var actions = 0;
    var dismissals = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.error,
          message: 'Exact error observation.',
          actionLabel: 'Review',
        ),
        onRetry: () => fail('generic retry must stay isolated from I7'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
        onFeedbackAction: () => actions += 1,
        onFeedbackDismiss: () => dismissals += 1,
      ),
    );

    expect(find.text('Return to LOOP'), findsNothing);
    await tester.tap(find.text('Review'));
    await tester.tap(find.byTooltip('Dismiss'));
    expect(actions, 1);
    expect(dismissals, 1);
  });

  testWidgets('I7 exposes a live region and accessible exact actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'toast',
          globalFeedback: const LoopGlobalFeedback(
            kind: LoopNoticeKind.warning,
            message: 'Exact warning observation.',
            actionLabel: 'Review',
          ),
          onFeedbackAction: () {},
          onFeedbackDismiss: () {},
        ),
      );

      _expectHeader(tester, 'Feature feedback');
      final noticeSemantics = tester.getSemantics(
        find.byType(LoopGlobalNotice),
      );
      expect(noticeSemantics.label, 'Warning. Exact warning observation.');
      expect(noticeSemantics.flagsCollection.isLiveRegion, isTrue);
      _expectTapButton(tester, find.text('Review'), 'Review');
      _expectTapButton(
        tester,
        find.widgetWithIcon(IconButton, Icons.close_rounded),
        'Dismiss',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unknown I7 remains usable at large text', (tester) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        onSecondaryAction: () => returns += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Return to LOOP'));
    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long I7 feedback and exact actions fit at large text', (
    tester,
  ) async {
    var actions = 0;
    var dismissals = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.warning,
          message: 'The owning feature supplied this bounded warning after observing its exact current state.',
          actionLabel: 'Review source',
        ),
        onFeedbackAction: () => actions += 1,
        onFeedbackDismiss: () => dismissals += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Review source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review source'));
    await tester.ensureVisible(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    expect(actions, 1);
    expect(dismissals, 1);
    expect(tester.takeException(), isNull);
  });
}

void _expectHeader(WidgetTester tester, String label) {
  final semantics = tester.getSemantics(find.text(label));
  expect(semantics.flagsCollection.isHeader, isTrue);
}

void _expectTapButton(WidgetTester tester, Finder finder, String label) {
  final semantics = tester.getSemantics(finder);
  expect(semantics.label, label);
  expect(semantics.flagsCollection.isButton, isTrue);
  expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}
