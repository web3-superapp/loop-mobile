import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s8_harness.dart';

/// `security`, `devices`, `key-export`, `social-recovery` (D20).
void main() {
  group('security', () {
    testWidgets('loading', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(pending: true),
          capabilities: S8Answer<LoopSecurityCapabilities>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('security-methods-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('error', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(
            failure: LoopChainFailureKind.unexpected,
          ),
        ),
      );
      final error = find.byKey(
        const ValueKey<String>('security-summary-state-error'),
      );
      await scrollToS8Section(tester, error);
      expect(error, findsOneWidget);
    });

    testWidgets('offline', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );
      final offline = find.byKey(
        const ValueKey<String>('security-summary-state-offline'),
      );
      await scrollToS8Section(tester, offline);
      expect(offline, findsOneWidget);
    });

    testWidgets('permission', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );
      final permission = find.byKey(
        const ValueKey<String>('security-summary-state-permission'),
      );
      await scrollToS8Section(tester, permission);
      expect(permission, findsOneWidget);
    });

    testWidgets('unavailable', (tester) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(mode: LoopChainGatewayMode.unavailable),
        meta: s8MetaSnapshot(
          security: LoopV2CapabilityAvailability.unavailable,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('security-capability-block')),
        findsOneWidget,
      );
    });

    testWidgets('an account with no security events shows the empty state', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
      );

      final empty = find.byKey(const ValueKey<String>('security-events-empty'));
      await scrollToS8Section(tester, empty);
      expect(empty, findsOneWidget);
      expect(find.text('还没有安全事件'), findsOneWidget);
    });

    testWidgets('an unavailable approvals block prints its reason, not a 0', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(
            value: s8Summary(approvalsAvailable: false),
          ),
        ),
      );

      final block = find.byKey(
        const ValueKey<String>('security-approvals-unavailable'),
      );
      await scrollToS8Section(tester, block);
      expect(block, findsOneWidget);
      expect(find.text('授权盘点读不到'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('security-approvals-active')),
        findsNothing,
      );
    });

    testWidgets('the approvals block states where its coverage starts', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
      );

      final freshness = find.byKey(
        const ValueKey<String>('security-approvals-freshness'),
      );
      await scrollToS8Section(tester, freshness);
      expect(find.textContaining('授权记录自区块 120,600,000 起'), findsOneWidget);
      expect(find.textContaining('索引高度 120,659,683'), findsOneWidget);
    });

    testWidgets('the high-risk signal quotes the server policy', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(
          summary: S8Answer<LoopSecuritySummary>(
            value: s8Summary(highRisk: true),
          ),
        ),
      );

      final notice = find.byKey(
        const ValueKey<String>('security-high-risk-notice'),
      );
      await scrollToS8Section(tester, notice);
      expect(notice, findsOneWidget);
      expect(find.textContaining('阈值 2'), findsOneWidget);
      expect(find.textContaining('deviceRiskV1'), findsNothing);
    });
  });

  group('devices', () {
    testWidgets('loading', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('devices-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('empty, with no current-device claim', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            value: s8Directory(
              devices: const <LoopDeviceSession>[],
              currentSessionId: null,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('devices-state-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('devices-current-unknown')),
        findsOneWidget,
      );
    });

    testWidgets('error', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            failure: LoopChainFailureKind.unexpected,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('devices-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('offline', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('devices-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('permission', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('devices-state-permission')),
        findsOneWidget,
      );
    });

    testWidgets('unavailable', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(mode: LoopChainGatewayMode.unavailable),
        meta: s8MetaSnapshot(
          security: LoopV2CapabilityAvailability.unavailable,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('devices-capability-block')),
        findsOneWidget,
      );
    });

    testWidgets('no device name, geography or continuous activity is shown', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(),
      );

      expect(find.text('iOS · 1.0.0'), findsOneWidget);
      expect(find.text('Android · 1.0.0'), findsOneWidget);
      expect(find.text('本次会话'), findsOneWidget);
      expect(find.textContaining('iPhone 15 Pro'), findsNothing);
      expect(find.textContaining('MacBook'), findsNothing);
      expect(find.textContaining('上海'), findsNothing);
    });

    testWidgets('two sessions of one device stay distinguishable', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            value: s8Directory(
              devices: <LoopDeviceSession>[
                s8Device(),
                // The same device, same platform, same client version: only
                // the session short form and the first login separate them.
                s8Device(
                  sessionId: s8OtherSessionId,
                  isCurrent: false,
                  createdAt: DateTime.utc(2026, 9, 3, 1),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('iOS · 1.0.0'), findsNWidgets(2));
      expect(find.textContaining('会话 3d4e'), findsOneWidget);
      expect(find.textContaining('会话 4e5f'), findsOneWidget);
      expect(find.textContaining('首次登录 2026-09-08 20:00 UTC'), findsOneWidget);
      expect(find.textContaining('首次登录 2026-09-03 01:00 UTC'), findsOneWidget);
      // The session in hand is being used, so no observation time is printed
      // beside it; the older session of the same device says whose it is.
      expect(find.text('本次会话'), findsOneWidget);
      expect(find.textContaining('正在使用'), findsOneWidget);
      expect(find.text('本设备 · 旧会话'), findsOneWidget);
      expect(find.textContaining('最后活跃 '), findsOneWidget);
    });

    testWidgets('the revoke sheet names the session it is about', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(
          devices: S8Answer<LoopDeviceDirectory>(
            value: s8Directory(
              devices: <LoopDeviceSession>[
                s8Device(),
                s8Device(
                  sessionId: s8OtherSessionId,
                  isCurrent: false,
                  createdAt: DateTime.utc(2026, 9, 3, 1),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('device-$s8OtherSessionId')),
      );
      await tester.pumpAndSettle();

      final sheet = find.byKey(const ValueKey<String>('device-revoke-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('4e5f')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('本设备的旧会话')),
        findsOneWidget,
      );
    });

    testWidgets('signing every other device out stays step-up refused', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(),
      );

      final button = find.byKey(const ValueKey<String>('devices-revoke-all'));
      await scrollToS8Section(tester, button);
      expect(tester.widget<LoopButton>(button).onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('devices-revoke-all-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('需要二次验证'), findsWidgets);
    });

    testWidgets('revoking another session states the audit-only effect', (
      tester,
    ) async {
      final gateway = FakeSecurityGateway();
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: gateway,
      );

      final row = find.byKey(ValueKey<String>('device-$s8OtherSessionId'));
      await scrollToS8Section(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      // The sheet states the effect before the command runs.
      expect(
        find.byKey(const ValueKey<String>('device-revoke-sheet')),
        findsOneWidget,
      );
      expect(find.textContaining('不会被终止'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('device-revoke-confirm')),
      );
      await tester.pumpAndSettle();

      expect(gateway.revoked, <String>[s8OtherSessionId]);
      final outcome = find.byKey(
        const ValueKey<String>('devices-revoke-outcome'),
      );
      await scrollToS8Section(tester, outcome);
      expect(find.text('已记录撤销，对方访问未终止'), findsWidgets);
      expect(find.textContaining('已下线'), findsNothing);
    });

    testWidgets('the current session is never a revoke target', (tester) async {
      final gateway = FakeSecurityGateway();
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: gateway,
      );

      final row = find.byKey(ValueKey<String>('device-$s8CurrentSessionId'));
      await scrollToS8Section(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('device-revoke-sheet')),
        findsNothing,
      );
      expect(gateway.revoked, isEmpty);
    });

    testWidgets('a step-up refusal is reported without a retry promise', (
      tester,
    ) async {
      final gateway = FakeSecurityGateway(
        revokeFailure: LoopChainFailureKind.stepUpRequired,
      );
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: gateway,
      );

      final row = find.byKey(ValueKey<String>('device-$s8OtherSessionId'));
      await scrollToS8Section(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('device-revoke-confirm')),
      );
      await tester.pumpAndSettle();

      final error = find.byKey(const ValueKey<String>('devices-command-error'));
      await scrollToS8Section(tester, error);
      expect(error, findsOneWidget);
      expect(find.textContaining('二次验证还没有开放'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('devices-revoke-outcome')),
        findsNothing,
      );
    });
  });

  group('key-export and social-recovery', () {
    testWidgets('key-export explains, never executes and shows no key', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const KeyExportScreen(),
        security: FakeSecurityGateway(),
      );

      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('key-export-action')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('key-export-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('0x'), findsNothing);
      expect(find.textContaining('已导出'), findsNothing);
      expect(find.text('Face ID'), findsNothing);
    });

    testWidgets('key-export loading', (tester) async {
      await pumpS8Page(
        tester,
        const KeyExportScreen(),
        security: FakeSecurityGateway(
          capabilities: S8Answer<LoopSecurityCapabilities>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('key-export-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.unexpected, 'key-export-state-error'),
      (LoopChainFailureKind.offline, 'key-export-state-offline'),
      (LoopChainFailureKind.unavailable, 'key-export-state-unavailable'),
      (LoopChainFailureKind.permissionDenied, 'key-export-state-permission'),
    ]) {
      testWidgets('key-export ${kind.name}', (tester) async {
        await pumpS8Page(
          tester,
          const KeyExportScreen(),
          security: FakeSecurityGateway(
            capabilities: S8Answer<LoopSecurityCapabilities>(failure: kind),
          ),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }

    testWidgets('key-export capability block', (tester) async {
      await pumpS8Page(
        tester,
        const KeyExportScreen(),
        security: FakeSecurityGateway(mode: LoopChainGatewayMode.unavailable),
        meta: s8MetaSnapshot(
          security: LoopV2CapabilityAvailability.unavailable,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('key-export-capability-block')),
        findsOneWidget,
      );
    });

    testWidgets('social-recovery shows no guardian list and no 0 / 3', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        const SocialRecoveryScreen(),
        security: FakeSecurityGateway(),
      );

      expect(find.text('2-of-3 守护人'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('social-recovery-unavailable')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('social-recovery-action')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('0 / 3'), findsNothing);
      expect(find.text('NightOwl'), findsNothing);
      expect(find.text('pepe_maxi'), findsNothing);
    });

    testWidgets('social-recovery loading', (tester) async {
      await pumpS8Page(
        tester,
        const SocialRecoveryScreen(),
        security: FakeSecurityGateway(
          capabilities: S8Answer<LoopSecurityCapabilities>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('social-recovery-state-loading')),
        findsOneWidget,
      );
    });

    for (final (kind, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.unexpected, 'social-recovery-state-error'),
      (LoopChainFailureKind.offline, 'social-recovery-state-offline'),
      (LoopChainFailureKind.unavailable, 'social-recovery-state-unavailable'),
      (
        LoopChainFailureKind.permissionDenied,
        'social-recovery-state-permission',
      ),
    ]) {
      testWidgets('social-recovery ${kind.name}', (tester) async {
        await pumpS8Page(
          tester,
          const SocialRecoveryScreen(),
          security: FakeSecurityGateway(
            capabilities: S8Answer<LoopSecurityCapabilities>(failure: kind),
          ),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      });
    }
  });
}
