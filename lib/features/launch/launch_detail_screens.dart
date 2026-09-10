import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Shared scaffolding for the six read-only launch record pages.
///
/// Each page owns its own capability gate, its own five states and its own
/// subject; a failing block never blanks a sibling that did load.
abstract class _LaunchRecordScreen extends ConsumerStatefulWidget {
  const _LaunchRecordScreen({super.key, this.launchId, this.onBack});

  final String? launchId;
  final VoidCallback? onBack;
}

/// `launch-detail` · one launch record.
class LaunchDetailScreen extends _LaunchRecordScreen {
  const LaunchDetailScreen({
    super.key,
    super.launchId,
    super.onBack,
    this.onOpenTier,
    this.onOpenRounds,
    this.onOpenTrade,
    this.onOpenHolders,
    this.onOpenGraduation,
    this.onOpenHistory,
  });

  final VoidCallback? onOpenTier;
  final VoidCallback? onOpenRounds;
  final VoidCallback? onOpenTrade;
  final VoidCallback? onOpenHolders;
  final VoidCallback? onOpenGraduation;
  final VoidCallback? onOpenHistory;

  @override
  ConsumerState<LaunchDetailScreen> createState() => _LaunchDetailScreenState();
}

class _LaunchDetailScreenState extends ConsumerState<LaunchDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final config = detail?.config;
    final pendingVersion = detail?.pendingConfigVersion;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-detail-screen'),
      archetype: LoopPageArchetype.record,
      title: detail?.launch.ticker ?? '项目详情',
      kicker: 'LAUNCH RECORD',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-detail-rounds-action'),
          icon: 'info',
          label: '轮次规则',
          onPressed: widget.onOpenRounds,
        ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'LAUNCH RECORD',
        heading: detail?.launch.name ?? launchMissingFigure,
        // No countdown, no round label, no progress: all three are contract
        // facts. The caption states what the record can and cannot prove.
        caption: '项目资料与轮次配置由 LOOP 提供；链上状态、价格与毕业进度暂时读不到。',
        stamp: detail == null
            ? null
            : launchPendingConfirmationLabel(pendingVersion),
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-detail-capability-unavailable'),
            icon: 'warn',
            message: '项目详情当前不可用',
            reason: '请稍后再试。',
          )
        else if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-detail',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到这个项目',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(
              capability: capability,
              launch: detail.launch,
            ),
          ),
          if (detail.project.narrative != null)
            LoopNotice(
              key: const ValueKey<String>('launch-detail-narrative'),
              icon: 'info',
              title: '${detail.project.name} · ${detail.project.ticker}',
              body: detail.project.narrative!,
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          const LoopLabel('链上四轴'),
          LaunchAxisBlock(state: detail.launch.onChainState),
          const LoopLabel('配置'),
          if (config == null)
            const LoopEmpty(
              key: ValueKey<String>('launch-detail-no-config'),
              icon: 'warn',
              message: '还没有任何配置版本',
              reason: '轮次、上限与费率都要等到配置版本被确认后才有数值。',
            )
          else
            LoopRecordGroup(
              key: const ValueKey<String>('launch-detail-slots'),
              rows: <LoopRecordRow>[
                for (
                  var index = 0;
                  index < config.slots.entries.length;
                  index += 1
                )
                  launchConfigSlotRow(
                    label: config.slots.entries[index].$1,
                    slot: config.slots.entries[index].$2,
                    configVersion: config.configVersion,
                    position: launchRowPosition(
                      index,
                      config.slots.entries.length,
                    ),
                  ),
              ],
            ),
          if (detail.configPending != null)
            LaunchUnavailableCard(
              label: '已确认的配置版本',
              fact: detail.configPending!,
            ),
          const LoopLabel('轮次'),
          _RoundsBlock(rounds: detail.rounds),
          const LoopLabel('行情与持有人'),
          LaunchUnavailableCard(label: '内盘行情', fact: detail.market),
          LaunchUnavailableCard(label: '持有人分布', fact: detail.holders),
          const LoopLabel('相关页面'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-tier'),
                title: '我的资格',
                subtitle: '资格规则由每次发射自己决定，不依赖质押',
                onTap: widget.onOpenTier,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-holders'),
                title: '内盘持有人',
                subtitle: '需要链上读数，当前不可得',
                onTap: widget.onOpenHolders,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-graduation'),
                title: '毕业与迁移',
                subtitle: '四个步骤全部待触发',
                onTap: widget.onOpenGraduation,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-history'),
                title: '我的参与记录',
                subtitle: '记录暂时读不到，空列表不代表你没有参与',
                onTap: widget.onOpenHistory,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          _LinksBlock(links: detail.project.officialLinks),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-detail-open-trade'),
                label: '进入内盘交易',
                onPressed: widget.onOpenTrade,
              ),
            ],
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-detail-baseline-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '不显示未经证明的数字',
            body:
                '${launchReasonCodeText('LAUNCH_CONTRACT_BASELINE_PENDING')}'
                '资料版本 ${detail.project.materialVersion}，'
                '登记于 ${launchTimestampLabel(detail.launch.createdAt)}。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _RoundsBlock extends StatelessWidget {
  const _RoundsBlock({required this.rounds});

  final List<LaunchRound> rounds;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-rounds-empty'),
        icon: 'warn',
        message: '还没有配置任何轮次',
        reason: '轮次数量由每次发射自己决定。',
      );
    }
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-rounds-list'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < rounds.length; index += 1)
          launchRoundRow(
            round: rounds[index],
            position: launchRowPosition(index, rounds.length),
          ),
      ],
    );
  }
}

