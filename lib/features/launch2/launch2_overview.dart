import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';

// ---------------------------------------------------------------------------
// 发射台总览 · `GET /v2/launch2/overview` (decision 0163 second phase,
// docs/32 §7, loop-api S181)
// ---------------------------------------------------------------------------
//
// The live tape (§7.1) and the stats strip (§7.5) read one answer. It is an
// enhancement: a 404, a 503, a missing field or an unreadable item draws
// nothing, never an error and never a figure the server did not send.

/// What one tape item reports.
enum Launch2ActivityKind {
  curveBuy('curve_buy'),
  curveSell('curve_sell'),
  nftMint('nft_mint'),
  graduated('graduated'),
  buyback('buyback'),
  roundActivated('round_activated'),
  rewardClaimed('reward_claimed');

  const Launch2ActivityKind(this.wireName);

  final String wireName;

  static Launch2ActivityKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// One indexed `launch2` event, newest first on the wire.
@immutable
final class Launch2Activity {
  const Launch2Activity({
    required this.kind,
    required this.instanceId,
    required this.ticker,
    required this.name,
    required this.at,
    this.logoUrl,
    this.actor,
    this.amountUsd1,
    this.transactionHash,
    this.account,
  });

  final Launch2ActivityKind kind;
  final String instanceId;
  final String ticker;
  final String name;
  final String? logoUrl;

  /// The full address of who did it; `null` reads as 「有人」.
  final String? actor;
  final Decimal? amountUsd1;
  final DateTime at;
  final String? transactionHash;

  /// The LOOP account behind [actor] (loop-api decision 0162 §A), sent only
  /// with `LAUNCH2_TRADER_ACCOUNT_EMIT=on` (decision 0166); `null` when the
  /// key is absent, unreadable, or the server has no visible account. It is
  /// not part of [identity]: the same event keeps one identity either way.
  final MemeAccountRef? account;

  /// One event, however often it is read again.
  String get identity =>
      '${kind.wireName}:$instanceId:${transactionHash ?? ''}:'
      '${at.toIso8601String()}:${actor ?? ''}';
}

/// The platform figures (§7.5). Counts are whole numbers.
@immutable
final class Launch2Stats {
  const Launch2Stats({
    required this.liveCount,
    required this.mintingCount,
    required this.priorityCount,
    required this.curveCount,
    required this.upcomingCount,
    required this.graduatedTotal,
    required this.graduatedThisWeek,
    required this.buybackUsd1Total,
    required this.nftMintedTotal,
  });

  final int liveCount;
  final int mintingCount;
  final int priorityCount;
  final int curveCount;
  final int upcomingCount;
  final int graduatedTotal;
  final int graduatedThisWeek;
  final Decimal buybackUsd1Total;
  final int nftMintedTotal;
}

@immutable
final class Launch2Overview {
  const Launch2Overview({required this.activity, this.stats, this.observedAt});

  final List<Launch2Activity> activity;

  /// `null` when the server sent none or any of its figures is unreadable.
  final Launch2Stats? stats;
  final DateTime? observedAt;
}

/// Feature-facing port for the overview read. Every failure is a
/// [LoopChainException]; the surfaces draw nothing on one.
abstract interface class Launch2OverviewGateway {
  LoopChainGatewayMode get mode;

  Future<Launch2Overview> loadOverview();
}

/// Production default until the composition root mounts the V2 adapter.
final class UnavailableLaunch2OverviewGateway
    implements Launch2OverviewGateway {
  const UnavailableLaunch2OverviewGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<Launch2Overview> loadOverview() => Future<Launch2Overview>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

/// Overridden by the composition root with the authenticated V2 adapter.
final launch2OverviewGatewayProvider = Provider<Launch2OverviewGateway>(
  (ref) => const UnavailableLaunch2OverviewGateway(),
);

/// The overview read. The v2 list owns its timing: it loads it with the
/// first page and refreshes it with every 60 s poll and pull (§7.1: no
/// timer of its own).
final class Launch2OverviewController
    extends LoopChainReadController<Launch2Overview> {
  @override
  bool get retainsAnswer => false;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(launch2OverviewGatewayProvider.select((g) => g.mode));

  @override
  Future<Launch2Overview> fetch() =>
      ref.read(launch2OverviewGatewayProvider).loadOverview();
}

final launch2OverviewControllerProvider =
    NotifierProvider.autoDispose<
      Launch2OverviewController,
      LoopChainResourceState<Launch2Overview>
    >(Launch2OverviewController.new);
