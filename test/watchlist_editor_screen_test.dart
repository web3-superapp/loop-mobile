import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/personalization/memory_watchlist_gateway.dart';

void main() {
  testWidgets('production is honestly unavailable and shows no fixture list', (
    tester,
  ) async {
    await _pumpWatchlist(tester);

    expect(find.text('Production connection unavailable'), findsOneWidget);
    expect(find.text('Watchlist is not connected'), findsOneWidget);
    expect(find.textContaining('No private request was sent'), findsOneWidget);
    expect(find.text('BTC'), findsNothing);
    expect(find.textContaining('开发预览'), findsNothing);
  });

  testWidgets('Preview is labelled and saves an edited ordered snapshot', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpWatchlist(tester, gateway: gateway);

    expect(find.text('开发预览 · in-memory Watchlist'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.text('ETH'), findsOneWidget);
    expect(find.text('SOL'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('watchlist-remove-ETH')));

    expect(find.text('ETH'), findsNothing);
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('watchlist-save')));

    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
    expect((await gateway.load()).groups.single.items, <WatchlistItem>[
      WatchlistItem(assetKey: 'BTC'),
      WatchlistItem(assetKey: 'SOL'),
    ]);
  });

  testWidgets('creates a group and rejects a duplicated asset reference', (
    tester,
  ) async {
    await _pumpWatchlist(tester, gateway: _previewGateway());

    await _tap(tester, find.byKey(const ValueKey('watchlist-new-group')));
    await tester.enterText(
      find.byKey(const ValueKey('watchlist-group-key-input')),
      'research',
    );
    await tester.enterText(
      find.byKey(const ValueKey('watchlist-group-name-input')),
      'Research',
    );
    await _tap(tester, find.byKey(const ValueKey('watchlist-confirm-group')));

    expect(find.text('RESEARCH'), findsOneWidget);
    expect(find.text('research'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('watchlist-add-research')));
    await tester.enterText(
      find.byKey(const ValueKey('watchlist-asset-key-input')),
      'AVAX',
    );
    await _tap(tester, find.byKey(const ValueKey('watchlist-confirm-asset')));

    expect(find.text('AVAX'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('watchlist-add-core')));
    await tester.enterText(
      find.byKey(const ValueKey('watchlist-asset-key-input')),
      'BTC',
    );
    await _tap(tester, find.byKey(const ValueKey('watchlist-confirm-asset')));

    expect(
      find.text(
        'That change is invalid, duplicated, or exceeds the Watchlist limit.',
      ),
      findsOneWidget,
    );
    expect(find.text('BTC'), findsOneWidget);
  });

  testWidgets('version conflict preserves the draft until explicit reload', (
    tester,
  ) async {
    final gateway = _previewGateway();
    await _pumpWatchlist(tester, gateway: gateway);

    await _tap(tester, find.byKey(const ValueKey('watchlist-remove-SOL')));
    await gateway.replace(
      expectedVersion: 1,
      groups: <WatchlistGroup>[
        WatchlistGroup(
          key: 'core',
          name: 'Core',
          items: <WatchlistItem>[
            WatchlistItem(assetKey: 'BTC'),
            WatchlistItem(assetKey: 'ETH'),
            WatchlistItem(assetKey: 'ARB'),
          ],
        ),
      ],
    );

    await _tap(tester, find.byKey(const ValueKey('watchlist-save')));

    expect(find.byKey(const ValueKey('watchlist-conflict')), findsOneWidget);
    expect(find.text('SOL'), findsNothing);
    expect(find.text('ARB'), findsNothing);
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('watchlist-conflict-reload')));

    expect(find.byKey(const ValueKey('watchlist-conflict')), findsNothing);
    expect(find.text('ARB'), findsOneWidget);
    expect(find.text('SOL'), findsNothing);
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
  });

  testWidgets('unexpected save failures stay sanitized and retryable', (
    tester,
  ) async {
    await _pumpWatchlist(tester, gateway: _FailingSaveWatchlistGateway());

    await _tap(tester, find.byKey(const ValueKey('watchlist-remove-ETH')));
    await _tap(tester, find.byKey(const ValueKey('watchlist-save')));

    expect(find.text('Changes were not saved'), findsOneWidget);
    expect(
      find.text(
        'The Watchlist operation failed. Provider details were not exposed.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('raw-provider-secret'), findsNothing);
    expect(find.byKey(const ValueKey('watchlist-retry-save')), findsOneWidget);
  });

  testWidgets('an unavailable save stays visibly unsaved and retryable', (
    tester,
  ) async {
    await _pumpWatchlist(tester, gateway: _UnavailableSaveWatchlistGateway());

    await _tap(tester, find.byKey(const ValueKey('watchlist-remove-ETH')));
    await _tap(tester, find.byKey(const ValueKey('watchlist-save')));

    expect(find.text('Changes were not saved'), findsOneWidget);
    expect(
      find.text(
        'The Watchlist service is unavailable. No change was presented as saved.',
      ),
      findsOneWidget,
    );
    expect(find.text('UNSAVED DRAFT'), findsOneWidget);
    expect(find.byKey(const ValueKey('watchlist-retry-save')), findsOneWidget);
  });
}

Future<void> _pumpWatchlist(
  WidgetTester tester, {
  WatchlistGateway? gateway,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gateway != null)
          watchlistGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const WatchlistEditorScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

MemoryWatchlistGateway _previewGateway() => MemoryWatchlistGateway(
  initialSnapshot: _snapshot(),
  clock: () => DateTime.utc(2026, 8, 25, 12),
);

WatchlistSnapshot _snapshot() => WatchlistSnapshot(
  version: 1,
  groups: <WatchlistGroup>[
    WatchlistGroup(
      key: 'core',
      name: 'Core',
      items: <WatchlistItem>[
        WatchlistItem(assetKey: 'BTC'),
        WatchlistItem(assetKey: 'ETH'),
        WatchlistItem(assetKey: 'SOL'),
      ],
    ),
  ],
  updatedAt: DateTime.utc(2026, 8, 25),
);

final class _FailingSaveWatchlistGateway implements WatchlistGateway {
  @override
  WatchlistMode get mode => WatchlistMode.preview;

  @override
  Future<WatchlistSnapshot> load() async => _snapshot();

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) async {
    throw Exception('raw-provider-secret');
  }
}

final class _UnavailableSaveWatchlistGateway implements WatchlistGateway {
  @override
  WatchlistMode get mode => WatchlistMode.preview;

  @override
  Future<WatchlistSnapshot> load() async => _snapshot();

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) async {
    throw const WatchlistGatewayException(
      WatchlistGatewayFailureKind.unavailable,
    );
  }
}
