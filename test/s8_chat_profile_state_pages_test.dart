import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/s5_page_harness.dart';

/// Loading / Empty / Error / Offline for the chat and profile pages the
/// 93-page matrix still listed as thin: `group`, `chat-search`,
/// `chat-forward`, `profile-edit`, `privacy`, `notif-settings`.
///
/// The recurring finding behind this file is the same on all six pages: a
/// request that never reached the server was being rendered as an answer. A
/// chat surface said the account's membership could not be confirmed, a search
/// said it had not completed, and a settings save said nothing at all. 01 §9
/// gives that observation its own state, so each page now routes it to a block
/// that names the actions it paused.

// ---------------------------------------------------------------------------
// chat · group
// ---------------------------------------------------------------------------

/// A LOOP token call that never left the device.
const _offlineToken = LoopBackendFailure(
  LoopBackendFailureKind.connection,
  code: 'connection_failed',
);

/// A token call the server answered, and refused.
const _refusedToken = LoopBackendFailure(
  LoopBackendFailureKind.unexpected,
  code: 'stream_token_unavailable',
);

// ---------------------------------------------------------------------------
// chat · chat-search
// ---------------------------------------------------------------------------

final class _FakeChatSearchGateway implements ChatSearchGateway {
  _FakeChatSearchGateway({
    this.hits = const <ChatSearchHit>[],
    this.failure,
    this.pending = false,
  });

  @override
  bool get connected => true;

  final List<ChatSearchHit> hits;
  final ChatSearchException? failure;
  final bool pending;

  int searches = 0;

  @override
  Future<List<ChatSearchHit>> search({
    required String query,
    required ChatSearchScope scope,
    required String? originCid,
    required int limit,
  }) {
    searches += 1;
    if (pending) return Completer<List<ChatSearchHit>>().future;
    final error = failure;
    if (error != null) return Future<List<ChatSearchHit>>.error(error);
    return Future<List<ChatSearchHit>>.value(hits);
  }
}

ChatSearchHit _hit() => ChatSearchHit(
  messageId: 'm1',
  cid: testGroupCid,
  senderLabel: '群成员',
  channelLabel: '群聊',
  text: '看看这个',
  createdAt: DateTime.utc(2026, 9, 8, 12),
);

Future<void> _query(WidgetTester tester, {bool settle = true}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('chat-search-input')),
    'loop',
  );
  await tester.testTextInput.receiveAction(TextInputAction.search);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

// ---------------------------------------------------------------------------
// profile · profile-edit and privacy
// ---------------------------------------------------------------------------

ProfileResource _profile({String? alias = 'Voyager_7'}) => ProfileResource(
  version: 1,
  values: ProfileValues(
    alias: alias,
    avatarRef: 'avatar:preset/people-01',
    bio: null,
    interests: const <ProfileInterest>[],
  ),
  updatedAt: DateTime.utc(2026, 9, 7, 1),
  loopId: 'LOOP-7HJKMNPQ',
  profileStatus: ProfileStatus.active,
  activatedAt: DateTime.utc(2026, 9, 7, 1),
);

final class _ProfileGateway implements ProfileGateway {
  _ProfileGateway({this.resource, this.failure});

  final ProfileResource? resource;
  final ProfileGatewayException? failure;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async {
    final error = failure;
    if (error != null) throw error;
    return resource!;
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    return ProfileResource(
      version: expectedVersion + 1,
      values: values,
      updatedAt: DateTime.utc(2026, 9, 7, 2),
      loopId: 'LOOP-7HJKMNPQ',
      profileStatus: ProfileStatus.active,
      activatedAt: DateTime.utc(2026, 9, 7, 1),
    );
  }
}

final class _PrivacyGateway implements PrivacyGateway {
  _PrivacyGateway({this.saveFailure});

  final PrivacyGatewayException? saveFailure;

  @override
  PrivacyMode get mode => PrivacyMode.production;

  @override
  Future<PrivacyResource> load() async => PrivacyResource(
    version: 1,
    values: const PrivacyValues(discoverable: true, anonymousMode: true),
    updatedAt: DateTime.utc(2026, 9, 7, 1),
  );

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) async {
    final error = saveFailure;
    if (error != null) throw error;
    return PrivacyResource(
      version: expectedVersion + 1,
      values: values,
      updatedAt: DateTime.utc(2026, 9, 7, 2),
    );
  }
}

final class _AvatarCatalog implements AvatarCatalogGateway {
  const _AvatarCatalog();

