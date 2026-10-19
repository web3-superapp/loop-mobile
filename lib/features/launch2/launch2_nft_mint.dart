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
/// broadcast. [detail] is what the page showed when the action started; its
/// [launch2OwnConfirmationSignature] is the baseline. The watch listens to
/// the instance the page keeps reading and, while the sheet is open, asks
/// for it again every `tradingInterval` (at most [launch2ConfirmationReads]
/// times), so the sheet does not wait on the page's slower 15 s read.
/// `null` when the read model carries no signal of the viewer's own.
Launch2ConfirmationProbe? launch2ReadModelConfirmation(
  WidgetRef ref,
  Launch2InstanceDetail detail,
  Launch2Intent intent,
) {
  final baseline = launch2OwnConfirmationSignature(detail, intent);
  if (baseline == null) return null;
  return () => _ReadModelConfirmation(
    ref,
    instanceId: detail.instanceId,
    intent: intent,
    baseline: baseline,
    interval: ref.read(launch2PollingProvider).tradingInterval,
  );
}

/// How many extra reads one watch asks for (the project page's own limit).
const int launch2ConfirmationReads = 36;

final class _ReadModelConfirmation implements Launch2ConfirmationWatch {
  _ReadModelConfirmation(
    this._ref, {
    required this.instanceId,
    required this.intent,
    required this.baseline,
    required this.interval,
  }) {
    _subscription = _ref
        .listenManual<LoopChainResourceState<Launch2InstanceDetail>>(
          launch2InstanceControllerProvider(instanceId),
          (_, next) => _check(next.value),
          fireImmediately: true,
        );
    _arm();
  }

  final WidgetRef _ref;
  final String instanceId;
  final Launch2Intent intent;
  final String baseline;
  final Duration interval;
  final Completer<void> _done = Completer<void>();
  ProviderSubscription<LoopChainResourceState<Launch2InstanceDetail>>?
  _subscription;
  Timer? _timer;
  int _reads = 0;
  bool _closed = false;

  @override
  Future<void> get confirmed => _done.future;

  void _check(Launch2InstanceDetail? value) {
    if (_closed || _done.isCompleted || value == null) return;
    final now = launch2OwnConfirmationSignature(value, intent);
    if (now != null && now != baseline) {
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
