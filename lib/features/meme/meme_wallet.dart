import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

/// The wallet a MEME write is prepared for: the account's active wallet, read
/// through the wallet directory and never guessed from an address.
@immutable
final class MemeActiveWallet {
  const MemeActiveWallet({
    required this.walletId,
    required this.address,
    required this.loading,
  });

  final String? walletId;

  /// The wallet's address, which the signing exit compares with the
  /// transaction's `from`.
  final String? address;

  /// The directory has not answered yet.
  final bool loading;
}

/// Watches the wallet directory, starting its read when nothing asked yet.
/// Call it from `build` so the page rebuilds when the directory answers.
MemeActiveWallet memeActiveWallet(WidgetRef ref) {
  final state = ref.watch(walletDirectoryControllerProvider);
  if (state.phase == LoopChainViewPhase.loading && state.value == null) {
    scheduleMicrotask(() {
      unawaited(ref.read(walletDirectoryControllerProvider.notifier).load());
    });
  }
  return _project(state);
}

/// The same answer read once, for a callback outside `build`.
MemeActiveWallet memeReadActiveWallet(WidgetRef ref) =>
    _project(ref.read(walletDirectoryControllerProvider));

MemeActiveWallet _project(LoopChainResourceState<LoopWalletDirectory> state) {
  final directory = state.value;
  final walletId = directory?.activeWalletId;
  String? address;
  for (final wallet in directory?.wallets ?? const <LoopWalletAccount>[]) {
    if (wallet.walletId == walletId) address = wallet.address;
  }
  return MemeActiveWallet(
    walletId: walletId,
    address: address,
    loading: state.phase == LoopChainViewPhase.loading,
  );
}
