import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_identity_scope.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_ai_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

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

    test('a persona still on its way says that, and no name', () {
      expect(
        communityChatPersonaSegment(
          const CommunityChatPersona(
            alias: 'Harbor-4821',
            projectionState: CommunityChatPersonaProjection.pending,
          ),
        ),
        '正在同步你的显示名',
      );
      // Nothing issued, or not a member: the page states neither in place of
      // the other.
      expect(communityChatPersonaSegment(null), isNull);
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

    testWidgets('the conversation is named by the profile the caller passed', (
      tester,
    ) async {
      // R14-3: the only place in the product that opens a conversation used to
      // pass the id alone, so `identity` was always null — the header read the
      // literal 「私聊」 and the `@` row under it had no name to offer and
      // failed closed on every real device visit.
      await pumpCommunityPage(
        tester,
        DirectMessageScreen(
          target: DirectMessageTarget(
            publicProfileId: testMemberId,
            identity: testProfile(
              publicProfileId: testMemberId,
              loopId: 'LOOP-3HJKMNPQ',
              alias: 'Voyager_09',
            ),
          ),
        ),
        chat: FakeChatV2Gateway(),
      );

      expect(find.text('Voyager_09'), findsOneWidget);
      expect(find.text('LOOP-3HJKMNPQ'), findsOneWidget);
      expect(find.text('私聊'), findsNothing);
      expect(find.textContaining('loop_'), findsNothing);
      // The same word travels to the Stream widgets under the page, so the
      // `@` candidate row names the peer the header just named.
      expect(
        tester
            .widget<LoopDirectPeerScope>(find.byType(LoopDirectPeerScope))
            .displayName,
        'Voyager_09',
      );
    });

    testWidgets('without an alias the header falls back to the LOOP ID', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        DirectMessageScreen(
          target: DirectMessageTarget(
            publicProfileId: testMemberId,
            identity: testProfile(
              publicProfileId: testMemberId,
              loopId: 'LOOP-3HJKMNPQ',
              alias: null,
            ),
          ),
        ),
        chat: FakeChatV2Gateway(),
      );

      expect(find.text('LOOP-3HJKMNPQ'), findsOneWidget);
      expect(
        tester
            .widget<LoopDirectPeerScope>(find.byType(LoopDirectPeerScope))
            .displayName,
        'LOOP-3HJKMNPQ',
      );
    });

    testWidgets('a deep link carries no identity, so none is published', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(channelCid: 'messaging:loop_direct_8e7d73c5'),
        chat: FakeChatV2Gateway(),
      );

      expect(find.text('私聊'), findsOneWidget);
      expect(find.byType(LoopDirectPeerScope), findsNothing);
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
      // The author and the clock are two lines of the export row now, the way
      // `#scr-chat-merge-preview` sets them.
      expect(find.text('匿名成员'), findsOneWidget);
      expect(find.text('2026-09-08 09:34 UTC'), findsOneWidget);
      expect(find.textContaining('LOOP-'), findsNothing);
      expect(find.textContaining('0x'), findsNothing);
      // `01`: the row carries its ordinal, and `1/1` says the whole
      // selection made it into the image.
      expect(find.text('01'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);

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
      expect(find.text('LOOP 上次观察在线'), findsOneWidget);
      // The call view under this list carries the device's own live count;
      // one screen never states two different numbers under one word.
      expect(find.text('当前在线'), findsNothing);
      // A 0 here beside 「LOOP 已加入 46」 is not a contradiction, and the row
      // says which one it is counting.
      expect(find.textContaining('不含还没连上语音的人'), findsOneWidget);

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

    testWidgets('a backstage room is never handed to the provider', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          backstage: true,
        ),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final block = find.byKey(
        const ValueKey<String>('voiceroom-media-backstage'),
      );
      await scrollToCommunitySection(tester, block);
      expect(block, findsOneWidget);
      expect(find.text('这个房间还没有开放收听'), findsOneWidget);
      // No call was made at all: the surface that would connect is not even
      // mounted.
      expect(media.handles, isEmpty);
      expect(voice.commands, isNot(contains('media:connect')));

      // The refresh is a read of the room, which is also the server's cue to
      // open it again.
      voice.loadSnapshot = testVoiceRoomSnapshot(role: VoiceRoomRole.listener);
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-media-backstage-retry')),
      );
      await tester.pumpAndSettle();
      expect(voice.commands, contains('load'));
      expect(block, findsNothing);
    });

    testWidgets('a room that is not open yet says so, not 「不可用」', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: null),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      // The page was read; the command is what the server refuses, naming
      // the rule in `detailsSafe`.
      final join = find.byKey(const ValueKey<String>('voiceroom-join'));
      await scrollToCommunitySection(tester, join);
      voice
        ..failure = CommunityFailureKind.unavailable
        ..failureReasonCode = 'VOICE_ROOM_BACKSTAGE_NOT_LIVE';
      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(find.text('这个房间还没有开放收听。刷新一次，或让主持人重新开启。'), findsWidgets);
      // Neither the generic class sentence nor the server's own name for the
      // rule reaches the reader.
      expect(find.text('语音房暂时不可用，稍后再试。'), findsNothing);
      expect(find.textContaining('BACKSTAGE'), findsNothing);
    });

    testWidgets('an unconfirmed go-live is named in words, not in a code', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(
            role: VoiceRoomRole.listener,
            providerConfirmed: false,
            providerReason: 'STREAM_CALL_GO_LIVE_UNCONFIRMED',
          ),
        ),
      );

      final notice = find.byKey(
        const ValueKey<String>('voiceroom-provider-unconfirmed'),
      );
      await scrollToCommunitySection(tester, notice);
      expect(
        find.text('这个房间还没有确认开放收听，现在可能听不到。刷新一次，或让主持人重新开启。'),
        findsOneWidget,
      );
      expect(find.textContaining('GO_LIVE'), findsNothing);
    });

    testWidgets('a connected device states the live count, and only it', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          participantCount: 0,
        ),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: _FakeVoiceMediaFactory(log: voice.commands),
      );

      final report = find.byKey(const ValueKey<String>('fake-presence'));
      await scrollToCommunitySection(tester, report);
      await tester.tap(report);
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey<String>('voiceroom-live'));
      await scrollToCommunitySection(tester, row);
      expect(find.text('当前在线'), findsOneWidget);
      expect(tester.widget<LoopRecordRow>(row).trailing, '3');
      // The earlier observation is not printed beside it: 「上次观察在线 0」
      // above 「此刻在通话里 3 人」 was one screen saying two things.
      expect(find.text('LOOP 上次观察在线'), findsNothing);
    });

    testWidgets(
      'R5-3: a connection whose count has not arrived never shows 0',
      (tester) async {
        final voice = FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(
            role: VoiceRoomRole.listener,
            participantCount: 0,
          ),
        );
        await pumpCommunityPage(
          tester,
          const VoiceRoomScreen(communityId: testCommunityId),
          voiceRoom: voice,
          audioRoomCallFactory: _FakeVoiceMediaFactory(log: voice.commands),
        );

        final report = find.byKey(
          const ValueKey<String>('fake-presence-counting'),
        );
        await scrollToCommunitySection(tester, report);
        await tester.tap(report);
        await tester.pumpAndSettle();

        final row = find.byKey(const ValueKey<String>('voiceroom-live'));
        await scrollToCommunitySection(tester, row);
        // 「已连接」 beside 「0」 was read as an empty room. The row states the
        // connection and says the number is still being taken.
        expect(find.text('当前在线'), findsOneWidget);
        expect(tester.widget<LoopRecordRow>(row).trailing, '正在统计');
        expect(tester.widget<LoopRecordRow>(row).trailing, isNot('0'));
      },
    );

    // R7-2: while the SDK put the connection back, the room facts fell back
    // to 「LOOP 上次观察在线 0」 — a 0 on the same screen as a panel that had
    // just said the count comes back with the connection.
    testWidgets('a reconnecting call states the retry, not an older 0', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          participantCount: 0,
        ),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: _FakeVoiceMediaFactory(log: voice.commands),
      );

      final report = find.byKey(
        const ValueKey<String>('fake-presence-reconnecting'),
      );
      await scrollToCommunitySection(tester, report);
      await tester.tap(report);
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey<String>('voiceroom-live'));
      await scrollToCommunitySection(tester, row);
      expect(find.text('语音连接'), findsOneWidget);
      expect(tester.widget<LoopRecordRow>(row).trailing, '重连中');
      // The one sentence the call panel prints for the same phase.
      expect(tester.widget<LoopRecordRow>(row).subtitle, '语音正在重连，人数以重新连接后为准');
      expect(find.text('LOOP 上次观察在线'), findsNothing);
      expect(find.text('0'), findsNothing);
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

    testWidgets('the listener list has a door, or no sentence about it', (
      tester,
    ) async {
      // 「听众列表在展开视图查看」 was a sentence with no way out of it, and
      // the reader on the review device asked where that view was.
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        VoiceRoomScreen(
          communityId: testCommunityId,
          onOpenExpanded: opened.add,
        ),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
      );

      final door = find.byKey(
        const ValueKey<String>('voiceroom-listeners-open'),
      );
      await scrollToCommunitySection(tester, door);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);

      // A page with nowhere to send the reader says nothing about a list
      // they cannot reach.
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
      );
      expect(find.textContaining('展开视图'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-listeners-open')),
        findsNothing,
      );
    });

    testWidgets('the host who is speaking is in 正在发言', (tester) async {
      // The review device: the host was talking and the grid was empty,
      // because it was drawn from LOOP's speaker roster — which records the
      // parts LOOP granted and carries no host at all.
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

      // No call of this device's own yet: the record is what there is, and it
      // says what it is a record of.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-speakers-empty')),
        findsOneWidget,
      );

      final speaking = find.byKey(
        const ValueKey<String>('fake-presence-speaking'),
      );
      await scrollToCommunitySection(tester, speaking);
      await tester.tap(speaking);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('voiceroom-speakers-live')),
        findsOneWidget,
      );
      expect(find.text('NightOwl'), findsWidgets);
      expect(find.text('正在发言'), findsWidgets);
    });

    testWidgets('a call nobody is speaking in says so, and not 没有发言人', (
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

      final counting = find.byKey(
        const ValueKey<String>('fake-presence-counting'),
      );
      await scrollToCommunitySection(tester, counting);
      await tester.tap(counting);
      await tester.pumpAndSettle();

      // Connected with nobody publishing: that is a quiet room, not a room
      // with no speakers in LOOP's record.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-speakers-silent')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-speakers-empty')),
        findsNothing,
      );
    });

    testWidgets('a hand raised in the room reaches the host who is watching', (
      tester,
    ) async {
      // The review devices: a listener raised a hand, the server recorded it,
      // and the host's page — which had read the queue when it opened — went
      // on showing an empty one until the room ended.
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-queue-empty')),
        findsOneWidget,
      );

      // Somebody raises a hand. The provider tells this device the queue
      // moved; the queue itself still comes from LOOP.
      voice.handRaises = <VoiceRoomHandRaiseEntry>[
        testHandRaiseEntry(alias: 'DeFiMaxi_349'),
      ];
      media.handles.single.emitSignal(AudioRoomRoomSignal.handRaise);
      await tester.pumpAndSettle();

      final queue = find.byKey(
        ValueKey<String>('voiceroom-queue-$testRequestId'),
      );
      await scrollToCommunitySection(tester, queue);
      expect(queue, findsOneWidget);
      expect(find.text('DeFiMaxi_349'), findsWidgets);
    });

    testWidgets('a hand the room was not told about says so', (tester) async {
      // The hand is recorded either way; whether the host was told is the
      // provider's own answer, and it is the one that decides what the
      // reader does next.
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          providerConfirmed: false,
          providerReason: 'STREAM_CALL_EVENT_UNCONFIRMED',
        ),
      )..loadSnapshot = testVoiceRoomSnapshot(role: VoiceRoomRole.listener);
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
      expect(find.textContaining('主持人可能要稍后才看到'), findsOneWidget);
      expect(find.text('已举手，等待主持人邀请'), findsNothing);
    });

    testWidgets('a listener who arrives changes the count the host reads', (
      tester,
    ) async {
      // 「主持人这边仍显示 1 人在房间里」: the room record was read when the
      // page opened, and joining is somebody else's action.
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.host,
          host: true,
          joinedCount: 1,
        ),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      expect(find.text('1 人在房间里'), findsOneWidget);

      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.host,
        host: true,
        joinedCount: 2,
      );
      media.handles.single.emitSignal(AudioRoomRoomSignal.participants);
      await tester.pumpAndSettle();

      expect(find.text('2 人在房间里'), findsOneWidget);
    });

    testWidgets('a room with no call of its own is still read', (tester) async {
      // No provider cue reaches a device that holds no call — a member who
      // joined in LOOP whose audio never came up, or a connection that
      // dropped. The floor under the cues is what answers for them.
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.host,
          host: true,
          joinedCount: 1,
        ),
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      expect(find.text('1 人在房间里'), findsOneWidget);

      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.host,
        host: true,
        joinedCount: 2,
      );
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(find.text('2 人在房间里'), findsOneWidget);
    });

    testWidgets('the queue names its rows the way the roster does', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
        handRaises: <VoiceRoomHandRaiseEntry>[
          testHandRaiseEntry(alias: 'DeFiMaxi_349'),
          // An anonymous member a host can still address: the name is the
          // server's label, the target is not published as a name.
          testHandRaiseEntry(
            handRaiseId: testAdminId,
            sequence: '2',
            publicProfileId: testAdminId,
            alias: null,
          ),
          // A queue row the server sent no command for is read, not invited.
          testHandRaiseEntry(
            handRaiseId: testCommunityId,
            sequence: '3',
            publicProfileId: null,
            alias: null,
            commands: const <VoiceRoomMemberCommand>[],
          ),
        ],
      );
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
      );

      final queue = find.byKey(
        ValueKey<String>('voiceroom-queue-$testRequestId'),
      );
      await scrollToCommunitySection(tester, queue);
      // Three rows in the queue, two of them anonymous, and the two the
      // server sent `invite_speaker` for are listed again under the host
      // controls. No loop id and no avatar reference arrive here at all.
      expect(find.text('DeFiMaxi_349'), findsNWidgets(2));
      expect(find.text('匿名成员'), findsNWidgets(3));
      expect(find.text('第 3 位'), findsOneWidget);

      final invite = find.byKey(
        ValueKey<String>('voiceroom-invite-$testAdminId'),
      );
      await scrollToCommunitySection(tester, invite);
      expect(invite, findsOneWidget);
      // The row without `invite_speaker` is not offered as an invitation.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-invite-null')),
        findsNothing,
      );
      // The lazy sliver builds this row before it is on screen, and a queue
      // this long puts it under the fold; the tap has to reach it.
      await tester.ensureVisible(invite);
      await tester.pumpAndSettle();
      await tester.tap(invite);
      await tester.pumpAndSettle();
      expect(voice.commands, contains('invite:$testAdminId'));
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

    // R7-1: on the review device the five seconds after 离开 showed the
    // disconnection lobby — 「语音已断开」 above a highlighted 「重新连接语音」 —
    // which answers the opposite of what the reader had just decided.
    testWidgets('the wait after 离开 is a departure, not a disconnection', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      )..membershipGate = Completer<void>();
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
      await tester.tap(find.text('离开').last);
      // The sheet closes and the call goes down; LOOP has not answered yet,
      // so the departing card holds a spinner and cannot settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(media.leaveCalls, 1);
      expect(voice.commands, isNot(contains('leave')));
      final departing = find.text('正在离开语音房…');
      await scrollToCommunitySection(tester, departing);
      expect(departing, findsOneWidget);
      expect(find.text('语音已断开'), findsNothing);
      expect(find.text('重新连接语音'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
        findsNothing,
      );

      voice.membershipGate!.complete();
      await tester.pumpAndSettle();
      expect(voice.commands, contains('leave'));
      expect(find.text('已离开语音房'), findsOneWidget);
      expect(find.text('正在离开语音房…'), findsNothing);
    });

    // A leave LOOP refused leaves this account a member of a room it can no
    // longer hear: the departure has to stop being the answer on screen.
    testWidgets('a refused leave puts the way back in on the screen', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      )..membershipGate = Completer<void>();
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final leave = find.byKey(const ValueKey<String>('voiceroom-leave'));
      await scrollToCommunitySection(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      await tester.tap(find.text('离开').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      voice.failure = CommunityFailureKind.unavailable;
      voice.membershipGate!.complete();
      await tester.pumpAndSettle();

      final disconnected = find.text('语音已断开');
      await scrollToCommunitySection(tester, disconnected);
      expect(disconnected, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
        findsOneWidget,
      );
      expect(find.text('正在离开语音房…'), findsNothing);
    });

    // The host ends the room and every other device simply stops hearing it.
    // Told as a dropped connection, the reader is handed 「重新连接语音」 for a
    // room nobody can enter again.
    testWidgets('a room the host ended is not a dropped connection', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      final back = <String>[];
      await pumpCommunityPage(
        tester,
        VoiceRoomScreen(
          communityId: testCommunityId,
          onBack: () => back.add('back'),
        ),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      expect(find.text('语音已连接（测试）'), findsOneWidget);

      // The room record is what tells the two apart, and it now says the host
      // ended it.
      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.listener,
        state: VoiceRoomState.ended,
      );
      final stop = find.byKey(
        const ValueKey<String>('fake-media-disconnected'),
      );
      await scrollToCommunitySection(tester, stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();

      expect(voice.commands, contains('load'));
      final ended = find.byKey(const ValueKey<String>('voiceroom-ended'));
      await scrollToCommunitySection(tester, ended);
      expect(find.text('房间已结束'), findsOneWidget);
      expect(find.text('主持人已经结束这个语音房。'), findsOneWidget);
      expect(find.text('语音已断开'), findsNothing);
      expect(find.text('重新连接语音'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
        findsNothing,
      );
      // The media surface belongs to a room that can be entered; this one
      // cannot.
      expect(find.text('语音已连接（测试）'), findsNothing);
      expect(media.leaveCalls, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-ended-back')),
      );
      await tester.pumpAndSettle();
      expect(back, <String>['back']);
    });

    // R9-4: the community page underneath holds the read it took before the
    // room was over. A reader who is told the room ended and then sent back
    // to 「当前有进行中的语音房」 with a way in has been told two things.
    testWidgets(
      'R9-4: going back from a room that ended re-reads the community',
      (tester) async {
        final community = FakeCommunityGateway(detail: testDetail());
        final voice = FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(
            role: VoiceRoomRole.listener,
            state: VoiceRoomState.ended,
          ),
        );
        final back = <String>[];
        await pumpCommunityPage(
          tester,
          VoiceRoomScreen(
            communityId: testCommunityId,
            onBack: () => back.add('back'),
          ),
          community: community,
          voiceRoom: voice,
        );

        // The community page below this one was read while the room was live.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VoiceRoomScreen)),
          listen: false,
        );
        final subscription = container.listen(
          communityProfileControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container
            .read(communityProfileControllerProvider.notifier)
            .open(testCommunityId);
        await tester.pumpAndSettle();
        final readsBeforeBack = community.reads;

        final ended = find.byKey(
          const ValueKey<String>('voiceroom-ended-back'),
        );
        await scrollToCommunitySection(tester, ended);
        await tester.tap(ended);
        await tester.pumpAndSettle();

        expect(back, <String>['back']);
        expect(community.reads, readsBeforeBack + 1);
      },
    );

    testWidgets('a call that stopped on a live room offers the audio back', (
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

      final stop = find.byKey(
        const ValueKey<String>('fake-media-disconnected'),
      );
      await scrollToCommunitySection(tester, stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();

      // The room is still running, so the membership stands and the audio is
      // on offer again.
      expect(voice.commands, contains('load'));
      expect(voice.commands, isNot(contains('leave')));
      final disconnected = find.text('语音已断开');
      await scrollToCommunitySection(tester, disconnected);
      expect(disconnected, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
        findsOneWidget,
      );
      expect(find.text('房间已结束'), findsNothing);
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

    testWidgets('a host takes its own mute intent back off a speaker row', (
      tester,
    ) async {
      final voice = hostGateway(
        speakers: <VoiceRoomMember>[
          testVoiceRoomMember(
            view: VoiceRoomRosterView.speaker,
            muted: true,
            commands: const <VoiceRoomMemberCommand>[
              VoiceRoomMemberCommand.removeSpeaker,
              VoiceRoomMemberCommand.unmute,
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
        const ValueKey<String>('voiceroom-member-speaker-$testMemberId'),
      );
      await scrollToCommunitySection(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      // The muted row now carries the way back out of the intent, and the
      // mute command is gone from it.
      expect(
        find.byKey(const ValueKey<String>('voiceroom-member-command-unmute')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-member-command-mute')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-member-command-unmute')),
      );
      await tester.pumpAndSettle();
      // The question says what the command does not do: it opens no
      // microphone for anyone.
      expect(find.textContaining('不会替对方打开麦克风'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(voice.commands, contains('unmute:$testMemberId'));
      expect(find.text('已取消静音意图'), findsOneWidget);
    });

    testWidgets(
      'a muted speaker clears its own mark and no other row is actionable',
      (tester) async {
        final voice =
            FakeVoiceRoomGateway(
                snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
              )
              ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
                VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
                  view: VoiceRoomRosterView.speaker,
                  items: <VoiceRoomMember>[
                    testVoiceRoomMember(
                      view: VoiceRoomRosterView.speaker,
                      muted: true,
                      isSelf: true,
                      commands: const <VoiceRoomMemberCommand>[
                        VoiceRoomMemberCommand.unmuteSelf,
                      ],
                    ),
                    testVoiceRoomMember(
                      view: VoiceRoomRosterView.speaker,
                      publicProfileId: testAdminId,
                      alias: 'DeFiMaxi_349',
                      muted: true,
                    ),
                  ],
                ),
                VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
                  view: VoiceRoomRosterView.listener,
                ),
              };
        await pumpCommunityPage(
          tester,
          const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
          voiceRoom: voice,
        );

        // The other muted row is still a row this viewer may not act on.
        final other = find.byKey(
          const ValueKey<String>('voiceroom-member-speaker-$testAdminId'),
        );
        await scrollToCommunitySection(tester, other);
        await tester.tap(other);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('voiceroom-member-sheet')),
          findsNothing,
        );

        final own = find.byKey(
          const ValueKey<String>('voiceroom-member-speaker-$testMemberId'),
        );
        await scrollToCommunitySection(tester, own);
        await tester.tap(own);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            const ValueKey<String>('voiceroom-member-command-unmute_self'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('不会打开麦克风'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey<String>('community-confirm-accept')),
        );
        await tester.pumpAndSettle();
        expect(voice.commands, contains('unmute:$testMemberId'));
      },
    );

    testWidgets('the microphone opening clears this account\'s mute mark', (
      tester,
    ) async {
      final voice =
          FakeVoiceRoomGateway(
              snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
            )
            ..rosters = <VoiceRoomRosterView, VoiceRoomMemberPage>{
              VoiceRoomRosterView.speaker: testVoiceRoomMemberPage(
                view: VoiceRoomRosterView.speaker,
                items: <VoiceRoomMember>[
                  testVoiceRoomMember(
                    view: VoiceRoomRosterView.speaker,
                    muted: true,
                    isSelf: true,
                    commands: const <VoiceRoomMemberCommand>[
                      VoiceRoomMemberCommand.unmuteSelf,
                    ],
                  ),
                ],
              ),
              VoiceRoomRosterView.listener: testVoiceRoomMemberPage(
                view: VoiceRoomRosterView.listener,
              ),
            };
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      // Mounting the call sends nothing: the intent is cleared by the
      // microphone opening, not by being in the room.
      expect(voice.commands, isNot(contains('unmute:$testMemberId')));

      final microphone = find.byKey(
        const ValueKey<String>('fake-microphone-opened'),
      );
      await scrollToCommunitySection(tester, microphone);
      await tester.tap(microphone);
      await tester.pumpAndSettle();
      // One DELETE, sent against the row the server marked as this account's,
      // and no question asked: the reader already opened the microphone.
      expect(
        voice.commands.where((command) => command == 'unmute:$testMemberId'),
        hasLength(1),
      );
      expect(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
        findsNothing,
      );
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

    // `#scr-voiceroom` opens on the `正在发言` grid, so the lobby reads the
    // speaker view — the same request the session page takes. The listener
    // list stays the session page's: the prototype's lobby says in so many
    // words that it is in the expanded view.
    testWidgets('the lobby asks for the speakers and nothing else', (
      tester,
    ) async {
      final voice = hostGateway();
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
      );

      final reads = voice.commands
          .where((command) => command.startsWith('members:'))
          .toList(growable: false);
      expect(reads, hasLength(1));
      expect(reads.single, contains('speaker'));
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
      // The part this account plays is on the strip, and the count is the
      // room's own joined figure — never an observation from some earlier
      // moment. R5-2: off the call that figure counts memberships, so the
      // strip says 「已加入」 and not 「在线」.
      expect(find.text('正在语音房 · $testVoiceRoomCommunityName'), findsOneWidget);
      expect(find.text('听众 · 46 人已加入'), findsOneWidget);
      expect(find.textContaining('上次观察'), findsNothing);
      expect(find.textContaining('人在线'), findsNothing);

      await tester.tap(banner);
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);
    });

    // S41: the call belongs to the app, not to the page. Closing the room
    // page used to dispose the widget that held it, so a reader who opened
    // another tab stopped hearing the room mid-sentence.
    testWidgets('closing the room page does not take the call down', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      final report = find.byKey(const ValueKey<String>('fake-presence'));
      await scrollToCommunitySection(tester, report);
      await tester.tap(report);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();

      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('media:leave')));
      // The strip carries the call's own head count, on whatever screen the
      // reader is looking at.
      expect(find.text('正在语音房 · $testVoiceRoomCommunityName'), findsOneWidget);
      expect(find.text('听众 · 3 人在通话'), findsOneWidget);

      // Coming back is a view binding to a call that never stopped: no second
      // call, no second token.
      await tester.tap(find.byKey(const ValueKey<String>('harness-open')));
      await tester.pumpAndSettle();
      expect(media.handles, hasLength(1));
      expect(media.joinCalls, 1);
      expect(find.text('语音已连接（测试）'), findsOneWidget);
    });

    testWidgets('the strip says what the call is doing, not what it was', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      final report = find.byKey(const ValueKey<String>('fake-presence'));
      await scrollToCommunitySection(tester, report);
      await tester.tap(report);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();

      // The provider drops the call while the reader is on another screen.
      // Nothing is putting it back, and the strip stops saying the room is
      // being heard.
      media.handles.first.emit(AudioRoomLivePhase.disconnected);
      await tester.pumpAndSettle();

      expect(find.text('正在语音房 · $testVoiceRoomCommunityName'), findsOneWidget);
      expect(find.text('听众 · 语音已断开'), findsOneWidget);
      expect(find.text('重新连接'), findsOneWidget);
      expect(find.text('返回房间'), findsNothing);
      // The dead call is taken down, and the room says the membership stands.
      expect(media.leaveCalls, 1);
      expect(voice.commands, contains('load'));
      expect(voice.commands, isNot(contains('leave')));
    });

    // Voice is foreground-only, and that rule did not move with the call:
    // LOOP leaving the foreground ends it whether or not a room page is on
    // screen. There is no background session behind any of this.
    testWidgets('LOOP leaving the foreground still ends the call', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();
      expect(media.leaveCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(media.leaveCalls, 1);
      // The membership is untouched: backgrounding is not leaving the room.
      expect(voice.commands, isNot(contains('leave')));

      // R9-6: the media went and the membership stayed, so the strip stays
      // too and says which of the two happened. On the review device it
      // simply disappeared, leaving the account recorded in a room it could
      // neither hear nor leave.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
        findsOneWidget,
      );
      expect(find.text('正在语音房 · $testVoiceRoomCommunityName'), findsOneWidget);
      expect(find.text('听众 · 语音已断开'), findsOneWidget);
      // Both ways out of it are on the strip: the audio back, or the room.
      expect(find.text('重新连接'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave')),
        findsOneWidget,
      );
    });

    testWidgets(
      'a room that ended while away takes the strip with it, and says so',
      (tester) async {
        final voice = FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        );
        final media = _FakeVoiceMediaFactory(log: voice.commands);
        await pumpCommunityPage(
          tester,
          _VoiceRoomBannerHarness(opened: <String>[]),
          voiceRoom: voice,
          audioRoomCallFactory: media,
        );
        await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
        await tester.pumpAndSettle();

        voice.loadSnapshot = testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          state: VoiceRoomState.ended,
        );
        media.handles.first.emit(AudioRoomLivePhase.disconnected);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
          findsNothing,
        );
        expect(media.leaveCalls, 1);
        // A marker the reader saw a moment ago cannot simply vanish: the strip
        // going is the whole visible consequence, so one line accounts for it.
        expect(find.text('房间已结束 · 主持人已经结束这个语音房'), findsOneWidget);
      },
    );

    // R9-5: the announcement is only as alive as the call that raises it. On
    // the review device the page was popped, the media chain went with it,
    // and when the host ended the room two minutes later nothing was left
    // listening: the strip stood there saying 「语音已断开」 and no line was
    // ever said. This mounts the chain the way production has it — a factory
    // derived from an autoDispose authorization — so the page going off the
    // screen is the real event and not one a value override papers over.
    testWidgets(
      'R9-5: a room ended off-screen still reaches the reader on another tab',
      (tester) async {
        final voice = FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        );
        final media = _FakeVoiceMediaFactory(log: voice.commands);
        var authorizations = 0;
        var chainGeneration = 0;

        await pumpCommunityPage(
          tester,
          _VoiceRoomBannerHarness(opened: <String>[]),
          voiceRoom: voice,
          videoAuthorizationLoader: () async {
            authorizations += 1;
            return StreamVideoSessionAuthorization.authorized;
          },
          audioRoomCallFactorySource: (ref) {
            final authorized =
                ref.watch(streamVideoAuthorizationProvider).value ==
                StreamVideoSessionAuthorization.authorized;
            final mine = ++chainGeneration;
            ref.onDispose(() {
              // A rebuild disposes the old element and builds another; a
              // chain that is really gone never does. What goes with it is
              // the client, and the call running on it: that is the
              // connection the review device saw closed on the way out.
              scheduleMicrotask(() {
                if (mine != chainGeneration) return;
                for (final call in media.handles) {
                  call.collapse();
                }
              });
            });
            return authorized ? media : null;
          },
        );

        final report = find.byKey(const ValueKey<String>('fake-presence'));
        await scrollToCommunitySection(tester, report);
        await tester.tap(report);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
        await tester.pumpAndSettle();

        // The page left; what the call is made of stayed. A chain that had
        // been dropped would go back for an authorization of its own.
        expect(authorizations, 1);
        expect(media.leaveCalls, 0);
        expect(
          find.text('正在语音房 · $testVoiceRoomCommunityName'),
          findsOneWidget,
        );
        expect(find.text('听众 · 3 人在通话'), findsOneWidget);

        // The host ends the room while the reader is somewhere else.
        voice.loadSnapshot = testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          state: VoiceRoomState.ended,
        );
        media.handles.first.emit(AudioRoomLivePhase.disconnected);
        await tester.pumpAndSettle();

        expect(media.leaveCalls, 1);
        expect(
          find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
          findsNothing,
        );
        expect(find.text('房间已结束 · 主持人已经结束这个语音房'), findsOneWidget);
        expect(authorizations, 1);
      },
    );

    testWidgets('离开 from the strip ends the call and the membership', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();

      // Leaving ends the membership, so the strip asks before it does.
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave')),
      );
      await tester.pumpAndSettle();
      expect(find.text('离开后你会退出这次通话，举手也会一并取消。'), findsOneWidget);
      expect(media.leaveCalls, 0);
      expect(voice.commands, isNot(contains('leave')));

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave-confirm')),
      );
      await tester.pumpAndSettle();

      // Same order as the room page's own exit: the call goes down first.
      expect(media.leaveCalls, 1);
      expect(
        voice.commands.indexOf('leave'),
        greaterThan(voice.commands.indexOf('media:leave')),
      );
      expect(find.text('已离开语音房'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
        findsNothing,
      );

      // The app holds nothing now: opening the room again makes a new call.
      await tester.tap(find.byKey(const ValueKey<String>('harness-open')));
      await tester.pumpAndSettle();
      expect(media.handles, hasLength(2));
    });

    // R9-3: the strip is above the router, so its own context is above every
    // tab scope and would answer 「no bar here」 on every screen. On the review
    // device the 「已离开语音房」 toast was placed as if nothing were under it
    // and came out beneath the floating bar, with one corner showing.
    testWidgets('R9-3: a toast from the strip clears the bar under it', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[], onTabRoute: () => true),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );
      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已离开语音房'), findsOneWidget);
      final placement = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byType(LoopToastView),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(placement.bottom, LoopToast.bottomOffset);
    });

    // A banner for a room that no longer exists takes the reader back to a
    // page with nothing on it.
    testWidgets('a room that ended takes the banner with it', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
      );

      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.listener,
        state: VoiceRoomState.ended,
      );
      final stop = find.byKey(
        const ValueKey<String>('fake-media-disconnected'),
      );
      await scrollToCommunitySection(tester, stop);
      await tester.tap(stop);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-minimized-banner')),
        findsNothing,
      );
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

    // R10-1: one line under an ellipsis drops the tail of the sentence, and
    // the tail is the only part a reader cannot guess. On the review device a
    // 14-character room name already left 「正在语音房 · Builders Guild · 听众 ·
    // 1 …」, so a call that stood read exactly like one that had stopped. The
    // room name is what gives way now, and the state never does.
    testWidgets('R10-1: a long room name never eats the state', (tester) async {
      const longName = '链上治理与合约安全长期研讨会共建者联盟第七期常设分会场';
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.listener,
          communityName: longName,
        ),
      );
      final media = _FakeVoiceMediaFactory(log: voice.commands);
      await pumpCommunityPage(
        tester,
        _VoiceRoomBannerHarness(opened: <String>[]),
        voiceRoom: voice,
        audioRoomCallFactory: media,
        // The narrowest screen this ships to.
        size: const Size(360, 1400),
      );
      final report = find.byKey(const ValueKey<String>('fake-presence'));
      await scrollToCommunitySection(tester, report);
      await tester.tap(report);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
      await tester.pumpAndSettle();

      // The state and the count are set whole: the line wraps, it does not
      // end in an ellipsis, and nothing of it is left unpainted.
      final status = find.text('听众 · 3 人在通话');
      expect(status, findsOneWidget);
      final statusText = tester.widget<Text>(status);
      expect(statusText.maxLines, isNull);
      expect(statusText.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester.renderObject<RenderParagraph>(status).didExceedMaxLines,
        isFalse,
      );

      // The room name is on a line of its own, and that is the line the
      // width is taken out of.
      final title = find.text('正在语音房 · $longName');
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).maxLines, 1);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isTrue,
      );

      // A stopped call says so on the strip itself, under the same long name,
      // instead of only in the button beside it.
      media.handles.first.emit(AudioRoomLivePhase.disconnected);
      await tester.pumpAndSettle();
      expect(find.text('听众 · 语音已断开'), findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('听众 · 语音已断开'))
            .didExceedMaxLines,
        isFalse,
      );
    });
  });

  group('voiceroom banner label', () {
    test('the strip names the room, the part and the people in it', () {
      // R5-2: the two figures that can stand here count different things, so
      // each is named for what it counts. On the review device the same word
      // covered both and the strip went from 「1 人在线」 to 「5 人在线」 as the
      // room page came off the screen.
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.host,
          count: 4,
          phase: AudioRoomLivePhase.connected,
        ),
        '正在语音房 · Builders Guild · 主持人 · 4 人在通话',
      );
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.host,
          count: 4,
          phase: AudioRoomLivePhase.idle,
        ),
        '正在语音房 · Builders Guild · 主持人 · 4 人已加入',
      );
      // No figure is invented when there is none to state.
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.speaker,
          count: null,
          phase: AudioRoomLivePhase.idle,
        ),
        '正在语音房 · Builders Guild · 发言人',
      );
      // Connected without a count yet: never a 0, and never silence either.
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.speaker,
          count: null,
          phase: AudioRoomLivePhase.connected,
        ),
        '正在语音房 · Builders Guild · 发言人 · 人数正在统计',
      );
      // S41: the call outlives the page, so the strip carries what it is
      // doing instead of one word for every moment off the call. A figure
      // from another moment is never printed under any of them.
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.listener,
          count: 46,
          phase: AudioRoomLivePhase.connecting,
        ),
        '正在语音房 · Builders Guild · 听众 · 正在连接语音',
      );
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.listener,
          count: 46,
          phase: AudioRoomLivePhase.reconnecting,
        ),
        '正在语音房 · Builders Guild · 听众 · 语音正在重连',
      );
      expect(
        voiceRoomBannerLabel(
          communityName: 'Builders Guild',
          role: VoiceRoomRole.listener,
          count: 46,
          phase: AudioRoomLivePhase.disconnected,
        ),
        '正在语音房 · Builders Guild · 听众 · 语音已断开',
      );
    });

    // R10-1: the strip sets the sentence in two lines, so each half is a
    // sentence of its own. The whole label is still what the two read
    // together — that is what assistive tech is handed.
    test('the two halves are the whole sentence, split where it may give', () {
      const name = '链上治理与合约安全长期研讨会共建者联盟第七期常设分会场';
      expect(voiceRoomBannerTitle(name), '正在语音房 · $name');
      expect(
        voiceRoomBannerStatus(
          role: VoiceRoomRole.listener,
          count: 3,
          phase: AudioRoomLivePhase.connected,
        ),
        '听众 · 3 人在通话',
      );
      expect(
        voiceRoomBannerStatus(
          role: VoiceRoomRole.host,
          count: null,
          phase: AudioRoomLivePhase.idle,
        ),
        '主持人',
      );
      for (final phase in AudioRoomLivePhase.values) {
        expect(
          voiceRoomBannerLabel(
            communityName: name,
            role: VoiceRoomRole.listener,
            count: 3,
            phase: phase,
          ),
          '${voiceRoomBannerTitle(name)} · '
          '${voiceRoomBannerStatus(role: VoiceRoomRole.listener, count: 3, phase: phase)}',
        );
      }
    });
  });

  group('community-ai', () {
    testWidgets('is the prototype page, in the prototype order, with nothing '
        'behind it', (tester) async {
      await pumpCommunityPage(tester, const CommunityAiScreen());

      // The page the AI button opens: the bar, the hero, the assistant's
      // turn, what it will be able to do, the sample questions, and the
      // composer the prototype ends with.
      expect(find.text('Community AI'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('community-ai-hero')),
        findsOneWidget,
      );
      expect(find.text('Community AI 还没有开放'), findsOneWidget);
      // The server's own sentence reaches the reader, and no reason code
      // does.
      expect(find.textContaining('这一页暂时不可用。'), findsWidgets);
      expect(find.textContaining('COMMUNITY_AI'), findsNothing);

      final collection = tester.widget<ListView>(
        find.byKey(const ValueKey<String>('community-ai-collection')),
      );
      final blocks = (collection.childrenDelegate as SliverChildListDelegate)
          .children
          .map((widget) => widget.key)
          .toList(growable: false);
      expect(blocks, <Key?>[
        null,
        const ValueKey<String>('community-ai-unavailable'),
        null,
        null,
        const ValueKey<String>('community-ai-scope-note'),
        null,
        const ValueKey<String>('community-ai-samples'),
      ]);

      // The prototype's sample answer and knowledge-base figures have no
      // source and must not appear.
      expect(find.textContaining('知识库 14 篇文档'), findsNothing);
      expect(find.textContaining('今日 42 条讨论'), findsNothing);
    });

    testWidgets('the composer takes no question and sends none', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const CommunityAiScreen());

      expect(
        find.byKey(const ValueKey<String>('community-ai-composer-unavailable')),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('loop-composer-input')),
      );
      expect(field.enabled, isFalse);
      final send = tester.widget<InkWell>(
        find.byKey(const ValueKey<String>('loop-composer-send')),
      );
      expect(send.onTap, isNull);
    });

    testWidgets('a sample question is a question, never a control', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const CommunityAiScreen());

      await scrollToCommunitySection(
        tester,
        find.byKey(const ValueKey<String>('community-ai-samples')),
      );
      for (final sample in const <String>[
        'Tokenomics 怎么分配',
        '怎么参与挖矿',
        '这周有什么动态',
      ]) {
        final chip = find.byKey(
          ValueKey<String>('community-ai-sample-$sample'),
        );
        expect(chip, findsOneWidget);
        expect(
          tester
              .widget<InkWell>(
                find.descendant(of: chip, matching: find.byType(InkWell)),
              )
              .onTap,
          isNull,
        );
      }
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
  final StreamController<AudioRoomCallReading> _readings =
      StreamController<AudioRoomCallReading>.broadcast();
  AudioRoomCallReading _reading = const AudioRoomCallReading(
    phase: AudioRoomLivePhase.connecting,
    participantCount: null,
  );

  @override
  AudioRoomCallReading get reading => _reading;

  @override
  Stream<AudioRoomCallReading> get readings => _readings.stream;

  final StreamController<AudioRoomRoomSignal> _signals =
      StreamController<AudioRoomRoomSignal>.broadcast();

  @override
  Stream<AudioRoomRoomSignal> get roomSignals => _signals.stream;

  /// Stands in for the provider telling this device the room changed.
  void emitSignal(AudioRoomRoomSignal signal) => _signals.add(signal);

  /// Stands in for the WebRTC stack being torn down under a call nobody
  /// asked to leave — the provider connection is closed and the reading says
  /// so, with no retirement of this device's own behind it. This is what the
  /// review device did to a live call the moment the room page was popped.
  void collapse() => emit(AudioRoomLivePhase.disconnected);

  /// Stands in for the provider's call state moving on its own. The reading
  /// leaves the call itself, which is what the strip reads once the room page
  /// is no longer on the screen.
  void emit(
    AudioRoomLivePhase phase, {
    int? participantCount,
    List<AudioRoomSpeaker> speakers = const <AudioRoomSpeaker>[],
  }) {
    _reading = AudioRoomCallReading(
      phase: phase,
      participantCount: participantCount,
      speakers: speakers,
    );
    _readings.add(_reading);
  }

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
  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  }) async {
    microphoneCalls += 1;
    return const AudioRoomMicrophoneOutcome.opened();
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
    Future<void> Function()? onMicrophoneEnabled,
    void Function({
      required AudioRoomLivePhase phase,
      required int? participantCount,
      required List<AudioRoomSpeaker> speakers,
    })?
    onPresence,
    VoidCallback? onDisconnected,
    Future<void> Function()? onSpeakAgainRequested,
  }) {
    return Column(
      children: <Widget>[
        const Text('语音已连接（测试）'),
        // Stands in for the official call state reporting its own head
        // count: the page and the shell strip read that, not an observation
        // taken earlier.
        TextButton(
          key: const ValueKey<String>('fake-presence'),
          onPressed: () {
            emit(AudioRoomLivePhase.connected, participantCount: 3);
            onPresence?.call(
              phase: AudioRoomLivePhase.connected,
              participantCount: 3,
              speakers: const <AudioRoomSpeaker>[],
            );
          },
          child: const Text('报告人数'),
        ),
        // Stands in for the SFU reporting somebody with a microphone open:
        // the grid above this panel draws the call, not LOOP's record of the
        // parts it granted.
        TextButton(
          key: const ValueKey<String>('fake-presence-speaking'),
          onPressed: () {
            const speakers = <AudioRoomSpeaker>[
              AudioRoomSpeaker(
                key: 'session-host',
                name: 'NightOwl',
                isLocal: true,
                isSpeaking: true,
              ),
            ];
            emit(
              AudioRoomLivePhase.connected,
              participantCount: 1,
              speakers: speakers,
            );
            onPresence?.call(
              phase: AudioRoomLivePhase.connected,
              participantCount: 1,
              speakers: speakers,
            );
          },
          child: const Text('报告有人在说话'),
        ),
        // Stands in for the SDK putting a dropped connection back on its own:
        // the call view stays, and the surfaces above it are told the phase,
        // not just that the device is 「not connected」.
        TextButton(
          key: const ValueKey<String>('fake-presence-reconnecting'),
          onPressed: () {
            emit(AudioRoomLivePhase.reconnecting);
            onPresence?.call(
              phase: AudioRoomLivePhase.reconnecting,
              participantCount: null,
              speakers: const <AudioRoomSpeaker>[],
            );
          },
          child: const Text('报告重连中'),
        ),
        // Stands in for the seconds between the connection and the SFU's
        // first head count: connected, and nobody counted yet.
        TextButton(
          key: const ValueKey<String>('fake-presence-counting'),
          onPressed: () {
            emit(AudioRoomLivePhase.connected);
            onPresence?.call(
              phase: AudioRoomLivePhase.connected,
              participantCount: null,
              speakers: const <AudioRoomSpeaker>[],
            );
          },
          child: const Text('报告连接但未统计'),
        ),
        // Stands in for the provider stopping this call with nobody putting
        // it back. The status goes through the same policy the official view
        // applies, so the page is driven by a call state and not by a
        // callback a test decided to fire.
        TextButton(
          key: const ValueKey<String>('fake-media-disconnected'),
          onPressed: () {
            if (StreamCallDisconnectPolicy.collapses(
              status: CallStatus.disconnected(
                DisconnectReason.reconnectionFailed(),
              ),
              retirementStarted: retirementStarted,
            )) {
              onDisconnected?.call();
            }
          },
          child: const Text('断开'),
        ),
        TextButton(
          key: const ValueKey<String>('fake-hangup'),
          onPressed: () => unawaited(onLeaveRequested()),
          child: const Text('挂断'),
        ),
        // Stands in for the device having opened the microphone: the surface
        // reports it only after the media command succeeded.
        TextButton(
          key: const ValueKey<String>('fake-microphone-opened'),
          onPressed: () async {
            microphoneCalls += 1;
            await onMicrophoneEnabled?.call();
          },
          child: const Text('开麦'),
        ),
      ],
    );
  }
}

/// Mounts the shell banner beside the room page so one test can close the page
/// without tearing down the provider scope that holds the session.
class _VoiceRoomBannerHarness extends StatefulWidget {
  const _VoiceRoomBannerHarness({required this.opened, this.onTabRoute});

  final List<String> opened;

  /// What the shell answers about the route the router is on. The strip sits
  /// above the router and cannot read it for itself.
  final bool Function()? onTabRoute;

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
        VoiceRoomMinimizedBanner(
          onOpen: widget.opened.add,
          onTabRoute: widget.onTabRoute,
        ),
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
        // Stands in for the reader coming back to the room from the strip.
        TextButton(
          key: const ValueKey<String>('harness-open'),
          onPressed: () => setState(() => _open = true),
          child: const Text('open'),
        ),
      ],
    );
  }
}
