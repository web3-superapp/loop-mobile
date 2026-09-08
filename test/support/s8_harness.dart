import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

const s8CurrentSessionId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const s8OtherSessionId = '1c3d2e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';
const s8CurrentDeviceId = '2d4e3f50-6b7c-4d8e-8f90-1b2c3d4e5f60';
const s8OtherDeviceId = '3e5f4061-7c8d-4e9f-8a01-2c3d4e5f6071';
const s8TicketId = '4f60517 2-8d9e-4f0a-8b12-3d4e5f607182';
const s8NotificationId = '5a716283-9e0f-4a1b-8c23-4e5f60718293';

/// A port double that answers with a fixed value, a fixed failure, or never.
final class S8Answer<T> {
  S8Answer({this.value, this.failure, this.pending = false});

  final T? value;
  final LoopChainFailureKind? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final kind = failure;
    if (kind != null) return Future<T>.error(LoopChainException(kind));
    return Future<T>.value(value as T);
  }
}

LoopDeviceSession s8Device({
  String sessionId = s8CurrentSessionId,
  String deviceId = s8CurrentDeviceId,
  LoopDevicePlatform platform = LoopDevicePlatform.ios,
  bool isCurrent = true,
  bool revoked = false,
}) => LoopDeviceSession(
  sessionId: sessionId,
  deviceId: deviceId,
  platform: platform,
  clientVersion: '1.0.0',
  status: revoked
      ? LoopDeviceSessionStatus.revoked
      : LoopDeviceSessionStatus.active,
  authStrength: LoopDeviceAuthStrength.providerAuthenticated,
  isCurrent: isCurrent,
  createdAt: DateTime.utc(2026, 9, 8, 20),
  lastSeenAt: DateTime.utc(2026, 9, 9),
  revokedAt: revoked ? DateTime.utc(2026, 9, 9, 1) : null,
);

const s8RiskPolicy = LoopDeviceRiskPolicy(
  configVersion: 'deviceRiskV1',
  windowHours: 24,
  newSessionThreshold: 2,
);

LoopDeviceDirectory s8Directory({
  List<LoopDeviceSession>? devices,
  String? currentSessionId = s8CurrentSessionId,
  bool highRisk = false,
  bool truncated = false,
}) => LoopDeviceDirectory(
  devices:
      devices ??
      <LoopDeviceSession>[
        s8Device(),
        s8Device(
          sessionId: s8OtherSessionId,
          deviceId: s8OtherDeviceId,
          platform: LoopDevicePlatform.android,
          isCurrent: false,
        ),
      ],
  currentSessionId: currentSessionId,
  riskSignals: LoopDeviceRiskSignals(
    newSessions24h: highRisk ? 3 : 1,
    highRiskNewDevice: highRisk,
    policy: s8RiskPolicy,
  ),
  revokeAll: const LoopUnavailable('AUTH_STEP_UP_REQUIRED'),
  truncated: truncated,
  observedAt: DateTime.utc(2026, 9, 9, 2),
);

LoopSecurityCapabilities s8Capabilities() => LoopSecurityCapabilities(
  items: <LoopSecurityCapability>[
    for (final id in LoopSecurityCapabilityId.values)
      LoopSecurityCapability(
        id: id,
        reasonCode: switch (id) {
          LoopSecurityCapabilityId.mfa => 'PRIVY_MFA_EVIDENCE_PENDING',
          LoopSecurityCapabilityId.passkey => 'PRIVY_PASSKEY_EVIDENCE_PENDING',
          LoopSecurityCapabilityId.recoveryPassword =>
            'PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING',
          LoopSecurityCapabilityId.autoRecovery =>
            'PRIVY_AUTO_RECOVERY_EVIDENCE_PENDING',
          LoopSecurityCapabilityId.socialRecovery =>
            'PRIVY_SOCIAL_RECOVERY_EVIDENCE_PENDING',
          LoopSecurityCapabilityId.keyExport =>
            'PRIVY_KEY_EXPORT_EVIDENCE_PENDING',
        },
        evidenceReasonCode: 'PRIVY_MFA_EVIDENCE_PENDING',
        guideKey: 'security.capability.${id.wireName}.howToEnable',
      ),
  ],
);

