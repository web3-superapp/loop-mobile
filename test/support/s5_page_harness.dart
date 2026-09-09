import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 's5_fixtures.dart';

/// A port double that answers with a fixed value, a fixed failure, or never.
///
/// `pending` keeps the loading state visible; `failure` drives the error,
/// offline, unavailable and permission states from one place.
final class S5Answer<T> {
  S5Answer({this.value, this.failure, this.pending = false});

  final T? value;
  final LoopChainFailureKind? failure;
  final bool pending;

  Future<T> resolve() {
    if (pending) return Completer<T>().future;
    final kind = failure;
    if (kind != null) return Future<T>.error(LoopChainException(kind));
    return Future<T>.value(value as T);
  }
}

final class FakeChainGateway implements ChainGateway {
  FakeChainGateway({
    S5Answer<LoopChainStatus>? status,
    S5Answer<LoopChainAssetView>? asset,
    this.mode = LoopChainGatewayMode.production,
  }) : status = status ?? S5Answer<LoopChainStatus>(value: s5Status()),
       asset =
           asset ??
           S5Answer<LoopChainAssetView>(
             value: LoopChainAssetView(
               asset: s5Asset(),
               capability: s5ViewableCapability,
             ),
           );

  final S5Answer<LoopChainStatus> status;
  final S5Answer<LoopChainAssetView> asset;

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopChainStatus> loadStatus() => status.resolve();

  @override
  Future<LoopChainAssetView> loadAsset(String assetId) => asset.resolve();
}

final class FakeWalletReadGateway implements WalletReadGateway {
  FakeWalletReadGateway({
    S5Answer<LoopWalletDirectory>? directory,
    S5Answer<LoopWalletBalances>? balances,
    S5Answer<LoopWalletActivityPage>? activity,
    S5Answer<LoopWalletReceive>? receive,
    this.switchFailure,
    this.activityMoreFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : directory =
           directory ?? S5Answer<LoopWalletDirectory>(value: s5Directory()),
       balances = balances ?? S5Answer<LoopWalletBalances>(value: s5Balances()),
       activity =
           activity ?? S5Answer<LoopWalletActivityPage>(value: s5Activity()),
       receive = receive ?? S5Answer<LoopWalletReceive>(value: s5Receive());

  final S5Answer<LoopWalletDirectory> directory;
  final S5Answer<LoopWalletBalances> balances;
  final S5Answer<LoopWalletActivityPage> activity;
  final S5Answer<LoopWalletReceive> receive;
  final LoopChainFailureKind? switchFailure;

  /// Applies only to a paged read, i.e. `loadActivity(cursor: …)`. The first
  /// page still lands, so a test can drive a "next page failed" state without
  /// blanking the tape that already loaded.
  final LoopChainFailureKind? activityMoreFailure;

  int directoryReads = 0;
  final List<String> switched = <String>[];
  final List<String?> expectedActive = <String?>[];
  final List<String?> activityCursors = <String?>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopWalletDirectory> loadWallets() {
    directoryReads += 1;
    return directory.resolve();
  }

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) {
    switched.add(walletId);
    expectedActive.add(expectedActiveWalletId);
    final failure = switchFailure;
    if (failure != null) {
      return Future<LoopWalletDirectory>.error(LoopChainException(failure));
    }
    return Future<LoopWalletDirectory>.value(
      s5Directory(activeWalletId: walletId),
    );
  }

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) =>
      balances.resolve();

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) {
    activityCursors.add(cursor);
    final more = activityMoreFailure;
    if (cursor != null && more != null) {
      return Future<LoopWalletActivityPage>.error(LoopChainException(more));
    }
    return activity.resolve();
  }

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) => receive.resolve();
}

