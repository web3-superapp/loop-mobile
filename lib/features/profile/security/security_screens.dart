import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart'
    show walletAutomaticRecoveryEvidence;
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/security/security_controllers.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/features/security/mfa/passkey_sheet.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The four D20 security surfaces (decision 0037).
///
/// Nothing on these pages claims a protection is enabled, a device was signed
/// out, or a guardian exists. The prototype's score badge, "3 项保护已开启"
/// heading, device names, geography, exported-key variant and guardian samples
/// have no backend source and are deliberately absent.

/// What a method that the account could turn on, but has not, is called.
String get _securityMethodOffLabel =>
    LoopL10n.current.profileSecurity_screensSecurityMethodOffLabel;

/// What a method LOOP has not shipped is called.
///
/// 「未开启」 on a row whose own sentence says 「还没有开放」 reads as the
/// account's own omission, and the two badges sat side by side on one page.
/// A method nobody can turn on is not switched off; it does not exist yet.
String get _securityMethodDeferredLabel =>
    LoopL10n.current.profileSecurity_screensSecurityMethodDeferredLabel;

/// Whether this reason means LOOP has not delivered the method, as opposed to
/// the account not having enabled one that exists.
bool _securityMethodIsDeferred(String reasonCode) =>
    reasonCode.endsWith('_EVIDENCE_PENDING') ||
    reasonCode.endsWith('_NOT_DELIVERED') ||
    // Decision 0156: the `current` projection's passkey without a published
    // relying party. Nobody can turn it on until the server has one.
    reasonCode == 'PASSKEY_RELYING_PARTY_NOT_CONFIGURED' ||
    reasonCode.endsWith('_DEFERRED');

/// A row's state badge with the row's explanation behind an (i) before it
/// (S278 · decision 0236, 需求方第 12 条): the sentence that used to stand
/// under the title is one tap away; the title and the state stay.
Widget _securityRowInfo({
  required String keyName,
  required String title,
  required String body,
  required Widget trailing,
}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    LoopInfoButton(
      key: ValueKey<String>('$keyName-info'),
      title: title,
      sheetKey: '$keyName-info-sheet',
      notes: <LoopInfoNote>[LoopInfoNote(body: body)],
    ),
    const SizedBox(width: 4),
    trailing,
  ],
);

bool _securityBlocked(
  LoopChainGatewayMode mode,
  LoopCapabilityProjection capability,
) => loopChainCapabilityBlocks(mode, capability);

/// One `unavailable` security method row plus its "how to enable" note.
///
/// It takes the method's id and the server's own reason, so it can only ever
/// be built for a method that has one (decision 0156: an available method
/// has no reason and is drawn by `_availableMethodRow`).
class _SecurityMethodRow extends LoopRecordRow {
  _SecurityMethodRow({
    required ({LoopSecurityCapabilityId id, String reasonCode}) capability,
    required LoopRowPosition position,
    VoidCallback? onTap,
  }) : this._(
         capability: capability,
         deferred: _securityMethodIsDeferred(capability.reasonCode),
         position: position,
         onTap: onTap,
       );

  /// A deferred method says what it would do, because its own reason is the
  /// row's title with 「还没有开放」 after it and the badge already carries
  /// that. A method that exists keeps the server's sentence.
  _SecurityMethodRow._({
    required ({LoopSecurityCapabilityId id, String reasonCode}) capability,
    required bool deferred,
    required super.position,
    super.onTap,
  }) : super(
         key: ValueKey<String>('security-method-${capability.id.wireName}'),
         title: capability.id.label,
         // S278 · decision 0236: what a deferred method would do is behind
         // the row's (i); a method that exists keeps the server's reason.
         subtitle: deferred ? null : loopReasonCodeText(capability.reasonCode),
         subtitleMaxLines: 2,
         trailingBadge: deferred
             ? _securityRowInfo(
                 keyName: 'security-method-${capability.id.wireName}',
                 title: capability.id.label,
                 body: capability.id.description,
                 trailing: LoopBadge(_securityMethodDeferredLabel),
               )
             : LoopBadge(_securityMethodOffLabel),
         semanticLabel: deferred
             ? '${capability.id.label}${LoopL10n.current.common_listSeparator}$_securityMethodDeferredLabel${LoopL10n.current.common_listSeparator}'
                   '${capability.id.description}'
             : '${capability.id.label}${LoopL10n.current.common_listSeparator}$_securityMethodOffLabel${LoopL10n.current.common_listSeparator}'
                   '${loopReasonCodeText(capability.reasonCode)}',
       );
}

