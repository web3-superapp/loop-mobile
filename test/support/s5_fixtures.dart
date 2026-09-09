import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

/// Shared wire and model fixtures for the step-5 tests.
///
/// They are test inputs only: nothing here is reachable from a product path,
/// so no surface can render them as an account or provider fact.
const s5RequestId = '11111111-1111-4111-8111-111111111111';
const s5ClientVersion = '0.1.0+1';
const s5WalletId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const s5OtherWalletId = '1c3d2e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';
const s5AlertId = '2d4e3f5a-6b7c-4d8e-9fa0-b1c2d3e4f5a6';
const s5NotificationId = '3e5f4a6b-7c8d-4e9f-a0b1-c2d3e4f5a6b7';
const s5RecommendationId = '4f6a5b7c-8d9e-4fa0-b1c2-d3e4f5a6b7c8';
const s5CommunityId = '5a7b6c8d-9eaf-4b01-8c23-d4e5f6a7b8c9';

const s5NativeAssetId = 'eip155:56:native';
const s5WbnbAssetId = 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const s5UsdtAssetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';
const s5Address = '0x00000000000000000000000000000000000000a1';
const s5PoolAddress = '0x3669000000000000000000000000000000000001';
const s5TxHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const s5BlockHash =
    '0x2222222222222222222222222222222222222222222222222222222222222222';
const s5Cursor = 'abc.def';

// ---------------------------------------------------------------------------
// wire fixtures
// ---------------------------------------------------------------------------

Map<String, Object?> s5Unavailable(String reasonCode) => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': reasonCode,
};

Map<String, Object?> s5Fact({
  Object? value = '747.39',
  String? source = 'dexscreener',
  String? fetchedAt = '2026-09-08T07:31:02.112Z',
  int? ttlSeconds = 30,
  String quality = 'fresh',
  Object? reasonCode,
}) => <String, Object?>{
  'value': value,
  'source': source,
  'fetchedAt': fetchedAt,
  'ttlSeconds': ttlSeconds,
  'quality': quality,
  'reasonCode': reasonCode,
};

Map<String, Object?> s5UnavailableFact(String reasonCode) => s5Fact(
  value: null,
  source: null,
  fetchedAt: null,
  ttlSeconds: null,
  quality: 'unavailable',
  reasonCode: reasonCode,
);

Map<String, Object?> s5AssetSummary({String symbol = 'WBNB'}) =>
    <String, Object?>{
      'symbol': symbol,
      'name': 'Wrapped BNB',
      'decimals': 18,
      'status': 'pending',
    };

Map<String, Object?> s5ChainAsset({String assetId = s5WbnbAssetId}) =>
    <String, Object?>{
      'assetId': assetId,
      'chainId': 'eip155:56',
      'address': assetId == s5NativeAssetId
          ? null
          : assetId.substring(assetId.lastIndexOf(':') + 1),
      'symbol': assetId == s5NativeAssetId ? 'BNB' : 'WBNB',
      'name': assetId == s5NativeAssetId ? 'BNB' : 'Wrapped BNB',
      'decimals': 18,
      'status': 'pending',
      'source': <String, Object?>{
        'kind': 'chain_call',
        'blockNumber': '120628195',
        'verifiedAt': '2026-09-08T05:12:21.926Z',
      },
      'updatedAt': '2026-09-08T05:12:21.926Z',
    };

Map<String, Object?> s5Capability({
  bool viewable = true,
  String value = 'viewable',
  Object? reasonCode = 'SWAP_MODULE_NOT_DELIVERED',
}) => <String, Object?>{
  'viewable': viewable,
  'swappable': false,
  'value': value,
  'reasonCode': reasonCode,
};

Map<String, Object?> s5ChainStatusBody({
  String rpcStatus = 'available',
  String verification = 'verified',
  String endpointStatus = 'healthy',
  Object? rpcReasonCode,
}) => <String, Object?>{
  'chain': <String, Object?>{
    'chainId': 'eip155:56',
    'name': 'BNB Smart Chain',
    'reference': 56,
    'nativeAssetId': s5NativeAssetId,
    'confirmations': 15,
    'reorgDepthBlocks': 64,
  },
  'rpc': <String, Object?>{
    'status': rpcStatus,
    'reasonCode': rpcReasonCode,
    'verification': verification,
    'head': <String, Object?>{
      'blockNumber': '120628164',
      'blockHash': s5BlockHash,
      'observedAt': '2026-09-08T05:12:07.738Z',
    },
    'endpoints': <Object?>[
      <String, Object?>{
        'endpointRef': 'rpc-2bd52ca6d267',
        'status': endpointStatus,
        'latencyMs': 515,
        'blockNumber': '120628163',
        'blockLagBlocks': 0,
        'chainVerification': verification,
        'observedAt': '2026-09-08T05:12:07.039Z',
      },
    ],
  },
  'indexer': <Object?>[
    <String, Object?>{
      'lane': 'erc20_transfer',
      'status': 'unavailable',
      'reasonCode': 'BSC_INDEXER_NOT_STARTED',
      'lastBlockNumber': null,
      'lastBlockHash': null,
      'lagBlocks': null,
      'reorgCount': null,
      'updatedAt': null,
    },
    <String, Object?>{
      'lane': 'pool_event',
      'status': 'available',
      'reasonCode': null,
      'lastBlockNumber': '120640705',
      'lastBlockHash': s5BlockHash,
      'lagBlocks': 33,
      'reorgCount': 0,
      'updatedAt': '2026-09-08T07:30:41.000Z',
    },
  ],
  'registry': <String, Object?>{
    'readableAssetCount': 2,
    'registeredPoolCount': 1,
  },
  'contractVersion': '2.0',
};

