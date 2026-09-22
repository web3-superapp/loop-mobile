import 'dart:async';

import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_push_device_registrar.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

/// Binds this device's push token to the account that is signed in on it.
///
/// Three registrations have to agree, and this is the only owner of all three:
/// the operating system's permission, LOOP's own `POST /v2/devices/push-token`,
/// and Stream's `/devices` entry for chat pushes. None of them is asked for
/// before there is an account: a permission prompt on first launch asks
/// somebody who has not yet decided to use LOOP to decide about notifications.
///
/// No page turns into an error because a background registration did not
/// complete, and nothing here is ever raised as a failure. But the step this
/// stopped at is written down: until 2026-09-22 a device that never got as far
/// as the permission prompt looked exactly like a device that had registered
/// and received nothing, and 「推送尚不可用」 from the capability document was
/// the only sentence either one could produce. The notification-preferences
/// page keeps the server's own statement and adds the one this device can
/// make, out of [_diagnostics].
final class LoopPushRegistrationCoordinator {
  LoopPushRegistrationCoordinator({
    required this._source,
    required this._readGateway,
    required this._readStreamRegistrar,
    required this._readPrincipalKey,
    required this._readPushCapabilityAvailable,
    required this._platform,
    required this._appVersion,
    required this._diagnostics,
    this.revokeTimeout = const Duration(seconds: 3),
  });

  final LoopPushTokenSource _source;
  final PushDeviceGateway Function() _readGateway;
  final LoopStreamPushDeviceRegistrar? Function() _readStreamRegistrar;

  /// The account this device is signed into, or `null`.
  ///
  /// It must only answer non-null once the backend has accepted the session:
  /// a token registered against an unverified session names an account the
  /// server has not agreed exists, and the command carries that session's id.
  final String? Function() _readPrincipalKey;

  /// Whether `GET /v2/meta/capabilities` says `pushNotifications` is
  /// available.
  ///
  /// Deliberately *availability*, not usability. That capability publishes
  /// `PUSH_DEVICE_DELIVERY_EVIDENCE_PENDING` as pending evidence until a real
  /// device has received something, and no device can receive anything until
  /// it has registered — gating registration on the evidence would be a
  /// deadlock. The pending evidence is a claim the UI must not make; it is not
  /// a reason to refuse the registration that would resolve it.
  final bool Function() _readPushCapabilityAvailable;

  /// `null` on a platform LOOP registered no push application for. Everything
  /// below then stays inert rather than sending `platform: 'unknown'`.
  final LoopPushPlatform? _platform;
  final String _appVersion;

  /// Where the registration stopped. Written at every exit, read by the
  /// notification-preferences page, sent nowhere.
  final LoopPushRegistrationDiagnosticsRecorder _diagnostics;

  /// Sign-out must not wait on push. Whatever has not answered by then is
  /// abandoned — the server voids this session's token in the same
  /// transaction as the logout anyway, so the revoke is tidiness and never a
  /// step logout depends on.
  final Duration revokeTimeout;

  StreamSubscription<String>? _subscription;
  Future<void> _queue = Future<void>.value();
  String? _registeredPrincipal;
  String? _registeredToken;
  LoopStreamPushDevice? _registeredStreamDevice;
  String? _askedPrincipal;
  LoopPushPermission _permission = LoopPushPermission.unsupported;

  /// The server said it has no push runtime. Set once per run; a retry would
  /// only ask the same closed capability again.
  var _runtimeDeferred = false;
  var _started = false;
  var _disposed = false;

  /// Visible for tests and for the sign-out path's own ordering checks.
  String? get registeredToken => _registeredToken;

  LoopPushPermission get permission => _permission;

  bool get runtimeDeferred => _runtimeDeferred;

