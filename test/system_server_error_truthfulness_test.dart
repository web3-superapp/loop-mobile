import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production server-error route stays unknown', (tester) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/error',
      unavailableKey: 'service-error-source-unavailable',
      absentClaims: <String>['服务暂时不可用', '追踪号', '联系客服'],
    );
  });

  testWidgets('naked server-error surface never infers a request error', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        onServiceRetry: () {},
        onServiceSupport: () {},
        onSecondaryAction: () {},
      ),
    );
    expect(find.text('服务状态还没有开放'), findsOneWidget);
    expect(find.text('服务暂时不可用'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.text('联系客服'), findsNothing);
    expect(find.textContaining('追踪号'), findsNothing);
    expect(find.text('返回 LOOP'), findsOneWidget);
  });

  testWidgets('explicit observation exposes only exact facts and actions', (
    tester,
  ) async {
    var retries = 0;
    var support = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: const LoopServiceErrorObservation(
          traceId: '7f3a2c9e',
          statusLabel: '502',
        ),
        onServiceRetry: () => retries += 1,
        onServiceSupport: () => support += 1,
        onRetry: () => fail('generic retry must stay isolated from I2'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );
    expect(find.text('服务暂时不可用'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('错误 502.*追踪号 7f3a2c9e')),
      findsOneWidget,
    );
    expect(find.text('服务状态还没有开放'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.tap(find.text('联系客服'));
    expect(retries, 1);
    expect(support, 1);

    // Without a trace id the page says so instead of inventing one.
    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: LoopServiceErrorObservation(),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('结果未确认.*追踪号未提供')), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(find.text('联系客服'), findsNothing);
  });

  testWidgets('explicit observation never accepts generic system actions', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: const LoopServiceErrorObservation(
          statusLabel: '502',
        ),
        onRetry: () => fail('generic retry must stay isolated from I2'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('服务暂时不可用'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(find.text('联系客服'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
  });

  testWidgets('server-error states remain usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'server-error',
        serviceErrorObservation: const LoopServiceErrorObservation(
          traceId: 'L-2048',
        ),
        onServiceRetry: () {},
        onServiceSupport: () {},
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('联系客服'));
    await tester.tap(find.text('联系客服'));
  });
}
