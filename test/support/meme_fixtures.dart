import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';

// ---------------------------------------------------------------------------
// MEME wire fixtures (loop-api `docs/frontend-v2-meme-api.md`)
// ---------------------------------------------------------------------------
//
// Every widget test builds its models by decoding these through the real
// codec, so a page test can never pass on a shape the server does not send.

const String memeTokenIdA = '9ea3e259-6148-4c43-a4be-87ad07223916';
const String memeTokenIdB = '1b2c3d4e-5f60-4a7b-8c9d-0e1f2a3b4c5d';
const String memeIntentIdA = 'dc41735e-f27e-438f-ab4f-9895eca03213';
const String memeWalletId = 'd64786bb-408d-415d-8a69-6277d56c921b';
const String memeWalletAddress = '0x000000000000000000000000000000000000000a';
const String memeCurveAddress = '0xe108d45e3e9d7b8c9c02c5e10544ad811cb39b8a';
const String memeUsd1Address = '0x17d554fd27345940e21d1d7328d038bd4049ce2b';
const String memeTokenAddress = '0xac42e9101f379437f3cce49a5b58609dd9a0ca94';
const String memeProfileId = '0b1c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const String memeMediaId = '2f0c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';

String? memeTestMediaUrl(String mediaId) =>
    'https://api.test/v2/media/$mediaId.webp';

Map<String, Object?> memeRowJson({
  String id = memeTokenIdA,
  String name = 'Frog',
  String symbol = 'FROG',
  String status = 'trading',
  int progressBps = 3327,
  String? price = '0.000009891332712022',
  String? cap = '9891.33271202236719478',
  String? change = '76.89',
  String? tokenAddress = memeTokenAddress,
  String? pool,
  String? graduatedAt,
  String priceSource = 'loop_curve',
  String? quoteUnavailable,
  bool creator = true,
  bool image = true,
  int holderCount = 12,
}) => <String, Object?>{
  'memeTokenId': id,
  'tokenAddress': tokenAddress,
  'name': name,
  'symbol': symbol,
  'imageUrl': image
      ? 'https://api-dev.example/v2/media/$memeMediaId.webp'
      : null,
  'creator': creator
      ? <String, Object?>{
          'publicProfileId': memeProfileId,
          'displayName': 'frogmaker',
          'avatarRef': null,
        }
      : null,
  'status': status,
  'progressBps': progressBps,
  'priceUsd1': price,
  'marketCapUsd1': cap,
  'change1hPct': change,
  'volume24hUsd1': '1980',
  'holderCount': holderCount,
  'tradeCount': 40,
  'createdAt': '2026-10-08T00:00:00.000Z',
  'graduatedAt': graduatedAt,
  'pool': pool,
  'priceSource': price == null
      ? null
      : <String, Object?>{
          'source': priceSource,
          'observedAt': '2026-10-08T03:00:00.000Z',
        },
  if (quoteUnavailable != null)
    'quoteUnavailable': <String, Object?>{'reasonCode': quoteUnavailable},
};

