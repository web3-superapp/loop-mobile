import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production offline route stays unknown without a source', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/offline',
      unavailableKey: 'connectivity-source-unavailable',
      absentClaims: <String>['当前设备离线', '完全离线', '重试'],
    );
  });

  testWidgets('naked offline surface never infers an offline state', (
    tester,
  ) async {
    var generic = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'offline',
        onRetry: () => generic += 1,
        onSecondaryAction: () => generic += 1,
      ),
    );
    expect(find.text('连接状态未接入'), findsOneWidget);
    expect(find.text('UNKNOWN'), findsOneWidget);
    expect(find.text('当前设备离线'), findsNothing);
    expect(find.text('无法连接到服务器'), findsNothing);
    expect(find.text('重试'), findsNothing);
    expect(find.byType(LoopConnectivityBanner), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('system-state-dismissible')),
      findsOneWidget,
    );
    await tester.tap(find.text('返回 LOOP'));
    expect(generic, 1);
  });

  testWidgets('explicit scopes render their exact notice and actions', (
    tester,
  ) async {
    final cases = <(LoopConnectivityScope, String, String)>[
      (LoopConnectivityScope.fullyOffline, '当前设备离线', '完全离线'),
      (LoopConnectivityScope.marketDataUnavailable, '行情来源暂时不可用', '行情来源暂时不可用'),
      (
        LoopConnectivityScope.tradingServiceUnavailable,
        '交易服务暂时不可用',
        '交易服务暂时不可用',
      ),
    ];
    for (final (scope, heading, notice) in cases) {
      var retries = 0;
      var continues = 0;
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'offline',
          connectivityScope: scope,
          onRetry: () => retries += 1,
          onSecondaryAction: () => continues += 1,
        ),
      );
      expect(find.text(heading), findsWidgets, reason: scope.name);
      expect(find.text(notice), findsWidgets, reason: scope.name);
      expect(find.text('连接状态未接入'), findsNothing, reason: scope.name);
      expect(find.text('返回 LOOP'), findsNothing, reason: scope.name);
      if (scope == LoopConnectivityScope.fullyOffline) {
        expect(find.byType(LoopEmpty), findsOneWidget);
        expect(find.text('OFFLINE'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('重试'));
      await tester.tap(find.text('重试'));
      expect(retries, 1, reason: scope.name);
      await tester.tap(
        find.text(
          scope == LoopConnectivityScope.fullyOffline ? '查看缓存内容' : '继续使用可用功能',
        ),
      );
      expect(continues, 1, reason: scope.name);
    }
  });

  testWidgets('connectivity banner announces and retries', (tester) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    await pumpSystemSurface(
      tester,
      Scaffold(
        body: LoopConnectivityBanner(
          scope: LoopConnectivityScope.marketDataUnavailable,
          onRetry: () => retries += 1,
        ),
      ),
      textScale: 2,
    );
    expect(find.text('行情不可用 · 价格可能已过期'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('行情来源暂时不可用')), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('offline states remain usable at 2x text', (tester) async {
    for (final scope in <LoopConnectivityScope?>[
      null,
      LoopConnectivityScope.fullyOffline,
    ]) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'offline',
          connectivityScope: scope,
          onRetry: () {},
          onSecondaryAction: () {},
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final action = find.text(scope == null ? '返回 LOOP' : '查看缓存内容');
      await tester.ensureVisible(action);
      await tester.tap(action);
    }
  });
}
