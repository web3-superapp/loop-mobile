import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Shared gate for the wallet read pages: both the wallet module and the chain
/// runtime must be available before any figure is requested.
bool _walletBlocked(WidgetRef ref) => walletCapabilityBlocks(
  ref.watch(walletReadGatewayProvider).mode,
  ref.watch(loopCapabilityProvider(LoopV2CapabilityId.walletRead)),
  ref.watch(loopCapabilityProvider(LoopV2CapabilityId.bscRead)),
);

/// The gate that actually closed the wallet pages.
///
/// A wallet read needs both gates, so the page reports the one that is shut
/// and keeps its projection: "LOOP never answered" and "LOOP answered that the
/// chain node is down" are two different facts, and the second one's reason is
/// the server's, never the client's guess. [fallback] is used only when the
/// server closed the gate without naming a rule.
({LoopCapabilityProjection capability, String fallback}) _walletBlockGate(
  WidgetRef ref,
) {
  final walletRead = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.walletRead),
  );
  if (!walletRead.isAvailable) {
    return (capability: walletRead, fallback: 'WALLET_RUNTIME_UNAVAILABLE');
  }
  return (
    capability: ref.watch(loopCapabilityProvider(LoopV2CapabilityId.bscRead)),
    fallback: 'BSC_CHAIN_RUNTIME_UNAVAILABLE',
  );
}

/// The whole-page block a closed wallet gate renders.
Widget _walletPageBlock(
  WidgetRef ref, {
  required Key key,
  required String title,
}) {
  final gate = _walletBlockGate(ref);
  return LoopCapabilityPageBlock.of(
    key: key,
    title: title,
    capability: gate.capability,
    fallbackReasonCode: gate.fallback,
  );
}

/// One pull re-reads the wallet directory and, when a wallet is selected, that
/// wallet's balances. Neither read clears what it already put on screen.
Future<void> _refreshWallet(WidgetRef ref, String? walletId) async {
  await ref.read(walletDirectoryControllerProvider.notifier).reload();
  if (walletId == null) return;
  await ref.read(walletBalancesControllerProvider(walletId).notifier).reload();
}

/// Loads the wallet directory once and returns the active wallet id.
String? _watchActiveWalletId(WidgetRef ref, {required bool blocked}) {
  final directory = ref.watch(walletDirectoryControllerProvider);
  if (!blocked && directory.phase == LoopChainViewPhase.loading) {
    scheduleMicrotask(
      () => unawaited(
        ref.read(walletDirectoryControllerProvider.notifier).load(),
      ),
    );
  }
  return directory.value?.activeWalletId;
}

/// Whether `GET /v2/wallets` answered, and answered "no wallet".
///
/// A directory that has not been read, or whose read failed, is never empty:
/// it is unknown, and the state block says so instead.
bool _directoryIsEmpty(LoopChainResourceState<LoopWalletDirectory> directory) {
  final value = directory.value;
  return directory.isReady && value != null && value.isEmpty;
}

/// The same answer, read from the provider. It is evaluated unconditionally so
/// a page's dependencies cannot change between builds.
bool _noWalletYet(WidgetRef ref) =>
    _directoryIsEmpty(ref.watch(walletDirectoryControllerProvider));

// ---------------------------------------------------------------------------
// wallet
// ---------------------------------------------------------------------------