Map<String, Object?> memePageJson({
  String tab = 'new',
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => <String, Object?>{
  'tab': tab,
  'items': items ?? <Map<String, Object?>>[memeRowJson()],
  'nextCursor': nextCursor,
  'rules': <String, Object?>{
    'configVersion': 'memeLaunchpadV1',
    'effectiveAt': '2026-10-08T00:00:00.000Z',
    'graduatingProgressBps': 5000,
    'hotWindowSeconds': 3600,
  },
  'observedAt': '2026-10-08T03:00:05.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> memeCurveJson({
  String vUsd1 = '7980000000000000000000',
  String vToken = '806766917293233082706766918',
  String realUsd1 = '1980000000000000000000',
  String sold = '266233082706766917293233082',
}) => <String, Object?>{
  'vUsd1': vUsd1,
  'vToken': vToken,
  'realUsd1': realUsd1,
  'sold': sold,
  'saleSupply': '800000000000000000000000000',
  'poolSupply': '200000000000000000000000000',
  'totalSupply': '1000000000000000000000000000',
  'graduationUsd1Estimate': '16982417582417582417583',
  'tradeFeeBps': 100,
  'walletCapTokens': '40000000000000000000000000',
  'minBuyUsd1': '1000000000000000000',
};

/// The start of a curve: 6,000 USD1 against 1,073,000,000 tokens.
Map<String, Object?> memeFreshCurveJson() => memeCurveJson(
  vUsd1: '6000000000000000000000',
  vToken: '1073000000000000000000000000',
  realUsd1: '0',
  sold: '0',
);

Map<String, Object?> memeDetailJson({
  String id = memeTokenIdA,
  String status = 'trading',
  int progressBps = 3327,
  String? price = '0.000009891332712022',
  String? cap = '9891.33271202236719478',
  String? change = '76.89',
  String? tokenAddress = memeTokenAddress,
  String? pool,
  String? graduatedAt,
  String priceSource = 'loop_curve',
  String? quoteUnavailable,
  Map<String, Object?>? curve,
  bool vanity = true,
  String? predictedAddress = '0xe6b1a3b4c4e370ea4760ed9ef299efc77cae6666',
  Map<String, Object?>? viewer,
  String? viewerUnavailable,
  bool viewerNull = false,
  Map<String, Object?>? graduation,
  bool mainnet = false,
}) => <String, Object?>{
  'memeToken': <String, Object?>{
    ...memeRowJson(
      id: id,
      status: status,
      progressBps: progressBps,
      price: price,
      cap: cap,
      change: change,
      tokenAddress: tokenAddress,
      pool: pool,
      graduatedAt: graduatedAt,
      priceSource: priceSource,
      quoteUnavailable: quoteUnavailable,
    ),
    'description': 'ribbit',
    'links': <String, Object?>{
      'twitter': 'https://x.com/frog',
      'telegram': null,
      'website': null,
    },
    'metadataHash':
        '0xe704000000000000000000000000000000000000000000000000000000009072',
    'salt':
        '0xd953000000000000000000000000000000000000000000000000000000000c1b',
    'predictedAddress': predictedAddress,
    'vanity': vanity,
    'curve': curve ?? memeCurveJson(),
    'contract': <String, Object?>{
      'address': memeCurveAddress,
      'version': '1.0.0',
      'chainId': mainnet ? 'eip155:56' : 'eip155:97',
      'chainReference': mainnet ? 56 : 97,
      'explorerUrl': 'https://testnet.bscscan.com/token/$memeTokenAddress',
    },
    'viewer': viewerNull || viewerUnavailable != null
        ? null
        : (viewer ?? memeViewerJson()),
    'viewerUnavailable': ?(viewerUnavailable == null
        ? null
        : <String, Object?>{'reasonCode': viewerUnavailable}),
    'graduation': graduation,
    'source': <String, Object?>{
      'source': 'loop_indexer',
      'observedAt': '2026-10-08T03:00:05.000Z',
    },
  },
  'contractVersion': '2.0',
};

Map<String, Object?> memeViewerJson({
  String balance = '10000000000000000000',
  String usd1Balance = '1000000000000000000000',
}) => <String, Object?>{
  'walletId': memeWalletId,
  'balance': balance,
  'usd1Balance': usd1Balance,
  'walletCapRemaining': '39999990000000000000000000',
  'allowanceUsd1': '0',
  'allowanceToken': '0',
};

Map<String, Object?> memeGraduationJson() => <String, Object?>{
  'pool': '0x7777777777777777777777777777777777777777',
  'lpBurnTx':
      '0x5000000000000000000000000000000000000000000000000000000000000001',
  'lpTokenId': '42',
  'usd1ToPool': '16982000000000000000000',
  'tokensToPool': '200000000000000000000000000',
  'feeUsd1': '600000000000000000000',
  'at': '2026-10-08T05:00:00.000Z',
  'residual': null,
};

Map<String, Object?> memeTradeJson({
  String txSuffix = '01',
  bool isBuy = true,
  Map<String, Object?>? account,
}) => <String, Object?>{
  'txHash':
      '0x02020000000000000000000000000000000000000000000000000000000000$txSuffix',
  'logIndex': 3,
  'blockNumber': '135600301',
  'wallet': memeWalletAddress,
  'account': account,
  'isBuy': isBuy,
  'usd1Amount': '5000000000000000000',
  'tokenAmount': '890000000000000000000000',
  'feeUsd1': '50000000000000000',
  'priceAfter': '0.0000056',
  'at': '2026-10-08T00:00:00.000Z',
};

Map<String, Object?> memeTradesJson({
  String id = memeTokenIdA,
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => <String, Object?>{
  'memeTokenId': id,
  'items': items ?? <Map<String, Object?>>[memeTradeJson()],
  'nextCursor': nextCursor,
  'source': <String, Object?>{
    'source': 'loop_indexer',
    'observedAt': '2026-10-08T03:00:05.000Z',
  },
  'contractVersion': '2.0',
};

Map<String, Object?> memeHolderJson({
  String wallet = memeWalletAddress,
  bool isCreator = true,
  bool isViewer = true,
}) => <String, Object?>{
  'wallet': wallet,
  'account': null,
  'balance': '100000000000000000000000000',
  'shareBps': 1000,
  'isCreator': isCreator,
  'isViewer': isViewer,
};

Map<String, Object?> memeHoldersJson({
  String id = memeTokenIdA,
  List<Map<String, Object?>>? items,
  String? nextCursor,
  String? frozenAt,
}) => <String, Object?>{
  'memeTokenId': id,
  'holderCount': 12,
  'frozenAt': frozenAt,
  'items': items ?? <Map<String, Object?>>[memeHolderJson()],
  'nextCursor': nextCursor,
  'source': <String, Object?>{
    'source': 'loop_indexer',
    'observedAt': '2026-10-08T03:00:05.000Z',
  },
  'contractVersion': '2.0',
};

Map<String, Object?> memeCandlesJson({
  String id = memeTokenIdA,
  String interval = '15m',
  int count = 3,
  String? frozenAt,
}) => <String, Object?>{
  'memeTokenId': id,
  'interval': interval,
  'items': <Map<String, Object?>>[
    for (var i = 0; i < count; i += 1)
      <String, Object?>{
        'openTime': DateTime.utc(2026, 10, 8, i).toIso8601String(),
        'open': '0.0000056',
        'high': '0.0000058',
        'low': '0.0000055',
        'close': '0.0000057',
        'volumeUsd1': '5',
        'tradeCount': 2,
      },
  ],
  'frozenAt': frozenAt,
  'source': <String, Object?>{
    'source': 'loop_indexer',
    'observedAt': '2026-10-08T03:00:05.000Z',
  },
  'contractVersion': '2.0',
};

Map<String, Object?> memeQuoteJson({
  String side = 'buy',
  bool walletCapHit = false,
  bool belowMinBuy = false,
  String out = '999636100727544464736354',
}) => <String, Object?>{
  'quote': <String, Object?>{
    'memeTokenId': memeTokenIdA,
    'side': side,
    'amountIn': '10000000000000000000',
    'out': out,
    'fee': '100000000000000000',
    if (side == 'buy') 'refund': '0',
    'priceImpactBps': 24,
    'priceBefore': '0.000009891332712022',
    'priceAfter': '0.000009915890340167',
    'minOutAtDefaultSlippage': '989639739720269020088990',
    'walletCapHit': walletCapHit,
    'walletCapRemaining': '39999990000000000000000000',
    'belowMinBuy': belowMinBuy,
  },
  'basis': <String, Object?>{
    'source': 'chain',
    'blockNumber': '135600320',
    'observedAt': '2026-10-08T03:00:05.000Z',
  },
  'contractVersion': '2.0',
};

Map<String, Object?> _transactionJson({
  required String to,
  required String data,
  required String nonce,
}) => <String, Object?>{
  'chainId': 97,
  'to': to,
  'data': data,
  'value': '0x0',
  'from': memeWalletAddress,
  'gas': '0x493e0',
  'nonce': nonce,
  'type': 'legacy',
  'maxFeePerGas': null,
  'maxPriorityFeePerGas': null,
  'gasPrice': '0x3b9aca00',
};

Map<String, Object?> memeIntentJson({
  String kind = 'buy',
  String state = 'prepared',
  bool approval = false,
  bool signingAllowed = true,
  String expiresAt = '2099-10-08T03:05:00.000Z',
  String? reasonCode,
  String mainData = '0xce9eb517',
  String? calldataData,
  String id = memeIntentIdA,
}) => <String, Object?>{
  'memeIntent': <String, Object?>{
    'memeIntentId': id,
    'kind': kind,
    'state': state,
    'memeTokenId': memeTokenIdA,
    'walletId': memeWalletId,
    'chainId': 'eip155:97',
    'chainReference': 97,
    'contractAddress': memeCurveAddress,
    'tokenAddress': kind == 'create' ? null : memeTokenAddress,
    if (kind == 'create')
      'predictedAddress': '0xe6b1a3b4c4e370ea4760ed9ef299efc77cae6666',
    'usd1Amount': kind == 'sell' ? '0' : '10000000000000000000',
    'tokenAmount': kind == 'sell' ? '1000000000000000000000' : '0',
    'expectedOut': '999636100727544464736354',
    'minOut': '989639739720269020088990',
    'fee': '100000000000000000',
    'refund': '0',
    'deadline': expiresAt,
    'expiresAt': expiresAt,
    'createdAt': '2026-10-08T03:00:00.000Z',
    'calldata': <String, Object?>{
      'to': memeCurveAddress,
      'data': calldataData ?? mainData,
      'value': '0',
    },
    'unsignedTransaction': _transactionJson(
      to: memeCurveAddress,
      data: mainData,
      nonce: approval ? '0x8' : '0x7',
    ),
    'approval': approval
        ? <String, Object?>{
            'token': memeUsd1Address,
            'spender': memeCurveAddress,
            'amount': '10000000000000000000',
            'calldata': <String, Object?>{
              'to': memeUsd1Address,
              'data': '0x095ea7b3',
              'value': '0',
            },
            'unsignedTransaction': _transactionJson(
              to: memeUsd1Address,
              data: '0x095ea7b3',
              nonce: '0x7',
            ),
          }
        : null,
    'payloadDigest':
        'eaa764e000000000000000000000000000000000000000000000000000096ca0',
    'snapshotBlockNumber': '135600320',
    'snapshotBlockHash':
        '0x1000000000000000000000000000000000000000000000000000000000000001',
    'transactionHash': state == 'prepared'
        ? null
        : '0x3000000000000000000000000000000000000000000000000000000000000003',
    'reasonCode': reasonCode,
    'simulation': <String, Object?>{
      'status': approval ? 'unavailable' : 'passed',
      'reasonCode': approval ? 'MEME_APPROVAL_REQUIRED' : null,
    },
    'policy': <String, Object?>{
      'configVersion': 'bscWriteCanaryV1',
      'canaryMaxUsd': '20',
      'valueUsd': '10',
      'priceSource': 'usd1_par',
    },
    'signing': <String, Object?>{
      'mode': 'device_eth_send_transaction',
      'allowed': state == 'prepared' && signingAllowed,
      'reasonCode': state == 'prepared'
          ? (signingAllowed ? null : 'MEME_SIMULATION_REVERTED')
          : 'MEME_INTENT_ALREADY_REPORTED',
    },
  },
  'contractVersion': '2.0',
};

// ---------------------------------------------------------------------------
// Decoded models
// ---------------------------------------------------------------------------

MemeTokenPage memePage({
  String tab = 'new',
  List<Map<String, Object?>>? items,
  String? nextCursor,
}) => LoopV2MemeCodec.tokenPage(
  memePageJson(tab: tab, items: items, nextCursor: nextCursor),
  mediaUrl: memeTestMediaUrl,
);

MemeTokenDetail memeDetail({
  String id = memeTokenIdA,
  String status = 'trading',
  int progressBps = 3327,
  Map<String, Object?>? curve,
  bool vanity = true,
  Map<String, Object?>? viewer,
  String? viewerUnavailable,
  Map<String, Object?>? graduation,
  String? tokenAddress = memeTokenAddress,
  String? price = '0.000009891332712022',
  String? quoteUnavailable,
  String priceSource = 'loop_curve',
  String? change = '76.89',
  bool mainnet = false,
}) => LoopV2MemeCodec.detail(
  memeDetailJson(
    mainnet: mainnet,
    id: id,
    status: status,
    progressBps: progressBps,
    curve: curve,
    vanity: vanity,
    viewer: viewer,
    viewerUnavailable: viewerUnavailable,
    graduation: graduation,
    tokenAddress: tokenAddress,
    price: price,
    cap: price == null ? null : '9891.33271202236719478',
    quoteUnavailable: quoteUnavailable,
    priceSource: priceSource,
    change: change,
  ),
  mediaUrl: memeTestMediaUrl,
);

MemeIntent memeIntent({
  String kind = 'buy',
  String state = 'prepared',
  bool approval = false,
  bool signingAllowed = true,
  String? reasonCode,
}) => LoopV2MemeCodec.intent(
  memeIntentJson(
    kind: kind,
    state: state,
    approval: approval,
    signingAllowed: signingAllowed,
    reasonCode: reasonCode,
  ),
);

MemeQuote memeQuote({
  String side = 'buy',
  bool walletCapHit = false,
  bool belowMinBuy = false,
}) => LoopV2MemeCodec.quote(
  memeQuoteJson(
    side: side,
    walletCapHit: walletCapHit,
    belowMinBuy: belowMinBuy,
  ),
  memeTokenId: memeTokenIdA,
  side: side == 'buy' ? MemeTradeSide.buy : MemeTradeSide.sell,
);

MemeTradePage memeTrades({List<Map<String, Object?>>? items, String? next}) =>
    LoopV2MemeCodec.tradePage(
      memeTradesJson(items: items, nextCursor: next),
      memeTokenId: memeTokenIdA,
    );

MemeHolderPage memeHolders({
  List<Map<String, Object?>>? items,
  String? next,
  String? frozenAt,
}) => LoopV2MemeCodec.holderPage(
  memeHoldersJson(items: items, nextCursor: next, frozenAt: frozenAt),
  memeTokenId: memeTokenIdA,
);

MemeCandleSeries memeCandles({
  MemeCandleInterval interval = MemeCandleInterval.fifteenMinutes,
  int count = 3,
}) => LoopV2MemeCodec.candles(
  memeCandlesJson(interval: interval.wireName, count: count),
  memeTokenId: memeTokenIdA,
  interval: interval,
);
