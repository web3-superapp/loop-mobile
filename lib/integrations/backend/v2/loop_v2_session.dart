import 'package:flutter/foundation.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';

enum LoopV2Platform {
  android('android'),
  ios('ios');

  const LoopV2Platform(this.wireName);

  final String wireName;

  static LoopV2Platform? tryParse(String value) {
    return switch (value) {
      'android' => LoopV2Platform.android,
      'ios' => LoopV2Platform.ios,
      _ => null,
    };
  }
}

@immutable
final class LoopV2ClientMetadata {
  const LoopV2ClientMetadata({
    required this.clientVersion,
    required this.platform,
  });

  static const contractVersion = '2.0';

  final String clientVersion;
  final LoopV2Platform platform;
}

@immutable
final class LoopV2CommandMetadata {
  const LoopV2CommandMetadata({
    required this.deviceId,
    required this.idempotencyKey,
    required this.clientVersion,
    required this.platform,
    this.contractVersion = LoopV2ClientMetadata.contractVersion,
  });

  final String deviceId;
  final String idempotencyKey;
  final String clientVersion;
  final LoopV2Platform platform;
  final String contractVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'idempotencyKey': idempotencyKey,
    'clientVersion': clientVersion,
    'platform': platform.wireName,
    'contractVersion': contractVersion,
  };
}

@immutable
final class LoopV2ActiveSession {
  const LoopV2ActiveSession({
    required this.accountId,
    required this.sessionId,
    required this.streamUserId,
    required this.deviceId,
  });

  final String accountId;
  final String sessionId;
  final String streamUserId;
  final String deviceId;

  LoopBootstrapIdentity get identity =>
      LoopBootstrapIdentity(loopUserId: accountId, streamUserId: streamUserId);

  Map<String, Object?> toJson() => <String, Object?>{
    'accountId': accountId,
    'sessionId': sessionId,
    'streamUserId': streamUserId,
    'deviceId': deviceId,
  };
}

@immutable
final class LoopV2AccountProjection {
  const LoopV2AccountProjection({
    required this.accountId,
    required this.streamUserId,
  });

  final String accountId;
  final String streamUserId;
}

@immutable
final class LoopV2BootstrapProjection {
  const LoopV2BootstrapProjection({
    required this.activeSession,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final LoopV2ActiveSession activeSession;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}

@immutable
final class LoopV2LogoutProjection {
  const LoopV2LogoutProjection({
    required this.sessionId,
    required this.revokedAt,
  });

  final String sessionId;
  final DateTime revokedAt;
}

@immutable
final class LoopV2OwnerJournal {
  const LoopV2OwnerJournal({
    this.pendingBootstrap,
    this.activeSession,
    this.pendingLogout,
    this.bootstrapRetirementRequested = false,
    this.revocationUnconfirmed = false,
  });

  static const schemaVersion = 1;

  final LoopV2CommandMetadata? pendingBootstrap;
  final LoopV2ActiveSession? activeSession;
  final LoopV2CommandMetadata? pendingLogout;
  final bool bootstrapRetirementRequested;
  final bool revocationUnconfirmed;

  bool get hasReusableActiveSession =>
      activeSession != null &&
      pendingLogout == null &&
      !bootstrapRetirementRequested &&
      !revocationUnconfirmed;

  LoopV2OwnerJournal copyWith({
    LoopV2CommandMetadata? pendingBootstrap,
    bool clearPendingBootstrap = false,
    LoopV2ActiveSession? activeSession,
    bool clearActiveSession = false,
    LoopV2CommandMetadata? pendingLogout,
    bool clearPendingLogout = false,
    bool? bootstrapRetirementRequested,
    bool? revocationUnconfirmed,
  }) {
    return LoopV2OwnerJournal(
      pendingBootstrap: clearPendingBootstrap
          ? null
          : pendingBootstrap ?? this.pendingBootstrap,
      activeSession: clearActiveSession
          ? null
          : activeSession ?? this.activeSession,
      pendingLogout: clearPendingLogout
          ? null
          : pendingLogout ?? this.pendingLogout,
      bootstrapRetirementRequested:
          bootstrapRetirementRequested ?? this.bootstrapRetirementRequested,
      revocationUnconfirmed:
          revocationUnconfirmed ?? this.revocationUnconfirmed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'pendingBootstrap': pendingBootstrap?.toJson(),
    'activeSession': activeSession?.toJson(),
    'pendingLogout': pendingLogout?.toJson(),
    'bootstrapRetirementRequested': bootstrapRetirementRequested,
    'revocationUnconfirmed': revocationUnconfirmed,
  };
}

enum LoopV2LogoutDisposition { notRequired, confirmed, unconfirmed }

final class LoopV2SessionStorageException implements Exception {
  const LoopV2SessionStorageException();

  @override
  String toString() => 'LOOP V2 session storage is unavailable.';
}
