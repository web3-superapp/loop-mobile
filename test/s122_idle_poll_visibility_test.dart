// Decision 0125: a poll runs only while its page is the one being looked at.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/time/loop_foreground_poll.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

class _PollingPage extends StatefulWidget {
  const _PollingPage({required this.onRead});

  final VoidCallback onRead;

  @override
  State<_PollingPage> createState() => _PollingPageState();
}

class _PollingPageState extends State<_PollingPage> {
  late final LoopForegroundPoll poll = LoopForegroundPoll(
    interval: const Duration(seconds: 5),
    read: () async => widget.onRead(),
  );

  @override
  void dispose() {
    poll.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    poll.setVisible(LoopForegroundPoll.pageVisible(context));
    poll.start();
    return const Scaffold(body: Text('community'));
  }
}

void main() {
  loopWatchGround();

  testWidgets('a covered poll asks nothing and reads once when uncovered', (
    tester,
  ) async {
    var reads = 0;
    final poll = LoopForegroundPoll(
      interval: const Duration(seconds: 5),
      read: () async => reads += 1,
    );
    addTearDown(poll.stop);

    poll.start();
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);

    poll.setVisible(false);
    expect(poll.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 60));
    expect(reads, 1, reason: 'nobody is looking at the page');

    poll.readNow();
    await tester.pump();
    expect(reads, 1, reason: 'a covered page does not read on request');

    poll.setVisible(true);
    await tester.pump();
    expect(reads, 1, reason: 'uncovering does not race the page');
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2, reason: 'the interval starts again from the uncovering');
    poll.stop();
  });

  testWidgets('a poll started while covered waits for the page', (
    tester,
  ) async {
    var reads = 0;
    final poll = LoopForegroundPoll(
      interval: const Duration(seconds: 5),
      read: () async => reads += 1,
    );
    addTearDown(poll.stop);

    poll.setVisible(false);
    poll.start();
    await tester.pump(const Duration(seconds: 30));
    expect(reads, 0);

    // Going to the background and back while covered still asks nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 30));
    expect(reads, 0);

    poll.setVisible(true);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);
    poll.stop();
  });

  testWidgets('a page pushed over the polling page stops its reads', (
    tester,
  ) async {
    var reads = 0;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        navigatorKey: navigator,
        home: _PollingPage(onRead: () => reads += 1),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('chat')),
      ),
    );
    await tester.pumpAndSettle();
    final before = reads;
    await tester.pump(const Duration(seconds: 60));
    expect(reads, before, reason: 'the community page is under the chat');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(reads, before + 1, reason: 'back on the page, the interval runs');
  });

  testWidgets('a polling page in an offstage tab stops its reads', (
    tester,
  ) async {
    var reads = 0;
    Widget shell({required bool onTab}) => MaterialApp(
      theme: LoopTheme.dark,
      home: TickerMode(
        enabled: onTab,
        child: _PollingPage(onRead: () => reads += 1),
      ),
    );
    await tester.pumpWidget(shell(onTab: true));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 1);

    await tester.pumpWidget(shell(onTab: false));
    await tester.pump(const Duration(seconds: 60));
    expect(reads, 1);

    await tester.pumpWidget(shell(onTab: true));
    await tester.pump(const Duration(seconds: 5));
    expect(reads, 2);
  });

  testWidgets('the community page stops asking for the room while a page '
      'covers it, and asks again when uncovered', (tester) async {
    final voiceRoom = FakeVoiceRoomGateway();
    int currentReads() =>
        voiceRoom.commands.where((c) => c.startsWith('current:')).length;
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(viewer: testViewer(role: CommunityRole.member)),
      ),
      voiceRoom: voiceRoom,
    );

    final open = currentReads();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(currentReads(), open + 1, reason: 'on screen, it reads the room');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('chat')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final covered = currentReads();
    await tester.pump(const Duration(seconds: 60));
    expect(currentReads(), covered, reason: 'nobody is looking at the page');

    navigator.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      currentReads(),
      covered + 1,
      reason: 'uncovered, the interval runs again',
    );

    await tester.pumpWidget(const SizedBox());
  });
}
