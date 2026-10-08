import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/features/chat/calls/active_voice_media.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
import 'package:loop_mobile/features/chat/calls/stream_foreground_call_view.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/integrations/device/voice_room_back_guard.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'support/community_test_harness.dart';
import 'support/communication_test_harness.dart';

/// S101 · decision 0106: the four acceptance findings on the voice room.
void main() {
  group('0106 · 3 automatic reconnection', () {
    test('backs off 1 s, 2 s, 4 s … and never waits more than 30 s', () {
      expect(
        List<int>.generate(8, (attempt) {
          return audioRoomRecoveryDelay(attempt).inSeconds;
        }),
        <int>[1, 2, 4, 8, 16, 30, 30, 30],
      );
    });

    testWidgets('a dropped call is joined again, backing off between '
        'attempts that fail', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      // The first call joins; the next two are refused; the fourth joins.
      final media = _Factory(joinFailures: <int>{1, 2});
      final radio = _Radio();
      await _pumpRoom(tester, voice: voice, media: media, radio: radio);
      await _closePage(tester);
      expect(media.handles, hasLength(1));

      media.handles.first.drop();
      await tester.pump();
      expect(_recovery(tester)?.reconnecting, isTrue);
      expect(media.handles.first.leaveCalls, 1);

      // First wait: 1 s.
      await tester.pump(const Duration(milliseconds: 900));
      expect(media.handles, hasLength(1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(media.handles, hasLength(2));
      expect(media.handles[1].joinCalls, 1);
      expect(_recovery(tester)?.attempt, 1);

      // Second wait: 2 s after the attempt at t = 1.0 s.
      await tester.pump(const Duration(milliseconds: 1700));
      expect(media.handles, hasLength(2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(media.handles, hasLength(3));
      expect(_recovery(tester)?.attempt, 2);

      // Third wait: 4 s after the attempt at t = 3.0 s, and this one joins.
      await tester.pump(const Duration(milliseconds: 3700));
      expect(media.handles, hasLength(3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(media.handles, hasLength(4));
      expect(media.handles.last.joinCalls, 1);
      expect(_recovery(tester), isNull);
      expect(_held(tester), same(media.handles.last));
      // The failed calls were taken down, and the membership never moved.
      expect(media.handles[1].leaveCalls, 1);
      expect(media.handles[2].leaveCalls, 1);
      expect(voice.commands, isNot(contains('leave')));
      // The room was read before every attempt.
      expect(voice.commands.where((c) => c == 'load'), hasLength(3));
    });

    testWidgets('the network coming back cuts the wait short', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory(joinFailures: <int>{1});
      final radio = _Radio();
      await _pumpRoom(tester, voice: voice, media: media, radio: radio);
      await _closePage(tester);

      media.handles.first.drop();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(media.handles, hasLength(2));
      // Now waiting 2 s; the radio says the network is back.
      radio.restore();
      await tester.pump();
      await tester.pump();
      expect(media.handles, hasLength(3));
      expect(_held(tester), same(media.handles.last));
      expect(_recovery(tester), isNull);
    });

    testWidgets('leaving the room stops it for good', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory(joinFailures: <int>{1, 2, 3, 4, 5});
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _closePage(tester);

      media.handles.first.drop();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(media.handles, hasLength(2));

      // 离开 from the strip, while the recovery waits.
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave-confirm')),
      );
      await tester.pump();
      await tester.pump();
      expect(voice.commands, contains('leave'));
      expect(_recovery(tester), isNull);

      await tester.pump(const Duration(minutes: 5));
      expect(media.handles, hasLength(2));
      expect(_held(tester), isNull);
    });

    testWidgets('a room the host ended is not joined again', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _closePage(tester);

      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.listener,
        state: VoiceRoomState.ended,
      );
      media.handles.first.drop();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(media.handles, hasLength(1));
      expect(_recovery(tester), isNull);
      expect(_session(tester), isNull);
      expect(find.text('房间已结束 · 主持人已经结束这个语音房'), findsOneWidget);
    });

    testWidgets('an account that is no longer in the room is not put back', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _closePage(tester);

      voice.loadSnapshot = testVoiceRoomSnapshot(role: null);
      media.handles.first.drop();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(media.handles, hasLength(1));
      expect(_recovery(tester), isNull);
      expect(_session(tester), isNull);
    });

    testWidgets('a read that could not finish is one more attempt, not an '
        'answer', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _closePage(tester);

      voice.failure = CommunityFailureKind.offline;
      media.handles.first.drop();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(media.handles, hasLength(1));
      expect(_recovery(tester)?.attempt, 1);
      expect(_session(tester), isNotNull);

      voice.failure = null;
      await tester.pump(const Duration(milliseconds: 2100));
      expect(media.handles, hasLength(2));
      expect(_recovery(tester), isNull);
    });

    testWidgets('a speaker comes back muted and is told so', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());

      // The speaker is talking when the network goes.
      await _tapInPage(tester, 'fake-mic-open');
      expect(media.handles.first.microphoneOpen, isTrue);
      await _tapInPage(tester, 'fake-drop-view');
      await tester.pump();
      await tester.pump();

      // The page says what the app is doing; nothing to press.
      expect(find.text('语音连接中断，正在自动重连'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-reconnect')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(media.handles, hasLength(2));
      // A new call, muted: nothing opened the microphone on the reader's
      // behalf, and the room says the microphone is theirs to open.
      expect(media.handles.last.microphoneCalls, 0);
      expect(media.handles.last.microphoneOpen, isFalse);
      final note = find.byKey(
        const ValueKey<String>('voiceroom-media-restored'),
      );
      await scrollToCommunitySection(tester, note);
      expect(note, findsOneWidget);
      expect(find.text(audioRoomRestoredMicrophoneNote), findsOneWidget);

      await _tapInPage(tester, 'fake-mic-open');
      expect(note, findsNothing);
    });

    testWidgets('a listener comes back with no line about a microphone', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _tapInPage(tester, 'fake-drop-view');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      expect(media.handles, hasLength(2));
      expect(
        find.byKey(const ValueKey<String>('voiceroom-media-restored')),
        findsNothing,
      );
    });
  });

  group('0106 · 1 Android root back', () {
    testWidgets('the guard speaks to MainActivity on Android only', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel(voiceRoomBackChannelName),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel(voiceRoomBackChannelName),
          null,
        ),
      );
      const guard = MethodChannelVoiceRoomBackGuard();

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await guard.setHoldsVoiceCall(true);
      await guard.setHoldsVoiceCall(false);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await guard.setHoldsVoiceCall(true);
      debugDefaultTargetPlatformOverride = null;

      expect(calls.map((call) => call.method), <String>[
        'setHoldsVoiceCall',
        'setHoldsVoiceCall',
      ]);
      expect(calls.map((call) => call.arguments), <Object?>[true, false]);
    });

    testWidgets('the root back keeps LOOP only while a call is held or being '
        'put back', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory(joinFailures: <int>{1});
      final back = _BackGuard();
      await _pumpRoom(
        tester,
        voice: voice,
        media: media,
        radio: _Radio(),
        back: back,
      );
      // Held: the back that has nothing left to pop goes to the background.
      expect(back.states, <bool>[true]);

      // Dropped and being put back: still guarded, through a failed attempt
      // and the new call that joins.
      await _closePage(tester);
      media.handles.first.drop();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 2100));
      expect(media.handles, hasLength(3));
      expect(_held(tester), same(media.handles.last));
      expect(back.states, <bool>[true]);

      // 离开: nothing to keep any more, and the back finishes LOOP again.
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-banner-leave-confirm')),
      );
      await tester.pump();
      await tester.pump();
      expect(back.states, <bool>[true, false]);
    });

    testWidgets('a room that ended hands the back back', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      final back = _BackGuard();
      await _pumpRoom(
        tester,
        voice: voice,
        media: media,
        radio: _Radio(),
        back: back,
      );
      await _closePage(tester);
      voice.loadSnapshot = testVoiceRoomSnapshot(
        role: VoiceRoomRole.listener,
        state: VoiceRoomState.ended,
      );
      media.handles.first.drop();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(back.states, <bool>[true, false]);
    });
  });

  group('0106 · 1 background', () {
    testWidgets('a room page in the background keeps its call', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
      );
      final media = _Factory();
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());
      await _tapInPage(tester, 'fake-mic-open');

      for (final state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pump(const Duration(minutes: 3));

      // The call is not retired and the microphone is not closed.
      expect(media.handles, hasLength(1));
      expect(media.handles.single.leaveCalls, 0);
      expect(media.handles.single.microphoneOpen, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(media.handles, hasLength(1));
      expect(find.text('语音已连接（测试）'), findsOneWidget);
      expect(find.text('语音已暂停'), findsNothing);
    });
  });

  group('0106 · 2 output route', () {
    test('the control reads the route back and asks for the other one', () {
      const speaker = AudioRoomOutputRoute(AudioRoomOutputKind.speaker);
      const earpiece = AudioRoomOutputRoute(AudioRoomOutputKind.earpiece);
      const headset = AudioRoomOutputRoute(
        AudioRoomOutputKind.external,
        label: 'AirPods Pro',
      );
      expect(audioRoomOutputLabel(speaker), '扬声器');
      expect(audioRoomOutputLabel(earpiece), '听筒');
      expect(audioRoomOutputLabel(headset), 'AirPods Pro');
      expect(audioRoomOutputLabel(null), '声音输出');
      expect(
        audioRoomOutputToggle(
          current: speaker,
          preference: AudioRoomOutputPreference.speaker,
        ),
        AudioRoomOutputPreference.earpiece,
      );
      // The route the provider reports wins over the last choice.
      expect(
        audioRoomOutputToggle(
          current: earpiece,
          preference: AudioRoomOutputPreference.speaker,
        ),
        AudioRoomOutputPreference.speaker,
      );
      // With a headset connected there is nothing to toggle.
      expect(
        audioRoomOutputToggle(
          current: headset,
          preference: AudioRoomOutputPreference.speaker,
        ),
        isNull,
      );
    });

    test('provider devices read as the three routes', () {
      RtcMediaDevice device(String id, {String? group, String label = 'x'}) =>
          RtcMediaDevice(
            id: id,
            label: label,
            groupId: group,
            kind: RtcMediaDeviceKind.audioOutput,
          );
      expect(
        audioRoomOutputRouteOf(device('Speaker', group: 'Speaker'))?.kind,
        AudioRoomOutputKind.speaker,
      );
      expect(
        audioRoomOutputRouteOf(device('speaker'))?.kind,
        AudioRoomOutputKind.speaker,
      );
      expect(
        audioRoomOutputRouteOf(device('Built-In Receiver', group: 'Receiver'))
            ?.kind,
        AudioRoomOutputKind.earpiece,
      );
      expect(
        audioRoomOutputRouteOf(device('earpiece'))?.kind,
        AudioRoomOutputKind.earpiece,
      );
      final bluetooth = audioRoomOutputRouteOf(
        device('bluetooth', group: 'bluetooth', label: 'WH-1000XM5'),
      );
      expect(bluetooth?.kind, AudioRoomOutputKind.external);
      expect(bluetooth?.label, 'WH-1000XM5');
      expect(audioRoomOutputRouteOf(null), isNull);
    });

    testWidgets('the reader\'s choice is put on this call and the next', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
      );
      final media = _Factory();
      await _pumpRoom(tester, voice: voice, media: media, radio: _Radio());

      // Speaker by default, applied as soon as the call is held.
      expect(media.handles.single.outputs, <AudioRoomOutputPreference>[
        AudioRoomOutputPreference.speaker,
      ]);
      await _tapInPage(tester, 'fake-output-toggle');
      expect(
        media.handles.single.outputs.last,
        AudioRoomOutputPreference.earpiece,
      );

      // A call the recovery puts back is given the same route.
      await _tapInPage(tester, 'fake-drop-view');
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(media.handles, hasLength(2));
      expect(
        media.handles.last.outputs.first,
        AudioRoomOutputPreference.earpiece,
      );
    });
  });

  group('0106 · 4 voiceroom-full', () {
    testWidgets('lobby → full → lobby → community never leaves the call, '
        'even when the authorization answers again', (tester) async {
      final voice = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      final handles = <_Call>[];
      var factories = 0;
      await pumpCommunityPage(
        tester,
        const _CommunityThenRoom(),
        voiceRoom: voice,
        videoAuthorizationLoader: () async =>
            StreamVideoSessionAuthorization.authorized,
        // Shaped like production: every time the authorization answers, a
        // new factory object is built on the same client.
        audioRoomCallFactorySource: (ref) {
          final authorized =
              ref.watch(streamVideoAuthorizationProvider).value ==
              StreamVideoSessionAuthorization.authorized;
          factories += 1;
          return authorized ? _Factory.sharing(handles) : null;
        },
        overrides: [loopConnectivitySignalProvider.overrideWithValue(_Radio())],
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-room')));
      await tester.pumpAndSettle();
      expect(handles, hasLength(1));
      expect(handles.single.joinCalls, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-invite-open')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-full-screen')),
        findsOneWidget,
      );

      // The authorization answers again while the session view is on top:
      // a token refresh, a provider rebuilt on the way. Same client.
      final factoriesBefore = factories;
      _container(tester).invalidate(streamVideoAuthorizationProvider);
      await tester.pumpAndSettle();
      expect(factories, greaterThan(factoriesBefore));

      // Back to the lobby.
      Navigator.of(
        tester.element(
          find.byKey(const ValueKey<String>('voiceroom-full-screen')),
        ),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('voiceroom-screen')),
        findsOneWidget,
      );
      expect(handles, hasLength(1));
      expect(handles.single.leaveCalls, 0);
      expect(_held(tester), same(handles.single));

      // Into the session view and back once more.
      await tester.tap(
        find.byKey(const ValueKey<String>('voiceroom-invite-open')),
      );
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(
          find.byKey(const ValueKey<String>('voiceroom-full-screen')),
        ),
      ).pop();
      await tester.pumpAndSettle();

      // And back to the community page.
      Navigator.of(
        tester.element(find.byKey(const ValueKey<String>('voiceroom-screen'))),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('open-room')), findsOneWidget);
      expect(handles, hasLength(1));
      expect(handles.single.leaveCalls, 0);
      expect(_held(tester), same(handles.single));
      expect(voice.commands, isNot(contains('leave')));
    });

    // Decision 0115: the host reaches the queue through 邀请发言 in the
    // bottom bar; nobody else's bar has it.
    testWidgets('only the host is offered the session view', (tester) async {
      Future<bool> offered(VoiceRoomSnapshot snapshot) async {
        await pumpCommunityPage(
          tester,
          VoiceRoomScreen(communityId: testCommunityId, onOpenExpanded: (_) {}),
          voiceRoom: FakeVoiceRoomGateway(snapshot: snapshot),
        );
        return find
            .byKey(const ValueKey<String>('voiceroom-invite-open'))
            .evaluate()
            .isNotEmpty;
      }

      expect(
        await offered(testVoiceRoomSnapshot(role: VoiceRoomRole.listener)),
        isFalse,
      );
      expect(
        await offered(testVoiceRoomSnapshot(role: VoiceRoomRole.speaker)),
        isFalse,
      );
      expect(await offered(testVoiceRoomSnapshot(role: null)), isFalse);
      expect(
        await offered(
          testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
        ),
        isTrue,
      );
    });

    testWidgets('a listener who follows a link to the session view gets it', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-full-screen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Future<void> _pumpRoom(
  WidgetTester tester, {
  required FakeVoiceRoomGateway voice,
  required _Factory media,
  required _Radio radio,
  _BackGuard? back,
}) async {
  await pumpCommunityPage(
    tester,
    const _BannerAndRoom(),
    voiceRoom: voice,
    audioRoomCallFactory: media,
    overrides: [
      loopConnectivitySignalProvider.overrideWithValue(radio),
      if (back != null) voiceRoomBackGuardProvider.overrideWithValue(back),
    ],
  );
  expect(media.handles, hasLength(1));
}

Future<void> _closePage(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('harness-close')));
  await tester.pumpAndSettle();
}

