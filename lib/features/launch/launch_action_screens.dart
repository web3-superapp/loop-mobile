import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch-trade` · the internal-market purchase form.
///
/// The form stays visible so the refusal is legible, but the main action is
/// disabled: the server answers `503 CAPABILITY_UNAVAILABLE` for every intent
/// while the Launch contract baseline is undelivered. There is no sell side —
/// an ungraduated launch is buy-only — and no signing sheet is ever opened.
class LaunchTradeScreen extends ConsumerStatefulWidget {
  const LaunchTradeScreen({
    super.key,
    this.launchId,
    this.onBack,
    this.onOpenHolders,
  });

  final String? launchId;
  final VoidCallback? onBack;
  final VoidCallback? onOpenHolders;

  @override
  ConsumerState<LaunchTradeScreen> createState() => _LaunchTradeScreenState();
}

class _LaunchTradeScreenState extends ConsumerState<LaunchTradeScreen> {
  final TextEditingController _amount = TextEditingController();
  String? _roundId;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amount
      ..removeListener(_onAmountChanged)
      ..dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  /// The exact string the server accepts. A malformed amount keeps the action
  /// disabled here rather than spending a request.
  String? get _payAmount {
    final raw = _amount.text.trim();
    if (raw.isEmpty ||
        !RegExp(r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$').hasMatch(raw)) {
      return null;
    }
    return raw;
  }

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
    final trade = ref.watch(launchTradeControllerProvider);
    final tradeController = ref.read(launchTradeControllerProvider.notifier);
    // The paying wallet is a real input the page must resolve. It is read
    // through the wallet port, never guessed from an address.
    final walletState = ref.watch(walletDirectoryControllerProvider);
    if (!blocked && walletState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(walletDirectoryControllerProvider.notifier).load(),
          );
        }
      });
    }
    final walletId = ref.watch(activeWalletIdProvider);
    final launchId = widget.launchId;
    final payAmount = _payAmount;
    final roundId = _roundId;
    // The action is closed by the server's own capability evidence, never by
    // a rule of our own. Everything else here is a real missing input.
    final refusedByEvidence = capability.evidencePending;
    final canSubmit =
        !refusedByEvidence &&
        !trade.busy &&
        launchId != null &&
        walletId != null &&
        roundId != null &&
        payAmount != null;

    return LoopFocusPage(
      key: const ValueKey<String>('launch-trade-screen'),
      archetype: LoopPageArchetype.action,
      title: detail?.launch.ticker ?? 'Launch 认购',
      kicker: '内盘 · 只买不卖',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-trade-holders-action'),
          icon: 'users',
          label: '查看持有人',
          onPressed: widget.onOpenHolders,
        ),
      ],
      folio: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: 'BUY QUOTE',
        // No quote: price, fee and cap are all contract facts.
        heading: launchMissingFigure,
        caption: '价格、手续费与剩余额度暂时读不到，现在无法报价。',
        stamp: 'DISABLED',
      ),
      body: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-trade-capability-unavailable'),
            icon: 'warn',
            message: '内盘认购当前不可用',
            reason: '请稍后再试。',
          )
        // A detail read that has not landed must not be shown as "no round to
        // join": loading, offline and a failed read each get their own block,
        // and none of them is evidence about the round configuration.
        else if (state.phase != LaunchViewPhase.ready)
          LaunchStateBlock(
            prefix: 'launch-trade',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '这个 Launch 没有可读的认购信息',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // The chain the owner would be paying on. It is the launch's own
          // published value, stated before the amount field, not after it.
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(
              capability: capability,
              launch: detail?.launch,
            ),
          ),
          const LoopLabel('支付金额'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const ValueKey<String>('launch-trade-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '支付数量',
                helperText: '可以填写，但暂时不能提交：报价与额度还读不到。',
              ),
            ),
          ),
          const LoopLabel('本轮参数'),
          _TradeParameters(
            detail: detail,
            selectedRoundId: roundId,
            onSelect: (value) => setState(() => _roundId = value),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('launch-trade-submit'),
              label: '买入',
              primary: true,
              block: true,
              onPressed: canSubmit
                  ? () => unawaited(
                      tradeController.submit(
                        launchId: launchId,
                        walletId: walletId,
                        roundId: roundId,
                        payAmount: payAmount,
                      ),
                    )
                  : null,
              semanticLabel: canSubmit ? '买入' : '买入，当前不可执行',
            ),
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-trade-refusal'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: trade.attempted ? '这次认购没有通过' : '认购入口当前不可执行',
            // Before an attempt the page states the capability evidence the
            // server published; after one it states what the server answered.
            body: trade.refusalKind != null
                ? launchFailureReason(trade.refusalKind)
                : refusedByEvidence
                ? '${launchReasonCodeText(capability.evidenceReasonCode)}'
                      '本页因此不构造任何交易，也不打开签名。'
                : _missingInputReason(
                    walletId: walletId,
                    roundId: roundId,
                    payAmount: payAmount,
                  ),
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopNotice(
            key: ValueKey<String>('launch-trade-buy-only'),
            icon: 'info',
            title: '未毕业只买不卖',
            body: '内盘阶段没有卖出接口。毕业并建立外部流动性之后，交易才会转到行情模块。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// Why the action is closed when the capability itself is open. Each reason
/// is a real missing input, not a restatement of the contract gap.
String _missingInputReason({
  required String? walletId,
  required String? roundId,
  required String? payAmount,
}) {
  if (walletId == null) return '还没有可用的支付钱包，请先在钱包中选择一个。';
  if (roundId == null) return '请先选择要参与的轮次。';
  if (payAmount == null) return '请输入一个有效的支付数量。';
  return '可以提交，结果以提交后的状态为准。';
}

class _TradeParameters extends StatelessWidget {
  const _TradeParameters({
    required this.detail,
    required this.selectedRoundId,
    required this.onSelect,
  });

  final LaunchDetail? detail;
  final String? selectedRoundId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final rounds = detail?.rounds ?? const <LaunchRound>[];
    if (rounds.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-trade-no-round'),
        icon: 'warn',
        message: '没有可参与的轮次',
        reason: '轮次配置尚未确认，因此没有价格、资格或额度可以展示。',
      );
    }
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-trade-rounds'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < rounds.length; index += 1)
          launchRoundRow(
            round: rounds[index],
            position: launchRowPosition(index, rounds.length),
            onTap: () => onSelect(rounds[index].roundId),
            selected: rounds[index].roundId == selectedRoundId,
          ),
      ],
    );
  }
}

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
      kicker: 'STAKING POSITION',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'STAKING POSITION',
        heading: launchMissingFigure,
        caption: '质押数量、可用余额与解除等待期都需要质押合约；本页整页不可执行。',
        stamp: 'NOT EXECUTABLE',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('loop-stake-capability-unavailable'),
            icon: 'warn',
            message: 'LOOP 质押当前不可用',
            reason: '请稍后再试。',
          )
        else if (stake == null)
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
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(capability: capability),
          ),
          const LoopLabel('质押状态'),
          LaunchUnavailableCard(label: '我的质押', fact: stake.stake),
          const LoopLabel('可执行性'),
          LoopRecordGroup(
            key: const ValueKey<String>('loop-stake-executable'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('loop-stake-executable-row'),
                title: '质押与解除质押',
                subtitle: '合约缺席时，本页不提供任何金额输入或签名入口',
                trailingBadge: LoopBadge(
                  stake.executable ? '可执行' : '不可执行',
                  kind: LoopBadgeKind.mute,
                ),
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('loop-stake-notice'),
            icon: 'lock',
            title: '资格不依赖质押',
            body: 'Launch 资格由每次发射自己的规则决定，与是否质押 LOOP 无关。这里不承诺任何倍率、等待期或权益。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
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
      kicker: 'PUBLIC ECONOMY',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'PUBLIC ECONOMY',
        // The only provable headline is a count of approved rounds.
        heading: economy == null
            ? launchMissingFigure
            : '${economy.confirmedRoundCount} 个已确认轮次',
        caption: '这里只显示 LOOP 能核对的数量；总量、发行与生态税暂时读不到。',
        stamp: economy == null ? null : 'LOOP DB',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('loop-economy-capability-unavailable'),
            icon: 'warn',
            message: '生态账本当前不可用',
            reason: '请稍后再试。',
          )
        else if (economy == null)
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
          const LoopLabel('暂时无法核对的项目'),
          LaunchUnavailableCard(label: '总量', fact: economy.totalSupply),
          LaunchUnavailableCard(label: '累计分发', fact: economy.distributed),
          LaunchUnavailableCard(label: '累计生态税', fact: economy.ecosystemTax),
          // The economy response carries no configuration version, so the
          // footer omits the segment rather than restating an assumed one.
          LaunchSourceFooter(
            source: economy.source,
            observedAt: economy.observedAt,
          ),
          const SizedBox(height: 20),
        ],
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
      kicker: 'CURATED LAUNCH',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: 'CURATED LAUNCH',
        heading: selected == null
            ? '新建申请'
            : launchReviewStatusLabel(selected.reviewStatus),
        caption: '提交不代表通过。审核由人工进行，结果与上线时间以最新状态为准。',
        stamp: selected == null ? null : 'v${selected.materialVersion}',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-apply-capability-unavailable'),
            icon: 'warn',
            message: '申请入口当前不可用',
            reason: '请稍后再试。',
          )
        else if (state.phase != LaunchViewPhase.ready)
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
    final reason = project.reviewReasonCode;
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
            body: launchReviewReasonText(reason),
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
                style: LoopTypography.sora(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: LoopColors.text2,
                  height: 1.6,
                ),
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