LoopSecuritySummary s8Summary({
  bool approvalsAvailable = true,
  bool withEvent = false,
  bool highRisk = false,
}) => LoopSecuritySummary(
  devices: LoopSecurityDevicesAvailable(
    deviceCount: 2,
    activeSessionCount: 2,
    newSessions24h: highRisk ? 3 : 1,
    highRiskNewDevice: highRisk,
    policy: s8RiskPolicy,
  ),
  approvals: approvalsAvailable
      ? LoopSecurityApprovalsAvailable(
          walletId: s8NotificationId,
          activeCount: 3,
          unlimitedCount: 1,
          indexerBlockNumber: '120659683',
          headBlockNumber: '120661145',
          observedAt: DateTime.utc(2026, 9, 9, 2),
        )
      : const LoopSecurityApprovalsUnavailable(
          LoopUnavailable('SEND_APPROVALS_RUNTIME_DEFERRED'),
        ),
  securityEvents: const LoopSecurityNotificationLock(
    category: LoopNotificationCategory.securityEvent,
    enabled: true,
    locked: true,
  ),
  recentSecurityEvents: LoopSecurityEventsAvailable(
    items: withEvent
        ? <LoopNotificationEntry>[
            LoopNotificationEntry(
              notificationId: s8NotificationId,
              type: LoopNotificationCategory.securityEvent,
              entityRef: 'deviceSession:$s8OtherSessionId',
              contextRoute: 'devices',
              contextParams: const <String, String>{
                'sessionId': s8OtherSessionId,
              },
              payload: const <String, String?>{
                'event': 'session_revoked',
                'platform': 'android',
              },
              source: 'loop_session',
              observedAt: null,
              readAt: null,
              createdAt: DateTime.utc(2026, 9, 9, 1),
            ),
          ]
        : const <LoopNotificationEntry>[],
  ),
  observedAt: DateTime.utc(2026, 9, 9, 2),
);

const s8SettingsValues = LoopAccountSettingsValues(
  displayCurrency: 'USD',
  language: 'zh-CN',
);

LoopAccountSettings s8Settings({int version = 0}) => LoopAccountSettings(
  values: s8SettingsValues,
  version: version,
  updatedAt: version == 0 ? null : DateTime.utc(2026, 9, 9),
  policy: LoopAccountSettingsPolicy(
    configVersion: 'accountSettingsV1',
    fixed: s8SettingsValues,
    localOnly: const <String>['reduceMotion', 'theme'],
  ),
);

LoopAbout s8About() => LoopAbout(
  contractVersion: '2.0',
  configVersions: <LoopAboutConfigVersion>[
    LoopAboutConfigVersion(
      module: 'productPolicy',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
    ),
    const LoopAboutConfigVersion(
      module: 'support',
      configVersion: 'supportPolicyV1',
      effectiveAt: null,
    ),
  ],
  termsGate: const LoopAboutTermsGate(
    requiredVersion: null,
    reasonCode: 'TERMS_POLICY_UNAVAILABLE',
  ),
  openSource: LoopOpenSourceRegister(
    source: 'docs/open-source-attribution.md',
    summary: 'This register covers the direct runtime dependencies.',
    entries: const <LoopOpenSourceEntry>[
      LoopOpenSourceEntry(
        name: 'Fastify',
        purpose: 'HTTP server and route lifecycle',
        license: 'MIT',
      ),
    ],
  ),
  clientBuildReasonCode: 'CLIENT_BUILD_IS_DEVICE_LOCAL',
);

const s8SupportPolicy = LoopSupportPolicy(
  configVersion: 'supportPolicyV1',
  responseWindowHours: 24,
  businessDaysOnly: true,
  escalationChannel: 'copy',
);

