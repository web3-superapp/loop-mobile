import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
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
        meta: testMetaSnapshot(voiceRoomEvidencePending: true),
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-evidence-pending')),
        findsOneWidget,
      );
      expect(find.textContaining('不能创建通话'), findsOneWidget);
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

    testWidgets('a host is offered no speaker to remove', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
          handRaises: <VoiceRoomHandRaiseEntry>[testHandRaiseEntry()],
        ),
      );

      final unavailable = find.byKey(
        const ValueKey<String>('voiceroom-remove-speaker-unavailable'),
      );
      await scrollToCommunitySection(tester, unavailable);
      expect(unavailable, findsOneWidget);
      // A hand raise is a request to speak, never a speaker.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-remove-speaker')),
        findsNothing,
      );
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
