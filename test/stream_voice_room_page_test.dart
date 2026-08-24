import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_call.dart';
import 'package:loop_mobile/features/chat/calls/audio_room_contract.dart';
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
        child: const MaterialApp(home: StreamVoiceRoomPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No authorized room assigned'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsNothing);
    expect(find.text('Connected'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join audio room'),
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

    expect(find.text('Audio room ready'), findsOneWidget);
    expect(find.text('Muted on entry'), findsOneWidget);
    expect(find.text('Permission when needed'), findsOneWidget);

    await tester.tap(find.text('Join audio room'));
    await tester.tap(find.text('Join audio room'));
    await tester.pump();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(factory.createCalls, 1);
    expect(handle.joinCalls, 1);
    expect(find.text('Join audio room'), findsNothing);

    joinGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Official CallState view'), findsOneWidget);
    expect(find.text('Audio room ready'), findsNothing);

    await tester.tap(find.byKey(const Key('fake-leave-room')));
    await tester.pumpAndSettle();

    expect(handle.leaveCalls, 1);
    expect(find.text('Audio room ready'), findsOneWidget);
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
    await tester.tap(find.text('Join audio room'));
    await tester.pumpAndSettle();

    expect(find.text('Join failed'), findsOneWidget);
    expect(
      find.text(
        'Could not join this audio room. Check room access and connection, then retry.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('provider-secret-detail'), findsNothing);
    expect(handle.leaveCalls, 1);
    expect(find.text('Official CallState view'), findsNothing);
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
    await tester.tap(find.text('Join audio room'));
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
      await tester.tap(find.text('Join audio room'));
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
      expect(find.text('Audio room paused'), findsOneWidget);
      expect(find.text('Audio room ready'), findsNothing);
      expect(factory.createCalls, 1);
      expect(handle.joinCalls, 1);

      retirementGate.complete();
      await tester.pumpAndSettle();

      expect(handle.backgroundMicrophoneDisableCalls, 2);
      expect(find.text('Audio room ready'), findsOneWidget);
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
    await tester.tap(find.text('Join audio room'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(handle.backgroundRetirementCalls, 1);
    expect(find.text('Room cleanup incomplete'), findsOneWidget);
    expect(find.text('Join audio room'), findsOneWidget);
    final joinButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Join audio room'),
    );
    expect(joinButton.onPressed, isNull);
    expect(find.textContaining('provider-retirement-detail'), findsNothing);
    expect(factory.createCalls, 1);
    expect(handle.joinCalls, 1);

    await tester.tap(find.text('Retry cleanup'));
    await tester.pumpAndSettle();

    expect(handle.leaveCalls, 2);
    expect(find.text('Audio room ready'), findsOneWidget);
    expect(find.text('Room cleanup incomplete'), findsNothing);
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
    await tester.tap(find.text('Join audio room'));
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
    expect(find.text('Audio room paused'), findsOneWidget);

    activeRemovalGate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Audio room paused'), findsOneWidget);
    expect(find.text('Audio room ready'), findsNothing);
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
    expect(find.text('Audio room ready'), findsOneWidget);
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
      await tester.tap(find.text('Join audio room'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fake-leave-room')));
      await tester.tap(find.byKey(const Key('fake-leave-room')));
      await tester.pump();

      expect(handle.leaveCalls, 1);
      expect(handle.suspendAudioCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 1);
      expect(find.text('Official CallState view'), findsOneWidget);
      expect(find.text('Audio room ready'), findsNothing);

      leaveGate.complete();
      await tester.pumpAndSettle();

      expect(handle.leaveCalls, 1);
      expect(handle.backgroundMicrophoneDisableCalls, 2);
      expect(find.text('Audio room ready'), findsOneWidget);
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
      await tester.tap(find.text('Join audio room'));
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
    await tester.tap(find.text('Join audio room'));
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
    await tester.tap(find.text('Join audio room'));
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
    child: const MaterialApp(home: StreamVoiceRoomPage()),
  );
}

AudioRoomTarget _target(String roomId) {
  return AudioRoomTarget.tryParse(
    callType: AudioRoomTarget.callType,
    roomId: roomId,
  )!;
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

  @override
  Widget buildForeground({required Future<void> Function() onLeaveRequested}) {
    return Column(
      children: <Widget>[
        const Text('Official CallState view'),
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
