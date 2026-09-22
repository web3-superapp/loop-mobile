import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';

/// Decision 0076: the moment, not just the condition.
///
/// The landing is published *before* the frame that draws Community — the end
/// of the opening publishes it and then navigates, and a restored session
/// publishes it and lets the launch gate refresh the router. A prompt raised
/// there sits over 创建钱包 or over the launch page, which is exactly what
/// this decision moved it away from. So the whole application is mounted here
/// and the prompt is counted against the location on screen.
void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  testWidgets('nothing is asked until a product frame has been drawn', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, settle: false);

    expect(harness.router.state.matchedLocation, isNot('/community'));
    expect(find.byType(LoopShell), findsNothing);

    // Frame by frame up to the first product frame. The landing is published
    // somewhere in here, and the router's location changes with it — which is
    // exactly why neither may raise the dialog by itself.
    // Frame by frame up to the first product frame. The landing is published
    // somewhere in here and the launch page is still what the owner is
    // looking at, which is the whole of what 0076 moved the dialog away from.
    var frames = 0;
    while (find.byType(LoopShell).evaluate().isEmpty) {
      if (harness.router.state.matchedLocation != '/community') {
        expect(
          harness.source.permissionRequests,
          0,
          reason: '还停在启动页或开号步骤上，不能弹系统通知授权',
        );
        expect(harness.gateway.registered, isEmpty);
      }
      frames += 1;
      expect(frames, lessThan(120), reason: '这个 build 根本没有走到产品页');
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.pumpAndSettle();

    expect(harness.router.state.matchedLocation, '/community');
    expect(harness.source.permissionRequests, 1);
    expect(harness.gateway.registered, hasLength(1));
    expect(harness.diagnostics.value.gate, LoopPushRegistrationGate.registered);
  });

  testWidgets('returning to Community does not ask a second time', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    expect(harness.source.permissionRequests, 1);

    harness.router.go('/market');
    await tester.pumpAndSettle();
    harness.router.go('/community');
    await tester.pumpAndSettle();

    expect(harness.source.permissionRequests, 1);
    expect(harness.gateway.registered, hasLength(1));
  });
}

final class _Harness {
  _Harness({
    required this.source,
    required this.gateway,
    required this.diagnostics,
  });

  late final GoRouter router;
  final _CountingPushTokenSource source;
  final _RecordingPushDeviceGateway gateway;
  final LoopPushRegistrationDiagnosticsRecorder diagnostics;
}

Future<_Harness> _pumpApp(WidgetTester tester, {bool settle = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final gateway = _RecordingPushDeviceGateway();
  final diagnostics = LoopPushRegistrationDiagnosticsRecorder();
  addTearDown(diagnostics.dispose);
  late final _Harness harness;
  // Counting is enough: the test pumps up to the first product frame itself
  // and checks the count on every frame before it. A location would not do —
  // the router's changes a whole frame earlier, inside the listener that
  // caused it.
  final source = _CountingPushTokenSource();
  harness = _Harness(
    source: source,
    gateway: gateway,
    diagnostics: diagnostics,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // A build with a client version, so `X-Loop-Platform` and the push
        // platform exist at all. No Stream key and no backend URL: nothing
        // in this test reaches a network.
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: 'app',
            privyAppClientId: 'client',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        // An account the server calls active: no opening sequence, and the
        // landing is published a turn after the session, as it is on a
        // restored session.
        profileGatewayProvider.overrideWithValue(
          const _ActiveProfileGateway(delay: Duration(milliseconds: 50)),
        ),
        loopOnboardingProgressStoreProvider.overrideWithValue(
          InMemoryLoopOnboardingProgressStore(),
        ),
        // The LOOP identity behind the session, which the registration may
        // not name an account without.
        loopBackendAccessTokenSourceProvider.overrideWithValue(
          _TestAccessTokens(),
        ),
        loopBootstrapRepositoryProvider.overrideWithValue(
          _TestBootstrapRepository(),
        ),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => s5MetaSnapshot(
            pushNotifications: LoopV2CapabilityAvailability.available,
          ),
        ),
        pushDeviceGatewayProvider.overrideWithValue(gateway),
        loopPushTokenSourceProvider.overrideWithValue(source),
        loopPushRegistrationDiagnosticsProvider.overrideWithValue(diagnostics),
      ],
      child: const LoopApp(),
    ),
  );
  // Bound before anything is allowed to settle, so the probe can answer from
  // the very first frame onwards.
  harness.router = GoRouter.of(tester.element(find.byType(Navigator).first));
  if (settle) await tester.pumpAndSettle();
  return harness;
}

const _firebaseToken = 'test-registration-token';

final class _CountingPushTokenSource implements LoopPushTokenSource {
  var permissionRequests = 0;

  @override
  bool get isEnabled => true;

  @override
  Future<LoopPushPermission> requestPermission() async {
    permissionRequests += 1;
    return LoopPushPermission.granted;
  }

  @override
  Future<LoopPushPermission> currentPermission() async =>
      LoopPushPermission.granted;

  @override
  Future<String?> currentToken() async => _firebaseToken;

  @override
  Future<String?> currentApnsToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Future<void> deleteToken() async {}
}

final class _RecordingPushDeviceGateway implements PushDeviceGateway {
  final registered = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  }) async {
    registered.add(token);
    return LoopPushTokenRegistration(
      registered: true,
      pushTokenId: '9e0f1a2b-3c4d-4e5f-8a6b-7c8d9e0f1a2b',
      platform: platform,
      provider: LoopPushTokenRegistration.firebaseProvider,
      appVersion: appVersion,
      observedAt: DateTime.utc(2026, 9, 22, 4, 5, 6),
    );
  }

  @override
  Future<LoopPushTokenRevocation> revokeToken() async =>
      LoopPushTokenRevocation(
        registered: false,
        revokedAt: null,
        observedAt: DateTime.utc(2026, 9, 22, 4, 10),
      );
}

final class _TestAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'privy-access-token';
}

final class _TestBootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: 'loop-user-a',
      streamUserId: 'stream-user-a',
    );
  }
}

final class _ActiveProfileGateway implements ProfileGateway {
  const _ActiveProfileGateway({this.delay = Duration.zero});

  final Duration delay;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return ProfileResource(
      version: 1,
      values: ProfileValues(alias: 'Voyager_7', avatarRef: null),
      updatedAt: DateTime.utc(2026, 9, 20, 6, 32),
      loopId: 'LOOP-7HJKMNPQ',
      profileStatus: ProfileStatus.active,
      activatedAt: DateTime.utc(2026, 9, 20, 6, 32),
    );
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => throw UnsupportedError('read-only test gateway');
}