  LoopPushRegistrationDiagnostics get diagnostics => _diagnostics.value;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _subscription = _source.tokenRefreshes.listen(
      (token) => _enqueue(() => _onTokenRefreshed(token)),
      onError: (Object _, StackTrace _) {
        // A provider that cannot keep its own stream open cannot register
        // anything either. There is nothing to report and nothing to retry.
      },
    );
    onIdentityMayHaveChanged();
  }

  /// Re-evaluates the registration after the session or the backend identity
  /// changed. Safe to call repeatedly: an account that is already registered
  /// asks the provider for nothing.
  void onIdentityMayHaveChanged() {
    if (_disposed) return;
    _enqueue(_synchronize);
  }

  /// Drops this device's registration **while the session still exists**.
  ///
  /// Both the LOOP revoke and Stream's `removeDevice` need the credentials
  /// sign-out is about to take away, so this runs before the session is torn
  /// down. Never throws and never outlasts [revokeTimeout].
  Future<void> revokeForSignOut() async {
    if (_disposed) return;
    try {
      await _enqueue(_revoke).timeout(revokeTimeout);
    } catch (_) {
      // Logout is the owner's decision and cannot be held up by a provider.
    }
  }

  Future<void> _synchronize() async {
    final platform = _platform;
    // The build fact first: a platform with no push application never
    // acquires an account, so reporting the account would name the condition
    // that can still change and hide the one that cannot.
    if (platform == null) {
      _record(LoopPushRegistrationGate.noPlatform);
      return;
    }
    final principal = _readPrincipalKey();
    if (principal == null) {
      _record(LoopPushRegistrationGate.noPrincipal);
      return;
    }
    if (principal == _registeredPrincipal && _registeredToken != null) return;
    if (_runtimeDeferred) {
      _record(LoopPushRegistrationGate.runtimeDeferred);
      return;
    }

    final gateway = _readGateway();
    if (gateway.mode != LoopChainGatewayMode.production) {
      _record(LoopPushRegistrationGate.gatewayNotProduction);
      return;
    }
    // 0067 §7.6: while the capability is not available there is no push
    // runtime to register with, and `POST` would answer `503`. Not asking is
    // the same outcome without the request or the permission prompt.
    if (!_readPushCapabilityAvailable()) {
      _record(LoopPushRegistrationGate.capabilityUnavailable);
      return;
    }

    // A device answers once per account. Asking again on every identity
    // change would re-prompt on Android 13 and, worse, teach the owner that
    // the answer does not stick.
    if (_askedPrincipal != principal) {
      _permission = await _source.requestPermission();
      _askedPrincipal = principal;
    }
    switch (_permission) {
      case LoopPushPermission.granted:
      case LoopPushPermission.provisional:
        break;
      // Not a refusal: this build has no push provider to refuse with.
      case LoopPushPermission.unsupported:
        _record(LoopPushRegistrationGate.tokenSourceDisabled);
        return;
      case LoopPushPermission.denied:
        _record(LoopPushRegistrationGate.permissionDenied);
        return;
    }

    final token = await _source.currentToken();
    // No token yet is ordinary on iOS, where it only exists after APNs has
    // answered. The refresh stream delivers it when it does.
    if (token == null) {
      _record(LoopPushRegistrationGate.noTokenYet);
      return;
    }
    await _register(principal, token);
  }

  void _record(
    LoopPushRegistrationGate gate, {
    LoopChainFailureKind? failureKind,
  }) {
    if (_disposed) return;
    _diagnostics.record(gate, failureKind: failureKind);
  }

  Future<void> _onTokenRefreshed(String token) async {
    final principal = _readPrincipalKey();
    final platform = _platform;
    if (principal == null || platform == null || _runtimeDeferred) return;
    if (token == _registeredToken && principal == _registeredPrincipal) return;

    final previousStreamDevice = _registeredStreamDevice;
    await _register(principal, token);
    if (_registeredToken != token) return;
    // LOOP's own side needs nothing further: the same session registering a
    // new token retires the previous row in the server's transaction, and the
    // revoke route names no token, so calling it here would drop the row that
    // was just created. Stream keeps one entry per device id, so only a device
    // that actually changed has to be removed.
    if (previousStreamDevice == null ||
        previousStreamDevice == _registeredStreamDevice) {
      return;
    }
    await _removeStreamDevice(previousStreamDevice);
  }

  Future<void> _register(String principal, String token) async {
    final platform = _platform;
    if (platform == null) return;
    try {
      final registration = await _readGateway().registerToken(
        platform: platform,
        token: token,
        appVersion: _appVersion,
      );
      if (!registration.registered) {
        _record(LoopPushRegistrationGate.registerFailed);
        return;
      }
    } on LoopChainException catch (failure) {
      // `503 CAPABILITY_UNAVAILABLE` / `PUSH_RUNTIME_DEFERRED`: the backend has
      // no Firebase credentials. Retrying cannot change that, and repeating it
      // on every identity change would be a loop nobody can see.
      if (failure.kind == LoopChainFailureKind.unavailable) {
        _runtimeDeferred = true;
        _record(LoopPushRegistrationGate.runtimeDeferred);
        return;
      }
      _record(
        LoopPushRegistrationGate.registerFailed,
        failureKind: failure.kind,
      );
      return;
    } catch (_) {
      // Fail-closed: an unregistered device is the state LOOP already
      // describes everywhere as 「推送尚不可用」. The failure has no kind LOOP
      // classifies, and nothing about it is written down beyond that.
      _record(LoopPushRegistrationGate.registerFailed);
      return;
    }
    if (_disposed || _readPrincipalKey() != principal) return;
    _registeredPrincipal = principal;
    _registeredToken = token;
    _record(LoopPushRegistrationGate.registered);
    // Stream delivers its own chat pushes and refuses a device with no
    // connected user, so this is attempted after LOOP's own registration and
    // its refusal changes nothing about LOOP's.
    await _addStreamDevice(token);
  }

  /// How Stream addresses this device, which is not how LOOP's backend does.
  ///
  /// LOOP's backend takes the Firebase registration token on both platforms —
  /// decision 0067 uploads the APNs key to the same Firebase project and lets
  /// FCM reach Apple. Stream is a second, independent sender: its `LOOPAPNS`
  /// configuration talks to Apple directly and needs the APNs device token.
  /// Sending the wrong one to either is a registration that is accepted and
  /// never delivers.
  Future<LoopStreamPushDevice?> _streamDevice(String firebaseToken) async {
    switch (_platform) {
      case null:
        return null;
      case LoopPushPlatform.android:
        return LoopStreamPushDevice(
          id: firebaseToken,
          provider: LoopStreamPushProvider.firebase,
        );
      case LoopPushPlatform.ios:
        final apnsToken = await _source.currentApnsToken();
        if (apnsToken == null) return null;
        return LoopStreamPushDevice(
          id: apnsToken,
          provider: LoopStreamPushProvider.apn,
        );
    }
  }

  Future<void> _revoke() async {
    final streamDevice = _registeredStreamDevice;
    final hadRegistration = _registeredToken != null;
    _registeredPrincipal = null;
    _registeredToken = null;
    _registeredStreamDevice = null;
    _askedPrincipal = null;
    if (streamDevice != null) await _removeStreamDevice(streamDevice);
    if (!hadRegistration) return;
    try {
      // Idempotent by contract, and available even while push is not: a
      // session with no token still answers `200` with `revokedAt: null`.
      await _readGateway().revokeToken();
    } catch (_) {
      // The server voids this session's token when the session ends anyway.
      // An unconfirmed revoke is not a reason to keep the owner on the
      // sign-out screen.
    }
    await _source.deleteToken();
  }

  Future<void> _addStreamDevice(String token) async {
    final device = await _streamDevice(token);
    if (device == null || device == _registeredStreamDevice) return;
    try {
      final accepted = await _readStreamRegistrar()?.addDevice(device) ?? false;
      if (accepted) _registeredStreamDevice = device;
    } catch (_) {
      // Chat still works over the websocket; only its push does not.
    }
  }

  Future<void> _removeStreamDevice(LoopStreamPushDevice device) async {
    try {
      await _readStreamRegistrar()?.removeDevice(device);
    } catch (_) {
      // A provider refusal is not a LOOP fact.
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final ready = _queue.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    final result = ready.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