Map<String, Object?> s5WalletDirectoryBody({
  Object? activeWalletId = s5WalletId,
  String status = 'active',
  bool isActive = true,
}) => <String, Object?>{
  'wallets': <Object?>[
    <String, Object?>{
      'walletId': s5WalletId,
      'provider': 'privy',
      'address': s5Address,
      'kind': 'embedded',
      'status': status,
      'isActive': isActive,
      'firstSeenAt': '2026-09-08T00:00:00.000Z',
      'lastSeenAt': '2026-09-08T00:00:00.000Z',
    },
  ],
  'activeWalletId': activeWalletId,
  'source': <String, Object?>{
    'provider': 'privy',
    'observedAt': '2026-09-08T05:12:07.738Z',
  },
  'contractVersion': '2.0',
};

Map<String, Object?> s5BalanceAvailable({
  String displayBalance = '7',
  String spendableBalance = '6.995',
}) => <String, Object?>{
  'status': 'available',
  'rawValue': '7000000000000000000',
  'displayBalance': displayBalance,
  'availableBalance': displayBalance,
  'spendableBalance': spendableBalance,
  'gasReserve': '0.005',
};

Map<String, Object?> s5ValuationAvailable({
  String quality = 'fresh',
  Object? proxyAsset,
  String valueUsd = '5231.73',
}) => <String, Object?>{
  'status': 'available',
  'priceSource': 'dexscreener',
  'fetchedAt': '2026-09-08T07:52:56.738Z',
  'quality': quality,
  'reasonCode': null,
  'proxyAsset': proxyAsset,
  'priceUsd': '747.39',
  'valueUsd': valueUsd,
};

Map<String, Object?> s5BalanceRow({
  String assetId = s5NativeAssetId,
  Object? balance,
  Object? pending,
  Object? valuation,
  Object? crossCheck,
}) => <String, Object?>{
  'assetId': assetId,
  'symbol': assetId == s5NativeAssetId ? 'BNB' : 'WBNB',
  'name': assetId == s5NativeAssetId ? 'BNB' : 'Wrapped BNB',
  'decimals': 18,
  'address': assetId == s5NativeAssetId
      ? null
      : assetId.substring(assetId.lastIndexOf(':') + 1),
  'balance': balance ?? s5BalanceAvailable(),
  'pending':
      pending ??
      <String, Object?>{
        'status': 'available',
        'rawValue': '0',
        'displayValue': '0',
      },
  'valuation':
      valuation ??
      s5ValuationAvailable(quality: 'proxied', proxyAsset: s5WbnbAssetId),
  'crossCheck':
      crossCheck ??
      <String, Object?>{
        'source': 'privy',
        'status': 'matched',
        'reasonCode': null,
        'blockDelta': null,
      },
};

Map<String, Object?> s5NetWorth({
  String status = 'available',
  int unavailableCount = 0,
}) => <String, Object?>{
  'status': status,
  'valuationCurrency': 'USD',
  'valueUsd': '6352.815',
  'unavailableCount': unavailableCount,
  'quality': 'fresh',
  'priceSource': 'dexscreener',
  'asOf': '2026-09-08T07:52:56.738Z',
  'isSpendable': false,
};

Map<String, Object?> s5BalancesBody({
  List<Object?>? balances,
  Object? netWorth,
}) => <String, Object?>{
  'walletId': s5WalletId,
  'snapshot': <String, Object?>{
    'blockNumber': '120628164',
    'blockHash': s5BlockHash,
    'observedAt': '2026-09-08T05:12:07.738Z',
    'confirmations': 15,
  },
  'gasReservePolicy': <String, Object?>{
    'configVersion': 'walletGasReserveV1',
    'nativeReserveRaw': '5000000000000000',
    'nativeReserve': '0.005',
  },
  'balances': balances ?? <Object?>[s5BalanceRow()],
  'netWorth': netWorth ?? s5NetWorth(),
  'contractVersion': '2.0',
};

Map<String, Object?> s5ActivityBody({Object? nextCursor}) => <String, Object?>{
  'walletId': s5WalletId,
  'items': <Object?>[
    <String, Object?>{
      'assetId': s5WbnbAssetId,
      'symbol': 'WBNB',
      'decimals': 18,
      'direction': 'in',
      'counterpartyAddress': s5Address,
      'rawValue': '1500000000000000000',
      'displayValue': '1.5',
      'transactionHash': s5TxHash,
      'logIndex': 3,
      'blockNumber': '120628064',
      'blockHash': s5BlockHash,
      'confirmations': 101,
      'status': 'confirmed',
      'observedAt': '2026-09-08T00:00:00.000Z',
    },
  ],
  'nextCursor': nextCursor,
  'freshness': <String, Object?>{
    'indexerBlockNumber': '120628771',
    'headBlockNumber': '120628804',
    'lagBlocks': 33,
    'observedAt': '2026-09-08T05:16:56.199Z',
  },
  'nativeTransfers': s5Unavailable('NATIVE_TRANSFER_SCAN_NOT_SUPPORTED'),
  'crossChain': s5Unavailable('CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED'),
  'contractVersion': '2.0',
};

