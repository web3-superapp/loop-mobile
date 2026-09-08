import 'package:uuid/uuid.dart';

/// Idempotency keys for the S3 write operations.
///
/// One logical operation (identified by its signature) reserves exactly one
/// canonical lowercase UUIDv4. A retry after an unresolved outcome — a timeout
/// or a lost connection — replays the same key, so the server can recognise
/// the duplicate. Any resolved outcome, success or terminal rejection,
/// releases the key: the next attempt is a new logical operation and can never
/// collide with the recorded one.
final class LoopV2CommandKeyring {
  LoopV2CommandKeyring({this._uuid = const Uuid()});

  final Uuid _uuid;
  final Map<String, String> _keys = <String, String>{};

  String reserve(String signature) =>
      _keys.putIfAbsent(signature, () => _uuid.v4().toLowerCase());

  void release(String signature) => _keys.remove(signature);

  /// Visible for tests: the key currently bound to [signature], if any.
  String? peek(String signature) => _keys[signature];
}
