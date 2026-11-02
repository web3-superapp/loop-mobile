// S339 · decision 0267: wire fixtures for 发送 LOOP 项目 NFT. Every value
// here is 测试专用; models are produced by the real codec.
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/nft_send.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';

import 'launch2_fixtures.dart';
import 's5_fixtures.dart';
import 's6_fixtures.dart';

const s339Chain = 'eip155:97';
const s339TokenId = '7';

String _pad(String hex) => hex.padLeft(64, '0');

/// `safeTransferFrom(s6From, s6Recipient, tokenId)`.
String s339TransferData({String tokenId = s339TokenId}) =>
    '0x42842e0e'
    '${_pad(s6From.substring(2))}'
    '${_pad(s6Recipient.substring(2))}'
    '${_pad(BigInt.parse(tokenId).toRadixString(16))}';

final SendNftTarget s339Target = SendNftTarget(
  walletId: s5WalletId,
  chainId: s339Chain,
  contractAddress: l2Nft,
  tokenId: BigInt.parse(s339TokenId),
  ticker: 'FROG',
  projectName: 'Frog Launch',
  instanceId: l2InstanceA,
);

/// One `send_nft` intent resource, as docs/53 §二 describes it.
Map<String, Object?> s339IntentBody({
  String state = 'awaiting_signature',
  String simulationStatus = 'passed',
  bool signingAllowed = true,
  Object? signingReason,
  String expiresAt = '2026-09-09T13:37:30.323Z',
  bool nftBlock = true,
  bool includeAsset = false,
  String? argsTokenId = s339TokenId,
  String? nftTokenId = s339TokenId,
  String data = '',
  String to = l2Nft,
  String recipientBasis = 'indexed_erc20_transfers',
  bool includeBalance = true,
  Map<String, Object?>? extraReview,
}) => <String, Object?>{
  'intentId': s6IntentId,
  'kind': 'send_nft',
  'state': state,
  'walletId': s5WalletId,
  'chainId': s339Chain,
  'review': <String, Object?>{
    'kind': 'send_nft',
    if (includeAsset)
      'asset': <String, Object?>{
        'assetId': '$s339Chain:erc721:$l2Nft',
        'address': l2Nft,
        'symbol': 'FROG',
        'decimals': 0,
      },
    'recipient': <String, Object?>{...s6Recipient_(), 'basis': recipientBasis},
    'decodedCall': <String, Object?>{
      'functionName': 'safeTransferFrom',
      'selector': '0x42842e0e',
      'args': <String, Object?>{
        'from': s6From,
        'to': s6Recipient,
        'tokenId': ?argsTokenId,
      },
    },
    'fee': s6Fee(),
    if (includeBalance) 'balance': s6Balance(),
    if (nftBlock)
      'nft': <String, Object?>{
        'contractAddress': l2Nft,
        'tokenId': ?nftTokenId,
        'projectName': 'Frog Launch',
      },
    ...?extraReview,
  },
  'reviewSha256': 'd' * 64,
  'factsObservedAt': '2026-09-09T13:35:30.323Z',
  'expiresAt': expiresAt,
  'simulation': <String, Object?>{
    'status': simulationStatus,
    'source': 'rpc_call',
    'observedAt': '2026-09-09T13:35:28.987Z',
    'reasonCode': null,
  },
  'policy': <String, Object?>{
    'configVersion': 'bscWriteCanaryV1',
    'canaryMaxUsd': '20',
    'exposureBasis': 'none',
    'exposureRaw': null,
    'exposureBlockNumber': null,
    'valueUsd': null,
    'priceSource': null,
    'priceFetchedAt': null,
  },
  'signing': <String, Object?>{
    'mode': 'device_eth_send_transaction',
    'allowed': signingAllowed,
    'reasonCode': signingReason,
  },
  'unsignedTransaction': <String, Object?>{
    'chainId': 97,
    'from': s6From,
    'to': to,
    'data': data.isEmpty ? s339TransferData() : data,
    'value': '0x0',
    'gas': '0x1d4c0',
    'nonce': '0x12',
    'type': 'eip1559',
    'maxFeePerGas': '0x2faf080',
    'maxPriorityFeePerGas': '0x2faf080',
    'gasPrice': null,
  },
  'authorizationPayload': null,
  'result': <String, Object?>{
    'transactionHash': null,
    'providerActionId': null,
    'reasonCode': null,
    'receipt': null,
  },
  'version': '1',
  'createdAt': '2026-09-09T13:35:30.323Z',
  'updatedAt': '2026-09-09T13:35:30.323Z',
  'contractVersion': '2.0',
};

LoopWalletIntent s339Intent({
  String state = 'awaiting_signature',
  String simulationStatus = 'passed',
  bool signingAllowed = true,
}) => LoopV2IntentCodec.intent(
  s339IntentBody(
    state: state,
    simulationStatus: simulationStatus,
    signingAllowed: signingAllowed,
  ),
);