/// `security` · summary + the six unavailable methods + recent events.
class SecurityCenterScreen extends ConsumerStatefulWidget {
  const SecurityCenterScreen({
    required this.onNavigate,
    super.key,
    this.onBack,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<SecurityCenterScreen> createState() =>
      _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends ConsumerState<SecurityCenterScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final summary = ref.watch(securitySummaryControllerProvider);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked) {
      if (summary.phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(securitySummaryControllerProvider.notifier).load(),
            );
          }
        });
      }
      if (methods.phase == LoopChainViewPhase.loading) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(securityCapabilitiesControllerProvider.notifier).load(),
            );
          }
        });
      }
    }
    final resource = summary.value;
    // Decision 0156: an available MFA / Passkey row says what the provider
    // holds for this account, so the provider is asked once the server has
    // said the method works. The all-pending projection asks nothing.
    final mfa = ref.watch(loopMfaProvider);
    final asksProvider =
        methods.isReady &&
        methods.value!.items.any(
          (item) =>
              item.isAvailable &&
              item.id != LoopSecurityCapabilityId.autoRecovery,
        );
    if (asksProvider && mfa.phase == LoopMfaPhase.unknown) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(loopMfaProvider.notifier).load());
      });
    }
    final notOpen = methods.isReady
        ? methods.value!.items
              .where(
                (item) =>
                    !item.isAvailable &&
                    !loopHiddenSecurityCapabilities.contains(item.id),
              )
              .map((item) => item.id.label)
              .toList(growable: false)
        : null;
    final anyAvailable =
        methods.isReady && methods.value!.items.any((i) => i.isAvailable);

    // Decision 0126: flat sections. The Chalk posture card restated the
    // device count the 设备 row already carries, so it is gone.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('security-screen'),
        archetype: LoopPageArchetype.action,
        title: context.l10n.common_securityCenter,
        onBack: widget.onBack,
        block: blocked
            ? LoopCapabilityPageBlock.of(
                key: const ValueKey<String>('security-capability-block'),
                title: context
                    .l10n
                    .profileSecurity_screensSecurityCapabilityBlockTitle,
                capability: capability,
                fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
              )
            : null,
        sections: <Widget>[
          // 验证 and 恢复 are the prototype's own two groups; one 账户保护 list
          // of six put 「导出私钥」 next to 「多因素验证」 and lost the reading
          // order the page is arranged by (audit 2026-09-21 §J.5).
          if (!methods.isReady) ...<Widget>[
            LoopLabel(context.l10n.profileSecurity_screensLoopLabel),
            LoopChainStateBlock(
              keyPrefix: 'security-methods',
              phase: methods.phase,
              failureKind: methods.failureKind,
              emptyMessage: context.l10n.profileSecurity_screensEmptyMessage,
              onRetry: () => unawaited(
                ref
                    .read(securityCapabilitiesControllerProvider.notifier)
                    .reload(),
              ),
            ),
          ] else
            _SecurityMethodGroup(
              // S278 · decision 0236: the 「由 Privy 提供」 card that closed
              // the page is the (i) beside the first group's title.
              scopeNote: !anyAvailable
                  ? context.l10n.profileSecurity_screensScopeNote
                  : notOpen!.isEmpty
                  ? context.l10n.profileSecurity_screensScopeNote2
                  : context.l10n.profileSecurity_screensScopeNote3(
                      notOpen.join(
                        LoopL10n.current.profileSecurity_screensListSeparator,
                      ),
                    ),
              capabilities: methods.value!,
              onNavigate: widget.onNavigate,
              mfa: mfa,
              onOpenMfa: () => unawaited(showLoopMfaSheet(context)),
              onOpenPasskey: () => unawaited(showLoopPasskeySheet(context)),
              onRetryMfa: () =>
                  unawaited(ref.read(loopMfaProvider.notifier).load()),
            ),
          // Decision 0152: the large-amount step-up is this device's and this
          // account's own rule. It reads no security resource, so it stays
          // whatever the two reads above answered.
          LoopLabel(context.l10n.profileSecurity_screensLoopLabel2),
          // S288: the one row stands on the group's block like every other
          // group on this page; it reads its own state, so it goes in as a
          // child rather than a plain row.
          const LoopRecordGroup.children(
            key: ValueKey<String>('security-step-up-group'),
            children: <Widget>[LoopStepUpSettingRow()],
          ),
          LoopLabel(context.l10n.profileSecurity_screensLoopLabel3),
          if (!summary.isReady)
            LoopChainStateBlock(
              keyPrefix: 'security-summary',
              phase: summary.phase,
              failureKind: summary.failureKind,
              emptyMessage: context.l10n.profileSecurity_screensEmptyMessage2,
              onRetry: () => unawaited(
                ref.read(securitySummaryControllerProvider.notifier).reload(),
              ),
            )
          else ...<Widget>[
            _SecurityDevicesBlock(
              block: resource!.devices,
              onOpenDevices: () => widget.onNavigate('devices'),
            ),
            LoopLabel(context.l10n.common_tokenApprovals),
            _SecurityApprovalsBlock(block: resource.approvals),
            LoopLabel(context.l10n.common_notifications),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('security-notification-lock'),
                  title: context
                      .l10n
                      .profileSecurity_screensSecurityNotificationLockTitle,
                  subtitle: context
                      .l10n
                      .profileSecurity_screensSecurityNotificationLockSubtitle,
                  // 「保存的是意图，不代…」 stopped before the qualification that
                  // is the whole point of the sentence.
                  subtitleMaxLines: 2,
                  trailingBadge: LoopBadge(
                    context.l10n.common_on,
                    kind: LoopBadgeKind.up,
                  ),
                  onTap: () => widget.onNavigate('notif-settings'),
                ),
              ],
            ),
            LoopLabel(context.l10n.profileSecurity_screensLoopLabel4),
            _SecurityEventsBlock(block: resource.recentSecurityEvents),
            LoopProvenanceFooter(
              key: const ValueKey<String>('security-observed-at'),
              text: context.l10n.profileSecurity_screensSecurityObservedAtText(
                loopRelativeTime(resource.observedAt),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Methods the server still lists but the center no longer shows.
///
/// Decision 0151 (owner ruling 2026-10-12): 恢复密码 is not offered by LOOP.
/// `GET /v2/security/capabilities` still sends it and the codec still reads
/// it, so a response that carries it stays valid; the page just leaves it out.
const Set<LoopSecurityCapabilityId> loopHiddenSecurityCapabilities =
    <LoopSecurityCapabilityId>{LoopSecurityCapabilityId.recoveryPassword};

/// What an available method that the account has turned on is called.
String get _securityMethodOnLabel => LoopL10n.current.common_on;

/// What 自动恢复 is called when the server says its flow is available.
///
/// Decision 0158 (review of 0156): available is the server's word for "this
/// client's flow works", and 已开启 / 已启用 come only from the provider's
/// answer on this device. Nothing on the device reads 自动恢复 back, so the
/// row states that it is the default way, with its source, and never that it
/// is switched on.
String get _securityMethodDefaultLabel =>
    LoopL10n.current.profileSecurity_screensSecurityMethodDefaultLabel;

/// The 自动恢复 row's source line (decision 0156): the server's reference
/// without its engineering tag (「S60a: 」), else the S60a sentence itself.
String securityAutoRecoverySource(LoopSecurityCapability capability) {
  final reference = (capability.evidenceReference ?? '')
      .replaceFirst(RegExp(r'^[A-Za-z][A-Za-z0-9]*:\s*'), '')
      .trim();
  return reference.isEmpty ? walletAutomaticRecoveryEvidence : reference;
}

/// One method the `current` projection reports available (decision 0156).
///
/// Available is the server's word for "this client's flow works", never for
/// "this account has it". 已开启 / 未开启 come from the provider's own answer
/// on this device ([LoopMfaState]); before that answer the row says it is
/// reading, and an unanswered provider is not 未开启.
LoopRecordRow _availableMethodRow({
  required LoopSecurityCapability capability,
  required LoopMfaState mfa,
  required LoopRowPosition position,
  required VoidCallback onOpenMfa,
  required VoidCallback onOpenPasskey,
  required VoidCallback onRetry,
}) {
  final id = capability.id;
  final key = ValueKey<String>('security-method-${id.wireName}');
  if (id == LoopSecurityCapabilityId.autoRecovery) {
    final source = securityAutoRecoverySource(capability);
    return LoopRecordRow(
      key: key,
      title: id.label,
      trailingBadge: _securityRowInfo(
        keyName: key.value,
        title: id.label,
        body: source,
        trailing: LoopBadge(_securityMethodDefaultLabel),
      ),
      position: position,
      semanticLabel:
          '${id.label}${LoopL10n.current.common_listSeparator}$_securityMethodDefaultLabel${LoopL10n.current.common_listSeparator}$source',
    );
  }
  final passkey = id == LoopSecurityCapabilityId.passkey;
  if (passkey && !mfa.canUsePasskey) {
    // The server publishes the relying party, but this build carries no
    // domain credential: the sheet could not create anything here.
    final reason = loopMfaFailureText(
      LoopMfaFailureKind.passkeyDomainUnconfigured,
    );
    return LoopRecordRow(
      key: key,
      title: id.label,
      subtitle: reason,
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(LoopL10n.current.common_unavailable),
      position: position,
      semanticLabel: LoopL10n.current.profileSecurity_screensSemanticLabel(
        id.label,
        reason,
      ),
    );
  }
  switch (mfa.phase) {
    case LoopMfaPhase.unknown:
    case LoopMfaPhase.reading:
      return LoopRecordRow(
        key: key,
        title: id.label,
        trailingBadge: _securityRowInfo(
          keyName: key.value,
          title: id.label,
          body: id.description,
          trailing: LoopBadge(LoopL10n.current.common_loading),
        ),
        position: position,
        semanticLabel: LoopL10n.current.profileSecurity_screensSemanticLabel2(
          id.label,
        ),
      );
    case LoopMfaPhase.unavailable:
      final reason = loopMfaFailureText(
        mfa.failure ?? LoopMfaFailureKind.unavailable,
      );
      return LoopRecordRow(
        key: key,
        title: id.label,
        subtitle: LoopL10n.current.profileSecurity_screensSubtitle(reason),
        subtitleMaxLines: 2,
        trailingBadge: LoopBadge(
          LoopL10n.current.profileSecurity_screensLoopBadge,
        ),
        onTap: onRetry,
        position: position,
        semanticLabel: LoopL10n.current.profileSecurity_screensSemanticLabel3(
          id.label,
          reason,
        ),
      );
    case LoopMfaPhase.known:
      break;
  }
  final on = passkey ? mfa.hasPasskey : mfa.isEnrolled;
  final String detail;
  if (!on) {
    detail = id.description;
  } else if (passkey) {
    final named = mfa.passkeys
        .map((one) => one.label)
        .whereType<String>()
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);
    detail = named.isEmpty
        ? LoopL10n.current.profileSecurity_screensIf
        : named.join(' · ');
  } else {
    detail = mfa.enrollments.map((one) => one.kind.label).join(' · ');
  }
  final label = on ? _securityMethodOnLabel : _securityMethodOffLabel;
  final badge = LoopBadge(
    label,
    kind: on ? LoopBadgeKind.up : LoopBadgeKind.mute,
  );
  return LoopRecordRow(
    key: key,
    title: id.label,
    // S278 · decision 0236: what an unused method does is behind (i); what
    // the provider holds for this account is a fact and stays.
    subtitle: on ? detail : null,
    subtitleMaxLines: 2,
    trailingBadge: on
        ? badge
        : _securityRowInfo(
            keyName: key.value,
            title: id.label,
            body: detail,
            trailing: badge,
          ),
    onTap: mfa.isBusy ? null : (passkey ? onOpenPasskey : onOpenMfa),
    position: position,
    semanticLabel: on
        ? LoopL10n.current.profileSecurity_screensSemanticLabelDetail(
            detail,
            id.label,
            label,
          )
        : LoopL10n.current.profileSecurity_screensSemanticLabel4(
            id.label,
            label,
          ),
  );
}

class _SecurityMethodGroup extends StatelessWidget {
  const _SecurityMethodGroup({
    required this.scopeNote,
    required this.capabilities,
    required this.onNavigate,
    required this.mfa,
    required this.onOpenMfa,
    required this.onOpenPasskey,
    required this.onRetryMfa,
  });

  final LoopSecurityCapabilities capabilities;
  final ValueChanged<String> onNavigate;

  /// Who provides these protections, behind the first title's (i).
  final String scopeNote;

  /// The provider's answer about this account's second factor and passkeys.
  /// Read only by rows the server reports available.
  final LoopMfaState mfa;
  final VoidCallback onOpenMfa;
  final VoidCallback onOpenPasskey;
  final VoidCallback onRetryMfa;

  /// `验证` in the prototype: the two factors that guard a session.
  static const _verification = <LoopSecurityCapabilityId>{
    LoopSecurityCapabilityId.mfa,
    LoopSecurityCapabilityId.passkey,
  };

  List<LoopRecordRow> _rows(List<LoopSecurityCapability> items) {
    LoopRowPosition positionOf(int index) => items.length == 1
        ? LoopRowPosition.single
        : index == 0
        ? LoopRowPosition.first
        : index == items.length - 1
        ? LoopRowPosition.last
        : LoopRowPosition.middle;
    return <LoopRecordRow>[
      for (var index = 0; index < items.length; index += 1)
        if (items[index].isAvailable)
          _availableMethodRow(
            capability: items[index],
            mfa: mfa,
            position: positionOf(index),
            onOpenMfa: onOpenMfa,
            onOpenPasskey: onOpenPasskey,
            onRetry: onRetryMfa,
          )
        else
          _SecurityMethodRow(
            capability: (
              id: items[index].id,
              reasonCode:
                  items[index].reasonCode ?? items[index].evidenceReasonCode,
            ),
            position: positionOf(index),
            onTap: switch (items[index].id) {
              LoopSecurityCapabilityId.socialRecovery => () => onNavigate(
                'social-recovery',
              ),
              LoopSecurityCapabilityId.keyExport => () => onNavigate(
                'key-export',
              ),
              _ => null,
            },
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = capabilities.items
        .where((item) => !loopHiddenSecurityCapabilities.contains(item.id))
        .toList(growable: false);
    final verification = items
        .where((item) => _verification.contains(item.id))
        .toList(growable: false);
    final recovery = items
        .where((item) => !_verification.contains(item.id))
        .toList(growable: false);
    // Decision 0156: the guide explains only what is still not open. An
    // available method is explained by its own row.
    final deferred = items
        .where((item) => !item.isAvailable)
        .toList(growable: false);
    Widget title(String text, String id) => LoopInfoLabel(
      text,
      key: ValueKey<String>('security-label-$id'),
      info: LoopInfoButton(
        key: const ValueKey<String>('security-scope-info'),
        title: context.l10n.profileSecurity_screensSecurityScopeInfoTitle,
        sheetKey: 'security-scope-info-sheet',
        notes: <LoopInfoNote>[
          LoopInfoNote(
            key: const ValueKey<String>('security-scope-notice'),
            body: scopeNote,
          ),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        if (verification.isNotEmpty) ...<Widget>[
          title(context.l10n.profileSecurity_screensLoopLabel, 'verification'),
          LoopRecordGroup(rows: _rows(verification)),
        ],
        if (recovery.isNotEmpty) ...<Widget>[
          if (verification.isEmpty)
            title(context.l10n.profileSecurity_screensTitle, 'recovery')
          else
            LoopLabel(context.l10n.profileSecurity_screensTitle),
          LoopRecordGroup(rows: _rows(recovery)),
        ],
        if (deferred.isNotEmpty)
          LoopDisclosure(
            key: const ValueKey<String>('security-methods-guide'),
            summary:
                context.l10n.profileSecurity_screensSecurityMethodsGuideSummary,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final item in deferred)
                    Padding(
                      key: ValueKey<String>(
                        'security-methods-guide-${item.id.wireName}',
                      ),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.id.label, style: LoopType.title),
                          const SizedBox(height: 3),
                          Text(item.id.description, style: LoopType.bodySm),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SecurityDevicesBlock extends StatelessWidget {
  const _SecurityDevicesBlock({
    required this.block,
    required this.onOpenDevices,
  });

  final LoopSecurityDevicesBlock block;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityDevicesUnavailable(fact: final fact) =>
        LoopUnavailableLine.fact(
          key: const ValueKey<String>('security-devices-unavailable'),
          label: context
              .l10n
              .profileSecurity_screensSecurityDevicesUnavailableLabel,
          fact: fact,
        ),
      LoopSecurityDevicesAvailable(
        deviceCount: final count,
        activeSessionCount: final sessions,
        newSessions24h: final recent,
        highRiskNewDevice: final risky,
        policy: final policy,
      ) =>
        Column(
          children: <Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('security-devices-entry'),
                  title: context
                      .l10n
                      .profileSecurity_screensSecurityDevicesEntryTitle,
                  subtitle: context.l10n
                      .profileSecurity_screensSecurityDevicesEntrySubtitle(
                        recent,
                        sessions,
                        policy.windowHours,
                      ),
                  trailing: '$count',
                  onTap: onOpenDevices,
                ),
              ],
            ),
            if (risky)
              LoopNotice(
                key: const ValueKey<String>('security-high-risk-notice'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: context
                    .l10n
                    .profileSecurity_screensSecurityHighRiskNoticeTitle,
                body: context.l10n
                    .profileSecurity_screensSecurityHighRiskNoticeBody(
                      policy.newSessionThreshold,
                      recent,
                      policy.windowHours,
                    ),
                margin: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  12,
                  LoopSpacing.page,
                  0,
                ),
              ),
          ],
        ),
    };
  }
}

class _SecurityApprovalsBlock extends StatelessWidget {
  const _SecurityApprovalsBlock({required this.block});

  final LoopSecurityApprovalsBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityApprovalsUnavailable(fact: final fact) =>
        LoopUnavailableLine.fact(
          key: const ValueKey<String>('security-approvals-unavailable'),
          label: context
              .l10n
              .profileSecurity_screensSecurityApprovalsUnavailableLabel,
          fact: fact,
        ),
      LoopSecurityApprovalsAvailable(
        activeCount: final active,
        unlimitedCount: final unlimited,
        indexerBlockNumber: final indexed,
        approvalCoverageFromBlockNumber: final coverageFrom,
        headBlockNumber: final head,
        observedAt: final observedAt,
      ) =>
        Column(
          children: <Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('security-approvals-active'),
                  title: context
                      .l10n
                      .profileSecurity_screensSecurityApprovalsActiveTitle,
                  trailingBadge: LoopInfoButton(
                    key: ValueKey<String>('security-approvals-active-info'),
                    title: context
                        .l10n
                        .profileSecurity_screensSecurityApprovalsActiveTitle,
                    sheetKey: 'security-approvals-active-info-sheet',
                    notes: <LoopInfoNote>[
                      LoopInfoNote(
                        body: context.l10n.profileSecurity_screensBody,
                      ),
                    ],
                  ),
                  trailing: '$active',
                  position: LoopRowPosition.first,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('security-approvals-unlimited'),
                  title: context
                      .l10n
                      .profileSecurity_screensSecurityApprovalsUnlimitedTitle,
                  trailingBadge: LoopInfoButton(
                    key: ValueKey<String>('security-approvals-unlimited-info'),
                    title: context
                        .l10n
                        .profileSecurity_screensSecurityApprovalsUnlimitedTitle,
                    sheetKey: 'security-approvals-unlimited-info-sheet',
                    notes: <LoopInfoNote>[
                      LoopInfoNote(
                        body: context.l10n.profileSecurity_screensBody2,
                      ),
                    ],
                  ),
                  trailing: '$unlimited',
                  position: LoopRowPosition.last,
                ),
              ],
            ),
            LoopProvenanceFooter(
              key: const ValueKey<String>('security-approvals-freshness'),
              text: context.l10n
                  .profileSecurity_screensSecurityApprovalsFreshnessText(
                    loopGroupedFigure(coverageFrom.toString()),
                    loopGroupedFigure(indexed.toString()),
                    loopGroupedFigure(head.toString()),
                    loopRelativeTime(observedAt),
                  ),
            ),
          ],
        ),
    };
  }
}

