import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';

/// D20 security models (decision 0037).
///
/// Nothing here claims enrollment, protection or a terminated provider
/// session. `GET /v2/security/capabilities` reports six permanently
/// unavailable methods, and a device revoke is an audit projection only.

/// Platform reported for one device session. There is no device name and no
/// location field on the wire, so neither is ever rendered.
enum LoopDevicePlatform {
  ios('ios', 'iOS'),
  android('android', 'Android');

  const LoopDevicePlatform(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopDevicePlatform? tryParse(String value) {
    for (final platform in values) {
      if (platform.wireName == value) return platform;
    }
    return null;
  }
}

enum LoopDeviceSessionStatus {
  active('active'),
  revoked('revoked');

  const LoopDeviceSessionStatus(this.wireName);

  final String wireName;

  static LoopDeviceSessionStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// The only authentication strength the contract can report today.
enum LoopDeviceAuthStrength {
  providerAuthenticated('providerAuthenticated', 'Privy 已验证');

  const LoopDeviceAuthStrength(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopDeviceAuthStrength? tryParse(String value) {
    for (final strength in values) {
      if (strength.wireName == value) return strength;
    }
    return null;
  }
}

/// One `device_sessions` row.
///
/// [lastSeenAt] is the bootstrap observation time (decision 0027), not a
/// continuous activity time, and there is no geography.
@immutable
final class LoopDeviceSession {
  const LoopDeviceSession({
    required this.sessionId,
    required this.deviceId,
    required this.platform,
    required this.clientVersion,
    required this.status,
    required this.authStrength,
    required this.isCurrent,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revokedAt,
  });

  final String sessionId;
  final String deviceId;
  final LoopDevicePlatform platform;
  final String clientVersion;
  final LoopDeviceSessionStatus status;
  final LoopDeviceAuthStrength authStrength;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;

  bool get isActive => status == LoopDeviceSessionStatus.active;

  /// The prototype's device name has no backend field; platform plus client
  /// version is the whole truth the server reports.
  String get displayName => '${platform.label} · $clientVersion';
}

/// Server-published high-risk window. The threshold is never hard-coded.
@immutable
final class LoopDeviceRiskPolicy {
  const LoopDeviceRiskPolicy({
    required this.configVersion,
    required this.windowHours,
    required this.newSessionThreshold,
  });

  final String configVersion;
  final int windowHours;
  final int newSessionThreshold;
}

@immutable
final class LoopDeviceRiskSignals {
  const LoopDeviceRiskSignals({
    required this.newSessions24h,
    required this.highRiskNewDevice,
    required this.policy,
  });

  final int newSessions24h;
  final bool highRiskNewDevice;
  final LoopDeviceRiskPolicy policy;
}

/// `GET /v2/devices`. There is no cursor: [truncated] states that the server
/// stopped at its own limit.
@immutable
final class LoopDeviceDirectory {
  LoopDeviceDirectory({
    required List<LoopDeviceSession> devices,
    required this.currentSessionId,
    required this.riskSignals,
    required this.revokeAll,
    required this.truncated,
    required this.observedAt,
  }) : devices = List<LoopDeviceSession>.unmodifiable(devices);

  final List<LoopDeviceSession> devices;

  /// `null` when the request carried no `X-Loop-Session-ID`; every row is then
  /// `isCurrent: false` and no row may be presented as this device.
  final String? currentSessionId;
  final LoopDeviceRiskSignals riskSignals;

  /// Always unavailable in this step: signing every device out needs step-up.
  final LoopUnavailable revokeAll;
  final bool truncated;
  final DateTime observedAt;

  int get activeCount => devices.where((device) => device.isActive).length;

  int get deviceCount => devices
      .where((device) => device.isActive)
      .map((device) => device.deviceId)
      .toSet()
      .length;

  LoopDeviceSession? get current {
    for (final device in devices) {
      if (device.isCurrent) return device;
    }
    return null;
  }
}

/// `POST /v2/devices/{sessionId}/revoke`.
///
/// The effect is deliberately narrow: LOOP refuses later requests carrying the
/// revoked `X-Loop-Session-ID`, and nothing else. The other device's Privy
/// access token keeps working, so the UI must never say "已下线".
@immutable
final class LoopDeviceRevocation {
  const LoopDeviceRevocation({
    required this.sessionId,
    required this.revokedAt,
    required this.effect,
    required this.providerAccessTerminated,
  });

  static const auditOnlyEffect = 'auditOnly';

  final String sessionId;
  final DateTime revokedAt;

  /// Always `auditOnly`.
  final String effect;

  /// Always `false`.
  final bool providerAccessTerminated;
}

/// The six permanently unavailable Privy security methods, in contract order.
enum LoopSecurityCapabilityId {
  mfa('mfa', '多因素验证', '登录与敏感操作需要第二个因素。'),
  passkey('passkey', 'Passkey', '用设备生物识别代替密码。'),
  recoveryPassword('recoveryPassword', '恢复密码', '由你保管的一段口令，用来在新设备恢复钱包。'),
  autoRecovery('autoRecovery', '自动恢复', '由 Provider 托管的恢复分片。'),
  socialRecovery('socialRecovery', '社交恢复', '2-of-3 守护人共同确认才能恢复。'),
  keyExport('keyExport', '导出私钥', '把私钥带走，不受 LOOP 或 Privy 限制。');

