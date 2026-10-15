import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_stage.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

/// Decision 0183 (S192): the shared state blocks of the chain, community and
/// launch slices draw the family parts — an illustrated `LoopEmptyState` for a
/// collection that is empty, one `LoopInlineUnavailable` line for a fact that
/// could not be read — and keep their keys and copy.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[child],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  group('chain blocks', () {
    testWidgets('the default empty phase is an illustrated empty state', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoopChainStateBlock(
          phase: LoopChainViewPhase.empty,
          failureKind: null,
          keyPrefix: 'probe',
          emptyMessage: '还没有记录',
          emptyReason: '下一次读取后会出现在这里。',
        ),
      );
      expect(tester.widget(_key('probe-state-empty')), isA<LoopEmptyState>());
      expect(
        find.byKey(
          ValueKey<String>(
            'loop-empty-illustration-${LoopIllustration.history.fileName}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('还没有记录'), findsOneWidget);
      expect(find.text('下一次读取后会出现在这里。'), findsOneWidget);
    });

    testWidgets('a caller can name the empty illustration', (tester) async {
      await _pump(
        tester,
        const LoopChainStateBlock(
          phase: LoopChainViewPhase.empty,
          failureKind: null,
          keyPrefix: 'probe',
          emptyIllustration: LoopIllustration.search,
        ),
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'loop-empty-illustration-${LoopIllustration.search.fileName}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the unavailable phase is one inline line with its reason', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoopChainStateBlock(
          phase: LoopChainViewPhase.unavailable,
          failureKind: LoopChainFailureKind.unavailable,
          keyPrefix: 'probe',
        ),
      );
      expect(
        tester.widget(_key('probe-state-unavailable')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('该内容当前不可用'), findsOneWidget);
      expect(find.byType(LoopEmptyState), findsNothing);
    });

    testWidgets('an unreachable capability gate is an offline line', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoopCapabilityBlockCard(
          label: '兑换暂不可用',
          capability: LoopCapabilityProjection.unknown(unreachable: true),
        ),
      );
      final line = tester.widget<LoopInlineUnavailable>(
        _key('capability-unreachable'),
      );
      expect(line.icon, 'offline');
      expect(find.text('兑换暂不可用'), findsOneWidget);
    });
  });

  group('community blocks', () {
    testWidgets('empty is illustrated, unavailable is a line', (tester) async {
      await _pump(
        tester,
        const CommunityStateBlock(
          phase: CommunityViewPhase.empty,
          failureKind: null,
          emptyMessage: '还没有成员',
        ),
      );
      expect(
        tester.widget(_key('community-state-empty')),
        isA<LoopEmptyState>(),
      );
      expect(find.text('还没有成员'), findsOneWidget);

      await _pump(
        tester,
        const CommunityStateBlock(
          phase: CommunityViewPhase.unavailable,
          failureKind: CommunityFailureKind.unavailable,
        ),
      );
      expect(
        tester.widget(_key('community-state-unavailable')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('该功能当前不可用'), findsOneWidget);
    });

    testWidgets('an unavailable fact keeps its key, reason and next step', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        CommunityUnavailableCard(
          label: '成员名单暂不可用',
          fact: const LoopUnavailableFact('COMMUNITY_MEMBERS_DEFERRED'),
          action: LoopButton(
            key: const ValueKey<String>('probe-next'),
            label: '返回社区',
            onPressed: () => taps += 1,
          ),
        ),
      );
      final card = _key('community-unavailable-COMMUNITY_MEMBERS_DEFERRED');
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(LoopInlineUnavailable)),
        findsOneWidget,
      );
      expect(find.text('成员名单暂不可用'), findsOneWidget);
      await tester.tap(_key('probe-next'));
      expect(taps, 1);
    });
  });

  group('launch blocks', () {
    testWidgets('empty is illustrated, unavailable is a line', (tester) async {
      await _pump(
        tester,
        const LaunchStateBlock(
          prefix: 'probe',
          phase: LaunchViewPhase.empty,
          failureKind: null,
          emptyMessage: '还没有项目',
        ),
      );
      expect(tester.widget(_key('probe-state-empty')), isA<LoopEmptyState>());
      expect(
        find.byKey(
          ValueKey<String>(
            'loop-empty-illustration-${LoopIllustration.launchpad.fileName}',
          ),
        ),
        findsOneWidget,
      );

      await _pump(
        tester,
        const LaunchStateBlock(
          prefix: 'probe',
          phase: LaunchViewPhase.unavailable,
          failureKind: LaunchFailureKind.unavailable,
        ),
      );
      expect(
        tester.widget(_key('probe-state-unavailable')),
        isA<LoopInlineUnavailable>(),
      );
    });

    testWidgets('an unavailable launch fact is one line', (tester) async {
      await _pump(
        tester,
        const LaunchUnavailableCard(
          label: '持有人分布',
          fact: LaunchUnavailable('LAUNCH_HOLDERS_DEFERRED'),
        ),
      );
      expect(
        tester.widget(_key('launch-unavailable-持有人分布')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('持有人分布'), findsOneWidget);
    });
  });

  group('voice room stage', () {
    testWidgets('an unread roster is one inline line on both grids', (
      tester,
    ) async {
      await _pump(
        tester,
        VoiceRoomSpeakerGrid(
          roster: const VoiceRoomRosterState(
            view: VoiceRoomRosterView.speaker,
            phase: CommunityViewPhase.unavailable,
            failureKind: CommunityFailureKind.unavailable,
          ),
          onRetry: () {},
        ),
      );
      expect(
        tester.widget(_key('voiceroom-speakers-unavailable')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('发言人名单当前不可用'), findsOneWidget);

      await _pump(
        tester,
        VoiceRoomListenerGrid(
          roster: const VoiceRoomRosterState(
            view: VoiceRoomRosterView.listener,
            phase: CommunityViewPhase.unavailable,
            failureKind: CommunityFailureKind.unavailable,
          ),
          total: 0,
          onRetry: () {},
        ),
      );
      expect(
        tester.widget(_key('voiceroom-listeners-unavailable')),
        isA<LoopInlineUnavailable>(),
      );
      expect(find.text('听众名单当前不可用'), findsOneWidget);
    });
  });

  testWidgets('a closed channel with no retry is one inline line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: const Scaffold(
          body: LoopStreamChannelStateBlock(
            icon: 'warn',
            message: '这个会话暂时打不开。',
          ),
        ),
      ),
    );
    final line = tester.widget<LoopInlineUnavailable>(
      find.byType(LoopInlineUnavailable),
    );
    expect(line.message, '会话不可用');
    expect(line.detail, '这个会话暂时打不开。');
    expect(line.onRetry, isNull);
  });
}
