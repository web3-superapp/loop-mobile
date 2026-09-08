import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';

/// One dispatched but unconfirmed `POST /v2/profile/loop-id`.
///
/// Both the idempotency key and the exact body are durable: a retry must send
/// the original key with the original bytes, including the interest order, or
/// the backend answers `IDEMPOTENCY_CONFLICT`.
@immutable
final class LoopV2ActivationRecord {
  const LoopV2ActivationRecord({required this.command, required this.request});

  static const schemaVersion = 1;

  final LoopV2CommandMetadata command;
  final LoopV2ActivationRequest request;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'command': command.toJson(),
    'request': <String, Object?>{
      'alias': request.alias,
      'avatarRef': request.avatarRef,
      'interests': <String>[
        for (final interest in request.interests) interest.wireValue,
      ],
    },
  };
}

abstract interface class LoopV2ActivationJournalStore {
  Future<String> loadOrCreateDeviceId();

  Future<LoopV2ActivationRecord?> readRecord(String ownerPartition);

  Future<void> writeRecord(
    String ownerPartition,
    LoopV2ActivationRecord record,
  );

  Future<void> deleteRecord(String ownerPartition);
}

final class FlutterSecureLoopV2ActivationJournalStore
    implements LoopV2ActivationJournalStore {
  FlutterSecureLoopV2ActivationJournalStore({
    required this._deviceIds,
    LoopV2SecureKeyValueStore secureStorage = loopV2SecureKeyValueStore,
  }) : _storage = secureStorage;

  static const _keyPrefix = 'loop.backend.v2.profile.activation.';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _clientVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final LoopV2SessionJournalStore _deviceIds;
  final LoopV2SecureKeyValueStore _storage;

  @override
  Future<String> loadOrCreateDeviceId() => _deviceIds.loadOrCreateDeviceId();

  @override
  Future<LoopV2ActivationRecord?> readRecord(String ownerPartition) async {
    final key = _key(ownerPartition);
    try {
      final raw = await _storage.read(key);
      if (raw == null) return null;
      return _parse(jsonDecode(raw));
    } catch (error) {
      if (error is LoopV2SessionStorageException) rethrow;
      throw const LoopV2SessionStorageException();
    }
  }

  @override
  Future<void> writeRecord(
    String ownerPartition,
    LoopV2ActivationRecord record,
  ) async {
    final key = _key(ownerPartition);
    try {
      final validated = _parse(record.toJson());
      await _storage.write(key, jsonEncode(validated.toJson()));
    } catch (_) {
      throw const LoopV2SessionStorageException();
    }
  }

  @override
  Future<void> deleteRecord(String ownerPartition) async {
    final key = _key(ownerPartition);
    try {
      await _storage.delete(key);
    } catch (_) {
      throw const LoopV2SessionStorageException();
    }
  }

  String _key(String ownerPartition) {
    if (!_uuidPattern.hasMatch(ownerPartition)) {
      throw const LoopV2SessionStorageException();
    }
    return '$_keyPrefix$ownerPartition';
  }

  LoopV2ActivationRecord _parse(Object? value) {
    final root = _strictMap(value, const <String>{
      'schemaVersion',
      'command',
      'request',
    });
    if (root['schemaVersion'] != LoopV2ActivationRecord.schemaVersion) {
      throw const LoopV2SessionStorageException();
    }
    return LoopV2ActivationRecord(
      command: _parseCommand(root['command']),
      request: _parseRequest(root['request']),
    );
  }

  LoopV2CommandMetadata _parseCommand(Object? value) {
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
        clientVersion.length < 5 ||
        clientVersion.length > 64 ||
        !_clientVersionPattern.hasMatch(clientVersion) ||
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

  LoopV2ActivationRequest _parseRequest(Object? value) {
    final map = _strictMap(value, const <String>{
      'alias',
      'avatarRef',
      'interests',
    });
    final alias = map['alias'];
    final avatarRef = map['avatarRef'];
    final rawInterests = map['interests'];
    if (alias is! String ||
        (avatarRef != null && avatarRef is! String) ||
        rawInterests is! List ||
        rawInterests.length > profileMaximumInterests) {
      throw const LoopV2SessionStorageException();
    }
    final interests = <ProfileInterest>[];
    for (final raw in rawInterests) {
      if (raw is! String) throw const LoopV2SessionStorageException();
      try {
        final interest = ProfileInterest.fromWire(raw);
        if (interests.contains(interest)) {
          throw const LoopV2SessionStorageException();
        }
        interests.add(interest);
      } on InvalidProfileContractException {
        throw const LoopV2SessionStorageException();
      }
    }
    try {
      // Reuse the exact contract validation so a tampered record cannot
      // resubmit a body the client would never have produced.
      final values = ProfileValues(
        alias: alias,
        avatarRef: avatarRef as String?,
        interests: interests,
      );
      if (values.alias != alias) throw const LoopV2SessionStorageException();
    } on InvalidProfileContractException {
      throw const LoopV2SessionStorageException();
    }
    return LoopV2ActivationRequest(
      alias: alias,
      avatarRef: avatarRef,
      interests: List<ProfileInterest>.unmodifiable(interests),
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
