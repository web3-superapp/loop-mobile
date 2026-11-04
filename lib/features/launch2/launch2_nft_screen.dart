import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_card.dart';
import 'package:loop_mobile/features/launch2/launch2_nft_mint.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';
import 'package:loop_mobile/features/wallet/nft_send.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

// ---------------------------------------------------------------------------
// `launch2-nft` · 共识勋章 (decision 0163, docs/32 §4)
// ---------------------------------------------------------------------------
//
// One instance's NFT as a page of its own, in the prototype's parts
// (decision 0164): a quiet ledger card with the stage and its countdown, the
// medal under it, what the medal does and the rules as `.label` rows, what
// this wallet holds as `.kv` and the one button. The page reads the project page's own instance read
// (`launch2InstanceControllerProvider`), and its 「铸造」 is the project
// page's own trip ([launch2MintNft]). A Purple ring marks the medal here
// (decision 0212, S257 — Brass retired from this page); the main button is
// the ordinary yellow primary.

/// What the main button does.
enum Launch2NftAction {
  /// The NFT mint trip.
  mint,

  /// The project page, where the curve and the pool trade.
  openProject,

  /// Nothing now: the button is drawn disabled.
  none,
}

/// The page's ledger card, button and medal for one instance read
/// (docs/32 §4.2).
@immutable
final class Launch2NftView {
  const Launch2NftView({
    required this.status,
    required this.statusLit,
    required this.buttonLabel,
    required this.action,
    required this.litRing,
    required this.medalLabel,
    this.countdownTo,
    this.stampPrefix,
    this.statusDetail,
  });

  /// The stage sentence, the first part of the ledger card's caption.
  final String status;

  /// The ledger card's stamp counts down to this.
  final DateTime? countdownTo;

  /// The words before the stamp's countdown.
  /// `null` reads 「剩」.
  final String? stampPrefix;

  /// Lime heading: the stage takes orders or mints now. Chalk otherwise.
  final bool statusLit;

  /// The caption's figures after the sentence (「已铸 N 枚」, a hold reason).
  final String? statusDetail;
  final String buttonLabel;
  final Launch2NftAction action;

  /// A lit (Purple) ring; otherwise the greyed one.
  final bool litRing;

  /// The medal's lower arc: 「#tokenId」 once held, 「共识勋章」 before.
  final String medalLabel;
}

