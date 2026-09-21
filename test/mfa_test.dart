import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';

void main() {
  loopWatchGround();

  const totp = LoopMfaEnrollment(kind: LoopMfaMethodKind.totp);

  group('reading what the provider holds', () {
    test('an answered read is the only thing that means "none"', () async {
      final container = _container(_FakeMfaGateway());

      await container.read(loopMfaProvider.notifier).load();

      final state = container.read(loopMfaProvider);
      expect(state.phase, LoopMfaPhase.known);
      expect(state.enrollments, isEmpty);
      expect(state.isEnrolled, isFalse);
    });

    test('a provider that cannot be asked is unavailable, not empty', () async {
      final container = _container(const UnavailableLoopMfaGateway());

      await container.read(loopMfaProvider.notifier).load();

      final state = container.read(loopMfaProvider);
      expect(state.phase, LoopMfaPhase.unavailable);
      expect(state.failure, LoopMfaFailureKind.unavailable);
      expect(state.isEnrolled, isFalse);
    });

    test('an application with MFA switched off says exactly that', () async {
      final container = _container(
        _FakeMfaGateway(
          failure: const LoopMfaException(
            LoopMfaFailureKind.notEnabled,
            providerMessage: 'MFA is not enabled for this app',
          ),
        ),
      );

      await container.read(loopMfaProvider.notifier).load();

      expect(
        container.read(loopMfaProvider).failure,
        LoopMfaFailureKind.notEnabled,
      );
      // The provider's own sentence is kept for the log, never for the page.
      expect(
        container.read(loopMfaProvider).providerMessage,
        'MFA is not enabled for this app',
      );
      expect(
        loopMfaFailureText(LoopMfaFailureKind.notEnabled),
        contains('登录服务尚未开启 MFA'),
      );
    });
  });

  group('enrolling TOTP', () {
    test('a secret is not an enrolment', () async {
      final gateway = _FakeMfaGateway();
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      await controller.beginTotp();

      final state = container.read(loopMfaProvider);
      expect(state.step, LoopMfaEnrollmentStep.confirming);
      expect(state.secret?.secret, 'JBSWY3DPEHPK3PXP');
      expect(state.secret?.authUrl, startsWith('otpauth://totp/'));
      // Nothing was enrolled by asking for a key.
      expect(state.isEnrolled, isFalse);
    });

    test('a wrong code keeps the step open and enrols nothing', () async {
      final gateway = _FakeMfaGateway(
        submitFailure: const LoopMfaException(LoopMfaFailureKind.invalidCode),
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();
      await controller.beginTotp();

      expect(await controller.submitTotp('000000'), isFalse);

      final state = container.read(loopMfaProvider);
      expect(state.step, LoopMfaEnrollmentStep.confirming);
      expect(state.failure, LoopMfaFailureKind.invalidCode);
      expect(state.isEnrolled, isFalse);
    });

    test(
      'the account is enrolled only by what the provider returned',
      () async {
        final gateway = _FakeMfaGateway(afterSubmit: <LoopMfaEnrollment>[totp]);
        final container = _container(gateway);
        final controller = container.read(loopMfaProvider.notifier);
        await controller.load();
        await controller.beginTotp();

        expect(await controller.submitTotp('123456'), isTrue);

        final state = container.read(loopMfaProvider);
        expect(state.hasTotp, isTrue);
        expect(state.step, LoopMfaEnrollmentStep.idle);
        // The secret is gone the moment it is no longer needed.
        expect(state.secret, isNull);
        expect(gateway.submitted, <String>['123456']);
      },
    );

    test('leaving the sheet drops the secret and enrols nothing', () async {
      final container = _container(_FakeMfaGateway());
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();
      await controller.beginTotp();

      controller.cancelTotp();

      final state = container.read(loopMfaProvider);
      expect(state.secret, isNull);
      expect(state.step, LoopMfaEnrollmentStep.idle);
      expect(state.isEnrolled, isFalse);
    });
  });

  group('removing TOTP', () {
    test('what is left is what the provider said is left', () async {
      final gateway = _FakeMfaGateway(
        enrollments: <LoopMfaEnrollment>[totp],
        afterRemove: const <LoopMfaEnrollment>[],
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.removeTotp(), isTrue);

      expect(container.read(loopMfaProvider).hasTotp, isFalse);
      expect(gateway.removals, 1);
    });

    test('a refused removal leaves the method exactly where it was', () async {
      final gateway = _FakeMfaGateway(
        enrollments: <LoopMfaEnrollment>[totp],
        removeFailure: const LoopMfaException(
          LoopMfaFailureKind.notAuthenticated,
        ),
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.removeTotp(), isFalse);

      expect(container.read(loopMfaProvider).hasTotp, isTrue);
      expect(
        container.read(loopMfaProvider).failure,
        LoopMfaFailureKind.notAuthenticated,
      );
    });
  });

  group('04 reports the second factor it was given', () {
    testWidgets('no provider behind the page is 不可用, never 未开启', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('security-setup'),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-mfa')),
      );
      expect(row.trailing, '不可用');
      expect(row.onTap, isNull);
      expect(row.subtitle, contains('这次运行没有连上登录服务'));
    });

    testWidgets('an answered, empty account is 未开启 and can be opened', (
      tester,
    ) async {
      var opened = 0;
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          mfa: const LoopMfaState(phase: LoopMfaPhase.known),
          onOpenMfa: () => opened += 1,
        ),
      );

      final finder = find.byKey(const ValueKey<String>('security-mfa'));
      expect(tester.widget<LoopRecordRow>(finder).trailing, '未开启');

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('an enrolled account names the method the provider named', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          mfa: const LoopMfaState(
            phase: LoopMfaPhase.known,
            enrollments: <LoopMfaEnrollment>[totp],
          ),
          onOpenMfa: () {},
        ),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-mfa')),
      );
      expect(row.trailing, '已开启');
      expect(row.subtitle, contains('验证器 App'));
      expect(row.semanticLabel, contains('已开启'));
    });

    testWidgets('大额交易二次验证 stays closed, and says why', (tester) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('security-setup'),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-大额交易二次验证')),
      );
      expect(row.trailing, '不可用');
      expect(row.subtitle, contains('还没有会触发它的链上操作'));
    });
  });

  group('the enrolment sheet', () {
    testWidgets('an application with MFA off offers no code field', (
      tester,
    ) async {
      final container = _container(
        _FakeMfaGateway(
          beginFailure: const LoopMfaException(LoopMfaFailureKind.notEnabled),
        ),
      );
      await container.read(loopMfaProvider.notifier).load();
      await _pumpSheet(tester, container);

      await tester.tap(find.byKey(const ValueKey<String>('mfa-sheet-begin')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-failure')),
        findsOneWidget,
      );
      expect(find.text('登录服务尚未开启 MFA'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-code')),
        findsNothing,
      );
    });

    testWidgets('a secret is shown as a square and as a key to type', (
      tester,
    ) async {
      final container = _container(
        _FakeMfaGateway(afterSubmit: <LoopMfaEnrollment>[totp]),
      );
      await container.read(loopMfaProvider.notifier).load();
      await _pumpSheet(tester, container);

      await tester.tap(find.byKey(const ValueKey<String>('mfa-sheet-begin')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-qr')),
        findsOneWidget,
      );
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      // Six digits are needed before anything can be submitted.
      expect(_enabled(tester, 'mfa-sheet-submit'), isFalse);

      await tester.enterText(
        find.byKey(const ValueKey<String>('mfa-sheet-code')),
        '123456',
      );
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'mfa-sheet-submit'), isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('mfa-sheet-submit')));
      await tester.pumpAndSettle();

      expect(container.read(loopMfaProvider).hasTotp, isTrue);
      // The sheet turns into the removal it now has something to remove.
      expect(find.text('关闭 MFA'), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------

ProviderContainer _container(LoopMfaGateway gateway) {
  final container = ProviderContainer(
    overrides: [loopMfaGatewayProvider.overrideWithValue(gateway)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  loopArmGroundProbe(tester);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLoopMfaSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) {
  final button = tester.widget<LoopButton>(find.byKey(ValueKey<String>(key)));
  return button.onPressed != null;
}

final class _FakeMfaGateway implements LoopMfaGateway {
  _FakeMfaGateway({
    this.enrollments = const <LoopMfaEnrollment>[],
    this.afterSubmit,
    this.afterRemove,
    this.failure,
    this.beginFailure,
    this.submitFailure,
    this.removeFailure,
  });

  final List<LoopMfaEnrollment> enrollments;
  final List<LoopMfaEnrollment>? afterSubmit;
  final List<LoopMfaEnrollment>? afterRemove;
  final LoopMfaException? failure;
  final LoopMfaException? beginFailure;
  final LoopMfaException? submitFailure;
  final LoopMfaException? removeFailure;

  final List<String> submitted = <String>[];
  int removals = 0;

  @override
  Future<List<LoopMfaEnrollment>> readEnrollments() async {
    final error = failure;
    if (error != null) throw error;
    return enrollments;
  }

  @override
  Future<LoopTotpSecret> beginTotpEnrollment() async {
    final error = beginFailure;
    if (error != null) throw error;
    return const LoopTotpSecret(
      secret: 'JBSWY3DPEHPK3PXP',
      authUrl: 'otpauth://totp/LOOP:owner?secret=JBSWY3DPEHPK3PXP&issuer=LOOP',
    );
  }

  @override
  Future<List<LoopMfaEnrollment>> completeTotpEnrollment(String code) async {
    submitted.add(code);
    final error = submitFailure;
    if (error != null) throw error;
    return afterSubmit ?? enrollments;
  }

  @override
  Future<List<LoopMfaEnrollment>> removeTotp() async {
    removals += 1;
    final error = removeFailure;
    if (error != null) throw error;
    return afterRemove ?? const <LoopMfaEnrollment>[];
  }
}
