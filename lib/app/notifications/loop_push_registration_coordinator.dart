import 'dart:async';

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
/// Nothing here is reported to the reader. A refused permission, a refused
/// registration and an offline device all mean the same thing — the account is
/// not addressable on this device — and no page turns into an error because a
/// background registration did not complete. The notification-preferences page
/// remains the honest surface for what the account asked to hear about.
final class LoopPushRegistrationCoordinator {
  LoopPushRegistrationCoordinator({
    required this._source,
    required this._readGateway,
    required this._readStreamRegistrar,
    required this._readPrincipalKey,
    required this._platform,
    required this._appVersion,
    this.revokeTimeout = const Duration(seconds: 3),
  });

  final LoopPushTokenSource _source;
  final PushDeviceGateway Function() _readGateway;
  final LoopStreamPushDeviceRegistrar? Function() _readStreamRegistrar;

  /// The account this device is signed into, or `null`.
  ///
  /// It must only answer non-null once the backend has accepted the session:
  /// a token registered against an unverified session names an account the
  /// server has not agreed exists.
  final String? Function() _readPrincipalKey;

  /// `null` on a platform LOOP registered no push application for. Everything
  /// below then stays inert rather than sending `platform: 'unknown'`.
  final LoopPushPlatform? _platform;
  final String _appVersion;

  /// Sign-out must not wait on push. Whatever has not answered by then is
  /// abandoned; the server drops a token that stops being deliverable anyway.
  final Duration revokeTimeout;

  StreamSubscription<String>? _subscription;
  Future<void> _queue = Future<void>.value();
  String? _registeredPrincipal;
  String? _registeredToken;
  LoopStreamPushDevice? _registeredStreamDevice;
  String? _askedPrincipal;
  LoopPushPermission _permission = LoopPushPermission.unsupported;
  var _started = false;
  var _disposed = false;

  /// Visible for tests and for the sign-out path's own ordering checks.
  String? get registeredToken => _registeredToken;

  LoopPushPermission get permission => _permission;

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
  /// Called before the session is torn down, because both the LOOP revoke and
  /// Stream's `removeDevice` need the credentials that sign-out is about to
  /// take away. Never throws and never outlasts [revokeTimeout].
  Future<void> revokeForSignOut() async {
    if (_disposed) return;
    try {
      await _enqueue(_revoke).timeout(revokeTimeout);
    } catch (_) {
      // Logout is the owner's decision and cannot be held up by a provider.
    }
  }

  Future<void> _synchronize() async {
    final principal = _readPrincipalKey();
    final platform = _platform;
    if (principal == null || platform == null) return;
    if (principal == _registeredPrincipal && _registeredToken != null) return;

    final gateway = _readGateway();
    if (gateway.mode != LoopChainGatewayMode.production) return;

    // A device answers once per account. Asking again on every identity
    // change would re-prompt on Android 13 and, worse, teach the owner that
    // the answer does not stick.
    if (_askedPrincipal != principal) {
      _permission = await _source.requestPermission();
      _askedPrincipal = principal;
    }
    if (_permission != LoopPushPermission.granted &&
        _permission != LoopPushPermission.provisional) {
      return;
    }

    final token = await _source.currentToken();
    // No token yet is ordinary on iOS, where it only exists after APNs has
    // answered. The refresh stream delivers it when it does.
    if (token == null) return;
    await _register(principal, token);
  }

  Future<void> _onTokenRefreshed(String token) async {
    final principal = _readPrincipalKey();
    final platform = _platform;
    if (principal == null || platform == null) return;
    if (token == _registeredToken && principal == _registeredPrincipal) return;

    final previousToken = _registeredToken;
    final previousStreamDevice = _registeredStreamDevice;
    await _register(principal, token);
    if (previousToken == null || previousToken == token) return;
    if (_registeredToken != token) return;
    // The old token is now somebody else's or nobody's. Dropping it is the
    // only thing that stops a rotated device from being addressed twice. The
    // previous Stream device is only dropped when the new registration moved
    // to a different one; on iOS the APNs token usually does not rotate with
    // the Firebase one.
    await _dropToken(
      previousToken,
      previousStreamDevice == _registeredStreamDevice
          ? null
          : previousStreamDevice,
    );
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
      if (!registration.registered) return;
    } catch (_) {
      // Fail-closed: an unregistered device is the state LOOP already
      // describes everywhere as 「推送未接通」.
      return;
    }
    if (_disposed || _readPrincipalKey() != principal) return;
    _registeredPrincipal = principal;
    _registeredToken = token;
    // Stream delivers its own chat pushes and refuses a device with no
    // connected user, so this is attempted after LOOP's own registration and
    // its refusal changes nothing about LOOP's.
    await _addStreamDevice(token);
  }

  /// How Stream addresses this device, which is not how LOOP's backend does.
  ///
  /// Android is the same Firebase token on both sides. iOS is not: Stream's
  /// `LOOPAPNS` configuration talks to Apple directly and needs the APNs
  /// device token, while LOOP's own sender goes through Firebase and needs the
  /// registration token. Sending the wrong one to either is a registration
  /// that is accepted and never delivers.
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
    final token = _registeredToken;
    final streamDevice = _registeredStreamDevice;
    final platform = _platform;
    _registeredPrincipal = null;
    _registeredToken = null;
    _registeredStreamDevice = null;
    _askedPrincipal = null;
    if (token == null || platform == null) return;
    await _dropToken(token, streamDevice);
    await _source.deleteToken();
  }

  Future<void> _dropToken(String token, LoopStreamPushDevice? device) async {
    final platform = _platform;
    if (platform == null) return;
    if (device != null) {
      try {
        await _readStreamRegistrar()?.removeDevice(device);
      } catch (_) {
        // A provider refusal is not a LOOP fact.
      }
    }
    try {
      await _readGateway().revokeToken(platform: platform, token: token);
    } catch (_) {
      // The server expires a token it cannot deliver to; an unconfirmed
      // revoke is not a reason to keep the owner on the sign-out screen.
    }
  }

  Future<void> _addStreamDevice(String token) async {
    final device = await _streamDevice(token);
    if (device == null || device == _registeredStreamDevice) return;
    try {
      if (await (_readStreamRegistrar()?.addDevice(device) ??
          Future<bool>.value(false))) {
        _registeredStreamDevice = device;
      }
    } catch (_) {
      // Chat still works over the websocket; only its push does not.
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
