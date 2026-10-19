import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/meme/meme_wallet.dart';

// ---------------------------------------------------------------------------
// One NFT mint, shared by the project page and 共识勋章 (decision 0163)
// ---------------------------------------------------------------------------
//
// The confirm sheet (price, 每个地址终身 1 枚, the ticked risk sentence) →
// `POST …/nft/prepare` → the MEME v2 signing exit. There is no report route
// (contract §3.4): a broadcast is 「已广播」 and the caller re-reads the
// instance until `viewer.nft` shows the mint. Both pages call this one
// function; neither keeps its own copy of the trip.

/// Where the mint started (decision 0163). The action keeps one name from
/// the confirm sheet to the wallet; since decision 0200 that name is 「铸造」
/// from both entries (the App no longer mixes 「购买 NFT / 发售」 with 「铸造」).
enum Launch2NftMintEntry {
  projectPage,
  mintPage;

  /// The action's name on the signing exit.
  String get noun => '铸造';
}

/// How one trip through [launch2MintNft] ended.
sealed class Launch2NftMintResult {
  const Launch2NftMintResult();
}

/// Closed before anything was asked of the server or the wallet: the confirm
/// sheet was dismissed, or the signing sheet closed before the wallet opened.
final class Launch2NftMintCancelled extends Launch2NftMintResult {
  const Launch2NftMintCancelled();
}

/// The prepare was refused (or no wallet could pay): nothing was signed.
final class Launch2NftMintRefused extends Launch2NftMintResult {
  const Launch2NftMintRefused(this.failure);

  final Launch2ActionFailure failure;
}

/// The signing exit answered for [intent].
final class Launch2NftMintSigned extends Launch2NftMintResult {
  const Launch2NftMintSigned({required this.intent, required this.outcome});

  final Launch2Intent intent;
  final Launch2SignOutcome outcome;
}

/// The wallet's USD1 when the server read it at a block (after graduation,
/// decision 0148); `null` otherwise — never a guess.
Decimal? launch2ReadUsd1(Launch2InstanceDetail detail) {
  final holding = detail.viewer?.holding;
  return holding != null && holding.balancesRead ? holding.usd1Balance : null;
}

/// Mints one NFT of [detail]'s instance.
///
/// [onPreparing] runs as the prepare is sent and [onPrepared] once it
/// answered with an intent, right before the signing sheet opens — the
/// caller's 「正在准备…」. A refusal that says the stage moved under the page
/// (`LAUNCH2_STAGE_MISMATCH`) also re-reads the instance (decision 0142).
Future<Launch2NftMintResult> launch2MintNft(
  BuildContext context,
  WidgetRef ref,
  Launch2InstanceDetail detail, {
  VoidCallback? onPreparing,
  VoidCallback? onPrepared,
  Launch2NftMintEntry entry = Launch2NftMintEntry.projectPage,
}) async {
  final confirmed = await showLaunch2NftConfirmSheet(
    context,
    ticker: detail.row.ticker,
    priceLabel: launch2Usd1Label(detail.row.nftSale.priceUsd1),
    heading: '${entry.noun} ${detail.row.ticker} 共识勋章',
    confirmLabel: '继续${entry.noun}',
  );
  if (!confirmed || !context.mounted) return const Launch2NftMintCancelled();
  final wallet = memeReadActiveWallet(ref);
  final walletId = wallet.walletId ?? detail.viewer?.walletId;
  if (walletId == null) {
    return const Launch2NftMintRefused(
      Launch2ActionFailure('还没有可用的钱包，激活钱包后再铸造'),
    );
  }
  onPreparing?.call();
  final Launch2Intent intent;
  try {
    intent = await ref
        .read(launch2GatewayProvider)
        .prepareNftMint(instanceId: detail.instanceId, walletId: walletId);
  } on LoopChainException catch (failure) {
    if (failure.reasonCode == launch2StageMismatchCode && context.mounted) {
      unawaited(
        ref
            .read(launch2InstanceControllerProvider(detail.instanceId).notifier)
            .reload(),
      );
    }
    return Launch2NftMintRefused(
      launch2ActionFailure(failure, usd1Balance: launch2ReadUsd1(detail)),
    );
  } catch (_) {
    return Launch2NftMintRefused(
      Launch2ActionFailure(
        loopChainFailureReason(LoopChainFailureKind.unexpected),
      ),
    );
  }
  if (!context.mounted) return const Launch2NftMintCancelled();
  onPrepared?.call();
  final outcome = await showLaunch2SignSheet(
    context,
    intent: intent,
    signer: ref.read(launch2IntentSignerProvider),
    fromAddress: memeReadActiveWallet(ref).address,
    ticker: detail.row.ticker,
    clock: ref.read(launch2ClockProvider),
    noun: entry.noun,
    confirmation: launch2ReadModelConfirmation(ref, detail, intent),
  );
  if (outcome == null) return const Launch2NftMintCancelled();
  return Launch2NftMintSigned(intent: intent, outcome: outcome);
}

