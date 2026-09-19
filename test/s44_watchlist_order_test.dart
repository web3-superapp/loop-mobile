import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';

import 'support/s5_page_harness.dart';

/// Real-device report 2026-09-19 · F6.
///
/// Rows were dragged into a new order, saved, and the page behind still
/// carried the old one until it was pulled down. 行情 projects the same
/// resource the editor just replaced, so the list it read before the save is
/// stale — exactly as it is after a star press, which has invalidated it all
/// along.
void main() {
  test('a saved order is stale on the page behind the editor', () async {
    final watchlist = FakeWatchlistGateway();
    final container = ProviderContainer(
      overrides: [
        watchlistGatewayProvider.overrideWithValue(watchlist),
        marketReadGatewayProvider.overrideWithValue(FakeMarketReadGateway()),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose providers need a listener to survive between reads.
    container.listen(
      marketOverviewControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      watchlistEditorControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(marketOverviewControllerProvider.notifier).load();
    expect(container.read(marketOverviewControllerProvider).isReady, isTrue);

    final editor = container.read(watchlistEditorControllerProvider.notifier);
    await editor.load();
    final before = container
        .read(watchlistEditorControllerProvider)
        .selectedGroup!
        .items
        .map((item) => item.assetId)
        .toList(growable: false);
    editor.reorder(0, 1);
    expect(await editor.save(), isTrue);

    // The document the server answered with carries the dragged order…
    final saved = watchlist.written.single
        .expand((group) => group.items)
        .map((item) => item.assetId)
        .take(2)
        .toList(growable: false);
    expect(saved, <String>[before[1], before[0]]);
    // …and the page behind this one has to read it again before it prints an
    // order. It never keeps the one the owner just changed.
    expect(container.read(marketOverviewControllerProvider).isReady, isFalse);
  });

  test('a save that never committed leaves the page behind alone', () async {
    final watchlist = FakeWatchlistGateway(
      replaceFailure: LoopChainFailureKind.versionConflict,
    );
    final container = ProviderContainer(
      overrides: [
        watchlistGatewayProvider.overrideWithValue(watchlist),
        marketReadGatewayProvider.overrideWithValue(FakeMarketReadGateway()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      marketOverviewControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    container.listen(
      watchlistEditorControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );

    await container.read(marketOverviewControllerProvider.notifier).load();
    final editor = container.read(watchlistEditorControllerProvider.notifier);
    await editor.load();
    editor.reorder(0, 1);

    expect(await editor.save(), isFalse);
    // Nothing was committed, so the list the page already read is still the
    // committed one. Dropping it would make it re-read for no change.
    expect(container.read(marketOverviewControllerProvider).isReady, isTrue);
  });
}
