import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';

/// Strict decoders for the Launch slots loop-api decision 0076 turned into
/// unions (client decision 0088).
///
/// Every decoder first picks the branch by the discriminator the pre-S83a
/// object already carried, then decodes that branch strictly: unknown keys
/// are refused on both sides. The `unavailable` branch keeps exactly the keys
/// and strictness it had in step 7; the only widening is `reasonCode`, which
/// the main-agent ruling on 0076 made "any reason-code string".
abstract final class LoopV2LaunchChainCodec {
  static final RegExp bytes32Pattern = RegExp(r'^0x[0-9a-f]{64}$');
  static final RegExp addressPattern = RegExp(r'^0x[0-9a-f]{40}$');
  static final RegExp calldataPattern = RegExp(r'^0x([0-9a-f]{2})*$');
  static final RegExp payloadDigestPattern = RegExp(r'^[0-9a-f]{64}$');

  static Never invalid() => LoopV2S7Codec.invalid();

  static String _amount(Map<String, Object?> map, String key) =>
      LoopV2S7Codec.requirePattern(
        map,
        key,
        LoopV2S7Codec.integerAmountPattern,
        maxLength: 78,
      );

  static String _block(Map<String, Object?> map, String key) =>
      LoopV2S7Codec.requirePattern(
        map,
        key,
        LoopV2S7Codec.blockNumberPattern,
        maxLength: 20,
      );

  static String? _optionalBlock(Map<String, Object?> map, String key) =>
      map[key] == null ? null : _block(map, key);

  static String _bytes32(Map<String, Object?> map, String key) =>
      LoopV2S7Codec.requirePattern(map, key, bytes32Pattern, maxLength: 66);

  static String _address(Map<String, Object?> map, String key) =>
      LoopV2S7Codec.requirePattern(map, key, addressPattern, maxLength: 42);

  static int _bounded(Map<String, Object?> map, String key, int maximum) {
    final value = map[key];
    if (value is! int || value < 0 || value > maximum) invalid();
    return value;
  }

  static int _roundIndex(Map<String, Object?> map) =>
      _bounded(map, 'roundIndex', 65535);

  static List<String> _proof(Object? raw) {
    final items = <String>[];
    for (final entry in LoopV2S7Codec.requireList(raw, maximum: 64)) {
      if (entry is! String || !bytes32Pattern.hasMatch(entry)) invalid();
      items.add(entry);
    }
    return List<String>.unmodifiable(items);
  }

  static T _enum<T>(
    Map<String, Object?> map,
    String key,
    T? Function(String) parse,
  ) {
    final value = map[key];
    if (value is! String) invalid();
    final parsed = parse(value);
    if (parsed == null) invalid();
    return parsed;
  }

  // -------------------------------------------------------------------------
  // launch.onChainState / launch.contractAddress
  // -------------------------------------------------------------------------

  static const _unavailableAxisKeys = <String>{
    'saleState',
    'entitlementState',
    'liquidityState',
    'operationalState',
    'stateTupleDigest',
    'snapshotBlockNumber',
    'snapshotBlockHash',
    'source',
    'reasonCode',
  };