Map<String, Object?> s5ReceiveBody() => <String, Object?>{
  'walletId': s5WalletId,
  'networks': <Object?>[
    <String, Object?>{
      'chainId': 'eip155:56',
      'name': 'BNB Smart Chain',
      'address': s5Address,
      'uri': 'ethereum:$s5Address@56',
      'warningKey': 'wallet.receive.bscOnly',
    },
  ],
  'contractVersion': '2.0',
};

Map<String, Object?> s5WatchlistBody({int version = 1}) => <String, Object?>{
  'version': version,
  'updatedAt': '2026-09-08T05:12:50.038Z',
  'groups': <Object?>[
    <String, Object?>{
      'key': 'mining',
      'name': 'Mining',
      'items': <Object?>[
        <String, Object?>{
          'assetId': s5WbnbAssetId,
          'asset': s5AssetSummary(),
          'reasonCode': null,
        },
        <String, Object?>{
          'assetId': s5UsdtAssetId,
          'asset': null,
          'reasonCode': 'ASSET_NOT_READABLE',
        },
      ],
    },
  ],
  'contractVersion': '2.0',
};

Map<String, Object?> s5OverviewBody({
  Object? watchlist,
  Object? trending,
  bool newPairsAvailable = false,
}) => <String, Object?>{
  'watchlist':
      watchlist ??
      <String, Object?>{
        'status': 'available',
        'version': 3,
        'items': <Object?>[
          <String, Object?>{
            'assetId': s5WbnbAssetId,
            'asset': s5AssetSummary(),
            'price': s5Fact(),
            'priceChange24h': s5Fact(value: '-3.2', ttlSeconds: 30),
          },
        ],
      },
  'trending':
      trending ??
      <String, Object?>{
        'status': 'available',
        'recommendationId': s5RecommendationId,
        'rules': <String, Object?>{
          'configVersion': 'marketTrendingV1',
          'effectiveAt': '2026-09-08T00:00:00.000Z',
          'ordering': 'dexscreener_volume_h24_desc',
        },
        'items': <Object?>[
          <String, Object?>{
            'assetId': s5WbnbAssetId,
            'asset': s5AssetSummary(),
            'price': s5Fact(
              quality: 'stale',
              reasonCode: 'MARKET_PROVIDER_RATE_LIMITED',
            ),
            'priceChange24h': s5UnavailableFact('MARKET_FACT_NOT_REPORTED'),
            'volume24h': s5Fact(value: '1234567.89'),
            'liquidityUsd': s5Fact(value: '9876543.21'),
          },
        ],
      },
  'newPairs': newPairsAvailable
      ? <String, Object?>{'status': 'available'}
      : s5Unavailable('MARKET_PROVIDER_GECKOTERMINAL_DISABLED'),
  'smartMoney': s5Unavailable('SMART_MONEY_RUNTIME_DEFERRED'),
  'observedAt': '2026-09-08T07:31:02.300Z',
  'contractVersion': '2.0',
};

Map<String, Object?> s5AssetDetailBody({
  Object? capability,
  Object? community,
  Object? security,
}) => <String, Object?>{
  'asset': s5ChainAsset(),
  'capability': capability ?? s5Capability(),
  'price': s5Fact(),
  'priceChange24h': s5Fact(value: '0.27'),
  'liquidityUsd': s5Fact(value: '9876543.21'),
  'volume24h': s5Fact(value: '1234567.89'),
  'marketCap': s5UnavailableFact('MARKET_FACT_NOT_REPORTED'),
  'fdv': s5Fact(value: '99999999'),
  'primaryPair': <String, Object?>{
    'pairAddress': s5PoolAddress,
    'dexId': 'pancakeswap',
    'labels': <Object?>['v3'],
    'quoteTokenAddress': s5UsdtAssetId.substring(
      s5UsdtAssetId.lastIndexOf(':') + 1,
    ),
    'quoteTokenSymbol': 'USDT',
    'pairCreatedAt': '2023-04-05T14:12:23.000Z',
  },
  'community': community ?? s5Unavailable('COMMUNITY_NOT_BOUND'),
  'security':
      security ??
      <String, Object?>{
        'status': 'available',
        'source': 'goplus',
        'fetchedAt': '2026-09-08T07:20:00.000Z',
        'ttlSeconds': 600,
        'quality': 'fresh',
        'reasonCode': null,
        'facts': <Object?>[
          <String, Object?>{
            'fact': 'openSource',
            'value': 'true',
            'source': 'goplus',
            'observedAt': '2026-09-08T07:20:00.000Z',
          },
          <String, Object?>{
            'fact': 'sellTax',
            'value': '0.05',
            'source': 'goplus',
            'observedAt': '2026-09-08T07:20:00.000Z',
          },
        ],
      },
  'holderCount': s5Fact(value: '8019338', source: 'goplus', ttlSeconds: 600),
  'contractVersion': '2.0',
};