final class FakeMarketReadGateway implements MarketReadGateway {
  FakeMarketReadGateway({
    S5Answer<MarketOverview>? overview,
    S5Answer<MarketAssetDetail>? asset,
    S5Answer<MarketCandleSeries>? candles,
    S5Answer<MarketTradesPage>? trades,
    S5Answer<MarketHolders>? holders,
    S5Answer<MarketNewPairsPage>? newPairs,
    S5Answer<LoopUnavailable>? smartMoney,
    this.mode = LoopChainGatewayMode.production,
  }) : overview = overview ?? S5Answer<MarketOverview>(value: s5Overview()),
       asset = asset ?? S5Answer<MarketAssetDetail>(value: s5Detail()),
       candles = candles ?? S5Answer<MarketCandleSeries>(value: s5Series()),
       trades =
           trades ??
           S5Answer<MarketTradesPage>(
             value: MarketTradesPage(
               assetId: s5WbnbAssetId,
               trades: MarketTradesAvailable(
                 source: LoopFactSource.loopIndexer,
                 items: const <MarketTrade>[],
                 nextCursor: null,
                 freshness: LoopIndexerFreshness(
                   indexerBlockNumber: BigInt.from(120640710),
                   headBlockNumber: BigInt.from(120640743),
                   lagBlocks: 33,
                   observedAt: DateTime.utc(2026, 9, 8, 7, 31),
                 ),
               ),
             ),
           ),
       holders =
           holders ??
           S5Answer<MarketHolders>(
             value: MarketHolders(
               assetId: s5WbnbAssetId,
               holderCount: s5FreshFact('8019338'),
               distribution: const LoopUnavailable(
                 'HOLDER_DISTRIBUTION_NOT_SUPPORTED',
               ),
             ),
           ),
       newPairs =
           newPairs ??
           S5Answer<MarketNewPairsPage>(
             value: const MarketNewPairsPage(
               newPairs: MarketNewPairsUnavailable(
                 'MARKET_PROVIDER_GECKOTERMINAL_DISABLED',
               ),
               riskScreening: LoopUnavailable(
                 'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
               ),
             ),
           ),
       smartMoney =
           smartMoney ??
           S5Answer<LoopUnavailable>(
             value: const LoopUnavailable('SMART_MONEY_RUNTIME_DEFERRED'),
           );

  final S5Answer<MarketOverview> overview;
  final S5Answer<MarketAssetDetail> asset;
  final S5Answer<MarketCandleSeries> candles;
  final S5Answer<MarketTradesPage> trades;
  final S5Answer<MarketHolders> holders;
  final S5Answer<MarketNewPairsPage> newPairs;
  final S5Answer<LoopUnavailable> smartMoney;

  final List<LoopCandleInterval> intervals = <LoopCandleInterval>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<MarketOverview> loadOverview() => overview.resolve();

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) => asset.resolve();

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) {
    intervals.add(interval);
    return candles.resolve();
  }

  @override
  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor}) =>
      trades.resolve();

  @override
  Future<MarketHolders> loadHolders(String assetId) => holders.resolve();

  @override
  Future<MarketNewPairsPage> loadNewPairs() => newPairs.resolve();

  @override
  Future<LoopUnavailable> loadSmartMoney() => smartMoney.resolve();
}