  @override
  Future<List<AvatarPreset>> load() async => const <AvatarPreset>[
    AvatarPreset(
      avatarRef: 'avatar:preset/people-01',
      atlas: 'people',
      slot: 1,
      label: 'People 01',
    ),
  ];
}

Future<void> _pumpProfile(
  WidgetTester tester,
  String surfaceId, {
  ProfileGateway? profile,
  PrivacyGateway? privacy,
}) async {
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileGatewayProvider.overrideWithValue(
          profile ?? _ProfileGateway(resource: _profile()),
        ),
        privacyGatewayProvider.overrideWithValue(privacy ?? _PrivacyGateway()),
        avatarCatalogGatewayProvider.overrideWithValue(const _AvatarCatalog()),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: LoopToastHost(
          child: ProfileSurfaceScreen.fromId(surfaceId, onNavigate: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('group', () {
    testWidgets('a chat session still being restored shows its own state', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupChatScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        streamAuthorization: () =>
            Completer<StreamSessionAuthorization>().future,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('group-channel-connecting')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-channel-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('group-channel-offline')),
        findsNothing,
      );
    });

    testWidgets('empty is a group that was never named, not an empty channel', (
      tester,
    ) async {
      // Message history belongs to Stream, so this page owns no collection
      // that can come back with no rows: "nothing to show" only exists when
      // the route carried no channel address at all. It fails closed and
      // renders no error, because nothing failed.
      await pumpCommunityPage(
        tester,
        const GroupChatScreen(channelCid: null),
        chat: FakeChatV2Gateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('group-missing-cid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-channel-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('group-channel-offline')),
        findsNothing,
      );
    });

    testWidgets('a refused chat token is an error with a retry', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupChatScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        streamAuthorization: () =>
            Future<StreamSessionAuthorization>.error(_refusedToken),
      );

      expect(
        find.byKey(const ValueKey<String>('group-channel-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('group-channel-offline')),
        findsNothing,
      );
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('an offline token call pauses instead of erroring', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        GroupChatScreen(channelCid: testGroupCid),
        chat: FakeChatV2Gateway(),
        streamAuthorization: () =>
            Future<StreamSessionAuthorization>.error(_offlineToken),
      );

      expect(
        find.byKey(const ValueKey<String>('group-channel-offline')),
        findsOneWidget,
      );
      // A token call that never left the device did not refuse anything.
      expect(
        find.byKey(const ValueKey<String>('group-channel-error')),
        findsNothing,
      );
      expect(find.textContaining('已暂停'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-stream-message-composer')),
        findsNothing,
      );
    });
  });

  group('chat-search', () {
    testWidgets('a search in flight shows the skeleton and no result count', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(pending: true),
      );
      await _query(tester, settle: false);

      expect(
        find.byKey(const ValueKey<String>('chat-search-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-results')),
        findsNothing,
      );
      expect(find.text('0 条结果'), findsNothing);
    });

    testWidgets('a search that matched nothing is empty, not an error', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(),
      );
      await _query(tester);

      expect(
        find.byKey(const ValueKey<String>('chat-search-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-state-offline')),
        findsNothing,
      );
    });

    testWidgets('a refused search is an error and shows no result', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(
          hits: <ChatSearchHit>[_hit()],
          failure: const ChatSearchException(offline: false),
        ),
      );
      await _query(tester);

      expect(
        find.byKey(const ValueKey<String>('chat-search-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-state-offline')),
        findsNothing,
      );
      expect(find.text('看看这个'), findsNothing);
    });

    testWidgets('an offline search pauses and never reads as no matches', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(
          failure: const ChatSearchException(offline: true),
        ),
      );
      await _query(tester);

      expect(
        find.byKey(const ValueKey<String>('chat-search-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-search-empty')),
        findsNothing,
      );
      expect(find.text('没有匹配的消息'), findsNothing);
    });
  });

  group('chat-forward', () {
    testWidgets('a pending read shows the skeleton and selects nothing', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatForwardScreen(sourceCid: testGroupCid),
        forwardState: const ChatForwardState(
          sourceCid: testGroupCid,
          loading: true,
        ),
        // The skeleton animates forever, so the frame is pumped rather than
        // settled.
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('chat-forward-loading')),
        findsOneWidget,
      );
      expect(find.text('0 条已选择'), findsOneWidget);
    });

    testWidgets('a read with nothing forwardable states both empties', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatForwardScreen(sourceCid: testGroupCid),
        forwardState: const ChatForwardState(sourceCid: testGroupCid),
      );

      expect(
        find.byKey(const ValueKey<String>('chat-forward-no-messages')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-forward-no-targets')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-forward-error')),
        findsNothing,
      );
    });

    testWidgets('a failed read is an error and offers a retry', (tester) async {
      await pumpCommunityPage(
        tester,
        const ChatForwardScreen(sourceCid: testGroupCid),
        forwardState: const ChatForwardState(
          sourceCid: testGroupCid,
          failed: true,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('chat-forward-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-forward-state-offline')),
        findsNothing,
      );
    });

    testWidgets('an offline read pauses and forwards nothing', (tester) async {
      await pumpCommunityPage(
        tester,
        const ChatForwardScreen(sourceCid: testGroupCid),
        forwardState: const ChatForwardState(
          sourceCid: testGroupCid,
          offline: true,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('chat-forward-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-forward-error')),
        findsNothing,
      );
      // An offline read is not "this conversation has no messages".
      expect(
        find.byKey(const ValueKey<String>('chat-forward-no-messages')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-forward-open-merge')),
        findsNothing,
      );
    });
  });

  group('profile-edit', () {
    testWidgets('empty does not apply: an activated profile is always a form', (
      tester,
    ) async {
      // `GET /v2/profile` answers with one resource whose optional fields may
      // be null; there is no collection that can come back with no rows. An
      // unset alias is an empty field, never an empty page, and the editor
      // renders no failure block for it.
      await _pumpProfile(
        tester,
        'profile-edit',
        profile: _ProfileGateway(resource: _profile(alias: null)),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('profile-empty')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('profile-edit-failure')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('profile-error')), findsNothing);
    });

    testWidgets('a failed read never shows an editable identity', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        'profile-edit',
        profile: _ProfileGateway(
          failure: const ProfileGatewayException(
            ProfileGatewayFailureKind.unexpected,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('profile-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('profile-edit-alias-field')),
        findsNothing,
      );
    });
  });

  group('privacy', () {
    testWidgets('empty does not apply: privacy is a fixed set of switches', (
      tester,
    ) async {
      // `GET /v2/privacy` answers with one `PrivacyValues` record covering
      // every switch the page renders. There is no list to be empty, so the
      // loaded page always shows the full set and no failure block.
      await _pumpProfile(tester, 'privacy');

      expect(
        find.byKey(const ValueKey<String>('privacy-anonymous-mode')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('privacy-empty')), findsNothing);
      expect(find.byKey(const ValueKey<String>('privacy-error')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('privacy-save-failure')),
        findsNothing,
      );
    });

    testWidgets('an offline save pauses and keeps the switches it read', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        'privacy',
        privacy: _PrivacyGateway(
          saveFailure: const PrivacyGatewayException(
            PrivacyGatewayFailureKind.offline,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('privacy-discoverable')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('privacy-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('privacy-save-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privacy-save-failure')),
        findsNothing,
      );
      // A save that never reached the server announces no version.
      expect(find.textContaining('已提交到版本'), findsNothing);
    });

    testWidgets('a refused save says so instead of silently doing nothing', (
      tester,
    ) async {
      await _pumpProfile(
        tester,
        'privacy',
        privacy: _PrivacyGateway(
          saveFailure: const PrivacyGatewayException(
            PrivacyGatewayFailureKind.unexpected,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('privacy-discoverable')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('privacy-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('privacy-save-failure')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privacy-save-offline')),
        findsNothing,
      );
      expect(find.textContaining('已提交到版本'), findsNothing);
    });
  });

  group('notif-settings', () {
    testWidgets('a pending read shows the skeleton and no switch', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          preferences: S5Answer<LoopNotificationPreferences>(pending: true),
        ),
        settle: false,
      );

      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-state-loading'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
        findsNothing,
      );
      expect(find.textContaining('项开启'), findsNothing);
    });

    testWidgets('empty does not apply: every category is always present', (
      tester,
    ) async {
      // `GET /v2/notifications/preferences` always answers with the full
      // category set, so `LoopNotificationPreferences` cannot come back with
      // no rows: the state block's empty arm is unreachable here.
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-state-empty'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-state-error'),
        ),
        findsNothing,
      );
      expect(find.textContaining('项开启'), findsOneWidget);
    });

    testWidgets('a failed read is an error, never a page of default switches', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          preferences: S5Answer<LoopNotificationPreferences>(
            failure: LoopChainFailureKind.unexpected,
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-state-error'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
        findsNothing,
      );
    });

    testWidgets('an offline save pauses and never reads as a failed save', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          writeFailure: LoopChainFailureKind.offline,
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-save-offline'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-preferences-error')),
        findsNothing,
      );
      expect(find.text('通知设置已保存'), findsNothing);
    });
  });
}
