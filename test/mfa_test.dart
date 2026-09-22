import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/features/security/mfa/passkey_sheet.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/integrations/privy/privy_mfa_gateway.dart';

import 'support/loop_ground_probe.dart';

void main() {
  group('privy relying party', () {
    test('the SDK is handed an https origin, never a bare domain', () {
      // iPhone 14 Pro Max, 2026-09-22: the bare domain LOOP configures as
      // the RP ID came back from the Privy SDK as
      // passkeyCreationFailed("Invalid relying party URL").
      expect(
        privyRelyingPartyOrigin('api-dev.quant-dinger.cc'),
        'https://api-dev.quant-dinger.cc',
      );
      expect(
        privyRelyingPartyOrigin(' api-dev.quant-dinger.cc '),
        'https://api-dev.quant-dinger.cc',
      );
      expect(
        privyRelyingPartyOrigin('https://api-dev.quant-dinger.cc'),
        'https://api-dev.quant-dinger.cc',
      );
    });
  });

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

  group('binding a passkey', () {
    const bound = LoopPasskeyCredential(
      credentialId: 'cred-1',
      label: 'iPhone',
    );

    test(
      'a build with no domain credential asks the platform nothing',
      () async {
        final gateway = _FakeMfaGateway(relyingParty: null);
        final container = _container(gateway);
        final controller = container.read(loopMfaProvider.notifier);
        await controller.load();

        expect(await controller.linkPasskey(), isFalse);

        expect(gateway.links, 0);
        expect(
          container.read(loopMfaProvider).failure,
          LoopMfaFailureKind.passkeyDomainUnconfigured,
        );
        expect(container.read(loopMfaProvider).hasPasskey, isFalse);
        expect(
          loopMfaFailureText(LoopMfaFailureKind.passkeyDomainUnconfigured),
          contains('域名凭据'),
        );
      },
    );

    test(
      'the account has a passkey only because the provider said so',
      () async {
        final gateway = _FakeMfaGateway(
          afterLink: const <LoopPasskeyCredential>[bound],
        );
        final container = _container(gateway);
        final controller = container.read(loopMfaProvider.notifier);
        await controller.load();
        expect(container.read(loopMfaProvider).hasPasskey, isFalse);

        expect(await controller.linkPasskey(), isTrue);

        final state = container.read(loopMfaProvider);
        expect(state.passkeys, <LoopPasskeyCredential>[bound]);
        expect(state.passkeyWorking, isFalse);
        // A way back in is not a second factor.
        expect(state.hasPasskeyMfa, isFalse);
      },
    );

    test('a dismissed system prompt binds nothing and says so', () async {
      final gateway = _FakeMfaGateway(
        linkFailure: const LoopMfaException(
          LoopMfaFailureKind.cancelled,
          providerMessage: 'androidx.credentials … activity is cancelled',
        ),
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.linkPasskey(), isFalse);

      final state = container.read(loopMfaProvider);
      expect(state.failure, LoopMfaFailureKind.cancelled);
      expect(state.hasPasskey, isFalse);
      // The provider's own words stay in the log, never on the page.
      expect(state.providerMessage, contains('androidx.credentials'));
    });

    test('unbinding needs the device first, and then the provider', () async {
      final gateway = _FakeMfaGateway(
        passkeys: const <LoopPasskeyCredential>[bound],
      );
      final authenticator = _FakeAuthenticator();
      final container = _container(gateway, authenticator: authenticator);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.unlinkPasskey('cred-1'), isTrue);

      expect(authenticator.prompts, 1);
      expect(gateway.unlinked, <String>['cred-1']);
      expect(container.read(loopMfaProvider).hasPasskey, isFalse);
    });

    test('a device with nothing to ask with is not a refusal', () async {
      final gateway = _FakeMfaGateway(
        passkeys: const <LoopPasskeyCredential>[bound],
      );
      final authenticator = _FakeAuthenticator(available: false);
      final container = _container(gateway, authenticator: authenticator);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.unlinkPasskey('cred-1'), isTrue);

      // Nothing was asked, because there was nothing to ask.
      expect(authenticator.prompts, 0);
      expect(gateway.unlinked, <String>['cred-1']);
    });

    test('a provider that refused the unbind changes nothing', () async {
      final gateway = _FakeMfaGateway(
        passkeys: const <LoopPasskeyCredential>[bound],
        unlinkFailure: const LoopMfaException(
          LoopMfaFailureKind.notAuthenticated,
        ),
      );
      final container = _container(
        gateway,
        authenticator: _FakeAuthenticator(),
      );
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.unlinkPasskey('cred-1'), isFalse);

      expect(container.read(loopMfaProvider).hasPasskey, isTrue);
      expect(
        container.read(loopMfaProvider).failure,
        LoopMfaFailureKind.notAuthenticated,
      );
    });

    test(
      'a device that said no leaves the passkey exactly where it was',
      () async {
        final gateway = _FakeMfaGateway(
          passkeys: const <LoopPasskeyCredential>[bound],
        );
        final container = _container(
          gateway,
          authenticator: _FakeAuthenticator(
            outcome: LoopDeviceAuthOutcome.canceled,
          ),
        );
        final controller = container.read(loopMfaProvider.notifier);
        await controller.load();

        expect(await controller.unlinkPasskey('cred-1'), isFalse);

        expect(gateway.unlinked, isEmpty);
        expect(container.read(loopMfaProvider).hasPasskey, isTrue);
        expect(
          container.read(loopMfaProvider).failure,
          LoopMfaFailureKind.cancelled,
        );
      },
    );
  });

  group('passkey as a second factor', () {
    test('an account with no passkey gets one before it is enrolled', () async {
      final gateway = _FakeMfaGateway();
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.enablePasskeyMfa(), isTrue);

      expect(gateway.links, 1);
      // The credential enrolled is the one the link call answered with.
      expect(gateway.enrolledPasskeys, <List<String>>[
        <String>['cred-1'],
      ]);
      expect(container.read(loopMfaProvider).hasPasskeyMfa, isTrue);
    });

    test(
      'an account that already has one is not asked to make another',
      () async {
        final gateway = _FakeMfaGateway(
          passkeys: const <LoopPasskeyCredential>[
            LoopPasskeyCredential(credentialId: 'cred-9'),
          ],
        );
        final container = _container(gateway);
        final controller = container.read(loopMfaProvider.notifier);
        await controller.load();

        expect(await controller.enablePasskeyMfa(), isTrue);

        expect(gateway.links, 0);
        expect(gateway.enrolledPasskeys, <List<String>>[
          <String>['cred-9'],
        ]);
      },
    );

    test('a device with no passkey provider enrols nothing', () async {
      final gateway = _FakeMfaGateway(
        passkeys: const <LoopPasskeyCredential>[
          LoopPasskeyCredential(credentialId: 'cred-9'),
        ],
        passkeyMfaFailure: const LoopMfaException(
          LoopMfaFailureKind.deviceUnsupported,
          providerMessage: 'CreateCredentialProviderConfigurationException',
        ),
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.enablePasskeyMfa(), isFalse);

      final state = container.read(loopMfaProvider);
      expect(state.hasPasskeyMfa, isFalse);
      expect(state.failure, LoopMfaFailureKind.deviceUnsupported);
      expect(state.passkeyWorking, isFalse);
    });

    test('switching the factor off keeps the way back in', () async {
      final gateway = _FakeMfaGateway(
        enrollments: const <LoopMfaEnrollment>[
          LoopMfaEnrollment(kind: LoopMfaMethodKind.passkey),
        ],
        passkeys: const <LoopPasskeyCredential>[
          LoopPasskeyCredential(credentialId: 'cred-1', enrolledInMfa: true),
        ],
      );
      final container = _container(gateway);
      final controller = container.read(loopMfaProvider.notifier);
      await controller.load();

      expect(await controller.disablePasskeyMfa(), isTrue);

      expect(gateway.passkeyMfaRemovals, 1);
      final state = container.read(loopMfaProvider);
      expect(state.hasPasskeyMfa, isFalse);
      expect(state.hasPasskey, isTrue);
    });

    testWidgets('04 names Passkey once the provider reported it', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          mfa: const LoopMfaState(
            phase: LoopMfaPhase.known,
            enrollments: <LoopMfaEnrollment>[
              LoopMfaEnrollment(kind: LoopMfaMethodKind.passkey),
            ],
          ),
          onOpenMfa: () {},
        ),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-mfa')),
      );
      expect(row.trailing, '已开启');
      expect(row.subtitle, contains('Passkey'));
    });

    testWidgets('the sheet offers Passkey beside the authenticator app', (
      tester,
    ) async {
      final container = _container(_FakeMfaGateway());
      await container.read(loopMfaProvider.notifier).load();
      await _pumpSheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-passkey')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-begin')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('mfa-sheet-passkey')));
      await tester.pumpAndSettle();

      expect(container.read(loopMfaProvider).hasPasskeyMfa, isTrue);
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('mfa-sheet-passkey')),
            )
            .label,
        '关闭 Passkey 验证',
      );
    });

    testWidgets('a build with no domain credential offers no passkey button', (
      tester,
    ) async {
      final container = _container(_FakeMfaGateway(relyingParty: null));
      await container.read(loopMfaProvider.notifier).load();
      await _pumpSheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-passkey')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mfa-sheet-passkey-unavailable')),
        findsOneWidget,
      );
    });
  });

  group('03 reports the passkey the provider holds', () {
    testWidgets('no domain credential leaves the row unavailable', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('wallet-recovery'),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('recovery-passkey')),
      );
      expect(row.trailing, '不可用');
      expect(row.onTap, isNull);
      expect(row.subtitle, contains(loopPasskeyDomainPending));
    });

    testWidgets('a configured build opens the binding sheet', (tester) async {
      var opened = 0;
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-recovery',
          capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
          mfa: const LoopMfaState(phase: LoopMfaPhase.known),
          onOpenPasskey: () => opened += 1,
        ),
      );

      final finder = find.byKey(const ValueKey<String>('recovery-passkey'));
      expect(tester.widget<LoopRecordRow>(finder).trailing, '可用');

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('a bound passkey says 已设置 and can be opened again', (
      tester,
    ) async {
      var opened = 0;
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-recovery',
          capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
          mfa: const LoopMfaState(
            phase: LoopMfaPhase.known,
            passkeys: <LoopPasskeyCredential>[
              LoopPasskeyCredential(credentialId: 'cred-1', label: 'iPhone'),
            ],
          ),
          onOpenPasskey: () => opened += 1,
        ),
      );

      final finder = find.byKey(const ValueKey<String>('recovery-passkey'));
      final row = tester.widget<LoopRecordRow>(finder);
      expect(row.trailing, '已设置');
      expect(row.subtitle, contains('iPhone'));
      // Nothing more to add is not what this page says once one is bound.
      expect(
        find.byKey(const ValueKey<String>('wallet-recovery-unavailable')),
        findsNothing,
      );

      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets('an unread provider never claims a passkey', (tester) async {
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-recovery',
          capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
          mfa: const LoopMfaState(phase: LoopMfaPhase.unavailable),
          onOpenPasskey: () {},
        ),
      );

      expect(
        tester
            .widget<LoopRecordRow>(
              find.byKey(const ValueKey<String>('recovery-passkey')),
            )
            .trailing,
        '可用',
      );
    });
  });

  group('the passkey binding sheet', () {
    testWidgets('an account with none is told so, and offered one', (
      tester,
    ) async {
      final gateway = _FakeMfaGateway();
      final container = _container(gateway);
      await _pumpPasskeySheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-empty')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('passkey-sheet-link')),
      );
      await tester.pumpAndSettle();

      expect(gateway.links, 1);
      expect(
        find.byKey(const ValueKey<String>('passkey-cred-1')),
        findsOneWidget,
      );
    });

    testWidgets('unbinding is never one tap', (tester) async {
      final gateway = _FakeMfaGateway(
        passkeys: const <LoopPasskeyCredential>[
          LoopPasskeyCredential(credentialId: 'cred-1', label: 'iPhone'),
        ],
      );
      final container = _container(
        gateway,
        authenticator: _FakeAuthenticator(),
      );
      await _pumpPasskeySheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-unlink')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('passkey-cred-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-confirm')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('passkey-sheet-unlink')),
      );
      await tester.pumpAndSettle();

      expect(gateway.unlinked, <String>['cred-1']);
      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-empty')),
        findsOneWidget,
      );
    });

    testWidgets('a build with no domain credential binds nothing', (
      tester,
    ) async {
      final gateway = _FakeMfaGateway(relyingParty: null);
      final container = _container(gateway);
      await _pumpPasskeySheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-link')),
        findsNothing,
      );
      expect(gateway.links, 0);
    });

    testWidgets('a provider that could not be asked claims nothing', (
      tester,
    ) async {
      final container = _container(
        _FakeMfaGateway(
          failure: const LoopMfaException(LoopMfaFailureKind.unavailable),
        ),
      );
      await _pumpPasskeySheet(tester, container);

      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-unknown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('passkey-sheet-empty')),
        findsNothing,
      );
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

