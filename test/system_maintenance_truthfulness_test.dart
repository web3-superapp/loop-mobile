import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production maintenance route stays unknown', (tester) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/maintenance',
      unavailableKey: 'maintenance-source-unavailable',
      absentClaims: <String>['维护通知已生效', 'UTC', '再次检查', '查看服务状态'],
    );
  });

  testWidgets('naked maintenance surface never infers a window', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        onMaintenanceRecheck: () {},
        onMaintenanceStatus: () {},
        onSecondaryAction: () {},
      ),
    );
    expect(find.text('维护状态未接入'), findsOneWidget);
    expect(find.text('维护通知已生效'), findsNothing);
    expect(find.text('再次检查'), findsNothing);
    expect(find.text('查看服务状态'), findsNothing);
    expect(find.text('返回 LOOP'), findsOneWidget);
  });

  testWidgets('explicit notice shows only the supplied window and actions', (
    tester,
  ) async {
    var rechecks = 0;
    var status = 0;
    var readOnly = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(
          windowLabel: '03:00–05:00 UTC',
          detail: '期间社区互动暂停；钱包与 Mining 数据只读。',
        ),
        onMaintenanceRecheck: () => rechecks += 1,
        onMaintenanceStatus: () => status += 1,
        onSecondaryAction: () => readOnly += 1,
      ),
    );
    expect(find.text('03:00–05:00 UTC'), findsOneWidget);
    expect(find.text('WINDOW'), findsOneWidget);
    expect(find.text('维护状态未接入'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
    await tester.tap(find.text('再次检查'));
    await tester.tap(find.text('查看服务状态'));
    await tester.tap(find.text('查看只读内容'));
    expect((rechecks, status, readOnly), (1, 1, 1));

    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: LoopMaintenanceNotice(),
      ),
    );
    expect(find.text('维护通知已生效'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.textContaining('UTC'), findsNothing);
    expect(find.text('再次检查'), findsNothing);
  });

  testWidgets('maintenance states remain usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(
          windowLabel: '01:00 UTC',
        ),
        onMaintenanceRecheck: () {},
        onMaintenanceStatus: () {},
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('查看服务状态'));
    await tester.tap(find.text('查看服务状态'));
  });
}