/// The view of [detail] (docs/32 §4.2). [walletActive]: the account has a
/// wallet the mint can be paid from.
Launch2NftView launch2NftView(
  Launch2InstanceDetail detail, {
  required bool walletActive,
}) {
  final row = detail.row;
  final viewer = detail.viewer;
  final held = (viewer?.nftHeld ?? 0) > 0;
  final tokenId = viewer?.mintedTokenId;
  final medal = held && tokenId != null
      ? '#$tokenId'
      : LoopL10n.current.launch2_launch2NftS;
  final minted = LoopL10n.current.launch2_launch2HeroSwitch4(
    row.nftSale.soldCount,
  );
  final next = row.nextChangeAt;
  final toProject = LoopL10n.current.launch2_launch2NftToProject;
  switch (row.stage) {
    case Launch2Stage.upcoming:
      return Launch2NftView(
        status: next == null
            ? LoopL10n.current.launch2_launch2HeroSwitch2
            : LoopL10n.current.launch2_launch2FormatUpcoming2,
        countdownTo: next,
        stampPrefix: LoopL10n.current.launch2_launch2AtmosphereCountdown,
        statusLit: false,
        statusDetail: LoopL10n.current.launch2_launch2InstanceUpcoming(
          launch2SaleDurationLabel(row.nftSale),
          launch2Usd1Label(row.nftSale.priceUsd1),
        ),
        buttonLabel: LoopL10n.current.launch2_launch2NftButtonLabel,
        action: Launch2NftAction.none,
        litRing: false,
        medalLabel: medal,
      );
    case Launch2Stage.nftSale:
      return Launch2NftView(
        status: LoopL10n.current.launch2_launch2FormatNftSale,
        countdownTo: next,
        statusLit: true,
        statusDetail: minted,
        buttonLabel: held
            ? LoopL10n.current.launch2_launch2NftButtonLabel2
            : walletActive
            ? LoopL10n.current.launch2_launch2NftButtonLabel3(
                launch2Usd1Label(row.nftSale.priceUsd1),
              )
            : LoopL10n.current.launch2_launch2NftButtonLabel4,
        action: held || !walletActive
            ? Launch2NftAction.none
            : Launch2NftAction.mint,
        litRing: true,
        medalLabel: medal,
      );
    case Launch2Stage.snapshotPending:
      // Decision 0202: the publication attempt's own words, as on the
      // project page (名单生成中 → 名单发布中 → …).
      return Launch2NftView(
        status: LoopL10n.current.launch2_launch2NftStatus(
          launch2SnapshotPendingTitle(detail.snapshot),
        ),
        statusLit: false,
        statusDetail: minted,
        buttonLabel: held
            ? LoopL10n.current.launch2_launch2NftButtonLabel5
            : LoopL10n.current.launch2_launch2NftButtonLabel6,
        action: Launch2NftAction.none,
        litRing: true,
        medalLabel: medal,
      );
    case Launch2Stage.priority:
      return Launch2NftView(
        status: LoopL10n.current.launch2_launch2HeroPriority,
        countdownTo: next,
        statusLit: true,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        litRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.public:
      return Launch2NftView(
        status: detail.snapshot.openedWithoutHolders != null
            ? LoopL10n.current.launch2_launch2NftStatus2
            : LoopL10n.current.launch2_launch2NftStatus3,
        statusLit: true,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        litRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.graduated:
      return Launch2NftView(
        status: LoopL10n.current.common_graduated,
        statusLit: false,
        statusDetail: minted,
        buttonLabel: toProject,
        action: Launch2NftAction.openProject,
        litRing: held,
        medalLabel: medal,
      );
    case Launch2Stage.closedNoHolders:
      // Decision 0120 / 0142: a legacy sale with no holder is closed for
      // good — neither round opens, so the page does not say it did.
      return Launch2NftView(
        status: LoopL10n.current.launch2_launch2NftStatus4,
        statusLit: false,
        buttonLabel: LoopL10n.current.launch2_launch2NftButtonLabel7,
        action: Launch2NftAction.openProject,
        litRing: false,
        medalLabel: medal,
      );
    case Launch2Stage.paused:
      return Launch2NftView(
        status: LoopL10n.current.launch2_launch2FormatSwitch29,
        statusLit: false,
        statusDetail: launch2HoldReasonText(row.holdReason),
        buttonLabel: LoopL10n.current.launch2_launch2NftButtonLabel7,
        action: Launch2NftAction.openProject,
        litRing: false,
        medalLabel: medal,
      );
  }
}

/// 「我的持有」 (docs/32 §4.1).
String launch2NftHoldingText(Launch2InstanceDetail detail) {
  final viewer = detail.viewer;
  if (viewer == null) return LoopL10n.current.launch2_launch2InstanceRows7;
  if (viewer.nftHeld <= 0) return '0 / 1';
  final tokenId = viewer.mintedTokenId;
  if (tokenId == null) return '${viewer.nftHeld} / 1';
  if (detail.snapshot.published) {
    return viewer.snapshotMember
        ? LoopL10n.current.launch2_launch2NftIf(tokenId)
        : '#$tokenId';
  }
  return LoopL10n.current.launch2_launch2NftIf2(tokenId);
}

/// The toast once a mint shows up in the read model (docs/32 §4.3).
String get launch2NftMintedToast =>
    LoopL10n.current.launch2_launch2NftLaunch2NftMintedToast;

/// The NFTs this wallet can send from [detail] (S339 · decision 0267), one
/// per token id, ascending; empty when there is nothing to offer: no viewer,
/// nothing held, no known token id or no published NFT contract.
///
/// The token ids are the server's `heldTokenIds` when it sent them, else the
/// one this wallet minted. Ownership is the server's to check at prepare.
List<SendNftTarget> launch2NftSendTargets(Launch2InstanceDetail detail) {
  final viewer = detail.viewer;
  if (viewer == null || viewer.nftHeld <= 0) return const <SendNftTarget>[];
  final ids = viewer.heldTokenIds ?? <BigInt>[?viewer.mintedTokenId];
  final row = detail.row;
  return <SendNftTarget>[
    for (final id in ids)
      ?SendNftTarget.tryCreate(
        walletId: viewer.walletId,
        chainId: row.chainId,
        contractAddress: detail.contracts['nft'],
        tokenId: id,
        ticker: row.ticker,
        projectName: row.name,
        instanceId: row.instanceId,
        nftImageUrl: row.nftImageUrl,
        logoUrl: row.logoUrl,
      ),
  ];
}

class Launch2NftScreen extends ConsumerStatefulWidget {
  const Launch2NftScreen({
    required this.instanceId,
    super.key,
    this.onBack,
    this.onNavigate,
    this.onSendNft,
  });

  final String? instanceId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  /// Opens the NFT send flow (S339 · decision 0267). Defaults to pushing
  /// `/wallet/send/to` with the NFT's draft.
  final void Function(SendNftTarget target)? onSendNft;

  @override
  ConsumerState<Launch2NftScreen> createState() => _Launch2NftScreenState();
}

/// Our own mint, until the read model shows it.
@immutable
final class _Pending {
  const _Pending({required this.text, required this.locked});

  final String text;

  /// Broadcast: no second mint until the lane shows it.
  final bool locked;
}

class _Launch2NftScreenState extends ConsumerState<Launch2NftScreen> {
  Timer? _poll;
  _Pending? _pending;
  Launch2ActionFailure? _failure;
  bool _preparing = false;
  int _settleReads = 0;

  /// The project page's limit: how many re-reads a broadcast waits for.
  static const int _settleLimit = 36;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    unawaited(context.push(location));
  }

  /// 「去充值」 (decision 0201, same target as the project page): the
  /// wallet's own receive page, for the active wallet when it has a
  /// canonical id.
  void _openTopUp(Launch2InstanceDetail detail) {
    final walletId =
        memeReadActiveWallet(ref).walletId ?? detail.viewer?.walletId;
    _open(
      walletId != null && WalletRoute.isCanonical(walletId)
          ? WalletRoute.receive(walletId)
          : WalletRoute.receivePath,
    );
  }

  /// 「领取测试币」 next to 「去充值」 (decision 0154), only while the server
  /// publishes `testnetFaucet` as available and the wallet has a canonical
  /// id. A grant re-reads this instance so the balance follows.
  VoidCallback? _faucetAction(Launch2InstanceDetail detail) {
    if (!testnetFaucetVisible(ref)) return null;
    final active = memeReadActiveWallet(ref);
    final walletId = active.walletId ?? detail.viewer?.walletId;
    if (walletId == null || !WalletRoute.isCanonical(walletId)) return null;
    return () => unawaited(
      showTestnetFaucetSheet(
        context,
        walletId: walletId,
        address: active.address,
        onGranted: () => unawaited(_controller(detail.instanceId).reload()),
      ),
    );
  }

  /// 「发送」: the send flow, unless the server's `nftSend` capability is not
  /// available or this session already heard its switch is off.
  /// 「发送」 with several NFTs held: the owner picks one first.
  Future<void> _sendOne(List<SendNftTarget> targets) async {
    if (!_sendAllowed()) return;
    if (targets.length == 1) {
      _send(targets.single);
      return;
    }
    final picked = await showLoopSheet<SendNftTarget>(
      context,
      barrierLabel: LoopL10n.current.launch2_launch2NftBarrierLabel,
      builder: (sheetContext) => Launch2NftSendPicker(
        targets: targets,
        onPick: (target) => Navigator.of(sheetContext).pop(target),
      ),
    );
    if (picked == null || !mounted) return;
    _send(picked);
  }

  /// Whether a send may start; otherwise the toast says it may not.
  bool _sendAllowed() {
    final capability = ref.read(
      loopCapabilityProvider(LoopV2CapabilityId.nftSend),
    );
    if (capability.isAvailable && !ref.read(nftSendDisabledProvider)) {
      return true;
    }
    LoopToast.show(context, message: nftSendDisabledText);
    return false;
  }

  void _send(SendNftTarget target) {
    // The server's `nftSend` capability decides first; a 503 this session
    // already heard is the fallback when the capability lags the switch.
    if (!_sendAllowed()) return;
    final send = widget.onSendNft;
    if (send != null) {
      send(target);
      return;
    }
    unawaited(context.push('/wallet/send/to', extra: SendDraft.nft(target)));
  }

  Launch2InstanceController _controller(String id) =>
      ref.read(launch2InstanceControllerProvider(id).notifier);

  void _armPoll(String id, Launch2InstanceDetail detail) {
    if (_poll != null || detail.stage.terminal) return;
    final polling = ref.read(launch2PollingProvider);
    final fast = _pending?.locked ?? false;
    _poll = Timer(polling.intervalFor(detail.stage, fast: fast), () {
      _poll = null;
      if (!mounted) return;
      unawaited(_controller(id).reload());
    });
  }

  void _settle(Launch2InstanceDetail detail) {
    final pending = _pending;
    if (pending == null || !pending.locked) return;
    if ((detail.viewer?.nftHeld ?? 0) > 0) {
      setState(() {
        _pending = null;
        _settleReads = 0;
      });
      LoopToast.show(context, message: launch2NftMintedToast);
      return;
    }
    _settleReads += 1;
    if (_settleReads >= _settleLimit) {
      setState(() {
        _pending = _Pending(
          text: LoopL10n.current.launch2_launch2NftText,
          locked: false,
        );
      });
    }
  }

  Future<void> _mint(Launch2InstanceDetail detail) async {
    final result = await launch2MintNft(
      context,
      ref,
      detail,
      onPreparing: () {
        if (!mounted) return;
        setState(() {
          _preparing = true;
          _failure = null;
        });
      },
      onPrepared: () {
        if (mounted) setState(() => _preparing = false);
      },
      entry: Launch2NftMintEntry.mintPage,
    );
    if (!mounted) return;
    switch (result) {
      case Launch2NftMintCancelled():
        return;
      case Launch2NftMintRefused(:final failure):
        setState(() {
          _preparing = false;
          _failure = failure;
        });
      case Launch2NftMintSigned(:final intent, :final outcome):
        setState(() {
          _settleReads = 0;
          _pending = _Pending(
            text: launch2OutcomeText(
              outcome,
              intent.kind,
              noun: Launch2NftMintEntry.mintPage.noun,
            ),
            locked: outcome.broadcast,
          );
        });
        if (outcome.broadcast) {
          _poll?.cancel();
          _poll = null;
          // Decision 0203: the signing sheet may already have watched the
          // read show the mint; settle on what is on screen first.
          final shown = ref
              .read(launch2InstanceControllerProvider(detail.instanceId))
              .value;
          if (shown != null) _settle(shown);
          unawaited(_controller(detail.instanceId).reload());
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-nft-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.launch2_launch2NftS,
        onBack: widget.onBack,
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('launch2-nft-invalid-identity'),
            illustration: LoopIllustration.launchpad,
            title: context
                .l10n
                .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityTitle,
            message: context
                .l10n
                .launch2_launch2DynamicRewardsLaunch2DynRewardsInvalidIdentityMessage,
            compact: true,
          ),
        ],
      );
    }
    final instanceId = id!;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    final blocked = launch2ReadsBlocked(ref);
    final provider = launch2InstanceControllerProvider(instanceId);
    final state = blocked ? null : ref.watch(provider);
    if (state != null) {
      launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    }
    ref.listen<LoopChainResourceState<Launch2InstanceDetail>>(provider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null && !identical(previous?.value, value)) {
        _settle(value);
      }
    });
    final detail = state?.value;
    final wallet = detail == null ? null : memeActiveWallet(ref);
    if (detail != null) _armPoll(instanceId, detail);
    final view = detail == null
        ? null
        : launch2NftView(
            detail,
            walletActive: wallet?.walletId != null || detail.viewer != null,
          );
    return LoopDashboardPage(
      key: const ValueKey<String>('launch2-nft-screen'),
      archetype: LoopPageArchetype.record,
      title: context.l10n.launch2_launch2NftS,
      onBack: widget.onBack,
      updating: state?.refreshing ?? false,
      onRefresh: blocked ? null : () => ref.read(provider.notifier).reload(),
      block: blocked
          ? LoopPageBlock(
              key: const ValueKey<String>('launch2-nft-blocked'),
              title: context
                  .l10n
                  .launch2_launch2DynamicRewardsLaunch2DynRewardsBlockedTitle,
              message: launch2CapabilityText(capability),
            )
          : null,
      bottomBar: detail == null || view == null
          ? null
          : _bottomBar(detail, view),
      sections: <Widget>[
        if (state == null || detail == null || view == null)
          LoopChainStateBlock(
            keyPrefix: 'launch2-nft',
            phase: state?.phase ?? LoopChainViewPhase.unavailable,
            failureKind: state?.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: context.l10n.launch2_launch2FormatSwitch24,
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          ..._sections(detail, view),
      ],
    );
  }

  Widget _bottomBar(Launch2InstanceDetail detail, Launch2NftView view) {
    final hold = detail.tradingHold;
    final mint = view.action == Launch2NftAction.mint;
    final locked = _pending?.locked ?? false;
    final enabled = switch (view.action) {
      Launch2NftAction.mint => hold == null && !_preparing && !locked,
      Launch2NftAction.openProject => true,
      Launch2NftAction.none => false,
    };
    final failure = mint && hold == null && !_preparing ? _failure : null;
    final sendTargets = launch2NftSendTargets(detail);
    final main = LoopButton(
      key: const ValueKey<String>('launch2-nft-mint'),
      label: mint && _preparing
          ? LoopL10n.current.launch2_launch2DynamicRewardsLabel
          : view.buttonLabel,
      primary: true,
      block: true,
      onPressed: !enabled
          ? null
          : switch (view.action) {
              Launch2NftAction.mint => () => unawaited(_mint(detail)),
              Launch2NftAction.openProject => () => _open(
                Launch2Route.instance(detail.instanceId),
              ),
              Launch2NftAction.none => null,
            },
    );
    return Launch2BarShell(
      failure: mint && hold != null
          ? Launch2TradingHoldLine(
              key: const ValueKey<String>('launch2-nft-bar-hold'),
              hold: hold,
              padding: EdgeInsets.zero,
            )
          : failure == null
          ? null
          : Launch2ActionFailureLine(
              key: const ValueKey<String>('launch2-nft-bar-failure'),
              message: failure.text,
              // Decision 0201: a balance refusal offers 「去充值」 here too,
              // as on the project page (docs/22 §3 mints from this page).
              topUpKey: const ValueKey<String>('launch2-nft-bar-topup'),
              onTopUp: failure.topUp ? () => _openTopUp(detail) : null,
              faucetKey: const ValueKey<String>('launch2-nft-bar-faucet'),
              onFaucet: _faucetAction(detail),
            ),
      // S339 · decision 0267: a held NFT is sent from here, beside the
      // page's own action.
      child: sendTargets.isEmpty
          ? main
          : LoopButtonPair(
              key: const ValueKey<String>('launch2-nft-actions'),
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('launch2-nft-send'),
                  label: LoopL10n.current.common_send,
                  block: true,
                  onPressed: () => unawaited(_sendOne(sendTargets)),
                ),
                main,
              ],
            ),
    );
  }

  List<Widget> _sections(Launch2InstanceDetail detail, Launch2NftView view) {
    final row = detail.row;
    final pending = _pending;
    final summary = row.summary;
    final failure = _failure;
    return <Widget>[
      // Decision 0161: the chain guard's hold, above everything that pays.
      if (detail.tradingHold case final Launch2TradingHold hold)
        Launch2TradingHoldBanner(hold: hold),
      if (pending != null)
        LoopNotice(
          key: const ValueKey<String>('launch2-nft-pending'),
          icon: pending.locked ? 'clock' : 'info',
          body: pending.text,
        ),
      if (failure != null && !_preparing)
        LoopInlineUnavailable(
          key: const ValueKey<String>('launch2-nft-action-failed'),
          icon: 'warn',
          message: failure.text,
        ),
      _NftFolio(
        detail: detail,
        view: view,
        onElapsed: () => unawaited(_controller(detail.instanceId).reload()),
      ),
      LoopAtmoPrecache(
        paths: launch2NftCardAssets,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: LoopSpacing.tight),
            child: Launch2NftMedal(
              key: const ValueKey<String>('launch2-nft-medal'),
              ticker: row.ticker,
              logoUrl: row.logoUrl,
              nftImageUrl: row.nftImageUrl,
              identity: row.instanceId,
              bottomLabel: view.medalLabel,
              lit: view.litRing,
            ),
          ),
        ),
      ),
      if (summary != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            LoopSpacing.tight,
            LoopSpacing.page,
            0,
          ),
          child: Text(
            summary,
            key: const ValueKey<String>('launch2-nft-summary'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: LoopType.caption.copyWith(color: LoopColors.text2),
          ),
        ),
      LoopLabel(LoopL10n.current.launch2_launch2NftLoopLabel),
      LoopRecordGroup(
        key: const ValueKey<String>('launch2-nft-benefits'),
        rows: <LoopRecordRow>[
          _entry(
            'ticket',
            LoopL10n.current.launch2_launch2NftEntry,
            LoopL10n.current.launch2_launch2NftEntry2,
          ),
          _entry(
            'droplet',
            LoopL10n.current.launch2_launch2NftEntry3,
            LoopL10n.current.launch2_launch2NftEntry4(
              launch2Usd1Label(detail.template.buybackOrderUsd1),
            ),
          ),
        ],
      ),
      LoopLabel(LoopL10n.current.launch2_launch2InstanceTitle5),
      LoopRecordGroup(
        key: const ValueKey<String>('launch2-nft-rules'),
        rows: <LoopRecordRow>[
          _entry(
            'user',
            LoopL10n.current.launch2_launch2NftEntry5,
            LoopL10n.current.launch2_launch2NftEntry6(
              launch2Usd1Label(row.nftSale.priceUsd1),
            ),
          ),
          _entry(
            'clock',
            LoopL10n.current.launch2_launch2NftEntry7(
              launch2SaleDurationLabel(row.nftSale),
            ),
            LoopL10n.current.launch2_launch2InstanceLaunch2NftEnd(
              loopDateTimeLabel(row.nftSale.endAt),
            ),
          ),
          _entry(
            'warn',
            LoopL10n.current.launch2_launch2InstanceLaunch2TemplateRiskTitle,
            LoopL10n.current.launch2_nftRiskBody(
              launch2SentenceCase(launch2NftRiskSentence),
            ),
          ),
        ],
      ),
      LoopLabel(LoopL10n.current.launch2_launch2NftLoopLabel2),
      LoopKeyValue(
        key: const ValueKey<String>('launch2-nft-held'),
        label: LoopL10n.current.launch2_launch2InstanceLaunch2NftHeldLabel,
        value: launch2NftHoldingText(detail),
      ),
      LoopKeyValue(
        key: const ValueKey<String>('launch2-nft-sold'),
        label: LoopL10n.current.launch2_launch2InstanceRows4,
        value: LoopL10n.current.launch2_launch2InstanceRows5(
          row.nftSale.soldCount,
        ),
      ),
      // Decision 0202: the published list, as on the project page.
      if (launch2SnapshotPublishedShown(detail))
        Launch2SnapshotPublishedBlock(detail: detail),
      LoopProvenanceLine(
        key: const ValueKey<String>('launch2-nft-provenance'),
        sources: <String>[
          LoopL10n.current.launch2_launch2InstanceLoopProvenanceLine,
        ],
        observedAt: detail.projectedAt,
        padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 6, 16, 4),
        detail: LoopL10n.current.launch2_launch2NftLaunch2NftProvenanceDetail,
      ),
    ];
  }
}

