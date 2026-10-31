// S324 · decision 0254 · UX-001 / UX-002 / UX-008.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/account/privy_otp_screen.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';

final _base = DateTime.utc(2026, 10, 31, 1);
DateTime _now = _base;

void main() {
  loopWatchGround();
  setUp(() => _now = _base);

  group('UX-002 · the login page', () {
    testWidgets('three methods of one shape, the wallet link and the terms '
        'line at the foot', (tester) async {
      await _pumpLogin(tester, _Credential());

      for (final key in const <String>[
        'privy-apple-login-button',
        'privy-google-login-button',
        'privy-email-login-button',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))).height,
          AuthMethodButton.height + 12,
          reason: key,
        );
      }
      expect(find.text('使用 Apple 登录'), findsOneWidget);
      expect(find.text('使用 Google 登录'), findsOneWidget);
      expect(find.text('使用邮箱登录'), findsOneWidget);
      expect(find.text('选择一种方式登录或创建账户'), findsOneWidget);
      expect(find.textContaining('外部钱包只是登录凭证'), findsNothing);
      // The e-mail field is no longer on this page.
      expect(find.byKey(const ValueKey('privy-email-field')), findsNothing);

      final terms = find.byKey(const ValueKey('privy-auth-terms'));
      final wallet = find.byKey(const ValueKey('privy-wallet-login-button'));
      expect(terms, findsOneWidget);
      expect(
        tester.getTopLeft(terms).dy,
        greaterThan(tester.getBottomLeft(wallet).dy),
      );
      // The terms line sits at the foot of the screen, not under the buttons.
      expect(tester.getBottomLeft(terms).dy, greaterThan(2532 / 3 - 120));
    });

    testWidgets('pressing Apple puts only Apple into its busy state', (
      tester,
    ) async {
      final credential = _Credential();
      await _pumpLogin(tester, credential);

      await tester.tap(find.byKey(const ValueKey('privy-apple-login-button')));
      await tester.pump();

      expect(credential.calls, <PrivyOAuthLoginProvider>[
        PrivyOAuthLoginProvider.apple,
      ]);
      expect(_method(tester, 'privy-apple-login-button').busy, isTrue);
      expect(_method(tester, 'privy-google-login-button').busy, isFalse);
      expect(_method(tester, 'privy-email-login-button').busy, isFalse);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('privy-apple-login-button')),
          matching: find.byKey(const ValueKey('auth-method-busy')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('auth-method-busy')), findsOneWidget);
      expect(find.text('使用 Google 登录'), findsOneWidget);
      expect(find.text('使用邮箱登录'), findsOneWidget);
      expect(find.text('已有钱包？连接钱包', findRichText: true), findsOneWidget);
      expect(find.textContaining('发送中'), findsNothing);
      // The others wait, without claiming anything.
      expect(_method(tester, 'privy-google-login-button').onPressed, isNull);
      expect(_method(tester, 'privy-email-login-button').onPressed, isNull);
    });

    testWidgets('pressing Google puts only Google into its busy state', (
      tester,
    ) async {
      final credential = _Credential();
      await _pumpLogin(tester, credential);

      await tester.tap(find.byKey(const ValueKey('privy-google-login-button')));
      await tester.pump();

      expect(_method(tester, 'privy-google-login-button').busy, isTrue);
      expect(_method(tester, 'privy-apple-login-button').busy, isFalse);
      expect(_method(tester, 'privy-email-login-button').busy, isFalse);
      expect(find.text('使用 Google 登录…'), findsOneWidget);
      expect(find.text('使用 Apple 登录'), findsOneWidget);
    });

    testWidgets('an OAuth attempt never makes 获取验证码 say 发送中', (tester) async {
      final credential = _Credential();
      final container = await _pumpEmail(tester, credential);

      unawaited(container.read(emailAuthProvider.notifier).loginWithGoogle());
      await tester.pump();

      final send = tester.widget<LoopButton>(
        find.byKey(const ValueKey('privy-auth-primary-button')),
      );
      expect(send.label, '获取验证码');
      expect(send.onPressed, isNull);
    });

    testWidgets('only sending the code makes 获取验证码 say 发送中', (tester) async {
      final auth = _Session(holdSend: true);
      var sent = 0;
      final container = await _pumpEmail(
        tester,
        _Credential(),
        auth: auth,
        onCodeSent: () => sent += 1,
      );

      await tester.enterText(
        find.byKey(const ValueKey('privy-email-field')),
        'owner@example.com',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
      await tester.pump();

      expect(find.text('发送中…'), findsOneWidget);
      expect(
        container.read(emailAuthProvider).activeOperation,
        IdentityAuthOperation.sendEmailCode,
      );
      auth.releaseSend();
      await tester.pump();
      await tester.pump();
      expect(sent, 1);
    });
  });

  group('UX-002 · the code page', () {
    testWidgets('the countdown turns into 重新发送 in the same place', (
      tester,
    ) async {
      final container = await _pumpOtp(tester);

      final hint = find.byKey(const ValueKey('privy-otp-resend-hint'));
      expect(hint, findsOneWidget);
      expect(
        find.text('${emailAuthResendCooldown.inSeconds} 秒后可重新发送'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('privy-otp-resend')), findsNothing);
      final countdownCentre = tester.getCenter(hint);

      _now = _base.add(emailAuthResendCooldown);
      await tester.pump(const Duration(seconds: 1));

      final resend = find.byKey(const ValueKey('privy-otp-resend'));
      expect(hint, findsNothing);
      expect(resend, findsOneWidget);
      expect(find.text('重新发送'), findsOneWidget);
      expect(
        tester.getCenter(resend).dy,
        moreOrLessEquals(countdownCentre.dy, epsilon: 14),
      );
      expect(
        tester.getCenter(resend).dx,
        moreOrLessEquals(countdownCentre.dx, epsilon: 1),
      );

      await tester.tap(resend);
      await tester.pump();
      await tester.pump();
      expect(container.read(emailAuthProvider).resendAvailableAt, isNotNull);
      expect(
        find.byKey(const ValueKey('privy-otp-resend-hint')),
        findsOneWidget,
      );
    });

    testWidgets('继续 stays closed until all six digits are in', (tester) async {
      await _pumpOtp(tester);

      LoopButton next() => tester.widget<LoopButton>(
        find.byKey(const ValueKey('privy-auth-primary-button')),
      );
      expect(next().label, '继续');
      expect(next().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('privy-otp-field')),
        '84201',
      );
      await tester.pump();
      expect(next().onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('privy-otp-field')),
        '842011',
      );
      await tester.pump();
      expect(next().onPressed, isNotNull);
    });

    testWidgets('the removed lines stay removed and the address is masked', (
      tester,
    ) async {
      await _pumpOtp(tester, email: '1026276885@qq.com');

      expect(find.text('验证码已发送至 1026••••85@qq.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('privy-otp-change-email')),
        findsOneWidget,
      );
      expect(find.text('更换邮箱'), findsOneWidget);
      expect(find.textContaining('还可尝试'), findsNothing);
      expect(find.textContaining('垃圾邮件'), findsNothing);
      expect(find.text('换个邮箱'), findsNothing);
      expect(find.byType(LoopButtonPair), findsNothing);
      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets(
      'UX-008 · the cells are rounded and the waiting one is Purple',
      (tester) async {
        await _pumpOtp(tester);
        await tester.tap(find.byKey(const ValueKey('privy-otp-field')));
        await tester.pump();

        BoxDecoration cell(int index) =>
            tester
                    .widget<Container>(
                      find.byKey(ValueKey<String>('privy-otp-cell-$index')),
                    )
                    .decoration!
                as BoxDecoration;
        expect(cell(1).borderRadius, LoopRadius.control);
        expect(cell(6).borderRadius, LoopRadius.control);
        expect((cell(1).border! as Border).top.color, LoopColors.purple);
        expect((cell(2).border! as Border).top.color, isNot(LoopColors.purple));
        expect((cell(1).border! as Border).top.color, isNot(LoopColors.yellow));
      },
    );
  });

  group('UX-001 · one launch frame', () {
    testWidgets('restoring, the hand-over and the launch page put the mark in '
        'the same place', (tester) async {
      final rects = <Rect>[];
      for (final frame in <Widget>[
        const PrivySessionRestoreScreen(),
        const PrivySessionHandoverFrame(),
        const AccountSurfaceScreen.fromId(
          'splash',
          splashPhase: LoopSplashPhase.preparingAccount,
        ),
      ]) {
        await _pumpBare(tester, frame);
        rects.add(
          tester.getRect(
            find.descendant(
              of: find.byType(LoopLaunchFrame),
              matching: find.byType(LoopBrandMark),
            ),
          ),
        );
      }
      expect(rects[1], rects[0]);
      expect(rects[2], rects[0]);
      // The native launch image is 103 pt tall, centred on the screen.
      expect(rects[0].height, LoopLaunchFrame.markHeight);
      expect(rects[0].center.dy, moreOrLessEquals(2532 / 3 / 2, epsilon: 1));
    });

    testWidgets('the hand-over already says what the launch page says', (
      tester,
    ) async {
      await _pumpBare(tester, const PrivySessionHandoverFrame());
      expect(find.text(SplashScreen.preparingText), findsOneWidget);
      await _pumpBare(
        tester,
        const AccountSurfaceScreen.fromId(
          'splash',
          splashPhase: LoopSplashPhase.preparingAccount,
        ),
      );
      expect(find.text(SplashScreen.preparingText), findsOneWidget);
    });

    testWidgets('a long wait changes only the line', (tester) async {
      await _pumpBare(tester, const PrivySessionRestoreScreen());
      final mark = tester.getRect(find.byType(LoopBrandMark));
      expect(
        find.text(PrivySessionRestoreScreen.restoringTitle),
        findsOneWidget,
      );

      await tester.pump(PrivySessionRestoreScreen.slowAfter);
      expect(find.text(PrivySessionRestoreScreen.slowMessage), findsOneWidget);
      expect(find.text(PrivySessionRestoreScreen.restoringTitle), findsNothing);
      expect(tester.getRect(find.byType(LoopBrandMark)), mark);
    });
  });
}

