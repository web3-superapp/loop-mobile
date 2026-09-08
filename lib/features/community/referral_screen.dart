import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// zh-CN copy for one versioned referral level description key.
String referralLevelDescription(String descriptionKey) =>
    switch (descriptionKey) {
      'mining.referral.level1' => 'L1 · 我直接邀请并经服务端验证的人',
      'mining.referral.level2' => 'L2 · 我的 L1 再邀请的人',
      'mining.referral.level3' => 'L3 · 我的 L2 再邀请的人',
      'mining.referral.level4' => 'L4 · 我的 L3 再邀请的人',
      'mining.referral.level5' => 'L5 · 我的 L4 再邀请的人',
      _ => '服务端定义的关系层级',
    };

/// `referral` · read-only rules.
///
/// The five ratios come from `GET /v2/mining/referral/rules`. Relationship
/// counts and the invite code have no source and stay unavailable, so the
/// share action is disabled rather than promising a relationship.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key, this.onBack, this.onOpenMining});

  final VoidCallback? onBack;

  /// The prototype's "back to mining" control. Referral is a Mining Power
  /// rule page, so it offers a way back to the Mining tab.
  final VoidCallback? onOpenMining;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(referralRulesControllerProvider);
    final controller = ref.read(referralRulesControllerProvider.notifier);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    final rules = state.value;
    return LoopDashboardPage(
      key: const ValueKey<String>('referral-screen'),
      archetype: LoopPageArchetype.record,
      title: 'Referral Boost',
      // The Preview label is added to the page's own eyebrow, never instead
      // of it: both facts stay visible.
      kicker: communityPreviewKicker(mode) == null
          ? 'MINING POWER · SERVER VERIFIED'
          : 'MINING POWER · ${communityPreviewKicker(mode)}',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('referral-explain-action'),
          icon: 'info',
          label: 'Referral 说明',
          onPressed: () => unawaited(_explain()),
        ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'REFERRAL RULES',
        // The final boost figure needs the relationship graph, which has no
        // source: the heading states the rule version instead of a number.
        heading: rules == null
            ? communityMissingFigure
            : '五级关系加成 · ${rules.configVersion}',
        caption: '加成只计入 Mining Power，不是收入、佣金或返佣。关系人数当前没有来源。',
        stamp: rules == null ? null : 'READ ONLY',
      ),
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '邀请规则'),
        if (communityCapabilityBlocks(mode, capability))
          LoopEmpty(
            key: const ValueKey<String>('referral-capability-unavailable'),
            icon: 'warn',
            message: '邀请规则当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求邀请规则。'
                : '服务端原因：${capability.reasonCode}。',
          )
        else if (rules == null)
          CommunityStateBlock(
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到邀请规则',
            emptyReason: '服务端没有返回版本化的比例配置。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('五级比例'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (var index = 0; index < rules.levels.length; index += 1)
                _levelRow(rules.levels[index], index, rules.levels.length),
            ],
          ),
          const LoopLabel('关系深度'),
          CommunityUnavailableCard(label: '各级关系人数', fact: rules.edges),
          const LoopLabel('邀请码'),
          CommunityUnavailableCard(label: '我的邀请码', fact: rules.inviteCode),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('referral-back-to-mining'),
                label: '返回挖矿',
                onPressed: widget.onOpenMining,
              ),
              LoopButton(
                key: const ValueKey<String>('referral-invite-action'),
                label: '邀请好友',
                // Disabled: there is no invite code to share.
                onPressed: null,
              ),
            ],
          ),
          LoopNotice(
            key: const ValueKey<String>('referral-mining-only'),
            icon: 'info',
            title: '只计入 Mining Power',
            body:
                '这是 Mining Power 加成，不是收入、佣金或返佣。分享完成不代表关系成立；'
                '关系是否有效由服务端在 ${rules.appliesTo} 口径下验证。'
                '规则版本 ${rules.configVersion}，生效于 '
                '${communityObservedAtLabel(rules.effectiveAt)}。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// The prototype's topbar info control. It restates the rule's scope; it
  /// never adds a figure the server did not send.
  Future<void> _explain() => showLoopSheet<void>(
    context,
    barrierLabel: '关闭 Referral 说明',
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('referral-explain-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Referral 说明',
            style: LoopTypography.sora(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '五级比例来自服务端的版本化配置，不随账号变化。加成只计入 Mining Power，'
            '不是收入、佣金或返佣。各级关系人数与邀请码还没有服务端来源，'
            '因此本页不显示任何人数，「邀请好友」也保持禁用。',
            style: LoopTypography.sora(
              size: 13,
              weight: FontWeight.w500,
              color: LoopColors.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          LoopButton(
            key: const ValueKey<String>('referral-explain-close'),
            label: '知道了',
            block: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );

  LoopRecordRow _levelRow(ReferralLevel level, int index, int length) {
    return LoopRecordRow(
      key: ValueKey<String>('referral-level-${level.level}'),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: level.level == 1 ? LoopColors.lime : LoopColors.card2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'L${level.level}',
          style: LoopTypography.mono(
            size: 12,
            weight: FontWeight.w700,
            color: level.level == 1 ? LoopColors.ink : LoopColors.chalk,
          ),
        ),
      ),
      title: 'L${level.level} · ${level.boostPercent}%',
      subtitle: referralLevelDescription(level.descriptionKey),
      // Relationship counts are unavailable, so the row shows the em dash
      // rather than a zero.
      trailing: communityMissingFigure,
      trailingCaption: '关系数',
      position: communityRowPosition(index, length),
      semanticLabel: 'L${level.level}，加成 ${level.boostPercent}%，关系数暂无来源',
    );
  }
}
