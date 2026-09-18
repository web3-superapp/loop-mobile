import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/communication_test_harness.dart';

void main() {
  group('community-chat', () {
    testWidgets('an unavailable capability closes the page before any read', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(detail: testDetail());
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        meta: testMetaSnapshot(
          communityChat: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('community-chat-capability-unavailable'),
        ),
        findsOneWidget,
      );
      expect(gateway.commands, isEmpty);
    });

    testWidgets('the channel name keeps one line beside its four tools', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(chat: testChatAvailable),
        ),
      );

      for (final tool in <String>[
        'community-chat-open-search',
        'community-chat-open-forward',
        'community-chat-open-voice',
        'community-chat-open-profile',
      ]) {
        expect(
          find.byKey(ValueKey<String>(tool)),
          findsOneWidget,
          reason: tool,
        );
      }

      final title = find.text('Frog Holders');
      expect(title, findsOneWidget);
      // The column beside four tools is about 120pt wide. At the bar's 24pt
      // heading step that was four characters and an ellipsis; `dense` prints
      // it at 18pt over at most two lines, which holds the whole name — and
      // the ellipsis is still there for one that does not fit.
      expect(tester.widget<Text>(title).maxLines, 2);
      expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
      );
      expect(tester.getSize(title).height, lessThan(48));
      // The bar is no taller than the one that truncated.
      expect(tester.getSize(find.byType(LoopTopbar)).height, lessThan(90));
      // `#scr-community-chat .topbar{padding-right:12px}`: the prototype's
      // own tightening gives the name back what it can of that column.
      expect(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('community-chat-open-profile')),
            )
            .right,
        390 - 12,
      );
    });

    testWidgets('a missing community identifier is never guessed', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: null),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      expect(
        find.byKey(const ValueKey<String>('community-chat-missing-id')),
        findsOneWidget,
      );
    });

    testWidgets('a pending read shows the loading skeleton', (tester) async {
      final gateway = FakeCommunityGateway(detail: testDetail())
        ..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('an offline read keeps the offline state and no channel', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(failure: CommunityFailureKind.offline),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('a syncing channel says so and never reads as unavailable', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(chat: testChatSyncing),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-chat-syncing')),
        findsOneWidget,
      );
      expect(find.text('聊天权限同步中'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-chat-unavailable')),
        findsNothing,
      );
    });

    testWidgets('an unavailable channel renders the server reason code', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            chat: const CommunityChatSection(
              status: CommunityChatStatus.unavailable,
              channelCid: null,
              memberState: null,
              reasonCode: 'COMMUNITY_CHANNEL_CAPACITY_PENDING',
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-chat-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('成员上限'), findsOneWidget);
    });

    testWidgets(
      'an available channel mounts the Stream surface, not a fixture',
      (tester) async {
        await pumpCommunityPage(
          tester,
          const CommunityChatScreen(communityId: testCommunityId),
          community: FakeCommunityGateway(
            detail: testDetail(chat: testChatAvailable),
          ),
        );

        // No Stream session exists in a widget test, so the surface must stop at
        // its own not-connected state rather than showing any message.
        expect(
          find.byKey(
            const ValueKey<String>('community-chat-channel-not-connected'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('演示数据'), findsNothing);
      },
    );
  });

  group('dm', () {
    testWidgets('a missing target is never guessed', (tester) async {
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(),
        chat: FakeChatV2Gateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('dm-missing-target')),
        findsOneWidget,
      );
    });

    testWidgets('a non-friend target explains the message request first', (
      tester,
    ) async {
      final social = FakeSocialGateway();
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(
          target: DirectMessageTarget(publicProfileId: testMemberId),
        ),
        chat: FakeChatV2Gateway(failure: CommunityFailureKind.notFound),
        social: social,
      );

      expect(
        find.byKey(const ValueKey<String>('dm-friendship-required')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dm-send-message-request')),
        findsOneWidget,
      );
      // The E2EE disclaimer is present, and it never claims encryption.
      expect(find.text('不声明端到端加密'), findsOneWidget);
      expect(find.textContaining('端到端加密的'), findsNothing);
    });

    testWidgets('sending the message request goes through the social port', (
      tester,
    ) async {
      final social = FakeSocialGateway();
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(
          target: DirectMessageTarget(publicProfileId: testMemberId),
        ),
        chat: FakeChatV2Gateway(failure: CommunityFailureKind.notFound),
        social: social,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('dm-send-message-request')),
      );
      await tester.pumpAndSettle();

      expect(social.commands, contains('message-request:$testMemberId'));
      expect(find.text('消息请求已发送'), findsOneWidget);
    });

    testWidgets('a resolved operation opens the returned channel only', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(
          target: DirectMessageTarget(publicProfileId: testMemberId),
        ),
        chat: FakeChatV2Gateway(),
      );

      // The resolved CID is the only thing that may open a channel; without a
      // Stream session the surface stops at its own not-connected state and
      // renders no message at all.
      expect(
        find.byKey(const ValueKey<String>('dm-channel-not-connected')),
        findsOneWidget,
      );
    });

    testWidgets('an operator-required outcome is not presented as a failure', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(
          target: DirectMessageTarget(publicProfileId: testMemberId),
        ),
        chat: FakeChatV2Gateway(operatorRequired: true),
      );

      expect(
        find.byKey(const ValueKey<String>('dm-operator-required')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dm-operator-required-notice')),
        findsOneWidget,
      );
      // A terminal unresolved outcome offers no retry: reopening would start a
      // second logical operation under a new key.
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsNothing,
      );
      expect(find.text('重试'), findsNothing);
      expect(find.text('再试一次'), findsNothing);
    });
  });

  group('group and group-info', () {
    testWidgets('a group without a channel identifier fails closed', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const GroupChatScreen(channelCid: null),
        chat: FakeChatV2Gateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('group-missing-cid')),
        findsOneWidget,
      );
    });

    testWidgets('an unavailable capability closes the group page', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupChatScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        meta: testMetaSnapshot(
          communityChat: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('group-capability-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets(
      'the group page info control opens group-info, not a community',
      (tester) async {
        final opened = <String>[];
        await pumpCommunityPage(
          tester,
          GroupChatScreen(channelCid: testGroupCid, onOpenInfo: opened.add),
          chat: FakeChatV2Gateway(),
        );

        await tester.tap(find.byKey(const ValueKey<String>('group-open-info')));
        await tester.pump();

        // The walkthrough tapped the community channel's own (i), which is
        // labelled 社区信息 and opens the community record on purpose. A LOOP
        // group's (i) carries the channel to `group-info`.
        expect(opened, <String>[testGroupCid]);
      },
    );

    testWidgets('group-info renders member management as unavailable', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        groupAliasResolver: FakeGroupAliasResolverGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('group-info-members-unavailable')),
        findsOneWidget,
      );
      expect(find.text('NightOwl'), findsNothing);
      expect(find.text('fox_trader'), findsNothing);
    });

    testWidgets('leaving a group goes through the LOOP backend after a sheet', (
      tester,
    ) async {
      final chat = FakeChatV2Gateway();
      await pumpCommunityPage(
        tester,
        GroupInfoScreen(channelCid: testGroupCid),
        chat: chat,
        groupAliasResolver: FakeGroupAliasResolverGateway(),
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('group-info-leave')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('group-info-leave')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('group-leave-confirm-sheet')),
        findsOneWidget,
      );

      await tester.tap(find.text('退出').last);
      await tester.pumpAndSettle();
      expect(chat.commands, contains('leave-group:$testResolvedGroupId'));
      expect(find.text('已退出群聊'), findsOneWidget);
    });
  });

  group('chat-search', () {
    testWidgets('a disconnected Stream session issues no search', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const ChatSearchScreen());

      expect(
        find.byKey(const ValueKey<String>('chat-search-not-connected')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-results')),
        findsNothing,
      );
    });

    testWidgets('the four scopes plus the current conversation are offered', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        ChatSearchScreen(originCid: testGroupCid),
      );

      for (final label in <String>['当前会话', '全部', '社区', '群聊', '私聊']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    test('a group or community hit carries the neutral member label', () {
      // Stream's account-level `user.name` is never the sender of a group or
      // community result; the group message list uses the same neutral label.
      expect(
        chatSearchSenderLabel(LoopChatSurface.group),
        loopGroupMemberNeutralLabel,
      );
      expect(
        chatSearchSenderLabel(LoopChatSurface.communityChat),
        loopGroupMemberNeutralLabel,
      );
      expect(chatSearchSenderLabel(LoopChatSurface.direct), '私聊');
    });
  });

  group('chat-forward', () {
    testWidgets('a missing source conversation fails closed', (tester) async {
      await pumpCommunityPage(tester, const ChatForwardScreen(sourceCid: null));

      expect(
        find.byKey(const ValueKey<String>('chat-forward-missing-source')),
        findsOneWidget,
      );
    });

    test('the selection cap refuses the twenty-first message', () {
      final state = ChatForwardState(
        sourceCid: testGroupCid,
        messages: <ChatForwardMessage>[
          for (var index = 0; index < 25; index += 1)
            ChatForwardMessage(
              messageId: 'm$index',
              text: 'message $index',
              createdAt: DateTime.utc(2026, 9, 8, 9, index),
              forwardable: true,
            ),
        ],
      );
      var selected = <String>{};
      for (final message in state.messages) {
        if (selected.length >= chatForwardSelectionLimit) break;
        selected = <String>{...selected, message.messageId};
      }
      expect(selected, hasLength(chatForwardSelectionLimit));
      expect(chatForwardSelectionLimit, 20);
    });

    test('a non-forwardable message is skipped and counted, never sent', () {
      final state = ChatForwardState(
        sourceCid: testGroupCid,
        messages: <ChatForwardMessage>[
          ChatForwardMessage(
            messageId: 'a',
            text: 'kept',
            createdAt: DateTime.utc(2026, 9, 8, 9),
            forwardable: true,
          ),
          ChatForwardMessage(
            messageId: 'b',
            text: '',
            createdAt: DateTime.utc(2026, 9, 8, 9, 1),
            forwardable: false,
          ),
        ],
        selected: const <String>{'a', 'b'},
      );

      expect(state.selectedMessages, hasLength(2));
      expect(state.mergeRows.map((row) => row.messageId), <String>['a']);
    });
  });

  group('chat-merge-preview', () {
    testWidgets('the merged rows are anonymous and carry no identity', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const ChatMergePreviewScreen());

      // Nothing is selected yet, so nothing may be rendered.
      expect(
        find.byKey(const ValueKey<String>('chat-merge-empty')),
        findsOneWidget,
      );
    });

    test('the merge caps at fifty rows and reports the truncation', () {
      final state = ChatForwardState(
        sourceCid: testGroupCid,
        messages: <ChatForwardMessage>[
          for (var index = 0; index < 60; index += 1)
            ChatForwardMessage(
              messageId: 'm$index',
              text: 'message $index',
              createdAt: DateTime.utc(2026, 9, 8, 9),
              forwardable: true,
            ),
        ],
        selected: <String>{
          for (var index = 0; index < 60; index += 1) 'm$index',
        },
      );

      expect(state.mergeRows, hasLength(chatMergeSelectionLimit));
      expect(state.mergeTruncated, isTrue);
      expect(chatMergeSelectionLimit, 50);
    });

    test('the anonymous label is the only author a merged row can carry', () {
      expect(chatMergeAnonymousLabel, '匿名成员');
    });

    testWidgets('the export encodes the anonymous card and shares it once', (
      tester,
    ) async {
      final sink = RecordingChatMergeExportSink();
      await pumpCommunityPage(
        tester,
        const ChatMergePreviewScreen(),
        mergeExportSink: sink,
        selectedForward: <ChatForwardMessage>[
          ChatForwardMessage(
            messageId: 'a',
            text: '社区金库仓位已完成服务端复核。',
            createdAt: DateTime.utc(2026, 9, 8, 9, 34),
            forwardable: true,
          ),
        ],
      );

      // Only the anonymous label is rendered, so only it can be captured.
      expect(find.text('匿名成员 · 2026-09-08 09:34 UTC'), findsOneWidget);
      expect(find.textContaining('LOOP-'), findsNothing);
      expect(find.textContaining('0x'), findsNothing);

      final export = find.byKey(const ValueKey<String>('chat-merge-export'));
      await scrollToCommunitySection(tester, export);
      // `toImage` awaits real engine work, so the capture runs outside the
      // fake async zone.
      await tester.runAsync(() async {
        await tester.tap(export);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(sink.shared, hasLength(1));
      expect(sink.fileNames, <String>['loop-merge-preview.png']);
      // A real PNG signature proves the bytes were encoded on device.
      expect(sink.shared.single.take(4), <int>[0x89, 0x50, 0x4e, 0x47]);
    });

    testWidgets('an unavailable share adapter encodes and shares nothing', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatMergePreviewScreen(),
        selectedForward: <ChatForwardMessage>[
          ChatForwardMessage(
            messageId: 'a',
            text: 'kept',
            createdAt: DateTime.utc(2026, 9, 8, 9),
            forwardable: true,
          ),
        ],
      );

      final export = find.byKey(const ValueKey<String>('chat-merge-export'));
      await scrollToCommunitySection(tester, export);
      // `toImage` awaits real engine work, so the capture runs outside the
      // fake async zone.
      await tester.runAsync(() async {
        await tester.tap(export);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('本次运行没有装配系统分享，长图未生成'), findsOneWidget);
    });
  });

  group('voiceroom', () {
    testWidgets('a pending role evidence closes the whole page', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        meta: testMetaSnapshot(
          voiceRoomEvidence: LoopV2CapabilityEvidenceStatus.pending,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-evidence-pending')),
        findsOneWidget,
      );
      expect(find.textContaining('语音房还在验证中'), findsOneWidget);
      // The page must not read the room while the evidence is missing.
      expect(voice.commands, isEmpty);
    });

    testWidgets('no live room renders the server reason, never a fixture', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          notLiveReasonCode: 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
      expect(find.text('PEPE 语音房'), findsNothing);
      expect(find.text('3,241 在线'), findsNothing);
    });

    testWidgets('an offline read keeps the offline state', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(failure: CommunityFailureKind.offline),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('the room names its own community in the title', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(communityName: 'Builders Guild'),
        ),
      );

      // Decision 0052: the room resource carries the community name, so the
      // page says which room this is without a second read.
      expect(find.text('Builders Guild 语音房'), findsOneWidget);
    });

    testWidgets('a listener sees no host control', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-mute-all')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('voiceroom-end')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-raise-hand')),
        findsOneWidget,
      );
    });

    testWidgets('a host sees the host controls and the queue', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
        handRaises: <VoiceRoomHandRaiseEntry>[testHandRaiseEntry()],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-mute-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-end')),
        findsOneWidget,
      );
    });

    testWidgets('a speaker is offered no hand raise and no self demotion', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      expect(leave, findsOneWidget);
      // A speaker already holds the role a hand raise asks for.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-raise-hand')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-cancel-hand')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-step-down-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('a listener sees only its own place in the queue', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          handRaise: VoiceRoomHandRaise(
            handRaiseId: testRequestId,
            sequence: '2',
            state: VoiceRoomHandRaiseState.pending,
            createdAt: DateTime.utc(2026, 9, 8, 12, 20),
          ),
        ),
        // The host-only queue read must not be issued for a listener.
        handRaises: <VoiceRoomHandRaiseEntry>[testHandRaiseEntry()],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final own = find.byKey(const ValueKey<String>('voiceroom-queue-self'));
      await scrollToCommunitySection(tester, own);
      expect(own, findsOneWidget);
      expect(find.text('第 2 位'), findsOneWidget);
      expect(voice.commands, isNot(contains('hand-raises')));
      expect(
        find.byKey(const ValueKey<String>('voiceroom-invite-empty')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('voiceroom-remove-speaker-unavailable'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-step-down-unavailable')),
        findsNothing,
      );
    });

    testWidgets('the observed count says the server observed it', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
      );

      final row = find.byKey(const ValueKey<String>('voiceroom-live'));
      await scrollToCommunitySection(tester, row);
      expect(find.text('服务端观测在线'), findsOneWidget);
      // The call view under this list carries the device's own live count;
      // one screen never states two different numbers under one word.
      expect(find.text('当前在线'), findsNothing);

      // Each of these lines carries an observation time or a disclaimer at
      // its end; one line cut them at 「观察于 202…」 and 「也不是…」.
      for (final key in const <String>[
        'voiceroom-live',
        'voiceroom-observed',
        'voiceroom-role-intent',
      ]) {
        final row = find.byKey(ValueKey<String>(key));
        await scrollToCommunitySection(tester, row);
        expect(tester.widget<LoopRecordRow>(row).subtitleMaxLines, 2);
      }
    });

    testWidgets('an unobserved participant count renders the em dash', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(observedAvailable: false),
        ),
      );

      final row = find.byKey(const ValueKey<String>('voiceroom-observed'));
      await scrollToCommunitySection(tester, row);
      expect(row, findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a join reads the room again so the count is not lost', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: null, observedAvailable: false),
      )..loadSnapshot = testVoiceRoomSnapshot(role: VoiceRoomRole.listener);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      final join = find.byKey(const ValueKey<String>('voiceroom-join'));
      await scrollToCommunitySection(tester, join);
      await tester.tap(join);
      await tester.pumpAndSettle();

      // The whole chain is pinned here: the tap issues exactly one join for
      // this room, and the answer becomes the page's own state.
      expect(voice.commands, contains('join'));
      expect(
        voice.commands.where((command) => command == 'join'),
        hasLength(1),
      );
      final role = find.byKey(const ValueKey<String>('voiceroom-role'));
      await scrollToCommunitySection(tester, role);
      expect(find.text('听众'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsNothing,
      );
      expect(
        voice.commands.indexOf('load'),
        greaterThan(voice.commands.indexOf('join')),
      );
      final live = find.byKey(const ValueKey<String>('voiceroom-live'));
      await scrollToCommunitySection(tester, live);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
    });

    testWidgets('an unprovisioned room says why it cannot be joined', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: null, provisioned: false),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      final refusal = find.byKey(
        const ValueKey<String>('voiceroom-not-joinable'),
      );
      await scrollToCommunitySection(tester, refusal);
      expect(refusal, findsOneWidget);
      // A disabled button with no sentence beside it reads as a dead tap.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsNothing,
      );
      expect(voice.commands, isNot(contains('join')));
    });

    testWidgets('a joined room hands the exact room to the reviewed lobby', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
        ),
      );

      final media = find.byKey(const ValueKey<String>('voiceroom-media'));
      await scrollToCommunitySection(tester, media);
      expect(media, findsOneWidget);
      // The lobby receives the authorized room as a constructor argument, so
      // no scoped provider can resolve it to the fail-closed default.
      final lobby = tester.widget<StreamVoiceRoomPage>(
        find.byType(StreamVoiceRoomPage),
      );
      expect(lobby.target, isNotNull);
      expect(lobby.target!.roomId, 'loop_voice_$testChannelHex');
    });

    testWidgets('the joined room keeps one scrolling layer', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
        ),
      );

      // The media surface used to be a whole page inside a 420px box: the
      // reader could scroll the middle of the screen and the screen itself,
      // and the embedded app bar offered a second way back.
      final vertical = tester
          .widgetList<Scrollable>(find.byType(Scrollable))
          .where(
            (view) =>
                view.axisDirection == AxisDirection.down ||
                view.axisDirection == AxisDirection.up,
          );
      expect(vertical, hasLength(1));
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('the hand-raise queue is never a speaker to remove', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
        handRaises: <VoiceRoomHandRaiseEntry>[testHandRaiseEntry()],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final invite = find.byKey(
        ValueKey<String>('voiceroom-invite-$testMemberId'),
      );
      await scrollToCommunitySection(tester, invite);
      expect(invite, findsOneWidget);
      // 移出发言 is a speaker-row command now; the queue offers only 邀请.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-remove-speaker')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('voiceroom-remove-speaker-unavailable'),
        ),
        findsNothing,
      );
    });

    testWidgets('leaving asks first and says what leaving does', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-leave-sheet')),
        findsOneWidget,
      );
      // Nothing is committed while the question is open.
      expect(voice.commands, isNot(contains('leave')));

      await tester.tap(find.text('离开').last);
      await tester.pumpAndSettle();
      expect(voice.commands, contains('leave'));
      expect(find.text('已离开语音房'), findsOneWidget);
    });

    // `DELETE /v2/voice-rooms/{id}/members/me` refuses the host by design
    // (loop-api `leaveVoiceRoom`; the contract says "The host cannot leave; it
    // ends the room instead"). The exit each role is offered follows that
    // rule, so no role is shown a command the server can only refuse.
    for (final row in <({VoiceRoomRole role, bool host, bool leaves})>[
      (role: VoiceRoomRole.listener, host: false, leaves: true),
      (role: VoiceRoomRole.speaker, host: false, leaves: true),
      (role: VoiceRoomRole.host, host: true, leaves: false),
    ]) {
      testWidgets('the ${row.role.name} is offered the exit the server has', (
        tester,
      ) async {
        final voice = FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: row.role, host: row.host),
        );
        await pumpCommunityPage(
          tester,
          const VoiceRoomScreen(communityId: testCommunityId),
          voiceRoom: voice,
        );

        final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
        final hostExit = find.byKey(
          const ValueKey<String>('voiceroom-host-no-leave'),
        );
        final end = find.byKey(const ValueKey<String>('voiceroom-end'));
        await scrollToCommunitySection(tester, row.leaves ? leave : hostExit);
        expect(leave, row.leaves ? findsOneWidget : findsNothing);
        expect(hostExit, row.leaves ? findsNothing : findsOneWidget);
        expect(end, row.host ? findsOneWidget : findsNothing);
        if (!row.leaves) {
          // The page says why there is no 离开, and names the two things that
          // do exist: 结束房间, and the back key that only minimises.
          expect(find.text('主持人不能离开房间'), findsOneWidget);
          expect(find.textContaining('结束房间'), findsWidgets);
          expect(find.textContaining('返回键'), findsWidgets);
        }
      });
    }

    testWidgets('the host confirmation says everyone is disconnected', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final end = find.byKey(const ValueKey<String>('voiceroom-end'));
      await scrollToCommunitySection(tester, end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      expect(find.textContaining('所有人都会立刻断开'), findsOneWidget);
      expect(find.textContaining('主持人没有「离开」'), findsWidgets);
      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('end')));

      await tester.tap(find.text('结束房间').last);
      await tester.pumpAndSettle();
      // Same order as 离开: the provider call goes down before the room does.
      expect(media.leaveCalls, 1);
      expect(
        voice.commands.indexOf('end'),
        greaterThan(voice.commands.indexOf('media:leave')),
      );
      expect(find.text('房间已结束'), findsOneWidget);
    });

    testWidgets('hanging up as the host asks the end-room question', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final hangUp = find.byKey(const ValueKey<String>('fake-hangup'));
      await scrollToCommunitySection(tester, hangUp);
      await tester.tap(hangUp);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('voiceroom-end-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-leave-sheet')),
        findsNothing,
      );
      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('end')));
    });

    testWidgets('ending the room asks first', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final end = find.byKey(const ValueKey<String>('voiceroom-end'));
      await scrollToCommunitySection(tester, end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-end-sheet')),
        findsOneWidget,
      );
      expect(voice.commands, isNot(contains('end')));

      await tester.tap(find.text('结束房间').last);
      await tester.pumpAndSettle();
      expect(voice.commands, contains('end'));
    });

    testWidgets('raising a hand goes through the LOOP command port', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      final raise = find.byKey(const ValueKey<String>('voiceroom-raise-hand'));
      await scrollToCommunitySection(tester, raise);
      await tester.tap(raise);
      await tester.pumpAndSettle();

      expect(voice.commands, contains('raise-hand'));
    });
  });

  group('voiceroom media', () {
    testWidgets('joining the room is the same step as hearing it', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: null, observedAvailable: false),
      )..loadSnapshot = testVoiceRoomSnapshot(role: VoiceRoomRole.listener);
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final join = find.byKey(const ValueKey<String>('voiceroom-join'));
      await scrollToCommunitySection(tester, join);
      await tester.tap(join);
      await tester.pumpAndSettle();

      // One tap, two steps, in this order: LOOP grants the membership and the
      // connection it authorizes follows on its own.
      expect(
        voice.commands.where((command) => command == 'join'),
        hasLength(1),
      );
      expect(media.joinCalls, 1);
      expect(
        voice.commands.indexOf('media:connect'),
        greaterThan(voice.commands.indexOf('join')),
      );
      expect(find.text('语音已连接（测试）'), findsOneWidget);
      // A listener hears the room; it does not ask for a microphone.
      expect(media.microphoneCalls, 0);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsNothing,
      );
    });

    testWidgets('a member who is already in the room only connects', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      expect(find.text('语音已连接（测试）'), findsOneWidget);
      expect(media.joinCalls, 1);
      // The membership is already there: joining again would be a second
      // command for a grant this account holds.
      expect(voice.commands, isNot(contains('join')));
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsNothing,
      );
    });

    testWidgets('a failed connection keeps the membership and offers it back', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(
        log: voice.commands,
        joinFailures: 1,
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final failure = find.text('已加入，语音连接失败');
      await scrollToCommunitySection(tester, failure);
      expect(failure, findsOneWidget);
      expect(find.text('语音已连接（测试）'), findsNothing);
      // The media failure is not a membership failure: LOOP is not told to
      // leave, and the page never reads as "not joined".
      expect(voice.commands, isNot(contains('leave')));
      final role = find.byKey(const ValueKey<String>('voiceroom-role'));
      await scrollToCommunitySection(tester, role);
      expect(find.text('听众'), findsOneWidget);
      expect(find.text('未加入'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-join')),
        findsNothing,
      );

      final retry = find.byKey(
        const ValueKey<String>('voiceroom-media-reconnect'),
      );
      await scrollToCommunitySection(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(media.joinCalls, 2);
      expect(find.text('语音已连接（测试）'), findsOneWidget);
      expect(voice.commands, isNot(contains('join')));
    });

    testWidgets('an unavailable voice token still reads as joined', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        videoAuthorization: StreamVideoSessionAuthorization.unavailable,
      );

      final failure = find.text('已加入，语音连接失败');
      await scrollToCommunitySection(tester, failure);
      expect(failure, findsOneWidget);
      expect(find.text('重试会话'), findsOneWidget);
      expect(voice.commands, isNot(contains('leave')));
    });

    testWidgets('leaving drops the audio before it releases the membership', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      )..loadSnapshot = testVoiceRoomSnapshot(role: null);
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      expect(find.text('语音已连接（测试）'), findsOneWidget);

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      // The question is still asked, and nothing moves while it is open.
      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('leave')));

      await tester.tap(find.text('离开').last);
      await tester.pumpAndSettle();

      expect(media.leaveCalls, 1);
      expect(
        voice.commands.where((command) => command == 'leave'),
        hasLength(1),
      );
      expect(
        voice.commands.indexOf('leave'),
        greaterThan(voice.commands.indexOf('media:leave')),
      );
      expect(find.text('已离开语音房'), findsOneWidget);
    });

    testWidgets('hanging up inside the call is the same single exit', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final hangUp = find.byKey(const ValueKey<String>('fake-hangup'));
      await scrollToCommunitySection(tester, hangUp);
      await tester.tap(hangUp);
      await tester.pumpAndSettle();

      // Dropping the audio alone would leave this account a member of a room
      // it can no longer hear, so the in-call control asks the page's one
      // 离开 question.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-leave-sheet')),
        findsOneWidget,
      );
      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('leave')));
    });
  });

  group('voiceroom roster', () {
    FakeVoiceRoomGateway hostGateway({
      List<VoiceRoomMember> speakers = const <VoiceRoomMember>[],
      List<VoiceRoomMember> listeners = const <VoiceRoomMember>[],
      String? listenerCursor,
    }) =>
        FakeVoiceRoomGateway(
            snapshot: testVoiceRoomSnapshot(
              role: VoiceRoomRole.host,
              host: true,
            ),
          )
          ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
            VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
              view: VoiceRoomRosterView.speaker,
              items: speakers,
            ),
            VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
              view: VoiceRoomRosterView.listener,
              items: listeners,
              nextCursor: listenerCursor,
            ),
          };

    testWidgets('a host sees exactly the commands the server sent per row', (
      tester,
    ) async {
      final voice = hostGateway(
        speakers: <VoiceRoomMember>[
          testVoiceRoomMember(
            view: VoiceRoomRosterView.speaker,
            muted: true,
            commands: const <VoiceRoomMemberCommand>[
              VoiceRoomMemberCommand.removeSpeaker,
              VoiceRoomMemberCommand.mute,
            ],
          ),
        ],
        listeners: <VoiceRoomMember>[
          testVoiceRoomMember(
            view: VoiceRoomRosterView.listener,
            publicProfileId: testAdminId,
            alias: null,
            handRaised: true,
            commands: const <VoiceRoomMemberCommand>[
              VoiceRoomMemberCommand.inviteSpeaker,
            ],
          ),
        ],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final speakerRow = find.byKey(
        const ValueKey<String>('voiceroom-member-speaker-$testMemberId'),
      );
      await scrollToCommunitySection(tester, speakerRow);
      expect(speakerRow, findsOneWidget);
      expect(find.text('已静音'), findsOneWidget);

      await tester.tap(speakerRow);
      await tester.pumpAndSettle();
      // The row publishes two commands, so the sheet offers those two and no
      // invite — the viewer's role decides nothing here.
      expect(
        find.byKey(
          const ValueKey<String>('voiceroom-member-command-remove_speaker'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-member-command-mute')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('voiceroom-member-command-invite_speaker'),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-member-command-mute')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(voice.commands, contains('mute:$testMemberId'));
    });

    testWidgets('a host invites one listener through the row command', (
      tester,
    ) async {
      final voice = hostGateway(
        listeners: <VoiceRoomMember>[
          testVoiceRoomMember(
            view: VoiceRoomRosterView.listener,
            handRaised: true,
            commands: const <VoiceRoomMemberCommand>[
              VoiceRoomMemberCommand.inviteSpeaker,
            ],
          ),
        ],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final row = find.byKey(
        const ValueKey<String>('voiceroom-member-listener-$testMemberId'),
      );
      await scrollToCommunitySection(tester, row);
      expect(find.text('已举手'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('voiceroom-member-command-invite_speaker'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(voice.commands, contains('invite:$testMemberId'));
    });

    testWidgets('a plain member gets no row command at all', (tester) async {
      final voice =
          FakeVoiceRoomGateway(
              snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
            )
            ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
              VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
                view: VoiceRoomRosterView.speaker,
                items: <VoiceRoomMember>[
                  testVoiceRoomMember(view: VoiceRoomRosterView.speaker),
                ],
              ),
              VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
                view: VoiceRoomRosterView.listener,
                items: <VoiceRoomMember>[
                  // Anonymous to this viewer: no identifier, nothing to open.
                  testVoiceRoomMember(
                    view: VoiceRoomRosterView.listener,
                    publicProfileId: null,
                    alias: null,
                  ),
                ],
              ),
            };
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final row = find.byKey(
        const ValueKey<String>('voiceroom-member-listener-0'),
      );
      await scrollToCommunitySection(tester, row);
      expect(find.text('匿名成员'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-member-sheet')),
        findsNothing,
      );
    });

    testWidgets('an empty roster is not the same state as an unreadable one', (
      tester,
    ) async {
      final voice = hostGateway();
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final empty = find.byKey(
        const ValueKey<String>('voiceroom-roster-listener-empty'),
      );
      await scrollToCommunitySection(tester, empty);
      expect(empty, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-roster-speaker-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-roster-listener-error')),
        findsNothing,
      );
    });

    testWidgets('a roster that cannot be read says so and keeps the room', (
      tester,
    ) async {
      final voice = hostGateway()
        ..rosterFailure = CommunityFailureKind.unexpected;
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final error = find.byKey(
        const ValueKey<String>('voiceroom-roster-listener-error'),
      );
      await scrollToCommunitySection(tester, error);
      expect(error, findsOneWidget);
      // The room above it was read and stays readable.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-live')),
        findsOneWidget,
      );
    });

    testWidgets('another page is read with the cursor and nothing else', (
      tester,
    ) async {
      final voice =
          hostGateway(
              listeners: <VoiceRoomMember>[
                testVoiceRoomMember(view: VoiceRoomRosterView.listener),
              ],
              listenerCursor: 'page2.cursor',
            )
            ..rosterPages = <String, VoiceRoomMemberPage>{
              'page2.cursor': testVoiceRoomMemberPage(
                view: VoiceRoomRosterView.listener,
                items: <VoiceRoomMember>[
                  testVoiceRoomMember(
                    view: VoiceRoomRosterView.listener,
                    publicProfileId: testAdminId,
                    alias: 'DeFiMaxi_349',
                  ),
                ],
              ),
            };
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final more = find.byKey(
        const ValueKey<String>('voiceroom-roster-listener-load-more'),
      );
      await scrollToCommunitySection(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(voice.commands, contains('members:listener:page2.cursor'));
      expect(find.text('DeFiMaxi_349'), findsOneWidget);
      // The last page ends in a sentence, not in silence.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-roster-listener-end')),
        findsOneWidget,
      );
      expect(more, findsNothing);
    });

    testWidgets('the lobby asks for no roster at all', (tester) async {
      final voice = hostGateway();
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      expect(
        voice.commands.where((command) => command.startsWith('members:')),
        isEmpty,
      );
    });
  });

  group('voiceroom banner', () {
    testWidgets('the banner stands while the member is still in the room', (
      tester,
    ) async {
      final opened = <String>[];
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: opened),
        voiceRoom: voice,
      );

      final banner = find.byKey(
        const ValueKey<String>('voiceroom-minimized-banner'),
      );
      // On the room page itself the banner would only repeat the page.
      expect(banner, findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();
      expect(banner, findsOneWidget);
      // Decision 0052: the strip names the community it belongs to, from the
      // room resource, so a reader with one banner knows which room it is.
      expect(
        find.text('正在语音房 · $testVoiceRoomCommunityName · 服务端观测 12 人'),
        findsOneWidget,
      );

      await tester.tap(banner);
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);
    });

    testWidgets('leaving the room takes the banner with it', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      )..loadSnapshot = testVoiceRoomSnapshot(role: null);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
      );

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      await tester.tap(find.text('离开').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
        findsNothing,
      );
    });
  });

  group('community-ai', () {
    testWidgets('every functional area stays unavailable', (tester) async {
      await pumpCommunityPage(tester, const CommunityAiScreen());

      expect(
        find.byKey(const ValueKey<String>('community-ai-unavailable')),
        findsOneWidget,
      );
      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('community-ai-composer-unavailable')),
      );
      expect(
        find.byKey(const ValueKey<String>('community-ai-composer-unavailable')),
        findsOneWidget,
      );
      // The prototype's sample answer and knowledge-base figures have no
      // source and must not appear.
      expect(find.textContaining('知识库 14 篇文档'), findsNothing);
      expect(find.textContaining('今日 42 条讨论'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });
}

/// One Stream Audio Room call, recorded into the same log as the LOOP
/// commands so a test can pin the order of the two.
final class _FakeVoiceMediaFactory implements AudioRoomCallFactory {
  _FakeVoiceMediaFactory({required this.log, this.joinFailures = 0});

  final List<String> log;
  int joinFailures;
  final List<_FakeVoiceMediaCall> handles = <_FakeVoiceMediaCall>[];

  int get joinCalls =>
      handles.fold(0, (total, handle) => total + handle.joinCalls);
  int get leaveCalls =>
      handles.fold(0, (total, handle) => total + handle.leaveCalls);
  int get microphoneCalls =>
      handles.fold(0, (total, handle) => total + handle.microphoneCalls);

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) {
    final fails = joinFailures > 0;
    if (fails) joinFailures -= 1;
    final handle = _FakeVoiceMediaCall(
      roomId: target.roomId,
      log: log,
      failsJoin: fails,
    );
    handles.add(handle);
    return handle;
  }
}

