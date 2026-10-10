import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';

// S138 · the minute display (requirer §6.2, decisions 0140, 0141; loop-api
// `frontend-v2-mining-rewards-api.md` §3.2).
//
// The previous hour's reward is shown growing over the following hour, one
// step per completed minute. The figure is a function of three facts — the
// settled hour, the instant its display window opened, and the server's
// clock — and of nothing else: no timer adds anything to it. A refresh, a
// return from the background or another phone therefore lands on exactly the
// same figure. A timer only decides *when* the page asks this function again.

/// What the 分钟增长 module shows at one instant.
enum MiningMinutePhase {
  /// 「首个小时结算后开始展示奖励」: nothing to grow yet, and nothing faked.
  awaitingFirstSettlement,

  /// Inside the display hour: [MiningMinuteProgress.shown] grows each minute.
  displaying,

  /// The display hour is over and the next hour has not been settled: 「结算中」,
  /// with the whole previous hour shown.
  settling,

  /// The settlement store is down.
  unavailable,
}

@immutable
final class MiningMinuteProgress {
  const MiningMinuteProgress({
    required this.phase,
    required this.completedMinutes,
    required this.shown,
    required this.total,
    this.nextUpdateAt,
    this.windowStart,
    this.windowEnd,
  });

  final MiningMinutePhase phase;

  /// 0..60.
  final int completedMinutes;

  /// The figure on screen.
  final BigInt shown;

  /// The settled hour's whole reward.
  final BigInt total;

  /// The next instant (server frame) the figure changes; `null` when it no
  /// longer will in this window.
  final DateTime? nextUpdateAt;
  final DateTime? windowStart;
  final DateTime? windowEnd;
}

/// The figure after [completedMinutes] of the window — the contract's
/// `displayedRaw(m) = m >= 60 ? total : floor(total × m / 60)` (§3.2), in
/// LOOP's smallest unit. The 60th minute lands on [total] exactly, so the
/// hour's display ends on the hour's real reward, and the figure equals the
/// server's own `displayedRaw` at every minute.
BigInt miningMinuteShown(BigInt total, int completedMinutes) {
  if (completedMinutes <= 0 || total <= BigInt.zero) return BigInt.zero;
  if (completedMinutes >= 60) return total;
  return total * BigInt.from(completedMinutes) ~/ BigInt.from(60);
}

/// The server's clock now, from the instant it named and the device instant
/// that answer arrived at. Only a device *duration* is used, never the device
/// wall clock as a time of day: a phone set a day wrong still derives the
/// right minute.
DateTime miningServerNow({
  required DateTime serverTime,
  required DateTime receivedAt,
  required DateTime deviceNow,
}) {
  final elapsed = deviceNow.toUtc().difference(receivedAt.toUtc());
  // A device clock moved backwards since the answer cannot run the server
  // clock backwards past the instant it named.
  return serverTime.toUtc().add(elapsed.isNegative ? Duration.zero : elapsed);
}

/// Derives the 分钟增长 module from the rewards answer at [serverNow].
MiningMinuteProgress miningMinuteProgress(
  MiningRewardsView view, {
  required DateTime serverNow,
}) {
  final epoch = view.lastEpoch;
  final display = view.display;
  if (display.state == MiningDisplayState.unavailable) {
    return MiningMinuteProgress(
      phase: MiningMinutePhase.unavailable,
      completedMinutes: 0,
      shown: BigInt.zero,
      total: epoch?.totalReward ?? BigInt.zero,
    );
  }
  if (epoch == null ||
      display.state == MiningDisplayState.awaitingFirstSettlement) {
    return MiningMinuteProgress(
      phase: MiningMinutePhase.awaitingFirstSettlement,
      completedMinutes: 0,
      shown: BigInt.zero,
      total: BigInt.zero,
    );
  }
  final window = display.window;
  final windowStart = (window?.windowStart ?? epoch.epochEnd).toUtc();
  final windowEnd =
      (window?.windowEnd ?? windowStart.add(const Duration(hours: 1))).toUtc();
  final total = window?.total ?? epoch.totalReward;
  final now = serverNow.toUtc();
  final elapsed = now.difference(windowStart);
  final minutes = elapsed.isNegative
      ? 0
      : (elapsed.inSeconds ~/ 60).clamp(0, 60);
  // The server already saw the window close, or the clock says it has.
  if (display.state == MiningDisplayState.settling ||
      minutes >= 60 ||
      !now.isBefore(windowEnd)) {
    return MiningMinuteProgress(
      phase: MiningMinutePhase.settling,
      completedMinutes: 60,
      shown: total,
      total: total,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }
  // The server's own figure while it is still the minute it computed it for;
  // the same formula for every later minute.
  final shown = window != null && window.completedMinutes == minutes
      ? window.displayed
      : miningMinuteShown(total, minutes);
  return MiningMinuteProgress(
    phase: MiningMinutePhase.displaying,
    completedMinutes: minutes,
    shown: shown,
    total: total,
    nextUpdateAt: windowStart.add(Duration(minutes: minutes + 1)),
    windowStart: windowStart,
    windowEnd: windowEnd,
  );
}