Map<String, Object?> s5Candle({
  String openTime = '2026-09-08T06:00:00.000Z',
  String closeTime = '2026-09-08T07:00:00.000Z',
  String open = '747.12',
  String high = '748.9',
  String low = '746.5',
  String close = '747.48',
  bool isOpen = false,
}) => <String, Object?>{
  'openTime': openTime,
  'closeTime': closeTime,
  'open': open,
  'high': high,
  'low': low,
  'close': close,
  'volume': '1234.5',
  'swapCount': 4812,
  'isOpen': isOpen,
};

Map<String, Object?> s5CandlesBody({
  String interval = '1h',
  String quality = 'derived',
  List<Object?>? items,
}) => <String, Object?>{
  'assetId': s5WbnbAssetId,
  'interval': interval,
  'candles': <String, Object?>{
    'status': 'available',
    'quality': quality,
    'source': 'loop_indexer',
    'fetchedAt': '2026-09-08T07:30:41.000Z',
    'labelKey': 'market.candles.onChainSwapAggregate',
    'pool': <String, Object?>{
      'address': s5PoolAddress,
      'protocol': 'pancakeswap_v3',
      'quoteAssetId': s5UsdtAssetId,
      'quoteSymbol': 'USDT',
    },
    'priceUnit': 'USDT per WBNB',
    'items':
        items ??
        <Object?>[
          s5Candle(),
          s5Candle(
            openTime: '2026-09-08T07:00:00.000Z',
            closeTime: '2026-09-08T08:00:00.000Z',
            isOpen: true,
          ),
        ],
  },
  'contractVersion': '2.0',
};

Map<String, Object?> s5TradesBody({bool isOwn = true}) => <String, Object?>{
  'assetId': s5WbnbAssetId,
  'trades': <String, Object?>{
    'status': 'available',
    'source': 'loop_indexer',
    'items': <Object?>[
      <String, Object?>{
        'transactionHash': s5TxHash,
        'logIndex': 12,
        'blockNumber': '120640705',
        'blockHash': s5BlockHash,
        'blockTimestamp': '2026-09-08T07:30:39.000Z',
        'confirmations': 101,
        'status': 'confirmed',
        'direction': 'buy',
        'amountAsset': '1.25',
        'amountQuote': '934.35',
        'quoteAssetId': s5UsdtAssetId,
        'quoteSymbol': 'USDT',
        'priceAfter': '747.482453211647133359',
        'poolAddress': s5PoolAddress,
        'isOwn': isOwn,
      },
    ],
    'nextCursor': null,
    'freshness': <String, Object?>{
      'indexerBlockNumber': '120640710',
      'headBlockNumber': '120640743',
      'lagBlocks': 33,
      'observedAt': '2026-09-08T07:31:00.000Z',
    },
  },
  'contractVersion': '2.0',
};

Map<String, Object?> s5HoldersBody() => <String, Object?>{
  'assetId': s5WbnbAssetId,
  'holderCount': s5Fact(value: '8019338', source: 'goplus', ttlSeconds: 600),
  'distribution': s5Unavailable('HOLDER_DISTRIBUTION_NOT_SUPPORTED'),
  'contractVersion': '2.0',
};

Map<String, Object?> s5NewPairsBody({bool available = false}) =>
    <String, Object?>{
      'newPairs': available
          ? <String, Object?>{
              'status': 'available',
              'source': 'geckoterminal',
              'fetchedAt': '2026-09-08T07:31:00.000Z',
              'ttlSeconds': 60,
              'quality': 'fresh',
              'reasonCode': null,
              'items': <Object?>[
                <String, Object?>{
                  'poolAddress': s5PoolAddress,
                  'dexId': 'pancakeswap_v3',
                  'name': 'X / WBNB',
                  'baseTokenAddress': s5Address,
                  'quoteTokenAddress': s5Address,
                  'registryAssetId': s5WbnbAssetId,
                  'createdAt': '2026-09-08T05:00:00.000Z',
                  'reserveUsd': '12345.6',
                  'volumeH24Usd': '2345.6',
                },
              ],
            }
          : s5Unavailable('MARKET_PROVIDER_GECKOTERMINAL_DISABLED'),
      'riskScreening': s5Unavailable('MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED'),
      'contractVersion': '2.0',
    };

Map<String, Object?> s5AlertBody({
  String state = 'active',
  Object? triggeredAt,
  int version = 1,
}) => <String, Object?>{
  'alertId': s5AlertId,
  'assetId': s5WbnbAssetId,
  'asset': s5AssetSummary(),
  'condition': 'at_or_above',
  'threshold': '800.5',
  'expiresAt': null,
  'state': state,
  'triggeredAt': triggeredAt,
  'lastEvaluatedAt': '2026-09-08T07:31:30.000Z',
  'delivery': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
  'version': version,
  'createdAt': '2026-09-08T07:00:00.000Z',
  'updatedAt': '2026-09-08T07:31:30.000Z',
};