LoopSupportTicket s8Ticket({
  LoopSupportTicketStatus status = LoopSupportTicketStatus.open,
  String body = '为什么我的币没有权重',
}) => LoopSupportTicket(
  ticketId: s8NotificationId,
  category: LoopSupportCategory.mining,
  body: body,
  status: status,
  createdAt: DateTime.utc(2026, 9, 9),
  updatedAt: DateTime.utc(2026, 9, 9),
  lastEventAt: DateTime.utc(2026, 9, 9),
  events: <LoopSupportEvent>[
    LoopSupportEvent(
      eventVersion: 0,
      eventType: LoopSupportEventType.created,
      actor: LoopSupportActor.user,
      note: null,
      occurredAt: DateTime.utc(2026, 9, 9),
    ),
    if (status == LoopSupportTicketStatus.answered)
      LoopSupportEvent(
        eventVersion: 1,
        eventType: LoopSupportEventType.answered,
        actor: LoopSupportActor.operator,
        note: '已核对，权重需要资产先完成登记。',
        occurredAt: DateTime.utc(2026, 9, 9, 1),
      ),
  ],
);

LoopSupportTicketPage s8TicketPage({
  List<LoopSupportTicket>? items,
  String? nextCursor,
}) => LoopSupportTicketPage(
  items: items ?? <LoopSupportTicket>[s8Ticket()],
  nextCursor: nextCursor,
  attachments: const LoopUnavailable('SUPPORT_ATTACHMENTS_UNAVAILABLE'),
  policy: s8SupportPolicy,
);