/// One `.row` of the medal's facts: a glyph, the fact and its line.
LoopRecordRow _entry(String icon, String title, String line) => LoopRecordRow(
  leading: LoopRowIcon(icon: icon),
  title: title,
  subtitle: line,
  subtitleMaxLines: 3,
  chevron: false,
);

/// `.ledger-card.ledger-quiet.folio-primary`: CONSENSUS MEDAL, the ticker,
/// the stage sentence with what was minted, and the countdown in the stamp.
class _NftFolio extends StatelessWidget {
  const _NftFolio({
    required this.detail,
    required this.view,
    required this.onElapsed,
  });

  final Launch2InstanceDetail detail;
  final Launch2NftView view;
  final VoidCallback onElapsed;

  @override
  Widget build(BuildContext context) {
    final row = detail.row;
    final caption = <String>[view.status, ?view.statusDetail].join(' · ');
    Widget folio(String? stamp) => LoopFolioPrimary(
      key: const ValueKey<String>('launch2-nft-folio'),
      archetype: LoopFolioArchetype.record,
      ring: false,
      headingTone: view.statusLit
          ? LoopFolioHeadingTone.accent
          : LoopFolioHeadingTone.neutral,
      kicker: context.l10n.launch2_launch2NftS,
      heading: launch2HeroTicker(row.ticker),
      caption: caption,
      stamp: stamp,
    );
    final target = view.countdownTo;
    return KeyedSubtree(
      key: const ValueKey<String>('launch2-nft-status'),
      child: target == null
          ? folio(null)
          : Launch2CountdownBuilder(
              target: target,
              onElapsed: onElapsed,
              builder: (context, text) => folio(
                '${view.stampPrefix ?? context.l10n.launch2_launch2AtmosphereCountdown2}$text',
              ),
            ),
    );
  }
}

