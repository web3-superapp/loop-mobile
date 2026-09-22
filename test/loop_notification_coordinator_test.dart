import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/notifications/loop_notification_coordinator.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  final now = DateTime.utc(2026, 8, 25, 12);

  test('the destination comes from the feed, not from the payload', () async {
    final source = _TestEventSource(
      initialInteraction: _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.priceAlertTriggered,
      ),
    );
    final tokens = _TokenSource();
    final repository = _Repository((_) async => _identityA);
    final bootstrap = _bootstrap(
      principalKey: _principalA,
      tokens: tokens,
      repository: repository,
    );
    expect(await bootstrap.authorize(), LoopBootstrapAuthorization.authorized);
    final session = _authenticated(_principalA);
    final navigations = <String>[];
    // The payload named `priceAlert:<id>` and nothing else. Which asset that
    // alert watches is the feed's answer, read back for the account that is
    // signed in now.
    final resolved = <String>[];
    final coordinator = LoopNotificationCoordinator(
      source: source,
      readSession: () => session,
      readBootstrapSession: () => bootstrap,
      navigate: (intent) => navigations.add(intent.location),
      resolveContext: (pointer) async {
        resolved.add(pointer.entityRef);
        return const LoopNotificationContext(
          contextRoute: 'token',
          assetId: _wbnbAssetId,
        );
      },
      clock: () => now,
    );
    addTearDown(() async {
      await coordinator.dispose();
      bootstrap.dispose();
      await source.close();
    });

    coordinator.start();
    coordinator.start();
    await _flushAsyncWork();

    expect(source.initialInteractionCalls, 1);
    expect(tokens.calls, 1);
    expect(repository.calls, 1);
    expect(resolved, <String>[
      'priceAlert:00000000-0000-4000-8000-000000000001',
    ]);
    expect(navigations, <String>[
      '/market/token?assetId=${Uri.encodeQueryComponent(_wbnbAssetId)}',
    ]);
  });

  test(
    'an unresolvable price alert opens the alerts page, naming no asset',
    () async {
      final source = _TestEventSource(
        initialInteraction: _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.priceAlertTriggered,
        ),
      );
      final bootstrap = _bootstrap(
        principalKey: _principalA,
        repository: _Repository((_) async => _identityA),
      );
      await bootstrap.authorize();
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => _authenticated(_principalA),
        readBootstrapSession: () => bootstrap,
        navigate: (intent) => navigations.add(intent.location),
        // This account's feed has no such notification, or the read failed.
        // Either way the payload does not get to choose a token.
        resolveContext: (_) async => null,
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        bootstrap.dispose();
        await source.close();
      });

      coordinator.start();
      await _flushAsyncWork();

      expect(navigations, <String>['/market/alerts']);
    },
  );

  test(
    'a feed record for another destination cannot redirect the tap',
    () async {
      final source = _TestEventSource(
        initialInteraction: _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.priceAlertTriggered,
        ),
      );
      final bootstrap = _bootstrap(
        principalKey: _principalA,
        repository: _Repository((_) async => _identityA),
      );
      await bootstrap.authorize();
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => _authenticated(_principalA),
        readBootstrapSession: () => bootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async =>
            const LoopNotificationContext(contextRoute: 'devices'),
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        bootstrap.dispose();
        await source.close();
      });

      coordinator.start();
      await _flushAsyncWork();

      expect(navigations, <String>['/market/alerts']);
    },
  );

  test(
    'foreground and background delivery never navigate or consume the tap',
    () async {
      final source = _TestEventSource();
      final bootstrap = _bootstrap(
        principalKey: _principalA,
        repository: _Repository((_) async => _identityA),
      );
      await bootstrap.authorize();
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => _authenticated(_principalA),
        readBootstrapSession: () => bootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        bootstrap.dispose();
        await source.close();
      });
      coordinator.start();

      source.emit(
        _event(
          LoopNotificationSourceEventKind.foreground,
          type: LoopPushNotificationType.securityEvent,
        ),
      );
      source.emit(
        _event(
          LoopNotificationSourceEventKind.background,
          type: LoopPushNotificationType.securityEvent,
        ),
      );
      expect(navigations, isEmpty);

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
        ),
      );
      await _flushAsyncWork();
      expect(navigations, <String>['/profile/devices']);
    },
  );

  test(
    'restoring interaction waits for a verified bootstrap identity',
    () async {
      final source = _TestEventSource();
      final tokens = _TokenSource();
      final repository = _Repository((_) async => _identityA);
      final bootstrap = _bootstrap(
        principalKey: _principalA,
        tokens: tokens,
        repository: repository,
      );
      var session = const LoopSessionState.restoring();
      LoopBootstrapSession? currentBootstrap;
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => session,
        readBootstrapSession: () => currentBootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        bootstrap.dispose();
        await source.close();
      });
      coordinator.start();

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.communityVoiceRoomStarted,
        ),
      );
      expect(navigations, isEmpty);
      expect(repository.calls, 0);

      session = _authenticated(_principalA);
      currentBootstrap = bootstrap;
      coordinator.onIdentityMayHaveChanged();
      await _flushAsyncWork();

      expect(tokens.calls, 1);
      expect(repository.calls, 1);
      expect(navigations, <String>['/chat/voice']);
    },
  );

  test('restoring keeps only the latest valid interaction', () async {
    final source = _TestEventSource();
    final bootstrap = _bootstrap(
      principalKey: _principalA,
      repository: _Repository((_) async => _identityA),
    );
    var session = const LoopSessionState.restoring();
    LoopBootstrapSession? currentBootstrap;
    final navigations = <String>[];
    final coordinator = LoopNotificationCoordinator(
      source: source,
      readSession: () => session,
      readBootstrapSession: () => currentBootstrap,
      navigate: (intent) => navigations.add(intent.location),
      resolveContext: (_) async => null,
      clock: () => now,
    );
    addTearDown(() async {
      await coordinator.dispose();
      bootstrap.dispose();
      await source.close();
    });
    coordinator.start();

    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.securityEvent,
        entity: '00000000-0000-4000-8000-000000000005',
      ),
    );
    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.communityVoiceRoomStarted,
        entity: '00000000-0000-4000-8000-000000000006',
      ),
    );
    expect(navigations, isEmpty);

    session = _authenticated(_principalA);
    currentBootstrap = bootstrap;
    coordinator.onIdentityMayHaveChanged();
    await _flushAsyncWork();

    expect(navigations, <String>['/chat/voice']);
  });

  test('a hung bootstrap releases a timed-out interaction', () async {
    final source = _TestEventSource();
    final authorizationGate = Completer<LoopBootstrapIdentity>();
    final repository = _Repository((_) => authorizationGate.future);
    final bootstrap = _bootstrap(
      principalKey: _principalA,
      repository: repository,
    );
    final navigations = <String>[];
    final coordinator = LoopNotificationCoordinator(
      source: source,
      readSession: () => _authenticated(_principalA),
      readBootstrapSession: () => bootstrap,
      navigate: (intent) => navigations.add(intent.location),
      resolveContext: (_) async => null,
      clock: () => now,
      restoringWait: const Duration(milliseconds: 5),
    );
    addTearDown(() async {
      await coordinator.dispose();
      bootstrap.dispose();
      await source.close();
    });
    coordinator.start();

    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.securityEvent,
      ),
    );
    await _flushAsyncWork();
    expect(repository.calls, 1);

    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.communityVoiceRoomStarted,
        entity: '00000000-0000-4000-8000-000000000007',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    authorizationGate.complete(_identityA);
    await _flushAsyncWork();

    expect(navigations, isEmpty);
  });

  for (final ineligibleState in <LoopSessionState>[
    const LoopSessionState.signedOut(),
    const LoopSessionState.preview(),
    const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified),
  ]) {
    test('${ineligibleState.mode.name} clears a pending interaction', () async {
      final source = _TestEventSource();
      final authorizationGate = Completer<LoopBootstrapIdentity>();
      final repository = _Repository((_) => authorizationGate.future);
      final oldBootstrap = _bootstrap(
        principalKey: _principalA,
        repository: repository,
      );
      final replacementBootstrap = _bootstrap(
        principalKey: _principalA,
        repository: _Repository((_) async => _identityA),
      );
      await replacementBootstrap.authorize();
      var session = _authenticated(_principalA);
      LoopBootstrapSession? currentBootstrap = oldBootstrap;
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => session,
        readBootstrapSession: () => currentBootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        oldBootstrap.dispose();
        replacementBootstrap.dispose();
        await source.close();
      });
      coordinator.start();

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
        ),
      );
      await _flushAsyncWork();
      expect(repository.calls, 1);

      session = ineligibleState;
      currentBootstrap = null;
      coordinator.onIdentityMayHaveChanged();
      authorizationGate.complete(_identityA);
      await _flushAsyncWork();

      session = _authenticated(_principalA);
      currentBootstrap = replacementBootstrap;
      coordinator.onIdentityMayHaveChanged();
      await _flushAsyncWork();
      expect(navigations, isEmpty);
    });
  }

  test(
    'an old account authorization cannot navigate after account rotation',
    () async {
      final source = _TestEventSource();
      final oldAuthorizationGate = Completer<LoopBootstrapIdentity>();
      final oldRepository = _Repository((_) => oldAuthorizationGate.future);
      final oldBootstrap = _bootstrap(
        principalKey: _principalA,
        repository: oldRepository,
      );
      final newBootstrap = _bootstrap(
        principalKey: _principalB,
        repository: _Repository((_) async => _identityB),
      );
      await newBootstrap.authorize();
      var session = _authenticated(_principalA);
      var currentBootstrap = oldBootstrap;
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => session,
        readBootstrapSession: () => currentBootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => now,
      );
      addTearDown(() async {
        await coordinator.dispose();
        oldBootstrap.dispose();
        newBootstrap.dispose();
        await source.close();
      });
      coordinator.start();

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
        ),
      );
      await _flushAsyncWork();
      expect(oldRepository.calls, 1);

      session = _authenticated(_principalB);
      currentBootstrap = newBootstrap;
      coordinator.onIdentityMayHaveChanged();
      oldAuthorizationGate.complete(_identityA);
      await _flushAsyncWork();
      expect(navigations, isEmpty);

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
          entity: '00000000-0000-4000-8000-000000000002',
        ),
      );
      await _flushAsyncWork();
      expect(navigations, <String>['/profile/devices']);
    },
  );

  test(
    'an over-full payload and an expired restoring window never navigate',
    () async {
      final expiredSource = _TestEventSource();
      final authorizedBootstrap = _bootstrap(
        principalKey: _principalA,
        repository: _Repository((_) async => _identityA),
      );
      await authorizedBootstrap.authorize();
      final navigations = <String>[];
      final expiredCoordinator = LoopNotificationCoordinator(
        source: expiredSource,
        readSession: () => _authenticated(_principalA),
        readBootstrapSession: () => authorizedBootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => DateTime.utc(2026, 8, 25, 12, 11),
      );
      addTearDown(() async {
        await expiredCoordinator.dispose();
        authorizedBootstrap.dispose();
        await expiredSource.close();
      });
      expiredCoordinator.start();
      // A fifth key is not a richer notification: it is a payload LOOP did not
      // write, and half-reading it is how a sender nobody vetted gets a
      // destination.
      expiredSource.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
          extra: const <String, Object?>{'contextParams': 'assetId=PEPE'},
        ),
      );
      await _flushAsyncWork();
      expect(navigations, isEmpty);

      final restoringSource = _TestEventSource();
      var restoringSession = const LoopSessionState.restoring();
      LoopBootstrapSession? restoringBootstrap;
      final restoringCoordinator = LoopNotificationCoordinator(
        source: restoringSource,
        readSession: () => restoringSession,
        readBootstrapSession: () => restoringBootstrap,
        navigate: (intent) => navigations.add(intent.location),
        resolveContext: (_) async => null,
        clock: () => now,
        restoringWait: const Duration(milliseconds: 5),
      );
      addTearDown(() async {
        await restoringCoordinator.dispose();
        await restoringSource.close();
      });
      restoringCoordinator.start();
      restoringSource.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          type: LoopPushNotificationType.securityEvent,
          entity: '00000000-0000-4000-8000-000000000003',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      restoringSession = _authenticated(_principalA);
      restoringBootstrap = authorizedBootstrap;
      restoringCoordinator.onIdentityMayHaveChanged();
      await _flushAsyncWork();
      expect(navigations, isEmpty);
    },
  );

  test('dispose cancels delivery and ignores a late identity result', () async {
    final source = _TestEventSource();
    final authorizationGate = Completer<LoopBootstrapIdentity>();
    final repository = _Repository((_) => authorizationGate.future);
    final bootstrap = _bootstrap(
      principalKey: _principalA,
      repository: repository,
    );
    final navigations = <String>[];
    final coordinator = LoopNotificationCoordinator(
      source: source,
      readSession: () => _authenticated(_principalA),
      readBootstrapSession: () => bootstrap,
      navigate: (intent) => navigations.add(intent.location),
      resolveContext: (_) async => null,
      clock: () => now,
    );
    addTearDown(() async {
      bootstrap.dispose();
      await source.close();
    });
    coordinator.start();
    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.securityEvent,
      ),
    );
    await _flushAsyncWork();
    expect(repository.calls, 1);

    await coordinator.dispose();
    authorizationGate.complete(_identityA);
    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        type: LoopPushNotificationType.communityVoiceRoomStarted,
        entity: '00000000-0000-4000-8000-000000000004',
      ),
    );
    await _flushAsyncWork();

    expect(navigations, isEmpty);
  });

  test('source event toString never includes payload values', () {
    const marker = 'secret-notification-payload-marker';
    final event = LoopNotificationSourceEvent(
      kind: LoopNotificationSourceEventKind.interaction,
      data: <String, Object?>{'body': marker},
    );

    expect(event.toString(), isNot(contains(marker)));
    expect(event.toString(), contains('interaction'));
  });
}