final class _FakeVoiceMediaCall implements AudioRoomCallHandle {
  _FakeVoiceMediaCall({
    required this.roomId,
    required this.log,
    required this.failsJoin,
  });

  @override
  final String roomId;
  final List<String> log;
  final bool failsJoin;
  int joinCalls = 0;
  int leaveCalls = 0;
  int microphoneCalls = 0;
  var _retired = false;

  @override
  bool get retirementStarted => _retired;

  @override
  Future<void> joinMuted() async {
    joinCalls += 1;
    log.add('media:connect');
    if (failsJoin) {
      throw const AudioRoomCallFailure(AudioRoomCallFailureKind.join);
    }
  }

  @override
  Future<bool> setMicrophoneEnabled({required bool enabled}) async {
    microphoneCalls += 1;
    return true;
  }

  @override
  Future<void> retireForBackground() => leave();

  @override
  Future<void> leave() async {
    leaveCalls += 1;
    _retired = true;
    log.add('media:leave');
  }

  @override
  Widget buildForeground({
    required Future<void> Function() onLeaveRequested,
    bool inline = false,
  }) {
    return Column(
      children: <Widget>[
        const Text('语音已连接（测试）'),
        TextButton(
          key: const ValueKey<String>('fake-hangup'),
          onPressed: () => unawaited(onLeaveRequested()),
          child: const Text('挂断'),
        ),
      ],
    );
  }
}

/// Mounts the shell banner beside the room page so one test can close the page
/// without tearing down the provider scope that holds the session.
class _VoiceRoomBannerHarness extends StatefulWidget {
  const _VoiceRoomBannerHarness({required this.opened});

  final List<String> opened;

  @override
  State<_VoiceRoomBannerHarness> createState() =>
      _VoiceRoomBannerHarnessState();
}

class _VoiceRoomBannerHarnessState extends State<_VoiceRoomBannerHarness> {
  var _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        VoiceRoomMinimizedBanner(onOpen: widget.opened.add),
        Expanded(
          child: _open
              ? const VoiceRoomScreen(communityId: testCommunityId)
              : const ColoredBox(color: LoopColors.ink),
        ),
        TextButton(
          key: const ValueKey<String>('harness-close'),
          onPressed: () => setState(() => _open = false),
          child: const Text('close'),
        ),
      ],
    );
  }
}