final class FakeWatchlistGateway implements WatchlistGateway {
  FakeWatchlistGateway({
    S5Answer<WatchlistSnapshot>? snapshot,
    this.replaceFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : snapshot = snapshot ?? S5Answer<WatchlistSnapshot>(value: s5Watchlist());

  final S5Answer<WatchlistSnapshot> snapshot;
  final LoopChainFailureKind? replaceFailure;

  final List<int> expectedVersions = <int>[];
  final List<List<WatchlistGroup>> written = <List<WatchlistGroup>>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<WatchlistSnapshot> load() => snapshot.resolve();

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) {
    expectedVersions.add(expectedVersion);
    written.add(groups);
    final failure = replaceFailure;
    if (failure != null) {
      return Future<WatchlistSnapshot>.error(LoopChainException(failure));
    }
    return Future<WatchlistSnapshot>.value(
      WatchlistSnapshot(
        version: expectedVersion + 1,
        updatedAt: DateTime.utc(2026, 9, 8, 6),
        groups: groups,
      ),
    );
  }
}

final class FakeAlertsGateway implements AlertsGateway {
  FakeAlertsGateway({
    S5Answer<LoopAlertPage>? page,
    this.commandFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : page =
           page ??
           S5Answer<LoopAlertPage>(
             value: LoopAlertPage(
               items: <LoopPriceAlert>[s5Alert()],
               nextCursor: null,
             ),
           );

  final S5Answer<LoopAlertPage> page;
  final LoopChainFailureKind? commandFailure;

  final List<LoopAlertDraft> created = <LoopAlertDraft>[];
  final List<LoopAlertDraft> updated = <LoopAlertDraft>[];
  final List<String> deleted = <String>[];
  final List<int> expectedVersions = <int>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopAlertPage> listAlerts({String? cursor}) => page.resolve();

  @override
  Future<LoopPriceAlert> createAlert(LoopAlertDraft draft) {
    created.add(draft);
    final failure = commandFailure;
    if (failure != null) {
      return Future<LoopPriceAlert>.error(LoopChainException(failure));
    }
    return Future<LoopPriceAlert>.value(s5Alert());
  }

  @override
  Future<LoopPriceAlert> updateAlert({
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
  }) {
    updated.add(draft);
    expectedVersions.add(expectedVersion);
    final failure = commandFailure;
    if (failure != null) {
      return Future<LoopPriceAlert>.error(LoopChainException(failure));
    }
    return Future<LoopPriceAlert>.value(s5Alert(version: expectedVersion + 1));
  }

  @override
  Future<void> deleteAlert({
    required String alertId,
    required int expectedVersion,
  }) {
    deleted.add(alertId);
    expectedVersions.add(expectedVersion);
    final failure = commandFailure;
    if (failure != null) return Future<void>.error(LoopChainException(failure));
    return Future<void>.value();
  }
}

final class FakeNotificationsGateway implements NotificationsGateway {
  FakeNotificationsGateway({
    S5Answer<LoopNotificationFeed>? feed,
    S5Answer<LoopNotificationPreferences>? preferences,
    this.writeFailure,
    this.mode = LoopChainGatewayMode.production,
  }) : feed = feed ?? S5Answer<LoopNotificationFeed>(value: s5Feed()),
       preferences =
           preferences ??
           S5Answer<LoopNotificationPreferences>(value: s5Preferences());

  final S5Answer<LoopNotificationFeed> feed;
  final S5Answer<LoopNotificationPreferences> preferences;
  final LoopChainFailureKind? writeFailure;

  final List<String> read = <String>[];
  final List<Map<LoopNotificationCategory, bool>> written =
      <Map<LoopNotificationCategory, bool>>[];
  final List<int> expectedVersions = <int>[];

  @override
  final LoopChainGatewayMode mode;

  @override
  Future<LoopNotificationFeed> loadFeed({String? cursor}) => feed.resolve();

  @override
  Future<LoopNotificationEntry> markRead(String notificationId) {
    read.add(notificationId);
    final failure = writeFailure;
    if (failure != null) {
      return Future<LoopNotificationEntry>.error(LoopChainException(failure));
    }
    return Future<LoopNotificationEntry>.value(
      s5Notification(readAt: DateTime.utc(2026, 9, 8, 8)),
    );
  }

  @override
  Future<LoopNotificationPreferences> loadPreferences() =>
      preferences.resolve();

  @override
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  }) {
    expectedVersions.add(expectedVersion);
    written.add(categories);
    final failure = writeFailure;
    if (failure != null) {
      return Future<LoopNotificationPreferences>.error(
        LoopChainException(failure),
      );
    }
    return Future<LoopNotificationPreferences>.value(
      LoopNotificationPreferences(
        version: expectedVersion + 1,
        updatedAt: DateTime.utc(2026, 9, 8, 8),
        categories: <LoopNotificationCategory, LoopNotificationCategoryState>{
          for (final entry in categories.entries)
            entry.key: LoopNotificationCategoryState(
              enabled: entry.value,
              locked: entry.key == LoopNotificationCategory.securityEvent,
            ),
        },
        push: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
      ),
    );
  }
}

/// A capability document where the five S5 ids can be flipped independently.
LoopV2MetaSnapshot s5MetaSnapshot({
  LoopV2CapabilityAvailability marketRead =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability walletRead =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability bscRead = LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability watchlist =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability priceAlerts =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability notificationsFeed =
      LoopV2CapabilityAvailability.available,
  LoopV2CapabilityAvailability sendApprovals =
      LoopV2CapabilityAvailability.unavailable,
  LoopV2CapabilityAvailability privySwap =
      LoopV2CapabilityAvailability.unavailable,
  // The Privy BSC swap device evidence is pending until a real device proves
  // it; a test may clear it to exercise the open path.
  bool swapEvidencePending = true,
}) {
  return LoopV2MetaSnapshot(
    clientPolicy: LoopV2ClientPolicy(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      defaultRoute: LoopV2PrimaryTab.community,
      navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
      versionGate: const LoopV2VersionGate.unavailable(
        reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
      ),
      regionGate: const LoopV2RegionGate(
        status: LoopV2RegionGateStatus.unavailable,
        reasonCode: 'REGION_POLICY_UNAVAILABLE',
        supportUrl: null,
        readOnlyAssetAccess: null,
      ),
      termsGate: const LoopV2TermsGate(
        status: LoopV2TermsGateStatus.unavailable,
        requiredVersion: null,
        reasonCode: 'TERMS_POLICY_UNAVAILABLE',
      ),
    ),
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-01',
      effectiveAt: DateTime.utc(2026, 9),
      capabilities: <LoopV2Capability>[
        for (final id in LoopV2CapabilityId.values)
          LoopV2Capability(
            id: id,
            availability: switch (id) {
              LoopV2CapabilityId.marketRead => marketRead,
              LoopV2CapabilityId.walletRead => walletRead,
              LoopV2CapabilityId.bscRead => bscRead,
              LoopV2CapabilityId.watchlist => watchlist,
              LoopV2CapabilityId.priceAlerts => priceAlerts,
              LoopV2CapabilityId.notificationsFeed => notificationsFeed,
              LoopV2CapabilityId.sendApprovals => sendApprovals,
              LoopV2CapabilityId.privySwap => privySwap,
              _ => LoopV2CapabilityAvailability.unavailable,
            },
            reasonCode: switch (id) {
              LoopV2CapabilityId.marketRead =>
                marketRead == LoopV2CapabilityAvailability.available
                    ? null
                    : 'MARKET_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.walletRead =>
                walletRead == LoopV2CapabilityAvailability.available
                    ? null
                    : 'BSC_CHAIN_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.bscRead =>
                bscRead == LoopV2CapabilityAvailability.available
                    ? null
                    : 'BSC_RPC_NOT_CONFIGURED',
              LoopV2CapabilityId.watchlist =>
                watchlist == LoopV2CapabilityAvailability.available
                    ? null
                    : 'WATCHLIST_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.priceAlerts =>
                priceAlerts == LoopV2CapabilityAvailability.available
                    ? null
                    : 'ALERTS_RUNTIME_UNAVAILABLE',
              LoopV2CapabilityId.notificationsFeed =>
                notificationsFeed == LoopV2CapabilityAvailability.available
                    ? null
                    : 'PUSH_RUNTIME_DEFERRED',
              LoopV2CapabilityId.sendApprovals =>
                sendApprovals == LoopV2CapabilityAvailability.available
                    ? null
                    : 'BSC_WRITES_DISABLED',
              LoopV2CapabilityId.privySwap =>
                privySwap == LoopV2CapabilityAvailability.available
                    ? null
                    : 'BSC_WRITES_DISABLED',
              _ => 'CAPABILITY_NOT_DELIVERED',
            },
            evidence: id == LoopV2CapabilityId.privySwap && swapEvidencePending
                ? const LoopV2CapabilityEvidence(
                    status: LoopV2CapabilityEvidenceStatus.pending,
                    reasonCode: 'PRIVY_BSC_SWAP_DEVICE_EVIDENCE_PENDING',
                  )
                : const LoopV2CapabilityEvidence(
                    status: LoopV2CapabilityEvidenceStatus.notApplicable,
                    reasonCode: null,
                  ),
          ),
      ],
    ),
  );
}

/// Mounts one S5 page with the six ports and the capability document.
Future<void> pumpS5Page(
  WidgetTester tester,
  Widget page, {
  ChainGateway? chain,
  WalletReadGateway? wallet,
  MarketReadGateway? market,
  WatchlistGateway? watchlist,
  AlertsGateway? alerts,
  NotificationsGateway? notifications,
  LoopV2MetaSnapshot? meta,
  Size size = const Size(390, 2400),
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (chain != null) chainGatewayProvider.overrideWithValue(chain),
        if (wallet != null) walletReadGatewayProvider.overrideWithValue(wallet),
        if (market != null) marketReadGatewayProvider.overrideWithValue(market),
        if (watchlist != null)
          watchlistGatewayProvider.overrideWithValue(watchlist),
        if (alerts != null) alertsGatewayProvider.overrideWithValue(alerts),
        if (notifications != null)
          notificationsGatewayProvider.overrideWithValue(notifications),
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => meta ?? s5MetaSnapshot(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // A never-completing read keeps the skeleton animating, so the frame is
    // pumped a fixed number of times instead of settled.
    await tester.pump();
    await tester.pump();
  }
}

/// Scrolls the page's own collection until [finder] is built and visible.
Future<void> scrollToS5Section(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
}
