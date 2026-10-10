import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/crypto/loop_keccak.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the S138 hourly mining rewards (decision 0140).
///
/// Two drafts of the same contract exist while `frontend-v2-mining-rewards-
/// api.md` is being written, and both decode into one view model:
///
/// * the **hourly block** — `GET /v2/mining/rewards` carrying an `hourly`
///   object next to the legacy keys (loop-api decision 0116 draft); amounts
///   are raw integer strings (`*Raw`, 18 decimals);
/// * the **flat draft** of the S138 work order — `settledTotal`, `display`,
///   `nft`, `asset`, `invites`, `claim`, `serverTime` at the root; amounts are
///   whole-LOOP decimal strings with up to 18 decimals.
///
/// Every object is read through [LoopV2Contract.strictMap] or
/// [LoopV2Contract.strictMapWithOptional]: an unknown key is an invalid
/// payload, and a key listed as optional may be absent without failing.
abstract final class LoopV2MiningRewardsCodec {
  static final RegExp rawPattern = RegExp(r'^(0|[1-9][0-9]{0,77})$');
  static final RegExp loopDecimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,59})(\.[0-9]{1,18})?$',
  );
  static final RegExp powerPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
  );
  static final RegExp addressPattern = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp hashPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp hexDataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp quantityPattern = RegExp(
    r'^0x(0|[1-9a-f][0-9a-f]{0,63})$',
  );
  static final RegExp digestPattern = RegExp(r'^(0x)?[0-9a-f]{64}$');
  static final RegExp memeAssetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:0x[0-9a-f]{40}$',
  );
  static final RegExp symbolPattern = RegExp(r'^[A-Za-z0-9._-]{1,24}$');

  /// The legacy keys the rewards resource keeps next to `hourly`. They belong
  /// to the retired daily page and are not decoded here.
  static const legacyRootKeys = <String>{
    'claimable',
    'claimExecutable',
    'estimatedToday',
    'accumulated',
    'ledger',
    'source',
    'contractVersion',
  };

  static const hourlyKeys = <String>{
    'serverTime',
    'decimals',
    'displayState',
    'reasonCode',
    'totals',
    'lastHour',
    'display',
    'tracks',
    'referral',
    'parameters',
    'claim',
  };

  static const claimKeys = <String>{
    'claimId',
    'walletId',
    'status',
    'chainId',
    'chainReference',
    'contractAddress',
    'cumulativeAmountRaw',
    'amountRaw',
    'nonce',
    'deadline',
    'transactionHash',
    'blockNumber',
    'failureReasonCode',
    'createdAt',
    'updatedAt',
  };

  static const flatRootKeys = <String>{
    'settledTotal',
    'claimedTotal',
    'claimable',
    'lastEpoch',
    'display',
    'nft',
    'asset',
    'invites',
    'claim',
    'serverTime',
  };

  static const flatRootOptionalKeys = <String>{
    'contractVersion',
    'decimals',
    'minimumClaim',
  };

  static const transactionRequiredKeys = <String>{
    'chainId',
    'to',
    'data',
    'from',
  };
  static const transactionOptionalKeys = <String>{
    'value',
    'gas',
    'nonce',
    'type',
    'maxFeePerGas',
    'maxPriorityFeePerGas',
    'gasPrice',
  };

  static Never invalid() => LoopV2ChainCodec.invalid();

  // -------------------------------------------------------------------------
  // scalars
  // -------------------------------------------------------------------------

  static BigInt raw(Map<String, Object?> map, String key) => BigInt.parse(
    LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: rawPattern,
      maxLength: 78,
    ),
  );

  /// A whole-LOOP decimal string (`"60"`, `"0.0166"`) in the smallest unit.
  static BigInt loop(Map<String, Object?> map, String key) {
    final text = LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: loopDecimalPattern,
      maxLength: 80,
    );
    final dot = text.indexOf('.');
    final whole = dot < 0 ? text : text.substring(0, dot);
    final fraction = dot < 0 ? '' : text.substring(dot + 1);
    return BigInt.parse(whole) * miningLoopUnit +
        BigInt.parse(fraction.padRight(miningLoopDecimals, '0'));
  }

  static Decimal power(Map<String, Object?> map, String key) => Decimal.parse(
    LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: powerPattern,
      maxLength: 120,
    ),
  );

  static int count(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int && value >= 0) return value;
    if (value is String && rawPattern.hasMatch(value) && value.length <= 15) {
      return int.parse(value);
    }
    invalid();
  }

  static BigInt bigCount(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int && value >= 0) return BigInt.from(value);
    if (value is String) return raw(map, key);
    invalid();
  }

  static Object? _nullable(Map<String, Object?> map, String key) => map[key];

  static String _hash(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: hashPattern,
        maxLength: 66,
      );

  static String _address(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: addressPattern,
        maxLength: 42,
      );

  static String _id(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      );

  // -------------------------------------------------------------------------
  // GET /v2/mining/rewards
  // -------------------------------------------------------------------------

  /// Decodes either draft. The `hourly` key decides which one arrived.
  static MiningRewardsView rewards(Object? raw) {
    if (raw is Map && raw.containsKey('hourly')) return _hourlyRoot(raw);
    return _flatRoot(raw);
  }

  static MiningRewardsView _hourlyRoot(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(raw, const <String>{
      'hourly',
    }, legacyRootKeys);
    if (root.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(root);
    }
    final map = LoopV2Contract.strictMap(root['hourly'], hourlyKeys);
    if (map['decimals'] != miningLoopDecimals) invalid();
    final rawState = map['displayState'];
    final displayState = rawState is String
        ? MiningDisplayState.tryParse(rawState)
        : null;
    if (displayState == null) invalid();
    final reasonCode = LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode');
    final serverTime = LoopV2ChainCodec.requireTimestamp(map, 'serverTime');

    final totalsRaw = _nullable(map, 'totals');
    BigInt settled = BigInt.zero;
    BigInt claimed = BigInt.zero;
    BigInt claimable = BigInt.zero;
    if (totalsRaw != null) {
      final totals = LoopV2Contract.strictMap(totalsRaw, const <String>{
        'settledRaw',
        'claimedRaw',
        'claimableRaw',
      });
      settled = LoopV2MiningRewardsCodec.raw(totals, 'settledRaw');
      claimed = LoopV2MiningRewardsCodec.raw(totals, 'claimedRaw');
      claimable = LoopV2MiningRewardsCodec.raw(totals, 'claimableRaw');
    } else if (displayState != MiningDisplayState.unavailable) {
      // Totals are the ledger; only an unavailable store may withhold them.
      invalid();
    }

    MiningRewardEpoch? epoch;
    final lastHourRaw = _nullable(map, 'lastHour');
    if (lastHourRaw != null) {
      final hour = LoopV2Contract.strictMap(lastHourRaw, const <String>{
        'epochId',
        'hourStart',
        'hourEnd',
        'settledAt',
        'nftRewardRaw',
        'assetRewardRaw',
        'totalRewardRaw',
      });
      _id(hour, 'epochId');
      LoopV2ChainCodec.optionalTimestamp(hour, 'settledAt');
      epoch = MiningRewardEpoch(
        epochStart: LoopV2ChainCodec.requireTimestamp(hour, 'hourStart'),
        epochEnd: LoopV2ChainCodec.requireTimestamp(hour, 'hourEnd'),
        nftReward: LoopV2MiningRewardsCodec.raw(hour, 'nftRewardRaw'),
        assetReward: LoopV2MiningRewardsCodec.raw(hour, 'assetRewardRaw'),
        totalReward: LoopV2MiningRewardsCodec.raw(hour, 'totalRewardRaw'),
      );
      if (!epoch.epochEnd.isAfter(epoch.epochStart)) invalid();
    }

    var minutes = 0;
    var increment = BigInt.zero;
    DateTime? windowStart;
    DateTime? nextUpdateAt;
    final displayRaw = _nullable(map, 'display');
    if (displayRaw != null) {
      final display = LoopV2Contract.strictMap(displayRaw, const <String>{
        'windowStart',
        'windowEnd',
        'totalRaw',
        'perMinuteRaw',
        'completedMinutes',
        'displayedRaw',
        'nextUpdateAt',
      });
      windowStart = LoopV2ChainCodec.optionalTimestamp(display, 'windowStart');
      LoopV2ChainCodec.optionalTimestamp(display, 'windowEnd');
      LoopV2MiningRewardsCodec.raw(display, 'totalRaw');
      LoopV2MiningRewardsCodec.raw(display, 'displayedRaw');
      increment = LoopV2MiningRewardsCodec.raw(display, 'perMinuteRaw');
      minutes = LoopV2ChainCodec.requireInt(
        display,
        'completedMinutes',
        maximum: 60,
      );
      nextUpdateAt = LoopV2ChainCodec.optionalTimestamp(
        display,
        'nextUpdateAt',
      );
    }
    if (displayState == MiningDisplayState.showing && epoch == null) invalid();

    MiningNftTrack? nft;
    MiningAssetTrack? asset;
    final tracksRaw = _nullable(map, 'tracks');
    if (tracksRaw != null) {
      final tracks = LoopV2Contract.strictMap(tracksRaw, const <String>{
        'nft',
        'asset',
      });
      final n = LoopV2Contract.strictMap(tracks['nft'], const <String>{
        'realNftCount',
        'selfPower',
        'referralPower',
        'totalPower',
        'networkPower',
        'budgetRaw',
        'rewardRaw',
        'holdings',
      });
      for (final entry in LoopV2ChainCodec.requireList(n['holdings'])) {
        final row = LoopV2Contract.strictMap(entry, const <String>{
          'instanceId',
          'communityId',
          'countAtEnd',
          'power',
        });
        _id(row, 'instanceId');
        if (row['communityId'] != null) _id(row, 'communityId');
        LoopV2MiningRewardsCodec.raw(row, 'countAtEnd');
        power(row, 'power');
      }
      power(n, 'networkPower');
      LoopV2MiningRewardsCodec.raw(n, 'budgetRaw');
      nft = MiningNftTrack(
        realCount: LoopV2MiningRewardsCodec.raw(n, 'realNftCount'),
        ownPower: power(n, 'selfPower'),
        invitePower: power(n, 'referralPower'),
        totalPower: power(n, 'totalPower'),
        reward: LoopV2MiningRewardsCodec.raw(n, 'rewardRaw'),
      );
      final a = LoopV2Contract.strictMap(tracks['asset'], const <String>{
        'selfPower',
        'referralPower',
        'totalPower',
        'networkPower',
        'budgetRaw',
        'rewardRaw',
        'holdings',
        'excludedAssets',
      });
      final assets = <MiningTrackAsset>[];
      final seen = <String>{};
      for (final entry in LoopV2ChainCodec.requireList(a['holdings'])) {
        final row = LoopV2Contract.strictMap(entry, const <String>{
          'assetId',
          'balanceAtEndRaw',
          'power',
        });
        final assetId = LoopV2ChainCodec.requireString(
          row,
          'assetId',
          pattern: memeAssetIdPattern,
          maxLength: 80,
        );
        if (!seen.add(assetId)) invalid();
        LoopV2MiningRewardsCodec.raw(row, 'balanceAtEndRaw');
        assets.add(
          MiningTrackAsset(assetId: assetId, power: power(row, 'power')),
        );
      }
      for (final entry in LoopV2ChainCodec.requireList(a['excludedAssets'])) {
        final row = LoopV2Contract.strictMap(entry, const <String>{
          'assetId',
          'reasonCode',
        });
        LoopV2ChainCodec.requireString(
          row,
          'assetId',
          pattern: memeAssetIdPattern,
          maxLength: 80,
        );
        LoopV2ChainCodec.requireReasonCode(row, 'reasonCode');
      }
      power(a, 'networkPower');
      LoopV2MiningRewardsCodec.raw(a, 'budgetRaw');
      asset = MiningAssetTrack(
        assets: List<MiningTrackAsset>.unmodifiable(assets),
        ownPower: power(a, 'selfPower'),
        invitePower: power(a, 'referralPower'),
        totalPower: power(a, 'totalPower'),
        reward: LoopV2MiningRewardsCodec.raw(a, 'rewardRaw'),
      );
    }

    MiningInvites? invites;
    final referralRaw = _nullable(map, 'referral');
    if (referralRaw != null) {
      final referral = LoopV2Contract.strictMap(referralRaw, const <String>{
        'levels',
      });
      final levels = <MiningInviteLevel>[];
      for (final entry in LoopV2ChainCodec.requireList(
        referral['levels'],
        maximum: 5,
      )) {
        final row = LoopV2Contract.strictMap(entry, const <String>{
          'level',
          'ratioBps',
          'effectiveMembers',
          'nftPower',
          'assetPower',
          'totalPower',
          'nftUnitsByCommunity',
        });
        for (final unit in LoopV2ChainCodec.requireList(
          row['nftUnitsByCommunity'],
        )) {
          final u = LoopV2Contract.strictMap(unit, const <String>{
            'communityId',
            'units',
          });
          if (u['communityId'] != null) _id(u, 'communityId');
          power(u, 'units');
        }
        power(row, 'totalPower');
        final bps = LoopV2ChainCodec.requireInt(
          row,
          'ratioBps',
          maximum: 10000,
        );
        levels.add(
          MiningInviteLevel(
            level: LoopV2ChainCodec.requireInt(
              row,
              'level',
              minimum: 1,
              maximum: 5,
            ),
            ratePercent: (Decimal.fromInt(bps) / Decimal.fromInt(100))
                .toDecimal(),
            activeMembers: LoopV2ChainCodec.requireInt(row, 'effectiveMembers'),
            nftPower: power(row, 'nftPower'),
            assetPower: power(row, 'assetPower'),
          ),
        );
      }
      invites = _invites(levels);
    }

    BigInt? minimumClaim;
    final parametersRaw = _nullable(map, 'parameters');
    if (parametersRaw != null) {
      final parameters = LoopV2Contract.strictMap(parametersRaw, const <String>{
        'versionId',
        'configVersion',
        'effectiveFrom',
        'referralRatiosBps',
        'minimumClaimRaw',
      });
      _id(parameters, 'versionId');
      LoopV2ChainCodec.requireText(parameters, 'configVersion', maxLength: 64);
      LoopV2ChainCodec.requireTimestamp(parameters, 'effectiveFrom');
      final ratios = LoopV2ChainCodec.requireList(
        parameters['referralRatiosBps'],
        maximum: 5,
      );
      if (ratios.length != 5 ||
          ratios.any((value) => value is! int || value < 0 || value > 10000)) {
        invalid();
      }
      minimumClaim = LoopV2MiningRewardsCodec.raw(
        parameters,
        'minimumClaimRaw',
      );
    }

    final claimMap = LoopV2Contract.strictMap(map['claim'], const <String>{
      'executable',
      'reasonCode',
      'latest',
    });
    final latest = claimMap['latest'] == null
        ? null
        : claimRecord(claimMap['latest']);
    final claim = MiningClaimSummary(
      status: latest?.status ?? MiningClaimStatus.none,
      claimId: latest?.claimId,
      amount: latest?.amount,
      lastTx: latest?.tx,
      failureReasonCode: latest?.failureReasonCode,
      executable: LoopV2ChainCodec.requireBool(claimMap, 'executable'),
      reasonCode: LoopV2ChainCodec.optionalReasonCode(claimMap, 'reasonCode'),
    );

    return MiningRewardsView(
      settledTotal: settled,
      claimedTotal: claimed,
      claimable: claimable,
      lastEpoch: epoch,
      display: MiningMinuteDisplay(
        state: displayState,
        minutesElapsed: minutes,
        minuteIncrement: increment,
        windowStart: windowStart,
        nextUpdateAt: nextUpdateAt,
        reasonCode: reasonCode,
      ),
      nft: nft,
      asset: asset,
      invites: invites,
      claim: claim,
      serverTime: serverTime,
      minimumClaim: minimumClaim,
    );
  }

  static MiningInvites _invites(
    List<MiningInviteLevel> levels, {
    MiningInviteTotal? total,
  }) {
    // Five levels, each once, in order.
    final seen = <int>{};
    for (final level in levels) {
      if (!seen.add(level.level)) invalid();
    }
    final ordered = List<MiningInviteLevel>.of(levels)
      ..sort((a, b) => a.level.compareTo(b.level));
    var members = 0;
    var nftPower = Decimal.zero;
    var assetPower = Decimal.zero;
    for (final level in ordered) {
      members += level.activeMembers;
      nftPower += level.nftPower;
      assetPower += level.assetPower;
    }
    return MiningInvites(
      levels: List<MiningInviteLevel>.unmodifiable(ordered),
      total:
          total ??
          MiningInviteTotal(
            activeMembers: members,
            nftPower: nftPower,
            assetPower: assetPower,
          ),
    );
  }

  static MiningRewardsView _flatRoot(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(
      raw,
      flatRootKeys,
      flatRootOptionalKeys,
    );
    if (root.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(root);
    }
    if (root.containsKey('decimals') &&
        root['decimals'] != miningLoopDecimals) {
      invalid();
    }

    MiningRewardEpoch? epoch;
    if (root['lastEpoch'] != null) {
      final e = LoopV2Contract.strictMapWithOptional(
        root['lastEpoch'],
        const <String>{
          'epochStart',
          'epochEnd',
          'totalReward',
          'nftReward',
          'assetReward',
        },
        const <String>{'epochId', 'settledAt'},
      );
      epoch = MiningRewardEpoch(
        epochStart: LoopV2ChainCodec.requireTimestamp(e, 'epochStart'),
        epochEnd: LoopV2ChainCodec.requireTimestamp(e, 'epochEnd'),
        totalReward: loop(e, 'totalReward'),
        nftReward: loop(e, 'nftReward'),
        assetReward: loop(e, 'assetReward'),
      );
      if (!epoch.epochEnd.isAfter(epoch.epochStart)) invalid();
    }

    final d = LoopV2Contract.strictMapWithOptional(
      root['display'],
      const <String>{
        'state',
        'minutesElapsed',
        'minuteIncrement',
        'nextUpdateAt',
      },
      const <String>{'windowStart', 'reasonCode'},
    );
    final rawState = d['state'];
    final state = rawState is String
        ? MiningDisplayState.tryParse(rawState)
        : null;
    if (state == null) invalid();
    if (state == MiningDisplayState.showing && epoch == null) invalid();

    MiningNftTrack? nft;
    if (root['nft'] != null) {
      final n = LoopV2Contract.strictMap(root['nft'], const <String>{
        'realCount',
        'ownPower',
        'invitePower',
        'totalPower',
        'reward',
      });
      nft = MiningNftTrack(
        realCount: bigCount(n, 'realCount'),
        ownPower: power(n, 'ownPower'),
        invitePower: power(n, 'invitePower'),
        totalPower: power(n, 'totalPower'),
        reward: loop(n, 'reward'),
      );
    }

    MiningAssetTrack? asset;
    if (root['asset'] != null) {
      final a = LoopV2Contract.strictMap(root['asset'], const <String>{
        'assets',
        'ownPower',
        'invitePower',
        'totalPower',
        'reward',
      });
      final assets = <MiningTrackAsset>[];
      final seen = <String>{};
      for (final entry in LoopV2ChainCodec.requireList(a['assets'])) {
        final row = LoopV2Contract.strictMapWithOptional(
          entry,
          const <String>{'assetId', 'power'},
          const <String>{'symbol', 'amount'},
        );
        final assetId = LoopV2ChainCodec.requireString(
          row,
          'assetId',
          pattern: memeAssetIdPattern,
          maxLength: 80,
        );
        if (!seen.add(assetId)) invalid();
        assets.add(
          MiningTrackAsset(
            assetId: assetId,
            power: power(row, 'power'),
            symbol: LoopV2ChainCodec.optionalString(
              row,
              'symbol',
              pattern: symbolPattern,
              maxLength: 24,
            ),
            balance: LoopV2ChainCodec.optionalString(
              row,
              'amount',
              pattern: powerPattern,
              maxLength: 120,
            ),
          ),
        );
      }
      asset = MiningAssetTrack(
        assets: List<MiningTrackAsset>.unmodifiable(assets),
        ownPower: power(a, 'ownPower'),
        invitePower: power(a, 'invitePower'),
        totalPower: power(a, 'totalPower'),
        reward: loop(a, 'reward'),
      );
    }

    MiningInvites? invites;
    if (root['invites'] != null) {
      final i = LoopV2Contract.strictMap(root['invites'], const <String>{
        'levels',
        'total',
      });
      final levels = <MiningInviteLevel>[
        for (final entry in LoopV2ChainCodec.requireList(
          i['levels'],
          maximum: 5,
        ))
          _flatLevel(entry),
      ];
      MiningInviteTotal? total;
      if (i['total'] != null) {
        final t = LoopV2Contract.strictMapWithOptional(
          i['total'],
          const <String>{'nftPower', 'assetPower'},
          const <String>{'activeMembers', 'totalPower'},
        );
        if (t.containsKey('totalPower')) power(t, 'totalPower');
        total = MiningInviteTotal(
          activeMembers: t.containsKey('activeMembers')
              ? count(t, 'activeMembers')
              : levels.fold<int>(0, (sum, l) => sum + l.activeMembers),
          nftPower: power(t, 'nftPower'),
          assetPower: power(t, 'assetPower'),
        );
      }
      invites = _invites(levels, total: total);
    }

    final c = LoopV2Contract.strictMapWithOptional(
      root['claim'],
      const <String>{'status', 'lastTx'},
      const <String>{'claimId', 'executable', 'reasonCode', 'amount'},
    );
    final rawStatus = c['status'];
    final status = rawStatus is String
        ? MiningClaimStatus.tryParse(rawStatus)
        : null;
    if (status == null) invalid();

    return MiningRewardsView(
      settledTotal: loop(root, 'settledTotal'),
      claimedTotal: loop(root, 'claimedTotal'),
      claimable: loop(root, 'claimable'),
      lastEpoch: epoch,
      display: MiningMinuteDisplay(
        state: state,
        minutesElapsed: LoopV2ChainCodec.requireInt(
          d,
          'minutesElapsed',
          maximum: 60,
        ),
        minuteIncrement: loop(d, 'minuteIncrement'),
        windowStart: LoopV2ChainCodec.optionalTimestamp(d, 'windowStart'),
        nextUpdateAt: LoopV2ChainCodec.optionalTimestamp(d, 'nextUpdateAt'),
        reasonCode: LoopV2ChainCodec.optionalReasonCode(d, 'reasonCode'),
      ),
      nft: nft,
      asset: asset,
      invites: invites,
      claim: MiningClaimSummary(
        status: status,
        lastTx: _flatTx(c['lastTx']),
        claimId: c['claimId'] == null ? null : _id(c, 'claimId'),
        executable: c.containsKey('executable')
            ? LoopV2ChainCodec.requireBool(c, 'executable')
            : true,
        reasonCode: LoopV2ChainCodec.optionalReasonCode(c, 'reasonCode'),
        amount: c['amount'] == null ? null : loop(c, 'amount'),
      ),
      serverTime: LoopV2ChainCodec.requireTimestamp(root, 'serverTime'),
      minimumClaim: root['minimumClaim'] == null
          ? null
          : loop(root, 'minimumClaim'),
    );
  }

  static MiningInviteLevel _flatLevel(Object? entry) {
    final row = LoopV2Contract.strictMapWithOptional(
      entry,
      const <String>{
        'level',
        'ratePercent',
        'activeMembers',
        'nftPower',
        'assetPower',
      },
      const <String>{'totalPower'},
    );
    if (row.containsKey('totalPower')) power(row, 'totalPower');
    final rate = row['ratePercent'];
    final Decimal ratePercent;
    if (rate is int && rate >= 0 && rate <= 100) {
      ratePercent = Decimal.fromInt(rate);
    } else if (rate is String && powerPattern.hasMatch(rate)) {
      ratePercent = Decimal.parse(rate);
      if (ratePercent > Decimal.fromInt(100)) invalid();
    } else {
      invalid();
    }
    return MiningInviteLevel(
      level: LoopV2ChainCodec.requireInt(row, 'level', minimum: 1, maximum: 5),
      ratePercent: ratePercent,
      activeMembers: count(row, 'activeMembers'),
      nftPower: power(row, 'nftPower'),
      assetPower: power(row, 'assetPower'),
    );
  }

  static MiningClaimTx? _flatTx(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      if (!hashPattern.hasMatch(raw)) invalid();
      return MiningClaimTx(txHash: raw);
    }
    final t = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'txHash'},
      const <String>{'chainId', 'amount', 'at'},
    );
    return MiningClaimTx(
      txHash: _hash(t, 'txHash'),
      chainId: t['chainId'] == null
          ? null
          : LoopV2ChainCodec.requireKnownChainId(t, 'chainId'),
      amount: t['amount'] == null ? null : loop(t, 'amount'),
      at: LoopV2ChainCodec.optionalTimestamp(t, 'at'),
    );
  }

  // -------------------------------------------------------------------------
  // claims
  // -------------------------------------------------------------------------

  /// One claim: the hourly-block schema (`amountRaw`), or the flat draft
  /// (`amount` in whole LOOP).
  static MiningClaimRecord claimRecord(Object? raw) {
    if (raw is Map && raw.containsKey('amountRaw')) {
      final map = LoopV2Contract.strictMap(raw, claimKeys);
      final status = MiningClaimStatus.tryParse('${map['status']}');
      if (status == null || status == MiningClaimStatus.none) invalid();
      final chainId = LoopV2ChainCodec.requireKnownChainId(map, 'chainId');
      final reference = map['chainReference'];
      if (reference != null && reference != loopChainReference(chainId)) {
        invalid();
      }
      _id(map, 'walletId');
      _address(map, 'contractAddress');
      LoopV2MiningRewardsCodec.raw(map, 'cumulativeAmountRaw');
      LoopV2MiningRewardsCodec.raw(map, 'nonce');
      LoopV2ChainCodec.requireTimestamp(map, 'deadline');
      LoopV2ChainCodec.requireTimestamp(map, 'updatedAt');
      if (map['blockNumber'] != null) {
        LoopV2MiningRewardsCodec.raw(map, 'blockNumber');
      }
      return MiningClaimRecord(
        claimId: _id(map, 'claimId'),
        status: status,
        amount: LoopV2MiningRewardsCodec.raw(map, 'amountRaw'),
        createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
        txHash: map['transactionHash'] == null
            ? null
            : _hash(map, 'transactionHash'),
        chainId: chainId,
        failureReasonCode: LoopV2ChainCodec.optionalReasonCode(
          map,
          'failureReasonCode',
        ),
      );
    }
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'claimId', 'status', 'amount', 'createdAt'},
      const <String>{'txHash', 'chainId', 'failureReasonCode', 'updatedAt'},
    );
    final status = MiningClaimStatus.tryParse('${map['status']}');
    if (status == null || status == MiningClaimStatus.none) invalid();
    return MiningClaimRecord(
      claimId: _id(map, 'claimId'),
      status: status,
      amount: loop(map, 'amount'),
      createdAt: LoopV2ChainCodec.requireTimestamp(map, 'createdAt'),
      txHash: map['txHash'] == null ? null : _hash(map, 'txHash'),
      chainId: map['chainId'] == null
          ? null
          : LoopV2ChainCodec.requireKnownChainId(map, 'chainId'),
      failureReasonCode: LoopV2ChainCodec.optionalReasonCode(
        map,
        'failureReasonCode',
      ),
    );
  }

  static MiningClaimPage claims(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'items', 'nextCursor'},
      const <String>{'decimals', 'contractVersion'},
    );
    if (root.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(root);
    }
    if (root.containsKey('decimals') &&
        root['decimals'] != miningLoopDecimals) {
      invalid();
    }
    final items = <MiningClaimRecord>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      root['items'],
      maximum: 50,
    )) {
      final record = claimRecord(entry);
      if (!seen.add(record.claimId)) invalid();
      items.add(record);
    }
    return MiningClaimPage(
      items: List<MiningClaimRecord>.unmodifiable(items),
      nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
    );
  }

  /// `claim/report` → the claim as the server now reads it.
  static MiningClaimRecord reported(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'claim'},
      const <String>{'decimals', 'contractVersion'},
    );
    if (root.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(root);
    }
    return claimRecord(root['claim']);
  }

  // -------------------------------------------------------------------------
  // claim/prepare
  // -------------------------------------------------------------------------

  static MiningClaimIntent prepared(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'claim', 'intent'},
      const <String>{'decimals', 'contractVersion'},
    );
    if (root.containsKey('contractVersion')) {
      LoopV2ChainCodec.requireContractVersion(root);
    }
    if (root.containsKey('decimals') &&
        root['decimals'] != miningLoopDecimals) {
      invalid();
    }
    final claimRaw = root['claim'];
    final claim = LoopV2Contract.strictMap(claimRaw, claimKeys);
    final record = claimRecord(claimRaw);
    final chainId = record.chainId!;
    final contractAddress = _address(claim, 'contractAddress');
    final intent = LoopV2Contract.strictMapWithOptional(
      root['intent'],
      const <String>{'calldata', 'unsignedTransaction', 'signing'},
      const <String>{'payloadDigest'},
    );
    final calldata = LoopV2Contract.strictMap(
      intent['calldata'],
      const <String>{'to', 'data', 'value'},
    );
    final calldataTo = _address(calldata, 'to');
    final calldataData = LoopV2ChainCodec.requireString(
      calldata,
      'data',
      pattern: hexDataPattern,
      maxLength: 100000,
    );
    if (calldata['value'] != '0') invalid();
    final transaction = _transaction(intent['unsignedTransaction']);
    final signing = LoopV2Contract.strictMap(intent['signing'], const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    if (signing['mode'] != 'device_eth_send_transaction') invalid();
    final digest = intent['payloadDigest'] == null
        ? localDigest(transaction.wire)
        : LoopV2ChainCodec.requireString(
            intent,
            'payloadDigest',
            pattern: digestPattern,
            maxLength: 66,
          );
    final matches =
        transaction.to == contractAddress &&
        calldataTo == contractAddress &&
        transaction.data == calldataData &&
        transaction.chainReference == loopChainReference(chainId);
    return MiningClaimIntent(
      claimId: record.claimId,
      walletId: _id(claim, 'walletId'),
      chainId: chainId,
      contractAddress: contractAddress,
      amount: record.amount,
      cumulativeAmount: LoopV2MiningRewardsCodec.raw(
        claim,
        'cumulativeAmountRaw',
      ),
      deadline: LoopV2ChainCodec.requireTimestamp(claim, 'deadline'),
      createdAt: record.createdAt,
      transaction: transaction,
      payloadDigest: digest,
      signingAllowed: LoopV2ChainCodec.requireBool(signing, 'allowed'),
      signingReasonCode: LoopV2ChainCodec.optionalReasonCode(
        signing,
        'reasonCode',
      ),
      payloadMatchesReview: matches,
    );
  }

  static MiningClaimTransaction _transaction(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      transactionRequiredKeys,
      transactionOptionalKeys,
    );
    final chainId = map['chainId'];
    if (chainId != 56 && chainId != 97) invalid();
    final value = map['value'];
    if (value != null && value != '0x0' && value != '0') invalid();
    final type = map['type'];
    if (type != null && type != 'eip1559' && type != 'legacy') invalid();
    for (final key in const <String>[
      'gas',
      'nonce',
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'gasPrice',
    ]) {
      LoopV2ChainCodec.optionalString(
        map,
        key,
        pattern: quantityPattern,
        maxLength: 66,
      );
    }
    return MiningClaimTransaction(
      chainReference: chainId! as int,
      to: _address(map, 'to'),
      data: LoopV2ChainCodec.requireString(
        map,
        'data',
        pattern: hexDataPattern,
        maxLength: 100000,
      ),
      from: _address(map, 'from'),
      wire: Map<String, Object?>.unmodifiable(map),
    );
  }

  /// keccak-256 over the transaction's canonical JSON (keys sorted). Used
  /// only when the server sent no digest of its own, so the sheet and the
  /// wallet are still bound to one object.
  static String localDigest(Map<String, Object?> wire) {
    final keys = wire.keys.toList()..sort();
    final canonical = jsonEncode(<String, Object?>{
      for (final key in keys) key: wire[key],
    });
    final bytes = loopKeccak256(utf8.encode(canonical));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  // -------------------------------------------------------------------------
  // claim/prepare refusals that are about gas
  // -------------------------------------------------------------------------

  static const gasInsufficientCode = 'CLAIM_GAS_INSUFFICIENT';
  static const noGasSourceCode = 'CLAIM_NO_GAS_SOURCE';

  /// Reads a `409` body for the two gas refusals. Returns `null` for anything
  /// else, which then goes through the ordinary envelope check.
  ///
  /// The reason is accepted as the envelope `code` (S138 draft) or as
  /// `detailsSafe.reasonCode` under `INSUFFICIENT_BALANCE` (loop-api 0116
  /// draft). The swap suggestion is accepted nested (`suggestedSwap`) or as
  /// the flat `suggestedSwap…` slots.
  static ({String reason, MiningSuggestedSwap? swap, String? requiredNative})?
  gasRefusal(Object? body) {
    if (body is! Map) return null;
    final details = body['detailsSafe'];
    final detailMap = details is Map ? details : const <Object?, Object?>{};
    final code = body['code'];
    final detailReason = detailMap['reasonCode'];
    String? reason;
    for (final candidate in <Object?>[code, detailReason]) {
      if (candidate == gasInsufficientCode || candidate == noGasSourceCode) {
        reason = candidate! as String;
      }
    }
    if (reason == null) return null;
    String? text(Object? value, RegExp pattern, int max) =>
        value is String && value.length <= max && pattern.hasMatch(value)
        ? value
        : null;
    final asset = LoopV2ChainCodec.assetIdPattern;
    MiningSuggestedSwap? swap;
    final nested = detailMap['suggestedSwap'] ?? body['suggestedSwap'];
    if (nested is Map) {
      swap = MiningSuggestedSwap(
        fromAssetId: text(nested['fromAssetId'], asset, 80),
        toAssetId: text(nested['toAssetId'], asset, 80),
        fromSymbol: text(nested['fromSymbol'], symbolPattern, 24),
        toSymbol: text(nested['toSymbol'], symbolPattern, 24),
        amount: text(nested['amount'], powerPattern, 80),
      );
    } else if (detailMap.keys.any(
      (key) => key is String && key.startsWith('suggestedSwap'),
    )) {
      swap = MiningSuggestedSwap(
        fromAssetId: text(detailMap['suggestedSwapFromAssetId'], asset, 80),
        toAssetId: text(detailMap['suggestedSwapToAssetId'], asset, 80),
        fromSymbol: text(
          detailMap['suggestedSwapFromSymbol'],
          symbolPattern,
          24,
        ),
        toSymbol: text(detailMap['suggestedSwapToSymbol'], symbolPattern, 24),
        amount: text(detailMap['suggestedSwapToAmount'], powerPattern, 80),
      );
    }
    return (
      reason: reason,
      swap: swap,
      requiredNative: text(detailMap['requiredNativeAmount'], powerPattern, 80),
    );
  }
}
