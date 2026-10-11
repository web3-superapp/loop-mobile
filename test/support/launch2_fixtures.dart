// Contract-shaped `launch2` payloads (loop-api decision 0114 / 0117 / 0118,
// `docs/frontend-v2-launch2-api.md`), hand-written for client decision 0139;
// `snapshot.closure` and `closed_no_holders` from loop-api 0120 (decision
// 0142, loop-api integration/v2 548066c).
// Every builder answers the exact published key set so the strict codec is
// exercised by every widget test that uses them.

import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';

const String l2InstanceA = '8b9f3c1e-2d4a-4f6b-9c8d-1e2f3a4b5c6d';
const String l2InstanceB = '9c0a4d2f-3e5b-4a7c-8d9e-2f3a4b5c6d7e';
const String l2ProjectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String l2WalletId = 'd64786bb-408d-415d-8a69-6277d56c921b';
const String l2WalletAddress = '0x000000000000000000000000000000000000000a';
const String l2IntentId = 'dc41735e-f27e-438f-ab4f-9895eca03213';
const String l2Meme = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa6666';
const String l2Nft = '0x1111111111111111111111111111111111111111';
const String l2Curve = '0x2222222222222222222222222222222222222222';
const String l2Usd1 = '0x17d554fd27345940e21d1d7328d038bd4049ce2b';
const String l2Hook = '0x3333333333333333333333333333333333333333';
const String l2Hash =
    '0x5d1c000000000000000000000000000000000000000000000000000000000001';
const String l2PoolId =
    '0x9f00000000000000000000000000000000000000000000000000000000000099';

/// The clock every widget test runs on.
final DateTime l2Now = DateTime.utc(2027, 1, 20, 7);

String _iso(DateTime value) => value.toUtc().toIso8601String();

Map<String, Object?> l2RowJson({
  String instanceId = l2InstanceA,
  String stage = 'nft_sale',
  DateTime? nextChangeAt,
  bool noNextChange = false,
  String? holdReason,
  String soldCount = '2',
  int soldBps = 0,
  String soldSupply = '0',
  String price = '0.00004166666625',
  String name = 'Frog Launch',
  String ticker = 'FROG',
}) => <String, Object?>{
  'instanceId': instanceId,
  'projectId': l2ProjectId,
  'launchId': l2Hash,
  'chainId': 'eip155:97',
  'name': name,
  'ticker': ticker,
  'logoUrl': null,
  'memeAddress': l2Meme,
  'stage': stage,
  'nextChangeAt': noNextChange || stage == 'closed_no_holders'
      ? null
      : _iso(nextChangeAt ?? l2Now.add(const Duration(days: 2, hours: 3))),
  'holdReason': holdReason,
  'activatedAt': '2027-01-15T07:00:00.000Z',
  'nftSale': <String, Object?>{
    'priceUsd1': '100',
    'soldCount': soldCount,
    'startAt': '2027-01-16T07:00:00.000Z',
    'endAt': '2027-01-23T07:00:00.000Z',
  },
  'curve': <String, Object?>{
    'saleSupply': '800000000',
    'soldSupply': soldSupply,
    'soldBps': soldBps,
    'reserveUsd1': '0',
    'graduationReserveUsd1': '133333.332',
    'reserveBps': 0,
    'priceUsd1': price,
  },
  'graduatedAt': stage == 'graduated' ? '2027-01-24T07:00:00.000Z' : null,
};

Map<String, Object?> l2PageJson(
  List<Map<String, Object?>> rows, {
  String? nextCursor,
}) => <String, Object?>{
  'instances': rows,
  'nextCursor': nextCursor,
  'contractVersion': '2.0',
};

Map<String, Object?> l2ViewerJson({
  int held = 0,
  bool member = false,
  bool eligibleNow = false,
  String bought = '0',
  String net = '0',
}) => <String, Object?>{
  'walletId': l2WalletId,
  'nft': <String, Object?>{
    'mintedTokenId': held > 0 ? '1' : null,
    'held': held,
  },
  'snapshot': <String, Object?>{'member': member, 'eligibleNow': eligibleNow},
  'curve': <String, Object?>{
    'bought': bought,
    'sold': '0',
    'net': net,
    'cumulativeBought': bought,
    'remainingQuota': '5000000',
    'usd1Spent': '0',
    'usd1Received': '0',
    'taxUsd1': '0',
  },
};

