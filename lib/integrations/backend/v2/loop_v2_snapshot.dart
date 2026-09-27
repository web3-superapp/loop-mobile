import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

/// One signed-in account's view of the snapshot store (decision 0095).
///
/// It records the body of every cold-start read this account receives, and
/// on the first open of a page in this run it decodes the stored body back
/// through the same strict decoder a live answer uses. A resource that has
/// been restored once, or answered live once, is never restored again in this
/// run: from then on the read controller's own memory is the only fallback,
/// so an invalidated read (a watchlist edit, a new wallet) never reopens on
/// an answer older than the one it just replaced.
final class LoopV2SnapshotSession implements LoopSnapshotRestorer {
  LoopV2SnapshotSession({
    required this._store,
    required String principal,
    required this._clock,
  }) : accountKey = loopSnapshotAccountKey(principal) {
    // Binding removes whatever another account left behind.
    _store.bind(accountKey);
  }

  final LoopSnapshotStore _store;
  final DateTime Function() _clock;

  /// The fingerprint the answers are filed under.
  final String accountKey;

  final Set<String> _spent = <String>{};

  /// The [LoopV2SnapshotTap] handed to the four transports.
  void record(String resource, Object? body) {
    if (!LoopSnapshotResource.isKnown(resource)) return;
    _spent.add(resource);
    try {
      _store.write(
        LoopSnapshotRecord(
          accountKey: accountKey,
          resource: resource,
          body: body,
          observedAt: _clock().toUtc(),
        ),
      );
    } on Object {
      // Storing is a convenience for the next cold start. It never turns the
      // live answer the caller is about to receive into a failure.
    }
  }

  @override
  LoopRestoredSnapshot? restore(String resource) {
    if (!_spent.add(resource)) return null;
    final record = _store.read(accountKey, resource);
    if (record == null) return null;
    // Older than the window, it is not drawn at all: the page loads as a
    // skeleton rather than presenting a stale answer as the present.
    if (record.ageAt(_clock()) > LoopSnapshotPolicy.maxAge) return null;
    try {
      final value = decode(resource, record.body);
      if (value == null) return null;
      return LoopRestoredSnapshot(value: value, observedAt: record.observedAt);
    } on Object {
      // A body today's decoder refuses — an older contract, a damaged file —
      // is simply not a snapshot.
      return null;
    }
  }

  /// The live decoder for [resource], applied to a stored [body].
  static Object? decode(String resource, Object? body) {
    switch (resource) {
      case LoopSnapshotResource.walletDirectory:
        return DioLoopV2WalletApi.decodeDirectory(body);
      case LoopSnapshotResource.marketOverview:
        return DioLoopV2MarketApi.decodeOverview(body);
      case LoopSnapshotResource.communityHome:
        return DioLoopV2CommunityApi.decodeHome(body);
      case LoopSnapshotResource.launchOverview:
        return DioLoopV2LaunchApi.decodeOverview(body);
    }
    final walletId = LoopSnapshotResource.walletIdOf(resource);
    if (walletId == null || walletId.isEmpty) return null;
    return DioLoopV2WalletApi.decodeBalances(body, walletId: walletId);
  }
}

/// The snapshot session for the verified principal, or `null` when there is
/// no store (Preview, tests) or nobody is signed in.
final loopV2SnapshotSessionProvider = Provider<LoopV2SnapshotSession?>((ref) {
  final store = ref.watch(loopSnapshotStoreProvider);
  final principal = ref.watch(loopBootstrapPrincipalKeyProvider);
  if (store == null || principal == null) return null;
  return LoopV2SnapshotSession(
    store: store,
    principal: principal,
    clock: ref.watch(loopReadClockProvider),
  );
});
