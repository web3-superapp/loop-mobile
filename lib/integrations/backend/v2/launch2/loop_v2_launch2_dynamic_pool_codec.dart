import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the LoopDynamic half of `launch2` (client decision
/// 0157, loop-api S166 draft of 2026-10-13). Every object is closed: an
/// unknown, missing or repeated key is `invalidPayload`. The draft does not
/// show `contractVersion` on these roots; it is accepted when present and
/// then must be `2.0`.
abstract final class LoopV2Launch2DynamicPoolCodec {
  static const stateKeys = <String>{
    'hookAddress',
    'armed',
    'currentRoundId',
    'currentDropWad',
    'pot',
    'totalBuyWeight',
    'myBuyWeight',
    'priceTiming',
    'baseSellFeePpm',
    'routingPolicy',
  };

  static const roundKeys = <String>{
    'roundId',
    'startCandle',
    'endCandle',
    'closed',
    'allocation',
    'myWeight',
    'totalWeight',
    'claimable',
    'claimed',
  };

  static const reportKeys = <String>{'roundId', 'status'};

  static const _version = <String>{'contractVersion'};

  static final RegExp _policyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$');

  static Never _invalid() => LoopV2Launch2Codec.invalid();

  static Map<String, Object?> _root(Object? raw, Set<String> keys) {
    final map = LoopV2Contract.strictMapWithOptional(raw, keys, _version);
    if (map.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(map);
    }
    return map;
  }

  static BigInt? _optionalInteger(Map<String, Object?> map, String key) =>
      map[key] == null ? null : LoopV2Launch2Codec.integer(map, key);

  static Decimal? _optionalAmount(Map<String, Object?> map, String key) =>
      map[key] == null ? null : LoopV2Launch2Codec.amount(map, key);

  /// `GET …/dynamic-pool` (200 only; a 404 never reaches the codec).
  static Launch2DynamicPoolState state(Object? raw) {
    final map = _root(raw, stateKeys);
    final armed = LoopV2ChainCodec.requireBool(map, 'armed');
    final roundId = _optionalInteger(map, 'currentRoundId');
    // A running round has an id; none is running without one armed.
    if (armed && roundId == null) _invalid();
    final drop = LoopV2Launch2Codec.integer(map, 'currentDropWad');
    if (drop > launch2Wad) _invalid();
    final total = LoopV2Launch2Codec.amount(map, 'totalBuyWeight');
    final mine = _optionalAmount(map, 'myBuyWeight');
    if (mine != null && mine > total) _invalid();
    final timingText = map['priceTiming'];
    final timing = timingText is String
        ? Launch2PriceTiming.tryParse(timingText)
        : null;
    final policy = map['routingPolicy'];
    if (timing == null ||
        policy is! String ||
        !_policyPattern.hasMatch(policy)) {
      _invalid();
    }
    return Launch2DynamicPoolState(
      hookAddress: LoopV2Launch2Codec.anyCaseAddress(map, 'hookAddress'),
      armed: armed,
      currentRoundId: roundId,
      currentDropWad: drop,
      pot: LoopV2Launch2Codec.amount(map, 'pot'),
      totalBuyWeight: total,
      myBuyWeight: mine,
      priceTiming: timing,
      baseSellFeePpm: LoopV2ChainCodec.requireInt(
        map,
        'baseSellFeePpm',
        maximum: 1000000,
      ),
      routingPolicy: policy,
    );
  }

  /// `GET …/dynamic-pool/rewards`.
  static Launch2DynamicRewards rewards(Object? raw) {
    final root = _root(raw, const <String>{'rounds'});
    final items = LoopV2ChainCodec.requireList(root['rounds'], maximum: 500);
    final seen = <BigInt>{};
    final rounds = <Launch2DynamicRound>[];
    for (final item in items) {
      final round = _round(item);
      if (!seen.add(round.roundId)) _invalid();
      rounds.add(round);
    }
    return Launch2DynamicRewards(
      rounds: List<Launch2DynamicRound>.unmodifiable(rounds),
    );
  }

  static Launch2DynamicRound _round(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, roundKeys);
    final closed = LoopV2ChainCodec.requireBool(map, 'closed');
    final start = LoopV2Launch2Codec.integer(map, 'startCandle');
    final end = _optionalInteger(map, 'endCandle');
    final allocation = _optionalAmount(map, 'allocation');
    // A closed round has its green candle (after the one that armed it) and
    // its allocation; an open one has neither, and nothing to claim.
    if (closed != (end != null) ||
        closed != (allocation != null) ||
        (end != null && end < start)) {
      _invalid();
    }
    final mine = LoopV2Launch2Codec.amount(map, 'myWeight');
    final total = LoopV2Launch2Codec.amount(map, 'totalWeight');
    final claimable = LoopV2Launch2Codec.amount(map, 'claimable');
    // The draft does not say whether `claimed` is a flag or an amount; both
    // are read, nothing else is.
    final rawClaimed = map['claimed'];
    final Decimal? claimedAmount = rawClaimed is bool
        ? null
        : LoopV2Launch2Codec.amount(map, 'claimed');
    final alreadyClaimed = rawClaimed is bool
        ? rawClaimed
        : claimedAmount! > Decimal.zero;
    if (mine > total ||
        (allocation != null && claimable > allocation) ||
        (allocation != null &&
            claimedAmount != null &&
            claimedAmount > allocation) ||
        (!closed && (claimable > Decimal.zero || alreadyClaimed))) {
      _invalid();
    }
    return Launch2DynamicRound(
      roundId: LoopV2Launch2Codec.integer(map, 'roundId'),
      startCandle: start,
      endCandle: end,
      closed: closed,
      allocation: allocation,
      myWeight: mine,
      totalWeight: total,
      claimable: claimable,
      alreadyClaimed: alreadyClaimed,
      claimedAmount: claimedAmount,
    );
  }

  /// `POST …/dynamic-pool/claim/prepare`: one `dynamic_claim` intent for
  /// this instance and wallet, with no approval (a claim spends nothing).
  static Launch2Intent claimIntent(
    Object? raw, {
    required String instanceId,
    required String walletId,
  }) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'launch2Intent',
      'contractVersion',
    });
    LoopV2ChainCodec.requireContractVersion(root);
    final intent = LoopV2Launch2Codec.intentBody(
      root['launch2Intent'],
      venue: Launch2Venue.loopDynamicRewards,
    );
    if (intent.instanceId != instanceId ||
        intent.walletId != walletId ||
        intent.kind != Launch2IntentKind.rewardClaim ||
        intent.approval != null) {
      _invalid();
    }
    return intent;
  }

  /// `POST …/dynamic-pool/claim/report`.
  static Launch2DynamicClaimReport report(
    Object? raw, {
    required BigInt roundId,
  }) {
    final map = _root(raw, reportKeys);
    final status = map['status'];
    if (status != 'submitted' && status != 'confirmed' && status != 'failed') {
      _invalid();
    }
    final reported = LoopV2Launch2Codec.integer(map, 'roundId');
    if (reported != roundId) _invalid();
    return Launch2DynamicClaimReport(
      roundId: reported,
      status: status! as String,
    );
  }
}
