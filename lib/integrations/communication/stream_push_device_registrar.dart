import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Which of the LOOP application's Stream push configurations a device belongs
/// to, and what that configuration is called in the Stream dashboard.
///
/// The names are the dashboard's, not LOOP's. Stream routes by them, so a
/// value here that no longer exists in the dashboard stops chat pushes
/// silently — this is the one place to change when a configuration is renamed.
enum LoopStreamPushProvider {
  /// Android. The id is the Firebase registration token.
  firebase('firebase'),

  /// iOS. The id is the **APNs device token**, not the FCM one: Stream talks
  /// to Apple directly for this configuration and never sees Firebase.
  apn('LOOPAPNS');

  const LoopStreamPushProvider(this.configurationName);

  final String configurationName;
}

/// One device as Stream addresses it.
@immutable
final class LoopStreamPushDevice {
  const LoopStreamPushDevice({required this.id, required this.provider});

  final String id;
  final LoopStreamPushProvider provider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopStreamPushDevice &&
          other.id == id &&
          other.provider == provider;

  @override
  int get hashCode => Object.hash(id, provider);
}

/// Where LOOP tells Stream to deliver a chat message it did not deliver over
/// the websocket.
///
/// Stream sends its own chat pushes; the LOOP backend sends everything else.
/// They are two registrations of the same device with two different senders,
/// and neither replaces the other.
abstract interface class LoopStreamPushDeviceRegistrar {
  /// Registers [device] for the currently connected Stream user.
  ///
  /// Returns whether Stream accepted it. A refusal is a fact, never an
  /// exception the caller has to translate: chat still works over the socket.
  Future<bool> addDevice(LoopStreamPushDevice device);

  Future<bool> removeDevice(LoopStreamPushDevice device);
}

/// The official client's `/devices` registration.
final class StreamChatPushDeviceRegistrar
    implements LoopStreamPushDeviceRegistrar {
  const StreamChatPushDeviceRegistrar(this._client);

  final StreamChatClient _client;

  static PushProvider sdkProvider(LoopStreamPushProvider provider) =>
      switch (provider) {
        LoopStreamPushProvider.firebase => PushProvider.firebase,
        LoopStreamPushProvider.apn => PushProvider.apn,
      };

  @override
  Future<bool> addDevice(LoopStreamPushDevice device) async {
    // A device belongs to a connected user. Registering without one would
    // either fail or, worse, attach this token to whoever connects next.
    if (_client.state.currentUser == null) return false;
    try {
      await _client.addDevice(
        device.id,
        sdkProvider(device.provider),
        pushProviderName: device.provider.configurationName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> removeDevice(LoopStreamPushDevice device) async {
    if (_client.state.currentUser == null) return false;
    try {
      await _client.removeDevice(device.id);
      return true;
    } catch (_) {
      return false;
    }
  }
}
