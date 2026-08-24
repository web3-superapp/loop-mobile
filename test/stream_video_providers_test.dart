import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  test('missing API key does not create a Video session owner', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config(streamApiKey: '')),
        loopSessionProvider.overrideWith(_AuthenticatedSession.new),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(streamVideoSdkSessionProvider), isNull);
  });

  test(
    'unverified session never asks the backend for Video identity',
    () async {
      final source = _RecordingVideoSource();
      final factory = _RecordingVideoClientFactory();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          loopSessionProvider.overrideWith(_UnverifiedSession.new),
          streamVideoSessionSourceProvider.overrideWithValue(source),
          streamVideoClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(streamVideoAuthorizationProvider.future),
        StreamVideoSessionAuthorization.unavailable,
      );
      expect(source.identityCalls, 0);
      expect(source.tokenCalls, 0);
      expect(factory.createCalls, 0);
    },
  );

  test(
    'missing backend bootstrap fails before constructing Video SDK',
    () async {
      final source = _RecordingVideoSource();
      final factory = _RecordingVideoClientFactory();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          streamVideoSessionSourceProvider.overrideWithValue(source),
          streamVideoClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(streamVideoAuthorizationProvider.future),
        StreamVideoSessionAuthorization.unavailable,
      );
      expect(source.identityCalls, 1);
      expect(source.tokenCalls, 0);
      expect(factory.createCalls, 0);
    },
  );

  test(
    'verified session authorizes through the delayed backend seam',
    () async {
      final source = _RecordingVideoSource(
        identity: const StreamVideoIdentity(userId: 'stream-user-a'),
      );
      final factory = _RecordingVideoClientFactory();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          streamVideoSessionSourceProvider.overrideWithValue(source),
          streamVideoClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);

      expect(factory.createCalls, 0);
      expect(
        await container.read(streamVideoAuthorizationProvider.future),
        StreamVideoSessionAuthorization.authorized,
      );
      expect(factory.createCalls, 1);
      expect(source.requestedUserIds, <String>['stream-user-a']);
    },
  );

  test('principal change rotates the Video session owner', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        loopSessionProvider.overrideWith(_MutableSession.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      streamVideoSdkSessionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller =
        container.read(loopSessionProvider.notifier) as _MutableSession;

    final sessionA = subscription.read();
    controller.replace(
      const LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: PrivyAccountSummary(
          privyUserId: 'did:privy:user-a',
          wallet: PrivyWalletSummary(address: '0x1234'),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(subscription.read(), same(sessionA));

    controller.replace(
      const LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:user-b'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(subscription.read(), isNot(same(sessionA)));
  });
}

AppConfig _config({String streamApiKey = 'public-stream-api-key'}) {
  return AppConfig(
    privyAppId: 'privy-app',
    privyAppClientId: 'privy-client',
    streamApiKey: streamApiKey,
    backendBaseUrl: '',
    firebaseConfigured: false,
  );
}

final class _RecordingVideoSource implements StreamVideoSessionSource {
  _RecordingVideoSource({this.identity});

  final StreamVideoIdentity? identity;
  int identityCalls = 0;
  int tokenCalls = 0;
  final List<String> requestedUserIds = <String>[];

  @override
  Future<StreamVideoIdentity?> loadIdentity() async {
    identityCalls += 1;
    return identity;
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenCalls += 1;
    requestedUserIds.add(userId);
    return 'short-token';
  }
}

final class _RecordingVideoClientFactory implements StreamVideoClientFactory {
  int createCalls = 0;

  @override
  StreamVideoClientPort create({
    required String apiKey,
    required StreamVideoIdentity identity,
    required String initialToken,
    required Future<String> Function(String userId) tokenProvider,
  }) {
    createCalls += 1;
    return _RecordingVideoClient(
      userId: identity.userId,
      tokenProvider: tokenProvider,
    );
  }
}

final class _RecordingVideoClient implements StreamVideoClientPort {
  _RecordingVideoClient({required this.userId, required this.tokenProvider});

  @override
  final String userId;
  final Future<String> Function(String userId) tokenProvider;

  @override
  Future<bool> connect() async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {}
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

class _UnverifiedSession extends LoopSessionController {
  @override
  LoopSessionState build() =>
      const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified);
}

class _MutableSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );

  void replace(LoopSessionState next) => state = next;
}