/// `wallet` · the钱包 tab.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, this.onNavigate});

  final void Function(String location)? onNavigate;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  /// What a blocked action answers with.
  ///
  /// The prototype's four money actions are a Lime `Pay` pill, a compact
  /// 兑换 and a three-up 发送 / 接收 / 跨链 grid. They used to be demoted to
  /// list rows wearing a grey 不可用 badge, which emptied the page's first
  /// screen of every action it has (audit item 3). They keep their shape now;
  /// a closed gate takes the disabled paint and says, on the tap, the one
  /// sentence the server gave.
  void _blocked(String reason) {
    LoopToast.show(context, message: reason, kind: LoopToastKind.warn);
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final walletId = _watchActiveWalletId(ref, blocked: blocked);
    final directory = ref.watch(walletDirectoryControllerProvider);
    final balancesState = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (walletId != null &&
        balancesState != null &&
        balancesState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final balances = balancesState?.value;

    // A money-action row promises what the destination can do. Both gates are
    // read here so the promise matches the page one tap away.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final sendGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.sendApprovals),
    );
    final swapAvailable = swapGate.isAvailable;
    final sendAvailable = sendGate.isAvailable;
    final swapReason = loopReasonCodeText(
      swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
    );
    final sendReason = loopReasonCodeText(
      sendGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
    );
    // The prototype's asset rows carry each holding's mining power. It is the
    // Mining module's own snapshot, read through the same controller Mining
    // uses; a snapshot that has no row for a holding renders a dash.
    final miningAssets = watchWalletMiningAssets(ref);

    return LoopDashboardPage(
      key: const ValueKey<String>('wallet-screen'),
      archetype: LoopPageArchetype.record,
      title: '钱包',
      tabPage: true,
      // Balances the page already read stay on screen while the next read
      // runs; only the 更新中 mark changes.
      updating: balancesState?.refreshing ?? false,
      // Pull to re-read the directory and the balances of the active wallet.
      // The rows that were read stay on screen; only the 更新中 mark changes.
      onRefresh: () => _refreshWallet(ref, walletId),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('wallet-capability-block'),
              title: '钱包读取当前不可用',
            )
          : null,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('wallet-manage-action'),
          icon: 'wallet',
          label: '切换钱包',
          onPressed: () => _open('/wallet/manage'),
        ),
        LoopIconButton(
          key: const ValueKey<String>('wallet-history-action'),
          icon: 'clock',
          label: '交易记录',
          onPressed: () => _open('/wallet/history'),
        ),
      ],
      primary: _WalletPrimary(
        directory: directory.value,
        directoryIsEmpty: _directoryIsEmpty(directory),
        balances: balances,
        onOpenNetWorth: () => _open('/wallet/networth'),
      ),
      sections: <Widget>[
        // Three different answers, three different blocks: the list was not
        // read, the list was read and is empty, or a wallet is active.
        if (_directoryIsEmpty(directory))
          const WalletCreationBlock(keyPrefix: 'wallet-directory')
        else if (walletId == null && directory.isReady)
          LoopEmpty(
            key: const ValueKey<String>('wallet-directory-no-active'),
            message: '还没有选定当前钱包',
            reason: '这个账号已经有钱包，但还没有选定当前钱包。到“我的钱包”里选一个后才会显示余额。',
            action: LoopButton(
              key: const ValueKey<String>('wallet-directory-pick'),
              label: '我的钱包',
              primary: true,
              onPressed: () => _open('/wallet/manage'),
            ),
          )
        else if (walletId == null)
          LoopChainStateBlock(
            keyPrefix: 'wallet-directory',
            phase: directory.phase,
            failureKind: directory.failureKind,
            emptyMessage: '钱包清单还没有读到',
            emptyReason: '这不是“没有钱包”，只是这次没有读到清单。',
            onRetry: () => unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).reload(),
            ),
          )
        else if (balancesState == null || !balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'wallet-balances',
            phase: balancesState?.phase ?? LoopChainViewPhase.loading,
            failureKind: balancesState?.failureKind,
            emptyMessage: '这个钱包还没有可读资产',
            onRetry: () => unawaited(
              ref
                  .read(walletBalancesControllerProvider(walletId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          // The prototype's first screen: the Lime `Pay` pill beside 兑换,
          // then 发送 / 接收 / 跨链 as a three-up grid. Every entry keeps its
          // shape whether or not its gate is open.
          LoopPrimaryActionRow(
            onBlocked: _blocked,
            primary: LoopAction(
              actionKey: const ValueKey<String>('wallet-pay-entry'),
              label: 'Pay',
              icon: 'camera',
              // Pay has no reviewed runtime at all, so there is no gate to
              // read and the sentence is the product's own.
              blockedReason: '扫码支付还没有开放。',
            ),
            secondary: LoopAction(
              actionKey: const ValueKey<String>('wallet-swap-entry'),
              label: '兑换',
              icon: 'swap-vert',
              onPressed: swapAvailable ? () => _open('/wallet/swap') : null,
              blockedReason: swapAvailable ? null : swapReason,
            ),
          ),
          LoopActionGrid(
            onBlocked: _blocked,
            actions: <LoopAction>[
              LoopAction(
                actionKey: const ValueKey<String>('wallet-send-entry'),
                label: '发送',
                icon: 'arrow-up',
                onPressed: sendAvailable ? () => _open('/wallet/send') : null,
                blockedReason: sendAvailable ? null : sendReason,
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-receive-entry'),
                label: '接收',
                icon: 'arrow-down',
                onPressed: () => _open(WalletRoute.receive(walletId)),
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-bridge-entry'),
                label: '跨链',
                icon: 'globe',
                blockedReason: '跨链还没有开放。',
              ),
            ],
          ),
          WalletHoldingsPowerHint(onOpenMining: () => _open('/mining')),
          const LoopLabel('资产'),
          if (balances!.balances.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('wallet-balances-empty'),
              message: '还没有可读取的资产',
              reason: '登记资产后，这里会为每一个资产恒定保留一行。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final row in balances.balances)
                  walletBalanceRow(
                    row,
                    miningText: walletAssetPowerText(miningAssets, row.assetId),
                    onTap: () =>
                        _open(MarketAssetRoute.walletAsset(row.assetId)),
                  ),
              ],
            ),
          // One provenance line, not two: the block a figure was read at and
          // the reserve taken out of it are the same sentence about the same
          // snapshot.
          LoopProvenanceFooter(
            key: const ValueKey<String>('wallet-snapshot-footer'),
            text:
                '区块 '
                '${loopGroupedFigure(balances.snapshot.blockNumber.toString())} · '
                '${loopGroupedFigure(balances.snapshot.confirmations.toString())} 确认 · '
                '观察于 ${loopRelativeTime(balances.snapshot.observedAt)} · '
                '手续费保留 '
                '${loopFormatDecimal(balances.gasReservePolicy.nativeReserve)} BNB',
          ),
          // Decision 0038: the Launch chain block exists only when the
          // backend published one. Its balance is a testnet figure and is
          // never added to the assets above or to the net worth.
          if (balances.launchChain != null) ...<Widget>[
            const LoopLabel('Launch 链'),
            WalletLaunchChainCard(launchChain: balances.launchChain!),
          ],
          const LoopLabel('安全与连接'),
          // The prototype's four rows, in its order. The counts it shows —
          // 「8 个有效授权」, 「4 条链已启用」 — are not read here, so each row
          // says what its page is for instead of stating a figure this page
          // never asked for.
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-security-entry'),
                leading: const LoopRowIcon(icon: 'lock'),
                title: '安全中心',
                subtitle: '设备、会话与账户保护',
                onTap: () => _open('/profile/security'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-dapp-entry'),
                leading: const LoopRowIcon(icon: 'globe'),
                title: 'DApp 核对',
                subtitle: '本地核对网址；连接与签名尚未开放',
                onTap: () => _open('/wallet/dapp'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-approvals-entry'),
                leading: const LoopRowIcon(icon: 'shield'),
                title: '授权盘点',
                subtitle: '当场重读的 allowance()，回收会发送 approve(spender, 0)',
                // 「回收会发送 approve(spe…」 cut the sentence exactly where it
                // said what the action does.
                subtitleMaxLines: 2,
                onTap: () => _open('/wallet/approvals'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-networks-entry'),
                leading: const LoopRowIcon(icon: 'settings'),
                title: '网络与 RPC',
                // The page lists whatever the server published: the primary
                // chain always, and the Launch slot when it differs from it.
                subtitle: '已启用的网络与 RPC 端点健康',
                onTap: () => _open('/wallet/networks'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _WalletPrimary extends StatelessWidget {
  const _WalletPrimary({
    required this.directory,
    required this.directoryIsEmpty,
    required this.balances,
    required this.onOpenNetWorth,
  });

  final LoopWalletDirectory? directory;

  /// The directory was read and holds no wallet. Without it the caption could
  /// not tell "you have no wallet" from "the list was not read".
  final bool directoryIsEmpty;
  final LoopWalletBalances? balances;
  final VoidCallback onOpenNetWorth;

  @override
  Widget build(BuildContext context) {
    final active = directory?.active;
    final netWorth = balances?.netWorth;
    // A folio heading is a figure or a conclusion, never the page's own title:
    // 「钱包」 over the wallet page made the primary a second title bar (audit
    // item 1). Before the first read there is no figure, and the heading says
    // that instead.
    final heading = switch (netWorth) {
      LoopNetWorthValued(valueUsd: final value) => loopFormatUsd(value),
      LoopNetWorthUnavailable() => '净值不可用',
      null => '余额还没有读到',
    };
    return LoopFolioPrimary(
      key: const ValueKey<String>('wallet-folio'),
      archetype: LoopFolioArchetype.record,
      kicker: 'WALLET LEDGER',
      heading: heading,
      // Three answers the caption must keep apart: the list was never read,
      // the list was read and holds no wallet, and the list holds wallets but
      // names no active one. Only the first is a failed read.
      caption: switch ((active, directoryIsEmpty, directory)) {
        (final LoopWalletAccount active, _, _) =>
          '${active.truncatedAddress} · '
              '${netWorth is LoopNetWorthValued && netWorth.partial ? '部分资产未估值' : '净值不是可用余额'}',
        (_, true, _) => '这个账号还没有钱包，创建后余额会出现在这里。',
        (_, _, null) => '钱包列表暂时读不到，这里不显示余额。',
        _ => '还没有选定当前钱包，这里不显示余额。',
      },
      stamp: netWorth is LoopNetWorthValued ? 'NET WORTH' : null,
      trailing: LoopIconButton(
        key: const ValueKey<String>('wallet-networth-entry'),
        icon: 'chevron',
        label: '查看净值明细',
        onPressed: onOpenNetWorth,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// networth
// ---------------------------------------------------------------------------

/// `networth` · the valuation breakdown of the active wallet.
class NetWorthScreen extends ConsumerStatefulWidget {
  const NetWorthScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<NetWorthScreen> createState() => _NetWorthScreenState();
}

class _NetWorthScreenState extends ConsumerState<NetWorthScreen> {
  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final walletId = _watchActiveWalletId(ref, blocked: blocked);
    // A walletless account is not a page that is still loading.
    final noWalletYet = _noWalletYet(ref) && walletId == null;
    final state = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (walletId != null &&
        state != null &&
        state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final balances = state?.value;
    final netWorth = balances?.netWorth;

    return LoopDashboardPage(
      key: const ValueKey<String>('networth-screen'),
      onRefresh: walletId == null
          ? null
          : () => ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
      updating: state?.refreshing ?? false,
      archetype: LoopPageArchetype.listing,
      title: '净值明细',
      onBack: widget.onBack,
      // The prototype's net-worth primary is a Chalk card, and it is the page's
      // only figure. The app painted the same dark Lime folio every other page
      // wears and then repeated the total in a card below it (audit §A.2).
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('networth-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'WALLET OVERVIEW',
        heading: switch (netWorth) {
          LoopNetWorthValued(valueUsd: final value) => loopFormatUsd(value),
          LoopNetWorthUnavailable() => '净值不可用',
          null => '净值还没有读到',
        },
        caption: '全部钱包资产的当前估值与资产构成。',
        stamp: netWorth is LoopNetWorthValued && netWorth.partial
            ? 'PARTIAL'
            : null,
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('networth-capability-block'),
              title: '钱包读取当前不可用',
            )
          : null,
      sections: <Widget>[
        if (noWalletYet)
          const WalletCreationBlock(keyPrefix: 'networth')
        else if (walletId == null || state == null || !state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'networth',
            phase: state?.phase ?? LoopChainViewPhase.loading,
            failureKind: state?.failureKind,
            emptyMessage: '还没有可估值的资产',
            onRetry: walletId == null
                ? null
                : () => unawaited(
                    ref
                        .read(
                          walletBalancesControllerProvider(walletId).notifier,
                        )
                        .reload(),
                  ),
          )
        else ...<Widget>[
          // The total is the heading now; what stays here is everything the
          // heading cannot carry — 不是可用余额, the partial count, the quality
          // mark and the source.
          WalletNetWorthCard(netWorth: balances!.netWorth, compact: true),
          const LoopLabel('按资产'),
          // The prototype's 按资产 / 按链 / 按社区 segment bar is not here: one
          // chain is published and community binding has no read, so two of
          // the three chips would be dead and the third would group the list
          // it already is.
          // A registry with no readable row must say so. An unlabelled empty
          // group would read as "this wallet holds nothing", which the read
          // does not prove.
          if (balances.balances.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('networth-empty'),
              message: '这个钱包还没有可计入净值的资产',
              reason: '净值只累计已登记且可读的资产；读不到的资产不会被当作 0。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final row in balances.balances)
                  walletBalanceRow(
                    row,
                    onTap: () =>
                        _open(MarketAssetRoute.walletAsset(row.assetId)),
                  ),
              ],
            ),
          WalletSnapshotFooter(snapshot: balances.snapshot),
          // The prototype's 30D area chart keeps its panel. Nothing is drawn
          // in it: net worth over time needs the holdings this account held on
          // each of those days, and no read reports them. Multiplying today's
          // holdings by yesterday's prices would answer a different question
          // in the shape of this one.
          const LoopChartPanel(
            key: ValueKey<String>('networth-trend-unavailable'),
            range: '30D',
            absence: '净值走势与 24h 涨跌还没有数据来源，读到之前这里不画任何走势。',
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// asset
// ---------------------------------------------------------------------------

/// `asset` · one held asset inside the active wallet.
class WalletAssetScreen extends ConsumerStatefulWidget {
  const WalletAssetScreen({
    required this.assetId,
    super.key,
    this.onBack,
    this.onNavigate,
  });

  final String? assetId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<WalletAssetScreen> createState() => _WalletAssetScreenState();
}

class _WalletAssetScreenState extends ConsumerState<WalletAssetScreen> {
  void _blocked(String reason) {
    LoopToast.show(context, message: reason, kind: LoopToastKind.warn);
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return LoopFocusPage(
        key: const ValueKey<String>('wallet-asset-invalid'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这个资产',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('wallet-asset-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的资产标识',
            reason: '本页只接受规范的 CAIP assetId，未请求任何余额。',
          ),
        ],
      );
    }
    final blocked = _walletBlocked(ref);
    final walletId = _watchActiveWalletId(ref, blocked: blocked);
    // A walletless account is not a page that is still loading.
    final noWalletYet = _noWalletYet(ref) && walletId == null;
    final balancesState = walletId == null
        ? null
        : ref.watch(walletBalancesControllerProvider(walletId));
    if (walletId != null &&
        balancesState != null &&
        balancesState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final registry = ref.watch(chainAssetControllerProvider(assetId));
    if (!blocked && registry.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(chainAssetControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final row = balancesState?.value?.rowFor(assetId);
    final asset = registry.value?.asset;
    // The prototype's 发送 / 接收 / 兑换 row. Two of the three are writes, so
    // each one reads its own gate and states the server's sentence rather
    // than disappearing.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final sendGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.sendApprovals),
    );
    final swapAvailable = swapGate.isAvailable;
    final sendAvailable = sendGate.isAvailable;
    final swapReason = loopReasonCodeText(
      swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
    );
    final sendReason = loopReasonCodeText(
      sendGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
    );

    return LoopDashboardPage(
      key: ValueKey<String>('wallet-asset-$assetId'),
      onRefresh: walletId == null
          ? null
          : () => ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
      updating: balancesState?.refreshing ?? false,
      archetype: LoopPageArchetype.record,
      // One title line, as the prototype has it: 「Wallet 资产 · PEPE」. The
      // two-line title with the asset's name above its ticker turned the top
      // bar into a second primary (audit §A.3).
      title: '钱包资产 · ${asset?.symbol ?? row?.symbol ?? '—'}',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopSeg(
          key: const ValueKey<String>('wallet-asset-market-action'),
          label: '行情',
          selected: false,
          onSelected: () => _open(MarketAssetRoute.token(assetId)),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('wallet-asset-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET ASSET',
        // 「PEPE · $12,420」 — the ticker with what the holding is worth. A
        // balance with no price heads with the balance instead; neither is
        // ever the page's title.
        heading: _assetHeading(
          symbol: asset?.symbol ?? row?.symbol,
          balance: row?.balance,
          valuation: row?.valuation,
        ),
        caption: <String>[
          ?asset?.name,
          switch (row?.balance) {
            LoopBalanceAvailable(displayBalance: final value) =>
              loopFormatDecimal(value),
            LoopBalanceUnavailable(reasonCode: final reasonCode) =>
              loopReasonCodeText(reasonCode),
            null => '余额还没有读到',
          },
        ].join(' · '),
        stamp: _assetChainStamp(assetId),
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('wallet-asset-capability-block'),
              title: '钱包读取当前不可用',
            )
          : null,
      sections: <Widget>[
        if (noWalletYet)
          const WalletCreationBlock(keyPrefix: 'wallet-asset')
        else if (walletId == null ||
            balancesState == null ||
            !balancesState.isReady)
          LoopChainStateBlock(
            keyPrefix: 'wallet-asset',
            phase: balancesState?.phase ?? LoopChainViewPhase.loading,
            failureKind: balancesState?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '这个钱包没有这一行',
            onRetry: walletId == null
                ? null
                : () => unawaited(
                    ref
                        .read(
                          walletBalancesControllerProvider(walletId).notifier,
                        )
                        .reload(),
                  ),
          )
        else if (row == null)
          const LoopEmpty(
            key: ValueKey<String>('wallet-asset-missing-row'),
            icon: 'warn',
            message: '这个资产不在可读清单里',
            reason: '只有已登记的资产才会显示余额。',
          )
        else ...<Widget>[
          // The prototype's 2x2. Its four cells are 成本 / 浮动盈亏 / 收益率 /
          // 当前价; cost basis has no read, so the grid carries the four
          // figures this page actually has, and a figure with no read is a
          // dash rather than a zero.
          LoopStatGrid(
            stats: <LoopStat>[
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-balance'),
                label: '链上余额',
                value: switch (row.balance) {
                  LoopBalanceAvailable(displayBalance: final value) =>
                    loopFormatDecimal(value),
                  LoopBalanceUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-spendable'),
                label: '可动用',
                value: switch (row.balance) {
                  LoopBalanceAvailable(spendableBalance: final value) =>
                    loopFormatDecimal(value),
                  LoopBalanceUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-price'),
                label: '当前价',
                value: switch (row.valuation) {
                  LoopValuationAvailable(priceUsd: final value) =>
                    loopFormatUsd(value),
                  LoopValuationUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-value'),
                label: '估值',
                value: switch (row.valuation) {
                  LoopValuationAvailable(valueUsd: final value) =>
                    loopFormatUsd(value),
                  LoopValuationUnavailable() => loopFigureDash,
                },
              ),
            ],
          ),
          // The asset's own price line, from the same `1h` candle read the
          // Token Card uses. It is drawn only when the series was read.
          _AssetSparklinePanel(assetId: assetId),
          const LoopLabel('挖矿贡献'),
          WalletAssetPowerHint(
            assetId: assetId,
            onOpenMining: () => _open('/mining/assets'),
          ),
          LoopActionGrid(
            onBlocked: _blocked,
            actions: <LoopAction>[
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-send'),
                label: '发送',
                icon: 'arrow-up',
                onPressed: sendAvailable ? () => _open('/wallet/send') : null,
                blockedReason: sendAvailable ? null : sendReason,
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-receive'),
                label: '接收',
                icon: 'arrow-down',
                onPressed: () => _open(WalletRoute.receive(walletId)),
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-swap'),
                label: '兑换',
                icon: 'swap-vert',
                onPressed: swapAvailable ? () => _open('/wallet/swap') : null,
                blockedReason: swapAvailable ? null : swapReason,
              ),
            ],
          ),
          const LoopLabel('链上分布'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-asset-chain-row'),
                leading: const LoopNetworkLogo(network: 'bsc', size: 44),
                title: _assetChainName(assetId),
                subtitle: switch (row.balance) {
                  LoopBalanceAvailable(displayBalance: final value) =>
                    '${loopFormatDecimal(value)} ${row.symbol}',
                  LoopBalanceUnavailable(reasonCode: final reasonCode) =>
                    loopReasonCodeText(reasonCode),
                },
                trailing: switch (row.valuation) {
                  LoopValuationAvailable(valueUsd: final value) =>
                    loopFormatUsd(value),
                  LoopValuationUnavailable() => null,
                },
              ),
            ],
          ),
          const LoopLabel('收发记录'),
          _WalletAssetTransfers(
            walletId: walletId,
            assetId: assetId,
            onOpenHistory: () => _open(WalletRoute.history(walletId)),
          ),
          // The three key/value tables used to be the page. They state facts
          // nobody reads at a glance — a nineteen-digit minor-unit integer,
          // a precision, a registry status — and they pushed every prototype
          // block off the screen (audit item 5). They are still here, behind
          // the disclosure the prototype uses for exactly this.
          LoopDisclosure(
            key: const ValueKey<String>('wallet-asset-facts-disclosure'),
            summary: '余额说明与资产事实',
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _BalanceBreakdown(
                    row: row,
                    snapshot: balancesState.value!.snapshot,
                  ),
                  _RegistryFactsCard(
                    state: registry,
                    assetId: assetId,
                    rawValue: switch (row.balance) {
                      LoopBalanceAvailable(rawValue: final rawValue) =>
                        rawValue,
                      LoopBalanceUnavailable() => null,
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `PEPE · $12,420` — the prototype's asset heading.
///
/// It is the ticker with the one figure that says how much the holding is
/// worth. Without a price it falls back to the balance, and without a read it
/// says so; it is never the page's own title.
String _assetHeading({
  required String? symbol,
  required LoopBalanceAmount? balance,
  required LoopValuation? valuation,
}) {
  final ticker = symbol ?? '—';
  if (valuation is LoopValuationAvailable) {
    return '$ticker · ${loopFormatUsd(valuation.valueUsd)}';
  }
  if (balance is LoopBalanceAvailable) {
    return '$ticker · ${loopFormatDecimal(balance.displayBalance)}';
  }
  return '$ticker · 余额还没有读到';
}

/// The chain slot one canonical asset id names.
String _assetChainName(String assetId) {
  final chainId = assetId.substring(0, assetId.lastIndexOf(':'));
  return loopKnownChainIds.contains(chainId) ? loopChainName(chainId) : chainId;
}

/// The same chain, as the folio's uppercase stamp.
String? _assetChainStamp(String assetId) {
  final chainId = assetId.substring(0, assetId.lastIndexOf(':'));
  return loopKnownChainIds.contains(chainId)
      ? loopChainName(chainId).toUpperCase()
      : null;
}

/// The asset's own `1h` close line, inside the prototype's chart panel.
///
/// It is the series the Token Card reads, through the same controller, so no
/// request type is added. A series that was not read leaves the panel in place
/// and states why — the panel is the shape of the answer, and losing it was
/// half of audit item 6.
class _AssetSparklinePanel extends ConsumerWidget {
  const _AssetSparklinePanel({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = MarketCandleRequest(
      assetId: assetId,
      interval: LoopCandleInterval.oneHour,
    );
    final state = ref.watch(marketCandlesControllerProvider(request));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        unawaited(
          ref.read(marketCandlesControllerProvider(request).notifier).load(),
        );
      });
    }
    final absence = tokenCardSparklineAbsence(state);
    if (absence != null) {
      return LoopChartPanel(
        key: const ValueKey<String>('wallet-asset-chart'),
        range: '1H',
        absence: absence.text,
      );
    }
    final available = state.value!.candles as MarketCandlesAvailable;
    return LoopChartPanel(
      key: const ValueKey<String>('wallet-asset-chart'),
      range: '1H · ${loopFactSourceLabel(available.source)}',
      child: TokenCardSparklineView(
        state: state,
        keyPrefix: 'wallet-asset-sparkline',
      ),
    );
  }
}

/// The prototype's inline 收发记录 list, filtered to this one asset.
///
/// It reads the wallet activity the history page reads and shows the three
/// most recent rows for this asset, each with the direction icon the prototype
/// gives it. The full tape stays one tap away.
class _WalletAssetTransfers extends ConsumerWidget {
  const _WalletAssetTransfers({
    required this.walletId,
    required this.assetId,
    required this.onOpenHistory,
  });

  final String walletId;
  final String assetId;
  final VoidCallback onOpenHistory;

  static const int _rows = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletActivityControllerProvider(walletId));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        unawaited(
          ref.read(walletActivityControllerProvider(walletId).notifier).load(),
        );
      });
    }
    final page = state.value;
    if (page == null) {
      return LoopChainStateBlock(
        keyPrefix: 'wallet-asset-activity',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 2,
        emptyMessage: '这个资产还没有收发记录',
        onRetry: () => unawaited(
          ref
              .read(walletActivityControllerProvider(walletId).notifier)
              .reload(),
        ),
      );
    }
    final entries = page.items
        .where((entry) => entry.assetId == assetId)
        .take(_rows)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (entries.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('wallet-asset-activity-empty'),
            message: '这个资产还没有收发记录',
            reason: '索引器已经读到这个区间，但其中没有属于这个资产的转账。',
          )
        else
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in entries) walletActivityRow(entry),
            ],
          ),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('wallet-asset-history-entry'),
              leading: const LoopRowIcon(icon: 'clock'),
              title: '这个钱包的收发记录',
              subtitle: '来自链上索引的 ERC-20 转账',
              onTap: onOpenHistory,
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceBreakdown extends StatelessWidget {
  const _BalanceBreakdown({required this.row, required this.snapshot});

  final LoopAssetBalanceRow row;
  final LoopBalanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final balance = row.balance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSurfaceCard(
          key: const ValueKey<String>('wallet-asset-breakdown'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              switch (balance) {
                LoopBalanceUnavailable(reasonCode: final reasonCode) =>
                  LoopUnavailableCard(
                    key: const ValueKey<String>('wallet-asset-balance-missing'),
                    label: '链上余额读不到',
                    reasonCode: reasonCode,
                    margin: EdgeInsets.zero,
                  ),
                LoopBalanceAvailable() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Five separate meanings; the page never derives one from
                    // another.
                    LoopKeyValue(
                      label: '链上余额',
                      value: loopFormatDecimal(balance.displayBalance),
                    ),
                    LoopKeyValue(
                      label: '可用',
                      value: loopFormatDecimal(balance.availableBalance),
                    ),
                    LoopKeyValue(
                      label: '可动用（扣除手续费保留）',
                      value: loopFormatDecimal(balance.spendableBalance),
                    ),
                    LoopKeyValue(
                      label: '手续费保留',
                      value: loopFormatDecimal(balance.gasReserve),
                    ),
                  ],
                ),
              },
              switch (row.pending) {
                LoopPendingUnavailable(reasonCode: final reasonCode) =>
                  LoopUnavailableCard(
                    key: const ValueKey<String>('wallet-asset-pending-missing'),
                    label: '待确认金额不可用',
                    reasonCode: reasonCode,
                    margin: EdgeInsets.zero,
                  ),
                LoopPendingAvailable(value: final value) => LoopKeyValue(
                  label: '待确认入账（不计入可用）',
                  value: loopFormatDecimal(value),
                ),
              },
            ],
          ),
        ),
        _ValuationCard(valuation: row.valuation),
        _CrossCheckCard(crossCheck: row.crossCheck),
        WalletSnapshotFooter(snapshot: snapshot),
      ],
    );
  }
}

class _ValuationCard extends StatelessWidget {
  const _ValuationCard({required this.valuation});

  final LoopValuation valuation;

  @override
  Widget build(BuildContext context) {
    switch (valuation) {
      case LoopValuationUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('wallet-asset-valuation-unavailable'),
          label: '估值不可用',
          reasonCode: reasonCode,
        );
      case final LoopValuationAvailable valued:
        return LoopSurfaceCard(
          key: const ValueKey<String>('wallet-asset-valuation'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopKeyValue(label: '单价', value: loopFormatUsd(valued.priceUsd)),
              LoopKeyValue(label: '估值', value: loopFormatUsd(valued.valueUsd)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (valued.isProxied)
                    const LoopBadge(
                      '以 WBNB 计价',
                      key: ValueKey<String>('wallet-asset-proxied'),
                    ),
                  if (valued.quality == LoopFactQuality.stale)
                    const LoopBadge('数据可能过期', kind: LoopBadgeKind.down),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                <String>[
                  '来源 ${loopFactSourceLabel(valued.priceSource)}',
                  '观察于 ${loopRelativeTime(valued.fetchedAt)}',
                  if (valued.proxyAsset != null)
                    '代理资产 ${loopTruncatedAssetId(valued.proxyAsset!)}',
                ].join(' · '),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        );
    }
  }
}

class _CrossCheckCard extends StatelessWidget {
  const _CrossCheckCard({required this.crossCheck});

  final LoopBalanceCrossCheck crossCheck;

  @override
  Widget build(BuildContext context) {
    if (crossCheck.status == LoopCrossCheckStatus.matched) {
      return const SizedBox.shrink();
    }
    if (crossCheck.status == LoopCrossCheckStatus.unavailable) {
      return LoopUnavailableCard(
        key: const ValueKey<String>('wallet-asset-crosscheck-unavailable'),
        label: '与 Privy 的交叉核对不可用',
        // The server may state no reason. Substituting one here would invent a
        // cause it never reported, so the card falls back to a neutral line.
        reasonCode: crossCheck.reasonCode,
      );
    }
    return LoopNotice(
      key: const ValueKey<String>('wallet-asset-crosscheck'),
      icon: 'info',
      title: '数据源尚未对齐',
      body:
          '链上读数与 Privy 报告的数值不一致'
          '${crossCheck.blockDelta == null ? '' : '（相差 ${crossCheck.blockDelta} 个区块）'}。'
          '这里显示的始终是链上读数，交叉核对不会改变它。',
    );
  }
}

class _RegistryFactsCard extends StatelessWidget {
  const _RegistryFactsCard({
    required this.state,
    required this.assetId,
    this.rawValue,
  });

  final LoopChainResourceState<LoopChainAssetView> state;
  final String assetId;

  /// The exact integer minor-unit balance, kept for auditing.
  ///
  /// It used to sit in 「余额说明」 next to the four figures a reader compares,
  /// where `2990000000000000000` was nineteen digits nobody could read and
  /// nothing above it explained. The balance card now states the balance only
  /// in the asset's own unit; the integer the contract stores belongs with the
  /// other contract facts, grouped, and labelled with the precision that makes
  /// it mean something.
  final String? rawValue;

  @override
  Widget build(BuildContext context) {
    final view = state.value;
    if (view == null) {
      return LoopChainStateBlock(
        keyPrefix: 'wallet-asset-registry',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 2,
      );
    }
    final asset = view.asset;
    // A wallet asset is a registry asset, so precision is normally there. It
    // is still read as a fact that may be missing: an asset described by a
    // provider rather than by a chain call can carry none, and the integer
    // below is meaningless without it — so that row is dropped rather than
    // labelled with a precision nobody reported.
    final decimals = asset.decimals;
    return LoopSurfaceCard(
      key: const ValueKey<String>('wallet-asset-registry'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopKeyValue(label: '资产标识', value: loopTruncatedAssetId(assetId)),
          LoopKeyValue(
            label: '精度',
            value: decimals == null ? '数据不可得' : '$decimals',
          ),
          if (rawValue != null && decimals != null)
            LoopKeyValue(
              label: '最小单位余额（$decimals 位精度的整数）',
              value: loopGroupedFigure(rawValue!),
            ),
          LoopKeyValue(label: '登记状态', value: asset.status.label),
          if (asset.address != null)
            LoopKeyValue(
              label: '合约地址',
              value: loopTruncatedAddress(asset.address!),
            ),
          const SizedBox(height: 6),
          Text(
            <String>[
              '名称与精度只来自链上调用',
              if (asset.source.blockNumber != null)
                '区块高度 ${loopGroupedFigure(asset.source.blockNumber.toString())}',
              if (asset.source.verifiedAt != null)
                '校验于 ${loopRelativeTime(asset.source.verifiedAt!)}',
            ].join(' · '),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// receive
// ---------------------------------------------------------------------------

/// `receive` · the BSC deposit address and its EIP-681 QR code.
///
/// Only BNB Smart Chain is listed; other networks are simply absent rather
/// than rendered as unavailable placeholders.
class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key, this.walletId, this.onBack});

  final String? walletId;
  final VoidCallback? onBack;

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final walletId =
        widget.walletId ?? _watchActiveWalletId(ref, blocked: blocked);
    // A walletless account is not a page that is still loading.
    final noWalletYet = _noWalletYet(ref) && walletId == null;
    final state = walletId == null
        ? null
        : ref.watch(walletReceiveControllerProvider(walletId));
    if (walletId != null &&
        state != null &&
        state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(walletReceiveControllerProvider(walletId).notifier).load(),
          );
        }
      });
    }
    final networks = state?.value?.networks ?? const <LoopReceiveNetwork>[];
    final network = _selected < networks.length ? networks[_selected] : null;

    return LoopFocusPage(
      key: const ValueKey<String>('receive-screen'),
      archetype: LoopPageArchetype.action,
      title: '接收',
      onBack: widget.onBack,
      // The prototype's receive primary is a Chalk card; the app painted the
      // same dark folio every page wears (audit §A.4, item 2).
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('receive-folio'),
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.action,
        kicker: 'RECEIVE ADDRESS',
        heading: network == null
            ? '收款地址还没有读到'
            : '${network.name} · ${loopTruncatedAddress(network.address)}',
        caption: '二维码与完整地址绑定当前网络，复制前请再次核对。',
        stamp: network == null ? null : 'QR READY',
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('receive-capability-block'),
              title: '钱包读取当前不可用',
            )
          : null,
      body: <Widget>[
        if (noWalletYet)
          const WalletCreationBlock(keyPrefix: 'receive')
        else if (walletId == null || state == null || !state.isReady)
          LoopChainStateBlock(
            keyPrefix: 'receive',
            phase: state?.phase ?? LoopChainViewPhase.loading,
            failureKind: state?.failureKind,
            emptyMessage: '没有可用的接收地址',
            onRetry: walletId == null
                ? null
                : () => unawaited(
                    ref
                        .read(
                          walletReceiveControllerProvider(walletId).notifier,
                        )
                        .reload(),
                  ),
          )
        else if (network == null)
          const LoopEmpty(
            key: ValueKey<String>('receive-no-network'),
            icon: 'warn',
            message: '没有可接收的网络',
            reason: '暂时读不到可接收的网络。',
          )
        else ...<Widget>[
          _ReceiveQrCard(network: network),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('receive-copy-address'),
                label: '复制地址',
                primary: true,
                onPressed: () => unawaited(_copy(network.address, '地址已复制')),
              ),
              LoopButton(
                key: const ValueKey<String>('receive-copy-uri'),
                label: '复制付款链接',
                onPressed: () => unawaited(_copy(network.uri, '付款链接已复制')),
              ),
            ],
          ),
          // `.segs` under the buttons, as the prototype has it. Only the
          // networks the server published are listed: a chip for a network
          // LOOP does not publish would be an address that does not exist.
          const LoopLabel('网络'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: <Widget>[
                for (final (index, item) in networks.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(width: 7),
                  LoopSeg(
                    key: ValueKey<String>('receive-network-${item.chainId}'),
                    label: item.name,
                    selected: index == _selected,
                    onSelected: () => setState(() => _selected = index),
                  ),
                ],
              ],
            ),
          ),
          LoopNotice(
            key: const ValueKey<String>('receive-warning'),
            tone: LoopNoticeTone.warn,
            icon: 'warn',
            title: '只接收这一条网络的资产',
            body: loopReceiveWarningText(network.warningKey),
          ),
        ],
      ],
    );
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    LoopToast.show(context, message: message, kind: LoopToastKind.ok);
  }
}

class _ReceiveQrCard extends StatelessWidget {
  const _ReceiveQrCard({required this.network});

  final LoopReceiveNetwork network;

  @override
  Widget build(BuildContext context) {
    // The EIP-681 string is encoded on the device; the backend never sends an
    // image, and no dependency was added for it (decision 0057).
    final code = LoopQrCode.encode(network.uri);
    return LoopChalkCard(
      key: const ValueKey<String>('receive-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (code == null)
            const LoopUnavailableCard(
              key: ValueKey<String>('receive-qr-unavailable'),
              label: '二维码不可用',
              reasonCode: 'RECEIVE_QR_ENCODING_FAILED',
              margin: EdgeInsets.zero,
            )
          else
            Center(
              child: Semantics(
                key: const ValueKey<String>('receive-qr'),
                image: true,
                label: '${network.name} 收款二维码',
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(painter: _QrPainter(code: code)),
                ),
              ),
            ),
          const SizedBox(height: 16),
          SelectableText(
            network.address,
            key: const ValueKey<String>('receive-address-text'),
            textAlign: TextAlign.center,
            style: LoopMono.stamp.copyWith(color: LoopColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            network.uri,
            key: const ValueKey<String>('receive-uri-text'),
            textAlign: TextAlign.center,
            style: LoopMono.stamp.copyWith(color: LoopColors.inkText3),
          ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.code});

  final LoopQrCode code;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // A four-module quiet zone is required for a scannable symbol.
    const quietZone = 4;
    final modules = code.size + quietZone * 2;
    final scale = size.shortestSide / modules;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = LoopColors.chalk,
    );
    final paint = Paint()..color = LoopColors.ink;
    for (var y = 0; y < code.size; y += 1) {
      for (var x = 0; x < code.size; x += 1) {
        if (!code.isDark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (x + quietZone) * scale,
            (y + quietZone) * scale,
            scale,
            scale,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.code != code;
}

// ---------------------------------------------------------------------------
// wallets
// ---------------------------------------------------------------------------

/// `wallets` · the account's wallets and the active-wallet switch.
class WalletManagerScreen extends ConsumerStatefulWidget {
  const WalletManagerScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<WalletManagerScreen> createState() =>
      _WalletManagerScreenState();
}

class _WalletManagerScreenState extends ConsumerState<WalletManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final state = ref.watch(walletDirectoryControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(walletDirectoryControllerProvider.notifier).load(),
          );
        }
      });
    }
    final controller = ref.read(walletDirectoryControllerProvider.notifier);
    final directory = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('wallets-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的钱包',
      onBack: widget.onBack,
      actions: <Widget>[
        // The prototype's 添加. There is one creation path and it is the
        // wallet-less block's own button, so this control keeps its shape and
        // says what it would need.
        LoopSeg(
          key: const ValueKey<String>('wallets-add-action'),
          label: '添加',
          selected: false,
          onSelected: null,
          onBlocked: () => LoopToast.show(
            context,
            message: '再绑定一个钱包还没有开放。LOOP 为每个账号创建一个嵌入式钱包。',
            kind: LoopToastKind.warn,
          ),
        ),
      ],
      // The heading is the wallet in use, which is what this page is about.
      // 「1 个钱包」 counted the list instead of naming it, and 「我的钱包」
      // was the page's own title in the primary (audit item 1).
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('wallets-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET IDENTITY',
        heading: switch (directory?.active) {
          final LoopWalletAccount active => active.truncatedAddress,
          null when directory != null => '还没有选定当前钱包',
          null => '钱包清单还没有读到',
        },
        caption: '一个 LOOP ID 可以绑定多个钱包；地址是公开的链上事实，不是账号标识。',
        stamp: directory == null ? null : '${directory.wallets.length} WALLETS',
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('wallets-capability-block'),
              title: '钱包清单当前不可用',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || directory == null)
          LoopChainStateBlock(
            keyPrefix: 'wallets',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '钱包清单还没有读到',
            emptyReason: '这不是“没有钱包”，只是这次没有读到清单。',
            onRetry: () => unawaited(controller.reload()),
          )
        // The list was read and holds nothing. That is a different answer from
        // the block above, and it is the one this page can act on.
        else if (directory.isEmpty)
          const WalletCreationBlock(keyPrefix: 'wallets')
        else ...<Widget>[
          // A switch that never reached the server changed nothing: the
          // active wallet below is still the server's own answer. Offline is
          // therefore a pause, not a failed switch.
          if (state.failureKind == LoopChainFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('wallets-switch-offline'),
              pausedActions: const <String>['切换活跃钱包'],
              onRetry: () => unawaited(controller.reload()),
            )
          else if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('wallets-switch-error'),
              title: '活跃钱包没有切换',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: () => unawaited(controller.reload()),
            ),
          // The prototype puts the identity rule right under the primary,
          // where it explains the list that follows.
          const LoopNotice(
            key: ValueKey<String>('wallets-notice'),
            icon: 'id',
            title: '一个 LOOP ID，多个钱包',
            body: 'LOOP ID 是你的社交身份；钱包是可绑定、可更换的凭证。地址不是账号标识：每个请求指向的是一个不透明的钱包编号。',
          ),
          const LoopLabel('Privy 嵌入式钱包'),
          _WalletList(
            wallets: directory.embedded,
            activeWalletId: directory.activeWalletId,
            busy: state.busy,
            onActivate: (wallet) =>
                unawaited(_confirmActivate(controller, wallet)),
            emptyMessage: '没有嵌入式钱包',
          ),
          const LoopLabel('已连接的外部钱包'),
          _WalletList(
            wallets: directory.externals,
            activeWalletId: directory.activeWalletId,
            busy: state.busy,
            onActivate: (wallet) =>
                unawaited(_confirmActivate(controller, wallet)),
            emptyMessage: '没有已连接的外部钱包',
          ),
          LoopProvenanceFooter(
            key: const ValueKey<String>('wallets-source'),
            text: '来源 Privy · 观察于 ${loopRelativeTime(directory.observedAt)}',
          ),
          // The prototype closes this page on mining, because binding an old
          // wallet is how a holding starts counting.
          const LoopNotice(
            key: ValueKey<String>('wallets-mining-notice'),
            tone: LoopNoticeTone.warn,
            icon: 'mine',
            title: '所有绑定钱包的持仓都计入算力',
            body: '老钱包里的社区币不用搬家，绑定后就参与挖矿。已归档的钱包会保留，但不能成为活跃钱包。',
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _confirmActivate(
    WalletDirectoryController controller,
    LoopWalletAccount wallet,
  ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LoopSheet(
        title: '切换活跃钱包',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '钱包 ${wallet.truncatedAddress} 会成为余额、活动与收款页的当前钱包。',
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  label: '取消',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
                LoopButton(
                  key: const ValueKey<String>('wallets-activate-confirm'),
                  label: '切换',
                  primary: true,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!(confirmed ?? false)) return;
    final switched = await controller.setActive(wallet.walletId);
    if (!mounted) return;
    if (switched) {
      LoopToast.show(context, message: '已切换活跃钱包', kind: LoopToastKind.ok);
    }
  }
}

class _WalletList extends StatelessWidget {
  const _WalletList({
    required this.wallets,
    required this.activeWalletId,
    required this.busy,
    required this.onActivate,
    required this.emptyMessage,
  });

  final List<LoopWalletAccount> wallets;
  final String? activeWalletId;
  final bool busy;
  final void Function(LoopWalletAccount wallet) onActivate;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return LoopEmpty(
        key: ValueKey<String>('wallets-empty-$emptyMessage'),
        message: emptyMessage,
        reason: 'Privy 当前没有报告这一类钱包。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final wallet in wallets)
          LoopRecordRow(
            key: ValueKey<String>('wallet-row-${wallet.walletId}'),
            // `.row-ico` with the address's own first characters. The
            // prototype's wallet rows all carry one (audit item 7).
            leading: LoopRowIcon(
              monogram: wallet.address.length >= 4
                  ? wallet.address.substring(2, 4).toUpperCase()
                  : '··',
              tone: wallet.walletId == activeWalletId
                  ? LoopRowIconTone.accent
                  : LoopRowIconTone.neutral,
            ),
            // `.row[style="background:var(--mint-soft)"]`: the prototype tints
            // the wallet in use rather than leaving the badge to carry it.
            tinted: wallet.walletId == activeWalletId,
            title: wallet.kind == LoopWalletKind.embedded ? '嵌入式钱包' : '外部钱包',
            // Truncation is a client-side display concern; the model keeps the
            // full address and the request only ever carries `walletId`.
            subtitle:
                '${wallet.truncatedAddress} · '
                '${wallet.status == LoopWalletStatus.archived ? '已归档' : '可用'}',
            trailingBadge: wallet.walletId == activeWalletId
                ? const LoopBadge('使用中', kind: LoopBadgeKind.up)
                : wallet.status == LoopWalletStatus.archived
                ? const LoopBadge('已归档')
                : null,
            onTap:
                busy ||
                    wallet.walletId == activeWalletId ||
                    wallet.status == LoopWalletStatus.archived
                ? null
                : () => onActivate(wallet),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// tx-history
// ---------------------------------------------------------------------------

/// `tx-history` · indexed ERC-20 transfers for one wallet.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key, this.walletId, this.onBack});

  final String? walletId;
  final VoidCallback? onBack;

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final walletId =
        widget.walletId ?? _watchActiveWalletId(ref, blocked: blocked);
    // A walletless account is not a page that is still loading.
    final noWalletYet = _noWalletYet(ref) && walletId == null;
    final state = walletId == null
        ? null
        : ref.watch(walletActivityControllerProvider(walletId));
    if (walletId != null &&
        state != null &&
        state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(walletActivityControllerProvider(walletId).notifier)
                .load(),
          );
        }
      });
    }
    final page = state?.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('tx-history-screen'),
      onRefresh: walletId == null
          ? null
          : () => ref
                .read(walletActivityControllerProvider(walletId).notifier)
                .reload(),
      updating: state?.refreshing ?? false,
      archetype: LoopPageArchetype.record,
      title: '交易历史',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('tx-history-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET ACTIVITY',
        // The figure counts what the segment below actually lists. A tape
        // filtered to 发出 and showing nothing used to keep 「1 笔」 in the
        // hero, which reads as a row the list lost.
        heading: page == null ? '记录还没有读到' : '${_segmentCount(page)} 笔',
        caption: '发送、接收、兑换与跨链结果按时间形成统一钱包记录。',
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('tx-history-capability-block'),
              title: '钱包活动当前不可用',
            )
          : null,
      sections: <Widget>[
        if (noWalletYet)
          const WalletCreationBlock(keyPrefix: 'tx-history')
        else if (walletId == null || state == null || page == null)
          LoopChainStateBlock(
            keyPrefix: 'tx-history',
            phase: state?.phase ?? LoopChainViewPhase.loading,
            failureKind: state?.failureKind,
            emptyMessage: '还没有链上活动',
            emptyReason: '索引器已经读到这个区间，但其中没有属于这个钱包的转账。',
            onRetry: walletId == null
                ? null
                : () => unawaited(
                    ref
                        .read(
                          walletActivityControllerProvider(walletId).notifier,
                        )
                        .reload(),
                  ),
          )
        else ...<Widget>[
          _ActivitySegments(
            selected: _segment,
            onSelected: (index) => setState(() => _segment = index),
          ),
          ..._segmentBody(page, walletId),
          LoopProvenanceFooter(
            key: const ValueKey<String>('tx-history-freshness'),
            text: <String>[
              '索引高度 '
                  '${loopGroupedFigure(page.freshness.indexerBlockNumber.toString())}',
              if (page.freshness.lagBlocks != null)
                '数据落后 '
                    '${loopGroupedFigure(page.freshness.lagBlocks.toString())} 块',
              '观察于 ${loopRelativeTime(page.freshness.observedAt)}',
            ].join(' · '),
          ),
          // The pages already read stay on screen. A next page that never
          // reached the server is a pause on "load more", not a broken tape.
          if (state.failureKind == LoopChainFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('tx-history-page-offline'),
              pausedActions: const <String>['加载更多'],
              onRetry: () => unawaited(
                ref
                    .read(walletActivityControllerProvider(walletId).notifier)
                    .loadMore(),
              ),
            )
          else if (state.failureKind != null)
            LoopErrorState(
              key: const ValueKey<String>('tx-history-page-error'),
              title: '这一页没有加载完',
              reason: loopChainFailureReason(state.failureKind),
              onRetry: () => unawaited(
                ref
                    .read(walletActivityControllerProvider(walletId).notifier)
                    .loadMore(),
              ),
            )
          else if (page.nextCursor != null)
            LoopButton(
              key: const ValueKey<String>('tx-history-load-more'),
              label: '加载更多',
              block: true,
              onPressed: () => unawaited(
                ref
                    .read(walletActivityControllerProvider(walletId).notifier)
                    .loadMore(),
              ),
            ),
        ],
      ],
    );
  }

  /// How many rows the selected segment lists. The two segments that carry an
  /// unavailable fact rather than a list count the whole tape: their own card
  /// says why they have no rows, and a zero there would read as an answer.
  int _segmentCount(LoopWalletActivityPage page) => switch (_segment) {
    1 =>
      page.items
          .where((entry) => entry.direction == LoopTransferDirection.incoming)
          .length,
    2 =>
      page.items
          .where((entry) => entry.direction == LoopTransferDirection.outgoing)
          .length,
    _ => page.items.length,
  };

  List<Widget> _segmentBody(LoopWalletActivityPage page, String walletId) {
    switch (_segment) {
      case 1:
        return <Widget>[
          _activityList(
            page.items
                .where(
                  (entry) => entry.direction == LoopTransferDirection.incoming,
                )
                .toList(growable: false),
          ),
        ];
      case 2:
        return <Widget>[
          _activityList(
            page.items
                .where(
                  (entry) => entry.direction == LoopTransferDirection.outgoing,
                )
                .toList(growable: false),
          ),
        ];
      case 3:
        return <Widget>[
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('tx-history-native-unavailable'),
            label: '原生 BNB 转账不可用',
            fact: page.nativeTransfers,
          ),
        ];
      case 4:
        return <Widget>[
          LoopUnavailableCard.fact(
            key: const ValueKey<String>('tx-history-cross-chain-unavailable'),
            label: '跨链与挖矿领取记录不可用',
            fact: page.crossChain,
          ),
        ];
      default:
        return <Widget>[_activityList(page.items)];
    }
  }

  Widget _activityList(List<LoopWalletActivityEntry> entries) {
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('tx-history-empty'),
        message: '这一段没有记录',
        reason: '索引器已经读到这个区间，但其中没有符合的转账。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final entry in entries) walletActivityRow(entry),
      ],
    );
  }
}

