import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:uuid/uuid.dart';

const _loopV2SecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: false,
    storageNamespace: 'loop_backend_v2_session',
  ),
  iOptions: IOSOptions(
    accountName: 'com.cywd.loop.backend.v2.session',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  ),
);

abstract interface class LoopV2SessionJournalStore {
  Future<String> loadOrCreateDeviceId();

  Future<LoopV2OwnerJournal?> readOwnerJournal(String ownerPartition);

  Future<void> writeOwnerJournal(
    String ownerPartition,
    LoopV2OwnerJournal journal,
  );

  Future<void> deleteOwnerJournal(String ownerPartition);
}

abstract interface class LoopV2SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class _FlutterLoopV2SecureKeyValueStore
    implements LoopV2SecureKeyValueStore {
  const _FlutterLoopV2SecureKeyValueStore();

  final FlutterSecureStorage _storage = _loopV2SecureStorage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract final class LoopV2OwnerPartition {
  static String fromPrincipal(String principalKey, {Uuid uuid = const Uuid()}) {
    final principal = principalKey.trim();
    if (principal.isEmpty || principal != principalKey) {
      throw const LoopV2SessionStorageException();
    }
    return uuid.v5(
      Namespace.url.value,
      'https://quant-dinger.cc/loop/v2/privy-owner/$principal',
    );
  }
}

final class FlutterSecureLoopV2SessionJournalStore
    implements LoopV2SessionJournalStore {
  factory FlutterSecureLoopV2SessionJournalStore({
    LoopV2SecureKeyValueStore secureStorage =
        const _FlutterLoopV2SecureKeyValueStore(),
    Uuid uuid = const Uuid(),
  }) {
    return FlutterSecureLoopV2SessionJournalStore._(secureStorage, uuid);
  }

  FlutterSecureLoopV2SessionJournalStore._(this._storage, this._uuid);

  static const _deviceIdKey = 'loop.backend.v2.device_id';
  static const _ownerKeyPrefix = 'loop.backend.v2.owner.';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');
  static final RegExp _clientVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final LoopV2SecureKeyValueStore _storage;
  final Uuid _uuid;
  Future<String>? _deviceIdOperation;

  @override
  Future<String> loadOrCreateDeviceId() {
    return _deviceIdOperation ??= _loadOrCreateDeviceId();
  }

  Future<String> _loadOrCreateDeviceId() async {
    try {
      final stored = await _storage.read(_deviceIdKey);
      if (stored != null) {
        if (!_uuidV4Pattern.hasMatch(stored)) {
          throw const LoopV2SessionStorageException();
        }
        return stored;
      }
      final generated = _uuid.v4().toLowerCase();
      if (!_uuidV4Pattern.hasMatch(generated)) {
        throw const LoopV2SessionStorageException();
      }
      await _storage.write(_deviceIdKey, generated);
      return generated;
    } catch (error) {
      if (error is LoopV2SessionStorageException) rethrow;
      throw const LoopV2SessionStorageException();
    }
  }

  @override
  Future<LoopV2OwnerJournal?> readOwnerJournal(String ownerPartition) async {
    final key = _ownerKey(ownerPartition);
    try {
      final raw = await _storage.read(key);
      if (raw == null) return null;
      return _parseJournal(jsonDecode(raw));
    } catch (error) {
      if (error is LoopV2SessionStorageException) rethrow;
      throw const LoopV2SessionStorageException();
    }
  }

  @override
  Future<void> writeOwnerJournal(
    String ownerPartition,
    LoopV2OwnerJournal journal,
  ) async {
    final key = _ownerKey(ownerPartition);
    try {
      final validated = _parseJournal(journal.toJson());
      await _storage.write(key, jsonEncode(validated.toJson()));
    } catch (_) {
      throw const LoopV2SessionStorageException();
    }
  }

  @override
  Future<void> deleteOwnerJournal(String ownerPartition) async {
    final key = _ownerKey(ownerPartition);
    try {
      await _storage.delete(key);
    } catch (_) {
      throw const LoopV2SessionStorageException();
    }
  }

  String _ownerKey(String ownerPartition) {
    if (!_uuidPattern.hasMatch(ownerPartition)) {
      throw const LoopV2SessionStorageException();
    }
    return '$_ownerKeyPrefix$ownerPartition';
  }

  LoopV2OwnerJournal _parseJournal(Object? value) {
    final root = _strictMap(value, const <String>{
      'schemaVersion',
      'pendingBootstrap',
      'activeSession',
      'pendingLogout',
      'bootstrapRetirementRequested',
      'revocationUnconfirmed',
    });
    if (root['schemaVersion'] != LoopV2OwnerJournal.schemaVersion ||
        root['bootstrapRetirementRequested'] is! bool ||
        root['revocationUnconfirmed'] is! bool) {
      throw const LoopV2SessionStorageException();
    }
    final pendingBootstrap = _parseCommand(root['pendingBootstrap']);
    final activeSession = _parseActive(root['activeSession']);
    final pendingLogout = _parseCommand(root['pendingLogout']);
    final bootstrapRetirementRequested =
        root['bootstrapRetirementRequested']! as bool;
    final revocationUnconfirmed = root['revocationUnconfirmed']! as bool;
    final hasBootstrap = pendingBootstrap != null;
    final hasActive = activeSession != null;
    final hasLogout = pendingLogout != null;
    if ((hasBootstrap && (hasActive || hasLogout || revocationUnconfirmed)) ||
        (bootstrapRetirementRequested && !hasBootstrap) ||
        (hasLogout && !hasActive) ||
        (revocationUnconfirmed && !hasLogout)) {
      throw const LoopV2SessionStorageException();
    }
    return LoopV2OwnerJournal(
      pendingBootstrap: pendingBootstrap,
      activeSession: activeSession,
      pendingLogout: pendingLogout,
      bootstrapRetirementRequested: bootstrapRetirementRequested,
      revocationUnconfirmed: revocationUnconfirmed,
    );
  }

  LoopV2CommandMetadata? _parseCommand(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'deviceId',
      'idempotencyKey',
      'clientVersion',
      'platform',
      'contractVersion',
    });
    final deviceId = map['deviceId'];
    final idempotencyKey = map['idempotencyKey'];
    final clientVersion = map['clientVersion'];
    final platformValue = map['platform'];
    final contractVersion = map['contractVersion'];
    final platform = platformValue is String
        ? LoopV2Platform.tryParse(platformValue)
        : null;
    if (deviceId is! String ||
        !_uuidV4Pattern.hasMatch(deviceId) ||
        idempotencyKey is! String ||
        !_uuidV4Pattern.hasMatch(idempotencyKey) ||
        clientVersion is! String ||
        !_clientVersionPattern.hasMatch(clientVersion) ||
        clientVersion.length < 5 ||
        clientVersion.length > 64 ||
        platform == null ||
        contractVersion != LoopV2ClientMetadata.contractVersion) {
      throw const LoopV2SessionStorageException();
    }
    return LoopV2CommandMetadata(
      deviceId: deviceId,
      idempotencyKey: idempotencyKey,
      clientVersion: clientVersion,
      platform: platform,
    );
  }

  LoopV2ActiveSession? _parseActive(Object? value) {
    if (value == null) return null;
    final map = _strictMap(value, const <String>{
      'accountId',
      'sessionId',
      'streamUserId',
      'deviceId',
    });
    final accountId = map['accountId'];
    final sessionId = map['sessionId'];
    final streamUserId = map['streamUserId'];
    final deviceId = map['deviceId'];
    if (accountId is! String ||
        !_uuidPattern.hasMatch(accountId) ||
        sessionId is! String ||
        !_uuidPattern.hasMatch(sessionId) ||
        streamUserId is! String ||
        !_streamUserIdPattern.hasMatch(streamUserId) ||
        deviceId is! String ||
        !_uuidV4Pattern.hasMatch(deviceId)) {
      throw const LoopV2SessionStorageException();
    }
    return LoopV2ActiveSession(
      accountId: accountId,
      sessionId: sessionId,
      streamUserId: streamUserId,
      deviceId: deviceId,
    );
  }

  Map<String, Object?> _strictMap(Object? value, Set<String> expectedKeys) {
    if (value is! Map) throw const LoopV2SessionStorageException();
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) {
        throw const LoopV2SessionStorageException();
      }
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      throw const LoopV2SessionStorageException();
    }
    return result;
  }
}