/// [legacy]: a v2-generation (price-protected) execution; otherwise a v3 one,
/// whose three protection figures are `null` (loop-api decision 0122).
Map<String, Object?> l2BuybackRecordJson({bool legacy = true}) =>
    <String, Object?>{
      'buybackId': 'bb-1',
      'outcome': 'executed',
      'reasonCode': null,
      'usd1Spent': '100',
      'memeDelivered': '150000',
      'minMemeOut': legacy ? '148500' : null,
      'referencePriceUsd1': legacy ? '0.00066' : null,
      'spotPriceUsd1': legacy ? '0.00066' : null,
      'executedAt': '2027-01-24T08:00:00.000Z',
      'transactionHash': l2Hash,
      'blockNumber': '1400',
    };

/// The keeper's newest attempt (loop-api decision 0121); `null` = never.
/// Decision 0146: [lastResult] / [reasonCode] / [nextEligibleAt] vary it
/// for the keeper line (running, held, failed).
Map<String, Object?> l2KeeperJson({
  String lastResult = 'rejected',
  String? reasonCode = 'LAUNCH2_BUYBACK_PRINCIPAL_INSUFFICIENT',
  String? nextEligibleAt = '2027-01-24T08:00:45.000Z',
}) => <String, Object?>{
  'lastAttemptAt': '2027-01-24T08:00:15.000Z',
  'lastResult': lastResult,
  'reasonCode': reasonCode,
  'nextEligibleAt': nextEligibleAt,
};

Map<String, Object?> l2BuybackSummaryJson({
  bool latest = false,
  bool legacy = true,
  Map<String, Object?>? keeper,
}) => <String, Object?>{
  'recipient': '0x28816c4c4792467390c90e5b426f198570e29307',
  'paused': false,
  'executedCount': latest ? '1' : '0',
  'totalUsd1': latest ? '100' : '0',
  'totalMeme': latest ? '150000' : '0',
  'lastExecutedAt': latest ? '2027-01-24T08:00:00.000Z' : null,
  'escrowRecordedUsd1': '200',
  'escrowAvailableUsd1': latest ? '100' : '200',
  'latest': latest ? l2BuybackRecordJson(legacy: legacy) : null,
  // loop-api decision 0121: optional in the schema, always answered.
  'keeper': keeper,
};

