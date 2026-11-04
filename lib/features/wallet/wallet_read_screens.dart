import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/loop_backend_identity.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_bell.dart';
import 'package:loop_mobile/features/profile/me_attention.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_activity_export.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/external_wallet_intro_store.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart'; // S136
import 'package:loop_mobile/features/wallet/wallet_holdings.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/sharing/system_image_share.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_profile_sections.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';

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
///
/// Decision 0098: the two reads are sent together. The balances read is for
/// the wallet already on screen and needs nothing from the new directory; if
/// the directory names a different active wallet, the page rebuilds on it and
/// that wallet's own block reads its balances.
Future<void> _refreshWallet(WidgetRef ref, String? walletId) async {
  final directory = ref.read(walletDirectoryControllerProvider.notifier);
  final balances = walletId == null
      ? null
      : ref.read(walletBalancesControllerProvider(walletId).notifier);
  // Decision 0188: the net-worth history the header already asked for is
  // read again with the rest; a window nobody opened is not.
  final histories = walletId == null
      ? const <WalletNetWorthHistoryController>[]
      : <WalletNetWorthHistoryController>[
          for (final range in LoopNetWorthRange.values)
            if (ref.exists(
              walletNetWorthHistoryControllerProvider((
                walletId: walletId,
                range: range,
              )),
            ))
              ref.read(
                walletNetWorthHistoryControllerProvider((
                  walletId: walletId,
                  range: range,
                )).notifier,
              ),
        ];
  // S88d: the mining figures on this page are retained between visits, so a
  // pull is the one place they are read again on the spot.
  await Future.wait<void>(<Future<void>>[
    directory.reload(),
    if (balances != null) balances.reload(),
    for (final history in histories) history.reload(),
    if (ref.exists(miningSummaryControllerProvider))
      ref.read(miningSummaryControllerProvider.notifier).reload(),
  ]);
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

/// `wallet` · the 我的 tab (S343 · decision 0271: 钱包 and 我 in one page).
///
/// S349 (decision 0271 Amendment): the structure of another account's page
/// (decision 0218). From the top: the person (identity card, 分享名片), the
/// stranger requests while any wait, 总资产 with 钱包管理 beside the address
/// and five equal keys (接收 / 发送 / 兑换 / 扫码 / DApp), then 持仓 / 交易 /
/// 社区. 通知 and 设置 sit in the bar; the account rows are gone.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key, this.onNavigate});

  final void Function(String location)? onNavigate;

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with _WalletActivityTape<WalletScreen> {
  /// Whether this page drew the balances as a skeleton at some point. Only
  /// then does the list fade in when it lands; a list that was already on
  /// screen — retained, restored or refreshed — never blinks.
  bool _sawBalancesSkeleton = false;

  /// The asset area's tab (S259 · decision 0217): 代币 or NFT.
  int _assetTab = WalletAssetTabs.tokens;

  /// 持仓 / 交易 / 社区 (S349).
  LoopProfileSection _section = LoopProfileSection.holdings;

  @override
  void openFromTape(String location) => _open(location);

  /// What a closed key answers with: the server's own sentence, on the tap.
  void _blocked(String reason) {
    LoopToast.show(context, message: reason, kind: LoopToastKind.warn);
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    // A tab (情报 · 算力) is switched to, never pushed over 我的.
    if (LoopRouteManifest.isTabPath(Uri.parse(location).path)) {
      context.go(location);
      return;
    }
    context.push(location);
  }

  /// A profile destination id ([profileDestinationPath]).
  void _openProfile(String id) => _open(profileDestinationPath(id));

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(walletReadGatewayProvider).mode;
    final walletReadGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.walletRead),
    );
    final bscGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.bscRead),
    );
    final preview = mode == LoopChainGatewayMode.preview;
    // The wallet module itself is shut: nothing on this page can be read, and
    // the page says so as a whole.
    final blocked = !preview && !walletReadGate.isAvailable;
    // Only the chain node is shut (the dev RPC is down): the wallet list, the
    // four keys and the entry group still stand, and the asset list says in
    // one line that balances cannot be read now (decision 0119).
    final chainClosed = !preview && !blocked && !bscGate.isAvailable;
    final walletId = _watchActiveWalletId(ref, blocked: blocked);
    final directory = ref.watch(walletDirectoryControllerProvider);
    final balancesState = walletId == null || chainClosed
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
    final balancesLoading =
        !blocked &&
        !chainClosed &&
        balances == null &&
        (walletId == null
            ? directory.phase == LoopChainViewPhase.loading
            : balancesState?.phase == LoopChainViewPhase.loading);
    if (balancesLoading) _sawBalancesSkeleton = true;
    // Decision 0095: how old the figures on screen are, whenever that is not
    // "just read". A stored snapshot is always labelled; a refresh that failed
    // keeps the figures and says so.
    final balancesController = walletId == null || chainClosed
        ? null
        : ref.read(walletBalancesControllerProvider(walletId).notifier);
    final directoryController = ref.read(
      walletDirectoryControllerProvider.notifier,
    );
    final restoredAt =
        balancesController?.restoredObservedAt ??
        directoryController.restoredObservedAt;
    final refreshFailed =
        (balances != null && balancesState?.failureKind != null) ||
        (directory.value != null &&
            directory.failureKind != null &&
            directory.failureKind != LoopChainFailureKind.versionConflict);

    // A key promises what the destination can do. Both write gates are read
    // here so the promise matches the page one tap away.
    final swapGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.privySwap),
    );
    final sendGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.sendApprovals),
    );
    // Decision 0188: the eye is 0175's 「隐藏余额」, the same choice as 我.
    final hidden = ref.watch(
      loopBalanceVisibilityProvider.select((visibility) => visibility.hidden),
    );
    final directoryEmpty = _directoryIsEmpty(directory);
    // S136 · decision 0139: MEME v2 holdings and NFTs from `me/positions`;
    // nothing unless the switch is on and the server publishes `launch2`.
    final launch2 = launch2WalletEntries(ref, onOpen: _open, hidden: hidden);

    return LoopAtmoPrecache(
      paths: const <String>[
        ...loopAtmosphereTabAssets,
        LoopAtmoAssets.avatarChrome,
      ],
      child: LoopDashboardPage(
        key: const ValueKey<String>('wallet-screen'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.wallet_readScreensWalletScreenTitle,
        tabPage: true,
        // S343 · decision 0271: the bar keeps 交易历史 / 通知 / 设置 only.
        pageInfo: false,
        // Decision 0221: the wall under 钱包, the crown behind its title.
        backdrop: const LoopWallBackdrop(
          key: ValueKey<String>('wallet-atmo-backdrop'),
          fog: LoopWallFog.wallet,
          keyPrefix: 'wallet-atmo',
        ),
        titleField: LoopAtmoTitle(
          title: context.l10n.wallet_readScreensWalletScreenTitle,
          crownKey: ValueKey<String>('wallet-atmo-title-crown'),
        ),
        // Balances the page already read stay on screen while the next read
        // runs; only the 更新中 mark changes.
        updating: balancesState?.refreshing ?? false,
        onRefresh: () => Future.wait<void>(<Future<void>>[
          _refreshWallet(ref, chainClosed ? null : walletId),
          ref.read(profileControllerProvider.notifier).reload(),
          // S349: the section on screen is read again with the rest.
          if (walletId != null &&
              ref.exists(walletActivityControllerProvider(walletId)))
            ref
                .read(walletActivityControllerProvider(walletId).notifier)
                .reload(),
          if (ref.exists(communityHomeControllerProvider))
            ref.read(communityHomeControllerProvider.notifier).reload(),
        ]),
        actions: <Widget>[
          // S349: 交易历史 is the 交易 section now, not a key in the bar.
          // S343 · decision 0271: the bell left 聊天 for 我的.
          NotificationBellButton(
            onPressed: () => _openProfile('notifications'),
          ),
          LoopIconButton(
            key: const ValueKey<String>('profile-open-settings'),
            icon: 'settings',
            label: context.l10n.common_settings,
            onPressed: () => _openProfile('settings'),
          ),
        ],
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ProfileIdentitySection(onNavigate: _openProfile),
            MeMessageRequestsEntry(
              onOpen: () => _openProfile('friend-requests'),
            ),
            if (!blocked)
              _totalPlate(
                balances: balances,
                balancesLoading: balancesLoading,
                directory: directory,
                directoryEmpty: directoryEmpty,
                walletId: walletId,
                balancesState: balancesState,
              ),
          ],
        ),
        sections: <Widget>[
          if (!blocked) ...<Widget>[
            LoopFreshnessStrip(
              key: const ValueKey<String>('wallet-freshness'),
              restoredAt: restoredAt,
              readAt: balancesController?.valueObservedAt,
              refreshing:
                  (balancesState?.refreshing ?? false) || directory.refreshing,
              refreshFailed: refreshFailed,
              onRetry: () =>
                  unawaited(_refreshWallet(ref, chainClosed ? null : walletId)),
            ),
            // Decision 0095: the keys never wait for a balance.
            if (walletId != null)
              _quickActions(
                walletId: walletId,
                sendGate: sendGate,
                swapGate: swapGate,
              ),
          ],
          // S349: the bar another account's page draws (decision 0218).
          LoopProfileSectionsBar(
            key: const ValueKey<String>('me-sections'),
            selected: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
          ...switch (_section) {
            LoopProfileSection.holdings => _holdingsSection(
              blocked: blocked,
              directory: directory,
              directoryEmpty: directoryEmpty,
              walletId: walletId,
              chainClosed: chainClosed,
              chainReason: bscGate.reasonCode,
              balancesState: balancesState,
              hidden: hidden,
              sendGate: sendGate,
              swapGate: swapGate,
              launch2: launch2,
            ),
            LoopProfileSection.trades => _tradesSection(
              blocked: blocked,
              directory: directory,
              directoryEmpty: directoryEmpty,
              walletId: walletId,
            ),
            LoopProfileSection.communities => <Widget>[
              MeCommunitiesSection(
                key: const ValueKey<String>('me-communities-section'),
                onNavigate: _openProfile,
              ),
            ],
          },
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// The five keys (S349): 接收 / 发送 / 兑换 / 扫码 / DApp.
  Widget _quickActions({
    required String walletId,
    required LoopCapabilityProjection sendGate,
    required LoopCapabilityProjection swapGate,
  }) => WalletQuickActions(
    onBlocked: _blocked,
    actions: <WalletQuickAction>[
      WalletQuickAction(
        actionKey: const ValueKey<String>('wallet-receive-entry'),
        label: LoopL10n.current.common_receive,
        glyph: (color) => LoopIcon('arrow-down', size: 22, color: color),
        onPressed: () => _open(WalletRoute.receive(walletId)),
      ),
      WalletQuickAction(
        actionKey: const ValueKey<String>('wallet-send-entry'),
        label: LoopL10n.current.common_send,
        glyph: (color) => LoopIcon('arrow-up', size: 22, color: color),
        onPressed: sendGate.isAvailable ? () => _open('/wallet/send') : null,
        blockedReason: sendGate.isAvailable
            ? null
            : loopReasonCodeText(
                sendGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
              ),
      ),
      WalletQuickAction(
        actionKey: const ValueKey<String>('wallet-swap-entry'),
        label: LoopL10n.current.common_swap,
        glyph: (color) => LoopIcon('swap-vert', size: 22, color: color),
        primary: true,
        onPressed: swapGate.isAvailable ? () => _open('/wallet/swap') : null,
        blockedReason: swapGate.isAvailable
            ? null
            : loopReasonCodeText(
                swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
              ),
      ),
      // Decision 0113 (需求方 2026-10-08: 扫码支付先做扫码转账): the key
      // opens the scanner. A scanned address continues into 发送 with the
      // recipient filled in and the same server preflight and signing
      // sheet; the `pay` page itself stays unavailable.
      WalletQuickAction(
        actionKey: const ValueKey<String>('wallet-pay-entry'),
        label: LoopL10n.current.wallet_sendScreensSendRecipientScanLabel,
        glyph: (color) =>
            Icon(Icons.qr_code_scanner_rounded, size: 22, color: color),
        onPressed: () => _open('/scan'),
      ),
      // S342 · decision 0270: `/wallet/dapp` opens the in-app browser when
      // the server's `dappBrowser` is on and this build has a WebView, and
      // the URL review otherwise; the key is always there.
      WalletQuickAction(
        actionKey: const ValueKey<String>('wallet-dapp-entry'),
        label: 'DApp',
        glyph: (color) => LoopIcon('link', size: 22, color: color),
        onPressed: () => _openProfile('dapp'),
      ),
    ],
  );

  /// What stands in for a wallet-bound section while no wallet is active:
  /// the directory was read and is empty, it names no active wallet, or it
  /// was not read. `null` once a wallet is active.
  Widget? _directoryGate({
    required LoopChainResourceState<LoopWalletDirectory> directory,
    required bool directoryEmpty,
    required String? walletId,
  }) {
    if (directoryEmpty) {
      return const WalletCreationBlock(keyPrefix: 'wallet-directory');
    }
    if (walletId != null) return null;
    if (directory.isReady) {
      return LoopEmptyState(
        key: const ValueKey<String>('wallet-directory-no-active'),
        illustration: LoopIllustration.history,
        title: LoopL10n.current.wallet_readScreensWalletDirectoryNoActiveTitle,
        action: LoopButton(
          key: const ValueKey<String>('wallet-directory-pick'),
          label: LoopL10n.current.wallet_homeLabel16,
          primary: true,
          onPressed: () => _open('/wallet/manage'),
        ),
        compact: true,
      );
    }
    return LoopChainStateBlock(
      keyPrefix: 'wallet-directory',
      phase: directory.phase,
      failureKind: directory.failureKind,
      emptyMessage: LoopL10n.current.wallet_readScreensEmptyMessage,
      onRetry: () => unawaited(
        ref.read(walletDirectoryControllerProvider.notifier).reload(),
      ),
    );
  }

  /// 持仓: the 代币 / NFT holdings (S334 · decision 0263, the same holdings
  /// 我 listed), 产生算力 on the right of the tabs.
  List<Widget> _holdingsSection({
    required bool blocked,
    required LoopChainResourceState<LoopWalletDirectory> directory,
    required bool directoryEmpty,
    required String? walletId,
    required bool chainClosed,
    required String? chainReason,
    required LoopChainResourceState<LoopWalletBalances>? balancesState,
    required bool hidden,
    required LoopCapabilityProjection sendGate,
    required LoopCapabilityProjection swapGate,
    required Launch2WalletEntries launch2,
  }) {
    if (blocked) {
      return <Widget>[
        _walletPageBlock(
          ref,
          key: const ValueKey<String>('wallet-capability-block'),
          title: LoopL10n.current.wallet_readScreensWalletCapabilityBlockTitle,
        ),
      ];
    }
    final gate = _directoryGate(
      directory: directory,
      directoryEmpty: directoryEmpty,
      walletId: walletId,
    );
    if (gate != null || walletId == null) {
      return <Widget>[?gate];
    }
    return <Widget>[
      // S259 · decision 0217: 「代币 / NFT」, 产生算力 kept on the right of
      // the same line.
      WalletAssetTabs(
        selectedIndex: _assetTab,
        onSelected: (index) => setState(() => _assetTab = index),
        // S343 · decision 0271: 产生算力 opens 情报 · 算力.
        trailing: WalletPowerTag(onTap: () => _open(loopIntelPowerLocation)),
      ),
      ...(_assetTab == WalletAssetTabs.nft
          ? _nftBody(launch2: launch2, hidden: hidden)
          : _tokenBody(
              walletId: walletId,
              chainClosed: chainClosed,
              chainReason: chainReason,
              state: balancesState,
              hidden: hidden,
              sendGate: sendGate,
              swapGate: swapGate,
              launch2: launch2,
            )),
    ];
  }

  /// 交易: this wallet's own tape, the one `tx-history` draws (S349).
  List<Widget> _tradesSection({
    required bool blocked,
    required LoopChainResourceState<LoopWalletDirectory> directory,
    required bool directoryEmpty,
    required String? walletId,
  }) {
    if (blocked || _walletBlocked(ref)) {
      return <Widget>[
        _walletPageBlock(
          ref,
          key: const ValueKey<String>('me-trades-capability-block'),
          title:
              LoopL10n.current.wallet_readScreensMeTradesCapabilityBlockTitle,
        ),
      ];
    }
    final gate = _directoryGate(
      directory: directory,
      directoryEmpty: directoryEmpty,
      walletId: walletId,
    );
    if (gate != null || walletId == null) {
      return <Widget>[?gate];
    }
    return activityTapeSections(
      walletId: walletId,
      state: watchActivity(walletId),
      keyPrefix: 'me-trades',
      underTabs: true,
    );
  }

  /// 总资产 on its chrome plate (decision 0221); its figure stays Yellow.
  Widget _totalPlate({
    required LoopWalletBalances? balances,
    required bool balancesLoading,
    required LoopChainResourceState<LoopWalletDirectory> directory,
    required bool directoryEmpty,
    required String? walletId,
    required LoopChainResourceState<LoopWalletBalances>? balancesState,
  }) => LoopChromePlate(
    key: const ValueKey<String>('wallet-total-plate'),
    mark: LoopChromePlateMark.tag,
    // v3 (decision 0229): 28 from the plate to the keys (they keep 10
    // of their own above them). S350c: 16 above it, where the person's
    // card used to end on a rule.
    margin: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.segmentGap,
      LoopSpacing.page,
      LoopSpacing.bannerGap - 10,
    ),
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
    child: WalletTotalHeader(
      key: const ValueKey<String>('wallet-folio'),
      keyPrefix: 'wallet',
      balances: balances,
      loading: balancesLoading,
      unreadText: directoryEmpty
          ? LoopL10n.current.wallet_readScreensWalletFolioUnreadText
          : walletId == null && directory.isReady
          ? LoopL10n.current.wallet_readScreensWalletFolioUnreadText2
          // Decision 0123: a read that never reached LOOP is the device
          // being offline, not the figure being unavailable.
          : directory.phase == LoopChainViewPhase.offline ||
                balancesState?.phase == LoopChainViewPhase.offline
          ? LoopL10n.current.wallet_readScreensWalletFolioUnreadText3
          : LoopL10n.current.wallet_homeUnreadText,
      address: directory.value?.active?.truncatedAddress,
      fullAddress: directory.value?.active?.address,
      environmentTag: ref.watch(loopEnvironmentTagProvider),
      walletId: walletId,
      // S349 (需求方 11-03): 钱包管理 beside the address, in place of the
      // 我的钱包 row.
      addressTrailing: WalletManagePill(
        key: const ValueKey<String>('wallet-manage-action'),
        onPressed: () => _openProfile('wallets'),
      ),
    ),
  );

  /// 「代币」 in each of its states (S259 · decision 0217). The main chain's
  /// rows, the Launch chain's BNB and USD1 and the MEME v2 tokens are one
  /// list: valued rows by value, then the rest by amount. A row holding
  /// nothing is not drawn. A failed or closed main read is one weak line,
  /// never a block-sized card: the four keys and the entry group around it
  /// still work, and the Launch rows still stand.
  List<Widget> _tokenBody({
    required String walletId,
    required bool chainClosed,
    required String? chainReason,
    required LoopChainResourceState<LoopWalletBalances>? state,
    required bool hidden,
    required LoopCapabilityProjection sendGate,
    required LoopCapabilityProjection swapGate,
    required Launch2WalletEntries launch2,
  }) {
    void retry() => unawaited(
      ref.read(walletBalancesControllerProvider(walletId).notifier).reload(),
    );
    // S334 · decision 0263: the same holdings 我 lists.
    Widget mainRow(LoopAssetBalanceRow row) => WalletBalanceRow(
      row: row,
      hidden: hidden,
      gasReserve: row.isNative
          ? state?.value?.gasReservePolicy.nativeReserve
          : null,
      onTap: () => _open(MarketAssetRoute.walletAsset(row.assetId)),
      onRetry: retry,
      onBlocked: _blocked,
      actions: _rowActions(row, sendGate, swapGate),
    );
    final launch2Rows = <Widget>[
      for (final entry in walletHoldings(
        balances: null,
        launch2: launch2,
        hidden: hidden,
        mainRow: mainRow,
      ).tokens)
        entry.row,
      ?launch2.failure,
    ];
    if (chainClosed) {
      return <Widget>[
        LoopInlineUnavailable(
          key: const ValueKey<String>('wallet-balances-state-unavailable'),
          message: loopReasonCodeText(
            chainReason ?? 'BSC_CHAIN_RUNTIME_UNAVAILABLE',
          ),
        ),
        ...launch2Rows,
      ];
    }
    if (state == null || state.phase == LoopChainViewPhase.loading) {
      return const <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('wallet-balances-state-loading'),
          type: LoopSkeletonType.record,
          rows: 4,
          leadingSize: 40,
          subtitleLines: 1,
        ),
      ];
    }
    if (!state.isReady) {
      if (state.phase == LoopChainViewPhase.empty) {
        return <Widget>[
          if (launch2Rows.isEmpty)
            LoopEmptyState(
              key: ValueKey<String>('wallet-balances-state-empty'),
              illustration: LoopIllustration.history,
              title: LoopL10n.current.wallet_moneyAssetPickerTitle2,
              compact: true,
            ),
          ...launch2Rows,
        ];
      }
      final permission = state.phase == LoopChainViewPhase.permission;
      return <Widget>[
        // Keyed by phase, as the state block was: an offline read, a
        // refused one and a failed one stay three different answers.
        LoopInlineUnavailable(
          key: ValueKey<String>('wallet-balances-state-${state.phase.name}'),
          icon: loopChainIsOffline(state.failureKind) ? 'offline' : 'warn',
          message: _balancesFailureLine(state.phase, state.failureKind),
          onRetry: permission ? null : retry,
        ),
        ...launch2Rows,
      ];
    }
    final balances = state.value!;
    final netWorth = balances.netWorth;
    final launch = balances.launchChain;
    final launchNative = launch?.nativeBalance;
    final entries = walletHoldings(
      balances: balances,
      launch2: launch2,
      hidden: hidden,
      mainRow: mainRow,
    ).tokens;
    final launchSnapshot = launchNative?.snapshot;
    return <Widget>[
      LoopContentArrival(
        animate: _sawBalancesSkeleton,
        child: Column(
          key: const ValueKey<String>('wallet-asset-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final entry in entries) entry.row,
            if (launch != null && launchNative == null)
              walletLaunchUnavailableLine(launch),
            ?launch2.failure,
            if (entries.isEmpty &&
                launch2.failure == null &&
                (launch == null || launchNative != null))
              LoopEmptyState(
                key: ValueKey<String>('wallet-balances-empty'),
                illustration: LoopIllustration.history,
                title:
                    LoopL10n.current.wallet_readScreensWalletBalancesEmptyTitle,
                compact: true,
              ),
          ],
        ),
      ),
      if (launch != null && walletLaunchChainBadged(launch))
        walletLaunchTotalNote(),
      // One provenance line under the list: the block every balance was
      // read at, the price source and when it was observed. The full
      // statement — confirmations, the gas reserve and the Launch chain's
      // own block — is one tap away.
      LoopProvenanceLine(
        key: const ValueKey<String>('wallet-snapshot-footer'),
        prefix: LoopL10n.current.wallet_readScreensWalletSnapshotFooterPrefix(
          loopGroupedFigure(balances.snapshot.blockNumber.toString()),
        ),
        sources: <String>[
          if (netWorth is LoopNetWorthValued)
            loopFactSourceLabel(netWorth.priceSource),
        ],
        observedAt: balances.snapshot.observedAt,
        detail: LoopL10n.current.wallet_readScreensWalletSnapshotFooterDetail(
          loopFormatDecimal(balances.gasReservePolicy.nativeReserve),
          loopGroupedFigure(balances.snapshot.confirmations.toString()),
          launchSnapshot == null
              ? ''
              : LoopL10n.current.wallet_readScreensSX(
                  loopGroupedFigure(launchSnapshot.blockNumber.toString()),
                ),
        ),
      ),
    ];
  }

  /// 「NFT」 (S259 · decision 0217): the project NFTs (共识勋章), read from
  /// `me/positions` — since S273 (decision 0232) a two-column grid of
  /// picture cards; a card opens the medal page.
  List<Widget> _nftBody({
    required Launch2WalletEntries launch2,
    required bool hidden,
  }) {
    if (launch2.closed) {
      return <Widget>[
        LoopInlineUnavailable(
          key: ValueKey<String>('wallet-nft-unavailable'),
          icon: 'info',
          message:
              LoopL10n.current.wallet_readScreensWalletNftUnavailableMessage,
        ),
      ];
    }
    if (launch2.loading) {
      return const <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('wallet-nft-loading'),
          type: LoopSkeletonType.record,
          rows: 2,
          leadingSize: 40,
          subtitleLines: 1,
        ),
      ];
    }
    if (launch2.failure case final Widget failure) return <Widget>[failure];
    if (launch2.nfts.isEmpty) {
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('wallet-nft-empty'),
          illustration: LoopIllustration.launchpad,
          title: LoopL10n.current.wallet_readScreensWalletNftEmptyTitle,
          compact: true,
        ),
      ];
    }
    return <Widget>[
      // S273 · decision 0232: two picture cards to a row.
      Padding(
        key: const ValueKey<String>('wallet-nft-list'),
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          LoopSpacing.tight,
          LoopSpacing.page,
          LoopSpacing.rowGap,
        ),
        child: Launch2NftGrid(children: launch2.nfts),
      ),
      Consumer(
        builder: (context, ref, _) => LoopProvenanceLine(
          key: const ValueKey<String>('wallet-nft-provenance'),
          sources: <String>[context.l10n.wallet_readScreensLoopProvenanceLine],
          observedAt: ref
              .read(launch2PositionsControllerProvider.notifier)
              .valueObservedAt,
        ),
      ),
    ];
  }

  /// 发送 / 兑换 under a balance row (decision 0188). Each promises what the
  /// four keys above promise: the same gate, the same server sentence when
  /// it is shut. 兑换 starts from this row's asset.
  List<WalletRowAction> _rowActions(
    LoopAssetBalanceRow row,
    LoopCapabilityProjection sendGate,
    LoopCapabilityProjection swapGate,
  ) => <WalletRowAction>[
    WalletRowAction(
      label: LoopL10n.current.common_send,
      actionKey: ValueKey<String>('wallet-balance-send-${row.assetId}'),
      onPressed: sendGate.isAvailable ? () => _open('/wallet/send') : null,
      blockedReason: sendGate.isAvailable
          ? null
          : loopReasonCodeText(
              sendGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
            ),
    ),
    WalletRowAction(
      label: LoopL10n.current.common_swap,
      actionKey: ValueKey<String>('wallet-balance-swap-${row.assetId}'),
      onPressed: swapGate.isAvailable
          ? () => _open(
              Uri(
                path: '/wallet/swap',
                queryParameters: <String, String>{'from': row.assetId},
              ).toString(),
            )
          : null,
      blockedReason: swapGate.isAvailable
          ? null
          : loopReasonCodeText(
              swapGate.reasonCode ?? 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
            ),
    ),
  ];

  /// One short line per failure, so the asset list keeps its place.
  String _balancesFailureLine(
    LoopChainViewPhase phase,
    LoopChainFailureKind? kind,
  ) {
    if (phase == LoopChainViewPhase.permission) {
      return LoopL10n.current.wallet_readScreensBalancesFailureLine;
    }
    return switch (kind) {
      LoopChainFailureKind.offline =>
        LoopL10n.current.wallet_readScreensOffline,
      LoopChainFailureKind.timedOut =>
        LoopL10n.current.wallet_readScreensTimedOut,
      LoopChainFailureKind.rateLimited =>
        LoopL10n.current.wallet_readScreensRateLimited,
      LoopChainFailureKind.unavailable =>
        LoopL10n.current.wallet_readScreensUnavailable,
      _ => LoopL10n.current.wallet_readScreensSwitch,
    };
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
  final void Function(String location, {Object? extra})? onNavigate;

  @override
  ConsumerState<WalletAssetScreen> createState() => _WalletAssetScreenState();
}

