import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/firebase_options.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_event_source.dart';
import 'package:loop_mobile/integrations/notifications/loop_push_token_source.dart';

/// The only place in LOOP allowed to own Firebase global state.
///
/// Everything above this file speaks in [LoopNotificationSourceEvent] and
/// [LoopPushTokenSource]. That boundary is what keeps the notification router
/// a classifier of LOOP's own envelope rather than a parser of whatever a
/// provider happened to send: a `RemoteMessage` never leaves this file, and
/// nothing here decides a destination, an identity, or a delivery.
///
/// Three deliberate absences:
///
/// * No background message handler. A background isolate cannot navigate and
///   must not read the account, so an `onBackgroundMessage` entry point here
///   would be a second Firebase owner that does nothing. Display for a
///   backgrounded app is the notification payload's job, on the server.
/// * No foreground banner. LOOP does not render provider-supplied text: the
///   03 rule is that a notification carries a type and a context and never a
///   full address, a balance or a code, and the only way to hold a provider to
///   that from the client is to not draw its string at all.
/// * No PushKit and no VoIP. Audio Room stays foreground-only.
abstract final class LoopFirebaseIngress {
  /// Brings up the LOOP Firebase application, or reports that it could not.
  ///
  /// Idempotent: a second call returns the app the first one created. A
  /// failure is not thrown — a device that cannot reach the Firebase
  /// initialisation path still has an account, a wallet and a market, and none
  /// of them may be held up by push.
  ///
  /// It is, however, written down. Swallowing the failure entirely left the
  /// device with a disabled token source and no way for any surface to say
  /// so: it read exactly like a device that had registered. [diagnostics]
  /// receives the step and the time, never the options, the error or anything
  /// out of the configuration.
  static Future<FirebaseApp?> ensureApp({
    LoopPushRegistrationDiagnosticsRecorder? diagnostics,
  }) async {
    final options = DefaultFirebaseOptions.currentPlatformOrNull;
    if (options == null) {
      diagnostics?.record(LoopPushRegistrationGate.noPlatform);
      return null;
    }
    try {
      if (Firebase.apps.isNotEmpty) return Firebase.app();
      return await Firebase.initializeApp(options: options);
    } catch (_) {
      // Unknown initialization failures are fail-closed. They are never logged
      // with the payload or the configuration.
      diagnostics?.record(LoopPushRegistrationGate.tokenSourceDisabled);
      return null;
    }
  }
}

/// [LoopNotificationEventSource] over Firebase Cloud Messaging.
///
/// It normalizes and forwards; it validates nothing. Every rule about what a
/// notification may do — the schema, the recipient binding, the expiry, the
/// duplicate suppression, the destination — belongs to the router, which runs
/// after this and on data it does not trust.
final class FirebaseLoopNotificationEventSource
    implements LoopNotificationEventSource {
  FirebaseLoopNotificationEventSource(this._messaging);

  /// The messaging instance for the initialised LOOP Firebase application.
  factory FirebaseLoopNotificationEventSource.forDefaultApp() =>
      FirebaseLoopNotificationEventSource(FirebaseMessaging.instance);

  final FirebaseMessaging _messaging;

  /// The notification that started this process, when one did.
  ///
  /// The provider answers once per launch. A second reader would get `null`,
  /// so the coordinator is the only caller.
  @override
  Future<LoopNotificationSourceEvent?> loadInitialInteraction() async {
    final message = await _messaging.getInitialMessage();
    if (message == null) return null;
    return _event(message, LoopNotificationSourceEventKind.interaction);
  }

  @override
  Stream<LoopNotificationSourceEvent> get events =>
      loopMergeNotificationStreams(
        FirebaseMessaging.onMessage.map(
          (message) =>
              _event(message, LoopNotificationSourceEventKind.foreground),
        ),
        FirebaseMessaging.onMessageOpenedApp.map(
          (message) =>
              _event(message, LoopNotificationSourceEventKind.interaction),
        ),
      );

  static LoopNotificationSourceEvent _event(
    RemoteMessage message,
    LoopNotificationSourceEventKind kind,
  ) {
    // `data` only. The `notification` block is the provider's own display
    // copy; letting it reach the router would make a title into a routing
    // input. The router requires the exact LOOP envelope and refuses a map
    // that carries anything else, so an unexpected key fails closed here too.
    return LoopNotificationSourceEvent(
      kind: kind,
      data: Map<String, Object?>.of(message.data),
    );
  }
}

/// Merges two provider streams into the single stream the coordinator listens
/// to, and cancels both when it stops listening.
///
/// Written out rather than pulled from `package:async`: this is the whole of
/// what LOOP needs, and a dependency for it would have to be approved.
Stream<T> loopMergeNotificationStreams<T>(Stream<T> first, Stream<T> second) {
  late final StreamController<T> controller;
  StreamSubscription<T>? firstSubscription;
  StreamSubscription<T>? secondSubscription;
  controller = StreamController<T>(
    onListen: () {
      firstSubscription = first.listen(
        controller.add,
        onError: controller.addError,
      );
      secondSubscription = second.listen(
        controller.add,
        onError: controller.addError,
      );
    },
    onCancel: () async {
      final subscriptions = <StreamSubscription<T>?>[
        firstSubscription,
        secondSubscription,
      ];
      firstSubscription = null;
      secondSubscription = null;
      for (final subscription in subscriptions) {
        await subscription?.cancel();
      }
    },
  );
  return controller.stream;
}

/// [LoopPushTokenSource] over Firebase Cloud Messaging.
final class FirebaseLoopPushTokenSource implements LoopPushTokenSource {
  FirebaseLoopPushTokenSource(this._messaging);

  factory FirebaseLoopPushTokenSource.forDefaultApp() =>
      FirebaseLoopPushTokenSource(FirebaseMessaging.instance);

  final FirebaseMessaging _messaging;

  @override
  Future<LoopPushPermission> requestPermission() async {
    try {
      // While LOOP is in the foreground the provider must not draw anything:
      // the app is on screen and the router already has the event. This also
      // keeps provider-supplied copy off a device LOOP is actively showing.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      final settings = await _messaging.requestPermission();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized => LoopPushPermission.granted,
        AuthorizationStatus.provisional => LoopPushPermission.provisional,
        AuthorizationStatus.denied => LoopPushPermission.denied,
        AuthorizationStatus.notDetermined => LoopPushPermission.denied,
      };
    } catch (_) {
      return LoopPushPermission.unsupported;
    }
  }

  @override
  Future<String?> currentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> currentApnsToken() async {
    try {
      final token = await _messaging.getAPNSToken();
      if (token == null || token.trim().isEmpty) return null;
      return token;
    } catch (_) {
      // Android has no APNs token at all, and on iOS the token only exists
      // once Apple has answered the registration.
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // The backend revoke is the registration that matters. A provider that
      // refuses to drop its own token cannot keep the account addressable.
    }
  }
}