Map<String, Object?> s5NotificationBody({Object? readAt}) => <String, Object?>{
  'notificationId': s5NotificationId,
  'type': 'trade.priceAlert',
  'entityRef': 'priceAlert:$s5AlertId',
  'contextRoute': 'token',
  'contextParams': <String, Object?>{'assetId': s5WbnbAssetId},
  'payload': <String, Object?>{
    'assetId': s5WbnbAssetId,
    'symbol': 'WBNB',
    'condition': 'at_or_above',
    'threshold': '700',
    'observedValue': '747.39',
    'source': 'dexscreener',
    'observedAt': '2026-09-08T07:31:30.000Z',
  },
  'source': 'dexscreener',
  'observedAt': '2026-09-08T07:31:30.000Z',
  'readAt': readAt,
  'createdAt': '2026-09-08T07:31:31.204Z',
};

Map<String, Object?> s5FeedBody({Object? readAt, int unreadCount = 1}) =>
    <String, Object?>{
      'items': <Object?>[s5NotificationBody(readAt: readAt)],
      'nextCursor': null,
      'unreadCount': unreadCount,
      'push': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
      'contractVersion': '2.0',
    };

Map<String, Object?> s5PreferencesBody({
  int version = 0,
  bool communityAll = false,
}) => <String, Object?>{
  'version': version,
  'updatedAt': version == 0 ? null : '2026-09-08T07:00:00.000Z',
  'categories': <String, Object?>{
    for (final category in LoopNotificationCategory.values)
      category.wireName: <String, Object?>{
        'enabled': switch (category) {
          LoopNotificationCategory.communityAll => communityAll,
          _ => true,
        },
        'locked': category == LoopNotificationCategory.securityEvent,
      },
  },
  'push': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
  'contractVersion': '2.0',
};

// ---------------------------------------------------------------------------
// Dio harness
// ---------------------------------------------------------------------------

Dio s5Dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> s5Response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String cacheControl = 'no-store',
  String requestId = s5RequestId,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      'x-request-id': <String>[requestId],
    }),
  );
}

DioException s5ErrorResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  String category = 'availability',
  bool retryable = true,
  String userMessageKey = 'errors.capability.unavailable',
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: <String, Object?>{
        'code': code,
        'category': category,
        'retryable': retryable,
        'userMessageKey': userMessageKey,
        'correlationId': s5RequestId,
        'detailsSafe': null,
        'providerReferenceSafe': null,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': const <String>['no-store'],
        'x-request-id': const <String>[s5RequestId],
        if (statusCode == 401)
          'www-authenticate': const <String>['Bearer realm="loop-api"'],
      }),
    ),
  );
}

// ---------------------------------------------------------------------------
// model fixtures
// ---------------------------------------------------------------------------

Decimal s5Decimal(String value) => Decimal.parse(value);

LoopFact s5FreshFact(String value) => LoopFact(
  value: s5Decimal(value),
  source: LoopFactSource.dexscreener,
  fetchedAt: DateTime.utc(2026, 9, 8, 7, 31),
  ttlSeconds: 30,
  quality: LoopFactQuality.fresh,
  reasonCode: null,
);

LoopFact s5StaleFact(String value) => LoopFact(
  value: s5Decimal(value),
  source: LoopFactSource.dexscreener,
  fetchedAt: DateTime.utc(2026, 9, 8, 6),
  ttlSeconds: 30,
  quality: LoopFactQuality.stale,
  reasonCode: 'MARKET_PROVIDER_RATE_LIMITED',
);

LoopAssetSummary s5Summary({String symbol = 'WBNB'}) => LoopAssetSummary(
  symbol: symbol,
  name: 'Wrapped BNB',
  decimals: 18,
  status: LoopAssetStatus.pending,
);

MarketAssetRow s5MarketRow({
  String assetId = s5WbnbAssetId,
  LoopFact? price,
  LoopFact? change,
  LoopAssetSummary? asset,
}) => MarketAssetRow(
  assetId: assetId,
  asset: asset ?? s5Summary(),
  price: price ?? s5FreshFact('747.39'),
  priceChange24h: change ?? s5FreshFact('0.27'),
);

MarketOverview s5Overview({
  MarketWatchlistBlock? watchlist,
  MarketTrendingBlock? trending,
  bool newPairsAvailable = false,
}) => MarketOverview(
  watchlist:
      watchlist ??
      MarketWatchlistAvailable(
        version: 3,
        items: <MarketAssetRow>[s5MarketRow()],
      ),
  trending:
      trending ??
      MarketTrendingAvailable(
        recommendationId: s5RecommendationId,
        rules: MarketTrendingRules(
          configVersion: 'marketTrendingV1',
          effectiveAt: DateTime.utc(2026, 9, 8),
          ordering: 'dexscreener_volume_h24_desc',
        ),
        items: <MarketAssetRow>[s5MarketRow()],
      ),
  newPairsAvailable: newPairsAvailable,
  newPairsReasonCode: newPairsAvailable
      ? null
      : 'MARKET_PROVIDER_GECKOTERMINAL_DISABLED',
  smartMoney: const LoopUnavailable('SMART_MONEY_RUNTIME_DEFERRED'),
  observedAt: DateTime.utc(2026, 9, 8, 7, 31),
);