ProviderContainer _container(
  LoopMfaGateway gateway, {
  LoopDeviceAuthenticator? authenticator,
}) {
  final container = ProviderContainer(
    overrides: [
      loopMfaGatewayProvider.overrideWithValue(gateway),
      if (authenticator != null)
        loopDeviceAuthenticatorProvider.overrideWithValue(authenticator),
    ],
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

Future<void> _pumpPasskeySheet(
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
                onPressed: () => showLoopPasskeySheet(context),
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
    this.passkeys = const <LoopPasskeyCredential>[],
    this.afterSubmit,
    this.afterRemove,
    this.afterLink,
    this.failure,
    this.beginFailure,
    this.submitFailure,
    this.removeFailure,
    this.linkFailure,
    this.unlinkFailure,
    this.passkeyMfaFailure,
    this.relyingParty = 'api-dev.quant-dinger.cc',
  });

  final List<LoopMfaEnrollment> enrollments;
  final List<LoopPasskeyCredential> passkeys;
  final List<LoopMfaEnrollment>? afterSubmit;
  final List<LoopMfaEnrollment>? afterRemove;
  final List<LoopPasskeyCredential>? afterLink;
  final LoopMfaException? failure;
  final LoopMfaException? beginFailure;
  final LoopMfaException? submitFailure;
  final LoopMfaException? removeFailure;
  final LoopMfaException? linkFailure;
  final LoopMfaException? unlinkFailure;
  final LoopMfaException? passkeyMfaFailure;
  final String? relyingParty;

  final List<String> submitted = <String>[];
  final List<String> unlinked = <String>[];
  final List<List<String>> enrolledPasskeys = <List<String>>[];
  int removals = 0;
  int links = 0;
  int passkeyMfaRemovals = 0;

  @override
  String? get passkeyRelyingParty => relyingParty;

  @override
  Future<LoopSecondFactorFacts> readSecondFactor() async {
    final error = failure;
    if (error != null) throw error;
    return _facts();
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
  Future<LoopSecondFactorFacts> completeTotpEnrollment(String code) async {
    submitted.add(code);
    final error = submitFailure;
    if (error != null) throw error;
    return _facts(enrollments: afterSubmit);
  }

  @override
  Future<LoopSecondFactorFacts> removeTotp() async {
    removals += 1;
    final error = removeFailure;
    if (error != null) throw error;
    return _facts(enrollments: afterRemove ?? const <LoopMfaEnrollment>[]);
  }

  @override
  Future<LoopSecondFactorFacts> linkPasskey() async {
    links += 1;
    final error = linkFailure;
    if (error != null) throw error;
    return _facts(passkeys: afterLink ?? _linked);
  }

  @override
  Future<LoopSecondFactorFacts> unlinkPasskey(String credentialId) async {
    unlinked.add(credentialId);
    final error = unlinkFailure;
    if (error != null) throw error;
    return _facts(passkeys: const <LoopPasskeyCredential>[]);
  }

  @override
  Future<LoopSecondFactorFacts> enrollPasskeyMfa(
    List<String> credentialIds,
  ) async {
    enrolledPasskeys.add(credentialIds);
    final error = passkeyMfaFailure;
    if (error != null) throw error;
    return _facts(
      enrollments: <LoopMfaEnrollment>[
        ...enrollments,
        const LoopMfaEnrollment(kind: LoopMfaMethodKind.passkey),
      ],
      passkeys: afterLink ?? (passkeys.isEmpty ? _linked : passkeys),
    );
  }

  @override
  Future<LoopSecondFactorFacts> removePasskeyMfa() async {
    passkeyMfaRemovals += 1;
    final error = passkeyMfaFailure;
    if (error != null) throw error;
    return _facts(
      enrollments: <LoopMfaEnrollment>[
        for (final one in enrollments)
          if (one.kind != LoopMfaMethodKind.passkey) one,
      ],
    );
  }

  static const _linked = <LoopPasskeyCredential>[
    LoopPasskeyCredential(credentialId: 'cred-1', label: 'iPhone'),
  ];

  LoopSecondFactorFacts _facts({
    List<LoopMfaEnrollment>? enrollments,
    List<LoopPasskeyCredential>? passkeys,
  }) {
    return LoopSecondFactorFacts(
      enrollments: enrollments ?? this.enrollments,
      passkeys: passkeys ?? this.passkeys,
    );
  }
}

/// A device that answers the App lock's prompt however a test needs.
final class _FakeAuthenticator implements LoopDeviceAuthenticator {
  _FakeAuthenticator({this.available = true, this.outcome});

  final bool available;
  final LoopDeviceAuthOutcome? outcome;
  int prompts = 0;

  @override
  Future<LoopDeviceAuthCapability> readCapability() async => available
      ? const LoopDeviceAuthCapability.available(LoopDeviceAuthFactor.biometric)
      : const LoopDeviceAuthCapability.unavailable(
          LoopDeviceAuthUnavailableReason.noCredentialSet,
        );

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async {
    prompts += 1;
    return LoopDeviceAuthResult(outcome ?? LoopDeviceAuthOutcome.succeeded);
  }
}