Map<String, Object?> l2DetailJson({
  String instanceId = l2InstanceA,
  String stage = 'nft_sale',
  Map<String, Object?>? viewer,
  bool noViewer = false,
  bool owner = false,
  String? holdReason,
  bool noNextChange = false,
  String? cutoffBlock,
  Map<String, Object?>? publication,
  bool omitPublication = true,
  List<Map<String, Object?>> trades = const <Map<String, Object?>>[],
  int soldBps = 0,
  bool openedWithoutHolders = false,
  Map<String, Object?>? keeper,
}) {
  // loop-api decision 0122: a v3 sale with no NFT minted opens the public
  // round without a list.
  final opened = openedWithoutHolders;
  final published =
      !opened &&
      (stage == 'priority' || stage == 'public' || stage == 'graduated');
  return <String, Object?>{
    'instance': <String, Object?>{
      ...l2RowJson(
        instanceId: instanceId,
        stage: stage,
        holdReason: holdReason,
        noNextChange: noNextChange,
        soldBps: soldBps,
      ),
      'viewerIsProjectOwner': owner,
      'projectOwnerAddress': '0x7777777777777777777777777777777777777777',
      'configVersion': 1,
      'configHash': l2Hash,
      'buybackRecipient': '0x28816c4c4792467390c90e5b426f198570e29307',
      'template': <String, Object?>{
        'templateVersion': 'hooks_launch_v1',
        'memeTotalSupply': '1000000000',
        'curveSaleSupply': '800000000',
        'initialLiquiditySupply': '200000000',
        'graduationReserveUsd1': '133333.332',
        'curveBuyTaxBps': 1000,
        'curveSellTaxBps': 1000,
        'officialPoolTaxBps': 200,
        'lpFee': 2500,
        'tickSpacing': 60,
        'perAddressCap': '5000000',
        'perAddressCapBps': 50,
        'nftPriceUsd1': '100',
        'nftSaleSeconds': 604800,
        'earlyRoundSeconds': 3600,
        'buybackOrderUsd1': '100',
        'buybackMinIntervalSeconds': 10,
      },
      'contracts': <String, Object?>{
        'factory': '0x4444444444444444444444444444444444444444',
        'meme': l2Meme,
        'hook': l2Hook,
        'nft': l2Nft,
        'curve': l2Curve,
        'gate': '0x5555555555555555555555555555555555555555',
        'escrow': '0x6666666666666666666666666666666666666666',
        'snapshots': '0x7777777777777777777777777777777777777777',
        'graduationAdapter': '0x8888888888888888888888888888888888888888',
        'buybackAdapter': '0x9999999999999999999999999999999999999999',
        'priceRecorder': '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'buybackExecutor': '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      'snapshot': <String, Object?>{
        'status': opened
            ? 'opened_without_holders'
            : published
            ? 'published'
            : 'pending',
        'verification': published ? 'verified' : null,
        'root': published ? l2Hash : null,
        'dataHash': published ? l2Hash : null,
        'cutoffBlockNumber': cutoffBlock ?? (published ? '1234' : null),
        'cutoffBlockHash': published ? l2Hash : null,
        'publishedAt': published ? '2027-01-23T07:05:00.000Z' : null,
        'earlyRoundEndsAt': opened
            ? '2027-01-23T07:01:00.000Z'
            : published
            ? '2027-01-23T08:05:00.000Z'
            : null,
        'memberCount': published ? 160 : null,
        'signers': published
            ? <String>['0xcccccccccccccccccccccccccccccccccccccccc']
            : null,
        if (!omitPublication) 'publication': publication,
        // loop-api decision 0120: required; set only for the closed stage.
        'closure': stage == 'closed_no_holders'
            ? <String, Object?>{
                'reason': 'no_holders',
                'cutoffBlock': cutoffBlock ?? '1234',
                'closedAt': '2027-01-23T07:02:00.000Z',
              }
            : null,
        // loop-api decision 0122: optional in the schema, always answered.
        'openedWithoutHolders': opened
            ? <String, Object?>{
                'openedAt': '2027-01-23T07:01:00.000Z',
                'blockNumber': '1240',
                'transactionHash': l2Hash,
              }
            : null,
      },
      'graduation': stage == 'graduated'
          ? <String, Object?>{
              'graduatedAt': '2027-01-24T07:00:00.000Z',
              'officialPoolId': l2PoolId,
              'hookAddress': l2Hook,
              'lpFee': 2500,
              'tickSpacing': 60,
              'officialPoolTaxBps': 200,
              'transactionHash': l2Hash,
            }
          : null,
      'buyback': l2BuybackSummaryJson(
        latest: stage == 'graduated',
        keeper: keeper,
      ),
      'recentTrades': trades,
      'viewer': noViewer ? null : (viewer ?? l2ViewerJson()),
      'projectedAt': _iso(l2Now),
    },
    'contractVersion': '2.0',
  };
}

Map<String, Object?> l2TradeJson() => <String, Object?>{
  'tradeId': 't-1',
  'side': 'buy',
  'traderAddress': l2WalletAddress,
  'memeAmount': '1125000.5',
  'usd1Gross': '50',
  'usd1Net': '45',
  'taxUsd1': '5',
  'tradedAt': '2027-01-23T07:10:00.000Z',
  'transactionHash': l2Hash,
  'blockNumber': '1300',
};

Map<String, Object?> l2QuoteJson({
  String side = 'buy',
  String stage = 'priority',
  String requested = '50',
  bool exceedsMax = false,
  String amountIn = '50',
  String maxIn = '185185.18',
  String expectedOut = '1125000.5',
  String limitedBy = 'quota',
  bool required = true,
  bool? eligible = true,
  String? eligibilityReason,
  DateTime? deadline,
}) => <String, Object?>{
  'quote': <String, Object?>{
    'instanceId': l2InstanceA,
    'walletId': l2WalletId,
    'side': side,
    'stage': stage,
    'requestedAmount': requested,
    'exceedsMax': exceedsMax,
    'amountIn': amountIn,
    'maxIn': maxIn,
    'expectedOut': expectedOut,
    'minOut': '1113750.495',
    'slippageBps': 100,
    'taxUsd1': '5',
    'taxBps': 1000,
    'refundUsd1': '0',
    'priceBeforeUsd1': '0.00004166666625',
    'priceAfterUsd1': '0.0000435',
    'max': <String, Object?>{
      'amountIn': maxIn,
      'amountOut': '5000000',
      'limitedBy': limitedBy,
    },
    'quota': <String, Object?>{
      'capMeme': '5000000',
      'usedMeme': '0',
      'remainingMeme': '5000000',
    },
    'inventory': <String, Object?>{
      'saleSupply': '800000000',
      'soldSupply': '0',
      'remainingMeme': '800000000',
    },
    'eligibility': <String, Object?>{
      'required': required,
      'eligible': eligible,
      'reasonCode': eligibilityReason,
    },
    'deadline': _iso(deadline ?? l2Now.add(const Duration(minutes: 1))),
    'quotedAt': _iso(l2Now),
    'basis': <String, Object?>{'blockNumber': '1301', 'blockHash': l2Hash},
  },
  'contractVersion': '2.0',
};

Map<String, Object?> _tx({
  required String to,
  required String data,
  required String nonce,
}) => <String, Object?>{
  'chainId': 97,
  'to': to,
  'data': data,
  'value': '0x0',
  'from': l2WalletAddress,
  'gas': '0x5208',
  'nonce': nonce,
  'type': 'legacy',
  'gasPrice': '0x3b9aca00',
  'maxFeePerGas': null,
  'maxPriorityFeePerGas': null,
};

Map<String, Object?> l2IntentJson({
  String kind = 'nft_mint',
  bool approval = true,
  String? contract,
}) {
  final target = contract ?? (kind == 'nft_mint' ? l2Nft : l2Curve);
  const approveData =
      '0x095ea7b30000000000000000000000001111111111111111111111111111111111111111';
  return <String, Object?>{
    'launch2Intent': <String, Object?>{
      'intentId': l2IntentId,
      'kind': kind,
      'state': 'prepared',
      'instanceId': l2InstanceA,
      'walletId': l2WalletId,
      'chainId': 'eip155:97',
      'chainReference': 97,
      'contractAddress': target,
      'amountIn': kind == 'nft_mint' ? '100' : '50',
      'expectedOut': kind == 'nft_mint' ? '0.000000000000000001' : '1125000.5',
      'minOut': kind == 'nft_mint' ? '0.000000000000000001' : '1113750.495',
      'taxUsd1': kind == 'nft_mint' ? '0' : '5',
      'refundUsd1': '0',
      'deadline': _iso(l2Now.add(const Duration(minutes: 5))),
      'expiresAt': _iso(l2Now.add(const Duration(minutes: 5))),
      'createdAt': _iso(l2Now),
      'calldata': <String, Object?>{
        'to': target,
        'data': '0x1249c58b',
        'value': '0',
      },
      'unsignedTransaction': _tx(
        to: target,
        data: '0x1249c58b',
        nonce: approval ? '0x9' : '0x8',
      ),
      'approval': approval
          ? <String, Object?>{
              'token': l2Usd1,
              'spender': target,
              'amount': kind == 'nft_mint' ? '100' : '50',
              'calldata': <String, Object?>{
                'to': l2Usd1,
                'data': approveData,
                'value': '0',
              },
              'unsignedTransaction': _tx(
                to: l2Usd1,
                data: approveData,
                nonce: '0x8',
              ),
            }
          : null,
      'payloadDigest':
          '0f00000000000000000000000000000000000000000000000000000000000001',
      'snapshotBlockNumber': '1200',
      'snapshotBlockHash': l2Hash,
      'simulation': <String, Object?>{
        'status': approval ? 'unavailable' : 'passed',
        'reasonCode': approval ? 'LAUNCH2_APPROVAL_REQUIRED' : null,
      },
      'policy': <String, Object?>{
        'configVersion': 'bscWriteCanaryV1',
        'canaryMaxUsd': '1000',
        'valueUsd': '100',
        'priceSource': 'usd1_par',
      },
      'signing': <String, Object?>{
        'mode': 'device_eth_send_transaction',
        'allowed': true,
        'reasonCode': null,
      },
    },
    'contractVersion': '2.0',
  };
}

Map<String, Object?> l2BuybacksJson({
  String? blocked = 'BUYBACK_PRINCIPAL_INSUFFICIENT',
  bool liveUnavailable = false,
  bool legacy = true,
  Map<String, Object?>? keeper,
}) => <String, Object?>{
  'instanceId': l2InstanceA,
  'summary': l2BuybackSummaryJson(latest: true, legacy: legacy, keeper: keeper),
  'live': liveUnavailable
      ? null
      : <String, Object?>{
          'paused': false,
          'lastSuccessfulAt': '2027-01-24T08:00:00.000Z',
          'escrowRecordedUsd1': '200',
          'escrowSpentUsd1': '100',
          'escrowAvailableUsd1': '100',
          'nextOrderUsd1': '100',
          'nextOrderBlockedReason': blocked,
        },
  'liveUnavailable': liveUnavailable
      ? <String, Object?>{'reasonCode': 'LAUNCH2_CHAIN_READ_FAILED'}
      : null,
  'buybacks': <Object?>[l2BuybackRecordJson(legacy: legacy)],
  'nextCursor': null,
  'contractVersion': '2.0',
};

Map<String, Object?> l2PositionsJson() => <String, Object?>{
  'positions': <Object?>[
    <String, Object?>{
      'instanceId': l2InstanceA,
      'name': 'Frog Launch',
      'ticker': 'FROG',
      'logoUrl': null,
      'memeAddress': l2Meme,
      'stage': 'priority',
      'walletId': l2WalletId,
      'nft': <String, Object?>{'mintedTokenId': '1', 'held': 1},
      'snapshotMember': true,
      'curve': <String, Object?>{
        'bought': '1125000.5',
        'sold': '0',
        'net': '1125000.5',
        'cumulativeBought': '1125000.5',
        'remainingQuota': '3874999.5',
        'usd1Spent': '50',
        'usd1Received': '0',
        'taxUsd1': '5',
      },
      'lastActivityAt': '2027-01-23T07:10:00.000Z',
    },
  ],
  'contractVersion': '2.0',
};

String? _noMedia(String mediaId) => null;

Launch2InstancePage l2Page(List<Map<String, Object?>> rows, {String? next}) =>
    LoopV2Launch2Codec.page(
      l2PageJson(rows, nextCursor: next),
      mediaUrl: _noMedia,
    );

Launch2InstanceDetail l2Detail({
  String stage = 'nft_sale',
  Map<String, Object?>? viewer,
  bool noViewer = false,
  bool owner = false,
  String? holdReason,
  bool noNextChange = false,
  String? cutoffBlock,
  List<Map<String, Object?>> trades = const <Map<String, Object?>>[],
  bool openedWithoutHolders = false,
  Map<String, Object?>? keeper,
}) => LoopV2Launch2Codec.detail(
  l2DetailJson(
    openedWithoutHolders: openedWithoutHolders,
    keeper: keeper,
    stage: stage,
    viewer: viewer,
    noViewer: noViewer,
    owner: owner,
    holdReason: holdReason,
    noNextChange: noNextChange,
    cutoffBlock: cutoffBlock,
    trades: trades,
  ),
  mediaUrl: _noMedia,
);

Launch2Quote l2Quote({
  bool exceedsMax = false,
  String amountIn = '50',
  String maxIn = '185185.18',
  bool? eligible = true,
  DateTime? deadline,
  String requested = '50',
}) => LoopV2Launch2Codec.quote(
  l2QuoteJson(
    exceedsMax: exceedsMax,
    amountIn: amountIn,
    maxIn: maxIn,
    eligible: eligible,
    deadline: deadline,
    requested: requested,
  ),
  instanceId: l2InstanceA,
  side: Launch2Side.buy,
  walletId: l2WalletId,
);

Launch2Intent l2Intent({String kind = 'nft_mint', bool approval = true}) =>
    LoopV2Launch2Codec.intent(l2IntentJson(kind: kind, approval: approval));

Launch2BuybackPage l2Buybacks({
  String? blocked = 'BUYBACK_PRINCIPAL_INSUFFICIENT',
  bool legacy = true,
  Map<String, Object?>? keeper,
}) => LoopV2Launch2Codec.buybacks(
  l2BuybacksJson(blocked: blocked, legacy: legacy, keeper: keeper),
  instanceId: l2InstanceA,
);

Launch2Positions l2Positions() =>
    LoopV2Launch2Codec.positions(l2PositionsJson(), mediaUrl: _noMedia);
