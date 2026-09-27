import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `loop-stake` · the LOOP staking position.
///
/// The whole page is non-executable: there is no staking contract, so there is
/// no amount field, no tab pair and no signing entry point. Eligibility does
/// not depend on staking, and the page says so.
class LoopStakeScreen extends ConsumerStatefulWidget {
  const LoopStakeScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<LoopStakeScreen> createState() => _LoopStakeScreenState();
}

class _LoopStakeScreenState extends ConsumerState<LoopStakeScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchStakeControllerProvider);
    final controller = ref.read(launchStakeControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final stake = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('loop-stake-screen'),
      archetype: LoopPageArchetype.record,
      title: 'LOOP 质押',
      onBack: widget.onBack,
      // 暂无数值 described a page with no figures as if figures were owed,
      // and the English state name beside it was the wire value of the
      // executability flag. Neither is what a reader needs: staking has not
      // opened, and the sentence under the heading says what that costs.
      primary: const LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'STAKING POSITION',
          heading: '质押还没有开放',
          caption: '质押数量、可用余额与解除等待期都需要质押合约；本页不构造任何交易，也不打开签名。',
          stamp: '未开放',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.loop-stake-balance`: the two readings the prototype welds under
        // this folio. Both need the staking contract, so both are em dashes.
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: '钱包可用余额',
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: '已质押',
            trailingValue: loopFigureDash,
            spoken: '质押还没有开放',
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('loop-stake-capability-unavailable'),
              title: 'LOOP 质押当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (stake == null)
          LaunchStateBlock(
            prefix: 'loop-stake',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到质押状态',
            emptyReason: '质押还没有开放。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // `.loop-stake-tabs`: the prototype's two-way choice, kept as the
          // shape of the page and disabled, so the page reads as a form that
          // has not opened rather than as a page that never had one
          // (visual audit 2026-09-21 §H.10).
          LoopChipRow(
            key: const ValueKey<String>('loop-stake-tabs'),
            children: const <Widget>[
              LoopSeg(label: '质押', selected: true, onSelected: null),
              LoopSeg(label: '解除质押', selected: false, onSelected: null),
            ],
          ),
          _StakeAmountCard(executable: stake.executable),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('loop-stake-submit'),
              label: '确认质押',
              primary: true,
              block: true,
              // 03 §10.1: staking has no approved contract scheme, so the
              // action is marked non-executable and no signing entry point
              // exists on this page at all.
              onPressed: null,
              semanticLabel: '确认质押，当前不可执行',
            ),
          ),
          LaunchUnavailableCard(
            label: '我的质押',
            fact: stake.stake,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(capability: capability),
          ),
          const LoopNotice(
            key: ValueKey<String>('loop-stake-notice'),
            icon: 'lock',
            title: '质押与 Launch 资格',
            body:
                '质押用于 Launch 参与资格；某一次发射是否依赖质押，由它自己被批准的资格模式决定。'
                '质押与挖矿算力的关系以批准的公式版本为准，这里不承诺任何倍率、等待期或权益。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `.chalk-card.loop-stake-form`: the amount box, in the shape the prototype
/// gives it and with no way to type into it.
///
/// It is deliberately not a [TextField]. 03 §10.1 withholds the staking
/// contract until its own scheme is approved, so there is nothing to validate
/// an amount against and nothing to sign it with; a field that accepted a
/// number would be promising a transaction this build cannot build.
class _StakeAmountCard extends StatelessWidget {
  const _StakeAmountCard({required this.executable});

  final bool executable;

  @override
  Widget build(BuildContext context) {
    return LoopChalkCard(
      key: const ValueKey<String>('loop-stake-executable'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Builder(
        builder: (context) {
          final ink = LoopGround.inkOf(context);
          final auxiliary = LoopGround.auxiliaryOf(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '质押数量',
                      style: LoopTypography.eyebrow(11, color: auxiliary),
                    ),
                  ),
                  LoopBadge(
                    executable ? '可执行' : '不可执行',
                    kind: LoopBadgeKind.mute,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      launchMissingFigure,
                      style: LoopTypography.figure(
                        24,
                        weight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  Text('LOOP', style: LoopTypography.figure(13, color: ink)),
                ],
              ),
              const LoopHairline(),
              Text(
                '质押合约还没有上线，这一页不接受金额输入，也不会打开签名。',
                style: LoopTypography.caption(11, color: auxiliary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `loop-economy` · the public ledger.
///
/// Only counts the LOOP database can prove are numbers. Supply, distribution
/// and ecosystem tax stay unavailable with the server's own reason.
class LoopEconomyScreen extends ConsumerStatefulWidget {
  const LoopEconomyScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<LoopEconomyScreen> createState() => _LoopEconomyScreenState();
}

class _LoopEconomyScreenState extends ConsumerState<LoopEconomyScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchEconomyControllerProvider);
    final controller = ref.read(launchEconomyControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final economy = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('loop-economy-screen'),
      archetype: LoopPageArchetype.record,
      title: 'LOOP 生态账本',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'PUBLIC ECONOMY',
        // The only provable headline is a count of approved rounds.
        heading: economy == null
            ? launchMissingHeading
            : '${economy.confirmedRoundCount} 个已确认轮次',
        caption: '这里只显示 LOOP 能核对的数量；总量、发行与生态税暂时读不到。',
        stamp: economy == null ? null : 'LOOP DB',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'loop-economy-capability-unavailable',
              ),
              title: '生态账本当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (economy == null)
          LaunchStateBlock(
            prefix: 'loop-economy',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到账本计数',
            emptyReason: '暂时读不到可核对的数量。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('Launch'),
          // `.chalk-card` with a 2x2 grid: the prototype's Launch half of the
          // ledger. The registry count is LOOP's own and is a number; the
          // other three need the contract and print the em dash.
          _EconomyLaunchCard(
            economy: economy,
            contractLive: capability.evidenceConfirmed,
          ),
          // loop-api S83b.10: drawn only when the server sent `onChain`. An
          // absent key means no Launch contract is configured, and the page
          // stays exactly as it was before the contract.
          if (economy.onChain case final onChain?) ...<Widget>[
            const LoopLabel('链上账本'),
            _EconomyOnChainCard(onChain: onChain),
          ],
          const LoopLabel('LOOP'),
          LoopStatGrid(
            key: const ValueKey<String>('loop-economy-loop-stats'),
            stats: <LoopStat>[
              const LoopStat(label: '总量', value: loopFigureDash),
              const LoopStat(label: '累计分发', value: loopFigureDash),
              LoopStat(label: '已确认轮次', value: '${economy.confirmedRoundCount}'),
              LoopStat(label: '已通过申请', value: '${economy.projects.approved}'),
            ],
          ),
          _EconomyReasons(
            economy: economy,
            contractLive: capability.evidenceConfirmed,
          ),
          const LoopLabel('Value Flywheel'),
          LoopRecordGroup(
            key: const ValueKey<String>('loop-economy-flywheel'),
            rows: <LoopRecordRow>[
              for (var index = 0; index < _flywheel.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>('loop-economy-flywheel-$index'),
                  leading: LoopMonoTile(
                    label: (index + 1).toString().padLeft(2, '0'),
                  ),
                  title: _flywheel[index].$1,
                  subtitle: _flywheel[index].$2,
                  subtitleMaxLines: 2,
                  position: launchRowPosition(index, _flywheel.length),
                ),
            ],
          ),
          const LoopLabel('申请状态计数'),
          LoopRecordGroup(
            key: const ValueKey<String>('loop-economy-projects'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < economy.projects.entries.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    'loop-economy-project-${economy.projects.entries[index].$1}',
                  ),
                  title: economy.projects.entries[index].$1,
                  trailing: '${economy.projects.entries[index].$2}',
                  position: launchRowPosition(
                    index,
                    economy.projects.entries.length,
                  ),
                ),
            ],
          ),
          const LoopLabel('排期状态计数'),
          LoopRecordGroup(
            key: const ValueKey<String>('loop-economy-launches'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < economy.launches.entries.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    'loop-economy-launch-${economy.launches.entries[index].$1}',
                  ),
                  title: economy.launches.entries[index].$1,
                  trailing: '${economy.launches.entries[index].$2}',
                  position: launchRowPosition(
                    index,
                    economy.launches.entries.length,
                  ),
                ),
            ],
          ),
          // The economy response carries no configuration version, so the
          // footer omits the segment rather than restating an assumed one.
          LaunchSourceFooter(
            source: economy.source,
            kind: LaunchSourceKind.ledger,
            observedAt: economy.observedAt,
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The prototype's `Value Flywheel`: what LOOP's economy does with a launch
/// once it graduates. No rate appears — the retired permanent-tax figure is
/// forbidden copy (03 §10.1) and the live one is not approved.
const List<(String, String)> _flywheel = <(String, String)>[
  ('精品项目完成 Launch', '社区传播与内盘交易形成流动性'),
  ('达线毕业并进入外盘', '迁移后由外部流动性承接交易'),
  ('价值回流 LOOP', '增强流动性、挖矿吸引力与下一轮分发'),
];

/// `loop-economy` 的 `.chalk-card`: the Launch half of the public ledger.
class _EconomyLaunchCard extends StatelessWidget {
  const _EconomyLaunchCard({required this.economy, required this.contractLive});

  final LaunchEconomy economy;
  final bool contractLive;

  /// Every launch LOOP has registered, whatever its schedule says. It is a
  /// count of LOOP's own records, which is the only kind of number this page
  /// is allowed to print.
  int get _registered {
    final counts = economy.launches;
    return counts.unscheduled + counts.scheduled + counts.live + counts.ended;
  }

  @override
  Widget build(BuildContext context) {
    return LoopChalkCard(
      key: const ValueKey<String>('loop-economy-launch-card'),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _cell(context, '$_registered', '已登记发射')),
                Expanded(child: _cell(context, loopFigureDash, '已毕业')),
              ],
            ),
            const LoopHairline(),
            Row(
              children: <Widget>[
                Expanded(child: _cell(context, loopFigureDash, '累计成交量')),
                Expanded(child: _cell(context, loopFigureDash, '累计生态税')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String value, String label) => Semantics(
    container: true,
    label:
        '$label，'
        '${value == loopFigureDash ? launchEconomyReasonText(economy.ecosystemTax.reasonCode, contractLive: contractLive) : value}',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: LoopTypography.figure(
              16,
              weight: FontWeight.w700,
              color: LoopGround.inkOf(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: LoopTypography.caption(
              11,
              color: LoopGround.auxiliaryOf(context),
            ),
          ),
        ],
      ),
    ),
  );
}

/// zh-CN for an `economy.onChain` unavailable reason. The index codes get a
/// ledger sentence of their own: the global one talks about a list row.
String launchEconomyOnChainReasonText(String reasonCode) =>
    switch (reasonCode) {
      'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' => 'LOOP 的链上事件索引还没有开始，链上账本稍后可见。',
      'LAUNCH_ONCHAIN_STATE_NOT_PROJECTED' => 'LOOP 的链上事件索引还在追赶，链上账本稍后可见。',
      _ => launchReasonCodeText(reasonCode),
    };

/// `economy.onChain`: counts read from LOOP's Launch event index.
///
/// Available: 累计募集 (successful sales only) across the top, 已登记发售 and
/// 已锁 LP below, and the index block as a footnote. Unavailable: one strip
/// with the server's reason; never a zero.
class _EconomyOnChainCard extends StatelessWidget {
  const _EconomyOnChainCard({required this.onChain});

  final LaunchEconomyOnChain onChain;

  @override
  Widget build(BuildContext context) {
    return switch (onChain) {
      LaunchEconomyOnChainUnavailable(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('loop-economy-onchain-unavailable'),
        icon: 'info',
        message: '链上账本暂时读不到',
        reason: launchEconomyOnChainReasonText(reasonCode),
      ),
      final LaunchEconomyOnChainAvailable value => LoopChalkCard(
        key: const ValueKey<String>('loop-economy-onchain'),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _cell(
                context,
                const ValueKey<String>('loop-economy-onchain-raised'),
                launchUsd1Label(value.totalRaisedUsd1),
                '累计募集（仅成功的发售）',
                large: true,
              ),
              const LoopHairline(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _cell(
                      context,
                      const ValueKey<String>('loop-economy-onchain-sales'),
                      '${value.registeredSaleCount}',
                      '已登记发售',
                    ),
                  ),
                  Expanded(
                    child: _cell(
                      context,
                      const ValueKey<String>('loop-economy-onchain-lp'),
                      '${value.lockedLpCount}',
                      '已锁 LP',
                    ),
                  ),
                ],
              ),
              const LoopHairline(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '读自区块 ${loopGroupedFigure(value.indexedBlockNumber)}'
                  ' · LOOP 链上事件索引',
                  key: const ValueKey<String>('loop-economy-onchain-block'),
                  style: LoopTypography.figure(
                    11,
                    weight: FontWeight.w400,
                    height: 1.35,
                    color: LoopGround.auxiliaryOf(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    };
  }

  Widget _cell(
    BuildContext context,
    Key key,
    String value,
    String label, {
    bool large = false,
  }) => Semantics(
    key: key,
    container: true,
    label: '$label，$value',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: LoopTypography.figure(
                  large ? 20 : 16,
                  weight: FontWeight.w700,
                  color: LoopGround.inkOf(context),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: LoopTypography.caption(
                11,
                color: LoopGround.auxiliaryOf(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The reasons behind the ledger's em dashes, each stated once.
///
/// Three unavailable strips used to carry the same sentence three times; the
/// figures now sit in the grids and the sentences are de-duplicated here.
class _EconomyReasons extends StatelessWidget {
  const _EconomyReasons({required this.economy, required this.contractLive});

  final LaunchEconomy economy;
  final bool contractLive;

  @override
  Widget build(BuildContext context) {
    final codes = <String>{
      economy.totalSupply.reasonCode,
      economy.distributed.reasonCode,
      economy.ecosystemTax.reasonCode,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final code in codes)
          LoopEmpty(
            key: ValueKey<String>('loop-economy-reason-$code'),
            icon: 'info',
            message: '总量、累计分发与累计生态税暂时没有数值',
            reason: launchEconomyReasonText(code, contractLive: contractLive),
          ),
      ],
    );
  }
}

/// `launch-apply` · the real application draft form.
///
/// It creates a draft, edits it under a compare-and-set version, submits it,
/// and shows the server's own review state. Attachments and KYB have no
/// provider and are rendered as "待接入" without an upload control.
class LaunchApplyScreen extends ConsumerStatefulWidget {
  const LaunchApplyScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<LaunchApplyScreen> createState() => _LaunchApplyScreenState();
}

class _LaunchApplyScreenState extends ConsumerState<LaunchApplyScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _ticker = TextEditingController();
  final TextEditingController _narrative = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _x = TextEditingController();
  final TextEditingController _telegram = TextEditingController();
  final TextEditingController _discord = TextEditingController();
  String? _loadedProjectId;

  @override
  void dispose() {
    _name.dispose();
    _ticker.dispose();
    _narrative.dispose();
    _website.dispose();
    _x.dispose();
    _telegram.dispose();
    _discord.dispose();
    super.dispose();
  }

  void _fill(LaunchProject? project) {
    if (_loadedProjectId == project?.projectId) return;
    _loadedProjectId = project?.projectId;
    _name.text = project?.name ?? '';
    _ticker.text = project?.ticker ?? '';
    _narrative.text = project?.narrative ?? '';
    _website.text = project?.officialLinks.website ?? '';
    _x.text = project?.officialLinks.x ?? '';
    _telegram.text = project?.officialLinks.telegram ?? '';
    _discord.text = project?.officialLinks.discord ?? '';
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  LaunchProjectDraft _draft() => LaunchProjectDraft(
    name: _name.text.trim(),
    // The server requires upper case; normalising here avoids a round trip
    // rather than widening what it accepts.
    ticker: _ticker.text.trim().toUpperCase(),
    narrative: _optional(_narrative),
    // All four links round-trip: a link the server holds must survive an
    // edit that did not touch it.
    officialLinks: LaunchOfficialLinks(
      website: _optional(_website),
      x: _optional(_x),
      telegram: _optional(_telegram),
      discord: _optional(_discord),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchApplyControllerProvider);
    final controller = ref.read(launchApplyControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final selected = state.selected;
    _fill(selected);
    final editable = selected == null || selected.canEdit;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-apply-screen'),
      archetype: LoopPageArchetype.action,
      title: '申请发射',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: 'CURATED LAUNCH',
        // The heading is a conclusion, not the page's own title: the length
        // of the review pipeline before a draft exists, the applicant's own
        // state once one does.
        heading: selected == null
            ? '${_reviewPipeline.length} 步审核'
            : launchReviewStatusLabel(selected.reviewStatus),
        caption: '提交不代表通过。审核由人工进行，结果与上线时间以最新状态为准。',
        stamp: selected == null
            ? '${_reviewPipeline.length} STEPS'
            : 'v${selected.materialVersion}',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-apply-capability-unavailable',
              ),
              title: '申请入口当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (state.phase != LaunchViewPhase.ready)
          LaunchStateBlock(
            prefix: 'launch-apply',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '还没有任何申请',
            emptyReason: '填写下面的表单即可创建第一份草稿。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // `Review Record`: the four states the server's own machine moves a
          // draft through, with the applicant's current one marked. The
          // prototype opens on this block; the App opened straight onto the
          // form, so the page never said what submitting leads to
          // (visual audit 2026-09-21 §H.12).
          const LoopLabel('Review Record'),
          LoopRecordGroup(
            key: const ValueKey<String>('launch-apply-pipeline'),
            rows: <LoopRecordRow>[
              for (var index = 0; index < _reviewPipeline.length; index += 1)
                _pipelineRow(
                  index: index,
                  current: selected == null
                      ? null
                      : _reviewPipelineIndex(selected.reviewStatus),
                ),
            ],
          ),
          if (state.projects.isNotEmpty) ...<Widget>[
            const LoopLabel('我的申请'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-apply-projects'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.projects.length; index += 1)
                  _projectRow(
                    project: state.projects[index],
                    selected:
                        state.projects[index].projectId ==
                        state.selectedProjectId,
                    onTap: () =>
                        controller.select(state.projects[index].projectId),
                    position: launchRowPosition(index, state.projects.length),
                  ),
              ],
            ),
            if (selected != null)
              LoopButtonPair(
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('launch-apply-new'),
                    label: '新建另一份申请',
                    onPressed: state.busy
                        ? null
                        : () => controller.select(null),
                  ),
                ],
              ),
          ],
          if (selected != null) ...<Widget>[
            _ReviewStatusBlock(project: selected),
            _MilestoneBlock(projectId: selected.projectId),
          ],
          const LoopLabel('项目资料'),
          _ApplyForm(
            name: _name,
            ticker: _ticker,
            narrative: _narrative,
            website: _website,
            x: _x,
            telegram: _telegram,
            discord: _discord,
            enabled: editable && !state.busy,
            invalidField: state.invalidField,
          ),
          const LoopLabel('附件与主体审核'),
          _DeferredProviderBlock(project: selected),
          if (state.writeFailureKind != null) ...<Widget>[
            LoopNotice(
              key: const ValueKey<String>('launch-apply-write-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: '这次提交没有完成',
              body: launchFailureReason(state.writeFailureKind),
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('launch-apply-reload'),
                  label: '重新加载',
                  // A version conflict is resolved by re-reading the server's
                  // projection; the edits already typed stay in the fields.
                  onPressed: state.busy
                      ? null
                      : () => unawaited(controller.reload()),
                ),
              ],
            ),
          ],
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-apply-save'),
                label: selected == null ? '保存草稿' : '保存修改',
                primary: true,
                onPressed: !editable || state.busy
                    ? null
                    : () => unawaited(controller.save(_draft())),
              ),
              LoopButton(
                key: const ValueKey<String>('launch-apply-submit'),
                label: selected?.reviewStatus == LaunchReviewStatus.returned
                    ? '重新提交'
                    : '提交审核',
                onPressed: selected == null || !selected.canSubmit || state.busy
                    ? null
                    : () => unawaited(controller.submit()),
              ),
            ],
          ),
          // `details.focus-disclosure`: the curation statement and the
          // submission caveat, where the prototype keeps them.
          const LoopDisclosure(
            key: ValueKey<String>('launch-apply-principles'),
            summary: '筛选原则与提交说明',
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: _CurationCard(),
            ),
          ),
          const LoopNotice(
            key: ValueKey<String>('launch-apply-notice'),
            icon: 'info',
            title: '提交不代表通过',
            body: '审核由人工进行。通过后项目才会进入目录，再等待排期确认。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// One row of the `Review Record` block.
  ///
  /// The subtitle is the state's own next step, not a description of the
  /// page: 「能读到值就写值」 (visual audit §D+ #11).
  LoopRecordRow _pipelineRow({required int index, required int? current}) {
    final (label, status) = _reviewPipeline[index];
    final isCurrent = current == index;
    return LoopRecordRow(
      key: ValueKey<String>('launch-apply-pipeline-$index'),
      leading: LoopMonoTile(
        label: (index + 1).toString().padLeft(2, '0'),
        accent: isCurrent,
      ),
      title: label,
      subtitle: launchReviewStatusHint(status),
      subtitleMaxLines: 2,
      trailingBadge: isCurrent
          ? const LoopBadge('当前', kind: LoopBadgeKind.launch)
          : null,
      position: launchRowPosition(index, _reviewPipeline.length),
      semanticLabel:
          '$label，${launchReviewStatusHint(status)}'
          '${isCurrent ? '，当前状态' : ''}',
    );
  }

  LoopRecordRow _projectRow({
    required LaunchProject project,
    required bool selected,
    required VoidCallback onTap,
    required LoopRowPosition position,
  }) {
    return LoopRecordRow(
      key: ValueKey<String>('launch-apply-project-${project.projectId}'),
      leading: LaunchTickerTile(ticker: project.ticker),
      title: project.name,
      subtitle:
          '${project.ticker} · 资料版本 ${project.materialVersion} · '
          '更新于 ${launchTimestampLabel(project.updatedAt)}',
      trailingBadge: LoopBadge(
        launchReviewStatusLabel(project.reviewStatus),
        kind: selected ? LoopBadgeKind.launch : LoopBadgeKind.mute,
      ),
      onTap: onTap,
      position: position,
      semanticLabel:
          '${project.name}，${launchReviewStatusLabel(project.reviewStatus)}'
          '${selected ? '，已选中' : ''}',
    );
  }
}

/// The review pipeline, in the order the server's own state machine moves a
/// draft through it. The terminal states share the last step, because an
/// applicant reaches exactly one of them.
const List<(String, LaunchReviewStatus)> _reviewPipeline =
    <(String, LaunchReviewStatus)>[
      ('草稿', LaunchReviewStatus.draft),
      ('已提交', LaunchReviewStatus.submitted),
      ('审核中', LaunchReviewStatus.inReview),
      ('审核结果', LaunchReviewStatus.approved),
    ];

/// Which pipeline step one review status stands at.
int _reviewPipelineIndex(LaunchReviewStatus status) => switch (status) {
  LaunchReviewStatus.draft => 0,
  LaunchReviewStatus.submitted => 1,
  LaunchReviewStatus.inReview => 2,
  LaunchReviewStatus.returned ||
  LaunchReviewStatus.approved ||
  LaunchReviewStatus.rejected => 3,
};

/// `details > .record-card`: what LOOP curates for, in the prototype's words.
class _CurationCard extends StatelessWidget {
  const _CurationCard();

  @override
  Widget build(BuildContext context) {
    return LoopRecordCard(
      key: const ValueKey<String>('launch-apply-curation'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'CURATED LAUNCH',
            style: LoopTypography.eyebrow(11, color: LoopColors.text3),
          ),
          const SizedBox(height: 8),
          Text('先评估，再发射', style: LoopTypography.title(24)),
          const SizedBox(height: 5),
          Text(
            'LOOP 与交易所、KOL 和社区共同筛选有叙事、有传播力、可长期运营的项目。',
            style: LoopTypography.caption(11, color: LoopColors.text2),
          ),
          const LoopHairline(),
          Text(
            '人工审核 · 上限配置 · 流动性方案',
            style: LoopTypography.caption(11, color: LoopColors.text3),
          ),
        ],
      ),
    );
  }
}

/// The five exchange-listing tracks for one project.
///
/// 03 §8.4 fixes the tracks, so all five are always listed. A track with no
/// stored record arrives as an implicit `PREPARING` row and says "尚无记录"
/// rather than implying that preparation has begun.
class _MilestoneBlock extends ConsumerStatefulWidget {
  const _MilestoneBlock({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_MilestoneBlock> createState() => _MilestoneBlockState();
}

class _MilestoneBlockState extends ConsumerState<_MilestoneBlock> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(launchMilestonesControllerProvider);
    final controller = ref.read(launchMilestonesControllerProvider.notifier);
    scheduleMicrotask(() {
      if (mounted) unawaited(controller.open(widget.projectId));
    });
    final milestones = state.value;
    final items = milestones?.items ?? const <LaunchMilestone>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('交易所上线进度'),
        if (milestones == null)
          LaunchStateBlock(
            prefix: 'launch-milestones',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到上线进度',
            emptyReason: '进度由运营记录，本页不推断任何上线结论。',
            onRetry: () => unawaited(controller.reload()),
          )
        else
          LoopRecordGroup(
            key: const ValueKey<String>('launch-apply-milestones'),
            rows: <LoopRecordRow>[
              for (var index = 0; index < items.length; index += 1)
                launchMilestoneRow(
                  milestone: items[index],
                  position: launchRowPosition(index, items.length),
                ),
            ],
          ),
        const LoopNotice(
          key: ValueKey<String>('launch-apply-milestone-notice'),
          icon: 'shield',
          title: 'Alpha 不等于现货',
          body:
              '每条赛道单独记录，互不推导。只有「已上线」与「已获推荐位」附有复核过的材料；'
              '复核记录时间与平台可核验时间是两个不同的事实，缺一不补。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
      ],
    );
  }
}

class _ReviewStatusBlock extends StatelessWidget {
  const _ReviewStatusBlock({required this.project});

  final LaunchProject project;

  @override
  Widget build(BuildContext context) {
    // The server's own sentence for the applicant (decision 0041). It is
    // rendered verbatim: the client neither translates `reviewReasonCode`
    // itself nor reads the code back out of this text.
    final reason = project.reviewReasonText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('审核状态'),
        LoopRecordGroup(
          key: const ValueKey<String>('launch-apply-review-status'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: ValueKey<String>(
                'launch-apply-status-${project.reviewStatus.wireName}',
              ),
              title: launchReviewStatusLabel(project.reviewStatus),
              subtitle: launchReviewStatusHint(project.reviewStatus),
              position: LoopRowPosition.first,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('launch-apply-submitted-at'),
              title: '提交时间',
              // A non-owner projection nulls the review trail; the em dash is
              // "not visible to you", not "never submitted".
              subtitle: project.isOwnerProjection
                  ? '只有申请人可以看到审核轨迹'
                  : '审核轨迹与版本只属于申请人',
              trailing: project.submittedAt == null
                  ? launchMissingFigure
                  : launchTimestampLabel(project.submittedAt!),
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('launch-apply-reviewed-at'),
              title: '审核时间',
              trailing: project.reviewedAt == null
                  ? launchMissingFigure
                  : launchTimestampLabel(project.reviewedAt!),
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('launch-apply-launch-id'),
              title: '目录条目',
              subtitle: project.launchId == null
                  ? '通过审核后才会生成目录条目'
                  : '已进入目录，等待排期',
              trailing: project.launchId == null ? launchMissingFigure : '已生成',
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (reason != null)
          LoopNotice(
            key: const ValueKey<String>('launch-apply-returned-reason'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '退回原因',
            body: reason,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
      ],
    );
  }
}

class _ApplyForm extends StatelessWidget {
  const _ApplyForm({
    required this.name,
    required this.ticker,
    required this.narrative,
    required this.website,
    required this.x,
    required this.telegram,
    required this.discord,
    required this.enabled,
    required this.invalidField,
  });

  final TextEditingController name;
  final TextEditingController ticker;
  final TextEditingController narrative;
  final TextEditingController website;
  final TextEditingController x;
  final TextEditingController telegram;
  final TextEditingController discord;
  final bool enabled;
  final LaunchDraftField? invalidField;

  String? _errorFor(LaunchDraftField field) =>
      invalidField == field ? launchDraftFieldReason(field) : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('launch-apply-name'),
            controller: name,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: '项目名称（1–80）',
              errorText: _errorFor(LaunchDraftField.name),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-ticker'),
            controller: ticker,
            enabled: enabled,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Ticker（2–12 位大写字母或数字）',
              errorText: _errorFor(LaunchDraftField.ticker),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-narrative'),
            controller: narrative,
            enabled: enabled,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '叙事（可留空，≤2000）',
              errorText: _errorFor(LaunchDraftField.narrative),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-website'),
            controller: website,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: '官网（可留空，https://）',
              errorText: _errorFor(LaunchDraftField.officialLinks),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-x'),
            controller: x,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'X（可留空，https://）'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-telegram'),
            controller: telegram,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Telegram（可留空，https://）',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-discord'),
            controller: discord,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Discord（可留空，https://）',
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '当前状态下资料为只读。只有草稿与被退回的申请可以修改。',
                style: LoopTypography.caption(11, color: LoopColors.text2),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeferredProviderBlock extends StatelessWidget {
  const _DeferredProviderBlock({required this.project});

  final LaunchProject? project;

  @override
  Widget build(BuildContext context) {
    final current = project;
    if (current == null) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-apply-providers-pending'),
        icon: 'info',
        message: '附件上传与主体审核暂未开放',
        reason: '开放后可以在这里上传材料并查看审核状态。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LaunchUnavailableCard(label: '附件', fact: current.attachments),
        LoopEmpty(
          key: const ValueKey<String>('launch-apply-kyb'),
          icon: 'shield',
          message: '主体审核还没有开放',
          reason: launchReasonCodeText(current.kyb.reasonCode),
        ),
      ],
    );
  }
}