AuthMethodButton _method(WidgetTester tester, String key) =>
    tester.widget<AuthMethodButton>(find.byKey(ValueKey<String>(key)));

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpBare(WidgetTester tester, Widget child) async {
  _tall(tester);
  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: child));
  await tester.pump();
}

List<Override> _overrides(_Credential credential, _Session auth) => <Override>[
  appConfigProvider.overrideWithValue(
    const AppConfig(
      privyAppId: 'privy-app',
      privyAppClientId: 'privy-client',
      reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
      streamApiKey: '',
      backendBaseUrl: '',
      firebaseConfigured: false,
    ),
  ),
  privyAuthGatewayProvider.overrideWithValue(auth),
  privyCredentialGatewayProvider.overrideWithValue(credential),
  isIosIdentityPlatformProvider.overrideWithValue(true),
  loopFeatureSwitchesProvider.overrideWithValue(
    const LoopFeatureSwitchValues(appleLoginVisible: true),
  ),
  loopDeviceClockProvider.overrideWithValue(() => _now),
];

Future<void> _pumpLogin(WidgetTester tester, _Credential credential) async {
  _tall(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(credential, _Session()),
      child: MaterialApp(theme: LoopTheme.dark, home: const PrivyLoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpEmail(
  WidgetTester tester,
  _Credential credential, {
  _Session? auth,
  VoidCallback? onCodeSent,
}) async {
  _tall(tester);
  final container = ProviderContainer(
    overrides: _overrides(credential, auth ?? _Session()),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const _SignedOutProbe(),
        routes: <String, WidgetBuilder>{
          '/email': (_) => PrivyEmailScreen(onCodeSent: onCodeSent),
        },
      ),
    ),
  );
  // The session answers 「signed out」 before the step is opened.
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  unawaited(navigator.pushNamed('/email'));
  await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> _pumpOtp(
  WidgetTester tester, {
  String email = 'owner@example.com',
}) async {
  _tall(tester);
  final container = ProviderContainer(
    overrides: _overrides(_Credential(), _Session()),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: LoopTheme.dark, home: const PrivyOtpScreen()),
    ),
  );
  await container.read(emailAuthProvider.notifier).sendCode(email);
  await tester.pump();
  await tester.pump();
  return container;
}

/// Reads the session once so it starts restoring and settles signed out.
class _SignedOutProbe extends ConsumerWidget {
  const _SignedOutProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(emailAuthProvider);
    return const PrivyLoginScreen();
  }
}

class _Session implements PrivyAuthGateway {
  _Session({this.holdSend = false});

  final bool holdSend;
  final Completer<void> _sendGate = Completer<void>();

  void releaseSend() {
    if (!_sendGate.isCompleted) _sendGate.complete();
  }

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() async =>
      const PrivySessionSnapshot(PrivySessionKind.unauthenticated);

  @override
  Future<void> sendEmailCode(String email) async {
    if (holdSend) await _sendGate.future;
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) => Completer<PrivyAccountSummary>().future;

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}

/// An OAuth provider that never answers, so the busy state can be read.
class _Credential implements PrivyCredentialGateway {
  final calls = <PrivyOAuthLoginProvider>[];

  @override
  Future<PrivyAccountSummary> loginWithOAuth(PrivyOAuthLoginProvider provider) {
    calls.add(provider);
    return Completer<PrivyAccountSummary>().future;
  }

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) =>
      throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> unlinkSiwe({
    required String address,
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) => throw UnimplementedError();
}
