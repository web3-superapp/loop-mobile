import 'dart:async';

import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';

/// The only application owner allowed to bind notification candidates to the
/// current session, verified backend identity and root navigation.
final class LoopNotificationCoordinator {
  factory LoopNotificationCoordinator({
    required LoopNotificationEventSource source,
    required LoopSessionState Function() readSession,
    required LoopBootstrapSession? Function() readBootstrapSession,
    required void Function(LoopNotificationNavigationIntent intent) navigate,
    DateTime Function()? clock,
    Duration restoringWait = const Duration(seconds: 15),
  }) {
    if (restoringWait <= Duration.zero ||
        restoringWait > const Duration(minutes: 1)) {
      throw ArgumentError.value(
        restoringWait,
        'restoringWait',
        'must be greater than zero and at most one minute',
      );
    }
    return LoopNotificationCoordinator._(
      source,
      readSession,
      readBootstrapSession,
      navigate,
      restoringWait,
      clock,
    );
  }

  LoopNotificationCoordinator._(
    this._source,
    this._readSession,
    this._readBootstrapSession,
    this._navigate,
    this._restoringWait,
    DateTime Function()? clock,
  ) : _router = LoopNotificationRouter(clock: clock);

  final LoopNotificationEventSource _source;
  final LoopSessionState Function() _readSession;
  final LoopBootstrapSession? Function() _readBootstrapSession;
  final void Function(LoopNotificationNavigationIntent intent) _navigate;
  final Duration _restoringWait;
  final LoopNotificationRouter _router;

  StreamSubscription<LoopNotificationSourceEvent>? _subscription;
  Timer? _deferredTimer;
  _DeferredInteraction? _deferredInteraction;
  Future<void>? _identityResolution;
  var _identityGeneration = 0;
  var _started = false;
  var _disposed = false;

