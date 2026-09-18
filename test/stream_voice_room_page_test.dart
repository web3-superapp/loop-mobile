import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/calls/voice_media_link.dart';
import 'package:loop_mobile/features/chat/voice_room_page.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  testWidgets('signed-out production page never displays preview room data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [streamVideoPrincipalKeyProvider.overrideWithValue(null)],
        child: MaterialApp(theme: LoopTheme.dark, home: const VoiceRoomPage()),
      ),
    );

    expect(find.text('需要完成登录验证'), findsOneWidget);
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
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const StreamVoiceRoomPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语音会话暂时不可用'), findsOneWidget);
    expect(find.text('连接语音'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '连接语音'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('authorized frontend requires a backend-assigned room', (
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
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const StreamVoiceRoomPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有拿到语音房'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsNothing);
    expect(find.text('Connected'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '连接语音'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('join is muted single-flight and leave returns to lobby', (
    tester,
  ) async {
    final joinGate = Completer<void>();
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinFuture: joinGate.future,
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();

    expect(find.text('语音可以连接'), findsOneWidget);
    expect(find.text('进入即静音'), findsOneWidget);
    expect(find.text('按需申请权限'), findsOneWidget);

    await tester.tap(find.text('连接语音'));
    await tester.tap(find.text('连接语音'));
    await tester.pump();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(factory.createCalls, 1);
    expect(handle.joinCalls, 1);
    expect(find.text('连接语音'), findsNothing);

    joinGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(find.text('语音可以连接'), findsNothing);

    await tester.tap(find.byKey(const Key('fake-leave-room')));
    await tester.pumpAndSettle();

    expect(handle.leaveCalls, 1);
    expect(find.text('语音可以连接'), findsOneWidget);
  });

  testWidgets('join failure is sanitized and retires the failed Call', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinError: StateError('provider-secret-detail'),
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    expect(find.text('连接失败'), findsOneWidget);
    // An error the provider did not classify keeps the neutral sentence; the
    // provider's own words never reach the screen.
    expect(find.text('没能连上这个语音房，请稍后重试。'), findsOneWidget);
    expect(find.textContaining('provider-secret-detail'), findsNothing);
    expect(handle.leaveCalls, 1);
    expect(find.text('Official CallState view'), findsNothing);
  });

  testWidgets('a refused admission says so without quoting the provider', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinError: const AudioRoomCallFailure(
        AudioRoomCallFailureKind.join,
        refusal: AudioRoomJoinRefusal.permission,
        detail: 'missing permission join-backstage',
      ),
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    expect(find.text('这个房间还没有开放收听，请让主持人重新开启。'), findsOneWidget);
    expect(find.textContaining('join-backstage'), findsNothing);
    expect(find.textContaining('permission'), findsNothing);
    // The neutral sentence is not stacked on top of the one that says what
    // happened.
    expect(find.text('没能连上这个语音房，请稍后重试。'), findsNothing);
  });

  testWidgets('a connection that never arrived is not a refused room', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinError: const AudioRoomCallFailure(
        AudioRoomCallFailureKind.join,
        refusal: AudioRoomJoinRefusal.network,
        detail: 'connection timed out',
      ),
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    expect(find.text('这次连接没有接通，请检查网络后重试。'), findsOneWidget);
    expect(find.text('这个房间还没有开放收听，请让主持人重新开启。'), findsNothing);
  });

  testWidgets('the second attempt reads the room again and makes a new call', (
    tester,
  ) async {
    final factory = _SequencedAudioRoomCallFactory(<_RecordingAudioRoomCall>[
      _RecordingAudioRoomCall(
        roomId: 'loop-daily',
        joinError: const AudioRoomCallFailure(
          AudioRoomCallFailureKind.join,
          refusal: AudioRoomJoinRefusal.permission,
          detail: 'missing permission join-backstage',
        ),
      ),
      _RecordingAudioRoomCall(roomId: 'loop-daily'),
    ]);
    var refreshes = 0;

    await tester.pumpWidget(
      _readyPage(
        factory: factory,
        target: _target('loop-daily'),
        autoConnect: true,
        onReconnectRequested: () async => refreshes += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已加入，语音连接失败'), findsOneWidget);
    expect(factory.createCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
    );
    await tester.pumpAndSettle();

    // The room and the provider session are read again before anything is
    // connected, and the attempt runs on a call this device has not been
    // refused on.
    expect(refreshes, 1);
    expect(factory.createCalls, 2);
    expect(factory.handles.first.joinCalls, 1);
    expect(factory.handles.last.joinCalls, 1);
    expect(find.text('Official CallState view'), findsOneWidget);
  });

  testWidgets('R5-1: 「重试会话」 goes back for a token and makes a new call', (
    tester,
  ) async {
    // The refusal this card names — an authorized room with no usable
    // client — is held by the session this device already authorized, and
    // the session answers a second watch from the client it still holds. On
    // the review device three taps produced no request at all: no token, no
    // client, no call, and no way forward except leaving the page.
    final source = _RecordingVideoSource(
      identity: const StreamVideoIdentity(userId: 'stream-user-a'),
    );
    final clients = _RecordingVideoClientFactory();
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
    final calls = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_videoConfig()),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          streamVideoSessionSourceProvider.overrideWithValue(source),
          streamVideoClientFactoryProvider.overrideWithValue(clients),
          // Shaped like the real factory: it is computed again whenever the
          // authorization lands, and it hands out a factory only once this
          // device holds a client that was built after the retirement.
          audioRoomCallFactoryProvider.overrideWith((ref) {
            final authorized =
                ref.watch(streamVideoAuthorizationProvider).value ==
                StreamVideoSessionAuthorization.authorized;
            if (!authorized) return null;
            ref.watch(streamVideoSdkSessionProvider);
            return clients.createCalls >= 2 ? calls : null;
          }),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: StreamVoiceRoomPage(
              autoConnect: true,
              inline: true,
              target: _target('loop-daily'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已加入，语音连接失败'), findsOneWidget);
    expect(find.text('重试会话'), findsOneWidget);
    expect(source.tokenCalls, 1);
    expect(clients.createCalls, 1);
    expect(calls.createCalls, 0);

    await tester.tap(
      find.byKey(const ValueKey<String>('voiceroom-media-retry-session')),
    );
    await tester.pumpAndSettle();

    // A second attempt asks the backend again: a fresh identity, a fresh
    // token, a client built from it — and then a call this device has not
    // been refused on.
    expect(source.identityCalls, 2);
    expect(source.tokenCalls, 2);
    expect(clients.createCalls, 2);
    expect(calls.createCalls, 1);
    expect(handle.joinCalls, 1);
    expect(find.text('Official CallState view'), findsOneWidget);
    expect(find.text('重试会话'), findsNothing);
  });

  testWidgets(
    'R5-1: 「重试会话」 is the page own refresh when the page owns the room',
    (tester) async {
      // Inside the LOOP voice room page the room is read by the page, so the
      // retry is that page's refresh — the same three steps 「重新连接语音」
      // takes — and not a second, partial one beside it.
      final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
      final calls = _RecordingAudioRoomCallFactory(handle);
      var refreshes = 0;
      late final ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          streamVideoPrincipalKeyProvider.overrideWithValue('principal-a'),
          streamVideoAuthorizationProvider.overrideWith(
            (ref) async => StreamVideoSessionAuthorization.authorized,
          ),
          audioRoomCallFactoryProvider.overrideWith(
            (ref) => refreshes == 0 ? null : calls,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: StreamVoiceRoomPage(
                autoConnect: true,
                inline: true,
                target: _target('loop-daily'),
                onReconnectRequested: () async {
                  refreshes += 1;
                  container.invalidate(audioRoomCallFactoryProvider);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已加入，语音连接失败'), findsOneWidget);
      expect(calls.createCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-media-retry-session')),
      );
      await tester.pumpAndSettle();

      expect(refreshes, 1);
      expect(calls.createCalls, 1);
      expect(handle.joinCalls, 1);
      expect(find.text('Official CallState view'), findsOneWidget);
    },
  );

  testWidgets('R6-1: a stopped call comes back as a lobby with a way in', (
    tester,
  ) async {
    // Four and a half minutes without a network: the badge went from 「重连中」
    // to a red 「已断开」 and stayed there, with the whole screen still the
    // call view — a surface whose only controls are the microphone and the
    // hang-up. The one way back was to leave the page and come in again from
    // the banner. A call nobody is putting back is now taken down, and the
    // lobby that returns asks the backend for a room, a token and a call of
    // its own.
    final source = _RecordingVideoSource(
      identity: const StreamVideoIdentity(userId: 'stream-user-a'),
    );
    final clients = _RecordingVideoClientFactory();
    final factory = _SequencedAudioRoomCallFactory(<_RecordingAudioRoomCall>[
      _RecordingAudioRoomCall(roomId: 'loop-daily'),
      _RecordingAudioRoomCall(roomId: 'loop-daily'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_videoConfig()),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          streamVideoSessionSourceProvider.overrideWithValue(source),
          streamVideoClientFactoryProvider.overrideWithValue(clients),
          audioRoomCallFactoryProvider.overrideWith((ref) {
            final authorized =
                ref.watch(streamVideoAuthorizationProvider).value ==
                StreamVideoSessionAuthorization.authorized;
            if (!authorized) return null;
            ref.watch(streamVideoSdkSessionProvider);
            return factory;
          }),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: StreamVoiceRoomPage(
              autoConnect: true,
              inline: true,
              target: _target('loop-daily'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(source.tokenCalls, 1);
    expect(factory.createCalls, 1);

    // The SDK is putting the connection back on its own. Nothing is collapsed
    // while it does: a retry in progress is not a failure, and the reader kept
    // the audio back without touching anything on the review device.
    await tester.tap(find.byKey(const Key('fake-media-reconnecting')));
    await tester.pumpAndSettle();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
      findsNothing,
    );
    expect(factory.handles.first.leaveCalls, 0);

    await tester.tap(find.byKey(const Key('fake-media-disconnected')));
    await tester.pumpAndSettle();

    // The dead call is retired once — the handle's own leave is single-flight,
    // so a call the SDK already took down is not left a second time — and the
    // membership is untouched.
    expect(find.text('Official CallState view'), findsNothing);
    expect(find.text('语音已断开'), findsOneWidget);
    expect(factory.handles.first.leaveCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
    );
    await tester.pumpAndSettle();

    // A second identity, a second token, a second client, and a call this
    // device has not been disconnected from.
    expect(source.identityCalls, 2);
    expect(source.tokenCalls, 2);
    expect(clients.createCalls, 2);
    expect(factory.createCalls, 2);
    expect(factory.handles.last.joinCalls, 1);
    expect(find.text('Official CallState view'), findsOneWidget);
  });

  testWidgets('the connection note follows the part LOOP granted', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(
        factory: factory,
        target: _target('loop-daily'),
        autoConnect: true,
        viewerRole: AudioRoomViewerRole.host,
      ),
    );
    await tester.pump();

    expect(find.textContaining('你是主持人'), findsOneWidget);
    expect(find.textContaining('结束房间'), findsOneWidget);
    expect(find.textContaining('你以听众身份静音进入'), findsNothing);
  });

  test('a refusal is classified by what the provider answered', () {
    expect(
      AudioRoomJoinRefusalMapping.fromDetail(
        'Missing permission join-backstage',
      ),
      AudioRoomJoinRefusal.permission,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail('ApiException 403: forbidden'),
      AudioRoomJoinRefusal.permission,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail('token is expired'),
      AudioRoomJoinRefusal.session,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail('call not found'),
      AudioRoomJoinRefusal.roomUnavailable,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail('connection timed out'),
      AudioRoomJoinRefusal.network,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail('provider-secret-detail'),
      AudioRoomJoinRefusal.unknown,
    );
    expect(
      AudioRoomJoinRefusalMapping.fromDetail(null),
      AudioRoomJoinRefusal.unknown,
    );
  });

  test('every refusal has a sentence of its own', () {
    final sentences = <String>{
      for (final refusal in AudioRoomJoinRefusal.values)
        audioRoomJoinRefusalText(refusal),
    };
    expect(sentences.length, AudioRoomJoinRefusal.values.length);
    // Each of the three parts gets its own note, and only the host's names
    // the control a host actually has.
    expect(audioRoomConnectionNote(AudioRoomViewerRole.host), contains('结束房间'));
    expect(
      audioRoomConnectionNote(AudioRoomViewerRole.speaker),
      contains('你是发言人'),
    );
    expect(audioRoomConnectionNote(null), contains('听众'));
  });

  testWidgets('disposing during join retires late Call results', (
    tester,
  ) async {
    final joinGate = Completer<void>();
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinFuture: joinGate.future,
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(handle.suspendAudioCalls, 1);
    expect(handle.leaveCalls, 1);

    joinGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Official CallState view'), findsNothing);
    expect(handle.leaveCalls, 1);
  });

  testWidgets(
    'fast resume waits for explicit background mute and Call retirement',
    (tester) async {
      final retirementGate = Completer<void>();
      final handle = _RecordingAudioRoomCall(
        roomId: 'loop-daily',
        activeRemovalFuture: retirementGate.future,
      );
      final factory = _RecordingAudioRoomCallFactory(handle);
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });

      await tester.pumpWidget(
        _readyPage(factory: factory, target: _target('loop-daily')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接语音'));
      await tester.pumpAndSettle();
      expect(find.text('Official CallState view'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(handle.backgroundRetirementCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 1);
      expect(handle.leaveCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('Official CallState view'), findsNothing);
      expect(find.text('语音已暂停'), findsOneWidget);
      expect(find.text('语音可以连接'), findsNothing);
      expect(factory.createCalls, 1);
      expect(handle.joinCalls, 1);

      retirementGate.complete();
      await tester.pumpAndSettle();

      expect(handle.backgroundMicrophoneDisableCalls, 2);
      expect(find.text('语音可以连接'), findsOneWidget);
      expect(factory.createCalls, 1);
      expect(handle.joinCalls, 1);
    },
  );

  testWidgets('failed background retirement keeps resumed join fail-closed', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      retirementError: StateError('provider-retirement-detail'),
      retirementFailures: 1,
    );
    final factory = _RecordingAudioRoomCallFactory(handle);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(handle.backgroundRetirementCalls, 1);
    expect(find.text('上一次通话没有收尾'), findsOneWidget);
    expect(find.text('连接语音'), findsOneWidget);
    final joinButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '连接语音'),
    );
    expect(joinButton.onPressed, isNull);
    expect(find.textContaining('provider-retirement-detail'), findsNothing);
    expect(factory.createCalls, 1);
    expect(handle.joinCalls, 1);

    await tester.tap(find.text('重试收尾'));
    await tester.pumpAndSettle();

    expect(handle.leaveCalls, 2);
    expect(find.text('语音可以连接'), findsOneWidget);
    expect(find.text('上一次通话没有收尾'), findsNothing);
  });

  testWidgets('background cleanup preempts stuck Speak and native suspension', (
    tester,
  ) async {
    final microphoneGate = Completer<void>();
    final suspendGate = Completer<void>();
    final activeRemovalGate = Completer<void>();
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      microphoneEnableFuture: microphoneGate.future,
      suspendAudioFuture: suspendGate.future,
      activeRemovalFuture: activeRemovalGate.future,
    );
    final factory = _RecordingAudioRoomCallFactory(handle);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-speak')));
    await tester.pump();

    expect(handle.microphoneCommandLog, <String>['enable:start']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(handle.suspendAudioCalls, 1);
    expect(handle.backgroundMicrophoneDisableCalls, 1);
    expect(handle.leaveCalls, 1);
    expect(find.text('语音已暂停'), findsOneWidget);

    activeRemovalGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('语音已暂停'), findsOneWidget);
    expect(find.text('语音可以连接'), findsNothing);
    expect(handle.backgroundMicrophoneDisableCalls, 1);

    microphoneGate.complete();
    suspendGate.complete();
    await tester.pumpAndSettle();

    expect(handle.microphoneCommandLog, <String>[
      'enable:start',
      'disable',
      'enable:end',
      'disable',
    ]);
    expect(handle.leaveCalls, 1);
    expect(find.text('语音可以连接'), findsOneWidget);
  });

  testWidgets(
    'manual leave waits for active Call removal and stays single-flight',
    (tester) async {
      final leaveGate = Completer<void>();
      final handle = _RecordingAudioRoomCall(
        roomId: 'loop-daily',
        activeRemovalFuture: leaveGate.future,
      );
      final factory = _RecordingAudioRoomCallFactory(handle);

      await tester.pumpWidget(
        _readyPage(factory: factory, target: _target('loop-daily')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接语音'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-leave-room')));
      await tester.tap(find.byKey(const Key('fake-leave-room')));
      await tester.pump();

      expect(handle.leaveCalls, 1);
      expect(handle.suspendAudioCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 1);
      expect(find.text('Official CallState view'), findsOneWidget);
      expect(find.text('语音可以连接'), findsNothing);

      leaveGate.complete();
      await tester.pumpAndSettle();

      expect(handle.leaveCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 2);
      expect(find.text('语音可以连接'), findsOneWidget);
    },
  );

  testWidgets(
    'route dispose starts leave despite stuck Speak and native suspension',
    (tester) async {
      final microphoneGate = Completer<void>();
      final suspendGate = Completer<void>();
      final activeRemovalGate = Completer<void>();
      final handle = _RecordingAudioRoomCall(
        roomId: 'loop-daily',
        microphoneEnableFuture: microphoneGate.future,
        suspendAudioFuture: suspendGate.future,
        activeRemovalFuture: activeRemovalGate.future,
      );
      final factory = _RecordingAudioRoomCallFactory(handle);

      await tester.pumpWidget(
        _readyPage(factory: factory, target: _target('loop-daily')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('连接语音'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-speak')));
      await tester.pump();

      expect(handle.microphoneCommandLog, <String>['enable:start']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(handle.suspendAudioCalls, 1);
      expect(handle.leaveCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 1);

      activeRemovalGate.complete();
      microphoneGate.complete();
      suspendGate.complete();
      await tester.pumpAndSettle();

      expect(handle.leaveCalls, 1);
      expect(handle.microphoneCommandLog, <String>[
        'enable:start',
        'disable',
        'enable:end',
        'disable',
      ]);
    },
  );

  testWidgets('inactive permission transition does not retire the Call', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
    final factory = _RecordingAudioRoomCallFactory(handle);
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(handle.backgroundRetirementCalls, 0);
    expect(handle.leaveCalls, 0);
    expect(find.text('Official CallState view'), findsOneWidget);
  });

  testWidgets('failed leave removes Speak but keeps a Mute cleanup action', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      retirementError: StateError('provider-retirement-detail'),
      retirementFailures: 1,
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(factory: factory, target: _target('loop-daily')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('连接语音'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-speak')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fake-leave-room')));
    await tester.pumpAndSettle();

    expect(find.text('Retirement started'), findsOneWidget);
    expect(find.byKey(const Key('fake-speak')), findsNothing);
    expect(find.byKey(const Key('fake-mute')), findsOneWidget);
    expect(find.byKey(const Key('fake-leave-room')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fake-mute')));
    await tester.pump();

    expect(handle.backgroundMicrophoneDisableCalls, 2);
  });

  testWidgets('an authorized room connects without a second tap', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(
        factory: factory,
        target: _target('loop-daily'),
        autoConnect: true,
      ),
    );
    await tester.pumpAndSettle();

    // The member was already let in: hearing the room is not a second
    // decision, so there is no button asking for one.
    expect(find.text('连接语音'), findsNothing);
    expect(factory.createCalls, 1);
    expect(handle.joinCalls, 1);
    expect(find.text('Official CallState view'), findsOneWidget);
  });

  testWidgets('a failed automatic connection waits to be asked again', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(
      roomId: 'loop-daily',
      joinError: StateError('provider-secret-detail'),
    );
    final factory = _RecordingAudioRoomCallFactory(handle);

    await tester.pumpWidget(
      _readyPage(
        factory: factory,
        target: _target('loop-daily'),
        autoConnect: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('已加入，语音连接失败'), findsOneWidget);
    expect(find.textContaining('provider-secret-detail'), findsNothing);
    // A room that is ready again must not retry on its own: that would be an
    // unbounded reconnect loop behind a reader who is told it failed.
    expect(handle.joinCalls, 1);
    expect(handle.leaveCalls, 1);
    expect(find.text('重新连接语音'), findsOneWidget);
    expect(find.text('Official CallState view'), findsNothing);
  });

  testWidgets('the page exit takes the call down and keeps it down', (
    tester,
  ) async {
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');
    final factory = _RecordingAudioRoomCallFactory(handle);
    final link = VoiceMediaLink();

    await tester.pumpWidget(
      _readyPage(
        factory: factory,
        target: _target('loop-daily'),
        autoConnect: true,
        link: link,
      ),
    );
    await tester.pumpAndSettle();
    expect(link.isAttached, isTrue);
    expect(handle.joinCalls, 1);

    expect(await link.disconnect(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // The LOOP leave runs next: a surface that reconnected in that window
    // would put a call back into a room this account is leaving.
    expect(handle.leaveCalls, 1);
    expect(handle.joinCalls, 1);
    // R7-1: and what the window says is the reader's own decision, not a
    // dropped connection with a button that undoes it.
    expect(find.text('正在离开语音房…'), findsOneWidget);
    expect(find.text('语音已断开'), findsNothing);
    expect(find.text('重新连接语音'), findsNothing);

    // The page reports the LOOP half back. On a leave that went through this
    // surface is already gone; what this stands for is the one LOOP refused,
    // which leaves the account a member of a room it cannot hear.
    link.exitSettled();
    await tester.pumpAndSettle();
    expect(handle.joinCalls, 1);
    expect(find.text('正在离开语音房…'), findsNothing);
    expect(find.text('语音已断开'), findsOneWidget);
    expect(find.text('重新连接语音'), findsOneWidget);
  });

  test('one Call accepts only one Speak request', () async {
    final handle = _RecordingAudioRoomCall(roomId: 'loop-daily');

    expect(await handle.setMicrophoneEnabled(enabled: true), isTrue);
    expect(await handle.setMicrophoneEnabled(enabled: true), isFalse);
    expect(handle.microphoneCommandLog, <String>['enable:start', 'enable:end']);
  });

  test(
    'failed leave still permits Mute but permanently rejects Speak',
    () async {
      final handle = _RecordingAudioRoomCall(
        roomId: 'loop-daily',
        retirementError: StateError('provider-retirement-detail'),
        retirementFailures: 1,
      );

      await expectLater(handle.leave(), throwsA(isA<StateError>()));

      expect(await handle.setMicrophoneEnabled(enabled: true), isFalse);
      expect(await handle.setMicrophoneEnabled(enabled: false), isTrue);
      expect(handle.backgroundMicrophoneDisableCalls, 2);
    },
  );
}

Widget _readyPage({
  required AudioRoomCallFactory factory,
  required AudioRoomTarget target,
  bool autoConnect = false,
  VoiceMediaLink? link,
  AudioRoomViewerRole? viewerRole,
  Future<void> Function()? onReconnectRequested,
}) {
  return ProviderScope(
    overrides: [
      streamVideoPrincipalKeyProvider.overrideWithValue('principal-a'),
      streamVideoAuthorizationProvider.overrideWith(
        (ref) async => StreamVideoSessionAuthorization.authorized,
      ),
      audioRoomTargetProvider.overrideWith((ref) async => target),
      audioRoomCallFactoryProvider.overrideWithValue(factory),
    ],
    child: MaterialApp(
      theme: LoopTheme.dark,
      // The product only connects on its own inside the LOOP voice room
      // page, so the automatic surface is mounted the way that page mounts
      // it: one section, no page of its own.
      home: autoConnect
          ? Scaffold(
              body: StreamVoiceRoomPage(
                autoConnect: true,
                inline: true,
                link: link,
                viewerRole: viewerRole,
                onReconnectRequested: onReconnectRequested,
              ),
            )
          : const StreamVoiceRoomPage(),
    ),
  );
}

AudioRoomTarget _target(String roomId) {
  return AudioRoomTarget.tryParse(
    callType: AudioRoomTarget.callType,
    roomId: roomId,
  )!;
}

/// Hands out one call per attempt, so a second attempt is visibly not the
/// first one repeated.
final class _SequencedAudioRoomCallFactory implements AudioRoomCallFactory {
  _SequencedAudioRoomCallFactory(this.handles);

  final List<_RecordingAudioRoomCall> handles;
  int createCalls = 0;

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) {
    final handle = handles[createCalls.clamp(0, handles.length - 1)];
    createCalls += 1;
    return handle;
  }
}

final class _RecordingAudioRoomCallFactory implements AudioRoomCallFactory {
  _RecordingAudioRoomCallFactory(this.handle);

  final AudioRoomCallHandle handle;
  int createCalls = 0;

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) {
    createCalls += 1;
    return handle;
  }
}

final class _RecordingAudioRoomCall implements AudioRoomCallHandle {
  _RecordingAudioRoomCall({
    required this.roomId,
    this.joinFuture,
    this.joinError,
    this.activeRemovalFuture,
    this.retirementError,
    this.retirementFailures = 0,
    this.microphoneEnableFuture,
    this.suspendAudioFuture,
  }) {
    _commands = AudioRoomCallCommandCoordinator(
      _setProviderMicrophone,
      _providerLeave,
      _suspendAudio,
    );
  }

  @override
  final String roomId;
  final Future<void>? joinFuture;
  final Object? joinError;
  final Future<void>? activeRemovalFuture;
  final Object? retirementError;
  final Future<void>? microphoneEnableFuture;
  final Future<void>? suspendAudioFuture;
  late final AudioRoomCallCommandCoordinator _commands;
  int retirementFailures;
  int joinCalls = 0;
  int leaveCalls = 0;
  int backgroundRetirementCalls = 0;
  int backgroundMicrophoneDisableCalls = 0;
  int suspendAudioCalls = 0;
  final List<String> microphoneCommandLog = <String>[];

  @override
  bool get retirementStarted => _commands.retirementStarted;

  @override
  Future<void> joinMuted() async {
    joinCalls += 1;
    final error = joinError;
    if (error != null) throw error;
    await joinFuture;
  }

  @override
  Future<bool> setMicrophoneEnabled({required bool enabled}) {
    return _commands.setMicrophoneEnabled(enabled: enabled);
  }

  Future<bool> _setProviderMicrophone(bool enabled) async {
    if (enabled) {
      microphoneCommandLog.add('enable:start');
      await microphoneEnableFuture;
      microphoneCommandLog.add('enable:end');
    } else {
      backgroundMicrophoneDisableCalls += 1;
      microphoneCommandLog.add('disable');
    }
    return true;
  }

  Future<void> _suspendAudio() async {
    suspendAudioCalls += 1;
    await suspendAudioFuture;
  }

  @override
  Future<void> retireForBackground() {
    backgroundRetirementCalls += 1;
    return _commands.retire();
  }

  Future<void> _providerLeave() async {
    leaveCalls += 1;
    final error = retirementError;
    if (error != null && retirementFailures > 0) {
      retirementFailures -= 1;
      throw error;
    }
    await activeRemovalFuture;
  }

  @override
  Future<void> leave() {
    return _commands.retire();
  }

  void _reportStatus(CallStatus status, VoidCallback? onDisconnected) {
    if (StreamCallDisconnectPolicy.collapses(
      status: status,
      retirementStarted: retirementStarted,
    )) {
      onDisconnected?.call();
    }
  }

  @override
  Widget buildForeground({
    required Future<void> Function() onLeaveRequested,
    bool inline = false,
    Future<void> Function()? onMicrophoneEnabled,
    void Function({
      required AudioRoomLivePhase phase,
      required int? participantCount,
    })?
    onPresence,
    VoidCallback? onDisconnected,
  }) {
    return Column(
      children: <Widget>[
        const Text('Official CallState view'),
        // Stands in for the official call state moving on its own. Both
        // buttons hand the status to the same policy the real view uses, so
        // the page is driven by a status stream and not by a callback the
        // test decided to fire.
        TextButton(
          key: const Key('fake-media-reconnecting'),
          onPressed: () =>
              _reportStatus(CallStatus.reconnecting(2), onDisconnected),
          child: const Text('Reconnecting fake'),
        ),
        TextButton(
          key: const Key('fake-media-disconnected'),
          onPressed: () => _reportStatus(
            CallStatus.disconnected(DisconnectReason.reconnectionFailed()),
            onDisconnected,
          ),
          child: const Text('Disconnected fake'),
        ),
        if (retirementStarted)
          const Text('Retirement started')
        else
          TextButton(
            key: const Key('fake-speak'),
            onPressed: () => unawaited(setMicrophoneEnabled(enabled: true)),
            child: const Text('Speak fake'),
          ),
        if (retirementStarted)
          TextButton(
            key: const Key('fake-mute'),
            onPressed: () => unawaited(setMicrophoneEnabled(enabled: false)),
            child: const Text('Mute fake'),
          ),
        TextButton(
          key: const Key('fake-leave-room'),
          onPressed: () =>
              unawaited(onLeaveRequested().catchError((Object _) {})),
          child: const Text('Leave fake room'),
        ),
      ],
    );
  }
}

AppConfig _videoConfig() {
  return AppConfig(
    privyAppId: 'privy-app',
    privyAppClientId: 'privy-client',
    streamApiKey: 'public-stream-api-key',
    backendBaseUrl: '',
    firebaseConfigured: false,
  );
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

/// Counts what a retry actually asked the backend for.
final class _RecordingVideoSource implements StreamVideoSessionSource {
  _RecordingVideoSource({this.identity});

  final StreamVideoIdentity? identity;
  int identityCalls = 0;
  int tokenCalls = 0;

  @override
  Future<StreamVideoIdentity?> loadIdentity() async {
    identityCalls += 1;
    return identity;
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenCalls += 1;
    return 'short-token';
  }
}

final class _RecordingVideoClientFactory implements StreamVideoClientFactory {
  int createCalls = 0;

  @override
  StreamVideoClientPort create({
    required String apiKey,
    required StreamVideoIdentity identity,
    required String initialToken,
    required Future<String> Function(String userId) tokenProvider,
  }) {
    createCalls += 1;
    return _RecordingVideoClient(userId: identity.userId);
  }
}

final class _RecordingVideoClient implements StreamVideoClientPort {
  _RecordingVideoClient({required this.userId});

  @override
  final String userId;

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}
