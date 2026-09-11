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
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
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
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('wallet-receive-action'),
                label: '接收',
                primary: true,
                onPressed: () => _open(WalletRoute.receive(walletId)),
              ),
              LoopButton(
                key: const ValueKey<String>('wallet-networks-action'),
                label: '网络与 RPC',
                onPressed: () => _open('/wallet/networks'),
              ),
            ],
          ),
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
                    onTap: () =>
                        _open(MarketAssetRoute.walletAsset(row.assetId)),
                  ),
              ],
            ),
          WalletSnapshotFooter(snapshot: balances.snapshot),
          LoopProvenanceFooter(
            key: const ValueKey<String>('wallet-gas-reserve'),
            text:
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
          const LoopLabel('资金动作'),
          // The prototype's Pay / 兑换 / 发送 / 跨链 entries stay in place and
          // each opens its own manifest slug. None of them can sign yet: every
          // destination owns its unavailable state, so the entry point is
          // honest without this page having to speak for four other pages.
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-pay-entry'),
                title: 'Pay',
                subtitle: '扫码支付尚未开放',
                onTap: () => _open('/pay'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-swap-entry'),
                title: '兑换',
                subtitle: '通过 Privy 报价并在统一签名出口确认',
                onTap: () => _open('/wallet/swap'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-send-entry'),
                title: '发送',
                subtitle: '交易由 LOOP 构造，在本机签名并广播',
                onTap: () => _open('/wallet/send'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-bridge-entry'),
                title: '跨链',
                subtitle: '跨链尚未开放',
                onTap: () => _open('/wallet/bridge'),
              ),
            ],
          ),
          const LoopLabel('安全与连接'),
          const LoopUnavailableCard(
            key: ValueKey<String>('wallet-security-unavailable'),
            label: '安全中心 / DApp 浏览器状态不可用',
            reasonCode: 'WALLET_SECURITY_FACTS_DEFERRED',
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-approvals-entry'),
                title: '授权盘点',
                subtitle: '当场重读的 allowance()，回收会发送 approve(spender, 0)',
                onTap: () => _open('/wallet/approvals'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-security-entry'),
                title: '安全中心',
                subtitle: '设备、会话与账户保护',
                onTap: () => _open('/profile/security'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-dapp-entry'),
                title: 'DApp 核对',
                subtitle: '本地核对网址；连接与签名尚未开放',
                onTap: () => _open('/wallet/dapp'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-networks-entry'),
                title: '网络与 RPC',
                // The page lists whatever the server published: the primary
                // chain always, and the Launch slot when it differs from it.
                subtitle: '已启用的网络与 RPC 端点健康',
                onTap: () => _open('/wallet/networks'),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('wallet-wallets-entry'),
                title: '我的钱包',
                subtitle: '切换当前使用中的钱包',
                onTap: () => _open('/wallet/manage'),
              ),
            ],
          ),
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
    final heading = switch (netWorth) {
      LoopNetWorthValued(valueUsd: final value) => loopFormatUsd(value),
      LoopNetWorthUnavailable() => '净值不可用',
      null => '钱包',
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
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('networth-folio'),
        archetype: LoopFolioArchetype.listing,
        kicker: 'WALLET OVERVIEW',
        heading: switch (netWorth) {
          LoopNetWorthValued(valueUsd: final value) => loopFormatUsd(value),
          LoopNetWorthUnavailable() => '净值不可用',
          null => '净值明细',
        },
        caption: '这是展示信息，不是可用余额。24h 涨跌与走势图暂时读不到。',
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
          WalletNetWorthCard(netWorth: balances!.netWorth),
          const LoopLabel('按资产'),
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
          const LoopLabel('走势'),
          const LoopUnavailableCard(
            key: ValueKey<String>('networth-trend-unavailable'),
            label: '24h 涨跌与净值走势不可用',
            reasonCode: 'WALLET_NETWORTH_TREND_DEFERRED',
          ),
          const LoopNotice(
            key: ValueKey<String>('networth-notice'),
            title: '净值不是余额',
            body: '净值是按行情价折算的展示信息。可动用余额在钱包页按资产分别列出，两者不能互相推导。',
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

    return LoopDashboardPage(
      key: ValueKey<String>('wallet-asset-$assetId'),
      onRefresh: walletId == null
          ? null
          : () => ref
                .read(walletBalancesControllerProvider(walletId).notifier)
                .reload(),
      updating: balancesState?.refreshing ?? false,
      archetype: LoopPageArchetype.record,
      title: asset?.symbol ?? row?.symbol ?? '钱包资产',
      kicker: asset?.name,
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('wallet-asset-market-action'),
          icon: 'chart',
          label: '查看行情',
          onPressed: () => _open(MarketAssetRoute.token(assetId)),
        ),
      ],
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('wallet-asset-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET ASSET',
        heading: switch (row?.balance) {
          LoopBalanceAvailable(displayBalance: final value) =>
            loopFormatDecimal(value),
          LoopBalanceUnavailable() => '余额读不到',
          null => asset?.symbol ?? '钱包资产',
        },
        caption: switch (row?.valuation) {
          LoopValuationAvailable(valueUsd: final value) =>
            '估值 ${loopFormatUsd(value)}',
          LoopValuationUnavailable(reasonCode: final reasonCode) =>
            loopReasonCodeText(reasonCode),
          null => '余额尚未读取成功。',
        },
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
          const LoopLabel('余额说明'),
          _BalanceBreakdown(row: row, snapshot: balancesState.value!.snapshot),
          const LoopLabel('资产事实'),
          _RegistryFactsCard(state: registry, assetId: assetId),
          const LoopLabel('挖矿贡献'),
          const LoopUnavailableCard(
            key: ValueKey<String>('wallet-asset-mining-unavailable'),
            label: '挖矿贡献不可用',
            reasonCode: 'MINING_RUNTIME_DEFERRED',
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-asset-history-entry'),
                title: '这个钱包的收发记录',
                subtitle: '来自链上索引的 ERC-20 转账',
                onTap: () => _open(WalletRoute.history(walletId)),
              ),
            ],
          ),
        ],
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
                    LoopKeyValue(label: '最小单位', value: balance.rawValue),
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
  const _RegistryFactsCard({required this.state, required this.assetId});

  final LoopChainResourceState<LoopChainAssetView> state;
  final String assetId;

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
    return LoopSurfaceCard(
      key: const ValueKey<String>('wallet-asset-registry'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopKeyValue(label: '资产标识', value: loopTruncatedAssetId(assetId)),
          LoopKeyValue(label: '精度', value: '${asset.decimals}'),
          LoopKeyValue(label: '登记状态', value: asset.status.wireName),
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
                '区块高度 ${asset.source.blockNumber}',
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
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('receive-folio'),
        archetype: LoopFolioArchetype.action,
        kicker: 'RECEIVE ADDRESS',
        heading: network == null
            ? '接收地址'
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
          if (networks.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: <Widget>[
                  for (final (index, item) in networks.indexed) ...<Widget>[
                    LoopSeg(
                      key: ValueKey<String>('receive-network-${item.chainId}'),
                      label: item.name,
                      selected: index == _selected,
                      onSelected: () => setState(() => _selected = index),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
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
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('wallets-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: 'WALLET IDENTITY',
        heading: directory == null ? '我的钱包' : '${directory.wallets.length} 个钱包',
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
          const LoopNotice(
            key: ValueKey<String>('wallets-notice'),
            title: '地址不是账号标识',
            body: '所有请求都用不透明的 walletId 指向钱包。已归档的钱包会保留，但不能成为活跃钱包。',
          ),
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
        heading: page == null ? '交易历史' : '${page.items.length} 笔',
        caption: '只包含已登记资产的 ERC-20 转账，每条带交易哈希、区块与确认数。',
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
              '索引高度 ${page.freshness.indexerBlockNumber}',
              if (page.freshness.lagBlocks != null)
                '数据落后 ${page.freshness.lagBlocks} 块',
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
        for (final entry in entries)
          LoopRecordRow(
            key: ValueKey<String>('tx-entry-${entry.entryId}'),
            title:
                '${switch (entry.direction) {
                  LoopTransferDirection.incoming => '收到',
                  LoopTransferDirection.outgoing => '发出',
                  LoopTransferDirection.self => '自转',
                }} ${entry.symbol}',
            subtitle: <String>[
              loopConfirmationLabel(entry.status),
              if (entry.confirmations != null) '${entry.confirmations} 确认',
              '区块 ${entry.blockNumber}',
              '对方 ${loopTruncatedAddress(entry.counterpartyAddress)}',
              loopRelativeTime(entry.observedAt),
            ].join(' · '),
            trailing: loopFormatDecimal(entry.displayValue),
            trailingCaptionUp:
                entry.direction == LoopTransferDirection.incoming,
            trailingCaption: loopTruncatedAddress(entry.transactionHash),
            trailingBadge: entry.status == LoopConfirmationStatus.reorged
                ? const LoopBadge('已回滚', kind: LoopBadgeKind.down)
                : null,
          ),
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
        heading: status == null
            ? '网络与 RPC'
            : '${status.rpc.healthyCount} / ${status.rpc.endpoints.length} 正常',
        caption: status?.launchChain == null
            ? '只有 BNB Smart Chain 一条网络；端点以不可逆引用显示，永远不下发 RPC 地址。'
            : '主网 BNB Smart Chain 加上 LOOP 发布的 Launch 链；'
                  '端点以不可逆引用显示，永远不下发 RPC 地址。',
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
                title: status.chain.name,
                subtitle:
                    '${status.chain.chainId} · '
                    '${status.chain.confirmations} 确认 · '
                    '重组跟踪 ${status.chain.reorgDepthBlocks} 块',
                trailing: status.rpc.head == null
                    ? null
                    : '${status.rpc.head!.blockNumber}',
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
          const LoopLabel('RPC 端点'),
          if (status.rpc.endpoints.isEmpty)
            LoopUnavailableCard(
              key: const ValueKey<String>('networks-no-endpoints'),
              label: '没有已配置的 RPC 端点',
              reasonCode: status.rpc.reasonCode ?? 'BSC_RPC_NOT_CONFIGURED',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final endpoint in status.rpc.endpoints)
                  LoopRecordRow(
                    key: ValueKey<String>('rpc-${endpoint.endpointRef}'),
                    title: endpoint.endpointRef,
                    subtitle: <String>[
                      if (endpoint.latencyMs != null)
                        '延迟 ${endpoint.latencyMs}ms'
                      else
                        '延迟未知',
                      if (endpoint.blockLagBlocks != null)
                        '落后 ${endpoint.blockLagBlocks} 块',
                      '校验 ${endpoint.chainVerification.wireName}',
                      loopRelativeTime(endpoint.observedAt),
                    ].join(' · '),
                    trailing: endpoint.blockNumber == null
                        ? null
                        : '${endpoint.blockNumber}',
                    trailingBadge: LoopBadge(
                      switch (endpoint.status) {
                        LoopEndpointStatus.healthy => '正常',
                        LoopEndpointStatus.degraded => '异常',
                        LoopEndpointStatus.unreachable => '不可达',
                      },
                      kind: endpoint.isAbnormal
                          ? LoopBadgeKind.down
                          : LoopBadgeKind.up,
                    ),
                  ),
              ],
            ),
          const LoopLabel('索引器'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final lane in status.indexer)
                LoopRecordRow(
                  key: ValueKey<String>('lane-${lane.lane.wireName}'),
                  title: loopIndexerLaneLabel(lane.lane),
                  subtitle: lane.available
                      ? <String>[
                          if (lane.lastBlockNumber != null)
                            '高度 ${lane.lastBlockNumber}',
                          if (lane.lagBlocks != null) '落后 ${lane.lagBlocks} 块',
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
          const LoopLabel('设置'),
          const LoopUnavailableCard(
            key: ValueKey<String>('networks-custom-rpc'),
            label: '自定义 RPC 与自行添加网络不可用',
            reasonCode: 'WALLET_CUSTOM_RPC_DEFERRED',
          ),
        ],
      ],
    );
  }
}

/// The `networks` row for the Launch chain slot (decision 0038).
///
/// It publishes no endpoint reference and no URL: testnet endpoint health is
/// not part of the contract, so the row states the slot's own verification,
/// its confirmation depth and the server's reason code instead.
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
                    '${launchChain.confirmations} 确认 · '
                    '重组跟踪 ${launchChain.reorgDepthBlocks} 块'
              : loopReasonCodeText(reasonCode),
          trailing: head == null ? null : '${head.blockNumber}',
          trailingBadge: LoopBadge(badge, kind: kind),
        ),
      ],
    );
  }
}