  const LoopSecurityCapabilityId(this.wireName, this.label, this.description);

  final String wireName;
  final String label;
  final String description;

  static LoopSecurityCapabilityId? tryParse(String value) {
    for (final id in values) {
      if (id.wireName == value) return id;
    }
    return null;
  }
}

/// One `unavailable` security method plus the localisation key of its
/// "how to enable" explanation. There is no enabled variant in this step.
@immutable
final class LoopSecurityCapability {
  const LoopSecurityCapability({
    required this.id,
    required this.reasonCode,
    required this.evidenceReasonCode,
    required this.guideKey,
  });

  final LoopSecurityCapabilityId id;
  final String reasonCode;
  final String evidenceReasonCode;
  final String guideKey;
}

@immutable
final class LoopSecurityCapabilities {
  LoopSecurityCapabilities({required List<LoopSecurityCapability> items})
    : items = List<LoopSecurityCapability>.unmodifiable(items);

  final List<LoopSecurityCapability> items;

  LoopSecurityCapability? operator [](LoopSecurityCapabilityId id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// The device block of `GET /v2/security/summary`.
sealed class LoopSecurityDevicesBlock {
  const LoopSecurityDevicesBlock();
}

final class LoopSecurityDevicesAvailable extends LoopSecurityDevicesBlock {
  const LoopSecurityDevicesAvailable({
    required this.deviceCount,
    required this.activeSessionCount,
    required this.newSessions24h,
    required this.highRiskNewDevice,
    required this.policy,
  });

  final int deviceCount;
  final int activeSessionCount;
  final int newSessions24h;
  final bool highRiskNewDevice;
  final LoopDeviceRiskPolicy policy;
}

final class LoopSecurityDevicesUnavailable extends LoopSecurityDevicesBlock {
  const LoopSecurityDevicesUnavailable(this.fact);

  final LoopUnavailable fact;
}

/// The approvals block, projected from the S6 `GET /v2/approvals` summary.
sealed class LoopSecurityApprovalsBlock {
  const LoopSecurityApprovalsBlock();
}

final class LoopSecurityApprovalsAvailable extends LoopSecurityApprovalsBlock {
  const LoopSecurityApprovalsAvailable({
    required this.walletId,
    required this.activeCount,
    required this.unlimitedCount,
    required this.indexerBlockNumber,
    required this.approvalCoverageFromBlockNumber,
    required this.headBlockNumber,
    required this.observedAt,
  });

  final String walletId;
  final int activeCount;
  final int unlimitedCount;

  /// Kept as exact integer strings; never parsed into a `double`.
  final String indexerBlockNumber;

  /// The first block whose `Approval` events were decoded. The counts are only
  /// complete from here up: blocks below it were indexed for transfers only,
  /// so an approval granted earlier would be invisible. The page states it
  /// rather than implying the numbers cover all history.
  final String approvalCoverageFromBlockNumber;
  final String headBlockNumber;
  final DateTime observedAt;
}

final class LoopSecurityApprovalsUnavailable
    extends LoopSecurityApprovalsBlock {
  const LoopSecurityApprovalsUnavailable(this.fact);

  final LoopUnavailable fact;
}

/// The recent `security.event` block. An empty list is an empty state, not an
/// unavailable one.
sealed class LoopSecurityEventsBlock {
  const LoopSecurityEventsBlock();
}

final class LoopSecurityEventsAvailable extends LoopSecurityEventsBlock {
  LoopSecurityEventsAvailable({required List<LoopNotificationEntry> items})
    : items = List<LoopNotificationEntry>.unmodifiable(items);

  final List<LoopNotificationEntry> items;
}

final class LoopSecurityEventsUnavailable extends LoopSecurityEventsBlock {
  const LoopSecurityEventsUnavailable(this.fact);

  final LoopUnavailable fact;
}

/// `notifications.securityEvents`: always on and always locked.
@immutable
final class LoopSecurityNotificationLock {
  const LoopSecurityNotificationLock({
    required this.category,
    required this.enabled,
    required this.locked,
  });

  final LoopNotificationCategory category;
  final bool enabled;
  final bool locked;
}

/// `GET /v2/security/summary`. There is no score and no "all clear" badge.
@immutable
final class LoopSecuritySummary {
  const LoopSecuritySummary({
    required this.devices,
    required this.approvals,
    required this.securityEvents,
    required this.recentSecurityEvents,
    required this.observedAt,
  });

  final LoopSecurityDevicesBlock devices;
  final LoopSecurityApprovalsBlock approvals;
  final LoopSecurityNotificationLock securityEvents;
  final LoopSecurityEventsBlock recentSecurityEvents;
  final DateTime observedAt;
}