/// 共识勋章 (docs/32 §4.1): a perfect circle — a 2 px outer ring (Purple,
/// decision 0212 / S257, or the greyed tone), the ticker along the upper arc
/// in mono and [bottomLabel] along the lower one.
///
/// S273 · decision 0232 (需求方 「NFT 应该展示图片吧」): the whole disc inside
/// the arc band is the NFT's picture — [Launch2NftCard] in its medal shape,
/// the logo filling the disc, or the banner's default art with the ticker
/// when there is no logo — instead of a 56 dp logo on Graphite. The medal
/// grew from 152 to 200 so the picture reads (a 134 dp disc).
class Launch2NftMedal extends StatelessWidget {
  const Launch2NftMedal({
    required this.ticker,
    required this.bottomLabel,
    required this.lit,
    super.key,
    this.logoUrl,
    this.nftImageUrl,
    this.identity,
    this.size = 200,
  });

  final String ticker;
  final String? logoUrl;

  /// The owner's NFT picture: before [logoUrl] (decision 0232).
  final String? nftImageUrl;
  final String? identity;

  /// 「#tokenId」 or 「共识勋章」.
  final String bottomLabel;

  /// Purple ring and Chalk arc text; otherwise both greyed.
  final bool lit;
  final double size;

  /// The arc band's width ×2 plus the inner hairline: what the picture
  /// leaves to the ring and the words.
  static const double ringInset = 33;

