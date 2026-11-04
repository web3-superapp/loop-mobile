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
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
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
      title: context.l10n.launch_actionScreensLoopStakeScreenTitle,
      onBack: widget.onBack,
      // 暂无数值 described a page with no figures as if figures were owed,
      // and the English state name beside it was the wire value of the
      // executability flag. Neither is what a reader needs: staking has not
      // opened, and the sentence under the heading says what that costs.
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_actionScreensKicker,
          heading: context.l10n.launch_actionScreensHeading,
          caption: context.l10n.launch_actionScreensCaption,
          stamp: context.l10n.common_notOpenYet,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.loop-stake-balance`: the two readings the prototype welds under
        // this folio. Both need the staking contract, so both are em dashes.
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: context.l10n.launch_actionScreensLabel,
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: context.l10n.launch_actionScreensTrailingLabel,
            trailingValue: loopFigureDash,
            spoken: context.l10n.launch_actionScreensHeading,
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('loop-stake-capability-unavailable'),
              title: context
                  .l10n
                  .launch_actionScreensLoopStakeCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_actionScreensEmptyMessage,
            emptyReason: context.l10n.launch_actionScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // `.loop-stake-tabs`: the prototype's two-way choice, kept as the
          // shape of the page and disabled, so the page reads as a form that
          // has not opened rather than as a page that never had one
          // (visual audit 2026-09-21 §H.10).
          LoopChipRow(
            key: const ValueKey<String>('loop-stake-tabs'),
            children: <Widget>[
              LoopSeg(
                label: context.l10n.launch_actionScreensLabel2,
                selected: true,
                onSelected: null,
              ),
              LoopSeg(
                label: context.l10n.launch_actionScreensLabel3,
                selected: false,
                onSelected: null,
              ),
            ],
          ),
          _StakeAmountCard(executable: stake.executable),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('loop-stake-submit'),
              label: context.l10n.launch_actionScreensLoopStakeSubmitLabel,
              primary: true,
              block: true,
              // 03 §10.1: staking has no approved contract scheme, so the
              // action is marked non-executable and no signing entry point
              // exists on this page at all.
              onPressed: null,
              semanticLabel:
                  context.l10n.launch_actionScreensLoopStakeSubmitSemanticLabel,
            ),
          ),
          LaunchUnavailableCard(
            id: 'my-staking',
            label: context.l10n.launch_actionScreensLabel4,
            fact: stake.stake,
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(capability: capability),
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
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        0,
      ),
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
                      context.l10n.launch_actionScreensBuild,
                      style: LoopType.kicker.copyWith(color: auxiliary),
                    ),
                  ),
                  LoopBadge(
                    executable
                        ? context.l10n.launch_actionScreensLoopBadge
                        : context.l10n.launch_actionScreensS,
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
                      style: LoopType.figureLg.copyWith(color: ink),
                    ),
                  ),
                  Text('LOOP', style: LoopType.figure.copyWith(color: ink)),
                ],
              ),
              const LoopHairline(),
              Text(
                context.l10n.launch_actionScreensBuild2,
                style: LoopType.captionSm.copyWith(color: auxiliary),
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
      title: context.l10n.launch_actionScreensLoopEconomyScreenTitle,
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: context.l10n.launch_actionScreensKicker2,
        // The only provable headline is a count of approved rounds.
        heading: economy == null
            ? launchMissingHeading
            : context.l10n.launch_actionScreensHeading2(
                economy.confirmedRoundCount,
              ),
        caption: context.l10n.launch_actionScreensCaption2,
        stamp: economy == null ? null : context.l10n.launch_actionScreensStamp,
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'loop-economy-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_actionScreensLoopEconomyCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_actionScreensEmptyMessage2,
            emptyReason: context.l10n.launch_actionScreensEmptyReason2,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopLabel(context.l10n.launch_actionScreensLoopLabel),
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
            LoopLabel(context.l10n.launch_actionScreensLoopLabel2),
            _EconomyOnChainCard(onChain: onChain),
          ],
          const LoopLabel('LOOP'),
          LoopStatGrid(
            key: const ValueKey<String>('loop-economy-loop-stats'),
            stats: <LoopStat>[
              LoopStat(
                label: context.l10n.common_totalSupply,
                value: loopFigureDash,
              ),
              LoopStat(
                label: context.l10n.launch_actionScreensLabel5,
                value: loopFigureDash,
              ),
              LoopStat(
                label: context.l10n.launch_actionScreensLabel6,
                value: '${economy.confirmedRoundCount}',
              ),
              LoopStat(
                label: context.l10n.launch_actionScreensLabel7,
                value: '${economy.projects.approved}',
              ),
            ],
          ),
          _EconomyReasons(
            economy: economy,
            contractLive: capability.evidenceConfirmed,
          ),
          LoopLabel(context.l10n.launch_actionScreensLoopLabel3),
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
          LoopLabel(context.l10n.launch_actionScreensLoopLabel4),
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
          LoopLabel(context.l10n.launch_actionScreensLoopLabel5),
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
List<(String, String)> get _flywheel => <(String, String)>[
  (
    LoopL10n.current.launch_actionScreensText,
    LoopL10n.current.launch_actionScreensText2,
  ),
  (
    LoopL10n.current.launch_actionScreensText3,
    LoopL10n.current.launch_actionScreensText4,
  ),
  (
    LoopL10n.current.launch_actionScreensText5,
    LoopL10n.current.launch_actionScreensText6,
  ),
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
                Expanded(
                  child: _cell(
                    context,
                    '$_registered',
                    context.l10n.launch_actionScreensCell,
                  ),
                ),
                Expanded(
                  child: _cell(
                    context,
                    loopFigureDash,
                    context.l10n.common_graduated,
                  ),
                ),
              ],
            ),
            const LoopHairline(),
            Row(
              children: <Widget>[
                Expanded(
                  child: _cell(
                    context,
                    loopFigureDash,
                    context.l10n.launch_actionScreensCell2,
                  ),
                ),
                Expanded(
                  child: _cell(
                    context,
                    loopFigureDash,
                    context.l10n.launch_actionScreensCell3,
                  ),
                ),
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
        '$label${LoopL10n.current.common_listSeparator}'
        '${value == loopFigureDash ? launchEconomyReasonText(economy.ecosystemTax.reasonCode, contractLive: contractLive) : value}',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: LoopType.figure.copyWith(color: LoopGround.inkOf(context)),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: LoopType.kicker.copyWith(
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
      'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' =>
        LoopL10n.current.launch_actionScreensSwitch,
      'LAUNCH_ONCHAIN_STATE_NOT_PROJECTED' =>
        LoopL10n.current.launch_actionScreensSwitch2,
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
      LaunchEconomyOnChainUnavailable(:final reasonCode) =>
        LoopInlineUnavailable(
          key: const ValueKey<String>('loop-economy-onchain-unavailable'),
          message: context
              .l10n
              .launch_actionScreensLoopEconomyOnchainUnavailableMessage,
          detail: launchEconomyOnChainReasonText(reasonCode),
          maxLines: 2,
          detailMaxLines: 4,
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
                context.l10n.launch_actionScreensCell4,
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
                      context.l10n.launch_actionScreensCell5,
                    ),
                  ),
                  Expanded(
                    child: _cell(
                      context,
                      const ValueKey<String>('loop-economy-onchain-lp'),
                      '${value.lockedLpCount}',
                      context.l10n.launch_actionScreensCell6,
                    ),
                  ),
                ],
              ),
              const LoopHairline(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.l10n.launch_actionScreensLoopEconomyOnchainBlock(
                    loopGroupedFigure(value.indexedBlockNumber),
                  ),
                  key: const ValueKey<String>('loop-economy-onchain-block'),
                  style: LoopType.figureXs.copyWith(
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
    label: '$label${LoopL10n.current.common_listSeparator}$value',
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
              style: LoopType.captionSm.copyWith(
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
          LoopInlineUnavailable(
            key: ValueKey<String>('loop-economy-reason-$code'),
            message: context.l10n.launch_actionScreensMessage,
            detail: launchEconomyReasonText(code, contractLive: contractLive),
            maxLines: 2,
            detailMaxLines: 4,
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
    // Decision 0206: sent as typed (trimmed), never upper-cased.
    ticker: _ticker.text.trim(),
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
      title: context.l10n.launch_actionScreensLaunchApplyScreenTitle,
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: context.l10n.launch_actionScreensKicker3,
        // The heading is a conclusion, not the page's own title: the length
        // of the review pipeline before a draft exists, the applicant's own
        // state once one does.
        heading: selected == null
            ? context.l10n.launch_actionScreensHeading3(_reviewPipeline.length)
            : launchReviewStatusLabel(selected.reviewStatus),
        caption: context.l10n.launch_actionScreensCaption3,
        stamp: selected == null
            ? context.l10n.launch_actionScreensStamp2(_reviewPipeline.length)
            : 'v${selected.materialVersion}',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-apply-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_actionScreensLaunchApplyCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_actionScreensEmptyMessage3,
            emptyReason: context.l10n.launch_actionScreensEmptyReason3,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // `Review Record`: the four states the server's own machine moves a
          // draft through, with the applicant's current one marked. The
          // prototype opens on this block; the App opened straight onto the
          // form, so the page never said what submitting leads to
          // (visual audit 2026-09-21 §H.12).
          LoopLabel(context.l10n.launch_actionScreensLoopLabel6),
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
            LoopLabel(context.l10n.launch_actionScreensLoopLabel7),
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
                    label: context.l10n.launch_actionScreensLaunchApplyNewLabel,
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
          LoopLabel(context.l10n.launch_actionScreensLoopLabel8),
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
          LoopLabel(context.l10n.launch_actionScreensLoopLabel9),
          _DeferredProviderBlock(project: selected),
          if (state.writeFailureKind != null) ...<Widget>[
            LoopNotice(
              key: const ValueKey<String>('launch-apply-write-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title:
                  context.l10n.launch_actionScreensLaunchApplyWriteFailureTitle,
              body: launchFailureReason(state.writeFailureKind),
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                14,
                LoopSpacing.page,
                0,
              ),
            ),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('launch-apply-reload'),
                  label: context.l10n.common_reload,
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
                label: selected == null
                    ? context.l10n.launch_actionScreensLaunchApplySaveLabel
                    : context.l10n.launch_actionScreensLaunchApplySaveLabel2,
                primary: true,
                onPressed: !editable || state.busy
                    ? null
                    : () => unawaited(controller.save(_draft())),
              ),
              LoopButton(
                key: const ValueKey<String>('launch-apply-submit'),
                label:
                    selected?.reviewStatus == LaunchReviewStatus.returned ||
                        selected?.reviewStatus == LaunchReviewStatus.rejected
                    ? context.l10n.launch_actionScreensLaunchApplySubmitLabel
                    : context.l10n.launch_actionScreensLaunchApplySubmitLabel2,
                onPressed: selected == null || !selected.canSubmit || state.busy
                    ? null
                    : () => unawaited(controller.submit()),
              ),
            ],
          ),
          // `details.focus-disclosure`: the curation statement and the
          // submission caveat, where the prototype keeps them.
          LoopDisclosure(
            key: ValueKey<String>('launch-apply-principles'),
            summary:
                context.l10n.launch_actionScreensLaunchApplyPrinciplesSummary,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: _CurationCard(),
            ),
          ),
          LoopNotice(
            key: ValueKey<String>('launch-apply-notice'),
            icon: 'info',
            title: context.l10n.launch_actionScreensLaunchApplyNoticeTitle,
            body: context.l10n.launch_actionScreensLaunchApplyNoticeBody,
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
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
          ? LoopBadge(
              LoopL10n.current.launch_actionScreensLoopBadge2,
              kind: LoopBadgeKind.launch,
            )
          : null,
      position: launchRowPosition(index, _reviewPipeline.length),
      semanticLabel:
          '$label${LoopL10n.current.common_listSeparator}${launchReviewStatusHint(status)}'
          '${isCurrent ? LoopL10n.current.launch_actionScreensCurrentSuffix : ''}',
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
      subtitle: LoopL10n.current.launch_actionScreensSubtitle(
        launchTimestampLabel(project.updatedAt),
        project.materialVersion,
        project.ticker,
      ),
      trailingBadge: LoopBadge(
        launchReviewStatusLabel(project.reviewStatus),
        kind: selected ? LoopBadgeKind.launch : LoopBadgeKind.mute,
      ),
      onTap: onTap,
      position: position,
      semanticLabel:
          '${project.name}${LoopL10n.current.common_listSeparator}${launchReviewStatusLabel(project.reviewStatus)}'
          '${selected ? LoopL10n.current.launch_actionScreensSelectedSuffix : ''}',
    );
  }
}

/// The review pipeline, in the order the server's own state machine moves a
/// draft through it. The terminal states share the last step, because an
/// applicant reaches exactly one of them.
List<(String, LaunchReviewStatus)> get _reviewPipeline =>
    <(String, LaunchReviewStatus)>[
      (LoopL10n.current.common_draft, LaunchReviewStatus.draft),
      (LoopL10n.current.common_submitted, LaunchReviewStatus.submitted),
      (LoopL10n.current.common_inReview, LaunchReviewStatus.inReview),
      (
        LoopL10n.current.launch_actionScreensProjectRow,
        LaunchReviewStatus.approved,
      ),
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
            context.l10n.launch_actionScreensKicker3,
            style: LoopType.kicker,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.launch_actionScreensBuild3,
            style: LoopType.displaySm,
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.launch_actionScreensBuild4,
            style: LoopType.captionSm.copyWith(color: LoopColors.text2),
          ),
          const LoopHairline(),
          Text(
            context.l10n.launch_actionScreensBuild5,
            style: LoopType.captionSm,
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
        LoopLabel(context.l10n.launch_actionScreensLoopLabel10),
        if (milestones == null)
          LaunchStateBlock(
            prefix: 'launch-milestones',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: context.l10n.launch_actionScreensEmptyMessage4,
            emptyReason: context.l10n.launch_actionScreensEmptyReason4,
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
        LoopLabel(context.l10n.launch_actionScreensLoopLabel11),
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
              title:
                  context.l10n.launch_actionScreensLaunchApplySubmittedAtTitle,
              // A non-owner projection nulls the review trail; the em dash is
              // "not visible to you", not "never submitted".
              subtitle: project.isOwnerProjection
                  ? context
                        .l10n
                        .launch_actionScreensLaunchApplySubmittedAtSubtitle
                  : context
                        .l10n
                        .launch_actionScreensLaunchApplySubmittedAtSubtitle2,
              trailing: project.submittedAt == null
                  ? launchMissingFigure
                  : launchTimestampLabel(project.submittedAt!),
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('launch-apply-reviewed-at'),
              title:
                  context.l10n.launch_actionScreensLaunchApplyReviewedAtTitle,
              trailing: project.reviewedAt == null
                  ? launchMissingFigure
                  : launchTimestampLabel(project.reviewedAt!),
              position: LoopRowPosition.middle,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('launch-apply-launch-id'),
              title: context.l10n.launch_actionScreensLaunchApplyLaunchIdTitle,
              subtitle: project.launchId == null
                  ? context.l10n.launch_actionScreensLaunchApplyLaunchIdSubtitle
                  : context
                        .l10n
                        .launch_actionScreensLaunchApplyLaunchIdSubtitle2,
              trailing: project.launchId == null
                  ? launchMissingFigure
                  : context
                        .l10n
                        .launch_actionScreensLaunchApplyLaunchIdTrailing,
              position: LoopRowPosition.last,
            ),
          ],
        ),
        if (reason != null)
          LoopNotice(
            key: const ValueKey<String>('launch-apply-returned-reason'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title:
                context.l10n.launch_actionScreensLaunchApplyReturnedReasonTitle,
            body: reason,
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
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
              labelText: context.l10n.launch_actionScreensLabelText,
              errorText: _errorFor(LaunchDraftField.name),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-ticker'),
            controller: ticker,
            enabled: enabled,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: context.l10n.launch_actionScreensLabelText2,
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
              labelText: context.l10n.launch_actionScreensLabelText3,
              errorText: _errorFor(LaunchDraftField.narrative),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-website'),
            controller: website,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: context.l10n.launch_actionScreensLabelText4,
              errorText: _errorFor(LaunchDraftField.officialLinks),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-x'),
            controller: x,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: context.l10n.launch_actionScreensLabelText5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-telegram'),
            controller: telegram,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: context.l10n.launch_actionScreensLabelText6,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('launch-apply-discord'),
            controller: discord,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: context.l10n.launch_actionScreensLabelText7,
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                context.l10n.launch_actionScreensBuild6,
                style: LoopType.captionSm.copyWith(color: LoopColors.text2),
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
      return LoopInlineUnavailable(
        key: ValueKey<String>('launch-apply-providers-pending'),
        message:
            context.l10n.launch_actionScreensLaunchApplyProvidersPendingMessage,
        detail:
            context.l10n.launch_actionScreensLaunchApplyProvidersPendingDetail,
        maxLines: 2,
        detailMaxLines: 4,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LaunchUnavailableCard(
          id: 'attachments',
          label: context.l10n.launch_actionScreensLabel8,
          fact: current.attachments,
        ),
        LoopInlineUnavailable(
          key: const ValueKey<String>('launch-apply-kyb'),
          icon: 'shield',
          message: context.l10n.launch_actionScreensLaunchApplyKybMessage,
          detail: launchReasonCodeText(current.kyb.reasonCode),
          maxLines: 2,
          detailMaxLines: 4,
        ),
      ],
    );
  }
}