Future<void> _tapInPage(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey<String>(key));
  await scrollToCommunitySection(tester, target);
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
  listen: false,
);

AudioRoomRecovery? _recovery(WidgetTester tester) =>
    _container(tester).read(audioRoomRecoveryProvider);

AudioRoomCallHandle? _held(WidgetTester tester) =>
    _container(tester).read(activeVoiceMediaProvider);

VoiceRoomSession? _session(WidgetTester tester) =>
    _container(tester).read(voiceRoomSessionProvider);

/// The shell strip above a room page that can be closed without tearing down
/// the scope that holds the call.
class _BannerAndRoom extends StatefulWidget {
  const _BannerAndRoom();

  @override
  State<_BannerAndRoom> createState() => _BannerAndRoomState();
}

class _BannerAndRoomState extends State<_BannerAndRoom> {
  var _open = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        VoiceRoomMinimizedBanner(onOpen: (_) {}),
        Expanded(
          child: _open
              ? const VoiceRoomScreen(communityId: testCommunityId)
              : const SizedBox.expand(),
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

/// A community page that opens the room, which opens the session view — the
/// same stack `context.push` builds in production.
class _CommunityThenRoom extends StatelessWidget {
  const _CommunityThenRoom();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey<String>('open-room'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (lobbyContext) => VoiceRoomScreen(
                communityId: testCommunityId,
                onBack: () => Navigator.of(lobbyContext).pop(),
                onOpenExpanded: (id) => Navigator.of(lobbyContext).push(
                  MaterialPageRoute<void>(
                    builder: (fullContext) => VoiceRoomScreen(
                      communityId: id,
                      expanded: true,
                      onBack: () => Navigator.of(fullContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('社区'),
        ),
      ),
    );
  }
}

/// Records what `MainActivity` would be told about the root back.
final class _BackGuard implements VoiceRoomBackGuard {
  final List<bool> states = <bool>[];

  @override
  Future<void> setHoldsVoiceCall(bool holds) async => states.add(holds);
}

/// The platform radio, told by the test when the network comes back.
final class _Radio implements LoopConnectivitySignal {
  final StreamController<void> _restored = StreamController<void>.broadcast();

  void restore() => _restored.add(null);

  @override
  Stream<void> get onRestored => _restored.stream;
}

/// Hands out calls; the ones whose index is in [joinFailures] are refused.
///
/// Two factories that share [handles] are the same factory, the way two
/// provider factories on one client are.
final class _Factory implements AudioRoomCallFactory {
  _Factory({this.joinFailures = const <int>{}}) : handles = <_Call>[];

  _Factory.sharing(this.handles) : joinFailures = const <int>{};

  final List<_Call> handles;
  final Set<int> joinFailures;

  @override
  AudioRoomCallHandle create(AudioRoomTarget target) {
    final handle = _Call(
      roomId: target.roomId,
      failsJoin: joinFailures.contains(handles.length),
    );
    handles.add(handle);
    return handle;
  }

  @override
  bool operator ==(Object other) =>
      other is _Factory && identical(other.handles, handles);

  @override
  int get hashCode => identityHashCode(handles);
}

final class _Call implements AudioRoomCallHandle {
  _Call({required this.roomId, required this.failsJoin});

  @override
  final String roomId;
  final bool failsJoin;
  int joinCalls = 0;
  int leaveCalls = 0;
  int microphoneCalls = 0;
  var _retired = false;
  final List<AudioRoomOutputPreference> outputs = <AudioRoomOutputPreference>[];

  final StreamController<AudioRoomCallReading> _readings =
      StreamController<AudioRoomCallReading>.broadcast();
  AudioRoomCallReading _reading = const AudioRoomCallReading(
    phase: AudioRoomLivePhase.connected,
    participantCount: 2,
  );

  @override
  AudioRoomCallReading get reading => _reading;

  @override
  Stream<AudioRoomCallReading> get readings => _readings.stream;

  @override
  Stream<AudioRoomRoomSignal> get roomSignals =>
      const Stream<AudioRoomRoomSignal>.empty();

  @override
  bool get retirementStarted => _retired;

  @override
  bool microphoneOpen = false;

  /// The provider gave up on this call, with no view on screen to say so.
  void drop() {
    _reading = const AudioRoomCallReading(
      phase: AudioRoomLivePhase.disconnected,
      participantCount: null,
    );
    _readings.add(_reading);
  }

  @override
  Future<void> joinMuted() async {
    joinCalls += 1;
    if (failsJoin) {
      throw const AudioRoomCallFailure(
        AudioRoomCallFailureKind.join,
        refusal: AudioRoomJoinRefusal.network,
      );
    }
  }

  @override
  Future<AudioRoomMicrophoneOutcome> setMicrophoneEnabled({
    required bool enabled,
  }) async {
    microphoneCalls += 1;
    microphoneOpen = enabled;
    return const AudioRoomMicrophoneOutcome.opened();
  }

  @override
  Future<void> applyOutputPreference(
    AudioRoomOutputPreference preference,
  ) async {
    outputs.add(preference);
  }

  @override
  Future<void> leave() async {
    leaveCalls += 1;
    _retired = true;
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
    AudioRoomOutputPreference outputPreference =
        AudioRoomOutputPreference.speaker,
    ValueChanged<AudioRoomOutputPreference>? onOutputSelected,
  }) {
    return Column(
      children: <Widget>[
        const Text('语音已连接（测试）'),
        // The device opened the microphone; the page is told afterwards.
        TextButton(
          key: const ValueKey<String>('fake-mic-open'),
          onPressed: () async {
            microphoneCalls += 1;
            microphoneOpen = true;
            await onMicrophoneEnabled?.call();
          },
          child: const Text('开麦'),
        ),
        // The provider gave up on the call while the view is on screen,
        // through the same policy the official view applies.
        TextButton(
          key: const ValueKey<String>('fake-drop-view'),
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
        if (onOutputSelected != null)
          TextButton(
            key: const ValueKey<String>('fake-output-toggle'),
            onPressed: () => onOutputSelected(
              outputPreference == AudioRoomOutputPreference.speaker
                  ? AudioRoomOutputPreference.earpiece
                  : AudioRoomOutputPreference.speaker,
            ),
            child: Text('输出 ${outputPreference.name}'),
          ),
      ],
    );
  }
}
