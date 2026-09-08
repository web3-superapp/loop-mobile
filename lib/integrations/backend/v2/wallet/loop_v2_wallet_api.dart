import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the `wallet` read module (loop-api decision 0033).
///
/// `PUT /v2/wallets/active` is a version CAS and deliberately carries no
/// `Idempotency-Key`: the server answers `400 INVALID_REQUEST` when one is
/// present.
abstract interface class LoopV2WalletApi {
  Future<LoopWalletDirectory> getWallets({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopWalletDirectory> putActiveWallet({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String? expectedActiveWalletId,
    LoopV2WriteOrigin? origin,
  });

  Future<LoopWalletBalances> getBalances({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  });

  Future<LoopWalletActivityPage> getActivity({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    String? cursor,
  });

  Future<LoopWalletReceive> getReceive({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  });
}

final class DioLoopV2WalletApi implements LoopV2WalletApi {
  DioLoopV2WalletApi(this._dio);

  static const walletsPath = '/v2/wallets';
  static const activeWalletPath = '/v2/wallets/active';

  static const _directoryKeys = <String>{
    'wallets',
    'activeWalletId',
    'source',
    'contractVersion',
  };

  final Dio _dio;

  static String _requireWalletId(String value) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  /// `cursor` and `limit` are mutually exclusive: the page size is already
  /// encoded in the cursor, so no limit is ever sent alongside it.
  static Map<String, Object?>? _cursorQuery(String? cursor) {
    if (cursor == null) return null;
    if (cursor.length < 3 ||
        cursor.length > LoopV2ChainCodec.maximumCursorLength ||
        !LoopV2ChainCodec.cursorPattern.hasMatch(cursor)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return <String, Object?>{'cursor': cursor};
  }

  @override
  Future<LoopWalletDirectory> getWallets({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        walletsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _directory(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopWalletDirectory> putActiveWallet({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    required String? expectedActiveWalletId,
    LoopV2WriteOrigin? origin,
  }) async {
    final target = _requireWalletId(walletId);
    final expected = expectedActiveWalletId == null
        ? null
        : _requireWalletId(expectedActiveWalletId);
    try {
      final response = await _dio.put<Object?>(
        activeWalletPath,
        data: <String, Object?>{
          'walletId': target,
          'expectedActiveWalletId': expected,
        },
        options: LoopV2ModuleRequest.casOptions(
          accessToken,
          clientVersion,
          hasBody: true,
          origin: origin,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      return _directory(response.data);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.casWriteErrors,
      );
    }
  }

  @override
  Future<LoopWalletBalances> getBalances({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  }) async {
    final target = _requireWalletId(walletId);
    try {
      final response = await _dio.get<Object?>(
        '$walletsPath/$target/balances',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'walletId',
        'snapshot',
        'gasReservePolicy',
        'balances',
        'netWorth',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['walletId'] != target) LoopV2ChainCodec.invalid();

      final snapshot = LoopV2Contract.strictMap(
        root['snapshot'],
        const <String>{
          'blockNumber',
          'blockHash',
          'observedAt',
          'confirmations',
        },
      );
      final policy = LoopV2Contract.strictMap(
        root['gasReservePolicy'],
        const <String>{'configVersion', 'nativeReserveRaw', 'nativeReserve'},
      );
      if (policy['configVersion'] != 'walletGasReserveV1') {
        LoopV2ChainCodec.invalid();
      }

      final rows = <LoopAssetBalanceRow>[];
      final seen = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['balances'],
        maximum: 200,
      )) {
        final row = _balanceRow(raw);
        if (!seen.add(row.assetId)) LoopV2ChainCodec.invalid();
        rows.add(row);
      }

      return LoopWalletBalances(
        walletId: target,
        snapshot: LoopBalanceSnapshot(
          blockNumber: LoopV2ChainCodec.requireBlockNumber(
            snapshot,
            'blockNumber',
          ),
          blockHash: LoopV2ChainCodec.requireString(
            snapshot,
            'blockHash',
            pattern: LoopV2ChainCodec.hashPattern,
            maxLength: 66,
          ),
          observedAt: LoopV2ChainCodec.requireTimestamp(snapshot, 'observedAt'),
          confirmations: LoopV2ChainCodec.requireInt(
            snapshot,
            'confirmations',
            minimum: 1,
          ),
        ),
        gasReservePolicy: LoopGasReservePolicy(
          configVersion: 'walletGasReserveV1',
          nativeReserveRaw: LoopV2ChainCodec.requireRawAmount(
            policy,
            'nativeReserveRaw',
          ),
          nativeReserve: LoopV2ChainCodec.requireDecimal(
            policy,
            'nativeReserve',
          ),
        ),
        balances: rows,
        netWorth: _netWorth(root['netWorth']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopWalletActivityPage> getActivity({
    required String accessToken,
    required String clientVersion,
    required String walletId,
    String? cursor,
  }) async {
    final target = _requireWalletId(walletId);
    try {
      final response = await _dio.get<Object?>(
        '$walletsPath/$target/activity',
        queryParameters: _cursorQuery(cursor),
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'walletId',
        'items',
        'nextCursor',
        'freshness',
        'nativeTransfers',
        'crossChain',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['walletId'] != target) LoopV2ChainCodec.invalid();

      final items = <LoopWalletActivityEntry>[];
      final seen = <String>{};
      for (final raw in LoopV2ChainCodec.requireList(
        root['items'],
        maximum: 50,
      )) {
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'assetId',
          'symbol',
          'decimals',
          'direction',
          'counterpartyAddress',
          'rawValue',
          'displayValue',
          'transactionHash',
          'logIndex',
          'blockNumber',
          'blockHash',
          'confirmations',
          'status',
          'observedAt',
        });
        final rawDirection = map['direction'];
        if (rawDirection is! String) LoopV2ChainCodec.invalid();
        final direction = LoopTransferDirection.tryParse(rawDirection);
        if (direction == null) LoopV2ChainCodec.invalid();
        final entry = LoopWalletActivityEntry(
          assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
          symbol: LoopV2ChainCodec.requireText(map, 'symbol', maxLength: 32),
          decimals: LoopV2ChainCodec.requireInt(map, 'decimals', maximum: 36),
          direction: direction,
          counterpartyAddress: LoopV2ChainCodec.requireString(
            map,
            'counterpartyAddress',
            pattern: LoopV2ChainCodec.addressPattern,
            maxLength: 42,
          ),
          rawValue: LoopV2ChainCodec.requireRawAmount(map, 'rawValue'),
          displayValue: LoopV2ChainCodec.requireDecimal(map, 'displayValue'),
          transactionHash: LoopV2ChainCodec.requireString(
            map,
            'transactionHash',
            pattern: LoopV2ChainCodec.hashPattern,
            maxLength: 66,
          ),
          logIndex: LoopV2ChainCodec.requireInt(map, 'logIndex'),
          blockNumber: LoopV2ChainCodec.requireBlockNumber(map, 'blockNumber'),
          blockHash: LoopV2ChainCodec.requireString(
            map,
            'blockHash',
            pattern: LoopV2ChainCodec.hashPattern,
            maxLength: 66,
          ),
          confirmations: LoopV2ChainCodec.optionalInt(
            map,
            'confirmations',
            minimum: 0,
          ),
          status: LoopV2ChainCodec.requireConfirmationStatus(map, 'status'),
          observedAt: LoopV2ChainCodec.requireTimestamp(map, 'observedAt'),
        );
        if (!seen.add(entry.entryId)) LoopV2ChainCodec.invalid();
        items.add(entry);
      }

      return LoopWalletActivityPage(
        walletId: target,
        items: items,
        nextCursor: LoopV2ChainCodec.cursor(root, 'nextCursor'),
        freshness: LoopV2ChainCodec.freshness(root['freshness']),
        nativeTransfers: LoopV2ChainCodec.unavailable(root['nativeTransfers']),
        crossChain: LoopV2ChainCodec.unavailable(root['crossChain']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopWalletReceive> getReceive({
    required String accessToken,
    required String clientVersion,
    required String walletId,
  }) async {
    final target = _requireWalletId(walletId);
    try {
      final response = await _dio.get<Object?>(
        '$walletsPath/$target/receive',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'walletId',
        'networks',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['walletId'] != target) LoopV2ChainCodec.invalid();

      final networks = <LoopReceiveNetwork>[];
      for (final raw in LoopV2ChainCodec.requireList(
        root['networks'],
        maximum: 8,
      )) {
        final map = LoopV2Contract.strictMap(raw, const <String>{
          'chainId',
          'name',
          'address',
          'uri',
          'warningKey',
        });
        final address = LoopV2ChainCodec.requireString(
          map,
          'address',
          pattern: LoopV2ChainCodec.addressPattern,
          maxLength: 42,
        );
        final uri = LoopV2ChainCodec.requireString(
          map,
          'uri',
          pattern: RegExp(r'^ethereum:0x[0-9a-f]{40}@[1-9][0-9]{0,9}$'),
          maxLength: 80,
        );
        // The EIP-681 string must address the same wallet the row names.
        if (!uri.startsWith('ethereum:$address@')) LoopV2ChainCodec.invalid();
        networks.add(
          LoopReceiveNetwork(
            chainId: LoopV2ChainCodec.requireString(
              map,
              'chainId',
              pattern: LoopV2ChainCodec.chainIdPattern,
              maxLength: 32,
            ),
            name: LoopV2ChainCodec.requireText(map, 'name', maxLength: 64),
            address: address,
            uri: uri,
            warningKey: LoopV2ChainCodec.requireText(
              map,
              'warningKey',
              maxLength: 64,
            ),
          ),
        );
      }
      return LoopWalletReceive(walletId: target, networks: networks);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  static LoopWalletDirectory _directory(Object? data) {
    final root = LoopV2Contract.strictMap(data, _directoryKeys);
    LoopV2ChainCodec.requireContractVersion(root);
    final source = LoopV2Contract.strictMap(root['source'], const <String>{
      'provider',
      'observedAt',
    });
    if (source['provider'] != 'privy') LoopV2ChainCodec.invalid();

    final wallets = <LoopWalletAccount>[];
    final seen = <String>{};
    for (final raw in LoopV2ChainCodec.requireList(
      root['wallets'],
      maximum: 50,
    )) {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'walletId',
        'provider',
        'address',
        'kind',
        'status',
        'isActive',
        'firstSeenAt',
        'lastSeenAt',
      });
      if (map['provider'] != 'privy') LoopV2ChainCodec.invalid();
      final rawKind = map['kind'];
      final rawStatus = map['status'];
      if (rawKind is! String || rawStatus is! String) {
        LoopV2ChainCodec.invalid();
      }
      final kind = LoopWalletKind.tryParse(rawKind);
      final status = LoopWalletStatus.tryParse(rawStatus);
      if (kind == null || status == null) LoopV2ChainCodec.invalid();
      final walletId = LoopV2ChainCodec.requireString(
        map,
        'walletId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      );
      if (!seen.add(walletId)) LoopV2ChainCodec.invalid();
      final isActive = LoopV2ChainCodec.requireBool(map, 'isActive');
      // An archived wallet can never be the active one.
      if (status == LoopWalletStatus.archived && isActive) {
        LoopV2ChainCodec.invalid();
      }
      wallets.add(
        LoopWalletAccount(
          walletId: walletId,
          address: LoopV2ChainCodec.requireString(
            map,
            'address',
            pattern: LoopV2ChainCodec.addressPattern,
            maxLength: 42,
          ),
          kind: kind,
          status: status,
          isActive: isActive,
          firstSeenAt: LoopV2ChainCodec.requireTimestamp(map, 'firstSeenAt'),
          lastSeenAt: LoopV2ChainCodec.requireTimestamp(map, 'lastSeenAt'),
        ),
      );
    }

    final activeWalletId = LoopV2ChainCodec.optionalString(
      root,
      'activeWalletId',
      pattern: LoopV2Contract.uuidV4Pattern,
      maxLength: 36,
    );
    if (activeWalletId != null && !seen.contains(activeWalletId)) {
      LoopV2ChainCodec.invalid();
    }
    return LoopWalletDirectory(
      wallets: wallets,
      activeWalletId: activeWalletId,
      observedAt: LoopV2ChainCodec.requireTimestamp(source, 'observedAt'),
    );
  }

  static LoopAssetBalanceRow _balanceRow(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'assetId',
      'symbol',
      'name',
      'decimals',
      'address',
      'balance',
      'pending',
      'valuation',
      'crossCheck',
    });
    return LoopAssetBalanceRow(
      assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
      symbol: LoopV2ChainCodec.requireText(map, 'symbol', maxLength: 32),
      name: LoopV2ChainCodec.requireText(map, 'name'),
      decimals: LoopV2ChainCodec.requireInt(map, 'decimals', maximum: 36),
      address: LoopV2ChainCodec.optionalString(
        map,
        'address',
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      ),
      balance: _balanceAmount(map['balance']),
      pending: _pendingAmount(map['pending']),
      valuation: _valuation(map['valuation']),
      crossCheck: _crossCheck(map['crossCheck']),
    );
  }

  /// The discriminated union keeps "read failed" apart from "holds none".
  static LoopBalanceAmount _balanceAmount(Object? raw) {
    if (raw is! Map || raw['status'] == 'unavailable') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') LoopV2ChainCodec.invalid();
      return LoopBalanceUnavailable(
        LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'rawValue',
      'displayBalance',
      'availableBalance',
      'spendableBalance',
      'gasReserve',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    return LoopBalanceAvailable(
      rawValue: LoopV2ChainCodec.requireRawAmount(map, 'rawValue'),
      displayBalance: LoopV2ChainCodec.requireDecimal(map, 'displayBalance'),
      availableBalance: LoopV2ChainCodec.requireDecimal(
        map,
        'availableBalance',
      ),
      spendableBalance: LoopV2ChainCodec.requireDecimal(
        map,
        'spendableBalance',
      ),
      gasReserve: LoopV2ChainCodec.requireDecimal(map, 'gasReserve'),
    );
  }

  static LoopPendingAmount _pendingAmount(Object? raw) {
    if (raw is! Map || raw['status'] == 'unavailable') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') LoopV2ChainCodec.invalid();
      return LoopPendingUnavailable(
        LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'rawValue',
      'displayValue',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    return LoopPendingAvailable(
      rawValue: LoopV2ChainCodec.requireRawAmount(map, 'rawValue'),
      value: LoopV2ChainCodec.requireDecimal(map, 'displayValue'),
    );
  }

  static LoopValuation _valuation(Object? raw) {
    if (raw is! Map || raw['status'] == 'unavailable') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') LoopV2ChainCodec.invalid();
      return LoopValuationUnavailable(
        LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'priceSource',
      'fetchedAt',
      'quality',
      'reasonCode',
      'proxyAsset',
      'priceUsd',
      'valueUsd',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final rawQuality = map['quality'];
    if (rawQuality is! String) LoopV2ChainCodec.invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality != LoopFactQuality.fresh &&
        quality != LoopFactQuality.stale &&
        quality != LoopFactQuality.proxied) {
      LoopV2ChainCodec.invalid();
    }
    final proxyAsset = LoopV2ChainCodec.optionalString(
      map,
      'proxyAsset',
      pattern: LoopV2ChainCodec.assetIdPattern,
      maxLength: 64,
    );
    // A proxied price must name the asset whose price was borrowed, and only
    // a proxied price may name one.
    if ((quality == LoopFactQuality.proxied) != (proxyAsset != null)) {
      LoopV2ChainCodec.invalid();
    }
    return LoopValuationAvailable(
      priceSource: LoopV2ChainCodec.requireFactSource(map, 'priceSource'),
      fetchedAt: LoopV2ChainCodec.requireTimestamp(map, 'fetchedAt'),
      quality: quality!,
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      proxyAsset: proxyAsset,
      priceUsd: LoopV2ChainCodec.requireDecimal(map, 'priceUsd'),
      valueUsd: LoopV2ChainCodec.requireDecimal(map, 'valueUsd'),
    );
  }

  static LoopBalanceCrossCheck _crossCheck(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'source',
      'status',
      'reasonCode',
      'blockDelta',
    });
    if (map['source'] != 'privy') LoopV2ChainCodec.invalid();
    final rawStatus = map['status'];
    if (rawStatus is! String) LoopV2ChainCodec.invalid();
    final status = LoopCrossCheckStatus.tryParse(rawStatus);
    if (status == null) LoopV2ChainCodec.invalid();
    return LoopBalanceCrossCheck(
      status: status,
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      blockDelta: LoopV2ChainCodec.optionalInt(map, 'blockDelta'),
    );
  }

  static LoopNetWorth _netWorth(Object? raw) {
    if (raw is! Map || raw['status'] == 'unavailable') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'status',
        'reasonCode',
      });
      if (map['status'] != 'unavailable') LoopV2ChainCodec.invalid();
      return LoopNetWorthUnavailable(
        LoopV2ChainCodec.requireReasonCode(map, 'reasonCode'),
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'valuationCurrency',
      'valueUsd',
      'unavailableCount',
      'quality',
      'priceSource',
      'asOf',
      'isSpendable',
    });
    final status = map['status'];
    if (status != 'available' && status != 'partial') {
      LoopV2ChainCodec.invalid();
    }
    if (map['valuationCurrency'] != 'USD') LoopV2ChainCodec.invalid();
    final rawQuality = map['quality'];
    if (rawQuality is! String) LoopV2ChainCodec.invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality != LoopFactQuality.fresh && quality != LoopFactQuality.stale) {
      LoopV2ChainCodec.invalid();
    }
    final unavailableCount = LoopV2ChainCodec.requireInt(
      map,
      'unavailableCount',
    );
    final partial = status == 'partial';
    // `partial` and a non-zero unavailable count are the same fact; a mismatch
    // would let a partial total read as a complete one.
    if (partial != (unavailableCount > 0)) LoopV2ChainCodec.invalid();
    return LoopNetWorthValued(
      partial: partial,
      valuationCurrency: 'USD',
      valueUsd: LoopV2ChainCodec.requireDecimal(map, 'valueUsd'),
      unavailableCount: unavailableCount,
      quality: quality!,
      priceSource: LoopV2ChainCodec.requireFactSource(map, 'priceSource'),
      asOf: LoopV2ChainCodec.requireTimestamp(map, 'asOf'),
      // Net worth is display information, never a balance. The wire pins this
      // to false and any other value is an invalid payload.
      isSpendable: LoopV2ChainCodec.requireFalse(map, 'isSpendable'),
    );
  }
}
