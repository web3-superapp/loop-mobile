import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_state_card.dart';
import 'package:loop_mobile/features/community/community_manage_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart' show CallStatus;

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

/// The v1 accents the family no longer paints (docs/33 §1 rule 4).
final Set<Color> _v1Accents = <Color>{
  LoopColors.chat,
  LoopColors.danger,
  LoopColors.warning,
  LoopColors.market,
  LoopColors.elevated,
};

void _expectNoV1Accent(WidgetTester tester) {
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(
      _v1Accents.contains(text.style?.color),
      isFalse,
      reason: '${text.data} is painted ${text.style?.color}',
    );
  }
  for (final icon in tester.widgetList<LoopIcon>(find.byType(LoopIcon))) {
    expect(_v1Accents.contains(icon.color), isFalse, reason: icon.name);
  }
}

Finder _flatAround(Finder page) =>
    find.ancestor(of: page, matching: find.byType(LoopFlat));

void main() {
  group('0170 · second-level pages are flat (M17)', () {
    testWidgets('community-profile sits in LoopFlat with `.label` sections', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(miningPower: testSettledCommunityMiningPower()),
        ),
      );
      expect(
        _flatAround(
          find.byKey(const ValueKey<String>('community-profile-screen')),
        ),
        findsOneWidget,
      );
      expect(find.byType(LoopSectionTitle), findsNothing);
      final card = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, card);
      expect(find.widgetWithText(LoopLabel, '挖矿'), findsOneWidget);
      _expectNoV1Accent(tester);
    });

    testWidgets('community-manage sits in LoopFlat with `.label` sections', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        size: const Size(390, 2000),
        community: FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        ),
      );
      expect(
        _flatAround(
          find.byKey(const ValueKey<String>('community-manage-screen')),
        ),
        findsOneWidget,
      );
      expect(find.byType(LoopSectionTitle), findsNothing);
      for (final title in <String>['资料', '成员', '语音房']) {
        expect(find.widgetWithText(LoopLabel, title), findsOneWidget);
      }
      _expectNoV1Accent(tester);
    });

    testWidgets('community-members sits in LoopFlat', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        ),
      );
      expect(
        find.ancestor(
          of: find.byType(LoopPersonRow).first,
          matching: find.byType(LoopFlat),
        ),
        findsOneWidget,
      );
      _expectNoV1Accent(tester);
    });

    testWidgets('connections and stranger requests sit in LoopFlat', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(),
      );
      expect(_flatAround(find.byType(ConnectionsScreen).first), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ConnectionsScreen),
          matching: find.byType(LoopFlat),
        ),
        findsOneWidget,
      );

      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: FakeSocialGateway(),
      );
      expect(
        find.descendant(
          of: find.byType(MessageRequestsScreen),
          matching: find.byType(LoopFlat),
        ),
        findsOneWidget,
      );
    });
  });

  group('0170 · community-profile mining block (M2)', () {
    testWidgets('a record card of key-values, every figure in Chalk', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(miningPower: testSettledCommunityMiningPower()),
        ),
      );
      final summary = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, summary);
      expect(
        find.descendant(of: summary, matching: find.byType(LoopRecordCard)),
        findsOneWidget,
      );
      expect(find.byType(LoopSurfaceCard), findsNothing);
      final rows = tester
          .widgetList<LoopKeyValue>(
            find.descendant(of: summary, matching: find.byType(LoopKeyValue)),
          )
          .map((row) => row.label)
          .toList();
      expect(rows, <String>[
        '权重 · Mining Weight',
        '社区总算力',
        '我的持仓',
        '我的算力',
        '预估/日',
      ]);
      for (final key in <String>[
        'community-mining-weight',
        'community-mining-power',
        'community-mining-cell-holding',
        'community-mining-cell-power',
        'community-mining-cell-estimated',
      ]) {
        final figure = tester.widget<Text>(find.byKey(ValueKey<String>(key)));
        expect(figure.style?.color, LoopColors.chalk, reason: key);
        expect(figure.style?.color, isNot(LoopColors.lime), reason: key);
      }
    });

    testWidgets('a rejected application is the neutral badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: CommunityApplicationBadge(CommunityVerification.rejected),
          ),
        ),
      );
      final badge = tester.widget<LoopBadge>(find.byType(LoopBadge));
      expect(badge.kind, LoopBadgeKind.down);
      _expectNoV1Accent(tester);
    });
  });

  group('0170 · voice media area (M3)', () {
    loopWatchGround();

    Future<void> pumpLobby(
      WidgetTester tester,
      StreamVideoSessionAuthorization authorization,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streamVideoPrincipalKeyProvider.overrideWithValue('principal-a'),
            streamVideoAuthorizationProvider.overrideWith(
              (ref) async => authorization,
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const StreamVoiceRoomPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the lobby speaks the family: no Material glyph or button', (
      tester,
    ) async {
      await pumpLobby(tester, StreamVideoSessionAuthorization.unavailable);

      expect(find.text('语音会话暂时不可用'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(LoopStateCard), findsNothing);
      expect(find.byType(VoiceMediaStateCard), findsOneWidget);
      // The retry is a quiet `.btn`; the one Lime primary is 连接语音.
      final retry = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('voiceroom-media-retry-session')),
      );
      expect(retry.primary, isFalse);
      expect(retry.icon, 'refresh');
      final join = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('voiceroom-media-join')),
      );
      expect(join.primary, isTrue);
      expect(join.icon, 'voice');
      // The amber disc became a Card2 disc with a Lime glyph.
      final mark = tester.widget<Container>(
        find.byKey(const ValueKey<String>('voiceroom-lobby-mark')),
      );
      expect((mark.decoration! as BoxDecoration).color, LoopColors.card2);
      // No literal radial glow behind the page.
      for (final box in tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.gradient, isNot(isA<RadialGradient>()));
        }
      }
      _expectNoV1Accent(tester);
    });

    test('a status is a badge of the family pairs', () {
      expect(
        StreamCallStatusPresentation.badgeKind(CallStatus.connected()),
        LoopBadgeKind.up,
      );
      expect(
        StreamCallStatusPresentation.badgeKind(CallStatus.joined()),
        LoopBadgeKind.mining,
      );
      expect(
        StreamCallStatusPresentation.badgeKind(CallStatus.reconnecting(1)),
        LoopBadgeKind.mining,
      );
      expect(
        StreamCallStatusPresentation.badgeKind(CallStatus.reconnectingFailed()),
        LoopBadgeKind.down,
      );
    });

    test('the state card draws its glyph in Lime, Chalk or Text2 only', () {
      expect(
        VoiceMediaStateCard.glyphColor(LoopTone.positive),
        LoopColors.lime,
      );
      expect(VoiceMediaStateCard.glyphColor(LoopTone.warning), LoopColors.lime);
      expect(VoiceMediaStateCard.glyphColor(LoopTone.danger), LoopColors.chalk);
      expect(
        VoiceMediaStateCard.glyphColor(LoopTone.neutral),
        LoopColors.text2,
      );
    });

    testWidgets('the leaving key is the Chalk `.btn-danger`', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Center(
              child: LoopButton(
                key: const ValueKey<String>('leave'),
                primary: true,
                tone: LoopButtonTone.danger,
                icon: 'phone',
                label: '',
                semanticLabel: '断开语音连接',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final fill = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey<String>('leave')),
              matching: find.byType(Container),
            )
            .first,
      );
      // Decision 0211: a danger button is outlined in red with a red word.
      expect((fill.decoration! as BoxDecoration).color, isNull);
      expect(
        ((fill.foregroundDecoration! as BoxDecoration).border! as Border)
            .top
            .color,
        LoopColors.danger,
      );
      expect(
        tester.widget<LoopIcon>(find.byType(LoopIcon)).color,
        LoopColors.danger,
      );
      expect(find.bySemanticsLabel('断开语音连接'), findsOneWidget);
    });
  });
}
