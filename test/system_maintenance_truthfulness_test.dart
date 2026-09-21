import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_specimens.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production maintenance route draws the specimen', (
    tester,
  ) async {
    await expectProductionSpecimen(
      tester,
      location: '/system/maintenance',
      kicker: loopStateSpecimenLabel,
      specimenKeys: <String>[
        'maintenance-specimen',
        'maintenance-specimen-read-only',
      ],
      specimenText: <String>['Mining Power 正常累计'],
    );
  });

  testWidgets('the maintenance specimen keeps the window and the promise', (
    tester,
  ) async {
    var readOnly = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        onMaintenanceReadOnly: () => readOnly += 1,
        onMaintenanceRecheck: () => fail('the specimen has no 再次检查'),
        onMaintenanceStatus: () => fail('the specimen has no 查看服务状态'),
        onSecondaryAction: () => fail('a specimen page has no 返回 LOOP'),
      ),
    );
    expect(find.text(loopStateSpecimenLabel), findsOneWidget);
    expect(find.text('03:00–05:00 UTC'), findsOneWidget);
    expect(find.text('2H WINDOW'), findsOneWidget);
    expect(find.text('Mining Power 正常累计'), findsOneWidget);
    expect(find.text('再次检查'), findsNothing);
    expect(find.text('查看服务状态'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
    await tester.tap(find.text('查看只读内容'));
    expect(readOnly, 1);
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
        onMaintenanceReadOnly: () => readOnly += 1,
      ),
    );
    expect(find.text('03:00–05:00 UTC'), findsOneWidget);
    expect(find.text('WINDOW'), findsOneWidget);
    expect(find.text(loopStateSpecimenLabel), findsNothing);
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

  testWidgets('explicit notice never accepts generic system actions', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(
          windowLabel: '03:00–05:00 UTC',
        ),
        onRetry: () =>
            fail('generic retry must stay isolated from maintenance'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('03:00–05:00 UTC'), findsOneWidget);
    expect(find.text('再次检查'), findsNothing);
    expect(find.text('查看服务状态'), findsNothing);
    expect(find.text('查看只读内容'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
  });

  testWidgets('read-only action requires its dedicated callback', (
    tester,
  ) async {
    // The unknown state's generic return action never leaks into the
    // explicit state, and the explicit action never appears without its own
    // callback.
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );
    expect(find.text('查看只读内容'), findsNothing);

    var readOnly = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        maintenanceNotice: const LoopMaintenanceNotice(),
        onMaintenanceReadOnly: () => readOnly += 1,
      ),
    );
    await tester.tap(find.text('查看只读内容'));
    expect(readOnly, 1);

    // The specimen has its own read-only exit and never the generic one.
    var specimenReadOnly = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'maintenance',
        onMaintenanceReadOnly: () => specimenReadOnly += 1,
        onSecondaryAction: () => fail('a specimen page has no 返回 LOOP'),
      ),
    );
    expect(find.text('返回 LOOP'), findsNothing);
    await tester.tap(find.text('查看只读内容'));
    expect(specimenReadOnly, 1);
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
