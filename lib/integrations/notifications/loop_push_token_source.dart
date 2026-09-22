import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the device answered when LOOP asked to be allowed to notify.
///
/// `unsupported` is not a refusal: it is a build with no push provider at all
/// — the offline Preview composition, a test host, a platform LOOP registered
/// no Firebase application for. Nothing is asked and nothing is reported.
enum LoopPushPermission { granted, provisional, denied, unsupported }

/// The device half of push: the permission, the token, and the token again
/// when the provider rotates it.
///
/// Deliberately provider-neutral. The Firebase implementation lives in the one
/// reviewed ingress; everything above this line — the coordinator, the backend
/// gateway, the Stream registration — never names Firebase.
abstract interface class LoopPushTokenSource {
  /// Asks the device, once, whether LOOP may show notifications.
  ///
  /// On a device that has already answered, the platform returns the stored
  /// answer without showing a prompt, so this is safe to call again.
  Future<LoopPushPermission> requestPermission();

  /// The current registration token, or `null` when there is not one yet.
  ///
  /// `null` is ordinary on iOS: the token only exists after APNs has answered,
  /// which may be after the first read. The refresh stream delivers it then.
  Future<String?> currentToken();

  /// The raw APNs device token on iOS, or `null` anywhere else.
  ///
  /// Stream's APN configuration talks to Apple directly and addresses a device
  /// by this token; Firebase's registration token means nothing to it. On
  /// Android there is no such token and the answer is the absence of one.
  Future<String?> currentApnsToken();

  /// Every token the provider issues after the first one.
  Stream<String> get tokenRefreshes;

  /// Drops the device's registration at the provider.
  ///
  /// Called on sign-out together with the backend revoke, so the next account
  /// on this device is not addressable through the previous account's token.
  Future<void> deleteToken();
}

/// The default in every composition that has no reviewed push provider.
final class DisabledLoopPushTokenSource implements LoopPushTokenSource {
  const DisabledLoopPushTokenSource();

  @override
  Future<LoopPushPermission> requestPermission() async =>
      LoopPushPermission.unsupported;

  @override
  Future<String?> currentToken() async => null;

  @override
  Future<String?> currentApnsToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Future<void> deleteToken() async {}
}

/// Production default. `lib/main.dart` replaces it only when the build carries
/// a real Firebase configuration and the initialization succeeded.
final loopPushTokenSourceProvider = Provider<LoopPushTokenSource>(
  (ref) => const DisabledLoopPushTokenSource(),
);