class _WalletAssetScreenState extends ConsumerState<WalletAssetScreen> {
  void _blocked(String reason) {
    LoopToast.show(context, message: reason, kind: LoopToastKind.warn);
  }

  void _open(String location, {Object? extra}) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location, extra: extra);
      return;
    }
    context.push(location, extra: extra);
  }

  /// Opens Send with this asset already chosen.
  ///
  /// Step 1 exists to pick an asset; pressed here the asset is already
  /// picked, so the flow starts at step 2 with a draft carrying the wallet,
  /// the opaque asset id and the symbol. A row whose chain read failed cannot
  /// carry a draft — there is no spendable figure to check an amount against
  /// — so it falls back to step 1 rather than pretending.
  void _openSend({
    required String? walletId,
    required String assetId,
    required LoopAssetBalanceRow? row,
  }) {
    if (walletId == null ||
        row == null ||
        row.balance is! LoopBalanceAvailable) {
      _open('/wallet/send');
      return;
    }
    _open(
      '/wallet/send/to',
      extra: SendDraft(
        walletId: walletId,
        assetId: assetId,
        symbol: row.symbol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return LoopFocusPage(
        key: const ValueKey<String>('wallet-asset-invalid'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.wallet_readScreensWalletAssetInvalidTitle,
        onBack: widget.onBack,
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('wallet-asset-invalid-identity'),
            illustration: LoopIllustration.history,
            title:
                context.l10n.wallet_readScreensWalletAssetInvalidIdentityTitle,
            message: context
                .l10n
                .wallet_readScreensWalletAssetInvalidIdentityMessage,
            compact: true,
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
      title: context.l10n.wallet_readScreensWalletAssetMarketActionTitle(
        asset?.symbol ?? row?.symbol ?? '—',
      ),
      onBack: widget.onBack,
      actions: <Widget>[
        // `#scr-asset` draws 行情 as a `.topbar .seg`; decision 0087 keeps the
        // pill's frame and swaps the word for the bar glyph the 行情 tab
        // itself wears.
        LoopIconButton(
          key: const ValueKey<String>('wallet-asset-market-action'),
          icon: 'chart',
          label: context.l10n.common_market,
          framed: true,
          onPressed: () => _open(MarketAssetRoute.token(assetId)),
        ),
      ],
      primary: LoopFolioPrimary(
        ring: false,
        key: const ValueKey<String>('wallet-asset-folio'),
        archetype: LoopFolioArchetype.record,
        kicker: context.l10n.wallet_readScreensWalletAssetFolioKicker,
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
            null => context.l10n.wallet_readScreensLoopFolioPrimary,
          },
        ].join(' · '),
        stamp: _assetChainStamp(assetId),
      ),
      block: blocked
          ? _walletPageBlock(
              ref,
              key: const ValueKey<String>('wallet-asset-capability-block'),
              title: context.l10n.wallet_readScreensWalletCapabilityBlockTitle,
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
            emptyMessage: context.l10n.wallet_readScreensEmptyMessage2,
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
          LoopInlineUnavailable(
            key: ValueKey<String>('wallet-asset-missing-row'),
            message:
                context.l10n.wallet_readScreensWalletAssetMissingRowMessage,
            detail: context.l10n.wallet_readScreensWalletAssetMissingRowDetail,
            detailMaxLines: 3,
            maxLines: 2,
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
                label: context.l10n.wallet_readScreensLabel,
                value: switch (row.balance) {
                  LoopBalanceAvailable(displayBalance: final value) =>
                    loopFormatDecimal(value),
                  LoopBalanceUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-spendable'),
                label: context.l10n.wallet_readScreensLabel2,
                value: switch (row.balance) {
                  LoopBalanceAvailable(spendableBalance: final value) =>
                    loopFormatDecimal(value),
                  LoopBalanceUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-price'),
                label: context.l10n.wallet_readScreensLabel3,
                value: switch (row.valuation) {
                  LoopValuationAvailable(priceUsd: final value) =>
                    loopFormatUsd(value),
                  LoopValuationUnavailable() => loopFigureDash,
                },
              ),
              LoopStat(
                statKey: const ValueKey<String>('wallet-asset-stat-value'),
                label: context.l10n.wallet_readScreensLabel4,
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
          LoopLabel(context.l10n.wallet_readScreensLoopLabel),
          WalletAssetPowerHint(
            assetId: assetId,
            onOpenMining: () => _open('/mining/assets'),
          ),
          LoopActionGrid(
            onBlocked: _blocked,
            actions: <LoopAction>[
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-send'),
                label: context.l10n.common_send,
                icon: 'arrow-up',
                // 发送 pressed on one asset's own page already answers step
                // 1. Landing on 「选择要发送的资产」 made the owner pick the
                // asset they had just opened, out of eleven rows, ten of
                // which have nothing to send.
                onPressed: sendAvailable
                    ? () => _openSend(
                        walletId: walletId,
                        assetId: assetId,
                        row: row,
                      )
                    : null,
                blockedReason: sendAvailable ? null : sendReason,
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-receive'),
                label: context.l10n.common_receive,
                icon: 'arrow-down',
                onPressed: () => _open(WalletRoute.receive(walletId)),
              ),
              LoopAction(
                actionKey: const ValueKey<String>('wallet-asset-swap'),
                label: context.l10n.common_swap,
                icon: 'swap-vert',
                onPressed: swapAvailable ? () => _open('/wallet/swap') : null,
                blockedReason: swapAvailable ? null : swapReason,
              ),
            ],
          ),
          LoopLabel(context.l10n.wallet_readScreensLoopLabel2),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('wallet-asset-chain-row'),
                leading: const LoopNetworkLogo(network: 'bsc', size: 36),
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
          LoopLabel(context.l10n.wallet_readScreensLoopLabel3),
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
            summary: context
                .l10n
                .wallet_readScreensWalletAssetFactsDisclosureSummary,
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
  return LoopL10n.current.wallet_readScreensIf(ticker);
}

/// The chain slot one canonical asset id names.
String _assetChainName(String assetId) {
  final chainId = assetId.substring(0, assetId.lastIndexOf(':'));
  return loopKnownChainIds.contains(chainId) ? loopChainName(chainId) : chainId;
}

/// The same chain, as the folio's uppercase stamp.
///
/// The stamp is capped at 42% of the card, so 「BNB SMART CHAIN」 rendered as
/// 「BNB SMART CHA…」. The two published chains get the short form a stamp has
/// room for; an unknown chain gets no stamp rather than a truncated one.
String? _assetChainStamp(String assetId) =>
    switch (assetId.substring(0, assetId.lastIndexOf(':'))) {
      loopPrimaryChainId => 'BSC',
      // Decision 0204: the testnet stamp is a test-only hint.
      loopLaunchTestnetChainId =>
        loopTestHintsVisible ? loopTestnetStampText : 'BSC',
      _ => null,
    };

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
        emptyMessage: context.l10n.wallet_readScreensEmptyMessage3,
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
          LoopEmptyState(
            key: ValueKey<String>('wallet-asset-activity-empty'),
            illustration: LoopIllustration.history,
            title: context.l10n.wallet_readScreensEmptyMessage3,
            message:
                context.l10n.wallet_readScreensWalletAssetActivityEmptyMessage,
            compact: true,
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
              // Named after the page it opens (audit m9).
              title:
                  context.l10n.wallet_readScreensWalletAssetHistoryEntryTitle,
              subtitle: context
                  .l10n
                  .wallet_readScreensWalletAssetHistoryEntrySubtitle,
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
          margin: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              switch (balance) {
                LoopBalanceUnavailable(reasonCode: final reasonCode) =>
                  LoopUnavailableLine(
                    key: const ValueKey<String>('wallet-asset-balance-missing'),
                    label: context
                        .l10n
                        .wallet_readScreensWalletAssetBalanceMissingLabel,
                    reasonCode: reasonCode,
                    margin: EdgeInsets.zero,
                  ),
                LoopBalanceAvailable() => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Five separate meanings; the page never derives one from
                    // another.
                    LoopKeyValue(
                      label: context.l10n.wallet_readScreensLabel,
                      value: loopFormatDecimal(balance.displayBalance),
                    ),
                    LoopKeyValue(
                      label: context.l10n.wallet_readScreensLabel5,
                      value: loopFormatDecimal(balance.availableBalance),
                    ),
                    LoopKeyValue(
                      label: context.l10n.wallet_readScreensLabel6,
                      value: loopFormatDecimal(balance.spendableBalance),
                    ),
                    LoopKeyValue(
                      label: context.l10n.wallet_homeLabel11,
                      value: loopFormatDecimal(balance.gasReserve),
                    ),
                  ],
                ),
              },
              switch (row.pending) {
                LoopPendingUnavailable(reasonCode: final reasonCode) =>
                  LoopUnavailableLine(
                    key: const ValueKey<String>('wallet-asset-pending-missing'),
                    label: context
                        .l10n
                        .wallet_readScreensWalletAssetPendingMissingLabel,
                    reasonCode: reasonCode,
                    margin: EdgeInsets.zero,
                  ),
                LoopPendingAvailable(value: final value) => LoopKeyValue(
                  label: context.l10n.wallet_readScreensLabel7,
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
        return LoopUnavailableLine(
          key: const ValueKey<String>('wallet-asset-valuation-unavailable'),
          label: context
              .l10n
              .wallet_readScreensWalletAssetValuationUnavailableLabel,
          reasonCode: reasonCode,
        );
      case final LoopValuationAvailable valued:
        return LoopSurfaceCard(
          key: const ValueKey<String>('wallet-asset-valuation'),
          margin: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopKeyValue(
                label: context.l10n.wallet_readScreensLabel8,
                value: loopFormatUsd(valued.priceUsd),
              ),
              LoopKeyValue(
                label: context.l10n.wallet_readScreensLabel4,
                value: loopFormatUsd(valued.valueUsd),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (valued.isProxied)
                    LoopBadge(
                      context.l10n.wallet_readScreensWalletAssetProxied,
                      key: ValueKey<String>('wallet-asset-proxied'),
                    ),
                  if (valued.quality == LoopFactQuality.stale)
                    LoopBadge(
                      context.l10n.wallet_readScreensLoopBadge,
                      kind: LoopBadgeKind.down,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                <String>[
                  context.l10n.wallet_readScreensSwitch2(
                    loopFactSourceLabel(valued.priceSource),
                  ),
                  context.l10n.wallet_readScreensSwitch3(
                    loopRelativeTime(valued.fetchedAt),
                  ),
                  if (valued.proxyAsset != null)
                    context.l10n.wallet_readScreensSwitch4(
                      loopTruncatedAssetId(valued.proxyAsset!),
                    ),
                ].join(' · '),
                // R21 (decision 0190 M30).
                style: LoopType.captionSm.copyWith(color: LoopColors.text3),
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
      return LoopUnavailableLine(
        key: const ValueKey<String>('wallet-asset-crosscheck-unavailable'),
        label: context
            .l10n
            .wallet_readScreensWalletAssetCrosscheckUnavailableLabel,
        // The server may state no reason. Substituting one here would invent a
        // cause it never reported, so the card falls back to a neutral line.
        reasonCode: crossCheck.reasonCode,
      );
    }
    return LoopNotice(
      key: const ValueKey<String>('wallet-asset-crosscheck'),
      icon: 'info',
      title: context.l10n.wallet_homeIf2,
      body: context.l10n.wallet_readScreensWalletAssetCrosscheckBody(
        crossCheck.blockDelta == null
            ? ''
            : context.l10n.wallet_readScreensS2X(crossCheck.blockDelta),
      ),
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
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopKeyValue(
            label: context.l10n.wallet_activityExportSwitch3,
            value: loopTruncatedAssetId(assetId),
          ),
          LoopKeyValue(
            label: context.l10n.wallet_readScreensLabel9,
            value: decimals == null
                ? context.l10n.common_dataUnavailable
                : '$decimals',
          ),
          if (rawValue != null && decimals != null)
            LoopKeyValue(
              label: context.l10n.wallet_readScreensLabel10(decimals),
              value: loopGroupedFigure(rawValue!),
            ),
          LoopKeyValue(
            label: context.l10n.wallet_readScreensLabel11,
            value: asset.status.label,
          ),
          if (asset.address != null)
            LoopKeyValue(
              label: context.l10n.wallet_readScreensLabel12,
              value: loopTruncatedAddress(asset.address!),
            ),
          const SizedBox(height: 6),
          Text(
            <String>[
              context.l10n.wallet_readScreensIf2,
              if (asset.source.blockNumber != null)
                context.l10n.wallet_readScreensIf3(
                  loopGroupedFigure(asset.source.blockNumber.toString()),
                ),
              if (asset.source.verifiedAt != null)
                context.l10n.wallet_readScreensIf4(
                  loopRelativeTime(asset.source.verifiedAt!),
                ),
            ].join(' · '),
            // R21 (decision 0190 M30).
            style: LoopType.captionSm.copyWith(color: LoopColors.text3),
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
    // The directory is read either way: 获取资金 asks which wallet is the
    // active embedded one (S343 · decision 0271).
    final activeWalletId = _watchActiveWalletId(ref, blocked: blocked);
    final walletId = widget.walletId ?? activeWalletId;
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
    final active = ref.watch(walletDirectoryControllerProvider).value?.active;
    final faucetWalletId =
        walletId != null &&
            WalletRoute.isCanonical(walletId) &&
            testnetFaucetVisible(ref) &&
            active?.kind == LoopWalletKind.embedded &&
            active?.walletId == walletId
        ? walletId
        : null;

    // Decision 0126 (OKX 收款): network chips, the code centred, the address
    // in one capsule, then 复制 / 分享 — no folio restating the address.
    return LoopFlat(
      child: LoopFocusPage(
        key: const ValueKey<String>('receive-screen'),
        archetype: LoopPageArchetype.action,
        title: context.l10n.common_receive,
        onBack: widget.onBack,
        block: blocked
            ? _walletPageBlock(
                ref,
                key: const ValueKey<String>('receive-capability-block'),
                title:
                    context.l10n.wallet_readScreensWalletCapabilityBlockTitle,
              )
            : null,
        body: <Widget>[
          if (noWalletYet)
            const WalletCreationBlock(keyPrefix: 'receive')
          // Decision 0132: with no answer for this wallet on this device yet,
          // the page loads in its own shape — chip, code, address, buttons —
          // so nothing moves when the addresses land. Every later visit
          // opens on the stored answer and never shows this.
          else if ((walletId == null || state == null || !state.isReady) &&
              (state?.phase ?? LoopChainViewPhase.loading) ==
                  LoopChainViewPhase.loading)
            const WalletReceiveSkeleton(
              key: ValueKey<String>('receive-state-loading'),
            )
          else if (walletId == null || state == null || !state.isReady)
            LoopChainStateBlock(
              keyPrefix: 'receive',
              phase: state?.phase ?? LoopChainViewPhase.loading,
              failureKind: state?.failureKind,
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage4,
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
            LoopInlineUnavailable(
              key: ValueKey<String>('receive-no-network'),
              message: context.l10n.wallet_readScreensReceiveNoNetworkMessage,
              detail: context.l10n.wallet_readScreensReceiveNoNetworkDetail,
              detailMaxLines: 3,
              maxLines: 2,
            )
          else ...<Widget>[
            // Only the networks the server published are listed: a chip for a
            // network LOOP does not publish would be an address that does not
            // exist.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final (index, item) in networks.indexed) ...<Widget>[
                    if (index > 0) const SizedBox(width: 7),
                    ReceiveNetworkChip(
                      key: ValueKey<String>('receive-network-${item.chainId}'),
                      network: item,
                      selected: index == _selected,
                      // One published network is a label, not a choice.
                      onTap: networks.length < 2
                          ? null
                          : () => setState(() => _selected = index),
                    ),
                  ],
                ],
              ),
            ),
            _ReceiveQrCard(
              network: network,
              onCopy: () => unawaited(
                _copy(network.address, context.l10n.wallet_readScreensCopy),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: LoopButtonPair(
                padded: false,
                children: <Widget>[
                  LoopButton(
                    key: const ValueKey<String>('receive-copy-address'),
                    label:
                        context.l10n.wallet_readScreensReceiveCopyAddressLabel,
                    primary: true,
                    onPressed: () => unawaited(
                      _copy(
                        network.address,
                        context.l10n.wallet_readScreensCopy,
                      ),
                    ),
                  ),
                  LoopButton(
                    key: const ValueKey<String>('receive-share'),
                    label: context.l10n.common_share,
                    onPressed: () => unawaited(_share(network)),
                  ),
                ],
              ),
            ),
            // S343 · decision 0271: 获取资金 (the testnet faucet) moved here
            // from 我's 充值; only while the server publishes it for the
            // active embedded wallet.
            if (faucetWalletId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: LoopButton(
                  key: const ValueKey<String>('receive-faucet'),
                  label: testnetFaucetTitle,
                  icon: 'droplet',
                  block: true,
                  onPressed: () => unawaited(
                    showTestnetFaucetSheet(
                      context,
                      walletId: faucetWalletId,
                      address: network.address,
                    ),
                  ),
                ),
              ),
            LoopNotice(
              key: const ValueKey<String>('receive-warning'),
              tone: LoopNoticeTone.warn,
              icon: 'warn',
              title: context.l10n.wallet_readScreensReceiveWarningTitle,
              body: loopReceiveWarningText(network.warningKey),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copy(String value, String message) async {
    await LoopCopy.text(context, value, message: message);
  }

  /// Hands the address — and, since decision 0130 (audit 2026-10-09 m12),
  /// the same QR code the page shows, as a PNG drawn on this device — to the
  /// system share sheet. Nothing goes to LOOP. A code that cannot be drawn
  /// falls back to the address alone.
  Future<void> _share(LoopReceiveNetwork network) async {
    final text = LoopL10n.current.wallet_readScreensText(
      network.address,
      network.name,
    );
    final subject = LoopL10n.current.wallet_readScreensSubject(network.name);
    final code = LoopQrCode.encode(network.uri);
    final png = code == null ? null : await receiveQrPng(code);
    if (!mounted) return;
    var shared = false;
    if (png != null) {
      shared = await ref.read(loopImageShareProvider)(
        pngBytes: png,
        fileName: 'loop-receive-${network.chainId}.png',
        text: text,
        subject: subject,
      );
    }
    if (!mounted) return;
    if (!shared) {
      shared = await ref.read(loopTextShareProvider)(text, subject: subject);
    }
    if (!mounted || shared) return;
    LoopToast.show(
      context,
      message: LoopL10n.current.wallet_readScreensMessage,
    );
  }
}

/// The network a receive address is on (UX-016, decision 0257): the chain's
/// logo and name on a light grey capsule — a label, not the solid Purple tab
/// it was. With more than one published network each capsule chooses its
/// own, and the chosen one carries the brighter ground.
class ReceiveNetworkChip extends StatelessWidget {
  const ReceiveNetworkChip({
    required this.network,
    required this.selected,
    super.key,
    this.onTap,
  });

  final LoopReceiveNetwork network;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: selected ? LoopColors.card2 : LoopColors.card,
        borderRadius: LoopRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopNetworkLogo(network: network.chainId, size: 22),
          const SizedBox(width: 8),
          Text(
            network.name,
            maxLines: 1,
            style: LoopTypography.withWeight(
              LoopType.label,
              FontWeight.w600,
            ).copyWith(color: selected ? LoopColors.chalk : LoopColors.text2),
          ),
        ],
      ),
    );
    final tap = onTap;
    return Semantics(
      button: tap != null,
      selected: selected,
      label: context.l10n.wallet_readScreensLabel13(network.name),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
        child: Center(
          widthFactor: 1,
          child: tap == null
              ? chip
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: tap,
                  child: chip,
                ),
        ),
      ),
    );
  }
}

class _ReceiveQrCard extends StatelessWidget {
  const _ReceiveQrCard({required this.network, required this.onCopy});

  final LoopReceiveNetwork network;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    // The EIP-681 string is encoded on the device; the backend never sends an
    // image, and no dependency was added for it (decision 0057).
    final code = LoopQrCode.encode(network.uri);
    return Column(
      key: const ValueKey<String>('receive-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Decision 0171 (docs/33 L15): the prototype's one `.chalk-card` —
        // the code on the Chalk plate and the whole address under it in Ink
        // mono, with the copy glyph at its end. The hand-made Chalk box and
        // the Card address capsule are gone.
        LoopChalkCard(
          key: const ValueKey<String>('receive-chalk-card'),
          light: true,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (code == null)
                LoopInlineUnavailable(
                  key: const ValueKey<String>('receive-qr-unavailable'),
                  message: context.l10n
                      .wallet_readScreensReceiveQrUnavailableMessage(
                        loopReasonCodeText('RECEIVE_QR_ENCODING_FAILED'),
                      ),
                  maxLines: 2,
                  padding: const EdgeInsets.only(right: 8),
                )
              else
                Center(
                  child: Semantics(
                    key: const ValueKey<String>('receive-qr'),
                    image: true,
                    label: context.l10n.wallet_readScreensReceiveQrLabel(
                      network.name,
                    ),
                    child: SizedBox(
                      width: 208,
                      height: 208,
                      child: CustomPaint(painter: _QrPainter(code: code)),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                key: const ValueKey<String>('receive-address-capsule'),
                children: <Widget>[
                  Expanded(
                    child: SelectableText(
                      network.address,
                      key: const ValueKey<String>('receive-address-text'),
                      textAlign: TextAlign.center,
                      style: LoopType.code.copyWith(color: LoopColors.inkText2),
                    ),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('receive-address-copy'),
                    icon: 'copy',
                    label:
                        context.l10n.wallet_readScreensReceiveCopyAddressLabel,
                    color: LoopColors.ink,
                    onPressed: onCopy,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The receive code as a PNG: [size] pixels square, Ink modules on a Chalk
/// plate with the four-module quiet zone, the same drawing the page shows.
/// `null` when the engine could not encode it.
Future<Uint8List?> receiveQrPng(LoopQrCode code, {int size = 1024}) async {
  final recorder = ui.PictureRecorder();
  _QrPainter(code: code)
      .paint(Canvas(recorder), Size(size.toDouble(), size.toDouble()));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(size, size);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  } finally {
    picture.dispose();
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
    final walletLinkBusy = ref.watch(
      emailAuthProvider.select(
        (auth) =>
            auth.activeOperation == IdentityAuthOperation.externalWalletLink ||
            auth.activeOperation == IdentityAuthOperation.externalWalletUnlink,
      ),
    );

    // Decision 0126: a flat list of wallets; the folio that repeated the
    // active address above the row that carries it is gone.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('wallets-screen'),
        onRefresh: controller.reload,
        updating: state.refreshing,
        archetype: LoopPageArchetype.record,
        title: context.l10n.wallet_readScreensWalletsScreenTitle,
        onBack: widget.onBack,
        actions: <Widget>[
          // The prototype's 添加, as a glyph (decision 0087). S306 · decision
          // 0246: it is now 连接外部钱包 — Reown picks the wallet, the owner
          // signs, Privy links it to this account.
          LoopIconButton(
            key: const ValueKey<String>('wallets-add-action'),
            icon: 'plus',
            label: context.l10n.wallet_readScreensWalletsAddActionLabel,
            onPressed: blocked || walletLinkBusy
                ? null
                : () => unawaited(_addExternalWallet()),
            onBlocked: blocked
                ? () => LoopToast.show(
                    context,
                    message: context.l10n.wallet_readScreensMessage2,
                    kind: LoopToastKind.warn,
                  )
                : null,
          ),
        ],
        block: blocked
            ? _walletPageBlock(
                ref,
                key: const ValueKey<String>('wallets-capability-block'),
                title:
                    context.l10n.wallet_readScreensWalletsCapabilityBlockTitle,
              )
            : null,
        sections: <Widget>[
          if (!state.isReady || directory == null)
            LoopChainStateBlock(
              keyPrefix: 'wallets',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage,
              emptyReason: context.l10n.wallet_readScreensEmptyReason,
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
            if (loopChainIsOffline(state.failureKind))
              LoopOfflineState(
                cause: loopOfflineCauseFor(state.failureKind),
                key: const ValueKey<String>('wallets-switch-offline'),
                pausedActions: <String>[
                  context.l10n.wallet_readScreensLoopOfflineState,
                ],
                onRetry: () => unawaited(controller.reload()),
              )
            else if (state.failureKind != null)
              LoopErrorState(
                key: const ValueKey<String>('wallets-switch-error'),
                title: context.l10n.wallet_readScreensWalletsSwitchErrorTitle,
                reason: loopChainFailureReason(state.failureKind),
                onRetry: () => unawaited(controller.reload()),
              ),
            // The prototype puts the identity rule right under the primary,
            // where it explains the list that follows.
            LoopLabel(context.l10n.wallet_readScreensLoopLabel4),
            _WalletList(
              wallets: directory.embedded,
              activeWalletId: directory.activeWalletId,
              busy: state.busy,
              onActivate: (wallet) =>
                  unawaited(_confirmActivate(controller, wallet)),
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage5,
            ),
            LoopLabel(context.l10n.wallet_readScreensLoopLabel5),
            // S306: an external row opens one sheet that offers the switch
            // (when it applies) and 解绑.
            _WalletList(
              wallets: directory.externals,
              activeWalletId: directory.activeWalletId,
              busy: state.busy || walletLinkBusy,
              onActivate: (wallet) =>
                  unawaited(_openExternalWallet(controller, wallet)),
              tapActiveRow: true,
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage6,
            ),
            // The prototype closes this page on mining, because binding an old
            // wallet is how a holding starts counting (S304: an embedded-only
            // rule is a server switch, off by default). S278 · decision 0236:
            // that rule and the identity rule sit behind the source's (i).
            LoopProvenanceFooter(
              key: const ValueKey<String>('wallets-source'),
              margin: const EdgeInsets.fromLTRB(16, 8, 12, 4),
              title: context.l10n.wallet_readScreensWalletsSourceTitle,
              text: context.l10n.wallet_readScreensWalletsSourceText(
                loopRelativeTime(directory.observedAt),
              ),
              notes: <String>[
                context.l10n.wallet_readScreensLoopProvenanceFooter,
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  /// The external-wallet limit in force: the wallet list's own answer, then
  /// the client policy's, then the ruling's three (S306).
  int _externalWalletLimit(LoopWalletDirectory directory) =>
      directory.externalWalletLimit ??
      ref.read(loopExternalWalletLimitPolicyProvider) ??
      loopDefaultExternalWalletLimit;

  /// 添加 · 连接外部钱包 (S306, decision 0246).
  Future<void> _addExternalWallet() async {
    final directory = ref.read(walletDirectoryControllerProvider).value;
    if (directory == null) {
      LoopToast.show(
        context,
        message: LoopL10n.current.wallet_readScreensMessage3,
        kind: LoopToastKind.warn,
      );
      return;
    }
    final limit = _externalWalletLimit(directory);
    // The server's list may still be serving an observation from before the
    // last bind, so the session's own Privy credentials are counted too and
    // the larger of the two decides.
    final credentials =
        ref.read(loopSessionProvider).account?.externalEvmCredentials.length ??
        0;
    final bound = math.max(directory.liveExternals.length, credentials);
    if (bound >= limit) {
      await _showExternalWalletLimit(limit);
      return;
    }
    if (!await _confirmExternalWalletIntro()) return;
    if (!mounted) return;

    final before = _credentialAddresses();
    final auth = ref.read(emailAuthProvider.notifier);
    final outcome = await auth.connectExternalWallet(context);
    if (!mounted) return;
    final message = ref.read(emailAuthProvider).errorMessage;
    auth.clearFeedback();
    switch (outcome) {
      case ExternalWalletConnectOutcome.linked:
        final linked = _credentialAddresses().difference(before);
        final status = await ref
            .read(walletDirectoryControllerProvider.notifier)
            .resyncInventory();
        if (!mounted) return;
        _reportLinkResult(linked, status);
      case ExternalWalletConnectOutcome.failed:
        LoopToast.show(
          context,
          message: message ?? LoopL10n.current.wallet_readScreensMessage4,
          kind: LoopToastKind.err,
          toastKey: const ValueKey<String>('wallets-link-error'),
        );
      case ExternalWalletConnectOutcome.cancelled:
      case ExternalWalletConnectOutcome.ignored:
      case ExternalWalletConnectOutcome.loggedIn:
        break;
    }
  }

  /// The session's Privy external-wallet addresses, lower-cased.
  Set<String> _credentialAddresses() => <String>{
    for (final credential
        in ref.read(loopSessionProvider).account?.externalEvmCredentials ??
            const <PrivyExternalEvmCredentialSummary>[])
      credential.address.toLowerCase(),
  };

  /// After a bind, the synced list may say the server did not accept the
  /// wallet (loop-api decision 0185): past the limit, or owned by another
  /// LOOP account. That answer replaces the success toast.
  void _reportLinkResult(Set<String> linked, WalletInventorySyncStatus status) {
    final directory = ref.read(walletDirectoryControllerProvider).value;
    LoopWalletArchivedReason? refusal;
    if (directory != null && linked.isNotEmpty) {
      for (final wallet in directory.externals) {
        if (wallet.status == LoopWalletStatus.archived &&
            linked.contains(wallet.address.toLowerCase()) &&
            (wallet.archivedReason ==
                    LoopWalletArchivedReason.externalLimitExceeded ||
                wallet.archivedReason ==
                    LoopWalletArchivedReason.addressConflict)) {
          refusal = wallet.archivedReason;
          break;
        }
      }
    }
    switch (refusal) {
      case LoopWalletArchivedReason.externalLimitExceeded:
        final limit = _externalWalletLimit(directory!);
        LoopToast.show(
          context,
          message: LoopL10n.current.wallet_readScreensMessage5(limit),
          kind: LoopToastKind.warn,
          toastKey: const ValueKey<String>('wallets-link-limit'),
        );
        return;
      case LoopWalletArchivedReason.addressConflict:
        LoopToast.show(
          context,
          message: externalWalletLinkedElsewhereMessage,
          kind: LoopToastKind.err,
          toastKey: const ValueKey<String>('wallets-link-conflict'),
        );
        return;
      default:
        break;
    }
    LoopToast.show(
      context,
      message: status == WalletInventorySyncStatus.providerDisconnected
          ? LoopL10n.current.wallet_readScreensMessage6
          : LoopL10n.current.wallet_readScreensMessage7,
      kind: LoopToastKind.ok,
      toastKey: const ValueKey<String>('wallets-link-done'),
    );
  }

  Future<void> _showExternalWalletLimit(int limit) => showLoopSheet<void>(
    context,
    builder: (sheetContext) => Column(
      key: const ValueKey<String>('wallets-limit-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(
          LoopL10n.current.wallet_readScreensLoopSheetHeading(limit),
        ),
        Text(
          LoopL10n.current.wallet_readScreensWalletsLimitSheetBody(limit),
          key: const ValueKey<String>('wallets-limit-sheet-body'),
          style: LoopType.bodySm,
        ),
        const SizedBox(height: 16),
        LoopButton(
          key: const ValueKey<String>('wallets-limit-sheet-close'),
          label: LoopL10n.current.common_gotIt,
          primary: true,
          block: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );

  /// The note in front of the first 连接外部钱包 on this installation. Once
  /// it has been read and continued past, later taps go straight to Reown.
  /// A store that cannot answer shows it again rather than skipping it.
  Future<bool> _confirmExternalWalletIntro() async {
    final store = ref.read(loopExternalWalletIntroStoreProvider);
    try {
      final seen = await store.readSeen().timeout(const Duration(seconds: 1));
      if (seen ?? false) return true;
    } on Object {
      // Not known: show the note.
    }
    if (!mounted) return false;
    final proceed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        key: const ValueKey<String>('wallets-add-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(
            LoopL10n.current.wallet_readScreensLoopSheetHeading2,
          ),
          LoopNotice(
            key: ValueKey<String>('wallets-add-sheet-reason'),
            icon: 'link',
            title:
                LoopL10n.current.wallet_readScreensWalletsAddSheetReasonTitle,
            body: LoopL10n.current.wallet_readScreensWalletsAddSheetReasonBody,
            margin: EdgeInsets.fromLTRB(0, 0, 0, 12),
          ),
          LoopNotice(
            key: ValueKey<String>('wallets-add-sheet-scope'),
            icon: 'info',
            title: LoopL10n.current.wallet_readScreensWalletsAddSheetScopeTitle,
            body: LoopL10n.current.wallet_readScreensWalletsAddSheetScopeBody,
            margin: EdgeInsets.fromLTRB(0, 0, 0, 12),
          ),
          LoopNotice(
            key: ValueKey<String>('wallets-add-sheet-network'),
            icon: 'info',
            tone: LoopNoticeTone.warn,
            title:
                LoopL10n.current.wallet_readScreensWalletsAddSheetNetworkTitle,
            body: LoopL10n.current.wallet_readScreensWalletsAddSheetNetworkBody,
            margin: EdgeInsets.fromLTRB(0, 0, 0, 12),
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('wallets-add-sheet-close'),
                label: LoopL10n.current.common_cancel,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
              LoopButton(
                key: const ValueKey<String>('wallets-add-sheet-continue'),
                label: LoopL10n
                    .current
                    .wallet_readScreensWalletsAddSheetContinueLabel,
                primary: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (!(proceed ?? false)) return false;
    try {
      await store.writeSeen().timeout(const Duration(seconds: 1));
    } on Object {
      // The note shows again next time; nothing else depends on it.
    }
    return true;
  }

  /// An external row: the switch when it applies, and 解绑 (S306).
  Future<void> _openExternalWallet(
    WalletDirectoryController controller,
    LoopWalletAccount wallet,
  ) async {
    final canActivate =
        wallet.walletId !=
        ref.read(walletDirectoryControllerProvider).value?.activeWalletId;
    final choice = await showLoopSheet<_ExternalWalletChoice>(
      context,
      builder: (sheetContext) => Column(
        key: const ValueKey<String>('wallets-external-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(
            LoopL10n.current.wallet_readScreensLoopSheetHeading3(
              wallet.truncatedAddress,
            ),
          ),
          if (canActivate) ...<Widget>[
            Text(
              LoopL10n.current.wallet_readScreensOpenExternalWallet(
                wallet.truncatedAddress,
              ),
              style: LoopType.bodySm,
            ),
            const SizedBox(height: 16),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  label: LoopL10n.current.common_cancel,
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
                LoopButton(
                  key: const ValueKey<String>('wallets-activate-confirm'),
                  label: LoopL10n
                      .current
                      .wallet_readScreensWalletsActivateConfirmLabel,
                  primary: true,
                  onPressed: () =>
                      Navigator.of(sheetContext)
                          .pop(_ExternalWalletChoice.activate),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          LoopButton(
            key: const ValueKey<String>('wallets-unlink-action'),
            label: LoopL10n.current.wallet_readScreensWalletsUnlinkActionLabel,
            block: true,
            onPressed: () =>
                Navigator.of(sheetContext).pop(_ExternalWalletChoice.unlink),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _ExternalWalletChoice.activate:
        await _activate(controller, wallet);
      case _ExternalWalletChoice.unlink:
        await _confirmUnlink(controller, wallet);
      case null:
        break;
    }
  }

  Future<void> _confirmUnlink(
    WalletDirectoryController controller,
    LoopWalletAccount wallet,
  ) async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        key: const ValueKey<String>('wallets-unlink-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(
            LoopL10n.current.wallet_readScreensLoopSheetHeading4,
          ),
          Text(
            LoopL10n.current.wallet_readScreensWalletsUnlinkSheetBody(
              wallet.truncatedAddress,
            ),
            key: const ValueKey<String>('wallets-unlink-sheet-body'),
            style: LoopType.bodySm,
          ),
          const SizedBox(height: 16),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('wallets-unlink-cancel'),
                label: LoopL10n.current.common_cancel,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
              LoopButton(
                key: const ValueKey<String>('wallets-unlink-confirm'),
                label: LoopL10n
                    .current
                    .wallet_readScreensWalletsUnlinkConfirmLabel,
                primary: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    final auth = ref.read(emailAuthProvider.notifier);
    final unlinked = await auth.unlinkExternalWallet(wallet.address);
    if (!mounted) return;
    final message = ref.read(emailAuthProvider).errorMessage;
    auth.clearFeedback();
    if (!unlinked) {
      LoopToast.show(
        context,
        message: message ?? LoopL10n.current.wallet_readScreensMessage8,
        kind: LoopToastKind.err,
        toastKey: const ValueKey<String>('wallets-unlink-error'),
      );
      return;
    }
    final status = await controller.resyncInventory();
    if (!mounted) return;
    LoopToast.show(
      context,
      message: status == WalletInventorySyncStatus.providerDisconnected
          ? LoopL10n.current.wallet_readScreensMessage9
          : LoopL10n.current.wallet_readScreensMessage10,
      kind: LoopToastKind.ok,
      toastKey: const ValueKey<String>('wallets-unlink-done'),
    );
  }

  Future<void> _confirmActivate(
    WalletDirectoryController controller,
    LoopWalletAccount wallet,
  ) async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopSheetHeading(LoopL10n.current.wallet_readScreensLoopOfflineState),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                LoopL10n.current.wallet_readScreensOpenExternalWallet(
                  wallet.truncatedAddress,
                ),
                style: LoopType.bodySm,
              ),
              const SizedBox(height: 16),
              LoopButtonPair(
                children: <Widget>[
                  LoopButton(
                    label: LoopL10n.current.common_cancel,
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                  ),
                  LoopButton(
                    key: const ValueKey<String>('wallets-activate-confirm'),
                    label: LoopL10n
                        .current
                        .wallet_readScreensWalletsActivateConfirmLabel,
                    primary: true,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _activate(controller, wallet);
  }

  Future<void> _activate(
    WalletDirectoryController controller,
    LoopWalletAccount wallet,
  ) async {
    final switched = await controller.setActive(wallet.walletId);
    if (!mounted) return;
    if (switched) {
      LoopToast.show(
        context,
        message: LoopL10n.current.wallet_readScreensMessage11,
        kind: LoopToastKind.ok,
      );
    }
  }
}

enum _ExternalWalletChoice { activate, unlink }

class _WalletList extends StatelessWidget {
  const _WalletList({
    required this.wallets,
    required this.activeWalletId,
    required this.busy,
    required this.onActivate,
    required this.emptyMessage,
    this.tapActiveRow = false,
  });

  final List<LoopWalletAccount> wallets;
  final String? activeWalletId;
  final bool busy;
  final void Function(LoopWalletAccount wallet) onActivate;
  final String emptyMessage;

  /// Whether the row already in use still opens [onActivate]. The external
  /// rows do (S306): their sheet carries 解绑 as well as the switch.
  final bool tapActiveRow;

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) {
      return LoopEmptyState(
        key: ValueKey<String>('wallets-empty-$emptyMessage'),
        illustration: LoopIllustration.profile,
        title: emptyMessage,
        compact: true,
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
              circle: true,
              icon: wallet.kind == LoopWalletKind.embedded ? 'wallet' : 'link',
            ),
            // The prototype marks the wallet in use on the row itself, not
            // only with the badge in the value column.
            selected: wallet.walletId == activeWalletId,
            // Decision 0126: the section already names the kind, so the row
            // leads with the wallet's own address. Truncation is a display
            // concern; the request only ever carries `walletId`.
            title: wallet.truncatedAddress,
            subtitle:
                '${wallet.kind == LoopWalletKind.embedded ? context.l10n.wallet_readScreensLoopLabel4 : context.l10n.wallet_readScreensExternalWalletKind} · '
                '${wallet.status == LoopWalletStatus.archived ? context.l10n.wallet_readScreensLoopBadge3 : context.l10n.wallet_readScreensLabel5}',
            trailingBadge: wallet.walletId == activeWalletId
                ? LoopBadge(
                    context.l10n.wallet_readScreensLoopBadge2,
                    kind: LoopBadgeKind.up,
                  )
                : wallet.status == LoopWalletStatus.archived
                ? LoopBadge(context.l10n.wallet_readScreensLoopBadge3)
                : null,
            onTap:
                busy ||
                    (!tapActiveRow && wallet.walletId == activeWalletId) ||
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

/// `tx-history` · indexed ERC-20 transfers for one wallet, and — once the
/// server merges them (decision 0213) — the wallet's Launch-chain MEME v2
/// facts in the same tape.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    this.walletId,
    this.onBack,
    this.onNavigate,
  });

  final String? walletId;
  final VoidCallback? onBack;

  /// Opens a location (a MEME v2 row opens its project page); `null` pushes
  /// it on the app router.
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

/// The wallet's activity tape (S349): the filter chips, the rows by day, the
/// indexer's freshness and the next page as the reader scrolls on.
///
/// `tx-history` and 我的 · 交易 draw the same tape; each page keeps its own
/// filter and its own "next page on its way". The sections are returned one
/// by one, so the page's own list builds the load-more sentinel only when the
/// reader nears it.
mixin _WalletActivityTape<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// The selected filter chip: 全部 / 收到 / 发出 / 原生转账 / 跨链 · 挖矿.
  int tapeSegment = 0;

  /// A next page is on its way; one skeleton row stands at the end of the
  /// tape until it lands.
  bool _tapeLoadingMore = false;

  /// Opens a location a row links to (a MEME v2 row opens its project).
  void openFromTape(String location);

  Future<void> _loadMoreActivity(String walletId) async {
    if (_tapeLoadingMore) return;
    setState(() => _tapeLoadingMore = true);
    try {
      await ref
          .read(walletActivityControllerProvider(walletId).notifier)
          .loadMore();
    } finally {
      if (mounted) setState(() => _tapeLoadingMore = false);
    }
  }

  /// Starts the first read of [walletId]'s tape and returns its state.
  LoopChainResourceState<LoopWalletActivityPage> watchActivity(
    String walletId,
  ) {
    final state = ref.watch(walletActivityControllerProvider(walletId));
    if (state.phase == LoopChainViewPhase.loading) {
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
    return state;
  }

  /// The rows the selected chip lists, in the order it lists them.
  List<LoopWalletActivityEntry> tapeSegmentRows(
    LoopWalletActivityPage page,
  ) => switch (tapeSegment) {
    1 =>
      page.items
          .where((entry) => entry.direction == LoopTransferDirection.incoming)
          .toList(growable: false),
    2 =>
      page.items
          .where((entry) => entry.direction == LoopTransferDirection.outgoing)
          .toList(growable: false),
    3 || 4 => const <LoopWalletActivityEntry>[],
    _ => page.items,
  };

  /// The tape of [walletId] in each of its states, keyed under [keyPrefix].
  ///
  /// [underTabs] (S350c · decision 0276): the tape is a section under 我的's
  /// 持仓 / 交易 / 社区, so its chips are drawn as filters one step below
  /// those tabs, and an empty tape says only that it is empty.
  List<Widget> activityTapeSections({
    required String walletId,
    required LoopChainResourceState<LoopWalletActivityPage> state,
    required String keyPrefix,
    bool underTabs = false,
  }) {
    final page = state.value;
    final segments = _ActivitySegments(
      keyPrefix: keyPrefix,
      selected: tapeSegment,
      filter: underTabs,
      onSelected: (index) => setState(() => tapeSegment = index),
    );
    void reload() => unawaited(
      ref.read(walletActivityControllerProvider(walletId).notifier).reload(),
    );
    void loadMore() => unawaited(
      ref.read(walletActivityControllerProvider(walletId).notifier).loadMore(),
    );
    // Decision 0132: the first page loads as the tape it becomes — the
    // filter chips (they need no answer) over rows shaped like
    // [walletActivityRow] — so nothing moves when it lands.
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return <Widget>[
        segments,
        KeyedSubtree(
          key: ValueKey<String>('$keyPrefix-state-loading'),
          child: const WalletActivitySkeleton(),
        ),
      ];
    }
    if (page == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: keyPrefix,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: LoopL10n.current.wallet_readScreensEmptyMessage7,
          emptyReason: underTabs
              ? null
              : LoopL10n.current.wallet_readScreensEmptyReason2,
          onRetry: reload,
        ),
      ];
    }
    return <Widget>[
      segments,
      ..._tapeSegmentBody(page, keyPrefix),
      LoopProvenanceFooter(
        key: ValueKey<String>('$keyPrefix-freshness'),
        text: <String>[
          LoopL10n.current.wallet_readScreensLoopProvenanceFooter2(
            loopGroupedFigure(page.freshness.indexerBlockNumber.toString()),
          ),
          if (page.freshness.lagBlocks != null)
            LoopL10n.current.wallet_readScreensLoopProvenanceFooter3(
              loopGroupedFigure(page.freshness.lagBlocks.toString()),
            ),
          LoopL10n.current.wallet_readScreensSwitch3(
            loopRelativeTime(page.freshness.observedAt),
          ),
        ].join(' · '),
      ),
      // The pages already read stay on screen. A next page that never
      // reached the server is a pause on "load more", not a broken tape.
      if (loopChainIsOffline(state.failureKind))
        LoopOfflineState(
          cause: loopOfflineCauseFor(state.failureKind),
          key: ValueKey<String>('$keyPrefix-page-offline'),
          pausedActions: <String>[
            LoopL10n.current.wallet_readScreensLoopOfflineState2,
          ],
          onRetry: loadMore,
        )
      else if (state.failureKind != null)
        LoopErrorState(
          key: ValueKey<String>('$keyPrefix-page-error'),
          title: LoopL10n.current.wallet_readScreensTitle,
          reason: loopChainFailureReason(state.failureKind),
          onRetry: loadMore,
        )
      // v3 需求 6.2 · 4 (decision 0119): the tape scrolls on. The sentinel
      // asks for the next cursor once it is built — that is, once the reader
      // has scrolled near the end — and each cursor once.
      else if (page.nextCursor case final String cursor) ...<Widget>[
        LoopLoadMoreSentinel(
          key: ValueKey<String>('$keyPrefix-load-more'),
          cursor: cursor,
          onLoadMore: () => unawaited(_loadMoreActivity(walletId)),
        ),
        if (_tapeLoadingMore)
          KeyedSubtree(
            key: ValueKey<String>('$keyPrefix-loading-more'),
            child: const WalletActivitySkeleton(rows: 1),
          ),
      ] else if (page.rows.isNotEmpty)
        // S121 §1.1.1 #10: the end of the tape draws nothing.
        SizedBox(key: ValueKey<String>('$keyPrefix-end'), height: 12),
    ];
  }

  List<Widget> _tapeSegmentBody(LoopWalletActivityPage page, String keyPrefix) {
    switch (tapeSegment) {
      case 1:
      case 2:
        return <Widget>[_activityList(tapeSegmentRows(page), keyPrefix)];
      case 3:
        return <Widget>[
          LoopUnavailableLine.fact(
            key: ValueKey<String>('$keyPrefix-native-unavailable'),
            label: LoopL10n.current.wallet_readScreensLabel14,
            fact: page.nativeTransfers,
          ),
        ];
      case 4:
        return <Widget>[
          LoopUnavailableLine.fact(
            key: ValueKey<String>('$keyPrefix-cross-chain-unavailable'),
            label: LoopL10n.current.wallet_readScreensLabel15,
            fact: page.crossChain,
          ),
        ];
      default:
        return <Widget>[
          // Decision 0213: the MEME rows the server could not merge are a
          // stated gap at the head of the tape, never "no MEME records".
          if (page.launch2?.unavailable case final LoopUnavailable missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LoopUnavailableLine.fact(
                key: ValueKey<String>('$keyPrefix-launch2-unavailable'),
                label: LoopL10n.current.wallet_readScreensLabel16,
                fact: missing,
              ),
            ),
          _activityList(page.rows, keyPrefix),
        ];
    }
  }

  Widget _activityList(
    List<LoopWalletActivityRecord> entries,
    String keyPrefix,
  ) {
    if (entries.isEmpty) {
      return LoopEmptyState(
        key: ValueKey<String>('$keyPrefix-empty'),
        illustration: LoopIllustration.history,
        title: LoopL10n.current.wallet_readScreensTitle2,
        compact: true,
      );
    }
    // Decision 0133 (audit m13): the tape is read by day, as a bank or
    // wallet statement is — one small header per local day, rows unchanged.
    return Column(
      key: ValueKey<String>('$keyPrefix-days'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final day in walletActivityDays(entries)) ...<Widget>[
          WalletActivityDayHeader(
            key: ValueKey<String>('$keyPrefix-day-${day.key}'),
            label: day.label,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              for (final entry in day.entries)
                switch (entry) {
                  LoopWalletActivityEntry() => walletActivityRow(
                    entry,
                    // A tape row used to take the tap and do nothing: the
                    // hash it printed was truncated, could not be copied, and
                    // led nowhere.
                    onTap: () => unawaited(
                      showLoopSheet<void>(
                        context,
                        builder: (sheetContext) =>
                            WalletActivityDetailSheet(entry: entry),
                      ),
                    ),
                  ),
                  // A MEME v2 fact opens its project (decision 0213).
                  LoopWalletLaunch2ActivityEntry() => walletLaunch2ActivityRow(
                    entry,
                    onTap: () =>
                        openFromTape(Launch2Route.instance(entry.instanceId)),
                  ),
                },
            ],
          ),
        ],
      ],
    );
  }
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen>
    with _WalletActivityTape<TransactionHistoryScreen> {
  bool _exporting = false;

  @override
  void openFromTape(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    unawaited(context.push(location));
  }

  /// Encodes the rows the selected chip lists and hands them to the share
  /// sheet. The two chips that carry an unavailable fact rather than a list
  /// have nothing to encode, and say so instead of exporting a file with
  /// only a header in it.
  Future<void> _export(LoopWalletActivityPage page) async {
    if (_exporting) return;
    final rows = tapeSegmentRows(page);
    if (rows.isEmpty) {
      LoopToast.show(
        context,
        message: walletExportMessage(WalletExportOutcome.empty),
        kind: LoopToastKind.warn,
      );
      return;
    }
    setState(() => _exporting = true);
    final directory = ref.read(walletDirectoryControllerProvider).value;
    final address =
        directory?.wallets
            .where((wallet) => wallet.walletId == page.walletId)
            .firstOrNull
            ?.address ??
        page.walletId;
    final outcome = await ref
        .read(walletActivityExportSinkProvider)
        .shareCsv(
          csv: walletActivityCsv(rows),
          fileName: walletActivityCsvFileName(
            walletAddress: address,
            now: DateTime.now(),
          ),
        );
    if (!mounted) return;
    setState(() => _exporting = false);
    LoopToast.show(
      context,
      message: walletExportMessage(outcome),
      kind: outcome == WalletExportOutcome.shared
          ? LoopToastKind.ok
          : LoopToastKind.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _walletBlocked(ref);
    final walletId =
        widget.walletId ?? _watchActiveWalletId(ref, blocked: blocked);
    // A walletless account is not a page that is still loading.
    final noWalletYet = _noWalletYet(ref) && walletId == null;
    final state = walletId == null ? null : watchActivity(walletId);
    final page = state?.value;

    // Decision 0126: a flat record page — chips, OKX record rows, nothing
    // at the end. The folio that counted the rows is gone.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('tx-history-screen'),
        onRefresh: walletId == null
            ? null
            : () => ref
                  .read(walletActivityControllerProvider(walletId).notifier)
                  .reload(),
        updating: state?.refreshing ?? false,
        archetype: LoopPageArchetype.record,
        title: context.l10n.wallet_readScreensWalletAssetHistoryEntryTitle,
        onBack: widget.onBack,
        actions: <Widget>[
          // The prototype's 导出, doing what it says: the rows this page is
          // currently listing are encoded as CSV on device and handed to the
          // system share sheet. Nothing is uploaded, and nothing beyond what is
          // on screen is fetched. Decision 0087 draws it as the share glyph —
          // 「交给系统」 is exactly what the tap does — and the name still
          // switches to 导出中 while a run is in flight, because that state was
          // only ever carried by the word.
          LoopIconButton(
            key: const ValueKey<String>('tx-history-export-action'),
            icon: 'share',
            label: _exporting
                ? context.l10n.wallet_readScreensTxHistoryExportActionLabel
                : context.l10n.wallet_readScreensTxHistoryExportActionLabel2,
            onPressed: page == null || _exporting
                ? null
                : () => unawaited(_export(page)),
            onBlocked: page != null
                ? null
                : () => LoopToast.show(
                    context,
                    message: context.l10n.wallet_readScreensMessage12,
                    kind: LoopToastKind.warn,
                  ),
          ),
        ],
        block: blocked
            ? _walletPageBlock(
                ref,
                key: const ValueKey<String>('tx-history-capability-block'),
                title:
                    context.l10n.wallet_readScreensMeTradesCapabilityBlockTitle,
              )
            : null,
        sections: <Widget>[
          if (noWalletYet)
            const WalletCreationBlock(keyPrefix: 'tx-history')
          else if (walletId == null || state == null)
            LoopChainStateBlock(
              keyPrefix: 'tx-history',
              phase: LoopChainViewPhase.loading,
              failureKind: null,
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage7,
            )
          else
            ...activityTapeSections(
              walletId: walletId,
              state: state,
              keyPrefix: 'tx-history',
            ),
        ],
      ),
    );
  }
}

/// One indexed transfer, opened from a `tx-history` row.
///
/// It is not `tx-result`: that page reports an intent this device prepared and
/// polls its state. An indexed transfer has no intent — it may predate the
/// account, or have been signed elsewhere — so what this sheet can offer is
/// the record itself, in full, with the two identifiers a reader can take
/// somewhere else: the transaction hash and the explorer address that
/// resolves it.
class WalletActivityDetailSheet extends StatelessWidget {
  const WalletActivityDetailSheet({required this.entry, super.key});

  final LoopWalletActivityEntry entry;

  /// The block explorer that resolves this hash, chosen by the chain the
  /// asset id names. An asset on a chain LOOP does not publish gets no link
  /// rather than a guessed one.
  static String? explorerUrl(LoopWalletActivityEntry entry) {
    final chainId = entry.assetId.substring(0, entry.assetId.lastIndexOf(':'));
    final host = switch (chainId) {
      loopPrimaryChainId => 'bscscan.com',
      loopLaunchTestnetChainId => 'testnet.bscscan.com',
      _ => null,
    };
    return host == null ? null : 'https://$host/tx/${entry.transactionHash}';
  }

  void _copy(
    BuildContext context, {
    required String value,
    required String what,
  }) {
    unawaited(
      LoopCopy.text(
        context,
        value,
        message: context.l10n.wallet_readScreensMessage13(what),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = explorerUrl(entry);
    return Column(
      key: const ValueKey<String>('tx-entry-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSheetHeading(context.l10n.wallet_readScreensLoopSheetHeading5),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  LoopKeyValue(
                    label: context.l10n.wallet_activityExportSwitch2,
                    value: switch (entry.direction) {
                      LoopTransferDirection.incoming =>
                        context.l10n.wallet_activityExportIncoming,
                      LoopTransferDirection.outgoing =>
                        context.l10n.wallet_activityExportOutgoing,
                      LoopTransferDirection.self =>
                        context.l10n.wallet_activityExportSelf,
                    },
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.common_amount,
                    value:
                        '${loopFormatDecimal(entry.displayValue)} ${loopDisplaySymbol(entry.symbol)}',
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.wallet_activityExportSwitch5,
                    value: entry.counterpartyAddress,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.common_network,
                    value: _assetChainName(entry.assetId),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.wallet_activityExportSwitch7,
                    value: loopGroupedFigure(entry.blockNumber.toString()),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.wallet_activityExportSwitch8,
                    value: loopConfirmationLabel(entry.status),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  LoopKeyValue(
                    label: context.l10n.wallet_homeLabel5,
                    value: loopRelativeTime(entry.observedAt),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LoopLabel(context.l10n.wallet_txResultTxResultHashLabel),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText(
                entry.transactionHash,
                key: const ValueKey<String>('tx-entry-sheet-hash'),
                style: LoopType.code.copyWith(color: LoopColors.text2),
              ),
            ),
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('tx-entry-sheet-copy-hash'),
                  label:
                      context.l10n.wallet_readScreensTxEntrySheetCopyHashLabel,
                  primary: true,
                  onPressed: () => _copy(
                    context,
                    value: entry.transactionHash,
                    what: context.l10n.wallet_txResultTxResultHashLabel,
                  ),
                ),
                if (url != null)
                  LoopButton(
                    key: const ValueKey<String>('tx-entry-sheet-copy-link'),
                    label: context
                        .l10n
                        .wallet_readScreensTxEntrySheetCopyLinkLabel,
                    onPressed: () => _copy(
                      context,
                      value: url,
                      what: context.l10n.wallet_readScreensWhat,
                    ),
                  ),
              ],
            ),
            if (url != null) ...<Widget>[
              const SizedBox(height: 10),
              SelectableText(
                url,
                key: const ValueKey<String>('tx-entry-sheet-link'),
                style: LoopType.codeSm.copyWith(color: LoopColors.text2),
              ),
            ],
            // Opening an external browser needs a launcher this build does not
            // compose, so the sheet hands over the address instead of promising
            // a jump it cannot make.
            LoopNotice(
              key: ValueKey<String>('tx-entry-sheet-explorer-notice'),
              icon: 'info',
              title: context
                  .l10n
                  .wallet_readScreensTxEntrySheetExplorerNoticeTitle,
              body:
                  context.l10n.wallet_readScreensTxEntrySheetExplorerNoticeBody,
              margin: EdgeInsets.fromLTRB(0, 12, 0, 0),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivitySegments extends StatelessWidget {
  const _ActivitySegments({
    required this.keyPrefix,
    required this.selected,
    required this.onSelected,
    this.filter = false,
  });

  final String keyPrefix;
  final int selected;
  final ValueChanged<int> onSelected;

  /// S350c: the framed filter chips 我的 draws under its tabs, as
  /// [WalletAssetTabs] does under 持仓, from the page line.
  final bool filter;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      context.l10n.common_all,
      context.l10n.wallet_activityExportIncoming,
      context.l10n.wallet_activityExportOutgoing,
      context.l10n.wallet_readScreensBuild,
      context.l10n.wallet_readScreensBuild2,
    ];
    return Padding(
      padding: filter
          ? EdgeInsets.fromLTRB(
              0,
              LoopSpacing.segmentGap -
                  (LoopSeg.segmentTarget - WalletAssetTabs.filterHeight) / 2,
              0,
              4,
            )
          : const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: filter
            ? const EdgeInsets.symmetric(horizontal: LoopSpacing.page)
            : null,
        // The chosen chip's splat reaches above its capsule.
        clipBehavior: filter ? Clip.none : Clip.hardEdge,
        child: Row(
          children: <Widget>[
            for (final (index, label) in labels.indexed) ...<Widget>[
              if (filter && index > 0) const SizedBox(width: LoopSpacing.tight),
              LoopSeg(
                key: ValueKey<String>('$keyPrefix-seg-$index'),
                quiet: !filter,
                label: label,
                selected: index == selected,
                capsuleHeight: filter ? WalletAssetTabs.filterHeight : null,
                onSelected: () => onSelected(index),
              ),
              if (!filter) const SizedBox(width: 8),
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

    // Decision 0126: flat. The folio's 「1 / 4 正常」 is the chain row's own
    // badge; the endpoint detail stays one tap away below.
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('networks-screen'),
        onRefresh: ref.read(chainStatusControllerProvider.notifier).reload,
        updating: state.refreshing,
        archetype: LoopPageArchetype.record,
        title: context.l10n.wallet_readScreensNetworksScreenTitle,
        onBack: widget.onBack,
        block: blocked
            ? LoopCapabilityPageBlock.of(
                key: const ValueKey<String>('networks-capability-block'),
                title:
                    context.l10n.wallet_readScreensNetworksCapabilityBlockTitle,
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
              emptyMessage: context.l10n.wallet_readScreensEmptyMessage8,
              onRetry: () => unawaited(
                ref.read(chainStatusControllerProvider.notifier).reload(),
              ),
            )
          else if (status.chainIdMismatched)
            LoopUnavailableLine(
              key: ValueKey<String>('networks-chain-mismatch'),
              label: context.l10n.wallet_readScreensNetworksChainMismatchLabel,
              reasonCode: 'BSC_CHAIN_ID_MISMATCH',
            )
          else ...<Widget>[
            LoopLabel(context.l10n.wallet_readScreensLoopLabel6),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('networks-chain-row'),
                  // The prototype's chain rows all carry the chain's own logo;
                  // the app's row had no leading column at all (audit item 7).
                  leading: const LoopNetworkLogo(network: 'bsc', size: 36),
                  title: status.chain.name,
                  // 延迟 is what the prototype's row says, and it is the one
                  // fact a reader can act on. The chain id, the confirmation
                  // depth and the reorg window are operator facts; they moved
                  // into the disclosure below with the endpoints.
                  subtitle: _chainLatencyText(status),
                  subtitleMaxLines: 2,
                  // Decision 0126: the folio's 「1 / 4 正常」 is this row's value now.
                  // Lime is the success colour, so it follows the majority of what was
                  // measured; the head block moved into the operator line below.
                  trailing: status.rpc.endpoints.isEmpty
                      ? null
                      : context.l10n.wallet_readScreensNetworksChainRowTrailing(
                          status.rpc.endpoints.length,
                          status.rpc.healthyCount,
                        ),
                  trailingColor:
                      status.rpc.endpoints.isNotEmpty &&
                          status.rpc.healthyCount * 2 >=
                              status.rpc.endpoints.length
                      ? LoopColors.yellow
                      : LoopColors.chalk,
                  // The 正常 / 异常 pill said the count's news twice; it stays
                  // only when there is no count to read.
                  trailingBadge: status.rpc.endpoints.isNotEmpty
                      ? null
                      : LoopBadge(
                          status.rpc.available
                              ? context.l10n.common_normal
                              : context.l10n.wallet_readScreensS,
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
            LoopLabel(context.l10n.common_settings),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('networks-custom-rpc'),
                  title: context.l10n.wallet_readScreensNetworksCustomRpcTitle,
                  subtitle: loopReasonCodeText('WALLET_CUSTOM_RPC_DEFERRED'),
                  subtitleMaxLines: 2,
                  trailingBadge: LoopBadge(context.l10n.common_unavailable),
                ),
                // Decision 0204: the whole row is a test-only hint.
                if (loopTestHintsVisible)
                  LoopRecordRow(
                    key: const ValueKey<String>('networks-testnet'),
                    title: loopTestnetNetworkRowTitle,
                    // Decision 0038: the Launch slot is the only testnet the
                    // product has, and it is published by the server, never
                    // toggled here.
                    subtitle: status.launchChain == null
                        ? loopTestnetNetworkRowAbsent
                        : context.l10n
                              .wallet_readScreensNetworksTestnetSubtitle(
                                status.launchChain!.name,
                              ),
                    trailingBadge: LoopBadge(
                      status.launchChain == null
                          ? context.l10n.wallet_readScreensLoopBadge4
                          : context.l10n.wallet_readScreensS2,
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
              summary: context
                  .l10n
                  .wallet_readScreensNetworksOperatorDisclosureSummary,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LoopProvenanceFooter(
                      key: const ValueKey<String>('networks-chain-parameters'),
                      text: context.l10n
                          .wallet_readScreensNetworksChainParametersText(
                            status.chain.chainId,
                            loopGroupedFigure(
                              status.chain.confirmations.toString(),
                            ),
                            loopGroupedFigure(
                              status.chain.reorgDepthBlocks.toString(),
                            ),
                            status.rpc.head == null
                                ? ''
                                : context.l10n.wallet_readScreensS3X(
                                    loopGroupedFigure(
                                      status.rpc.head!.blockNumber.toString(),
                                    ),
                                  ),
                          ),
                    ),
                    LoopLabel(
                      context.l10n.wallet_readScreensLoopLabel7,
                      tight: true,
                    ),
                    if (status.rpc.endpoints.isEmpty)
                      LoopUnavailableLine(
                        key: const ValueKey<String>('networks-no-endpoints'),
                        label: context
                            .l10n
                            .wallet_readScreensNetworksNoEndpointsLabel,
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
                    LoopLabel(
                      context.l10n.wallet_readScreensLoopLabel8,
                      tight: true,
                    ),
                    LoopRecordGroup(
                      rows: <LoopRecordRow>[
                        for (final lane in status.indexer)
                          LoopRecordRow(
                            key: ValueKey<String>('lane-${lane.lane.wireName}'),
                            title: loopIndexerLaneLabel(lane.lane),
                            subtitle: lane.available
                                ? <String>[
                                    if (lane.lastBlockNumber != null)
                                      context.l10n
                                          .wallet_readScreensLoopRecordRow(
                                            loopGroupedFigure(
                                              lane.lastBlockNumber.toString(),
                                            ),
                                          ),
                                    if (lane.lagBlocks != null)
                                      context.l10n
                                          .wallet_readScreensLoopRecordRow2(
                                            loopGroupedFigure(
                                              lane.lagBlocks.toString(),
                                            ),
                                          ),
                                    if (lane.reorgCount != null)
                                      context.l10n
                                          .wallet_readScreensLoopRecordRow3(
                                            lane.reorgCount!,
                                          ),
                                    if (lane.updatedAt != null)
                                      loopRelativeTime(lane.updatedAt!),
                                  ].join(' · ')
                                : loopReasonCodeText(lane.reasonCode),
                            trailingBadge: LoopBadge(
                              lane.available
                                  ? context.l10n.wallet_readScreensLoopBadge5
                                  : context.l10n.wallet_readScreensS3,
                              kind: lane.available
                                  ? LoopBadgeKind.up
                                  : LoopBadgeKind.down,
                            ),
                          ),
                      ],
                    ),
                    LoopProvenanceFooter(
                      key: const ValueKey<String>('networks-registry'),
                      text: context.l10n.wallet_readScreensNetworksRegistryText(
                        status.registry.readableAssetCount,
                        status.registry.registeredPoolCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
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
    if (best != null)
      LoopL10n.current.wallet_readScreensFor(best)
    else
      LoopL10n.current.wallet_readScreensFor2,
    if (head != null)
      LoopL10n.current.wallet_readScreensSwitch3(
        loopRelativeTime(head.observedAt),
      ),
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
        LoopL10n.current.wallet_readScreensLoopRecordRow4(index + 1),
        if (endpoint.latencyMs != null)
          LoopL10n.current.wallet_readScreensFor(endpoint.latencyMs)
        else
          LoopL10n.current.wallet_readScreensFor2,
        if (endpoint.blockLagBlocks != null)
          LoopL10n.current.wallet_readScreensLoopRecordRow2(
            loopGroupedFigure(endpoint.blockLagBlocks.toString()),
          ),
        LoopL10n.current.wallet_readScreensLoopRecordRow6(
          endpoint.chainVerification.label,
        ),
        loopRelativeTime(endpoint.observedAt),
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: endpoint.blockNumber == null
          ? null
          : loopGroupedFigure(endpoint.blockNumber.toString()),
      trailingBadge: LoopBadge(switch (endpoint.status) {
        LoopEndpointStatus.healthy => LoopL10n.current.common_normal,
        LoopEndpointStatus.degraded => LoopL10n.current.wallet_readScreensS,
        LoopEndpointStatus.unreachable =>
          LoopL10n.current.wallet_readScreensUnreachable,
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
      return LoopUnavailableLine(
        key: const ValueKey<String>('networks-launch-chain-unavailable'),
        label: context.l10n
            .wallet_readScreensNetworksLaunchChainUnavailableLabel(
              launchChain.name,
            ),
        reasonCode: reasonCode!,
      );
    }
    final head = launchChain.head;
    // Three states, not two: verified is 正常, a verification that has not
    // finished yet is 待校验 — neither a fault nor a proof — and only an
    // unreachable or mismatched endpoint is 异常.
    final pending = reasonCode == 'LAUNCH_CHAIN_VERIFICATION_PENDING';
    final (String badge, LoopBadgeKind kind) = switch (launchChain.isHealthy) {
      true => (context.l10n.common_normal, LoopBadgeKind.up),
      false when pending => (
        context.l10n.wallet_readScreensSwitch5,
        LoopBadgeKind.mute,
      ),
      false => (context.l10n.wallet_readScreensS, LoopBadgeKind.down),
    };
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('networks-launch-chain-row'),
          title: context.l10n.wallet_readScreensLaunchChainTitle(
            launchChain.name,
          ),
          subtitle: reasonCode == null
              ? context.l10n.wallet_readScreensNetworksLaunchChainRowSubtitle(
                  launchChain.chainId,
                  loopGroupedFigure(launchChain.confirmations.toString()),
                  loopGroupedFigure(launchChain.reorgDepthBlocks.toString()),
                )
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