  /// Starts the default-disabled initial-interaction and event streams once.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _source.events.listen(
      _accept,
      onError: (Object _, StackTrace _) {
        // Provider ingress failures carry no application navigation authority.
      },
    );
    unawaited(_loadInitialInteraction());
  }

  /// Re-evaluates at most one deferred interaction after session/bootstrap
  /// ownership changes. Known-account interactions never cross an account
  /// switch; cold-start interactions still pass recipient binding after restore.
  void onIdentityMayHaveChanged() {
    if (_disposed) return;
    _identityGeneration += 1;
    final deferred = _deferredInteraction;
    if (deferred == null) return;

    final session = _readSession();
    if (session.mode == LoopSessionMode.restoring) return;
    if (session.mode != LoopSessionMode.authenticated) {
      _clearDeferredInteraction();
      return;
    }

    final principalKey = session.account?.privyUserId;
    if (principalKey == null ||
        principalKey.isEmpty ||
        principalKey != principalKey.trim() ||
        (deferred.principalKey != null &&
            deferred.principalKey != principalKey)) {
      _clearDeferredInteraction();
      return;
    }
    _continueDeferredInteraction();
  }

  Future<void> _loadInitialInteraction() async {
    try {
      final event = await _source.loadInitialInteraction();
      if (_disposed || event == null) return;
      _accept(event);
    } catch (_) {
      // Unknown ingress failures are fail-closed and never logged with payloads.
    }
  }

  void _accept(LoopNotificationSourceEvent event) {
    if (_disposed) return;
    final ingress = switch (event.kind) {
      LoopNotificationSourceEventKind.foreground =>
        LoopNotificationIngress.foreground,
      LoopNotificationSourceEventKind.background =>
        LoopNotificationIngress.background,
      LoopNotificationSourceEventKind.interaction =>
        LoopNotificationIngress.interaction,
    };
    final decision = _router.route(
      data: event.data,
      ingress: ingress,
      session: _currentContext(),
    );

    if (decision.disposition == LoopNotificationDisposition.navigationReady) {
      final intent = decision.intent;
      if (intent == null) return;
      try {
        _navigate(intent);
      } catch (_) {
        // A retired navigator cannot turn a notification into another effect.
      }
      return;
    }

    if (event.kind == LoopNotificationSourceEventKind.interaction &&
        decision.disposition == LoopNotificationDisposition.sessionDeferred) {
      _defer(event);
    }
  }

  LoopNotificationSessionContext _currentContext() {
    final session = _readSession();
    if (session.mode == LoopSessionMode.restoring) {
      return const LoopNotificationSessionContext.restoring();
    }
    if (session.mode != LoopSessionMode.authenticated) {
      return const LoopNotificationSessionContext.ineligible();
    }

    final identity = _readBootstrapSession()?.identity;
    if (identity == null) {
      return const LoopNotificationSessionContext.restoring();
    }
    return LoopNotificationSessionContext.authenticated(identity.streamUserId);
  }

  void _defer(LoopNotificationSourceEvent event) {
    final session = _readSession();
    final principalKey = session.mode == LoopSessionMode.authenticated
        ? session.account?.privyUserId
        : null;
    _identityGeneration += 1;
    _deferredTimer?.cancel();
    _deferredInteraction = _DeferredInteraction(event, principalKey);
    _deferredTimer = Timer(_restoringWait, _clearDeferredInteraction);
    _continueDeferredInteraction();
  }

  void _continueDeferredInteraction() {
    final deferred = _deferredInteraction;
    if (_disposed || deferred == null) return;
    final session = _readSession();
    if (session.mode == LoopSessionMode.restoring) return;
    if (session.mode != LoopSessionMode.authenticated) {
      _clearDeferredInteraction();
      return;
    }

    final principalKey = session.account?.privyUserId;
    if (principalKey == null ||
        principalKey.isEmpty ||
        principalKey != principalKey.trim() ||
        (deferred.principalKey != null &&
            deferred.principalKey != principalKey)) {
      _clearDeferredInteraction();
      return;
    }

    final bootstrap = _readBootstrapSession();
    if (bootstrap == null) {
      _clearDeferredInteraction();
      return;
    }
    if (bootstrap.identity != null) {
      _retryDeferredInteraction();
      return;
    }
    if (_identityResolution != null) return;

    final generation = _identityGeneration;
    late final Future<void> operation;
    operation =
        _resolveIdentity(
          bootstrap: bootstrap,
          principalKey: principalKey,
          generation: generation,
        ).whenComplete(() {
          if (identical(_identityResolution, operation)) {
            _identityResolution = null;
          }
          if (!_disposed && _deferredInteraction != null) {
            _continueDeferredInteraction();
          }
        });
    _identityResolution = operation;
  }

  Future<void> _resolveIdentity({
    required LoopBootstrapSession bootstrap,
    required String principalKey,
    required int generation,
  }) async {
    final authorization = await bootstrap.authorize();
    if (_disposed || generation != _identityGeneration) {
      return;
    }

    final deferred = _deferredInteraction;
    final session = _readSession();
    final currentBootstrap = _readBootstrapSession();
    if (deferred == null ||
        session.mode != LoopSessionMode.authenticated ||
        session.account?.privyUserId != principalKey ||
        (deferred.principalKey != null &&
            deferred.principalKey != principalKey) ||
        !identical(currentBootstrap, bootstrap)) {
      _clearDeferredInteraction();
      return;
    }
    if (authorization != LoopBootstrapAuthorization.authorized ||
        bootstrap.identity == null) {
      _clearDeferredInteraction();
      return;
    }
    _retryDeferredInteraction();
  }

  void _retryDeferredInteraction() {
    final deferred = _deferredInteraction;
    if (deferred == null) return;
    _clearDeferredInteraction();
    _accept(deferred.event);
  }

  void _clearDeferredInteraction() {
    _deferredTimer?.cancel();
    _deferredTimer = null;
    _deferredInteraction = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _identityGeneration += 1;
    _clearDeferredInteraction();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}

final class _DeferredInteraction {
  const _DeferredInteraction(this.event, this.principalKey);

  final LoopNotificationSourceEvent event;
  final String? principalKey;
}
