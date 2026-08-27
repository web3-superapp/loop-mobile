import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  test('Preview identity resolves only exact registered message targets', () {
    expect(
      PreviewConversationIdentity.group.location,
      '/chat/group?conversationId=glyph-hunters',
    );
    expect(
      PreviewConversationIdentity.direct.location,
      '/chat/dm?conversationId=sable-direct',
    );
    expect(
      PreviewConversationIdentity.resolve(
        conversationId: ChatContent.groupId,
        kind: ConversationKind.group,
      ),
      same(PreviewConversationIdentity.group),
    );
    expect(
      PreviewConversationIdentity.resolve(
        conversationId: ChatContent.groupId,
        kind: ConversationKind.direct,
      ),
      isNull,
    );
    expect(PreviewConversationIdentity.resolveMessage('another-group'), isNull);
    expect(
      PreviewConversationIdentity.locationForSummary(
        conversationId: 'another-group',
        kind: ConversationKind.group,
      ),
      isNull,
    );
  });

  test(
    'Preview route query rejects missing duplicate control and overlong IDs',
    () {
      expect(
        PreviewConversationIdentity.readSingleConversationId(
          Uri.parse('/chat/group'),
        ),
        isNull,
      );
      expect(
        PreviewConversationIdentity.readSingleConversationId(
          Uri.parse(
            '/chat/group?conversationId=glyph-hunters&conversationId=sable-direct',
          ),
        ),
        isNull,
      );
      expect(
        PreviewConversationIdentity.readSingleConversationId(
          Uri(
            path: '/chat/group',
            queryParameters: const {'conversationId': ''},
          ),
        ),
        isNull,
      );
      expect(
        PreviewConversationIdentity.resolveMessage('glyph\u0000-hunters'),
        isNull,
      );
      expect(
        PreviewConversationIdentity.resolveMessage(
          List<String>.filled(129, 'g').join(),
        ),
        isNull,
      );
    },
  );

  test('Preview gateway rejects unknown read send and scoped search without mutation', () async {
    final gateway = MemoryCommunicationGateway();
    final groupBefore = List<ConversationMessage>.of(
      (await gateway.loadMessages(ChatContent.groupId)).value!,
    );
    final directBefore = List<ConversationMessage>.of(
      (await gateway.loadMessages(ChatContent.directId)).value!,
    );

    final read = await gateway.loadMessages('another-group');
    final send = await gateway.sendText(
      conversationId: 'another-group',
      text: 'Must not enter Glyph Hunters',
    );
    final search = await gateway.searchMessages(
      query: 'unlock',
      conversationId: 'another-group',
    );

    expect(read.isSuccess, isFalse);
    expect(send.isSuccess, isFalse);
    expect(search.isSuccess, isFalse);
    expect(read.failure?.code, CommunicationFailure.conversationNotFound.code);
    expect(send.failure?.code, CommunicationFailure.conversationNotFound.code);
    expect(
      search.failure?.code,
      CommunicationFailure.conversationNotFound.code,
    );
    expect(
      (await gateway.loadMessages(ChatContent.groupId)).value,
      orderedEquals(groupBefore),
    );
    expect(
      (await gateway.loadMessages(ChatContent.directId)).value,
      orderedEquals(directBefore),
    );
  });

  testWidgets(
    'Preview deep links require an exact ID and never mount a fallback composer',
    (tester) async {
      final router = await _pumpPreviewApp(
        tester,
        gateway: MemoryCommunicationGateway(),
      );

      for (final location in <String>[
        '/chat/group',
        '/chat/group?conversationId=another-group',
        '/chat/group?conversationId=sable-direct',
        '/chat/group?conversationId=glyph-hunters&conversationId=sable-direct',
        '/chat/dm?conversationId=glyph-hunters',
        '/chat/group-info',
        '/chat/group-info?conversationId=another-group',
        '/chat/group-info?conversationId=sable-direct',
        '/chat/group-info?conversationId=glyph-hunters&conversationId=sable-direct',
        '/chat/search?conversationId=another-group',
        '/chat/search?conversationId=glyph-hunters&conversationId=sable-direct',
      ]) {
        router.go(location);
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('preview-conversation-unavailable'),
          ),
          findsOneWidget,
          reason: location,
        );
        expect(find.byTooltip('Send message'), findsNothing, reason: location);
        expect(find.text('NightOwl'), findsNothing, reason: location);
      }
    },
  );

  testWidgets('Conversation search keeps the exact Preview scope', (
    tester,
  ) async {
    final gateway = _RecordingSearchGateway();
    final router = await _pumpPreviewApp(tester, gateway: gateway);

    router.go(PreviewConversationIdentity.group.location);
    await tester.pumpAndSettle();
    expect(find.text('Glyph Hunters'), findsOneWidget);
    expect(find.byTooltip('Send message'), findsOneWidget);

    await tester.tap(find.byTooltip('Search this conversation'));
    await tester.pumpAndSettle();

    expect(find.text('Search Glyph Hunters'), findsOneWidget);
    expect(
      find.text('Results stay inside this exact Preview conversation.'),
      findsOneWidget,
    );
    expect(find.text('0xSable'), findsNothing);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'unlock');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(gateway.lastSearchConversationId, ChatContent.groupId);
    expect(gateway.lastSearchConversationId, isNot(ChatContent.directId));
  });

  testWidgets('Group information preserves the exact Preview search scope', (
    tester,
  ) async {
    final gateway = _RecordingSearchGateway();
    final router = await _pumpPreviewApp(tester, gateway: gateway);

    router.go(
      PreviewConversationIdentity.groupInfoLocation(ChatContent.groupId)!,
    );
    await tester.pumpAndSettle();
    expect(find.text('Glyph Hunters'), findsWidgets);

    await tester.tap(find.byTooltip('Search group messages'));
    await tester.pumpAndSettle();
    expect(find.text('Search Glyph Hunters'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(gateway.lastSearchConversationId, ChatContent.groupId);
  });

  testWidgets('Unknown or kind-mismatched search results are not navigable', (
    tester,
  ) async {
    final router = await _pumpPreviewApp(
      tester,
      gateway: _InvalidSearchResultGateway(),
    );
    router.go('/chat/search');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'fixture');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Preview conversation unavailable'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-preview-search-result-unknown')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search messages'), findsWidgets);
    expect(find.byTooltip('Send message'), findsNothing);
  });

  testWidgets('Inbox refuses an unregistered same-kind Preview conversation', (
    tester,
  ) async {
    await _pumpPreviewApp(tester, gateway: _UnknownInboxGateway());
    await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Decoy group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decoy group'));
    await tester.pumpAndSettle();

    expect(
      find.text('Preview conversation unavailable. No fallback was opened.'),
      findsOneWidget,
    );
    expect(find.text('NightOwl'), findsNothing);
    expect(find.byTooltip('Send message'), findsNothing);
  });

  testWidgets('Global Search names and opens the exact registered group', (
    tester,
  ) async {
    final router = await _pumpPreviewApp(
      tester,
      gateway: MemoryCommunicationGateway(),
    );
    router.go('/search');
    await tester.pumpAndSettle();

    expect(find.text(PreviewConversationIdentity.group.title), findsOneWidget);
    expect(find.text('ETH Holders Lounge'), findsNothing);
    await tester.tap(find.text(PreviewConversationIdentity.group.title));
    await tester.pumpAndSettle();

    expect(
      find.text('Offline preview · simulated conversation'),
      findsOneWidget,
    );
    expect(find.byTooltip('Send message'), findsOneWidget);
  });

  testWidgets('Preview notification opens the exact registered group', (
    tester,
  ) async {
    final router = await _pumpPreviewApp(
      tester,
      gateway: MemoryCommunicationGateway(),
    );
    router.go('/notifications');
    await tester.pumpAndSettle();

    final mention = find.text('Mentioned in Glyph Hunters');
    await tester.ensureVisible(mention);
    await tester.pumpAndSettle();
    await tester.tap(mention);
    await tester.pumpAndSettle();

    expect(
      find.text('Offline preview · simulated conversation'),
      findsOneWidget,
    );
    expect(find.byTooltip('Send message'), findsOneWidget);
  });
}

