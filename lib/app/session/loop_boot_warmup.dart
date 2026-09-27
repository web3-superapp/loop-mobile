import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

/// Whether Community's first read may start before the landing is decided.
///
/// Decision 0098. A signed-in cold start waits on the launch page for
/// `GET /v2/profile` (F1), and Community only asked for `GET /v2/community/home`
/// once its page was drawn — two round trips back to back although the second
/// needs nothing from the first. It is due as soon as the account is signed in
/// and the community gate is open, unless the profile has already answered
/// that the account is still in its opening sequence.
final loopCommunityWarmupDueProvider = Provider<bool>((ref) {
  if (ref.watch(loopBootstrapPrincipalKeyProvider) == null) return false;
  final landing = ref.watch(
    loopProfileLandingProvider.select((state) => state.landing),
  );
  if (landing == LoopProfileLanding.loopIdSetup) return false;
  final mode = ref.watch(
    communityGatewayProvider.select((gateway) => gateway.mode),
  );
  if (mode != CommunityGatewayMode.production) return false;
  return !communityCapabilityBlocks(
    mode,
    ref.watch(loopCapabilityProvider(LoopV2CapabilityId.community)),
  );
});

/// Whether the wallet tab's first reads may start before the tab is opened.
///
/// Decision 0098. The wallet page reads `GET /v2/wallets`, and only then that
/// wallet's balances: the second read needs the first one's `activeWalletId`,
/// so on the page they are two round trips back to back. Nothing about them
/// depends on Community, though, so they can run while Community is on screen
/// instead of after the owner taps 钱包.
///
/// It is due only when the page itself would read: the account is signed in
/// and `GET /v2/profile` answered active, the wallet adapter is the production
/// one, and both capability gates the page applies are open. A closed or
/// unobserved gate, a pending account and the Development Preview never warm
/// anything, so no request is sent that the page would not have sent.
final loopWalletWarmupDueProvider = Provider<bool>((ref) {
  if (ref.watch(loopBootstrapPrincipalKeyProvider) == null) return false;
  final landing = ref.watch(
    loopProfileLandingProvider.select((state) => state.landing),
  );
  if (landing != LoopProfileLanding.community) return false;
  final mode = ref.watch(
    walletReadGatewayProvider.select((gateway) => gateway.mode),
  );
  if (mode != LoopChainGatewayMode.production) return false;
  return !walletCapabilityBlocks(
    mode,
    ref.watch(loopCapabilityProvider(LoopV2CapabilityId.walletRead)),
    ref.watch(loopCapabilityProvider(LoopV2CapabilityId.bscRead)),
  );
});

/// Starts the first-screen reads of Community and Wallet once per account, as
/// soon as each is due (decision 0098).
///
/// The reads go through the same controllers the pages watch, so a page finds
/// either the answer or the read still in flight and joins it; nothing is read
/// twice. The warm-up holds a controller only while its read runs; afterwards
/// the controller's own retention (decision 0095, five minutes) decides how
/// long the answer stays. A read that failed with nothing to show is dropped,
/// so the page opens on its own fresh read rather than on a failure it never
/// asked for.
final class LoopBootWarmup {
  LoopBootWarmup._(this._ref);

  final Ref _ref;
  var _communityStarted = false;
  var _walletStarted = false;
  var _disposed = false;

  /// Whether this account's Community read has been started here.
  bool get communityStarted => _communityStarted;

  /// Whether this account's wallet reads have been started here.
  bool get walletStarted => _walletStarted;

  void _onCommunityDue(bool due) {
    if (!due || _communityStarted || _disposed) return;
    _communityStarted = true;
    // Never inside another provider's build: the trigger may fire while the
    // session, the landing or the capability document is being published.
    scheduleMicrotask(() => unawaited(_warmCommunity()));
  }

  void _onWalletDue(bool due) {
    if (!due || _walletStarted || _disposed) return;
    _walletStarted = true;
    scheduleMicrotask(() => unawaited(_warmWallet()));
  }

  Future<void> _warmCommunity() async {
    if (_disposed) return;
    final home = _ref.listen(communityHomeControllerProvider, (_, _) {});
    try {
      await _ref.read(communityHomeControllerProvider.notifier).load();
      if (_disposed) return;
      if (_ref.read(communityHomeControllerProvider).value == null) {
        _ref.invalidate(communityHomeControllerProvider);
      }
    } finally {
      home.close();
    }
  }

  Future<void> _warmWallet() async {
    if (_disposed) return;
    final directory = _ref.listen(walletDirectoryControllerProvider, (_, _) {});
    String? walletId;
    try {
      await _ref.read(walletDirectoryControllerProvider.notifier).load();
      if (_disposed) return;
      final value = _ref.read(walletDirectoryControllerProvider).value;
      if (value == null) {
        _ref.invalidate(walletDirectoryControllerProvider);
        return;
      }
      walletId = value.activeWalletId;
    } finally {
      directory.close();
    }
    if (walletId == null || _disposed) return;
    final balances = _ref.listen(
      walletBalancesControllerProvider(walletId),
      (_, _) {},
    );
    try {
      await _ref
          .read(walletBalancesControllerProvider(walletId).notifier)
          .load();
      if (_disposed) return;
      if (_ref.read(walletBalancesControllerProvider(walletId)).value == null) {
        _ref.invalidate(walletBalancesControllerProvider(walletId));
      }
    } finally {
      balances.close();
    }
  }

  void _dispose() => _disposed = true;
}

/// One warm-up per signed-in account. The application root keeps it listened
/// so a new account gets its own.
final loopBootWarmupProvider = Provider<LoopBootWarmup>((ref) {
  ref.watch(loopBootstrapPrincipalKeyProvider);
  final warmup = LoopBootWarmup._(ref);
  ref.onDispose(warmup._dispose);
  ref.listen<bool>(
    loopCommunityWarmupDueProvider,
    (previous, next) => warmup._onCommunityDue(next),
    fireImmediately: true,
  );
  ref.listen<bool>(
    loopWalletWarmupDueProvider,
    (previous, next) => warmup._onWalletDue(next),
    fireImmediately: true,
  );
  return warmup;
});
