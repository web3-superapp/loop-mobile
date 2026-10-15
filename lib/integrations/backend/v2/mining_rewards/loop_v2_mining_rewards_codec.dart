import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/crypto/loop_keccak.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';

/// Strict decoders for the S138 hourly mining rewards (decisions 0140, 0141).
///
/// The contract is loop-api `docs/frontend-v2-mining-rewards-api.md` with
/// `openapi/loop-api.v2.json` (loop-api decision 0116): `GET
/// /v2/mining/rewards` carries an `hourly` object next to the legacy daily
/// keys, every LOOP amount is a raw integer string (`*Raw`, 18 decimals), and
/// every power a decimal string. Only the `hourly` block is decoded; the
/// legacy keys are accepted and not read.
///
/// Every object is read through [LoopV2Contract.strictMap]: an unknown or a
/// missing key is an invalid payload. The only optional keys are the legacy
/// root keys of the rewards resource, which the contract keeps "unchanged"
/// for the retired daily page and may drop.
abstract final class LoopV2MiningRewardsCodec {
  static final RegExp rawPattern = RegExp(r'^(0|[1-9][0-9]{0,77})$');
  static final RegExp powerPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,18})?$',
  );
  static final RegExp addressPattern = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp hashPattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp hexDataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp quantityPattern = RegExp(
    r'^0x(0|[1-9a-f][0-9a-f]{0,63})$',
  );
  static final RegExp memeAssetIdPattern = RegExp(
    r'^eip155:[1-9][0-9]{0,9}:0x[0-9a-f]{40}$',
  );
  static final RegExp symbolPattern = RegExp(r'^[A-Za-z0-9._-]{1,24}$');

  /// The legacy daily keys the rewards resource keeps next to `hourly`
  /// (contract §3). They belong to the retired daily page and are not read.
  static const legacyRootKeys = <String>{
    'claimable',
    'claimExecutable',
    'estimatedToday',
    'accumulated',
    'ledger',
    'source',
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

  /// One claim, as `claim.latest`, `claims.items[]`, `prepare.claim` and
  /// `report.claim` all spell it (contract §5).
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

  /// `intent.unsignedTransaction` as loop-api `unsignedTransactionFor` builds
  /// it: all eleven keys, the three fee keys `null` when the fee type does not
  /// use them. It goes to the wallet verbatim, so an unreviewed key is
  /// refused rather than passed on.
  static const transactionKeys = <String>{
    'chainId',
    'to',
    'data',
    'value',
    'from',
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

  /// A `*Raw` amount: an integer in the token's smallest unit.
  static BigInt amountRaw(Map<String, Object?> map, String key) => BigInt.parse(
    LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: rawPattern,
      maxLength: 78,
    ),
  );

  static Decimal power(Map<String, Object?> map, String key) => Decimal.parse(
    LoopV2ChainCodec.requireString(
      map,
      key,
      pattern: powerPattern,
      maxLength: 120,
    ),
  );

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

  static String _memeAssetId(Map<String, Object?> map, String key) =>
      LoopV2ChainCodec.requireString(
        map,
        key,
        pattern: memeAssetIdPattern,
        maxLength: 80,
      );

  /// `decimals: 18` and `contractVersion: "2.0"`, both required.
  static void _envelope(Map<String, Object?> root) {
    LoopV2ChainCodec.requireContractVersion(root);
    if (root['decimals'] != miningLoopDecimals) invalid();
  }

  // -------------------------------------------------------------------------
  // GET /v2/mining/rewards
  // -------------------------------------------------------------------------

  static MiningRewardsView rewards(Object? raw) {
    final root = LoopV2Contract.strictMapWithOptional(raw, const <String>{
      'hourly',
      'contractVersion',
    }, legacyRootKeys);
    LoopV2ChainCodec.requireContractVersion(root);
    final map = LoopV2Contract.strictMap(root['hourly'], hourlyKeys);
    if (map['decimals'] != miningLoopDecimals) invalid();
    final rawState = map['displayState'];
    final displayState = rawState is String
        ? MiningDisplayState.tryParse(rawState)
        : null;
    if (displayState == null) invalid();
    final reasonCode = LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode');
    final serverTime = LoopV2ChainCodec.requireTimestamp(map, 'serverTime');

    final totalsRaw = map['totals'];
    BigInt settled = BigInt.zero;
    BigInt claimed = BigInt.zero;
    BigInt claimable = BigInt.zero;
    if (totalsRaw != null) {
      final totals = LoopV2Contract.strictMap(totalsRaw, const <String>{
        'settledRaw',
        'claimedRaw',
        'claimableRaw',
      });
      settled = amountRaw(totals, 'settledRaw');
      claimed = amountRaw(totals, 'claimedRaw');
      claimable = amountRaw(totals, 'claimableRaw');
    } else if (displayState != MiningDisplayState.unavailable) {
      // Totals are the ledger; only an unavailable store may withhold them
      // (contract §3.1).
      invalid();
    }

    MiningRewardEpoch? epoch;
    final lastHourRaw = map['lastHour'];
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
        nftReward: amountRaw(hour, 'nftRewardRaw'),
        assetReward: amountRaw(hour, 'assetRewardRaw'),
        totalReward: amountRaw(hour, 'totalRewardRaw'),
      );
      if (!epoch.epochEnd.isAfter(epoch.epochStart)) invalid();
    }

    MiningDisplayWindow? window;
    final displayRaw = map['display'];
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
      final total = amountRaw(display, 'totalRaw');
      final displayed = amountRaw(display, 'displayedRaw');
      if (displayed > total) invalid();
      window = MiningDisplayWindow(
        windowStart: LoopV2ChainCodec.optionalTimestamp(display, 'windowStart'),
        windowEnd: LoopV2ChainCodec.optionalTimestamp(display, 'windowEnd'),
        total: total,
        perMinute: amountRaw(display, 'perMinuteRaw'),
        completedMinutes: LoopV2ChainCodec.requireInt(
          display,
          'completedMinutes',
          maximum: 60,
        ),
        displayed: displayed,
        nextUpdateAt: LoopV2ChainCodec.optionalTimestamp(
          display,
          'nextUpdateAt',
        ),
      );
    }
    if (displayState == MiningDisplayState.displaying && epoch == null) {
      invalid();
    }

    MiningNftTrack? nft;
    MiningAssetTrack? asset;
    final tracksRaw = map['tracks'];
    if (tracksRaw != null) {
      final tracks = LoopV2Contract.strictMap(tracksRaw, const <String>{
        'nft',
        'asset',
      });
      nft = _nftTrack(tracks['nft']);
      asset = _assetTrack(tracks['asset']);
    }

    MiningInvites? invites;
    final referralRaw = map['referral'];
    if (referralRaw != null) {
      final referral = LoopV2Contract.strictMap(referralRaw, const <String>{
        'levels',
      });
      final entries = LoopV2ChainCodec.requireList(
        referral['levels'],
        maximum: 5,
      );
      // L1–L5, always five (contract §3).
      if (entries.length != 5) invalid();
      invites = _invites(<MiningInviteLevel>[
        for (final entry in entries) _level(entry),
      ]);
    }

    BigInt? minimumClaim;
    final parametersRaw = map['parameters'];
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
      minimumClaim = amountRaw(parameters, 'minimumClaimRaw');
    }

    // Decision 0185: `configurationReasonCode` (loop-api 0144 §8) is read
    // when present; an older backend omits it and the stage is inferred.
    final claimMap = LoopV2Contract.strictMapWithOptional(
      map['claim'],
      const <String>{'executable', 'reasonCode', 'latest'},
      const <String>{'configurationReasonCode'},
    );
    // Read leniently: a value that is not a reason code is treated as if the
    // key were absent, so one odd field never blanks the rewards page.
    final configurationRaw = claimMap['configurationReasonCode'];
    final configurationReported =
        claimMap.containsKey('configurationReasonCode') &&
        (configurationRaw == null ||
            (configurationRaw is String &&
                configurationRaw.length <= 64 &&
                LoopV2ChainCodec.reasonCodePattern.hasMatch(configurationRaw)));
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
      configurationReported: configurationReported,
      configurationReasonCode: configurationReported
          ? configurationRaw as String?
          : null,
    );

    return MiningRewardsView(
      settledTotal: settled,
      claimedTotal: claimed,
      claimable: claimable,
      lastEpoch: epoch,
      display: MiningMinuteDisplay(
        state: displayState,
        reasonCode: reasonCode,
        window: window,
      ),
      nft: nft,
      asset: asset,
      invites: invites,
      claim: claim,
      serverTime: serverTime,
      minimumClaim: minimumClaim,
    );
  }

  static MiningNftTrack _nftTrack(Object? raw) {
    final n = LoopV2Contract.strictMap(raw, const <String>{
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
      amountRaw(row, 'countAtEnd');
      power(row, 'power');
    }
    power(n, 'networkPower');
    amountRaw(n, 'budgetRaw');
    return MiningNftTrack(
      realCount: amountRaw(n, 'realNftCount'),
      ownPower: power(n, 'selfPower'),
      invitePower: power(n, 'referralPower'),
      totalPower: power(n, 'totalPower'),
      reward: amountRaw(n, 'rewardRaw'),
    );
  }

  static MiningAssetTrack _assetTrack(Object? raw) {
    final a = LoopV2Contract.strictMap(raw, const <String>{
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
      final assetId = _memeAssetId(row, 'assetId');
      if (!seen.add(assetId)) invalid();
      assets.add(
        MiningTrackAsset(
          assetId: assetId,
          power: power(row, 'power'),
          balanceAtEnd: amountRaw(row, 'balanceAtEndRaw'),
        ),
      );
    }
    final excluded = <MiningRewardsExcludedAsset>[];
    final seenExcluded = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(a['excludedAssets'])) {
      final row = LoopV2Contract.strictMap(entry, const <String>{
        'assetId',
        'reasonCode',
      });
      final assetId = _memeAssetId(row, 'assetId');
      if (!seenExcluded.add(assetId)) invalid();
      excluded.add(
        MiningRewardsExcludedAsset(
          assetId: assetId,
          reasonCode: LoopV2ChainCodec.requireReasonCode(row, 'reasonCode'),
        ),
      );
    }
    power(a, 'networkPower');
    amountRaw(a, 'budgetRaw');
    return MiningAssetTrack(
      assets: List<MiningTrackAsset>.unmodifiable(assets),
      excluded: List<MiningRewardsExcludedAsset>.unmodifiable(excluded),
      ownPower: power(a, 'selfPower'),
      invitePower: power(a, 'referralPower'),
      totalPower: power(a, 'totalPower'),
      reward: amountRaw(a, 'rewardRaw'),
    );
  }

  static MiningInviteLevel _level(Object? entry) {
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
    final bps = LoopV2ChainCodec.requireInt(row, 'ratioBps', maximum: 10000);
    return MiningInviteLevel(
      level: LoopV2ChainCodec.requireInt(row, 'level', minimum: 1, maximum: 5),
      ratePercent: (Decimal.fromInt(bps) / Decimal.fromInt(100)).toDecimal(),
      activeMembers: LoopV2ChainCodec.requireInt(row, 'effectiveMembers'),
      nftPower: power(row, 'nftPower'),
      assetPower: power(row, 'assetPower'),
    );
  }

  static MiningInvites _invites(List<MiningInviteLevel> levels) {
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
      total: MiningInviteTotal(
        activeMembers: members,
        nftPower: nftPower,
        assetPower: assetPower,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // claims
  // -------------------------------------------------------------------------

  /// One claim object (contract §5.2).
  static MiningClaimRecord claimRecord(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, claimKeys);
    final rawStatus = map['status'];
    final status = rawStatus is String
        ? MiningClaimStatus.tryParse(rawStatus)
        : null;
    if (status == null || status == MiningClaimStatus.none) invalid();
    final chainId = LoopV2ChainCodec.requireKnownChainId(map, 'chainId');
    final reference = map['chainReference'];
    if (reference != null && reference != loopChainReference(chainId)) {
      invalid();
    }
    _id(map, 'walletId');
    _address(map, 'contractAddress');
    amountRaw(map, 'cumulativeAmountRaw');
    amountRaw(map, 'nonce');
    LoopV2ChainCodec.requireTimestamp(map, 'deadline');
    LoopV2ChainCodec.requireTimestamp(map, 'updatedAt');
    if (map['blockNumber'] != null) amountRaw(map, 'blockNumber');
    return MiningClaimRecord(
      claimId: _id(map, 'claimId'),
      status: status,
      amount: amountRaw(map, 'amountRaw'),
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

  /// `GET /v2/mining/claims` (contract §5.4): newest first, 20 a page.
  static MiningClaimPage claims(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'items',
      'nextCursor',
      'decimals',
      'contractVersion',
    });
    _envelope(root);
    final items = <MiningClaimRecord>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      root['items'],
      maximum: 20,
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

  /// `claim/report` → the claim as the server now reads it (contract §5.3).
  static MiningClaimRecord reported(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'claim',
      'decimals',
      'contractVersion',
    });
    _envelope(root);
    return claimRecord(root['claim']);
  }

  // -------------------------------------------------------------------------
  // claim/prepare
  // -------------------------------------------------------------------------

  /// `claim/prepare` 201 (contract §5.2). `intent.payloadDigest` is required
  /// (loop-api decision 0123) and must equal `0x` + [localDigest] of the very
  /// `unsignedTransaction` handed to the wallet; any other value is an
  /// invalid payload and nothing is signed (decision 0143).
  static MiningClaimIntent prepared(Object? raw) {
    final root = LoopV2Contract.strictMap(raw, const <String>{
      'claim',
      'intent',
      'decimals',
      'contractVersion',
    });
    _envelope(root);
    final claimRaw = root['claim'];
    final claim = LoopV2Contract.strictMap(claimRaw, claimKeys);
    final record = claimRecord(claimRaw);
    final chainId = record.chainId!;
    final contractAddress = _address(claim, 'contractAddress');
    final intent = LoopV2Contract.strictMap(root['intent'], const <String>{
      'calldata',
      'unsignedTransaction',
      'payloadDigest',
      'signing',
    });
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
    final serverDigest = LoopV2ChainCodec.requireString(
      intent,
      'payloadDigest',
      pattern: payloadDigestPattern,
      maxLength: 66,
    );
    final ownDigest = '0x${localDigest(transaction.wire)}';
    // The server's digest and this device's must name the same object, or
    // the sheet could show one transaction while the wallet signs another.
    if (serverDigest != ownDigest) invalid();
    final signing = LoopV2Contract.strictMap(intent['signing'], const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    if (signing['mode'] != 'device_eth_send_transaction') invalid();
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
      cumulativeAmount: amountRaw(claim, 'cumulativeAmountRaw'),
      deadline: LoopV2ChainCodec.requireTimestamp(claim, 'deadline'),
      createdAt: record.createdAt,
      transaction: transaction,
      payloadDigest: serverDigest,
      localPayloadDigest: ownDigest,
      signingAllowed: LoopV2ChainCodec.requireBool(signing, 'allowed'),
      signingReasonCode: LoopV2ChainCodec.optionalReasonCode(
        signing,
        'reasonCode',
      ),
      payloadMatchesReview: matches,
    );
  }

  static MiningClaimTransaction _transaction(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, transactionKeys);
    final chainId = map['chainId'];
    if (chainId != 56 && chainId != 97) invalid();
    if (map['value'] != '0x0') invalid();
    final type = map['type'];
    if (type != 'eip1559' && type != 'legacy') invalid();
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
    // The fee keys follow the fee type: the other type's keys are null.
    final eip1559 = type == 'eip1559';
    if (map['gas'] == null || map['nonce'] == null) invalid();
    if (eip1559 &&
        (map['maxFeePerGas'] == null ||
            map['maxPriorityFeePerGas'] == null ||
            map['gasPrice'] != null)) {
      invalid();
    }
    if (!eip1559 &&
        (map['gasPrice'] == null ||
            map['maxFeePerGas'] != null ||
            map['maxPriorityFeePerGas'] != null)) {
      invalid();
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

  /// `intent.payloadDigest`: `0x` + 64 lowercase hex (keccak-256).
  static final RegExp payloadDigestPattern = RegExp(r'^0x[0-9a-f]{64}$');

  /// keccak-256 over the transaction's canonical JSON: keys sorted by code
  /// unit, no whitespace, `chainId` a JSON number, `null` kept (contract
  /// §5.2). Hex without the `0x`; the server's `payloadDigest` is `0x` + this.
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
  // claim/prepare refusals that are about gas (contract §5.5)
  // -------------------------------------------------------------------------

  static const insufficientBalanceCode = 'INSUFFICIENT_BALANCE';
  static const gasInsufficientCode = 'CLAIM_GAS_INSUFFICIENT';
  static const noGasSourceCode = 'CLAIM_NO_GAS_SOURCE';

  /// Reads a `409` body for the two gas refusals: `code:
  /// INSUFFICIENT_BALANCE` with `detailsSafe.reasonCode` naming one of them,
  /// the swap suggestion in the flat `detailsSafe.suggestedSwap…` slots.
  /// Returns `null` for anything else (`MINING_CLAIM_NOTHING_TO_CLAIM`,
  /// `MINING_CLAIM_BELOW_MINIMUM`, …), which then goes through the ordinary
  /// envelope check.
  static ({String reason, MiningSuggestedSwap? swap, String? requiredNative})?
  gasRefusal(Object? body) {
    if (body is! Map || body['code'] != insufficientBalanceCode) return null;
    final details = body['detailsSafe'];
    if (details is! Map) return null;
    final reason = details['reasonCode'];
    if (reason != gasInsufficientCode && reason != noGasSourceCode) {
      return null;
    }
    String? text(Object? value, RegExp pattern, int max) =>
        value is String && value.length <= max && pattern.hasMatch(value)
        ? value
        : null;
    final asset = LoopV2ChainCodec.assetIdPattern;
    MiningSuggestedSwap? swap;
    if (reason == gasInsufficientCode) {
      swap = MiningSuggestedSwap(
        fromAssetId: text(details['suggestedSwapFromAssetId'], asset, 80),
        toAssetId: text(details['suggestedSwapToAssetId'], asset, 80),
        fromSymbol: text(details['suggestedSwapFromSymbol'], symbolPattern, 24),
        toSymbol: text(details['suggestedSwapToSymbol'], symbolPattern, 24),
        amount: text(details['suggestedSwapToAmount'], powerPattern, 80),
      );
    }
    return (
      reason: reason! as String,
      swap: swap,
      requiredNative: text(details['requiredNativeAmount'], powerPattern, 80),
    );
  }
}