class _SecurityEventsBlock extends StatelessWidget {
  const _SecurityEventsBlock({required this.block});

  final LoopSecurityEventsBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      LoopSecurityEventsUnavailable(fact: final fact) =>
        LoopUnavailableLine.fact(
          key: const ValueKey<String>('security-events-unavailable'),
          label: context
              .l10n
              .profileSecurity_screensSecurityEventsUnavailableLabel,
          fact: fact,
        ),
      LoopSecurityEventsAvailable(items: final items) when items.isEmpty =>
        LoopEmptyState(
          key: ValueKey<String>('security-events-empty'),
          illustration: LoopIllustration.history,
          title: context.l10n.profileSecurity_screensSecurityEventsEmptyTitle,
          message:
              context.l10n.profileSecurity_screensSecurityEventsEmptyMessage,
          compact: true,
        ),
      LoopSecurityEventsAvailable(items: final items) => LoopRecordGroup(
        rows: <LoopRecordRow>[
          for (final item in items)
            LoopRecordRow(
              key: ValueKey<String>('security-event-${item.notificationId}'),
              title: item.payload['event'] == 'session_revoked'
                  ? context.l10n.profileSecurity_screensTitle2
                  : context.l10n.profileSecurity_screensTitle3,
              subtitle:
                  '${item.payload['platform'] ?? LoopL10n.current.profileSecurity_screensPlatformUnlabeled} · '
                  '${loopRelativeTime(item.createdAt)}'
                  '${item.source == null ? '' : LoopL10n.current.profileSecurity_screensEventSourceSuffix(item.source)}',
              position: LoopRowPosition.middle,
            ),
        ],
      ),
    };
  }
}

