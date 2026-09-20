import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_models.dart';

/// Decision 0055 · the reader's own name inside one community's group.
///
/// It is the single identity fact LOOP may state about the member in that
/// room; every other member's name is read from that member's own channel
/// projection and from no LOOP record.
void main() {
  group('community persona', () {
    testWidgets('the room says what this account is called in it', (
      tester,
    ) async {
      // Decision 0055. The strip is what a member reads above the composer:
      // their own community persona, the one identity fact LOOP may state
      // about them in that room.
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: LoopChatHeaderStrip(
              segments: <String>[
                ?communityChatPersonaSegment(
                  const CommunityChatPersona(
                    alias: 'Harbor-4821',
                    projectionState: CommunityChatPersonaProjection.confirmed,
                  ),
                ),
              ],
              collapsed: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('你在这个社区显示为 Harbor-4821'), findsOneWidget);
    });
  });
}
