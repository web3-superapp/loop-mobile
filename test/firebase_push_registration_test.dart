import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_coordinator.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/firebase_options.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_push_device_api.dart';
import 'package:loop_mobile/integrations/communication/stream_push_device_registrar.dart';
import 'package:loop_mobile/integrations/notifications/firebase_notification_ingress.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

import 'support/s5_fixtures.dart';

const _accessToken = 'privy-access-token';
const _principal = 'did:privy:user-a';
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

  group('设备令牌上报', () {
    test('注册带上契约头、不带 Idempotency-Key，并送出约定的三个字段', () async {
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
      );

      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/devices/push-token');
      expect(captured!.headers['authorization'], 'Bearer $_accessToken');
      expect(captured!.headers['x-loop-contract-version'], '2.0');
      expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      expect(captured!.data, <String, Object?>{
        'platform': 'android',
        'token': _firebaseToken,
        'appVersion': s5ClientVersion,
      });
      expect(registration.registered, isTrue);
      expect(registration.observedAt, DateTime.utc(2026, 9, 22, 4, 5, 6));
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
        api.registerToken(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          platform: LoopPushPlatform.ios,
          token: _firebaseToken,
          appVersion: s5ClientVersion,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('多出来的字段是无效响应，不是可以只读一半的响应', () async {
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          final body = _registrationBody()..['surprise'] = true;
          handler.resolve(s5Response(options, body));
        }),
      );

      await expectLater(
        api.registerToken(
          accessToken: _accessToken,
          clientVersion: s5ClientVersion,
          platform: LoopPushPlatform.android,
          token: _firebaseToken,
          appVersion: s5ClientVersion,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
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
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(sent, isFalse);
    });

    test('撤销走 DELETE，令牌在请求体里而不是查询串里', () async {
      RequestOptions? captured;
      final api = DioLoopV2PushDeviceApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, _registrationBody(registered: false)),
          );
        }),
      );

      await api.revokeToken(
        accessToken: _accessToken,
        clientVersion: s5ClientVersion,
        platform: LoopPushPlatform.ios,
        token: _firebaseToken,
      );

      expect(captured!.method, 'DELETE');
      expect(captured!.path, '/v2/devices/push-token');
      expect(captured!.uri.query, isEmpty);
      expect(captured!.data, <String, Object?>{
        'platform': 'ios',
        'token': _firebaseToken,
      });
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

      expect(harness.gateway.registered, <String>[_firebaseToken]);
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

    test('令牌轮换时重报新的，并撤销旧的', () async {
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
      expect(harness.gateway.revoked, <String>[_firebaseToken]);
      expect(harness.stream.added.map((device) => device.id), <String>[
        _firebaseToken,
        _rotatedFirebaseToken,
      ]);
      expect(harness.stream.removed.map((device) => device.id), <String>[
        _firebaseToken,
      ]);
    });

    test('后端拒绝注册时，Stream 那边也不会被登记', () async {
      final harness = _Harness(principal: _principal, gatewayRefuses: true);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();

      expect(harness.gateway.registered, <String>[_firebaseToken]);
      expect(harness.stream.added, isEmpty);
      expect(harness.coordinator.registeredToken, isNull);
    });

    test('退出时撤销后端与 Stream，并删掉设备上的令牌', () async {
      final harness = _Harness(principal: _principal);
      addTearDown(harness.dispose);

      harness.coordinator.start();
      await _settle();
      await harness.coordinator.revokeForSignOut();

      expect(harness.gateway.revoked, <String>[_firebaseToken]);
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

  group('点开通知之后重新读状态，不信任 payload 说了什么', () {
    final router = LoopNotificationRouter(clock: () => _now);
    const session = LoopNotificationSessionContext.authenticated(_streamUser);

    test('payload 自带 contextRoute 时，整条通知作废，而不是照着它跳', () {
      final decision = router.route(
        data: <String, Object?>{
          ..._envelope(LoopNotificationRouter.systemNoticeKind),
          'contextRoute': '/wallet/send',
        },
        ingress: LoopNotificationIngress.interaction,
        session: session,
      );

      expect(decision.disposition, LoopNotificationDisposition.malformed);
      expect(decision.intent, isNull);
    });

    test('目的地来自类型，不来自 payload 里的任何字符串', () {
      final decision = router.route(
        data: _envelope(LoopNotificationRouter.systemNoticeKind),
        ingress: LoopNotificationIngress.interaction,
        session: session,
      );

      expect(decision.intent?.location, '/notifications');
    });

    test('前台收到时只是「看到了」，不跳转也不消费这次点击', () {
      final foreground = LoopNotificationRouter(clock: () => _now).route(
        data: _envelope(LoopNotificationRouter.systemNoticeKind),
        ingress: LoopNotificationIngress.foreground,
        session: session,
      );

      expect(
        foreground.disposition,
        LoopNotificationDisposition.foregroundObserved,
      );
      expect(foreground.intent, isNull);
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

final _now = DateTime.utc(2026, 9, 22, 12);
const _streamUser = 'loop_7a7448be64e24f9fa9f1891f1beec7fd';

Map<String, Object?> _envelope(String kind) => <String, Object?>{
  'loop_schema': LoopNotificationRouter.schema,
  'event_id': '123e4567-e89b-42d3-a456-426614174000',
  'recipient_stream_user_id': _streamUser,
  'kind': kind,
  'occurred_at': '2026-09-22T11:59:00.000Z',
  'expires_at': '2026-09-22T12:10:00.000Z',
};

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
      'observedAt': '2026-09-22T04:05:06.000Z',
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
    required String? principal,
    LoopPushPlatform platform = LoopPushPlatform.android,
    LoopPushPermission permission = LoopPushPermission.granted,
    String? apnsToken,
    bool gatewayAvailable = true,
    bool gatewayRefuses = false,
    bool revokeHangs = false,
    Duration revokeTimeout = const Duration(seconds: 3),
  }) : source = _TestPushTokenSource(
         permission: permission,
         apnsToken: apnsToken,
       ),
       gateway = _TestPushDeviceGateway(
         available: gatewayAvailable,
         refuses: gatewayRefuses,
         revokeHangs: revokeHangs,
       ),
       stream = _TestStreamRegistrar() {
    coordinator = LoopPushRegistrationCoordinator(
      source: source,
      readGateway: () => gateway,
      readStreamRegistrar: () => stream,
      readPrincipalKey: () => principal,
      platform: platform,
      appVersion: s5ClientVersion,
      revokeTimeout: revokeTimeout,
    );
  }

  final _TestPushTokenSource source;
  final _TestPushDeviceGateway gateway;
  final _TestStreamRegistrar stream;
  late final LoopPushRegistrationCoordinator coordinator;

  Future<void> dispose() async {
    await coordinator.dispose();
    await source.close();
  }
}

final class _TestPushTokenSource implements LoopPushTokenSource {
  _TestPushTokenSource({required this.permission, this.apnsToken});

  final LoopPushPermission permission;
  final String? apnsToken;
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
    return _firebaseToken;
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
    required this.refuses,
    required this.revokeHangs,
  });

  final bool available;
  final bool refuses;
  final bool revokeHangs;

  final registered = <String>[];
  final revoked = <String>[];
  final platforms = <LoopPushPlatform>[];
  final appVersions = <String>[];

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
    if (refuses) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    return LoopPushTokenRegistration(
      registered: true,
      observedAt: DateTime.utc(2026, 9, 22, 4, 5, 6),
    );
  }

  @override
  Future<void> revokeToken({
    required LoopPushPlatform platform,
    required String token,
  }) async {
    if (revokeHangs) return Completer<void>().future;
    revoked.add(token);
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