class _ActivitySegments extends StatelessWidget {
  const _ActivitySegments({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['全部', '收到', '发出', '原生转账', '跨链 / 挖矿'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final (index, label) in labels.indexed) ...<Widget>[
              LoopSeg(
                key: ValueKey<String>('tx-history-seg-$index'),
                label: label,
                selected: index == selected,
                onSelected: () => onSelected(index),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// networks
// ---------------------------------------------------------------------------

/// `networks` · BSC only, with per-endpoint health.
///
/// The backend never sends an RPC URL: each endpoint is an opaque reference.
/// A chain-id mismatch makes the whole page unusable.
class NetworksScreen extends ConsumerStatefulWidget {
  const NetworksScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends ConsumerState<NetworksScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bscRead),
    );
    final mode = ref.watch(chainGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(chainStatusControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(chainStatusControllerProvider.notifier).load());
        }
      });
    }
    final status = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('networks-screen'),
      onRefresh: ref.read(chainStatusControllerProvider.notifier).reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '网络与 RPC',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('networks-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'NETWORK HEALTH',
        // Lime is the success colour, and 「1 / 4 正常」 in Lime read as good
        // news over four endpoints of which two were unreachable. The figure
        // stays; the colour follows the majority of what was measured.
        headingTone: status == null || status.rpc.endpoints.isEmpty
            ? LoopFolioHeadingTone.neutral
            : status.rpc.healthyCount * 2 >= status.rpc.endpoints.length
            ? LoopFolioHeadingTone.accent
            : LoopFolioHeadingTone.neutral,
        heading: status == null
            ? '网络与 RPC'
            : '${status.rpc.healthyCount} / ${status.rpc.endpoints.length} 正常',
        caption: status?.launchChain == null
            ? '只有 BNB Smart Chain 一条网络；端点只显示主机名，永远不下发完整 RPC 地址。'
            : '主网 BNB Smart Chain 加上 LOOP 发布的 Launch 链；'
                  '端点只显示主机名，永远不下发完整 RPC 地址。',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('networks-capability-block'),
              title: '链上读取当前不可用',
              capability: capability,
              fallbackReasonCode: 'BSC_RPC_NOT_CONFIGURED',
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || status == null)
          LoopChainStateBlock(
            keyPrefix: 'networks',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有可展示的网络',
            onRetry: () => unawaited(
              ref.read(chainStatusControllerProvider.notifier).reload(),
            ),
          )
        else if (status.chainIdMismatched)
          const LoopUnavailableCard(
            key: ValueKey<String>('networks-chain-mismatch'),
            label: '端点返回的不是 BNB Smart Chain',
            reasonCode: 'BSC_CHAIN_ID_MISMATCH',
          )
        else ...<Widget>[
          const LoopLabel('已启用'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('networks-chain-row'),
                // The prototype's chain rows all carry the chain's own logo;
                // the app's row had no leading column at all (audit item 7).
                leading: const LoopNetworkLogo(network: 'bsc', size: 44),
                title: status.chain.name,
                // 延迟 is what the prototype's row says, and it is the one
                // fact a reader can act on. The chain id, the confirmation
                // depth and the reorg window are operator facts; they moved
                // into the disclosure below with the endpoints.
                subtitle: _chainLatencyText(status),
                subtitleMaxLines: 2,
                trailing: status.rpc.head == null
                    ? null
                    : loopGroupedFigure(
                        status.rpc.head!.blockNumber.toString(),
                      ),
                trailingBadge: LoopBadge(
                  status.rpc.available ? '正常' : '异常',
                  kind: status.rpc.available
                      ? LoopBadgeKind.up
                      : LoopBadgeKind.down,
                ),
              ),
            ],
          ),
          // Decision 0038: a second row exists only when the backend published
          // a Launch chain slot of its own. While the slot equals the primary
          // chain the key is absent and this page shows nothing extra — not an
          // unavailable placeholder. Custom RPC and testnets stay unavailable.
          if (status.launchChain != null)
            _LaunchChainRow(launchChain: status.launchChain!),
          // The prototype's 设置 group: two rows, not a whole-width card.
          const LoopLabel('设置'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('networks-custom-rpc'),
                title: '自定义 RPC',
                subtitle: loopReasonCodeText('WALLET_CUSTOM_RPC_DEFERRED'),
                subtitleMaxLines: 2,
                trailingBadge: const LoopBadge('不可用'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('networks-testnet'),
                title: '测试网',
                // Decision 0038: the Launch slot is the only testnet the
                // product has, and it is published by the server, never
                // toggled here.
                subtitle: status.launchChain == null
                    ? '没有已发布的测试网'
                    : '${status.launchChain!.name} · 只有 Launch 使用',
                trailingBadge: LoopBadge(
                  status.launchChain == null ? '已关闭' : '已发布',
                  kind: status.launchChain == null
                      ? LoopBadgeKind.mute
                      : LoopBadgeKind.launch,
                ),
              ),
            ],
          ),
          // The endpoint list, the indexer lanes, the chain id, the reorg
          // window and the registry counts are operator facts. They filled
          // the page above the chain rows (audit item 5); they are still all
          // here, one tap away.
          LoopDisclosure(
            key: const ValueKey<String>('networks-operator-disclosure'),
            summary: '端点、索引器与链参数',
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LoopProvenanceFooter(
                    key: const ValueKey<String>('networks-chain-parameters'),
                    text:
                        '${status.chain.chainId} · '
                        '${loopGroupedFigure(status.chain.confirmations.toString())} 确认 · '
                        '重组跟踪 '
                        '${loopGroupedFigure(status.chain.reorgDepthBlocks.toString())} 块',
                  ),
                  const LoopLabel('RPC 端点', tight: true),
                  if (status.rpc.endpoints.isEmpty)
                    LoopUnavailableCard(
                      key: const ValueKey<String>('networks-no-endpoints'),
                      label: '没有已配置的 RPC 端点',
                      reasonCode:
                          status.rpc.reasonCode ?? 'BSC_RPC_NOT_CONFIGURED',
                    )
                  else
                    LoopRecordGroup(
                      rows: <LoopRecordRow>[
                        for (
                          var index = 0;
                          index < status.rpc.endpoints.length;
                          index += 1
                        )
                          _endpointRow(status.rpc.endpoints[index], index),
                      ],
                    ),
                  const LoopLabel('索引器', tight: true),
                  LoopRecordGroup(
                    rows: <LoopRecordRow>[
                      for (final lane in status.indexer)
                        LoopRecordRow(
                          key: ValueKey<String>('lane-${lane.lane.wireName}'),
                          title: loopIndexerLaneLabel(lane.lane),
                          subtitle: lane.available
                              ? <String>[
                                  if (lane.lastBlockNumber != null)
                                    '高度 '
                                        '${loopGroupedFigure(lane.lastBlockNumber.toString())}',
                                  if (lane.lagBlocks != null)
                                    '落后 '
                                        '${loopGroupedFigure(lane.lagBlocks.toString())} 块',
                                  if (lane.reorgCount != null)
                                    '重组 ${lane.reorgCount} 次',
                                  if (lane.updatedAt != null)
                                    loopRelativeTime(lane.updatedAt!),
                                ].join(' · ')
                              : loopReasonCodeText(lane.reasonCode),
                          trailingBadge: LoopBadge(
                            lane.available ? '运行中' : '未运行',
                            kind: lane.available
                                ? LoopBadgeKind.up
                                : LoopBadgeKind.down,
                          ),
                        ),
                    ],
                  ),
                  LoopProvenanceFooter(
                    key: const ValueKey<String>('networks-registry'),
                    text:
                        '可读资产 ${status.registry.readableAssetCount} 个 · '
                        '已登记池 ${status.registry.registeredPoolCount} 个',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// 延迟 for the chain row, taken from the endpoints that answered.
///
/// It is the lowest latency any endpoint reported, because that is the one a
/// read actually went through. Endpoints that reported none are not counted as
/// zero, and a chain with no measured endpoint says so.
String _chainLatencyText(LoopChainStatus status) {
  int? best;
  for (final endpoint in status.rpc.endpoints) {
    final latency = endpoint.latencyMs;
    if (latency == null) continue;
    if (best == null || latency < best) best = latency;
  }
  final head = status.rpc.head;
  return <String>[
    if (best != null) '延迟 ${best}ms' else '延迟未知',
    if (head != null) '观察于 ${loopRelativeTime(head.observedAt)}',
  ].join(' · ');
}

/// The `networks` row for the Launch chain slot (decision 0038).
///
/// It publishes no endpoint reference and no URL: testnet endpoint health is
/// not part of the contract, so the row states the slot's own verification,
/// its confirmation depth and the server's reason code instead.
/// One RPC endpoint row.
///
/// The opaque reference was the row's title, so the page headed its endpoints
/// 「rpc-956a0d5f88ea」, which no reader can match against anything; numbering
/// them said no more. The server now publishes the endpoint's host name for
/// display (decision 0049) and that is the title, with the position it was
/// published in kept as a caption so two hosts that read alike stay apart. The
/// reference stays as the widget key, where only a test reads it.
LoopRecordRow _endpointRow(LoopRpcEndpointHealth endpoint, int index) =>
    LoopRecordRow(
      key: ValueKey<String>('rpc-${endpoint.endpointRef}'),
      title: endpoint.label,
      subtitle: <String>[
        '端点 ${index + 1}',
        if (endpoint.latencyMs != null)
          '延迟 ${endpoint.latencyMs}ms'
        else
          '延迟未知',
        if (endpoint.blockLagBlocks != null)
          '落后 ${loopGroupedFigure(endpoint.blockLagBlocks.toString())} 块',
        '校验${endpoint.chainVerification.label}',
        loopRelativeTime(endpoint.observedAt),
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: endpoint.blockNumber == null
          ? null
          : loopGroupedFigure(endpoint.blockNumber.toString()),
      trailingBadge: LoopBadge(switch (endpoint.status) {
        LoopEndpointStatus.healthy => '正常',
        LoopEndpointStatus.degraded => '异常',
        LoopEndpointStatus.unreachable => '不可达',
      }, kind: endpoint.isAbnormal ? LoopBadgeKind.down : LoopBadgeKind.up),
    );

class _LaunchChainRow extends StatelessWidget {
  const _LaunchChainRow({required this.launchChain});

  final LoopLaunchChainStatus launchChain;

  @override
  Widget build(BuildContext context) {
    final reasonCode = launchChain.reasonCode;
    // "The backend chose the testnet but configured no endpoint" is not an
    // abnormal chain — it is a slot that was never wired up, and there is no
    // height or health to report for it. It renders as the unavailable card
    // the rest of the page uses for a missing source.
    if (reasonCode == 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED') {
      return LoopUnavailableCard(
        key: const ValueKey<String>('networks-launch-chain-unavailable'),
        label: '${launchChain.name}（Launch）未配置 RPC',
        reasonCode: reasonCode!,
      );
    }
    final head = launchChain.head;
    // Three states, not two: verified is 正常, a verification that has not
    // finished yet is 待校验 — neither a fault nor a proof — and only an
    // unreachable or mismatched endpoint is 异常.
    final pending = reasonCode == 'LAUNCH_CHAIN_VERIFICATION_PENDING';
    final (String badge, LoopBadgeKind kind) = switch (launchChain.isHealthy) {
      true => ('正常', LoopBadgeKind.up),
      false when pending => ('待校验', LoopBadgeKind.mute),
      false => ('异常', LoopBadgeKind.down),
    };
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('networks-launch-chain-row'),
          title: '${launchChain.name}（Launch）',
          subtitle: reasonCode == null
              ? '${launchChain.chainId} · '
                    '${loopGroupedFigure(launchChain.confirmations.toString())} 确认 · '
                    '重组跟踪 '
                    '${loopGroupedFigure(launchChain.reorgDepthBlocks.toString())} 块'
              : loopReasonCodeText(reasonCode),
          trailing: head == null
              ? null
              : loopGroupedFigure(head.blockNumber.toString()),
          trailingBadge: LoopBadge(badge, kind: kind),
        ),
      ],
    );
  }
}