LoopChainAsset s5Asset({String assetId = s5WbnbAssetId}) => LoopChainAsset(
  assetId: assetId,
  chainId: 'eip155:56',
  address: assetId == s5NativeAssetId
      ? null
      : assetId.substring(assetId.lastIndexOf(':') + 1),
  symbol: assetId == s5NativeAssetId ? 'BNB' : 'WBNB',
  name: assetId == s5NativeAssetId ? 'BNB' : 'Wrapped BNB',
  decimals: 18,
  status: LoopAssetStatus.pending,
  source: LoopAssetSource(
    kind: LoopAssetSourceKind.chainCall,
    blockNumber: BigInt.from(120628195),
    verifiedAt: DateTime.utc(2026, 9, 8, 5, 12),
  ),
  updatedAt: DateTime.utc(2026, 9, 8, 5, 12),
);

const s5ViewableCapability = LoopAssetCapability(
  viewable: true,
  swappable: false,
  value: LoopAssetCapabilityValue.viewable,
  reasonCode: 'SWAP_MODULE_NOT_DELIVERED',
);

MarketAssetDetail s5Detail({
  LoopAssetCapability? capability,
  MarketSecurityBlock? security,
  MarketCommunityBlock? community,
  LoopFact? price,
}) => MarketAssetDetail(
  asset: s5Asset(),
  capability: capability ?? s5ViewableCapability,
  price: price ?? s5FreshFact('747.39'),
  priceChange24h: s5FreshFact('0.27'),
  liquidityUsd: s5FreshFact('9876543.21'),
  volume24h: s5FreshFact('1234567.89'),
  marketCap: const LoopFact.unavailable('MARKET_FACT_NOT_REPORTED'),
  fdv: s5FreshFact('99999999'),
  primaryPair: MarketPrimaryPair(
    pairAddress: s5PoolAddress,
    dexId: 'pancakeswap',
    labels: const <String>['v3'],
    quoteTokenAddress: s5Address,
    quoteTokenSymbol: 'USDT',
    pairCreatedAt: DateTime.utc(2023, 4, 5),
  ),
  community:
      community ?? const MarketCommunityUnavailable('COMMUNITY_NOT_BOUND'),
  security:
      security ??
      MarketSecurityAvailable(
        source: LoopFactSource.goplus,
        fetchedAt: DateTime.utc(2026, 9, 8, 7, 20),
        ttlSeconds: 600,
        quality: LoopFactQuality.fresh,
        reasonCode: null,
        facts: <MarketSecurityFact>[
          MarketSecurityFact(
            fact: 'openSource',
            value: 'true',
            source: LoopFactSource.goplus,
            observedAt: DateTime.utc(2026, 9, 8, 7, 20),
          ),
        ],
      ),
  holderCount: s5FreshFact('8019338'),
);

LoopCandle s5ModelCandle({
  int hour = 6,
  String open = '747.12',
  String close = '747.48',
  bool isOpen = false,
}) => LoopCandle(
  openTime: DateTime.utc(2026, 9, 8, hour),
  closeTime: DateTime.utc(2026, 9, 8, hour + 1),
  open: s5Decimal(open),
  high: s5Decimal('748.9'),
  low: s5Decimal('746.5'),
  close: s5Decimal(close),
  volume: s5Decimal('1234.5'),
  swapCount: 4812,
  isOpen: isOpen,
);

MarketCandleSeries s5Series({
  LoopFactQuality quality = LoopFactQuality.derived,
  List<LoopCandle>? items,
}) => MarketCandleSeries(
  assetId: s5WbnbAssetId,
  interval: LoopCandleInterval.oneHour,
  candles: MarketCandlesAvailable(
    quality: quality,
    source: LoopFactSource.loopIndexer,
    fetchedAt: DateTime.utc(2026, 9, 8, 7, 30),
    labelKey: 'market.candles.onChainSwapAggregate',
    pool: const LoopCandlePool(
      address: s5PoolAddress,
      protocol: 'pancakeswap_v3',
      quoteAssetId: s5UsdtAssetId,
      quoteSymbol: 'USDT',
    ),
    priceUnit: 'USDT per WBNB',
    items:
        items ??
        <LoopCandle>[s5ModelCandle(), s5ModelCandle(hour: 7, isOpen: true)],
  ),
);

LoopWalletDirectory s5Directory({String? activeWalletId = s5WalletId}) =>
    LoopWalletDirectory(
      wallets: <LoopWalletAccount>[
        LoopWalletAccount(
          walletId: s5WalletId,
          address: s5Address,
          kind: LoopWalletKind.embedded,
          status: LoopWalletStatus.active,
          isActive: activeWalletId == s5WalletId,
          firstSeenAt: DateTime.utc(2026, 9, 8),
          lastSeenAt: DateTime.utc(2026, 9, 8),
        ),
        LoopWalletAccount(
          walletId: s5OtherWalletId,
          address: '0x00000000000000000000000000000000000000b2',
          kind: LoopWalletKind.external,
          status: LoopWalletStatus.active,
          isActive: activeWalletId == s5OtherWalletId,
          firstSeenAt: DateTime.utc(2026, 9, 8),
          lastSeenAt: DateTime.utc(2026, 9, 8),
        ),
      ],
      activeWalletId: activeWalletId,
      observedAt: DateTime.utc(2026, 9, 8, 5, 12),
    );