/// `devices` · the session list plus the audit-only revoke command.
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  Future<void> _confirmRevoke(LoopDeviceSession device) async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => _RevokeConfirmSheet(device: device),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref
        .read(devicesControllerProvider.notifier)
        .revoke(device.sessionId);
    if (!mounted) return;
    LoopToast.show(
      context,
      message: ok
          ? LoopL10n.current.profileSecurity_screensMessage
          : LoopL10n.current.profileSecurity_screensMessage2,
      kind: ok ? LoopToastKind.warn : LoopToastKind.err,
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final state = ref.watch(devicesControllerProvider);
    if (!blocked && state.resource.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(devicesControllerProvider.notifier).load());
        }
      });
    }
    final directory = state.resource.value;
    final controller = ref.read(devicesControllerProvider.notifier);

    return LoopDashboardPage(
      key: const ValueKey<String>('devices-screen'),
      archetype: LoopPageArchetype.action,
      title: context.l10n.profileSecurity_screensDevicesScreenTitle,
      onBack: widget.onBack,
      // `.folio-primary.chalk-card`, as on the prototype's TRUSTED DEVICES
      // card. No stamp: LOOP has no trust signal to put in one.
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('devices-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.profileSecurity_screensDevicesFolioKicker,
        heading: directory == null
            ? context.l10n.profileSecurity_screensDevicesScreenTitle
            : context.l10n.profileSecurity_screensDevicesFolioHeading(
                directory.activeCount,
                directory.deviceCount,
              ),
        caption: context.l10n.profileSecurity_screensDevicesFolioCaption,
        ring: false,
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('devices-capability-block'),
              title: context
                  .l10n
                  .profileSecurity_screensDevicesCapabilityBlockTitle,
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      sections: <Widget>[
        if (state.commandFailureKind != null)
          LoopErrorState(
            key: const ValueKey<String>('devices-command-error'),
            title: context.l10n.profileSecurity_screensMessage2,
            reason: loopChainFailureReason(state.commandFailureKind),
            onRetry: () => unawaited(controller.reload()),
          ),
        if (state.outcome != null)
          LoopNotice(
            key: const ValueKey<String>('devices-revoke-outcome'),
            icon: 'info',
            tone: LoopNoticeTone.warn,
            title: context.l10n.profileSecurity_screensMessage,
            body: context.l10n.profileSecurity_screensDevicesRevokeOutcomeBody(
              state.outcome!.providerAccessTerminated,
            ),
          ),
        if (!state.resource.isReady)
          LoopChainStateBlock(
            keyPrefix: 'devices',
            phase: state.resource.phase,
            failureKind: state.resource.failureKind,
            emptyMessage: context.l10n.profileSecurity_screensEmptyMessage3,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          if (directory!.riskSignals.highRiskNewDevice)
            LoopNotice(
              key: const ValueKey<String>('devices-high-risk-notice'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context
                  .l10n
                  .profileSecurity_screensSecurityHighRiskNoticeTitle,
              body: context.l10n
                  .profileSecurity_screensDevicesHighRiskNoticeBody(
                    directory.riskSignals.policy.newSessionThreshold,
                    directory.riskSignals.newSessions24h,
                    directory.riskSignals.policy.windowHours,
                  ),
            ),
          if (directory.currentSessionId == null)
            LoopNotice(
              key: ValueKey<String>('devices-current-unknown'),
              icon: 'info',
              title: context
                  .l10n
                  .profileSecurity_screensDevicesCurrentUnknownTitle,
              body:
                  context.l10n.profileSecurity_screensDevicesCurrentUnknownBody,
            ),
          LoopLabel(context.l10n.profileSecurity_screensLoopLabel5),
          if (directory.devices.isEmpty)
            LoopEmptyState(
              key: ValueKey<String>('devices-state-empty'),
              illustration: LoopIllustration.profile,
              title: context.l10n.profileSecurity_screensDevicesStateEmptyTitle,
              message:
                  context.l10n.profileSecurity_screensDevicesStateEmptyMessage,
              compact: true,
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final device in directory.devices)
                  _deviceRow(device, busy: state.busy),
              ],
            ),
          if (directory.truncated)
            LoopNotice(
              key: ValueKey<String>('devices-truncated'),
              icon: 'info',
              title: context.l10n.profileSecurity_screensDevicesTruncatedTitle,
              body: context.l10n.profileSecurity_screensDevicesTruncatedBody,
            ),
          LoopLabel(context.l10n.profileSecurity_screensLoopLabel6),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('devices-revoke-all'),
              label: context.l10n.profileSecurity_screensDevicesRevokeAllLabel,
              block: true,
              // Always refused: it needs a second factor that does not exist.
              onPressed: null,
            ),
          ),
          LoopUnavailableLine.fact(
            key: const ValueKey<String>('devices-revoke-all-unavailable'),
            label: context
                .l10n
                .profileSecurity_screensDevicesRevokeAllUnavailableLabel,
            fact: directory.revokeAll,
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              12,
              LoopSpacing.page,
              0,
            ),
          ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('devices-observed-at'),
            text: context.l10n.profileSecurity_screensSecurityObservedAtText(
              loopRelativeTime(directory.observedAt),
            ),
          ),
        ],
        LoopNotice(
          key: ValueKey<String>('devices-effect-notice'),
          icon: 'shield',
          title: context.l10n.profileSecurity_screensDevicesEffectNoticeTitle,
          body: context.l10n.profileSecurity_screensDevicesEffectNoticeBody,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// One session row.
  ///
  /// Two sessions of the same device carry the same platform and the same
  /// client version, so 「iOS · 1.0.0 · 最后活跃 6 天前」 was the same string
  /// twice and the reader could not tell which one they were revoking. The row
  /// now carries the server's session short form and the session's own first
  /// login, and it distinguishes 本次会话 from an older session of the same
  /// device (decision 0049).
  LoopRecordRow _deviceRow(LoopDeviceSession device, {required bool busy}) {
    final revoked = !device.isActive;
    final badge = device.isCurrent
        ? LoopBadge(
            LoopL10n.current.profileSecurity_screensLoopBadge2,
            kind: LoopBadgeKind.up,
          )
        : (revoked
              ? LoopBadge(LoopL10n.current.profileSecurity_screensLoopBadge3)
              : (device.isCurrentDevice
                    ? LoopBadge(
                        LoopL10n.current.profileSecurity_screensLoopBadge4,
                      )
                    : LoopBadge(
                        LoopL10n.current.profileSecurity_screensLoopBadge5,
                        kind: LoopBadgeKind.mute,
                      )));
    // The session in hand is being used right now, so its bootstrap
    // observation time is not a fact worth printing beside it.
    final state = revoked
        ? LoopL10n.current.profileSecurity_screensDeviceRow(
            loopRelativeTime(device.revokedAt!),
          )
        : device.isCurrent
        ? LoopL10n.current.profileSecurity_screensDeviceRow2
        : LoopL10n.current.profileSecurity_screensS(
            loopRelativeTime(device.lastSeenAt),
          );
    final identity = LoopL10n.current.profileSecurity_screensIdentity(
      loopSessionCreatedAtLabel(device.createdAt),
      device.sessionShortId,
    );
    return LoopRecordRow(
      key: ValueKey<String>('device-${device.sessionId}'),
      leading: LoopIcon(
        device.platform == LoopDevicePlatform.ios ? 'phone' : 'laptop',
        semanticLabel: device.platform.label,
      ),
      title: device.displayName,
      subtitle: '$identity\n$state · ${device.authStrength.label}',
      subtitleMaxLines: 2,
      trailingBadge: badge,
      position: LoopRowPosition.middle,
      onTap: device.isCurrent || revoked || busy
          ? null
          : () => unawaited(_confirmRevoke(device)),
      semanticLabel: <String>[
        device.displayName,
        LoopL10n.current.profileSecurity_screensLoopRecordRow(
          device.sessionShortId,
        ),
        if (device.isCurrent)
          LoopL10n.current.profileSecurity_screensLoopBadge2
        else if (device.isOlderSessionOfThisDevice)
          LoopL10n.current.profileSecurity_screensLoopRecordRow2,
        revoked
            ? LoopL10n.current.profileSecurity_screensLoopBadge3
            : LoopL10n.current.profileSecurity_screensS2,
      ].join(LoopL10n.current.common_listSeparator),
    );
  }
}