  static LaunchOnChainState onChainState(Object? raw) {
    if (raw is! Map) invalid();
    if (raw['source'] == 'chain') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        ..._unavailableAxisKeys,
        'configVersion',
      });
      LoopV2S7Codec.requireNull(map, 'reasonCode');
      return LaunchOnChainAvailable(
        saleState: _enum(map, 'saleState', LaunchSaleState.tryParse),
        entitlementState: _enum(
          map,
          'entitlementState',
          LaunchEntitlementState.tryParse,
        ),
        liquidityState: _enum(
          map,
          'liquidityState',
          LaunchLiquidityState.tryParse,
        ),
        operationalState: _enum(
          map,
          'operationalState',
          LaunchOperationalState.tryParse,
        ),
        stateTupleDigest: _bytes32(map, 'stateTupleDigest'),
        snapshotBlockNumber: _block(map, 'snapshotBlockNumber'),
        snapshotBlockHash: _bytes32(map, 'snapshotBlockHash'),
        configVersion: _bytes32(map, 'configVersion'),
      );
    }
    // The pre-S83a object, key for key.
    final map = LoopV2Contract.strictMap(raw, _unavailableAxisKeys);
    const axisValues = <String>{'unavailable'};
    LoopV2S7Codec.requireEnum(map, 'saleState', axisValues);
    LoopV2S7Codec.requireEnum(map, 'entitlementState', axisValues);
    LoopV2S7Codec.requireEnum(map, 'liquidityState', axisValues);
    LoopV2S7Codec.requireEnum(map, 'operationalState', axisValues);
    LoopV2S7Codec.requireNull(map, 'stateTupleDigest');
    LoopV2S7Codec.requireNull(map, 'snapshotBlockNumber');
    LoopV2S7Codec.requireNull(map, 'snapshotBlockHash');
    LoopV2S7Codec.requireEnum(map, 'source', axisValues);
    return LaunchOnChainUnavailable(
      LoopV2S7Codec.requireReasonCode(map, 'reasonCode'),
    );
  }

  static String? contractAddress(Map<String, Object?> map) =>
      map['contractAddress'] == null ? null : _address(map, 'contractAddress');

  // -------------------------------------------------------------------------
  // detail config / rounds (the `available` branches)
  // -------------------------------------------------------------------------

  static bool isAvailable(Object? raw) =>
      raw is Map && raw['status'] == 'available';

  static LaunchSaleConfig saleConfig(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'projectToken',
      'usd1',
      'softCapUsd1',
      'hardCapUsd1',
      'walletProjectCapUsd1',
      'minPurchaseUsd1',
      'protocolFeeBps',
      'liquidityBps',
      'tgeBps',
      'cliffSeconds',
      'vestingSeconds',
      'poolFeeTier',
      'lpLockSeconds',
      'configVersion',
    });
    if (map['status'] != 'available') invalid();
    return LaunchSaleConfig(
      projectToken: _address(map, 'projectToken'),
      usd1: _address(map, 'usd1'),
      softCapUsd1: _amount(map, 'softCapUsd1'),
      hardCapUsd1: _amount(map, 'hardCapUsd1'),
      walletProjectCapUsd1: _amount(map, 'walletProjectCapUsd1'),
      minPurchaseUsd1: _amount(map, 'minPurchaseUsd1'),
      protocolFeeBps: _bounded(map, 'protocolFeeBps', 65535),
      liquidityBps: _bounded(map, 'liquidityBps', 65535),
      tgeBps: _bounded(map, 'tgeBps', 65535),
      cliffSeconds: _bounded(map, 'cliffSeconds', 4294967295),
      vestingSeconds: _bounded(map, 'vestingSeconds', 4294967295),
      poolFeeTier: _bounded(map, 'poolFeeTier', 16777215),
      lpLockSeconds: _bounded(map, 'lpLockSeconds', 4294967295),
      configVersion: _bytes32(map, 'configVersion'),
    );
  }

  static LaunchChainRound chainRound(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'roundId',
      'roundIndex',
      'startAt',
      'endAt',
      'priceUsd1PerToken',
      'roundCapUsd1',
      'walletRoundCapUsd1',
      'allowlistRoot',
      'raisedUsd1',
    });
    if (map['status'] != 'available') invalid();
    final startAt = LoopV2S7Codec.requireTimestamp(map, 'startAt');
    final endAt = LoopV2S7Codec.requireTimestamp(map, 'endAt');
    if (endAt.isBefore(startAt)) invalid();
    return LaunchChainRound(
      roundId: LoopV2S7Codec.optionalId(map, 'roundId'),
      roundIndex: _roundIndex(map),
      startAt: startAt,
      endAt: endAt,
      priceUsd1PerToken: _amount(map, 'priceUsd1PerToken'),
      roundCapUsd1: _amount(map, 'roundCapUsd1'),
      walletRoundCapUsd1: _amount(map, 'walletRoundCapUsd1'),
      allowlistRoot: _bytes32(map, 'allowlistRoot'),
      raisedUsd1: _amount(map, 'raisedUsd1'),
    );
  }

  // -------------------------------------------------------------------------
  // eligibility
  // -------------------------------------------------------------------------

  static LaunchEligibilityResult eligibilityResult(Object? raw) {
    if (raw is! Map) invalid();
    if (!raw.containsKey('status')) {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'tier',
        'reasonCode',
        'snapshotBlock',
      });
      LoopV2S7Codec.requireNull(map, 'tier');
      LoopV2S7Codec.requireNull(map, 'snapshotBlock');
      return LaunchEligibilityPending(
        LoopV2S7Codec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'tier',
      'reasonCode',
      'snapshotBlock',
      'roundIndex',
      'allowlistRoot',
      'eligibilityProof',
    });
    if (map['status'] != 'available') invalid();
    final tier = map['tier'] == null
        ? null
        : LoopV2S7Codec.requireEnum(map, 'tier', const <String>{
            'priority',
            'community',
            'public',
          });
    return LaunchEligibilityEvaluated(
      tierWireName: tier,
      reasonCode: map['reasonCode'] == null
          ? null
          : LoopV2S7Codec.requireReasonCode(map, 'reasonCode'),
      snapshotBlock: _block(map, 'snapshotBlock'),
      roundIndex: _roundIndex(map),
      allowlistRoot: _bytes32(map, 'allowlistRoot'),
      eligibilityProof: _proof(map['eligibilityProof']),
    );
  }

  // -------------------------------------------------------------------------
  // holders
  // -------------------------------------------------------------------------

  static LaunchReading<T> reading<T>(
    Object? raw,
    T Function(Map<String, Object?>) available,
    Set<String> availableKeys,
  ) {
    if (raw is Map && raw['status'] == 'available') {
      return LaunchReadingAvailable<T>(
        available(
          LoopV2Contract.strictMap(raw, <String>{'status', ...availableKeys}),
        ),
      );
    }
    return LaunchReadingUnavailable<T>(LoopV2S7Codec.unavailable(raw));
  }

  static LaunchReading<LaunchHolderCount> holderCount(Object? raw) =>
      reading<LaunchHolderCount>(
        raw,
        (map) => LaunchHolderCount(
          holderCount: LoopV2S7Codec.requireCount(map, 'holderCount'),
          indexedBlockNumber: _block(map, 'indexedBlockNumber'),
        ),
        const <String>{'holderCount', 'indexedBlockNumber'},
      );

  static LaunchReading<LaunchPosition> position(Object? raw) =>
      reading<LaunchPosition>(
        raw,
        (map) => LaunchPosition(
          walletId: LoopV2S7Codec.requireId(map, 'walletId'),
          cumulativeUsd1: _amount(map, 'cumulativeUsd1'),
          purchasedTokens: _amount(map, 'purchasedTokens'),
          entitledTokens: _amount(map, 'entitledTokens'),
          claimableTokens: _amount(map, 'claimableTokens'),
          claimedTokens: _amount(map, 'claimedTokens'),
          refundableUsd1: _amount(map, 'refundableUsd1'),
          refundedUsd1: _amount(map, 'refundedUsd1'),
          snapshotBlockNumber: _block(map, 'snapshotBlockNumber'),
          snapshotBlockHash: _bytes32(map, 'snapshotBlockHash'),
        ),
        const <String>{
          'walletId',
          'cumulativeUsd1',
          'purchasedTokens',
          'entitledTokens',
          'claimableTokens',
          'claimedTokens',
          'refundableUsd1',
          'refundedUsd1',
          'snapshotBlockNumber',
          'snapshotBlockHash',
        },
      );

  static LaunchReading<LaunchWalletCap> walletCap(Object? raw) =>
      reading<LaunchWalletCap>(
        raw,
        (map) {
          final rounds = <LaunchWalletRoundCap>[];
          final seen = <int>{};
          for (final entry in LoopV2S7Codec.requireList(
            map['rounds'],
            maximum: 64,
          )) {
            final round = LoopV2Contract.strictMap(entry, const <String>{
              'roundIndex',
              'walletRoundCapUsd1',
              'cumulativeUsd1',
            });
            final index = _roundIndex(round);
            if (!seen.add(index)) invalid();
            rounds.add(
              LaunchWalletRoundCap(
                roundIndex: index,
                walletRoundCapUsd1: _amount(round, 'walletRoundCapUsd1'),
                cumulativeUsd1: _amount(round, 'cumulativeUsd1'),
              ),
            );
          }
          rounds.sort((a, b) => a.roundIndex.compareTo(b.roundIndex));
          return LaunchWalletCap(
            walletProjectCapUsd1: _amount(map, 'walletProjectCapUsd1'),
            rounds: List<LaunchWalletRoundCap>.unmodifiable(rounds),
            snapshotBlockNumber: _block(map, 'snapshotBlockNumber'),
            snapshotBlockHash: _bytes32(map, 'snapshotBlockHash'),
          );
        },
        const <String>{
          'walletProjectCapUsd1',
          'rounds',
          'snapshotBlockNumber',
          'snapshotBlockHash',
        },
      );

  // -------------------------------------------------------------------------
  // history
  // -------------------------------------------------------------------------

  static LaunchHistory history(Map<String, Object?> root, String launchId) {
    final source = reading<LaunchIndexedSource>(
      root['source'],
      (map) => LaunchIndexedSource(
        indexedBlockNumber: _block(map, 'indexedBlockNumber'),
        indexedBlockHash: _bytes32(map, 'indexedBlockHash'),
      ),
      const <String>{'indexedBlockNumber', 'indexedBlockHash'},
    );
    if (source is LaunchReadingUnavailable<LaunchIndexedSource>) {
      // Unchanged from step 7: an unavailable source has nothing to list, so
      // a row would be a fact nobody indexed.
      LoopV2S7Codec.requireEmptyList(root['purchaseRecords']);
      LoopV2S7Codec.requireEmptyList(root['entitlements']);
      LoopV2S7Codec.requireEmptyList(root['refunds']);
      return LaunchHistory(launchId: launchId, source: source);
    }
    final seen = <String>{};
    final purchases = <LaunchPurchaseRecord>[];
    for (final entry in LoopV2S7Codec.requireList(
      root['purchaseRecords'],
      maximum: 500,
    )) {
      final map = LoopV2Contract.strictMap(entry, const <String>{
        'purchaseRecordId',
        'walletId',
        'roundId',
        'roundIndex',
        'usd1Amount',
        'tokenAmount',
        'transactionHash',
        'logIndex',
        'blockNumber',
        'blockHash',
        'confirmationState',
        'observedAt',
      });
      final id = LoopV2S7Codec.requireId(map, 'purchaseRecordId');
      if (!seen.add(id)) invalid();
      purchases.add(
        LaunchPurchaseRecord(
          purchaseRecordId: id,
          walletId: LoopV2S7Codec.requireId(map, 'walletId'),
          roundId: LoopV2S7Codec.optionalId(map, 'roundId'),
          roundIndex: _roundIndex(map),
          usd1Amount: _amount(map, 'usd1Amount'),
          tokenAmount: _amount(map, 'tokenAmount'),
          transactionHash: _bytes32(map, 'transactionHash'),
          logIndex: LoopV2S7Codec.requireCount(map, 'logIndex'),
          blockNumber: _block(map, 'blockNumber'),
          blockHash: _bytes32(map, 'blockHash'),
          confirmationState: _enum(
            map,
            'confirmationState',
            LaunchConfirmationState.tryParse,
          ),
          observedAt: LoopV2S7Codec.requireTimestamp(map, 'observedAt'),
        ),
      );
    }
    final entitlements = <LaunchEntitlementRecord>[];
    for (final entry in LoopV2S7Codec.requireList(
      root['entitlements'],
      maximum: 500,
    )) {
      final map = LoopV2Contract.strictMap(entry, const <String>{
        'entitlementId',
        'walletId',
        'entitledTokens',
        'claimedTokens',
        'state',
        'frozenAtBlock',
      });
      final id = LoopV2S7Codec.requireId(map, 'entitlementId');
      if (!seen.add(id)) invalid();
      entitlements.add(
        LaunchEntitlementRecord(
          entitlementId: id,
          walletId: LoopV2S7Codec.requireId(map, 'walletId'),
          entitledTokens: _amount(map, 'entitledTokens'),
          claimedTokens: _amount(map, 'claimedTokens'),
          state: _enum(map, 'state', LaunchEntitlementRecordState.tryParse),
          frozenAtBlock: _optionalBlock(map, 'frozenAtBlock'),
        ),
      );
    }
    final refunds = <LaunchRefundRecord>[];
    for (final entry in LoopV2S7Codec.requireList(
      root['refunds'],
      maximum: 500,
    )) {
      final map = LoopV2Contract.strictMap(entry, const <String>{
        'refundLiabilityId',
        'walletId',
        'refundableUsd1',
        'refundedUsd1',
        'state',
        'frozenAtBlock',
      });
      final id = LoopV2S7Codec.requireId(map, 'refundLiabilityId');
      if (!seen.add(id)) invalid();
      refunds.add(
        LaunchRefundRecord(
          refundLiabilityId: id,
          walletId: LoopV2S7Codec.requireId(map, 'walletId'),
          refundableUsd1: _amount(map, 'refundableUsd1'),
          refundedUsd1: _amount(map, 'refundedUsd1'),
          state: _enum(map, 'state', LaunchRefundRecordState.tryParse),
          frozenAtBlock: _optionalBlock(map, 'frozenAtBlock'),
        ),
      );
    }
    return LaunchHistory(
      launchId: launchId,
      source: source,
      purchaseRecords: List<LaunchPurchaseRecord>.unmodifiable(purchases),
      entitlements: List<LaunchEntitlementRecord>.unmodifiable(entitlements),
      refunds: List<LaunchRefundRecord>.unmodifiable(refunds),
    );
  }

  // -------------------------------------------------------------------------
  // purchase intent (201)
  // -------------------------------------------------------------------------

  static const _intentRequiredKeys = <String>{
    'launchIntentId',
    'state',
    'launchId',
    'projectId',
    'walletId',
    'roundId',
    'roundIndex',
    'chainId',
    'contractAddress',
    'quoteAssetId',
    'usd1Amount',
    'expectedTokenAmount',
    'minTokenAmount',
    'walletCumulativeUsd1',
    'deadline',
    'eligibilityProof',
    'configVersion',
    'stateTupleDigest',
    'snapshotBlockNumber',
    'snapshotBlockHash',
    'payloadDigest',
    'unsignedTransaction',
    'expiresAt',
    'createdAt',
  };

  /// The S83b optional keys (loop-api decision 0077). Each is decoded to the
  /// OpenAPI schema when present; any other key is still refused.
  static const _intentOptionalKeys = <String>{
    'projectAssetId',
    'saleId',
    'walletRoundCapUsd1',
    'walletProjectCapUsd1',
    'transactionHash',
    'simulation',
    'policy',
    'signing',
    // loop-api decision 0080: only on `reverted`, a string or `null` (null
    // today: public RPC exposes no trace). Decoded wherever it appears so a
    // later widening of the state rule is not a whole-document failure.
    'revertReason',
  };

  static final RegExp _quantityPattern = RegExp(
    r'^0x(0|[1-9a-f][0-9a-f]{0,63})$',
  );
  static final RegExp _usdPattern = RegExp(
    r'^(0|[1-9][0-9]{0,77})(\.[0-9]{1,60})?$',
  );

  static String? _optionalReason(Map<String, Object?> map) =>
      map['reasonCode'] == null
      ? null
      : LoopV2S7Codec.requireReasonCode(map, 'reasonCode');

  static String? _optionalAmount(Map<String, Object?> map, String key) {
    if (!map.containsKey(key)) return null;
    return _amount(map, key);
  }

  static String _quantity(Map<String, Object?> map, String key) =>
      LoopV2S7Codec.requirePattern(map, key, _quantityPattern, maxLength: 66);

  /// The optional keys of `unsignedTransaction`, kept exactly as they
  /// arrived. A present key is validated; an absent one stays absent.
  static Map<String, Object?> _optionalTransaction(Map<String, Object?> map) {
    final optional = <String, Object?>{};
    if (map.containsKey('from')) optional['from'] = _address(map, 'from');
    if (map.containsKey('gas')) optional['gas'] = _quantity(map, 'gas');
    if (map.containsKey('nonce')) optional['nonce'] = _quantity(map, 'nonce');
    if (map.containsKey('type')) {
      final type = map['type'];
      if (type != 'eip1559' && type != 'legacy') invalid();
      optional['type'] = type;
    }
    for (final key in const <String>[
      'maxFeePerGas',
      'maxPriorityFeePerGas',
      'gasPrice',
    ]) {
      if (!map.containsKey(key)) continue;
      optional[key] = map[key] == null ? null : _quantity(map, key);
    }
    return optional;
  }

  static LaunchIntentSimulation? _simulation(Map<String, Object?> root) {
    if (!root.containsKey('simulation')) return null;
    final map = LoopV2Contract.strictMap(root['simulation'], const <String>{
      'status',
      'reasonCode',
    });
    return LaunchIntentSimulation(
      status: _enum(map, 'status', LaunchSimulationStatus.tryParse),
      reasonCode: _optionalReason(map),
    );
  }

  static LaunchIntentPolicy? _policy(Map<String, Object?> root) {
    if (!root.containsKey('policy')) return null;
    final map = LoopV2Contract.strictMap(root['policy'], const <String>{
      'configVersion',
      'canaryMaxUsd',
      'valueUsd',
      'priceSource',
    });
    return LaunchIntentPolicy(
      configVersion: LoopV2S7Codec.requireEnum(
        map,
        'configVersion',
        const <String>{'bscWriteCanaryV1'},
      ),
      canaryMaxUsd: LoopV2S7Codec.requirePattern(
        map,
        'canaryMaxUsd',
        _usdPattern,
        maxLength: 140,
      ),
      valueUsd: LoopV2S7Codec.requirePattern(
        map,
        'valueUsd',
        _usdPattern,
        maxLength: 140,
      ),
      priceSource: LoopV2S7Codec.requireEnum(map, 'priceSource', const <String>{
        'usd1_par',
      }),
    );
  }

  static LaunchIntentSigning? _signing(Map<String, Object?> root) {
    if (!root.containsKey('signing')) return null;
    final map = LoopV2Contract.strictMap(root['signing'], const <String>{
      'mode',
      'allowed',
      'reasonCode',
    });
    final allowed = map['allowed'];
    if (allowed is! bool) invalid();
    return LaunchIntentSigning(
      mode: LoopV2S7Codec.requireEnum(map, 'mode', const <String>{
        'device_eth_send_transaction',
      }),
      allowed: allowed,
      reasonCode: _optionalReason(map),
    );
  }

  static LaunchPurchaseIntent purchaseIntent(Object? raw) {
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      _intentRequiredKeys,
      _intentOptionalKeys,
    );
    final chainId = LoopV2S7Codec.requireEnum(
      map,
      'chainId',
      loopKnownChainIds,
    );
    final quoteAssetId = map['quoteAssetId'];
    if (quoteAssetId is! String ||
        quoteAssetId.isEmpty ||
        quoteAssetId.length > 128) {
      invalid();
    }
    String? projectAssetId;
    if (map.containsKey('projectAssetId')) {
      final value = map['projectAssetId'];
      if (value is! String || value.isEmpty || value.length > 128) invalid();
      projectAssetId = value;
    }
    final transaction = LoopV2Contract.strictMapWithOptional(
      map['unsignedTransaction'],
      const <String>{'chainId', 'to', 'data', 'value'},
      LaunchUnsignedTransaction.optionalKeys.toSet(),
    );
    final txChain = transaction['chainId'];
    if (txChain is! int || txChain != loopChainReference(chainId)) invalid();
    final contract = _address(map, 'contractAddress');
    final to = _address(transaction, 'to');
    if (to != contract) invalid();
    final data = LoopV2S7Codec.requirePattern(
      transaction,
      'data',
      calldataPattern,
      maxLength: 65536,
    );
    if (transaction['value'] != '0x0') invalid();
    final hash = map['transactionHash'];
    if (hash != null && (hash is! String || !bytes32Pattern.hasMatch(hash))) {
      invalid();
    }
    return LaunchPurchaseIntent(
      launchIntentId: LoopV2S7Codec.requireId(map, 'launchIntentId'),
      state: _enum(map, 'state', LaunchIntentState.tryParse),
      launchId: LoopV2S7Codec.requireId(map, 'launchId'),
      projectId: LoopV2S7Codec.requireId(map, 'projectId'),
      walletId: LoopV2S7Codec.requireId(map, 'walletId'),
      roundId: LoopV2S7Codec.requireId(map, 'roundId'),
      roundIndex: _roundIndex(map),
      chainId: chainId,
      contractAddress: contract,
      quoteAssetId: quoteAssetId,
      usd1Amount: _amount(map, 'usd1Amount'),
      expectedTokenAmount: _amount(map, 'expectedTokenAmount'),
      minTokenAmount: _amount(map, 'minTokenAmount'),
      walletCumulativeUsd1: _amount(map, 'walletCumulativeUsd1'),
      deadline: LoopV2S7Codec.requireTimestamp(map, 'deadline'),
      eligibilityProof: _proof(map['eligibilityProof']),
      configVersion: _bytes32(map, 'configVersion'),
      stateTupleDigest: _bytes32(map, 'stateTupleDigest'),
      snapshotBlockNumber: _block(map, 'snapshotBlockNumber'),
      snapshotBlockHash: _bytes32(map, 'snapshotBlockHash'),
      payloadDigest: LoopV2S7Codec.requirePattern(
        map,
        'payloadDigest',
        payloadDigestPattern,
        maxLength: 64,
      ),
      unsignedTransaction: LaunchUnsignedTransaction(
        chainId: txChain,
        to: to,
        data: data,
        value: '0x0',
        optional: _optionalTransaction(transaction),
      ),
      expiresAt: LoopV2S7Codec.requireTimestamp(map, 'expiresAt'),
      createdAt: LoopV2S7Codec.requireTimestamp(map, 'createdAt'),
      projectAssetId: projectAssetId,
      saleId: _optionalAmount(map, 'saleId'),
      walletRoundCapUsd1: _optionalAmount(map, 'walletRoundCapUsd1'),
      walletProjectCapUsd1: _optionalAmount(map, 'walletProjectCapUsd1'),
      transactionHash: hash as String?,
      simulation: _simulation(map),
      policy: _policy(map),
      signing: _signing(map),
      revertReason: LoopV2S7Codec.optionalText(
        map,
        'revertReason',
        maxLength: 256,
      ),
    );
  }
}
