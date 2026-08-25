import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_attachment_builder.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_message_preview_formatter.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  test('missing API key does not construct the official SDK session', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config(streamApiKey: '')),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(streamChatSdkSessionProvider), isNull);
  });

  test('SDK construction is lazy and performs no bootstrap request', () {
    final source = _RecordingSessionSource();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        loopSessionProvider.overrideWith(
          _SignedOutTestLoopSessionController.new,
        ),
        streamChatSessionSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    final session = container.read(streamChatSdkSessionProvider);

    expect(session, isNotNull);
    expect(session!.client.state.currentUser, isNull);
    expect(source.identityCalls, 0);
    expect(source.tokenCalls, 0);
  });

  test('missing backend bootstrap keeps authorization fail-closed', () async {
    final source = _RecordingSessionSource();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        streamChatSessionSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    container.read(loopSessionProvider);
    for (var attempt = 0; attempt < 5; attempt += 1) {
      if (container.read(loopSessionProvider).mode ==
          LoopSessionMode.authenticated) {
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.authenticated,
    );

    final result = await container.read(streamChatAuthorizationProvider.future);

    expect(result, StreamSessionAuthorization.unavailable);
    expect(source.identityCalls, 1);
    expect(source.tokenCalls, 0);
    expect(
      container.read(streamChatSdkSessionProvider)!.client.state.currentUser,
      isNull,
    );
  });

  testWidgets('production app mounts the official StreamChat scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StreamChat), findsOneWidget);
    final streamChat = tester.widget<StreamChat>(find.byType(StreamChat));
    expect(streamChat.key, ObjectKey(streamChat.client));
    expect(
      streamChat.configData?.attachmentBuilders,
      contains(isA<LoopStreamTokenCardAttachmentBuilder>()),
    );
    expect(
      streamChat.configData?.messagePreviewFormatter,
      isA<LoopStreamTokenCardMessagePreviewFormatter>(),
    );
    final composerBuilder = streamChat.componentBuilders
        ?.extension<MessageComposerProps>();
    expect(composerBuilder, isNotNull);
    final composer = composerBuilder!(
      tester.element(find.byType(StreamChat)),
      const MessageComposerProps(
        disableAttachments: false,
        enableVoiceRecording: true,
      ),
    );
    expect(composer, isA<DefaultStreamMessageComposer>());
    final props = (composer as DefaultStreamMessageComposer).props;
    expect(props.disableAttachments, isTrue);
    expect(props.enableVoiceRecording, isFalse);
  });

  testWidgets('an empty Stream key never mounts an SDK scope', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config(streamApiKey: '')),
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StreamChat), findsNothing);
  });

  test(
    'principal changes rotate the SDK session but wallet changes do not',
    () async {
      final source = _RecordingSessionSource();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          loopSessionProvider.overrideWith(_TestLoopSessionController.new),
          streamChatSessionSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        loopSessionProvider.notifier,
      ) as _TestLoopSessionController;
      final sessionA = container.read(streamChatSdkSessionProvider)!;

      controller.replace(
        const LoopSessionState(
          mode: LoopSessionMode.authenticated,
          account: PrivyAccountSummary(
            privyUserId: 'did:privy:user-a',
            wallet: PrivyWalletSummary(address: '0x1234'),
          ),
        ),
      );
      final sessionAfterWallet = container.read(streamChatSdkSessionProvider)!;
      expect(sessionAfterWallet, same(sessionA));
      expect(sessionAfterWallet.client, same(sessionA.client));

      controller.replace(
        const LoopSessionState(
          mode: LoopSessionMode.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:user-b'),
        ),
      );
      final sessionB = container.read(streamChatSdkSessionProvider)!;
      expect(sessionB, isNot(same(sessionA)));
      expect(sessionB.client, isNot(same(sessionA.client)));
      expect(
        sessionB.client.chatPersistenceClient,
        isNot(same(sessionA.client.chatPersistenceClient)),
      );
      expect(
        await sessionA.authorizer.authorize(),
        StreamSessionAuthorization.unavailable,
      );

      controller.replace(const LoopSessionState.signedOut());
      final signedOutSession = container.read(streamChatSdkSessionProvider)!;
      expect(signedOutSession, isNot(same(sessionB)));
      expect(signedOutSession.client, isNot(same(sessionB.client)));
      expect(
        signedOutSession.client.chatPersistenceClient,
        isNot(same(sessionB.client.chatPersistenceClient)),
      );
      expect(
        await sessionB.authorizer.authorize(),
        StreamSessionAuthorization.unavailable,
      );
      expect(source.identityCalls, 0);
      expect(source.tokenCalls, 0);
    },
  );
}

AppConfig _config({String streamApiKey = 'public-stream-api-key'}) {
  return AppConfig(
    privyAppId: 'privy-app',
    privyAppClientId: 'privy-client',
    streamApiKey: streamApiKey,
    backendBaseUrl: '',
    firebaseConfigured: false,
  );
}

class _RecordingSessionSource implements StreamChatSessionSource {
  int identityCalls = 0;
  int tokenCalls = 0;

  @override
  Future<StreamChatIdentity?> loadIdentity() async {
    identityCalls += 1;
    return null;
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenCalls += 1;
    return 'unreachable-token';
  }
}

class _TestLoopSessionController extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );

  void replace(LoopSessionState next) => state = next;
}

class _SignedOutTestLoopSessionController extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.signedOut();
}