/// Decision 0203 (S234-4): the sheet's own view of the read model after a
/// broadcast. `null` when [detail] (what the page showed when the action
/// started) carries no signal of the viewer's own for [intent].
///
/// The baseline is **not** [detail]: it is read from the instance's provider
/// at the moment the sheet starts the watch (the broadcast), so a read that
/// landed while the wallet was open is not taken for the confirmation. The
/// watch then listens without firing on the value it started from, and
/// confirms only on [launch2OwnConfirmationAdvanced] — the figure this
/// intent moves, in its own direction. While the sheet is open it also asks
/// for the instance every `tradingInterval` (at most
/// [launch2ConfirmationReads] times), so it does not wait on the page's
/// slower 15 s read.
Launch2ConfirmationProbe? launch2ReadModelConfirmation(
  WidgetRef ref,
  Launch2InstanceDetail detail,
  Launch2Intent intent,
) {
  if (launch2OwnConfirmationFigure(detail, intent) == null) return null;
  final instanceId = detail.instanceId;
  final interval = ref.read(launch2PollingProvider).tradingInterval;
  return () => _ReadModelConfirmation(
    ref,
    instanceId: instanceId,
    intent: intent,
    interval: interval,
  );
}

/// How many extra reads one watch asks for (the project page's own limit).
const int launch2ConfirmationReads = 36;

final class _ReadModelConfirmation implements Launch2ConfirmationWatch {
  _ReadModelConfirmation(
    this._ref, {
    required this.instanceId,
    required this.intent,
    required this.interval,
  }) {
    try {
      final provider = launch2InstanceControllerProvider(instanceId);
      final current = _ref.read(provider).value;
      _baseline = current == null
          ? null
          : launch2OwnConfirmationFigure(current, intent);
      // Nothing to compare against: never confirmed, nothing read.
      if (_baseline == null) {
        _closed = true;
        return;
      }
      _subscription = _ref
          .listenManual<LoopChainResourceState<Launch2InstanceDetail>>(
            provider,
            (_, next) => _check(next.value),
          );
    } on StateError {
      // The page that owns the read is gone.
      close();
      return;
    }
    _arm();
  }

  final WidgetRef _ref;
  final String instanceId;
  final Launch2Intent intent;
  final Duration interval;
  final Completer<void> _done = Completer<void>();
  Decimal? _baseline;
  ProviderSubscription<LoopChainResourceState<Launch2InstanceDetail>>?
  _subscription;
  Timer? _timer;
  int _reads = 0;
  bool _closed = false;

  @override
  Future<void> get confirmed => _done.future;

  void _check(Launch2InstanceDetail? value) {
    final baseline = _baseline;
    if (_closed || _done.isCompleted || value == null || baseline == null) {
      return;
    }
    final now = launch2OwnConfirmationFigure(value, intent);
    if (now != null &&
        launch2OwnConfirmationAdvanced(
          intent.kind,
          baseline: baseline,
          now: now,
        )) {
      _done.complete();
      _timer?.cancel();
    }
  }

  void _arm() {
    if (_closed || _done.isCompleted || _reads >= launch2ConfirmationReads) {
      return;
    }
    _timer = Timer(interval, () async {
      _reads += 1;
      if (_closed || _done.isCompleted) return;
      try {
        await _ref
            .read(launch2InstanceControllerProvider(instanceId).notifier)
            .reload();
      } on StateError {
        // The page was unmounted: its ref is gone, stop for good.
        close();
        return;
      } catch (_) {
        // A failed read is the page's to show; the watch only asks again.
      }
      _arm();
    });
  }

  @override
  void close() {
    _closed = true;
    _timer?.cancel();
    _subscription?.close();
  }
}

/// What the page says about a signing outcome until the read model shows
/// it — the project page's 「已广播 …」 notice, one sentence for both pages.
String launch2OutcomeText(
  Launch2SignOutcome outcome,
  Launch2IntentKind kind, {
  String? noun,
}) {
  final named = noun ?? launch2IntentNoun(kind);
  return outcome.broadcast
      ? launch2BroadcastText(outcome, kind, noun: named)
      : launch2StoppedAtRefresh(outcome)
      ? launch2RefreshReasonText(outcome, named)
      : outcome.approvalTxHash != null
      ? launch2ApprovalOnlyText(outcome.reasonCode, named)
      : launch2SignReasonText(outcome.reasonCode);
}
