import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_coordinator.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_providers.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/firebase_options.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_push_device_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/communication/stream_push_device_registrar.dart';
import 'package:loop_mobile/integrations/notifications/firebase_notification_ingress.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

import 'support/s5_fixtures.dart';

const _accessToken = 'privy-access-token';
const _principal = 'did:privy:user-a';
const _deviceId = '3f7c1a2b-4d5e-4f60-8a71-9b2c3d4e5f60';
const _sessionId = '5a716283-9c0d-4e1f-8a2b-3c4d5e6f7081';
const _idempotencyKey = '7c8d9e0f-1a2b-4c3d-8e4f-5a6b7c8d9e0f';
const _pushTokenId = '9e0f1a2b-3c4d-4e5f-8a6b-7c8d9e0f1a2b';
const _firebaseToken =
    'f7Qk2n9XsZ0AbCdEfGhIjKlMnOpQrStUvWxYz012345678-_abcdefghijklmnop';
const _rotatedFirebaseToken =
    'z9Yx8w7VuTsRqPoNmLkJiHgFeDcBa0123456789-_abcdefghijklmnopqrstuvw';
const _apnsToken =
    '740f4707bebcf74f9b7c25d48e3358945f6aa01da5ddb387462c7eaf61bb78ad';

void main() {
  group('Firebase 只在这个 build 真的配置过时才启动', () {
    test('没有配置就不是一个可以初始化的 build', () {
      expect(_config(firebaseConfigured: false).canInitializeFirebase, isFalse);
    });

    test('build profile 对不上时，配置齐全也不初始化', () {
      expect(
        _config(
          firebaseConfigured: true,
          declaredModeMatchesRuntime: false,
        ).canInitializeFirebase,
        isFalse,
      );
    });

    test('两个条件都成立才初始化', () {
      expect(_config(firebaseConfigured: true).canInitializeFirebase, isTrue);
    });

    test('两个平台的 options 就是 Firebase 控制台给的那一份', () {
      expect(DefaultFirebaseOptions.projectId, 'loop-d4746');
      expect(DefaultFirebaseOptions.android.messagingSenderId, '225868941577');
      expect(
        DefaultFirebaseOptions.android.appId,
        '1:225868941577:android:fe779e131119af7c64abd8',
      );
      expect(
        DefaultFirebaseOptions.ios.appId,
        '1:225868941577:ios:7d96d5ce4f5679a464abd8',
      );
      expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.cywd.loop');
      expect(
        DefaultFirebaseOptions.ios.projectId,
        DefaultFirebaseOptions.android.projectId,
      );
    });

    test('只有注册过的两个平台有 options，其他平台是「没有」而不是崩溃', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        DefaultFirebaseOptions.currentPlatformOrNull,
        same(DefaultFirebaseOptions.android),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        DefaultFirebaseOptions.currentPlatformOrNull,
        same(DefaultFirebaseOptions.ios),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(DefaultFirebaseOptions.currentPlatformOrNull, isNull);
      expect(
        () => DefaultFirebaseOptions.currentPlatform,
        throwsUnsupportedError,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('没有 provider 的组合里，通知入口和令牌来源都还是关着的', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(loopNotificationEventSourceProvider),
        isA<DisabledLoopNotificationEventSource>(),
      );
      expect(
        container.read(loopPushTokenSourceProvider),
        isA<DisabledLoopPushTokenSource>(),
      );
      expect(
        container.read(pushDeviceGatewayProvider),
        isA<UnavailablePushDeviceGateway>(),
      );
    });
  });

  group('设备令牌上报（0067）', () {
    test('注册带上整套登出头集合，包括一枚 Idempotency-Key', () async {
      RequestOptions? captured;
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, _registrationBody()));
        }),
      );

      final registration = await api.registerToken(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        platform: LoopPushPlatform.android,
        token: _firebaseToken,
        appVersion: s5ClientVersion,
        command: _command(),
      );

      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/devices/push-token');
      final headers = captured!.headers;
      expect(headers['authorization'], 'Bearer $_accessToken');
      expect(headers['x-loop-contract-version'], '2.0');
      expect(headers['x-loop-client-version'], s5ClientVersion);
      expect(headers['x-loop-platform'], 'android');
      expect(headers['x-loop-device-id'], _deviceId);
      expect(headers['x-loop-session-id'], _sessionId);
      expect(headers['idempotency-key'], _idempotencyKey);
      expect(captured!.data, <String, Object?>{
        'platform': 'android',
        'token': _firebaseToken,
        'appVersion': s5ClientVersion,
      });
      expect(registration.registered, isTrue);
      expect(registration.pushTokenId, _pushTokenId);
      expect(registration.provider, 'fcm');
      expect(registration.observedAt, DateTime.utc(2026, 9, 22, 4, 5, 6));
    });

    test('body 里的 platform 与头不一致时，请求根本不会发出去', () async {
      var sent = false;
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          sent = true;
          handler.resolve(s5Response(options, _registrationBody()));
        }),
      );

      await expectLater(
        api.registerToken(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          platform: LoopPushPlatform.ios,
          token: _firebaseToken,
          appVersion: s5ClientVersion,
          command: _command(),
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(sent, isFalse, reason: '这样的请求只会白烧掉一枚幂等键');
    });

    test('服务端说 registered:false 时，200 也不算注册成功', () async {
      final api = DioLoopV2PushDeviceApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _registrationBody(registered: false)),
          ),
        ),
      );

      await expectLater(
        _register(api),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('回执必须是对这台设备说的：平台、版本、provider 都要对得上', () async {
      for (final body in <Map<String, Object?>>[
        _registrationBody()..['platform'] = 'ios',
        _registrationBody()..['provider'] = 'apns',
        _registrationBody()..['appVersion'] = '9.9.9',
      ]) {
        final api = DioLoopV2PushDeviceApi(
          s5Dio(
            (options, handler) => handler.resolve(s5Response(options, body)),
          ),
        );

        await expectLater(
          _register(api),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test('多出来或少掉的字段都是无效响应，不是可以只读一半的响应', () async {
      final extra = _registrationBody()..['surprise'] = true;
      final missing = _registrationBody()..remove('pushTokenId');

      for (final body in <Map<String, Object?>>[extra, missing]) {
        final api = DioLoopV2PushDeviceApi(
          s5Dio(
            (options, handler) => handler.resolve(s5Response(options, body)),
          ),
        );

        await expectLater(
          _register(api),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test('不像令牌的东西根本不会被送出去', () async {
      var sent = false;
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          sent = true;
          handler.resolve(s5Response(options, _registrationBody()));
        }),
      );

      await expectLater(
        api.registerToken(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          platform: LoopPushPlatform.android,
          token: 'https://example.invalid/steal?token=$_firebaseToken',
          appVersion: s5ClientVersion,
          command: _command(),
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(sent, isFalse);
    });

    test('后端没配 Firebase 凭据时是 503，客户端读成 unavailable', () async {
      final api = DioLoopV2PushDeviceApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(
              options,
              statusCode: 503,
              code: 'CAPABILITY_UNAVAILABLE',
            ),
          ),
        ),
      );

      await expectLater(
        _register(api),
        throwsA(_failure(LoopBackendFailureKind.unavailable)),
      );
    });

    test('撤销不带 body、不带查询串，只带这台设备的 session', () async {
      RequestOptions? captured;
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(s5Response(options, _revocationBody()));
        }),
      );

      final revocation = await api.revokeToken(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        command: _command(),
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.path, '/v2/devices/push-token');
      expect(captured!.uri.query, isEmpty);
      expect(captured!.data, isNull);
      expect(captured!.headers['idempotency-key'], _idempotencyKey);
      expect(revocation.registered, isFalse);
      expect(revocation.revokedAt, DateTime.utc(2026, 9, 22, 4, 10));
    });

    test('这台设备本来就没有令牌时，撤销照样是 200，revokedAt 为空', () async {
      final api = DioLoopV2PushDeviceApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, _revocationBody(revokedAt: null)),
          ),
        ),
      );

      final revocation = await api.revokeToken(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        command: _command(),
      );

      expect(revocation.registered, isFalse);
      expect(revocation.revokedAt, isNull);
    });
  });

  group('登录之后才注册，退出之前先撤销', () {
    test('没有账号时，既不问权限也不读令牌', () async {
      final harness = _Harness(principal: null);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.source.permissionRequests, 0);
      expect(harness.source.tokenReads, 0);
      expect(harness.gateway.registered, isEmpty);
    });

    test('后端网关还没装好时，不去打扰设备', () async {
      final harness = _Harness(principal: _principal, gatewayAvailable: false);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.source.permissionRequests, 0);
      expect(harness.gateway.registered, isEmpty);
    });

    test('capability 不是 available 时，连系统权限都不问', () async {
      final harness = _Harness(
        principal: _principal,
        pushCapabilityAvailable: false,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.source.permissionRequests, 0);
      expect(harness.gateway.registered, isEmpty);
    });

    test('设备拒绝通知时，不上报任何令牌，也不重复追问', () async {
      final harness = _Harness(
        principal: _principal,
        permission: LoopPushPermission.denied,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      harness.coordinator.onIdentityMayHaveChanged();
      await _settle();

      expect(harness.source.permissionRequests, 1);
      expect(harness.gateway.registered, isEmpty);
      expect(harness.stream.added, isEmpty);
    });

    test('Android：同一个 Firebase 令牌同时报给 LOOP 和 Stream', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gateway.registered, <String>[_firebaseToken]);
      expect(harness.gateway.appVersions, <String>[s5ClientVersion]);
      expect(harness.stream.added, <LoopStreamPushDevice>[
        const LoopStreamPushDevice(
          id: _firebaseToken,
          provider: LoopStreamPushProvider.firebase,
        ),
      ]);
    });

    test('iOS：LOOP 收 Firebase 令牌，Stream 收 APNs 令牌', () async {
      final harness = _Harness(
        principal: _principal,
        platform: LoopPushPlatform.ios,
        apnsToken: _apnsToken,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gateway.registered, <String>[
        _firebaseToken,
      ], reason: '决定 0067：iOS 也上报 FCM 令牌，APNs 由 Firebase 代发');
      expect(harness.gateway.platforms, <LoopPushPlatform>[
        LoopPushPlatform.ios,
      ]);
      expect(harness.stream.added, <LoopStreamPushDevice>[
        const LoopStreamPushDevice(
          id: _apnsToken,
          provider: LoopStreamPushProvider.apn,
        ),
      ]);
      expect(
        LoopStreamPushProvider.apn.configurationName,
        'LOOPAPNS',
        reason: 'Stream 后台里这份配置就叫这个名字',
      );
    });

    test('身份没变时不会重复注册', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      harness.coordinator.onIdentityMayHaveChanged();
      await _settle();

      expect(harness.gateway.registered, <String>[_firebaseToken]);
      expect(harness.source.permissionRequests, 1);
    });

    test('令牌轮换时重报新的；旧行由服务端在同一事务里作废', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      harness.source.emitRefresh(_rotatedFirebaseToken);
      await _settle();

      expect(harness.gateway.registered, <String>[
        _firebaseToken,
        _rotatedFirebaseToken,
      ]);
      expect(
        harness.gateway.revokeCalls,
        0,
        reason: 'DELETE 不带令牌，这时候调它只会删掉刚建好的那一行',
      );
      expect(harness.stream.added.map((device) => device.id), <String>[
        _firebaseToken,
        _rotatedFirebaseToken,
      ]);
      expect(harness.stream.removed.map((device) => device.id), <String>[
        _firebaseToken,
      ]);
    });

    test('后端返回 unavailable 时不再重试，也不登记到 Stream', () async {
      final harness = _Harness(principal: _principal, gatewayDefers: true);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      harness.coordinator.onIdentityMayHaveChanged();
      await _settle();

      expect(harness.gateway.registered, <String>[_firebaseToken]);
      expect(harness.coordinator.runtimeDeferred, isTrue);
      expect(harness.stream.added, isEmpty);
      expect(harness.coordinator.registeredToken, isNull);
    });

    test('退出时撤销后端与 Stream，并删掉设备上的令牌', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      await harness.coordinator.revokeForSignOut();

      expect(harness.gateway.revokeCalls, 1);
      expect(harness.stream.removed.map((device) => device.id), <String>[
        _firebaseToken,
      ]);
      expect(harness.source.deleted, 1);
      expect(harness.coordinator.registeredToken, isNull);
    });

    test('撤销卡住时不会把退出一起卡住', () async {
      final harness = _Harness(
        principal: _principal,
        revokeHangs: true,
        revokeTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      await harness.coordinator.revokeForSignOut();

      expect(harness.coordinator.registeredToken, isNull);
    });
  });

  group('设备登记停在哪一步，这台设备自己记得（S73）', () {
    test('一开始什么都还没试过', () {
      final diagnostics = LoopPushRegistrationDiagnosticsRecorder();
      addTearDown(diagnostics.dispose);

      expect(diagnostics.value.gate, LoopPushRegistrationGate.notStarted);
      expect(diagnostics.value.observedAt, isNull);
    });

    test('后端还没有认下这个账号时停在这里，也不会先弹权限', () async {
      final harness = _Harness(principal: null);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.noPrincipal);
      expect(
        harness.source.permissionRequests,
        0,
        reason: '没有账号就先弹通知权限，等于问一个还没决定要不要用 LOOP 的人',
      );
    });

    test('没有注册过推送应用的平台上，停在平台而不是账号', () async {
      final harness = _Harness(principal: null, platform: null);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.noPlatform);
    });

    test('设备登记端口不是生产口径时停在端口', () async {
      final harness = _Harness(principal: _principal, gatewayAvailable: false);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.gatewayNotProduction);
      expect(harness.source.permissionRequests, 0);
    });

    test('能力文档没有把推送算作可用时停在能力', () async {
      final harness = _Harness(
        principal: _principal,
        pushCapabilityAvailable: false,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.capabilityUnavailable);
      expect(harness.source.permissionRequests, 0);
    });

    test('这个 build 根本没有推送组件时，是「没有通道」而不是「被拒绝」', () async {
      final harness = _Harness(
        principal: _principal,
        permission: LoopPushPermission.unsupported,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.tokenSourceDisabled);
      expect(harness.gateway.registered, isEmpty);
    });

    test('拒绝了通知权限就记成拒绝', () async {
      final harness = _Harness(
        principal: _principal,
        permission: LoopPushPermission.denied,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.permissionDenied);
    });

    test('iOS 还没拿到令牌时是「在等」，不是失败', () async {
      final harness = _Harness(
        principal: _principal,
        platform: LoopPushPlatform.ios,
        hasToken: false,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.noTokenYet);
      expect(harness.gateway.registered, isEmpty);
    });

    test('登记成功就记成已登记，只留下一步和一个时间', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(
        harness.diagnostics.value,
        LoopPushRegistrationDiagnostics(
          gate: LoopPushRegistrationGate.registered,
          observedAt: DateTime.utc(2026, 9, 22, 4, 5, 6),
        ),
        reason: '诊断里不留令牌、地址或任何 payload',
      );
    });

    test('LOOP 说自己没有推送运行时，记成没有开放而不是失败', () async {
      final harness = _Harness(principal: _principal, gatewayDefers: true);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.runtimeDeferred);
    });

    test('登记失败时连失败的种类一起记下来', () async {
      final harness = _Harness(
        principal: _principal,
        gatewayFailure: LoopChainFailureKind.offline,
      );
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gate, LoopPushRegistrationGate.registerFailed);
      expect(
        harness.diagnostics.value.failureKind,
        LoopChainFailureKind.offline,
      );
    });

    test('后端认下账号之后再问一次，这时候才会请求权限并登记', () async {
      // 真机上的顺序：会话先变成已登录，LOOP 的身份要等 bootstrap 回来才存在。
      // 第一次问的时候还没有账号，之后没人再问过 —— 于是权限弹窗从未出现。
      final harness = _Harness(principal: null);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      expect(harness.gate, LoopPushRegistrationGate.noPrincipal);
      expect(harness.source.permissionRequests, 0);

      harness.principal = _principal;
      harness.coordinator.onIdentityMayHaveChanged();
      await _settle();

      expect(harness.source.permissionRequests, 1);
      expect(harness.gateway.registered, <String>[_firebaseToken]);
      expect(harness.gate, LoopPushRegistrationGate.registered);
    });
  });

  group('真机上拦住登记的是哪一道门（S73）', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    /// The real sequence: the session turns authenticated first, and the LOOP
    /// identity behind it only exists once `bootstrap` has answered. The
    /// bootstrap provider publishes one owner object and fills the identity
    /// into it afterwards, so a listener on that provider never sees the
    /// identity appear.
    test('会话已登录、LOOP 身份还没回来时，登记停在账号上，不会先弹权限', () async {
      final repository = _TestBootstrapRepository();
      final bootstrap = LoopBootstrapSession(
        principalKey: _principal,
        accessTokens: _TestAccessTokens(),
        repository: repository,
      );
      final diagnostics = LoopPushRegistrationDiagnosticsRecorder();
      final source = _TestPushTokenSource(
        permission: LoopPushPermission.granted,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            _config(firebaseConfigured: true),
          ),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          loopBootstrapSessionProvider.overrideWithValue(bootstrap),
          loopPushTokenSourceProvider.overrideWithValue(source),
          loopPushRegistrationDiagnosticsProvider.overrideWithValue(
            diagnostics,
          ),
        ],
      );
      addTearDown(container.dispose);
      var republished = 0;
      container.listen(
        loopBootstrapSessionProvider,
        (previous, next) => republished += 1,
      );

      container.read(loopPushRegistrationCoordinatorProvider).start();
      await _settle();

      expect(
        diagnostics.value.gate,
        LoopPushRegistrationGate.noPrincipal,
        reason: '这就是真机上的状态：登录成功、能用社区和语音房，推送权限却从未被问过',
      );
      expect(source.permissionRequests, 0);

      // The identity arrives. Nothing about the provider graph changes.
      expect(
        await bootstrap.authorize(),
        LoopBootstrapAuthorization.authorized,
      );
      expect(bootstrap.identity, isNotNull);
      expect(republished, 0, reason: '身份是填进同一个对象里的，监听这个 provider 的人看不到它出现');
      expect(
        diagnostics.value.gate,
        LoopPushRegistrationGate.noPrincipal,
        reason: '没有人再问过一次，所以登记还停在原地',
      );

      // Which is why the application has to ask again at exactly this point.
      container.read(loopPushRegistrationCoordinatorProvider)
        ..onIdentityMayHaveChanged()
        ..onIdentityMayHaveChanged();
      await _settle();

      expect(
        diagnostics.value.gate,
        isNot(LoopPushRegistrationGate.noPrincipal),
        reason: '这一次账号这道门是开的',
      );
    });
  });

  group('点开通知之后重新读状态，不信任 payload 说了什么', () {
    const session = LoopNotificationSessionContext.authenticated();

    LoopNotificationRouter router() =>
        LoopNotificationRouter(clock: () => DateTime.utc(2026, 9, 22, 12));

    test('payload 恰好四个键，多一个就整条作废', () {
      final decision = router().route(
        data: <String, Object?>{
          ..._pushPayload(LoopPushNotificationType.priceAlertTriggered),
          'contextParams': 'assetId=eip155:56:native',
        },
        ingress: LoopNotificationIngress.interaction,
        session: session,
      );

      expect(decision.disposition, LoopNotificationDisposition.malformed);
      expect(decision.pointer, isNull);
    });

    test('推送只给出一个指针，具体去哪一页要等 feed 回答', () {
      final decision = router().route(
        data: _pushPayload(LoopPushNotificationType.priceAlertTriggered),
        ingress: LoopNotificationIngress.interaction,
        session: session,
      );

      expect(decision.disposition, LoopNotificationDisposition.pointerReady);
      expect(
        LoopNotificationRouter.resolve(decision.pointer!).location,
        '/market/alerts',
        reason: '没有 feed 记录时，只能打开不指名任何资产的那一页',
      );
      expect(
        LoopNotificationRouter.resolve(
          decision.pointer!,
          context: const LoopNotificationContext(
            contextRoute: 'token',
            assetId: 'eip155:56:native',
          ),
        ).location,
        '/market/token?assetId=${Uri.encodeQueryComponent('eip155:56:native')}',
      );
    });

    test('前台收到时只是「看到了」，不跳转也不消费这次点击', () {
      final foreground = router().route(
        data: _pushPayload(LoopPushNotificationType.securityEvent),
        ingress: LoopNotificationIngress.foreground,
        session: session,
      );

      expect(
        foreground.disposition,
        LoopNotificationDisposition.foregroundObserved,
      );
      expect(foreground.pointer, isNull);
    });

    test('provider 的两条流合成一条，取消时两条都停', () async {
      final foreground = StreamController<LoopNotificationSourceEvent>();
      final opened = StreamController<LoopNotificationSourceEvent>();
      final merged = loopMergeNotificationStreams(
        foreground.stream,
        opened.stream,
      );
      final seen = <LoopNotificationSourceEventKind>[];
      final subscription = merged.listen((event) => seen.add(event.kind));
      addTearDown(() async {
        await foreground.close();
        await opened.close();
      });

      foreground.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.foreground,
          data: const <String, Object?>{},
        ),
      );
      opened.add(
        LoopNotificationSourceEvent(
          kind: LoopNotificationSourceEventKind.interaction,
          data: const <String, Object?>{},
        ),
      );
      await _settle();

      expect(seen, <LoopNotificationSourceEventKind>[
        LoopNotificationSourceEventKind.foreground,
        LoopNotificationSourceEventKind.interaction,
      ]);

      await subscription.cancel();
      expect(foreground.hasListener, isFalse);
      expect(opened.hasListener, isFalse);
    });
  });
}

