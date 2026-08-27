import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/chat_secondary_pages.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';

void main() {
  test('Preview requests transition once without changing conversations or messages', () async {
    final gateway = MemoryCommunicationGateway();
    final conversationsBefore = (await gateway.loadConversations()).value!;
    final groupBefore = (await gateway.loadMessages(ChatContent.groupId))
        .value!;
    final directBefore = (await gateway.loadMessages(ChatContent.directId))
        .value!;

    final accepted = await gateway.acceptMessageRequest('r1');
    expect(accepted.isSuccess, isTrue);
    expect(
      (await gateway.loadMessageRequests()).value!.map((item) => item.id),
      <String>['r2'],
    );

    for (final repeated in <CommunicationResult<void>>[
      await gateway.acceptMessageRequest('r1'),
      await gateway.reportMessageRequest(requestId: 'r1', reason: 'Spam'),
      await gateway.ignoreMessageRequest('unknown-request'),
    ]) {
      expect(repeated.isSuccess, isFalse);
      expect(
        repeated.failure?.code,
        CommunicationFailure.previewRequestNotPending.code,
      );
    }

    final invalidReason = await gateway.reportMessageRequest(
      requestId: 'r2',
      reason: 'Unreviewed reason',
    );
    expect(invalidReason.isSuccess, isFalse);
    expect(
      invalidReason.failure?.code,
      CommunicationFailure.previewRequestReasonInvalid.code,
    );
    expect(
      (await gateway.loadMessageRequests()).value!.map((item) => item.id),
      <String>['r2'],
    );

    final removedLocally = await gateway.reportMessageRequest(
      requestId: 'r2',
      reason: 'Spam',
    );
    expect(removedLocally.isSuccess, isTrue);
    expect((await gateway.loadMessageRequests()).value, isEmpty);
    expect((await gateway.loadConversations()).value, conversationsBefore);
    expect(
      (await gateway.loadMessages(ChatContent.groupId)).value,
      groupBefore,
    );
    expect(
      (await gateway.loadMessages(ChatContent.directId)).value,
      directBefore,
    );
  });

  testWidgets(
    'Accept removes one Preview request without creating a Stream conversation',
    (tester) async {
      final harness = await _pumpRequestHarness(
        tester,
        gateway: MemoryCommunicationGateway(),
      );

      expect(find.text('2 preview requests'), findsOneWidget);
      await tester.tap(find.text('2 preview requests'));
      await tester.pumpAndSettle();

      await _tapRequestAction(tester, 'chat-preview-request-accept-r1');
      expect(
        find.text(
          'Marked accepted in 开发预览 and removed locally. No Stream conversation was created.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-preview-request-r1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-preview-request-r2')),
        findsOneWidget,
      );
      expect(find.text('0xSable'), findsNothing);

      harness.router.go('/chat');
      await tester.pumpAndSettle();
      expect(find.text('1 preview request'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('chat-preview-message-request-badge'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Report removes a simulated request but never claims submission',
    (tester) async {
      await _pumpRequestHarness(
        tester,
        gateway: MemoryCommunicationGateway(),
        initialLocation: '/chat/requests',
      );

      await _tapRequestAction(tester, 'chat-preview-request-report-r1');
      expect(
        find.text(
          'Development Preview only. Choosing a reason removes this simulated request locally; no report is submitted.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();

      expect(
        find.text('Removed from 开发预览. No report was submitted.'),
        findsOneWidget,
      );
      expect(find.text('Report submitted and request removed.'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('chat-preview-request-r1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Ignore reaches a truthful empty state and clears the Inbox badge',
    (tester) async {
      final harness = await _pumpRequestHarness(
        tester,
        gateway: MemoryCommunicationGateway(),
        initialLocation: '/chat/requests',
      );

      await _tapRequestAction(tester, 'chat-preview-request-ignore-r1');
      expect(
        find.text('Removed from 开发预览 only. No sender interaction occurred.'),
        findsOneWidget,
      );
      await _tapRequestAction(tester, 'chat-preview-request-ignore-r2');

      expect(
        find.byKey(
          const ValueKey<String>('chat-preview-message-requests-empty'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'No simulated requests remain in this Development Preview. Restarting the preview restores the fixtures.',
        ),
        findsOneWidget,
      );

      harness.router.go('/chat');
      await tester.pumpAndSettle();
      expect(find.text('No preview requests'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('chat-preview-message-request-badge'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a request card disables every action while resolution is pending',
    (tester) async {
      final gateway = _BlockingRequestGateway();
      await _pumpRequestHarness(
        tester,
        gateway: gateway,
        initialLocation: '/chat/requests',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('chat-preview-request-accept-r1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-preview-request-accept-r1')),
      );
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey<String>('chat-preview-request-accept-r1'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey<String>('chat-preview-request-ignore-r1'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(
                const ValueKey<String>('chat-preview-request-report-r1'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-preview-request-progress')),
        findsOneWidget,
      );

      gateway.acceptCompleter.complete(
        const CommunicationResult<void>.failure(
          CommunicationFailure.previewRequestNotPending,
        ),
      );
      await tester.pumpAndSettle();
    },
  );
}

Future<_RequestHarness> _pumpRequestHarness(
  WidgetTester tester, {
  required CommunicationGateway gateway,
  String initialLocation = '/chat',
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatInboxPage(),
      ),
      GoRoute(
        path: '/chat/requests',
        builder: (context, state) => const MessageRequestsPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [communicationGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: LoopTheme.dark,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _RequestHarness(router);
}

Future<void> _tapRequestAction(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _RequestHarness {
  const _RequestHarness(this.router);

  final GoRouter router;
}

class _BlockingRequestGateway extends MemoryCommunicationGateway {
  final acceptCompleter = Completer<CommunicationResult<void>>();

  @override
  Future<CommunicationResult<void>> acceptMessageRequest(String requestId) {
    return acceptCompleter.future;
  }
}