LoopAssetBalanceRow s5Row({
  String assetId = s5NativeAssetId,
  LoopBalanceAmount? balance,
  LoopValuation? valuation,
  LoopPendingAmount? pending,
  LoopBalanceCrossCheck? crossCheck,
}) => LoopAssetBalanceRow(
  assetId: assetId,
  symbol: assetId == s5NativeAssetId ? 'BNB' : 'WBNB',
  name: assetId == s5NativeAssetId ? 'BNB' : 'Wrapped BNB',
  decimals: 18,
  address: assetId == s5NativeAssetId ? null : s5Address,
  balance:
      balance ??
      LoopBalanceAvailable(
        rawValue: '7000000000000000000',
        displayBalance: s5Decimal('7'),
        availableBalance: s5Decimal('7'),
        spendableBalance: s5Decimal('6.995'),
        gasReserve: s5Decimal('0.005'),
      ),
  pending:
      pending ?? LoopPendingAvailable(rawValue: '0', value: s5Decimal('0')),
  valuation:
      valuation ??
      LoopValuationAvailable(
        priceSource: LoopFactSource.dexscreener,
        fetchedAt: DateTime.utc(2026, 9, 8, 7, 52),
        quality: LoopFactQuality.proxied,
        reasonCode: null,
        proxyAsset: s5WbnbAssetId,
        priceUsd: s5Decimal('747.39'),
        valueUsd: s5Decimal('5231.73'),
      ),
  crossCheck:
      crossCheck ??
      const LoopBalanceCrossCheck(
        status: LoopCrossCheckStatus.matched,
        reasonCode: null,
        blockDelta: null,
      ),
);

LoopWalletBalances s5Balances({
  List<LoopAssetBalanceRow>? rows,
  LoopNetWorth? netWorth,
  LoopLaunchChainBalance? launchChain,
}) => LoopWalletBalances(
  walletId: s5WalletId,
  snapshot: LoopBalanceSnapshot(
    blockNumber: BigInt.from(120628164),
    blockHash: s5BlockHash,
    observedAt: DateTime.utc(2026, 9, 8, 5, 12),
    confirmations: 15,
  ),
  gasReservePolicy: LoopGasReservePolicy(
    configVersion: 'walletGasReserveV1',
    nativeReserveRaw: '5000000000000000',
    nativeReserve: s5Decimal('0.005'),
  ),
  balances: rows ?? <LoopAssetBalanceRow>[s5Row()],
  launchChain: launchChain,
  netWorth:
      netWorth ??
      LoopNetWorthValued(
        partial: false,
        valuationCurrency: 'USD',
        valueUsd: s5Decimal('6352.815'),
        unavailableCount: 0,
        quality: LoopFactQuality.fresh,
        priceSource: LoopFactSource.dexscreener,
        asOf: DateTime.utc(2026, 9, 8, 7, 52),
        isSpendable: false,
      ),
);

LoopWalletActivityPage s5Activity({
  List<LoopWalletActivityEntry>? items,
  String? nextCursor,
}) => LoopWalletActivityPage(
  walletId: s5WalletId,
  items:
      items ??
      <LoopWalletActivityEntry>[
        LoopWalletActivityEntry(
          assetId: s5WbnbAssetId,
          symbol: 'WBNB',
          decimals: 18,
          direction: LoopTransferDirection.incoming,
          counterpartyAddress: s5Address,
          rawValue: '1500000000000000000',
          displayValue: s5Decimal('1.5'),
          transactionHash: s5TxHash,
          logIndex: 3,
          blockNumber: BigInt.from(120628064),
          blockHash: s5BlockHash,
          confirmations: 101,
          status: LoopConfirmationStatus.confirmed,
          observedAt: DateTime.utc(2026, 9, 8),
        ),
      ],
  nextCursor: nextCursor,
  freshness: LoopIndexerFreshness(
    indexerBlockNumber: BigInt.from(120628771),
    headBlockNumber: BigInt.from(120628804),
    lagBlocks: 33,
    observedAt: DateTime.utc(2026, 9, 8, 5, 16),
  ),
  nativeTransfers: const LoopUnavailable('NATIVE_TRANSFER_SCAN_NOT_SUPPORTED'),
  crossChain: const LoopUnavailable('CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED'),
);

LoopWalletReceive s5Receive() => LoopWalletReceive(
  walletId: s5WalletId,
  networks: const <LoopReceiveNetwork>[
    LoopReceiveNetwork(
      chainId: 'eip155:56',
      name: 'BNB Smart Chain',
      address: s5Address,
      uri: 'ethereum:$s5Address@56',
      warningKey: 'wallet.receive.bscOnly',
    ),
  ],
);

