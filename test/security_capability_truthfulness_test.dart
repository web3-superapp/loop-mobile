import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';
import 'support/s8_harness.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  testWidgets(
    'A11 exposes no providerless protection switch or secure-storage claim',
    (tester) async {
      final destinations = <String>[];
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          capabilities: const PrivyWalletCapabilities(
            canUsePasskey: true,
            canUseBiometrics: true,
          ),
          onNavigate: destinations.add,
        ),
      );

      // Decision 0121: no engineering banner; each row states its own state.
      expect(
        find.byKey(const ValueKey<String>('protection-setup-unavailable')),
        findsNothing,
      );
      expect(find.text('交易验证还开不了'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Save protection'), findsNothing);
      expect(find.textContaining('stored by the app'), findsNothing);
      expect(find.textContaining('PIN'), findsNothing);
      // A declared Privy capability is never reported as an enabled
      // protection, and with no device lock composed the rows that can be
      // on say 不可用 like MFA: 应用锁 and 大额交易二次验证 (decision 0152).
      expect(find.text('可用'), findsNothing);
      expect(find.text('不可用'), findsNWidgets(3));
      expect(find.textContaining('即将推出'), findsNothing);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('security-setup-continue')),
      );

      expect(destinations, <String>['loop-id-setup']);
    },
  );

  testWidgets('H5 states each protection method is off, with its reason', (
    tester,
  ) async {
    final destinations = <String>[];
    await pumpS8Page(
      tester,
      SecurityCenterScreen(onNavigate: destinations.add),
      security: FakeSecurityGateway(),
    );

    // No score, no badge, no "protections ready" claim.
    expect(find.text('GOOD'), findsNothing);
    expect(find.textContaining('项保护已开启'), findsNothing);
    // Decision 0126: the device count is the 设备 row's own value; the
    // posture card that repeated it is gone.
    expect(find.text('2 台设备 · 2 个会话'), findsNothing);
    final devices = tester.widget<LoopRecordRow>(
      find.byKey(const ValueKey<String>('security-devices-entry')),
    );
    expect(devices.trailing, '2');
    expect(devices.subtitle, startsWith('2 个活跃会话'));

    // Decision 0151: the server still lists 恢复密码 and the response stays
    // valid, but the center no longer shows it.
    final shown = LoopSecurityCapabilityId.values
        .where((id) => !loopHiddenSecurityCapabilities.contains(id))
        .toList(growable: false);
    expect(shown, hasLength(5));
    for (final id in shown) {
      final row = find.byKey(
        ValueKey<String>('security-method-${id.wireName}'),
      );
      await scrollToS8Section(tester, row);
      expect(row, findsOneWidget, reason: id.wireName);
    }
    expect(
      find.byKey(const ValueKey<String>('security-method-recoveryPassword')),
      findsNothing,
    );
    expect(find.text('恢复密码'), findsNothing);
    // None of the five exists yet, so none of them is "off": a badge reading
    // 未开启 over a sentence reading 还没有开放 made LOOP's omission look like
    // the account's.
    expect(find.text('还没有开放'), findsNWidgets(5));
    expect(find.text('未开启'), findsNothing);
    // And the row says what the method would do, instead of repeating its own
    // title with 还没有开放 after it — since S278 (decision 0236) behind the
    // row's (i), not under its title.
    for (final id in shown) {
      final row = find.byKey(
        ValueKey<String>('security-method-${id.wireName}'),
      );
      await scrollToS8Section(tester, row);
      expect(
        tester.widget<LoopRecordRow>(row).subtitle,
        isNull,
        reason: id.wireName,
      );
      expect(
        tester
            .widget<LoopInfoButton>(
              find.byKey(
                ValueKey<String>('security-method-${id.wireName}-info'),
              ),
            )
            .notes
            .single
            .body,
        id.description,
        reason: id.wireName,
      );
    }
    expect(find.text('已开启'), findsOneWidget); // security.event only

    // The two rows that lead somewhere lead to their own explanation page.
    // S278 · decision 0236: the row's (i) answers only its own 44 dp, which
    // on the S279 block sits near the row's centre — so the row is tapped
    // on its title, the way a finger reaches it.
    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('security-method-socialRecovery'),
        ),
        matching: find.text('社交恢复'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('security-method-keyExport')),
        matching: find.text('导出私钥'),
      ),
    );
    await tester.pumpAndSettle();
    expect(destinations, <String>['social-recovery', 'key-export']);
    expect(find.text('Recovery phrase'), findsNothing);
    expect(ProfileSurfaceScreen.supportedIds, isNot(contains('seed-backup')));
  });

  testWidgets('no recovery-phrase or seed surface is reachable from Profile', (
    tester,
  ) async {
    for (final retiredId in <String>[
      'seed-backup',
      'seed',
      'recovery-phrase',
    ]) {
      expect(ProfileSurfaceScreen.supportedIds, isNot(contains(retiredId)));

      await _pumpPhone(tester, ProfileSurfaceScreen.fromId(retiredId));

      expect(find.text('设置不可用'), findsOneWidget);
      expect(find.text('没有做任何更改'), findsOneWidget);
      expect(find.textContaining('Recovery phrase'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }
  });

  testWidgets('production LoopApp A11 keeps every setup method unavailable', (
    tester,
  ) async {
    final router = await _pumpAuthenticatedLoopApp(tester);

    router.go('/auth/security');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('protection-setup-unavailable')),
      findsNothing,
    );
    expect(find.text('可用'), findsNothing);
    // 应用锁, 大额交易二次验证 and MFA. In a widget test the device answers
    // that it can authenticate nobody, so even the protections that can be
    // on are offered as unavailable (decision 0152).
    expect(find.text('不可用'), findsNWidgets(3));
    expect(find.text('已开启'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('production LoopApp H5 fails closed with no adapter', (
    tester,
  ) async {
    final router = await _pumpAuthenticatedLoopApp(tester);

    router.go('/profile/security');
    await tester.pumpAndSettle();

    // Production has no assembled security adapter, so the whole page is
    // unavailable with a reason instead of claiming anything about the
    // account's protection.
    expect(
      find.byKey(const ValueKey<String>('security-capability-block')),
      findsOneWidget,
    );
    expect(find.text('安全中心当前不可用'), findsOneWidget);
    expect(find.textContaining('项保护已开启'), findsNothing);
    expect(find.text('已开启'), findsNothing);
    expect(find.text('Recovery phrase'), findsNothing);
  });

  test('A11 and H5 catalog copy reports current delivery truth', () {
    final a11 = SurfaceCatalog.byPath('/auth/security');
    final h5 = SurfaceCatalog.byPath('/profile/security');
    expect(a11.description, contains('no protection setting is saved'));
    expect(
      h5.description,
      contains('availability without claiming enrollment'),
    );
  });
}

Future<void> _pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpAuthenticatedLoopApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();

  return GoRouter.of(tester.element(find.byType(MemeScreen)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
