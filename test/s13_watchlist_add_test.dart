import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// S13 — the path that puts an asset *into* the Watchlist.
///
/// Before this slice the star on `token` opened the editor, and the editor
/// could only reorder and remove, so an empty Watchlist could never stop being
/// empty. The star is now the write, and the editor owns group creation.
void main() {
  final Finder star = find.byKey(
    const ValueKey<String>('token-watchlist-action'),
  );

  WatchlistSnapshot emptyWatchlist() => WatchlistSnapshot(
    version: 4,
    updatedAt: DateTime.utc(2026, 9, 10, 8),
    groups: const <WatchlistGroup>[],
  );

  group('token star', () {
    testWidgets('adding to an empty Watchlist creates the default group', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(value: emptyWatchlist()),
      );
      final semantics = tester.ensureSemantics();
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
      expect(find.bySemanticsLabel('加入自选'), findsOneWidget);

      await tester.tap(star);
      await tester.pumpAndSettle();

      // The group the server never generates: the client names it, in the
      // same compare-and-set that adds the first asset.
      expect(watchlist.expectedVersions, <int>[4]);
      final written = watchlist.written.single;
      expect(written.single.key, watchlistDefaultGroupKey);
      expect(written.single.name, watchlistDefaultGroupName);
      expect(written.single.items.single.assetId, s5WbnbAssetId);
      expect(find.text('已加入自选'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '移出自选');
      expect(find.bySemanticsLabel('移出自选'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('adding to an existing default group appends to it', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          value: WatchlistSnapshot(
            version: 2,
            updatedAt: null,
            groups: <WatchlistGroup>[
              WatchlistGroup(
                key: watchlistDefaultGroupKey,
                name: watchlistDefaultGroupName,
                items: <WatchlistItem>[
                  WatchlistItem(assetId: s5UsdtAssetId, asset: s5Summary()),
                ],
              ),
            ],
          ),
        ),
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      await tester.tap(star);
      await tester.pumpAndSettle();

      expect(watchlist.written.single.length, 1);
      expect(
        watchlist.written.single.single.items.map((item) => item.assetId),
        <String>[s5UsdtAssetId, s5WbnbAssetId],
      );
    });

    testWidgets('a watched asset shows the filled star and removes', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      expect(tester.widget<LoopIconButton>(star).label, '移出自选');
      expect(tester.widget<LoopIconButton>(star).color, LoopColors.lime);

      await tester.tap(star);
      await tester.pumpAndSettle();

      // Only the one asset leaves; the group and its other rows stay.
      expect(watchlist.expectedVersions, <int>[1]);
      expect(
        watchlist.written.single.single.items.map((item) => item.assetId),
        <String>[s5UsdtAssetId, s5NativeAssetId],
      );
      expect(find.text('已移出自选'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
    });

    testWidgets('a version conflict re-reads and retries exactly once', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(value: emptyWatchlist()),
        reloadSnapshot: S5Answer<WatchlistSnapshot>(
          value: WatchlistSnapshot(
            version: 9,
            updatedAt: DateTime.utc(2026, 9, 10, 9),
            groups: <WatchlistGroup>[
              WatchlistGroup(
                key: 'mining',
                name: 'Mining',
                items: <WatchlistItem>[
                  WatchlistItem(assetId: s5UsdtAssetId, asset: s5Summary()),
                ],
              ),
            ],
          ),
        ),
        replaceFailures: <LoopChainFailureKind>[
          LoopChainFailureKind.versionConflict,
        ],
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      await tester.tap(star);
      await tester.pumpAndSettle();

      // The retry is composed against the version that was actually read
      // back, and it keeps the other device's group.
      expect(watchlist.expectedVersions, <int>[4, 9]);
      expect(watchlist.written.last.map((group) => group.key), <String>[
        'mining',
        watchlistDefaultGroupKey,
      ]);
      expect(find.text('已加入自选'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '移出自选');
    });

    testWidgets('a second conflict is reported, not retried again', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(value: emptyWatchlist()),
        replaceFailure: LoopChainFailureKind.versionConflict,
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      await tester.tap(star);
      await tester.pumpAndSettle();

      expect(watchlist.expectedVersions.length, 2);
      expect(find.textContaining('自选已在其他设备上改动'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
    });

    testWidgets('offline says nothing was written', (tester) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(value: emptyWatchlist()),
        replaceFailure: LoopChainFailureKind.offline,
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      await tester.tap(star);
      await tester.pumpAndSettle();

      expect(watchlist.expectedVersions, <int>[4]);
      expect(find.textContaining('设备当前离线'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
    });

    testWidgets('a refused write keeps the star honest', (tester) async {
      final watchlist = FakeWatchlistGateway(
        replaceFailure: LoopChainFailureKind.permissionDenied,
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      await tester.tap(star);
      await tester.pumpAndSettle();

      // The server refused, so the asset is still watched.
      expect(tester.widget<LoopIconButton>(star).label, '移出自选');
      expect(find.textContaining('当前账号无权执行此操作'), findsOneWidget);
    });

    testWidgets('an unavailable Watchlist capability disables the star', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
        meta: s5MetaSnapshot(
          watchlist: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(tester.widget<LoopIconButton>(star).label, '自选当前不可用');
      expect(tester.widget<LoopIconButton>(star).onPressed, isNull);
      expect(watchlist.written, isEmpty);
    });
  });

  group('watchlist-edit new group', () {
    testWidgets('the empty state names both ways in and offers one', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 4,
              updatedAt: null,
              groups: const <WatchlistGroup>[],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('watchlist-no-groups')),
        findsOneWidget,
      );
      expect(find.textContaining('在代币页点右上角星标'), findsOneWidget);
      expect(find.textContaining('本页只编辑已存在的分组'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('watchlist-new-group-empty')),
        findsOneWidget,
      );
    });

    testWidgets('a new group travels in the next compare-and-set', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-new-group')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('watchlist-group-name-field')),
        '  长期观察  ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-group-name-confirm')),
      );
      await tester.pumpAndSettle();

      // Nothing is written until the explicit save.
      expect(watchlist.written, isEmpty);
      expect(find.text('长期观察 0'), findsOneWidget);

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-save')));
      await tester.pumpAndSettle();

      expect(watchlist.expectedVersions, <int>[1]);
      final written = watchlist.written.single;
      expect(written.length, 2);
      // The key is generated on the client; the server generates none.
      expect(written.last.key, 'g1');
      expect(written.last.name, '长期观察');
      expect(written.last.items, isEmpty);
      expect(find.text('自选已保存'), findsOneWidget);
    });

    testWidgets('an empty name is refused in the sheet', (tester) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-new-group')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('watchlist-group-name-field')),
        '   ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-group-name-confirm')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('watchlist-group-name-error')),
        findsOneWidget,
      );
      expect(find.text('分组名称不能为空。'), findsOneWidget);
      // The sheet stays open on the refusal, with the typed value intact.
      expect(
        find.byKey(const ValueKey<String>('watchlist-group-name-field')),
        findsOneWidget,
      );
      expect(watchlist.written, isEmpty);
    });

    testWidgets('a duplicate name is refused in the sheet', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-new-group')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('watchlist-group-name-field')),
        'Mining',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-group-name-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已经有同名分组了。'), findsOneWidget);
    });
  });

  group('watchlist contract bounds', () {
    test('the name bounds are the server\'s own', () {
      expect(
        watchlistGroupNameIssue('', existing: const <WatchlistGroup>[]),
        WatchlistGroupNameIssue.empty,
      );
      expect(
        watchlistGroupNameIssue(
          'x' * (watchlistMaxNameCodePoints + 1),
          existing: const <WatchlistGroup>[],
        ),
        WatchlistGroupNameIssue.tooLong,
      );
      expect(
        watchlistGroupNameIssue('a\u200bb', existing: const <WatchlistGroup>[]),
        WatchlistGroupNameIssue.invalidCharacters,
      );
      expect(
        watchlistGroupNameIssue(
          '自选',
          existing: <WatchlistGroup>[
            WatchlistGroup(
              key: watchlistDefaultGroupKey,
              name: watchlistDefaultGroupName,
              items: const <WatchlistItem>[],
            ),
          ],
        ),
        WatchlistGroupNameIssue.duplicate,
      );
      expect(
        watchlistGroupNameIssue(
          '第二十一个',
          existing: <WatchlistGroup>[
            for (var index = 0; index < watchlistMaxGroups; index += 1)
              WatchlistGroup(
                key: 'g$index',
                name: 'G$index',
                items: const <WatchlistItem>[],
              ),
          ],
        ),
        WatchlistGroupNameIssue.groupLimitReached,
      );
      expect(
        watchlistGroupNameIssue('自选 A', existing: const <WatchlistGroup>[]),
        isNull,
      );
    });

    test('a generated key never collides and matches the contract', () {
      final pattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$');
      expect(nextWatchlistGroupKey(const <String>[]), 'g1');
      expect(nextWatchlistGroupKey(const <String>['g1', 'g2']), 'g3');
      expect(pattern.hasMatch(nextWatchlistGroupKey(const <String>[])), isTrue);
      expect(pattern.hasMatch(watchlistDefaultGroupKey), isTrue);
    });
  });
}
