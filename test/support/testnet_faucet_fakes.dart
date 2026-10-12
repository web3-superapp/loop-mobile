import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_models.dart';

const String faucetBnbHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const String faucetUsd1Hash =
    '0x2222222222222222222222222222222222222222222222222222222222222222';

TestnetFaucetStatus faucetStatus({
  required String walletId,
  String address = '0xabcdefabcdefabcdefabcdefabcdefabcdef1234',
  bool available = true,
  DateTime? nextAvailableAt,
}) => TestnetFaucetStatus(
  walletId: walletId,
  address: address,
  bnbAmount: Decimal.parse('0.02'),
  usd1Amount: Decimal.parse('500'),
  cooldownSeconds: 86400,
  available: available,
  nextAvailableAt: available ? null : nextAvailableAt,
  lastGrant: null,
);

TestnetFaucetGranted faucetGranted({
  required String walletId,
  required DateTime grantedAt,
}) => TestnetFaucetGranted(
  walletId: walletId,
  address: '0xabcdefabcdefabcdefabcdefabcdefabcdef1234',
  bnb: TestnetFaucetTransfer(
    amount: Decimal.parse('0.02'),
    transactionHash: faucetBnbHash,
  ),
  usd1: TestnetFaucetTransfer(
    amount: Decimal.parse('500'),
    transactionHash: faucetUsd1Hash,
  ),
  grantedAt: grantedAt,
  nextAvailableAt: grantedAt.add(const Duration(days: 1)),
);

/// A faucet that answers what the test hands it. [claimGate], when set,
/// holds the claim until the test completes it.
final class FakeTestnetFaucetGateway implements TestnetFaucetGateway {
  FakeTestnetFaucetGateway({
    required this.status,
    this.claimResult,
    this.claimFailure,
    this.statusFailure,
  });

  TestnetFaucetStatus status;
  TestnetFaucetClaimResult? claimResult;
  LoopChainException? claimFailure;
  LoopChainException? statusFailure;
  Completer<void>? claimGate;

  final List<String> statusReads = <String>[];
  final List<String> claims = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<TestnetFaucetStatus> loadStatus({required String walletId}) async {
    statusReads.add(walletId);
    final failure = statusFailure;
    if (failure != null) throw failure;
    return status;
  }

  @override
  Future<TestnetFaucetClaimResult> claim({required String walletId}) async {
    claims.add(walletId);
    final gate = claimGate;
    if (gate != null) await gate.future;
    final failure = claimFailure;
    if (failure != null) throw failure;
    return claimResult!;
  }
}