Future<GoRouter> _pumpPreviewApp(
  WidgetTester tester, {
  required CommunicationGateway gateway,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const UnconfiguredPrivyAuthGateway(),
        ),
        developmentPreviewEnabledProvider.overrideWithValue(true),
        communicationGatewayProvider.overrideWithValue(gateway),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enter development preview'));
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(NavigationBar)));
}

final class _RecordingSearchGateway extends MemoryCommunicationGateway {
  String? lastSearchConversationId;

  @override
  Future<CommunicationResult<List<MessageSearchResult>>> searchMessages({
    required String query,
    String? conversationId,
  }) {
    lastSearchConversationId = conversationId;
    return super.searchMessages(query: query, conversationId: conversationId);
  }
}

final class _InvalidSearchResultGateway extends MemoryCommunicationGateway {
  @override
  Future<CommunicationResult<List<MessageSearchResult>>> searchMessages({
    required String query,
    String? conversationId,
  }) async {
    return const CommunicationResult<List<MessageSearchResult>>.success(
      <MessageSearchResult>[
        MessageSearchResult(
          id: 'unknown',
          conversationId: 'another-group',
          conversationTitle: 'Decoy group',
          senderAlias: 'Fixture',
          snippet: 'Unknown exact ID',
          timeLabel: 'Preview',
          kind: ConversationKind.group,
        ),
        MessageSearchResult(
          id: 'mismatch',
          conversationId: ChatContent.groupId,
          conversationTitle: 'Wrong kind',
          senderAlias: 'Fixture',
          snippet: 'Known ID with mismatched kind',
          timeLabel: 'Preview',
          kind: ConversationKind.direct,
        ),
      ],
    );
  }
}

final class _UnknownInboxGateway extends MemoryCommunicationGateway {
  @override
  Future<CommunicationResult<List<ConversationSummary>>>
  loadConversations() async {
    return const CommunicationResult<List<ConversationSummary>>.success(
      <ConversationSummary>[
        ConversationSummary(
          id: 'another-group',
          title: 'Decoy group',
          preview: 'Must not open Glyph Hunters',
          timeLabel: 'Preview',
          kind: ConversationKind.group,
        ),
      ],
    );
  }
}