/// The confirmation sheet for revoking one other session.
///
/// It states the real effect before the command, not after it.
class _RevokeConfirmSheet extends StatelessWidget {
  const _RevokeConfirmSheet({required this.device});

  final LoopDeviceSession device;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('device-revoke-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // R2 the one sheet-title step (decision 0191 M12).
        LoopSheetHeading(context.l10n.profileSecurity_screensLoopSheetHeading),
        LoopKeyValue(
          label: context.l10n.profileSecurity_screensLabel,
          value: device.platform.label,
        ),
        LoopKeyValue(
          label: context.l10n.profileSecurity_screensLabel2,
          value: device.clientVersion,
        ),
        // Which session this is: the sheet is the last screen before the
        // command, and two sessions of one device differ only here.
        LoopKeyValue(
          label: context.l10n.profileSecurity_screensLoopLabel5,
          value: device.sessionShortId,
        ),
        LoopKeyValue(
          label: context.l10n.profileSecurity_screensLabel3,
          value: loopSessionCreatedAtLabel(device.createdAt),
        ),
        if (device.isOlderSessionOfThisDevice)
          LoopKeyValue(
            label: context.l10n.profileSecurity_screensLabel4,
            value: context.l10n.profileSecurity_screensLoopRecordRow2,
          ),
        LoopKeyValue(
          label: context.l10n.profileSecurity_screensLabel5,
          value: loopRelativeTime(device.lastSeenAt),
        ),
        LoopNotice(
          key: ValueKey<String>('device-revoke-sheet-effect'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title:
              context.l10n.profileSecurity_screensDeviceRevokeSheetEffectTitle,
          body: context.l10n.profileSecurity_screensDeviceRevokeSheetEffectBody,
          margin: EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            14,
          ),
        ),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('device-revoke-cancel'),
              label: context.l10n.common_cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            LoopButton(
              key: const ValueKey<String>('device-revoke-confirm'),
              label:
                  context.l10n.profileSecurity_screensDeviceRevokeConfirmLabel,
              primary: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// `key-export` · explanation only. The export itself cannot run.
class KeyExportScreen extends ConsumerStatefulWidget {
  const KeyExportScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<KeyExportScreen> createState() => _KeyExportScreenState();
}

class _KeyExportScreenState extends ConsumerState<KeyExportScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked && methods.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(securityCapabilitiesControllerProvider.notifier).load(),
          );
        }
      });
    }
    final method = methods.value?[LoopSecurityCapabilityId.keyExport];

    return LoopFocusPage(
      key: const ValueKey<String>('key-export-screen'),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('key-export-capability-block'),
              title: context
                  .l10n
                  .profileSecurity_screensKeyExportCapabilityBlockTitle,
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      archetype: LoopPageArchetype.action,
      title: context.l10n.profileSecurity_modelsKeyExport,
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: ValueKey<String>('key-export-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.profileSecurity_screensKeyExportFolioKicker,
        heading: context.l10n.profileSecurity_screensKeyExportFolioHeading,
        caption: context.l10n.profileSecurity_screensKeyExportFolioCaption,
        stamp: context.l10n.profileSecurity_screensKeyExportFolioStamp,
        ring: false,
      ),
      body: <Widget>[
        LoopNotice(
          key: ValueKey<String>('key-export-risk'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title: context.l10n.profileSecurity_screensKeyExportRiskTitle,
          body: context.l10n.profileSecurity_screensKeyExportRiskBody,
        ),
        if (method == null)
          LoopChainStateBlock(
            keyPrefix: 'key-export',
            phase: methods.phase,
            failureKind: methods.failureKind,
            emptyMessage: context.l10n.profileSecurity_screensEmptyMessage4,
            skeleton: LoopSkeletonType.detail,
            onRetry: () => unawaited(
              ref
                  .read(securityCapabilitiesControllerProvider.notifier)
                  .reload(),
            ),
          )
        else
          LoopUnavailableLine(
            key: const ValueKey<String>('key-export-unavailable'),
            label: context
                .l10n
                .profileSecurity_screensKeyExportCapabilityBlockTitle,
            // The codec admits no available form for this method.
            reasonCode: method.reasonCode ?? method.evidenceReasonCode,
          ),
        LoopLabel(context.l10n.profileSecurity_screensLoopLabel7),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            // Both lines used to stop at an ellipsis one word before the
            // qualification that is their point (audit §J.7, §D #9).
            LoopRecordRow(
              key: ValueKey<String>('key-export-no-verification'),
              title: context
                  .l10n
                  .profileSecurity_screensKeyExportNoVerificationTitle,
              subtitle: context
                  .l10n
                  .profileSecurity_screensKeyExportNoVerificationSubtitle,
              subtitleMaxLines: 2,
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: ValueKey<String>('key-export-no-key'),
              title: context.l10n.profileSecurity_screensKeyExportNoKeyTitle,
              subtitle:
                  context.l10n.profileSecurity_screensKeyExportNoKeySubtitle,
              subtitleMaxLines: 2,
              position: LoopRowPosition.last,
            ),
          ],
        ),
      ],
      // The prototype lays this button out under the last row it belongs to,
      // not pinned above the bottom inset (§D #9).
      actionsFollowBody: true,
      primaryAction: LoopButton(
        key: ValueKey<String>('key-export-action'),
        label: context.l10n.profileSecurity_screensKeyExportActionLabel,
        block: true,
        primary: true,
        onPressed: null,
      ),
      disclosure: LoopDisclosure(
        key: const ValueKey<String>('key-export-control-disclosure'),
        summary: context
            .l10n
            .profileSecurity_screensKeyExportControlDisclosureSummary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            context.l10n.profileSecurity_screensText,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ),
    );
  }
}

