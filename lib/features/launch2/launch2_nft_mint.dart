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
}) async {
  final confirmed = await showLaunch2NftConfirmSheet(
    context,
    ticker: detail.row.ticker,
    priceLabel: launch2Usd1Label(detail.row.nftSale.priceUsd1),
  );
  if (!confirmed || !context.mounted) return const Launch2NftMintCancelled();
  final wallet = memeReadActiveWallet(ref);
  final walletId = wallet.walletId ?? detail.viewer?.walletId;
  if (walletId == null) {
    return const Launch2NftMintRefused(
      Launch2ActionFailure('还没有可用的钱包，激活钱包后再购买'),
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
  );
  if (outcome == null) return const Launch2NftMintCancelled();
  return Launch2NftMintSigned(intent: intent, outcome: outcome);
}

/// What the page says about a signing outcome until the read model shows
/// it — the project page's 「已广播 …」 notice, one sentence for both pages.
String launch2OutcomeText(Launch2SignOutcome outcome, Launch2IntentKind kind) {
  final noun = launch2IntentNoun(kind);
  return outcome.broadcast
      ? launch2BroadcastText(outcome, kind)
      : launch2StoppedAtRefresh(outcome)
      ? launch2RefreshReasonText(outcome, noun)
      : outcome.approvalTxHash != null
      ? launch2ApprovalOnlyText(outcome.reasonCode, noun)
      : launch2SignReasonText(outcome.reasonCode);
}
