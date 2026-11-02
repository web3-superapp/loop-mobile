import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';

// ---------------------------------------------------------------------------
// S339 · decision 0267 · 发送 LOOP 项目 NFT (docs/53)
// ---------------------------------------------------------------------------

/// The one project NFT a send names, as the NFT page read it.
///
/// It holds only identities and display text. Ownership is the server's to
/// check (`ownerOf` at prepare), and what is signed is the server's intent.
@immutable
final class SendNftTarget {
  const SendNftTarget({
    required this.walletId,
    required this.chainId,
    required this.contractAddress,
    required this.tokenId,
    required this.ticker,
    this.projectName,
    this.instanceId,
    this.nftImageUrl,
    this.logoUrl,
  });

  /// The wallet holding the NFT (the Launch viewer's wallet).
  final String walletId;

  /// The Launch chain the NFT contract lives on (CAIP-2).
  final String chainId;

  /// The project NFT contract, lower-case.
  final String contractAddress;
  final BigInt tokenId;
  final String ticker;
  final String? projectName;

  /// The Launch instance, re-read once a send is submitted.
  final String? instanceId;
  final String? nftImageUrl;
  final String? logoUrl;

  /// The exact decimal string the request carries.
  String get tokenIdText => tokenId.toString();

  /// 「T #id」.
  String get label => '$ticker #$tokenId';

  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _address = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// A target only when every identity a request needs is well-formed: a
  /// canonical wallet id, a known chain, an NFT contract address and a
  /// non-negative token id. Anything else draws no 发送.
  static SendNftTarget? tryCreate({
    required String? walletId,
    required String chainId,
    required String? contractAddress,
    required BigInt? tokenId,
    required String ticker,
    String? projectName,
    String? instanceId,
    String? nftImageUrl,
    String? logoUrl,
  }) {
    if (walletId == null || !_uuid.hasMatch(walletId)) return null;
    if (!loopKnownChainIds.contains(chainId)) return null;
    if (contractAddress == null || !_address.hasMatch(contractAddress)) {
      return null;
    }
    if (tokenId == null || tokenId.isNegative) return null;
    return SendNftTarget(
      walletId: walletId,
      chainId: chainId,
      contractAddress: contractAddress.toLowerCase(),
      tokenId: tokenId,
      ticker: ticker,
      projectName: projectName,
      instanceId: instanceId,
      nftImageUrl: nftImageUrl,
      logoUrl: logoUrl,
    );
  }
}

/// The toast an NFT send entry shows while the server's switch is off
/// (`503 NFT_SEND_DISABLED`).
const String nftSendDisabledText = '暂不支持发送 NFT';

/// The server's reason codes for a refused NFT send (docs/53 §二).
abstract final class NftSendReason {
  static const notOwned = 'NFT_NOT_OWNED';
  static const contractUnsupported = 'NFT_CONTRACT_UNSUPPORTED';
  static const recipientRejects = 'NFT_RECIPIENT_REJECTS';
  static const recipientSelf = 'RECIPIENT_SELF';
  static const disabled = 'NFT_SEND_DISABLED';
}

/// True when [failure] is the server's closed NFT send switch.
bool nftSendIsDisabled(LoopChainException? failure) =>
    failure != null && failure.reasonCode == NftSendReason.disabled;

/// The short line for a refused or failed NFT send; `null` when the failure
/// is not one of the NFT send's own and the page's shared state block says it.
String? nftSendFailureText(LoopChainException failure) {
  switch (failure.reasonCode) {
    case NftSendReason.notOwned:
      return '这枚 NFT 已不在你的钱包';
    case NftSendReason.contractUnsupported:
      return '暂不支持发送这个 NFT';
    case NftSendReason.recipientRejects:
      return '收款地址不接收这枚 NFT';
    case NftSendReason.recipientSelf:
      return '不能发送给自己';
    case NftSendReason.disabled:
      return nftSendDisabledText;
  }
  return switch (failure.kind) {
    LoopChainFailureKind.insufficientBalance =>
      '$loopLaunchNativeSymbolText 手续费不足，充值后再试',
    LoopChainFailureKind.idempotencyConflict => '这笔发送已提交过，请查看最新状态',
    _ => null,
  };
}

/// Whether a retry could change the answer. An ownership, contract,
/// recipient or switch refusal is the server's answer, not a fault.
bool nftSendFailureRetryable(LoopChainException failure) =>
    switch (failure.reasonCode) {
      NftSendReason.notOwned ||
      NftSendReason.contractUnsupported ||
      NftSendReason.recipientRejects ||
      NftSendReason.recipientSelf ||
      NftSendReason.disabled => false,
      _ => failure.kind != LoopChainFailureKind.idempotencyConflict,
    };

/// Set once this session has seen `503 NFT_SEND_DISABLED`: every NFT send
/// entry then answers with [nftSendDisabledText] instead of opening a flow
/// the server will refuse. A successful prepare clears it.
class NftSendDisabled extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final nftSendDisabledProvider = NotifierProvider<NftSendDisabled, bool>(
  NftSendDisabled.new,
);

/// Re-reads the Launch holdings an NFT send changes (S339 · decision 0267):
/// the wallet's `me/positions` (钱包 NFT tab, 个人主页 NFT tab) and the
/// instance the medal page reads.
///
/// Only a read somebody is showing is re-read: an unwatched read is created
/// fresh by the next page that asks for it.
void refreshLaunch2Holdings(WidgetRef ref, SendNftTarget? target) {
  if (ref.exists(launch2PositionsControllerProvider)) {
    unawaited(ref.read(launch2PositionsControllerProvider.notifier).reload());
  }
  final instanceId = target?.instanceId;
  if (instanceId == null) return;
  final instance = launch2InstanceControllerProvider(instanceId);
  if (ref.exists(instance)) unawaited(ref.read(instance.notifier).reload());
}
