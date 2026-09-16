import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The Launch desk's (i) used to be a dead end.
///
/// It pushes `launch-rounds` without a launch id, and that page reported the
/// missing subject as a missing launch: 「目标不存在、已被移除，或对当前账号不
/// 可见」 over a retry that could never change the answer, while the real
/// situation was only that the directory held no project. The control now
/// appears only when there is a project to open, and the page states what it
/// is missing instead of accusing a launch of being gone.
void main() {
  group('launch · the rules control', () {
    testWidgets('an empty directory offers no rules control', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(awaitingSchedule: const <LaunchSummary>[]),
          ),
        ),
      );

      expect(find.textContaining('0 个已登记项目'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('launch-rules-action')),
        findsNothing,
      );
    });

    testWidgets('a directory with a project keeps the control', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-rules-action')),
        findsOneWidget,
      );
    });
  });

  group('launch-rounds · no subject', () {
    testWidgets('a missing launch id is not a missing launch', (tester) async {
      final gateway = FakeLaunchGateway();
      await pumpS7Page(tester, const LaunchRoundsScreen(), launch: gateway);

      expect(
        find.byKey(const ValueKey<String>('launch-rounds-no-subject')),
        findsOneWidget,
      );
      expect(find.textContaining('目标不存在'), findsNothing);
      expect(find.byType(LoopErrorState), findsNothing);
      expect(find.text('重试'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('launch-rounds-state-error')),
        findsNothing,
      );
    });
  });
}
