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

  test(
    'authorized initial interaction navigates to its fixed route once',
    () async {
      final source = _TestEventSource(
        initialInteraction: _event(
          LoopNotificationSourceEventKind.interaction,
          kind: LoopNotificationRouter.chatMessageKind,
        ),
      );
      final tokens = _TokenSource();
      final repository = _Repository((_) async => _identityA);
      final bootstrap = _bootstrap(
        principalKey: _principalA,
        tokens: tokens,
        repository: repository,
      );
      expect(
        await bootstrap.authorize(),
        LoopBootstrapAuthorization.authorized,
      );
      final session = _authenticated(_principalA);
      final navigations = <String>[];
      final coordinator = LoopNotificationCoordinator(
        source: source,
        readSession: () => session,
        readBootstrapSession: () => bootstrap,
        navigate: (intent) => navigations.add(intent.location),
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
      expect(navigations, <String>[
        '/chat/channel/${Uri.encodeComponent('messaging:loop-room-42')}',
      ]);
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
          kind: LoopNotificationRouter.systemNoticeKind,
        ),
      );
      source.emit(
        _event(
          LoopNotificationSourceEventKind.background,
          kind: LoopNotificationRouter.systemNoticeKind,
        ),
      );
      expect(navigations, isEmpty);

      source.emit(
        _event(
          LoopNotificationSourceEventKind.interaction,
          kind: LoopNotificationRouter.systemNoticeKind,
        ),
      );
      expect(navigations, <String>['/notifications']);
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
          kind: LoopNotificationRouter.audioRoomActivityKind,
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
        kind: LoopNotificationRouter.systemNoticeKind,
        eventId: '123e4567-e89b-42d3-a456-426614174005',
      ),
    );
    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        kind: LoopNotificationRouter.audioRoomActivityKind,
        eventId: '123e4567-e89b-42d3-a456-426614174006',
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
        kind: LoopNotificationRouter.systemNoticeKind,
      ),
    );
    await _flushAsyncWork();
    expect(repository.calls, 1);

    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        kind: LoopNotificationRouter.audioRoomActivityKind,
        eventId: '123e4567-e89b-42d3-a456-426614174007',
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
          kind: LoopNotificationRouter.systemNoticeKind,
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
          kind: LoopNotificationRouter.systemNoticeKind,
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
          kind: LoopNotificationRouter.systemNoticeKind,
          eventId: '123e4567-e89b-42d3-a456-426614174002',
          recipientStreamUserId: _identityB.streamUserId,
        ),
      );
      expect(navigations, <String>['/notifications']);
    },
  );

  test('expired payload and expired restoring window never navigate', () async {
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
      clock: () => DateTime.utc(2026, 8, 25, 12, 11),
    );
    addTearDown(() async {
      await expiredCoordinator.dispose();
      authorizedBootstrap.dispose();
      await expiredSource.close();
    });
    expiredCoordinator.start();
    expiredSource.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        kind: LoopNotificationRouter.systemNoticeKind,
      ),
    );
    expect(navigations, isEmpty);

    final restoringSource = _TestEventSource();
    var restoringSession = const LoopSessionState.restoring();
    LoopBootstrapSession? restoringBootstrap;
    final restoringCoordinator = LoopNotificationCoordinator(
      source: restoringSource,
      readSession: () => restoringSession,
      readBootstrapSession: () => restoringBootstrap,
      navigate: (intent) => navigations.add(intent.location),
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
        kind: LoopNotificationRouter.systemNoticeKind,
        eventId: '123e4567-e89b-42d3-a456-426614174003',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    restoringSession = _authenticated(_principalA);
    restoringBootstrap = authorizedBootstrap;
    restoringCoordinator.onIdentityMayHaveChanged();
    await _flushAsyncWork();
    expect(navigations, isEmpty);
  });

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
        kind: LoopNotificationRouter.systemNoticeKind,
      ),
    );
    await _flushAsyncWork();
    expect(repository.calls, 1);

    await coordinator.dispose();
    authorizationGate.complete(_identityA);
    source.emit(
      _event(
        LoopNotificationSourceEventKind.interaction,
        kind: LoopNotificationRouter.audioRoomActivityKind,
        eventId: '123e4567-e89b-42d3-a456-426614174004',
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

LoopNotificationSourceEvent _event(
  LoopNotificationSourceEventKind sourceKind, {
  required String kind,
  String eventId = '123e4567-e89b-42d3-a456-426614174000',
  String recipientStreamUserId = _streamUserA,
}) {
  return LoopNotificationSourceEvent(
    kind: sourceKind,
    data: <String, Object?>{
      'loop_schema': LoopNotificationRouter.schema,
      'event_id': eventId,
      'recipient_stream_user_id': recipientStreamUserId,
      'kind': kind,
      'occurred_at': '2026-08-25T11:59:00.000Z',
      'expires_at': '2026-08-25T12:10:00.000Z',
      if (kind == LoopNotificationRouter.chatMessageKind)
        'cid': 'messaging:loop-room-42',
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