  /// The picture's diameter inside a medal of [size].
  double get pictureSize => size - ringInset * 2;

  /// The outer ring: Purple when lit (decision 0212, S257), else greyed.
  Color get ringColour => lit ? LoopColors.purple : LoopColors.text3;

  /// The arc text: Chalk on the dark face when lit, else greyed.
  Color get inkColour => lit ? LoopColors.chalk : LoopColors.text3;

  @override
  Widget build(BuildContext context) {
    final ring = ringColour;
    final ink = inkColour;
    return Semantics(
      image: true,
      label: context.l10n.launch2_launch2NftLaunch2NftMedalPictureLabel(
        bottomLabel,
        ticker,
      ),
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MedalPainter(
            tone: ring,
            ink: ink,
            top: launch2HeroTicker(ticker),
            bottom: bottomLabel,
          ),
          child: Center(
            child: Launch2NftCard(
              key: const ValueKey<String>('launch2-nft-medal-picture'),
              ticker: ticker,
              nftImageUrl: nftImageUrl,
              logoUrl: logoUrl,
              size: pictureSize,
              shape: Launch2NftCardShape.medal,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({
    required this.tone,
    required this.ink,
    required this.top,
    required this.bottom,
  });

  final Color tone;

  /// The arc text.
  final Color ink;
  final String top;
  final String bottom;

  /// Where the arc text runs, inside the outer ring.
  static const double _band = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas
      ..drawCircle(center, radius - 1, Paint()..color = LoopColors.graphite)
      ..drawCircle(
        center,
        radius - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = tone,
      )
      ..drawCircle(
        center,
        radius - _band * 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tone.withValues(alpha: 0.35),
      );
    final style = LoopTypography.withWeight(
      LoopType.figureXs,
      FontWeight.w600,
    ).copyWith(color: ink, letterSpacing: 0);
    final textRadius = radius - _band;
    _arc(canvas, center, textRadius, top, style, upper: true);
    _arc(canvas, center, textRadius, bottom, style, upper: false);
  }

  /// Lays [text] along the circle of [radius], centred on the top or the
  /// bottom, upright and reading left to right on both arcs.
  static void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    TextStyle style, {
    required bool upper,
  }) {
    if (text.isEmpty) return;
    const gap = 1.5;
    final glyphs = <TextPainter>[
      for (final rune in text.runes)
        TextPainter(
          text: TextSpan(text: String.fromCharCode(rune), style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final length =
        glyphs.fold<double>(0, (sum, glyph) => sum + glyph.width) +
        gap * (glyphs.length - 1);
    final sweep = length / radius;
    var angle = upper ? -math.pi / 2 - sweep / 2 : math.pi / 2 + sweep / 2;
    for (final glyph in glyphs) {
      final step = glyph.width / radius;
      final mid = upper ? angle + step / 2 : angle - step / 2;
      canvas
        ..save()
        ..translate(
          center.dx + radius * math.cos(mid),
          center.dy + radius * math.sin(mid),
        )
        ..rotate(upper ? mid + math.pi / 2 : mid - math.pi / 2);
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      final advance = (glyph.width + gap) / radius;
      angle = upper ? angle + advance : angle - advance;
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.tone != tone ||
      old.ink != ink ||
      old.top != top ||
      old.bottom != bottom;
}

/// Which NFT to send, when the wallet holds several of one project (S339 ·
/// decision 0267): one row per token id.
class Launch2NftSendPicker extends StatelessWidget {
  const Launch2NftSendPicker({
    required this.targets,
    required this.onPick,
    super.key,
  });

  final List<SendNftTarget> targets;
  final ValueChanged<SendNftTarget> onPick;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    key: const ValueKey<String>('launch2-nft-send-picker'),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.6,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopLabel(context.l10n.launch2_launch2NftLoopLabel3),
        Flexible(
          child: SingleChildScrollView(
            child: LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (final target in targets)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch2-nft-send-pick-${target.tokenIdText}',
                    ),
                    leading: const LoopRowIcon(icon: 'ticket'),
                    title: target.label,
                    onTap: () => onPick(target),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