Map<String, Object?> _pushPayload(LoopPushNotificationType type) =>
    <String, Object?>{
      'type': type.wireName,
      'entityRef': '${type.entityPrefix}:00000000-0000-4000-8000-00000000000a',
      'contextRoute': type.contextRoute.wireName,
      'eventVersion': LoopNotificationRouter.eventVersion,
    };

LoopV2SessionCommand _command({
  LoopV2Platform platform = LoopV2Platform.android,
}) => LoopV2SessionCommand(
  platform: platform,
  deviceId: _deviceId,
  sessionId: _sessionId,
  idempotencyKey: _idempotencyKey,
);

Future<LoopPushTokenRegistration> _register(DioLoopV2PushDeviceApi api) {
  return api.registerToken(
    accessToken: _accessToken,
    clientVersion: s5ClientVersion,
    platform: LoopPushPlatform.android,
    token: _firebaseToken,
    appVersion: s5ClientVersion,
    command: _command(),
  );
}

AppConfig _config({
  required bool firebaseConfigured,
  bool declaredModeMatchesRuntime = true,
}) {
  return AppConfig(
    privyAppId: 'app',
    privyAppClientId: 'client',
    streamApiKey: 'stream',
    backendBaseUrl: 'https://api-dev.quant-dinger.cc',
    firebaseConfigured: firebaseConfigured,
    declaredModeMatchesRuntime: declaredModeMatchesRuntime,
  );
}