class _LinksBlock extends StatelessWidget {
  const _LinksBlock({required this.links});

  final LaunchOfficialLinks links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('官方链接'),
        for (final entry in links.entries)
          LoopKeyValue(
            key: ValueKey<String>('launch-link-${entry.$1}'),
            label: entry.$1,
            value: entry.$2,
          ),
      ],
    );
  }
}

/// `launch-rounds` · the configured round slots for one launch.
class LaunchRoundsScreen extends _LaunchRecordScreen {
  const LaunchRoundsScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchRoundsScreen> createState() => _LaunchRoundsScreenState();
}

class _LaunchRoundsScreenState extends ConsumerState<LaunchRoundsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final config = detail?.config;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-rounds-screen'),
      archetype: LoopPageArchetype.record,
      title: '销售轮次规则',
      kicker: 'ROUND CONFIGURATION',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'ROUND CONFIGURATION',
        // The number of rounds comes from the configuration, never from a
        // fixed three-round story.
        heading: detail == null
            ? launchMissingFigure
            : '${detail.rounds.length} 个轮次',
        caption: '轮数、时间、价格、资格与上限都由这次发射的配置决定；还没确认的显示为待确认。',
        stamp: detail == null
            ? null
            : launchPendingConfirmationLabel(config?.configVersion),
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-rounds-capability-unavailable'),
            icon: 'warn',
            message: '轮次规则当前不可用',
            reason: '请稍后再试。',
          )
        else if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-rounds',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到轮次配置',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(
              capability: capability,
              launch: detail.launch,
            ),
          ),
          const LoopLabel('轮次'),
          _RoundsBlock(rounds: detail.rounds),
          const LoopLabel('合约限制'),
          if (config == null)
            const LoopEmpty(
              key: ValueKey<String>('launch-rounds-no-config'),
              icon: 'warn',
              message: '还没有任何配置版本',
              reason: '上限与费率要等到配置版本被确认后才有数值。',
            )
          else
            LoopRecordGroup(
              key: const ValueKey<String>('launch-rounds-slots'),
              rows: <LoopRecordRow>[
                for (
                  var index = 0;
                  index < config.slots.entries.length;
                  index += 1
                )
                  launchConfigSlotRow(
                    label: config.slots.entries[index].$1,
                    slot: config.slots.entries[index].$2,
                    configVersion: config.configVersion,
                    position: launchRowPosition(
                      index,
                      config.slots.entries.length,
                    ),
                  ),
              ],
            ),
          if (detail.configPending != null)
            LaunchUnavailableCard(
              label: '已确认的配置版本',
              fact: detail.configPending!,
            ),
          LoopNotice(
            key: const ValueKey<String>('launch-rounds-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '以最终确认的规则为准',
            body:
                '本页不写入任何固定的轮数、手续费率、持仓上限或毕业市值。'
                '${launchReasonCodeText('LAUNCH_CONFIG_PENDING_CONFIRMATION')}',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-graduation` · the four migration steps.
class LaunchGraduationScreen extends _LaunchRecordScreen {
  const LaunchGraduationScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchGraduationScreen> createState() =>
      _LaunchGraduationScreenState();
}

class _LaunchGraduationScreenState
    extends ConsumerState<LaunchGraduationScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final steps = detail?.graduation.steps ?? const <LaunchGraduationStep>[];

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-graduation-screen'),
      archetype: LoopPageArchetype.record,
      title: '毕业与迁移',
      kicker: 'GRADUATION PROGRESS',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'GRADUATION PROGRESS',
        // Never a percentage: progress needs the liquidity axis.
        heading: launchMissingFigure,
        caption: '毕业进度看的是流动性。合约上线前还没有可核对的进度。',
        stamp: 'PENDING',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>(
              'launch-graduation-capability-unavailable',
            ),
            icon: 'warn',
            message: '毕业进度当前不可用',
            reason: '请稍后再试。',
          )
        else if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-graduation',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到毕业记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('迁移步骤'),
          LoopRecordGroup(
            key: const ValueKey<String>('launch-graduation-steps'),
            rows: <LoopRecordRow>[
              for (var index = 0; index < steps.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'launch-graduation-step-${steps[index].step.wireName}',
                  ),
                  leading: _StepIndexTile(index: index + 1),
                  title: launchGraduationStepLabel(steps[index].step),
                  subtitle: '每一步完成后才进入下一步',
                  trailingBadge: const LoopBadge(
                    '待触发',
                    kind: LoopBadgeKind.mute,
                  ),
                  position: launchRowPosition(index, steps.length),
                  semanticLabel:
                      '${launchGraduationStepLabel(steps[index].step)}，待触发',
                ),
            ],
          ),
          const LoopLabel('流动性池信息'),
          LaunchUnavailableCard(
            label: '池地址与锁定信息',
            fact: detail.graduation.poolEvidence,
          ),
          const LoopLabel('流动性状态'),
          LaunchUnavailableCard(label: '外盘行情', fact: detail.market),
          LoopNotice(
            key: const ValueKey<String>('launch-graduation-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '毕业不是排期状态',
            body:
                '「已结束」只表示排期结束，不等于已毕业。'
                '是否毕业要看流动性和交易池，两项目前都读不到。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _StepIndexTile extends StatelessWidget {
  const _StepIndexTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        index.toString().padLeft(2, '0'),
        style: LoopTypography.figure(13, color: LoopColors.chalk),
      ),
    );
  }
}

/// `launch-tier` · the eligibility result for one launch.
class LaunchTierScreen extends _LaunchRecordScreen {
  const LaunchTierScreen({
    super.key,
    super.launchId,
    super.onBack,
    this.onOpenStake,
  });

  final VoidCallback? onOpenStake;

  @override
  ConsumerState<LaunchTierScreen> createState() => _LaunchTierScreenState();
}

class _LaunchTierScreenState extends ConsumerState<LaunchTierScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchEligibilityControllerProvider);
    final controller = ref.read(launchEligibilityControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final eligibility = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-tier-screen'),
      archetype: LoopPageArchetype.record,
      title: '我的资格',
      kicker: 'ELIGIBILITY',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'ELIGIBILITY',
        // The tier is `null` by contract: the heading is the em dash, never a
        // guessed "Public".
        heading: eligibility?.tier ?? launchMissingFigure,
        caption: '这是当前资格结果，不是等级；资格不依赖 LOOP 质押。',
        stamp: eligibility == null
            ? null
            : launchEligibilityModeLabel(eligibility.mode),
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-tier-capability-unavailable'),
            icon: 'warn',
            message: '资格查询当前不可用',
            reason: '请稍后再试。',
          )
        else if (eligibility == null)
          LaunchStateBlock(
            prefix: 'launch-tier',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到资格结果',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('资格模式'),
          LoopRecordGroup(
            key: const ValueKey<String>('launch-tier-mode'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: ValueKey<String>(
                  'launch-tier-mode-${eligibility.mode.wireName}',
                ),
                title: launchEligibilityModeLabel(eligibility.mode),
                subtitle: launchEligibilityModeDescription(eligibility.mode),
                trailingBadge: LoopBadge(
                  eligibility.mode == LaunchEligibilityMode.unavailable
                      ? '未配置'
                      : '已配置',
                  kind: eligibility.mode == LaunchEligibilityMode.unavailable
                      ? LoopBadgeKind.mute
                      : LoopBadgeKind.launch,
                ),
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-config-version'),
                title: '配置版本',
                subtitle: eligibility.effectiveAt == null
                    ? '尚未生效'
                    : '生效于 ${launchTimestampLabel(eligibility.effectiveAt!)}',
                trailing: eligibility.configVersion ?? launchMissingFigure,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-depends-on-staking'),
                title: '是否依赖质押',
                subtitle: '资格规则由这次发射决定，与 LOOP 质押数量无关',
                trailing: eligibility.dependsOnStaking ? '是' : '否',
                position: LoopRowPosition.last,
              ),
            ],
          ),
          const LoopLabel('资格结果'),
          LoopEmpty(
            key: const ValueKey<String>('launch-tier-result'),
            icon: 'ticket',
            message: '当前没有资格结论',
            reason: launchReasonCodeText(eligibility.reasonCode),
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-tier-open-stake'),
                label: '查看 LOOP 质押',
                onPressed: widget.onOpenStake,
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('launch-tier-notice'),
            icon: 'info',
            title: '资格不是等级，也不是权益',
            body: '资格是这次发射的准入结果，会随配置和快照变化。这里不显示任何门槛、费率或时间窗口。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-holders` · internal-market holder distribution.
class LaunchHoldersScreen extends _LaunchRecordScreen {
  const LaunchHoldersScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchHoldersScreen> createState() =>
      _LaunchHoldersScreenState();
}

class _LaunchHoldersScreenState extends ConsumerState<LaunchHoldersScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchHoldersControllerProvider);
    final controller = ref.read(launchHoldersControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final holders = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-holders-screen'),
      archetype: LoopPageArchetype.record,
      title: '内盘持有人',
      kicker: 'HOLDER DISTRIBUTION',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'HOLDER DISTRIBUTION',
        heading: launchMissingFigure,
        caption: '持有人数量、集中度、我的仓位与单地址上限都需要合约读数，当前全部不可得。',
        stamp: 'UNAVAILABLE',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>(
              'launch-holders-capability-unavailable',
            ),
            icon: 'warn',
            message: '持有人分布当前不可用',
            reason: '请稍后再试。',
          )
        else if (holders == null)
          LaunchStateBlock(
            prefix: 'launch-holders',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到持有人记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('分布'),
          LaunchUnavailableCard(label: '持有人分布', fact: holders.holders),
          const LoopLabel('我的仓位'),
          LaunchUnavailableCard(label: '我的持仓', fact: holders.myPosition),
          const LoopLabel('单地址上限'),
          LaunchUnavailableCard(label: '单地址持仓上限', fact: holders.walletCap),
          const LoopNotice(
            key: ValueKey<String>('launch-holders-notice'),
            icon: 'shield',
            title: '空白不是「没有持有人」',
            body: '暂时读不到合约信息，因此不显示地址、比例或上限。读不到不等于「分布为零」。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-history` · my participation records for one launch.
class LaunchHistoryScreen extends _LaunchRecordScreen {
  const LaunchHistoryScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchHistoryScreen> createState() =>
      _LaunchHistoryScreenState();
}

class _LaunchHistoryScreenState extends ConsumerState<LaunchHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchHistoryControllerProvider);
    final controller = ref.read(launchHistoryControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final history = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-history-screen'),
      archetype: LoopPageArchetype.record,
      title: '我的参与记录',
      kicker: 'PARTICIPATION LOG',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'PARTICIPATION LOG',
        heading: launchMissingFigure,
        caption: '购买、权益与退款记录都要看链上数据，目前读不到，因此不显示笔数或盈亏。',
        stamp: 'UNAVAILABLE',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>(
              'launch-history-capability-unavailable',
            ),
            icon: 'warn',
            message: '参与记录当前不可用',
            reason: '请稍后再试。',
          )
        else if (history == null)
          LaunchStateBlock(
            prefix: 'launch-history',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到参与记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('记录出处'),
          LaunchUnavailableCard(label: '购买、权益与退款记录', fact: history.source),
          const LoopNotice(
            key: ValueKey<String>('launch-history-notice'),
            icon: 'shield',
            title: '空列表不代表没有参与',
            body: '这里是「暂时读不到」，不是「没有记录」。合约上线后才会出现可核对的购买、权益与退款。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