final class FakeSecurityGateway implements SecurityGateway {
  FakeSecurityGateway({
    S8Answer<LoopDeviceDirectory>? devices,
    S8Answer<LoopSecurityCapabilities>? capabilities,
    S8Answer<LoopSecuritySummary>? summary,
    this.revokeFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : devices = devices ?? S8Answer<LoopDeviceDirectory>(value: s8Directory()),
       capabilities =
           capabilities ??
           S8Answer<LoopSecurityCapabilities>(value: s8Capabilities()),
       summary = summary ?? S8Answer<LoopSecuritySummary>(value: s8Summary());

  final S8Answer<LoopDeviceDirectory> devices;
  final S8Answer<LoopSecurityCapabilities> capabilities;
  final S8Answer<LoopSecuritySummary> summary;
  final LoopChainFailureKind? revokeFailure;
  final List<String> revoked = <String>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopDeviceDirectory> loadDevices() => devices.resolve();

  @override
  Future<LoopSecurityCapabilities> loadCapabilities() => capabilities.resolve();

  @override
  Future<LoopSecuritySummary> loadSummary() => summary.resolve();

  @override
  Future<LoopDeviceRevocation> revokeDevice(String sessionId) {
    revoked.add(sessionId);
    final failure = revokeFailure;
    if (failure != null) {
      return Future<LoopDeviceRevocation>.error(LoopChainException(failure));
    }
    return Future<LoopDeviceRevocation>.value(
      LoopDeviceRevocation(
        sessionId: sessionId,
        revokedAt: DateTime.utc(2026, 9, 9, 3),
        effect: LoopDeviceRevocation.auditOnlyEffect,
        providerAccessTerminated: false,
      ),
    );
  }
}

final class FakeAccountSettingsGateway implements AccountSettingsGateway {
  FakeAccountSettingsGateway({
    S8Answer<LoopAccountSettings>? settings,
    this.mode = LoopChainGatewayMode.production,
  }) : settings =
           settings ?? S8Answer<LoopAccountSettings>(value: s8Settings());

  final S8Answer<LoopAccountSettings> settings;

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopAccountSettings> load() => settings.resolve();

  @override
  Future<LoopAccountSettings> replace({
    required int expectedVersion,
    required LoopAccountSettingsValues values,
  }) => settings.resolve();
}

final class FakeAboutGateway implements AboutGateway {
  FakeAboutGateway({
    S8Answer<LoopAbout>? about,
    this.mode = LoopChainGatewayMode.production,
  }) : about = about ?? S8Answer<LoopAbout>(value: s8About());

  final S8Answer<LoopAbout> about;

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopAbout> load() => about.resolve();
}

final class FakeSupportGateway implements SupportGateway {
  FakeSupportGateway({
    S8Answer<LoopSupportTicketPage>? page,
    this.createFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : page = page ?? S8Answer<LoopSupportTicketPage>(value: s8TicketPage());

  final S8Answer<LoopSupportTicketPage> page;
  final LoopChainFailureKind? createFailure;
  final List<LoopSupportDraft> created = <LoopSupportDraft>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopSupportTicketPage> listTickets({String? cursor}) => page.resolve();

  @override
  Future<LoopSupportTicketResult> createTicket(LoopSupportDraft draft) {
    created.add(draft);
    final failure = createFailure;
    if (failure != null) {
      return Future<LoopSupportTicketResult>.error(LoopChainException(failure));
    }
    return Future<LoopSupportTicketResult>.value(
      LoopSupportTicketResult(
        ticket: s8Ticket(body: draft.body),
        attachments: const LoopUnavailable('SUPPORT_ATTACHMENTS_UNAVAILABLE'),
        policy: s8SupportPolicy,
      ),
    );
  }
}

/// A capability document with the three S8 modules set explicitly.
LoopV2MetaSnapshot s8MetaSnapshot({
  LoopV2CapabilityAvailability security =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability settings =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability support = LoopV2CapabilityAvailability.available,
}) {
  return LoopV2MetaSnapshot(
    clientPolicy: LoopV2ClientPolicy(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      defaultRoute: LoopV2PrimaryTab.community,
      navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
      versionGate: const LoopV2VersionGate.unavailable(
        reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
      ),
      regionGate: const LoopV2RegionGate(
        status: LoopV2RegionGateStatus.unavailable,
        reasonCode: 'REGION_POLICY_UNAVAILABLE',
        supportUrl: null,
        readOnlyAssetAccess: null,
      ),
      termsGate: const LoopV2TermsGate(
        status: LoopV2TermsGateStatus.unavailable,
        requiredVersion: null,
        reasonCode: 'TERMS_POLICY_UNAVAILABLE',
      ),
    ),
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      capabilities: <LoopV2Capability>[
        for (final id in LoopV2CapabilityId.values)
          LoopV2Capability(
            id: id,
            availability: switch (id) {
              LoopV2CapabilityId.security => security,
              LoopV2CapabilityId.settings => settings,
              LoopV2CapabilityId.support => support,
              _ => LoopV2CapabilityAvailability.unavailable,
            },
            reasonCode: switch (id) {
              LoopV2CapabilityId.security =>
                security == LoopV2CapabilityAvailability.available
                    ? null
                    : 'SECURITY_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.settings =>
                settings == LoopV2CapabilityAvailability.available
                    ? null
                    : 'SETTINGS_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.support =>
                support == LoopV2CapabilityAvailability.available
                    ? null
                    : 'SUPPORT_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.pay => 'PAY_RUNTIME_DEFERRED',
              LoopV2CapabilityId.bridge => 'BRIDGE_RUNTIME_DEFERRED',
              LoopV2CapabilityId.dappExecution =>
                'DAPP_EXECUTION_RUNTIME_DEFERRED',
              _ => 'CAPABILITY_NOT_DELIVERED',
            },
            evidence: const LoopV2CapabilityEvidence(
              status: LoopV2CapabilityEvidenceStatus.notApplicable,
              reasonCode: null,
            ),
          ),
      ],
    ),
  );
}

/// Mounts one S8 page with its ports and the capability document.
Future<void> pumpS8Page(
  WidgetTester tester,
  Widget page, {
  SecurityGateway? security,
  AccountSettingsGateway? settings,
  AboutGateway? about,
  SupportGateway? support,
  LoopV2MetaSnapshot? meta,
  Size size = const Size(390, 3200),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (security != null)
          securityGatewayProvider.overrideWithValue(security),
        if (settings != null)
          accountSettingsGatewayProvider.overrideWithValue(settings),
        if (about != null) aboutGatewayProvider.overrideWithValue(about),
        if (support != null) supportGatewayProvider.overrideWithValue(support),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => meta ?? s8MetaSnapshot(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

/// Scrolls the page's own collection until [finder] is built and visible.
Future<void> scrollToS8Section(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
}