Map<String, Object?> _registrationBody({bool registered = true}) =>
    <String, Object?>{
      'registered': registered,
      'pushTokenId': _pushTokenId,
      'platform': 'android',
      'provider': 'fcm',
      'appVersion': s5ClientVersion,
      'observedAt': '2026-09-22T04:05:06.000Z',
      'contractVersion': '2.0',
    };

Map<String, Object?> _revocationBody({
  String? revokedAt = '2026-09-22T04:10:00.000Z',
}) => <String, Object?>{
  'registered': false,
  'revokedAt': revokedAt,
  'observedAt': '2026-09-22T04:10:00.000Z',
  'contractVersion': '2.0',
};

Matcher _failure(LoopBackendFailureKind kind) =>
    isA<LoopBackendFailure>().having((failure) => failure.kind, 'kind', kind);

Future<void> _settle() async {
  for (var turn = 0; turn < 8; turn += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Harness {
  _Harness({
    required this.principal,
    LoopPushPlatform? platform = LoopPushPlatform.android,
    LoopPushPermission permission = LoopPushPermission.granted,
    String? apnsToken,
    bool hasToken = true,
    bool gatewayAvailable = true,
    bool gatewayDefers = false,
    LoopChainFailureKind? gatewayFailure,
    bool pushCapabilityAvailable = true,
    bool revokeHangs = false,
    Duration revokeTimeout = const Duration(seconds: 3),
  }) : source = _TestPushTokenSource(
         permission: permission,
         apnsToken: apnsToken,
         hasToken: hasToken,
       ),
       gateway = _TestPushDeviceGateway(
         available: gatewayAvailable,
         defers: gatewayDefers,
         failure: gatewayFailure,
         revokeHangs: revokeHangs,
       ),
       stream = _TestStreamRegistrar() {
    coordinator = LoopPushRegistrationCoordinator(
      source: source,
      readGateway: () => gateway,
      readStreamRegistrar: () => stream,
      readPrincipalKey: _readPrincipal,
      readPushCapabilityAvailable: () => pushCapabilityAvailable,
      platform: platform,
      appVersion: s5ClientVersion,
      diagnostics: diagnostics,
      revokeTimeout: revokeTimeout,
    );
  }

  /// Mutable so a test can do what the device does: become an account the
  /// backend has agreed exists *after* the coordinator first looked.
  String? principal;

  final _TestPushTokenSource source;
  final _TestPushDeviceGateway gateway;
  final _TestStreamRegistrar stream;
  final LoopPushRegistrationDiagnosticsRecorder diagnostics =
      LoopPushRegistrationDiagnosticsRecorder(
        clock: () => DateTime.utc(2026, 9, 22, 4, 5, 6),
      );
  late final LoopPushRegistrationCoordinator coordinator;

  LoopPushRegistrationGate get gate => diagnostics.value.gate;

  String? _readPrincipal() => principal;

  Future<void> dispose() async {
    await coordinator.dispose();
    await source.close();
    diagnostics.dispose();
  }
}

final class _TestPushTokenSource implements LoopPushTokenSource {
  _TestPushTokenSource({
    required this.permission,
    this.apnsToken,
    this.hasToken = true,
  });

  final LoopPushPermission permission;
  final String? apnsToken;

  /// iOS before APNs has answered: permission is granted and there is still
  /// no token to register.
  final bool hasToken;
  final StreamController<String> _refreshes = StreamController<String>();

  var permissionRequests = 0;
  var tokenReads = 0;
  var deleted = 0;

  void emitRefresh(String token) => _refreshes.add(token);

  Future<void> close() => _refreshes.close();

  @override
  Future<LoopPushPermission> requestPermission() async {
    permissionRequests += 1;
    return permission;
  }

  @override
  Future<String?> currentToken() async {
    tokenReads += 1;
    return hasToken ? _firebaseToken : null;
  }

  @override
  Future<String?> currentApnsToken() async => apnsToken;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Future<void> deleteToken() async {
    deleted += 1;
  }
}

final class _TestPushDeviceGateway implements PushDeviceGateway {
  _TestPushDeviceGateway({
    required this.available,
    required this.defers,
    required this.revokeHangs,
    this.failure,
  });

  final bool available;
  final bool defers;
  final LoopChainFailureKind? failure;
  final bool revokeHangs;

  final registered = <String>[];
  final platforms = <LoopPushPlatform>[];
  final appVersions = <String>[];
  var revokeCalls = 0;

  @override
  LoopChainGatewayMode get mode => available
      ? LoopChainGatewayMode.production
      : LoopChainGatewayMode.unavailable;

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  }) async {
    registered.add(token);
    platforms.add(platform);
    appVersions.add(appVersion);
    if (defers) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    final failure = this.failure;
    if (failure != null) throw LoopChainException(failure);
    return LoopPushTokenRegistration(
      registered: true,
      pushTokenId: _pushTokenId,
      platform: platform,
      provider: LoopPushTokenRegistration.firebaseProvider,
      appVersion: appVersion,
      observedAt: DateTime.utc(2026, 9, 22, 4, 5, 6),
    );
  }

  @override
  Future<LoopPushTokenRevocation> revokeToken() async {
    if (revokeHangs) return Completer<LoopPushTokenRevocation>().future;
    revokeCalls += 1;
    return LoopPushTokenRevocation(
      registered: false,
      revokedAt: DateTime.utc(2026, 9, 22, 4, 10),
      observedAt: DateTime.utc(2026, 9, 22, 4, 10),
    );
  }
}

final class _TestStreamRegistrar implements LoopStreamPushDeviceRegistrar {
  final added = <LoopStreamPushDevice>[];
  final removed = <LoopStreamPushDevice>[];

  @override
  Future<bool> addDevice(LoopStreamPushDevice device) async {
    added.add(device);
    return true;
  }

  @override
  Future<bool> removeDevice(LoopStreamPushDevice device) async {
    removed.add(device);
    return true;
  }
}

final class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: _principal),
  );
}

final class _TestAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => _accessToken;
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
