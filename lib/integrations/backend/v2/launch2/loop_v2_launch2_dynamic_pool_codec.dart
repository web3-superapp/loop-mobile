import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the LoopDynamic half of `launch2` (client decisions
/// 0157 / 0159; loop-api `frontend-v2-launch2-api.md` §3.12 and
/// `openapi/loop-api.v2.json`). Every object is closed: an unknown, missing
/// or repeated key is `invalidPayload`. Every root carries
/// `contractVersion: "2.0"`. Amounts are 18-decimal strings, ids are
/// decimal-integer strings, counts and bps are JSON integers.
abstract final class LoopV2Launch2DynamicPoolCodec {
  static const poolKeys = <String>{
    'instanceId',
    'hookKind',
    'status',
    'hook',
    'poolId',
    'router',
    'routerRegistry',
    'routingPolicy',
    'priceTiming',
    'buyTaxBps',
    'baseSellTaxBps',
    'excludeBuybackFromRewards',
    'armed',
    'currentRoundId',
    'candleId',
    'candleSeconds',
    'candleEndsAt',
    'rollPending',
    'currentDropWad',
    'currentDropBps',
    'potUsd1',
    'carryUsd1',
    'roundExtraFeesUsd1',
    'roundTotalBuyWeightUsd1',
    'reservedRewardsUsd1',
    'priceUsd1',
    'viewer',
    'summary',
    'basis',
  };

  /// The keys that stay set on a `not_applicable` / `not_graduated` answer;
  /// every other one is `null` (§3.12.1).
  static const _alwaysSet = <String>{
    'instanceId',
    'hookKind',
    'status',
    'candleSeconds',
  };

  /// May be `null` on an `active` answer: no round armed, no wallet.
  static const _activeNullable = <String>{'currentRoundId', 'viewer'};

  static const summaryKeys = <String>{
    'roundCount',
    'closedRoundCount',
    'allocatedUsd1',
    'claimedUsd1',
    'dynamicFeesUsd1',
    'baseSellFeesUsd1',
    'buyFeesMeme',
  };

  static const rewardsKeys = <String>{
    'instanceId',
    'walletId',
    'hookKind',
    'claimableUsd1',
    'claimedUsd1',
    'rounds',
    'contractVersion',
  };

  static const roundKeys = <String>{
    'roundId',
    'status',
    'weightUsd1',
    'totalBuyWeightUsd1',
    'allocationUsd1',
    'claimableUsd1',
    'claimedUsd1',
    'claimTransactionHash',
    'claimedAt',
    'startCandle',
    'endCandle',
    'activatedAt',
    'closedAt',
  };

  static const claimKeys = <String>{'roundId', 'hook', 'claimableUsd1'};

  static const reportKeys = <String>{
    'intentId',
    'instanceId',
    'walletId',
    'roundId',
    'transactionHash',
    'status',
    'amountUsd1',
    'claimedAt',
    'blockNumber',
    'reportedAt',
  };

  /// The 5-minute candle (§3.12; the schema's only value).
  static const int candleSeconds = 300;

  static Never _invalid() => LoopV2Launch2Codec.invalid();

  static Map<String, Object?> _root(Object? raw, Set<String> keys) {
    final map = LoopV2Contract.strictMap(raw, keys);
    LoopV2ChainCodec.requireContractVersion(map);
    return map;
  }

  static Decimal? _optionalAmount(Map<String, Object?> map, String key) =>
      map[key] == null ? null : LoopV2Launch2Codec.amount(map, key);

  static String _hookKind(Map<String, Object?> map) {
    final value = map['hookKind'];
    if (value != 'officialTax' && value != 'loopDynamic') _invalid();
    return value! as String;
  }

  // -------------------------------------------------------------------------
  // GET …/dynamic-pool
  // -------------------------------------------------------------------------

  /// `GET …/dynamic-pool` (200), checked against the instance asked for.
  static Launch2PoolKind pool(Object? raw, {required String instanceId}) {
    final root = _root(raw, const <String>{'dynamicPool', 'contractVersion'});
    final map = LoopV2Contract.strictMap(root['dynamicPool'], poolKeys);
    if (LoopV2Launch2Codec.uuid(map, 'instanceId') != instanceId) _invalid();
    final hookKind = _hookKind(map);
    final status = map['status'];
    if (LoopV2ChainCodec.requireInt(map, 'candleSeconds') != candleSeconds) {
      _invalid();
    }
    switch ((hookKind, status)) {
      case ('officialTax', 'not_applicable'):
      case ('loopDynamic', 'not_graduated'):
        for (final key in poolKeys.difference(_alwaysSet)) {
          if (map[key] != null) _invalid();
        }
        return hookKind == 'officialTax'
            ? const Launch2OfficialTaxPool()
            : const Launch2LoopDynamicNotGraduated();
      case ('loopDynamic', 'active'):
        for (final key in poolKeys.difference(_activeNullable)) {
          if (map[key] == null) _invalid();
        }
        return Launch2LoopDynamicPool(_active(map, instanceId));
      default:
        _invalid();
    }
  }

  static Launch2DynamicPoolState _active(
    Map<String, Object?> map,
    String instanceId,
  ) {
    final armed = LoopV2ChainCodec.requireBool(map, 'armed');
    final roundId = LoopV2Launch2Codec.optionalInteger(map, 'currentRoundId');
    // An armed round has an id.
    if (armed && roundId == null) _invalid();
    final dropWad = LoopV2Launch2Codec.amount(map, 'currentDropWad');
    if (dropWad > Decimal.one) _invalid();
    final total = LoopV2Launch2Codec.amount(map, 'roundTotalBuyWeightUsd1');
    final timingText = map['priceTiming'];
    final timing = timingText is String
        ? Launch2PriceTiming.tryParse(timingText)
        : null;
    final policyText = map['routingPolicy'];
    final policy = policyText is String
        ? Launch2RoutingPolicy.tryParse(policyText)
        : null;
    if (timing == null || policy == null) _invalid();
    Launch2DynamicViewer? viewer;
    if (map['viewer'] != null) {
      final raw = LoopV2Contract.strictMap(map['viewer'], const <String>{
        'walletId',
        'currentRoundWeightUsd1',
      });
      final weight = LoopV2Launch2Codec.amount(raw, 'currentRoundWeightUsd1');
      if (weight > total) _invalid();
      viewer = Launch2DynamicViewer(
        walletId: LoopV2Launch2Codec.uuid(raw, 'walletId'),
        currentRoundWeightUsd1: weight,
      );
    }
    final summary = LoopV2Contract.strictMap(map['summary'], summaryKeys);
    final roundCount = LoopV2ChainCodec.requireInt(summary, 'roundCount');
    final closedCount = LoopV2ChainCodec.requireInt(
      summary,
      'closedRoundCount',
    );
    if (closedCount > roundCount) _invalid();
    final basis = LoopV2Contract.strictMap(map['basis'], const <String>{
      'blockNumber',
      'blockHash',
    });
    LoopV2Launch2Codec.hash(basis, 'blockHash');
    return Launch2DynamicPoolState(
      instanceId: instanceId,
      hook: LoopV2Launch2Codec.anyCaseAddress(map, 'hook'),
      poolId: LoopV2Launch2Codec.hash(map, 'poolId'),
      router: LoopV2Launch2Codec.anyCaseAddress(map, 'router'),
      routerRegistry: LoopV2Launch2Codec.anyCaseAddress(map, 'routerRegistry'),
      routingPolicy: policy,
      priceTiming: timing,
      buyTaxBps: LoopV2Launch2Codec.bps(map, 'buyTaxBps'),
      baseSellTaxBps: LoopV2Launch2Codec.bps(map, 'baseSellTaxBps'),
      excludeBuybackFromRewards: LoopV2ChainCodec.requireBool(
        map,
        'excludeBuybackFromRewards',
      ),
      armed: armed,
      currentRoundId: roundId,
      candleId: LoopV2Launch2Codec.integer(map, 'candleId'),
      candleSeconds: candleSeconds,
      candleEndsAt: LoopV2ChainCodec.requireTimestamp(map, 'candleEndsAt'),
      rollPending: LoopV2ChainCodec.requireBool(map, 'rollPending'),
      currentDropWad: dropWad,
      currentDropBps: LoopV2Launch2Codec.bps(map, 'currentDropBps'),
      potUsd1: LoopV2Launch2Codec.amount(map, 'potUsd1'),
      carryUsd1: LoopV2Launch2Codec.amount(map, 'carryUsd1'),
      roundExtraFeesUsd1: LoopV2Launch2Codec.amount(map, 'roundExtraFeesUsd1'),
      roundTotalBuyWeightUsd1: total,
      reservedRewardsUsd1: LoopV2Launch2Codec.amount(
        map,
        'reservedRewardsUsd1',
      ),
      priceUsd1: LoopV2Launch2Codec.amount(map, 'priceUsd1'),
      viewer: viewer,
      summary: Launch2DynamicSummary(
        roundCount: roundCount,
        closedRoundCount: closedCount,
        allocatedUsd1: LoopV2Launch2Codec.amount(summary, 'allocatedUsd1'),
        claimedUsd1: LoopV2Launch2Codec.amount(summary, 'claimedUsd1'),
        dynamicFeesUsd1: LoopV2Launch2Codec.amount(summary, 'dynamicFeesUsd1'),
        baseSellFeesUsd1: LoopV2Launch2Codec.amount(
          summary,
          'baseSellFeesUsd1',
        ),
        buyFeesMeme: LoopV2Launch2Codec.amount(summary, 'buyFeesMeme'),
      ),
      basisBlockNumber: LoopV2Launch2Codec.integer(basis, 'blockNumber'),
    );
  }

  // -------------------------------------------------------------------------
  // GET …/dynamic-pool/rewards
  // -------------------------------------------------------------------------

  /// `GET …/dynamic-pool/rewards` for [walletId]. An OfficialTax instance
  /// answers `hookKind: officialTax` with no rounds.
  static Launch2DynamicRewards rewards(
    Object? raw, {
    required String instanceId,
    required String walletId,
  }) {
    final root = _root(raw, rewardsKeys);
    if (LoopV2Launch2Codec.uuid(root, 'instanceId') != instanceId ||
        LoopV2Launch2Codec.uuid(root, 'walletId') != walletId) {
      _invalid();
    }
    final hookKind = _hookKind(root);
    final items = LoopV2ChainCodec.requireList(root['rounds'], maximum: 100);
    if (hookKind == 'officialTax' && items.isNotEmpty) _invalid();
    final seen = <BigInt>{};
    final rounds = <Launch2DynamicRound>[];
    for (final item in items) {
      final round = _round(item);
      if (!seen.add(round.roundId)) _invalid();
      rounds.add(round);
    }
    return Launch2DynamicRewards(
      walletId: walletId,
      claimableUsd1: LoopV2Launch2Codec.amount(root, 'claimableUsd1'),
      claimedUsd1: LoopV2Launch2Codec.amount(root, 'claimedUsd1'),
      rounds: List<Launch2DynamicRound>.unmodifiable(rounds),
    );
  }

  static Launch2DynamicRound _round(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, roundKeys);
    final statusText = map['status'];
    final status = statusText is String
        ? Launch2DynamicRoundStatus.tryParse(statusText)
        : null;
    if (status == null) _invalid();
    final start = LoopV2Launch2Codec.integer(map, 'startCandle');
    final end = LoopV2Launch2Codec.optionalInteger(map, 'endCandle');
    final weight = LoopV2Launch2Codec.amount(map, 'weightUsd1');
    final total = LoopV2Launch2Codec.amount(map, 'totalBuyWeightUsd1');
    final allocation = _optionalAmount(map, 'allocationUsd1');
    final claimable = LoopV2Launch2Codec.amount(map, 'claimableUsd1');
    final claimed = _optionalAmount(map, 'claimedUsd1');
    final open = status == Launch2DynamicRoundStatus.open;
    // A running round has no closing candle and no allocation yet; a closed
    // one closed on a candle after the one that armed it. Only a claimed
    // round has what was claimed.
    if (open != (end == null) ||
        (open && allocation != null) ||
        (end != null && end < start) ||
        weight > total ||
        (status == Launch2DynamicRoundStatus.claimed) != (claimed != null)) {
      _invalid();
    }
    return Launch2DynamicRound(
      roundId: LoopV2Launch2Codec.integer(map, 'roundId'),
      status: status,
      weightUsd1: weight,
      totalBuyWeightUsd1: total,
      allocationUsd1: allocation,
      claimableUsd1: claimable,
      claimedUsd1: claimed,
      claimTransactionHash: LoopV2Launch2Codec.optionalHash(
        map,
        'claimTransactionHash',
      ),
      claimedAt: LoopV2ChainCodec.optionalTimestamp(map, 'claimedAt'),
      startCandle: start,
      endCandle: end,
      activatedAt: LoopV2ChainCodec.requireTimestamp(map, 'activatedAt'),
      closedAt: LoopV2ChainCodec.optionalTimestamp(map, 'closedAt'),
    );
  }

  // -------------------------------------------------------------------------
  // POST …/dynamic-pool/claim/prepare | report
  // -------------------------------------------------------------------------

  /// `POST …/dynamic-pool/claim/prepare` (201): one `dynamic_claim` intent
  /// for this instance, wallet and round, sent to the round's Hook with no
  /// approval (a claim spends nothing).
  static Launch2DynamicClaimPrepared claimPrepared(
    Object? raw, {
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  }) {
    final root = _root(raw, const <String>{
      'launch2Intent',
      'claim',
      'contractVersion',
    });
    final intent = LoopV2Launch2Codec.intentBody(
      root['launch2Intent'],
      venue: Launch2Venue.loopDynamicRewards,
    );
    final claimMap = LoopV2Contract.strictMap(root['claim'], claimKeys);
    final claim = Launch2DynamicClaim(
      roundId: LoopV2Launch2Codec.integer(claimMap, 'roundId'),
      hook: LoopV2Launch2Codec.anyCaseAddress(claimMap, 'hook'),
      claimableUsd1: LoopV2Launch2Codec.amount(claimMap, 'claimableUsd1'),
    );
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != Launch2IntentKind.rewardClaim ||
        intent.approval != null ||
        claim.roundId != roundId ||
        intent.contractAddress.toLowerCase() != claim.hook) {
      _invalid();
    }
    return Launch2DynamicClaimPrepared(intent: intent, claim: claim);
  }

  /// `POST …/dynamic-pool/claim/report` (200), checked against what was
  /// reported.
  static Launch2DynamicClaimReport report(
    Object? raw, {
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  }) {
    final root = _root(raw, const <String>{
      'dynamicClaimReport',
      'contractVersion',
    });
    final map = LoopV2Contract.strictMap(
      root['dynamicClaimReport'],
      reportKeys,
    );
    final statusText = map['status'];
    final status = statusText is String
        ? Launch2DynamicClaimStatus.tryParse(statusText)
        : null;
    if (status == null) _invalid();
    final reportedRound = LoopV2Launch2Codec.integer(map, 'roundId');
    final hash = LoopV2Launch2Codec.hash(map, 'transactionHash');
    final amount = _optionalAmount(map, 'amountUsd1');
    if (LoopV2Launch2Codec.uuid(map, 'intentId') != intentId ||
        LoopV2Launch2Codec.uuid(map, 'instanceId') != instanceId ||
        LoopV2Launch2Codec.uuid(map, 'walletId') != walletId ||
        reportedRound != roundId ||
        hash != transactionHash.toLowerCase() ||
        // `confirmed` carries what RewardClaimed paid.
        (status == Launch2DynamicClaimStatus.confirmed && amount == null)) {
      _invalid();
    }
    return Launch2DynamicClaimReport(
      intentId: intentId,
      roundId: reportedRound,
      transactionHash: hash,
      status: status,
      amountUsd1: amount,
      claimedAt: LoopV2ChainCodec.optionalTimestamp(map, 'claimedAt'),
      blockNumber: LoopV2Launch2Codec.optionalInteger(map, 'blockNumber'),
      reportedAt: LoopV2ChainCodec.requireTimestamp(map, 'reportedAt'),
    );
  }
}
