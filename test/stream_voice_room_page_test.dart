import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/voice_room_page.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';

void main() {
  testWidgets('signed-out production page never displays preview room data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [streamVideoPrincipalKeyProvider.overrideWithValue(null)],
        child: const MaterialApp(home: VoiceRoomPage()),
      ),
    );

    expect(find.text('Verified login required'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsNothing);
    expect(find.textContaining('participant'), findsNothing);
    expect(find.text('Ringing'), findsNothing);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('unavailable backend session fails closed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamVideoPrincipalKeyProvider.overrideWithValue('principal-a'),
          streamVideoAuthorizationProvider.overrideWith(
            (ref) async => StreamVideoSessionAuthorization.unavailable,
          ),
        ],
        child: const MaterialApp(home: StreamVoiceRoomPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stream session unavailable'), findsOneWidget);
    expect(find.text('Join audio room'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join audio room'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('authorized frontend remains media-disabled and truthful', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          streamVideoPrincipalKeyProvider.overrideWithValue('principal-a'),
          streamVideoAuthorizationProvider.overrideWith(
            (ref) async => StreamVideoSessionAuthorization.authorized,
          ),
        ],
        child: const MaterialApp(home: StreamVoiceRoomPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Foreground SDK ready'), findsOneWidget);
    expect(find.text('Media permissions pending'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsNothing);
    expect(find.textContaining('connected'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join audio room'),
    );
    expect(button.onPressed, isNull);
  });
}