/// `social-recovery` · the 2-of-3 explanation. No guardian list exists.
class SocialRecoveryScreen extends ConsumerStatefulWidget {
  const SocialRecoveryScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<SocialRecoveryScreen> createState() =>
      _SocialRecoveryScreenState();
}

class _SocialRecoveryScreenState extends ConsumerState<SocialRecoveryScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.security),
    );
    final mode = ref.watch(securityGatewayProvider).mode;
    final blocked = _securityBlocked(mode, capability);
    final methods = ref.watch(securityCapabilitiesControllerProvider);
    if (!blocked && methods.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(securityCapabilitiesControllerProvider.notifier).load(),
          );
        }
      });
    }
    final method = methods.value?[LoopSecurityCapabilityId.socialRecovery];

    return LoopFocusPage(
      key: const ValueKey<String>('social-recovery-screen'),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('social-recovery-capability-block'),
              title: context
                  .l10n
                  .profileSecurity_screensSocialRecoveryCapabilityBlockTitle,
              capability: capability,
              fallbackReasonCode: 'SECURITY_RUNTIME_UNAVAILABLE',
            )
          : null,
      archetype: LoopPageArchetype.action,
      title: context.l10n.profileSecurity_modelsSocialRecovery,
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: ValueKey<String>('social-recovery-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.profileSecurity_modelsSocialRecovery,
        heading: context.l10n.profileSecurity_screensSocialRecoveryFolioHeading,
        caption: context.l10n.profileSecurity_screensSocialRecoveryFolioCaption,
        stamp: context.l10n.profileSecurity_screensSocialRecoveryFolioStamp,
        ring: false,
      ),
      body: <Widget>[
        LoopNotice(
          key: ValueKey<String>('social-recovery-explainer'),
          icon: 'users',
          title:
              context.l10n.profileSecurity_screensSocialRecoveryExplainerTitle,
          body: context.l10n.profileSecurity_screensSocialRecoveryExplainerBody,
          margin: EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            14,
          ),
        ),
        if (method == null)
          LoopChainStateBlock(
            keyPrefix: 'social-recovery',
            phase: methods.phase,
            failureKind: methods.failureKind,
            emptyMessage: context.l10n.profileSecurity_screensEmptyMessage5,
            skeleton: LoopSkeletonType.detail,
            onRetry: () => unawaited(
              ref
                  .read(securityCapabilitiesControllerProvider.notifier)
                  .reload(),
            ),
          )
        else
          LoopUnavailableLine(
            key: const ValueKey<String>('social-recovery-unavailable'),
            label: context
                .l10n
                .profileSecurity_screensSocialRecoveryCapabilityBlockTitle,
            // The codec admits no available form for this method.
            reasonCode: method.reasonCode ?? method.evidenceReasonCode,
          ),
        // The prototype's own shape for "no guardians yet": a label and an
        // empty frame, not a paragraph about why the list is missing
        // (audit 2026-09-21 §J.8). No count: there is no guardian resource to
        // count, so 「0 / 3」 would be a figure with no source.
        LoopLabel(context.l10n.profileSecurity_screensLoopLabel8),
        LoopInlineUnavailable(
          key: ValueKey<String>('social-recovery-no-guardians'),
          icon: 'user',
          message: context
              .l10n
              .profileSecurity_screensSocialRecoveryNoGuardiansMessage,
          detail: context
              .l10n
              .profileSecurity_screensSocialRecoveryNoGuardiansDetail,
          maxLines: 2,
          detailMaxLines: 4,
        ),
      ],
      // The prototype puts 添加守护人 straight under the empty frame; pinned,
      // it sat about 280px below it (§D #9).
      actionsFollowBody: true,
      primaryAction: LoopButton(
        key: ValueKey<String>('social-recovery-action'),
        label: context.l10n.profileSecurity_screensSocialRecoveryActionLabel,
        block: true,
        primary: true,
        onPressed: null,
      ),
      disclosure: LoopDisclosure(
        key: const ValueKey<String>('social-recovery-disclosure'),
        summary:
            context.l10n.profileSecurity_screensSocialRecoveryDisclosureSummary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text(
            context.l10n.profileSecurity_screensText2,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      ),
    );
  }
}