const _principalA = 'did:privy:user-a';
const _principalB = 'did:privy:user-b';
const _streamUserA = 'loop_7a7448be64e24f9fa9f1891f1beec7fd';
const _wbnbAssetId = 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';

const _identityA = LoopBootstrapIdentity(
  loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
  streamUserId: _streamUserA,
);
const _identityB = LoopBootstrapIdentity(
  loopUserId: '8b8559cf-75f3-4eaf-ba02-902f2cafd8ae',
  streamUserId: 'loop_8b8559cf75f34eafba02902f2cafd8ae',
);

LoopSessionState _authenticated(String principalKey) {
  return LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: principalKey),
  );
}

LoopBootstrapSession _bootstrap({
  required String principalKey,
  _TokenSource? tokens,
  required LoopBootstrapRepository repository,
}) {
  return LoopBootstrapSession(
    principalKey: principalKey,
    accessTokens: tokens ?? _TokenSource(),
    repository: repository,
  );
}

/// The exact four-key push payload of decision 0067, and nothing else.
///
/// There is no recipient, no expiry and no event id in it: a push is a pointer
/// at a record, and the record is read back from the account's own feed after
/// the tap.
LoopNotificationSourceEvent _event(
  LoopNotificationSourceEventKind sourceKind, {
  required LoopPushNotificationType type,
  String entity = '00000000-0000-4000-8000-000000000001',
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  return LoopNotificationSourceEvent(
    kind: sourceKind,
    data: <String, Object?>{
      'type': type.wireName,
      'entityRef': '${type.entityPrefix}:$entity',
      'contextRoute': type.contextRoute.wireName,
      'eventVersion': LoopNotificationRouter.eventVersion,
      ...extra,
    },
  );
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _TestEventSource implements LoopNotificationEventSource {
  _TestEventSource({this.initialInteraction});

  final LoopNotificationSourceEvent? initialInteraction;
  final StreamController<LoopNotificationSourceEvent> _events =
      StreamController<LoopNotificationSourceEvent>.broadcast(sync: true);
  var initialInteractionCalls = 0;

  @override
  Stream<LoopNotificationSourceEvent> get events => _events.stream;

  void emit(LoopNotificationSourceEvent event) => _events.add(event);

  @override
  Future<LoopNotificationSourceEvent?> loadInitialInteraction() async {
    initialInteractionCalls += 1;
    return initialInteraction;
  }

  Future<void> close() => _events.close();
}

final class _TokenSource implements LoopBackendAccessTokenSource {
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return 'current-access-token';
  }
}

final class _Repository implements LoopBootstrapRepository {
  _Repository(this._handler);

  final Future<LoopBootstrapIdentity> Function(String token) _handler;
  var calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) {
    calls += 1;
    return _handler(accessToken);
  }
}