LoopChainStatus s5Status({
  bool mismatched = false,
  LoopEndpointStatus endpointStatus = LoopEndpointStatus.healthy,
  LoopLaunchChainStatus? launchChain,
}) => LoopChainStatus(
  launchChain: launchChain,
  chain: const LoopChainInfo(
    chainId: 'eip155:56',
    name: 'BNB Smart Chain',
    reference: 56,
    nativeAssetId: s5NativeAssetId,
    confirmations: 15,
    reorgDepthBlocks: 64,
  ),
  rpc: LoopRpcHealth(
    available: !mismatched,
    reasonCode: mismatched ? 'BSC_CHAIN_ID_MISMATCH' : null,
    verification: mismatched
        ? LoopChainVerification.mismatched
        : LoopChainVerification.verified,
    head: LoopChainHead(
      blockNumber: BigInt.from(120628164),
      blockHash: s5BlockHash,
      observedAt: DateTime.utc(2026, 9, 8, 5, 12),
    ),
    endpoints: <LoopRpcEndpointHealth>[
      LoopRpcEndpointHealth(
        endpointRef: 'rpc-2bd52ca6d267',
        status: endpointStatus,
        latencyMs: 515,
        blockNumber: BigInt.from(120628163),
        blockLagBlocks: 0,
        chainVerification: mismatched
            ? LoopChainVerification.mismatched
            : LoopChainVerification.verified,
        observedAt: DateTime.utc(2026, 9, 8, 5, 12),
      ),
    ],
  ),
  indexer: <LoopIndexerLaneStatus>[
    const LoopIndexerLaneStatus(
      lane: LoopIndexerLane.erc20Transfer,
      available: false,
      reasonCode: 'BSC_INDEXER_NOT_STARTED',
      lastBlockNumber: null,
      lastBlockHash: null,
      lagBlocks: null,
      reorgCount: null,
      updatedAt: null,
    ),
  ],
  registry: const LoopRegistryCounts(
    readableAssetCount: 2,
    registeredPoolCount: 1,
  ),
);

WatchlistSnapshot s5Watchlist({int version = 1}) => WatchlistSnapshot(
  version: version,
  updatedAt: DateTime.utc(2026, 9, 8, 5, 12),
  groups: <WatchlistGroup>[
    WatchlistGroup(
      key: 'mining',
      name: 'Mining',
      items: <WatchlistItem>[
        WatchlistItem(assetId: s5WbnbAssetId, asset: s5Summary()),
        WatchlistItem(
          assetId: s5UsdtAssetId,
          asset: s5Summary(symbol: 'USDT'),
        ),
        WatchlistItem(
          assetId: s5NativeAssetId,
          reasonCode: 'ASSET_NOT_READABLE',
        ),
      ],
    ),
  ],
);

LoopPriceAlert s5Alert({
  LoopAlertState state = LoopAlertState.active,
  int version = 1,
}) => LoopPriceAlert(
  alertId: s5AlertId,
  assetId: s5WbnbAssetId,
  asset: s5Summary(),
  condition: LoopAlertCondition.atOrAbove,
  threshold: s5Decimal('800.5'),
  thresholdText: '800.5',
  expiresAt: null,
  state: state,
  triggeredAt: state == LoopAlertState.triggered
      ? DateTime.utc(2026, 9, 8, 7, 31)
      : null,
  lastEvaluatedAt: DateTime.utc(2026, 9, 8, 7, 31),
  delivery: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
  version: version,
  createdAt: DateTime.utc(2026, 9, 8, 7),
  updatedAt: DateTime.utc(2026, 9, 8, 7, 31),
);

LoopNotificationEntry s5Notification({DateTime? readAt}) =>
    LoopNotificationEntry(
      notificationId: s5NotificationId,
      type: LoopNotificationCategory.tradePriceAlert,
      entityRef: 'priceAlert:$s5AlertId',
      contextRoute: 'token',
      contextParams: const <String, String>{'assetId': s5WbnbAssetId},
      payload: const <String, String?>{
        'symbol': 'WBNB',
        'threshold': '700',
        'observedValue': '747.39',
      },
      source: 'dexscreener',
      observedAt: DateTime.utc(2026, 9, 8, 7, 31),
      readAt: readAt,
      createdAt: DateTime.utc(2026, 9, 8, 7, 31),
    );

LoopNotificationFeed s5Feed({DateTime? readAt, int unreadCount = 1}) =>
    LoopNotificationFeed(
      items: <LoopNotificationEntry>[s5Notification(readAt: readAt)],
      nextCursor: null,
      unreadCount: unreadCount,
      push: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
    );

LoopNotificationPreferences s5Preferences({
  int version = 0,
  bool communityAll = false,
}) => LoopNotificationPreferences(
  version: version,
  updatedAt: version == 0 ? null : DateTime.utc(2026, 9, 8, 7),
  categories: <LoopNotificationCategory, LoopNotificationCategoryState>{
    for (final category in LoopNotificationCategory.values)
      category: LoopNotificationCategoryState(
        enabled: switch (category) {
          LoopNotificationCategory.communityAll => communityAll,
          _ => true,
        },
        locked: category == LoopNotificationCategory.securityEvent,
      ),
  },
  push: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
);
