import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
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

  /// A document already at [items] assets, spread over [groups] groups, none
  /// of which is the default group unless [withDefaultGroup] says so.
  WatchlistSnapshot fullWatchlist({
    required int items,
    required int groups,
    bool withDefaultGroup = false,
  }) {
    final rows = <WatchlistItem>[
      for (var index = 0; index < items; index += 1)
        WatchlistItem(
          assetId: 'eip155:56:0x${index.toRadixString(16).padLeft(40, '0')}',
          reasonCode: 'ASSET_NOT_READABLE',
        ),
    ];
    return WatchlistSnapshot(
      version: 4,
      updatedAt: null,
      groups: <WatchlistGroup>[
        for (var index = 0; index < groups; index += 1)
          WatchlistGroup(
            key: index == 0 && withDefaultGroup
                ? watchlistDefaultGroupKey
                : 'g$index',
            name: index == 0 && withDefaultGroup
                ? watchlistDefaultGroupName
                : 'G$index',
            // Every row lives in the first group; the rest exist to fill the
            // group budget.
            items: index == 0 ? rows : const <WatchlistItem>[],
          ),
      ],
    );
  }

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
      expect(find.textContaining('设备已离线'), findsOneWidget);
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
      expect(find.textContaining('当前账号没有执行这个操作的权限'), findsOneWidget);
    });

    testWidgets('a full Watchlist names the item limit, not the asset', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          value: fullWatchlist(
            items: watchlistMaxItems,
            groups: 1,
            withDefaultGroup: true,
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

      // Refused on device: no request, and the sentence is about the limit
      // rather than the server's "asset is not registered".
      expect(watchlist.written, isEmpty);
      expect(find.textContaining('自选已达 $watchlistMaxItems 项'), findsOneWidget);
      expect(find.textContaining('未登记'), findsNothing);
      expect(find.textContaining('资产未登记'), findsNothing);
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
    });

    testWidgets('a full group budget names the group limit', (tester) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          value: fullWatchlist(items: 3, groups: watchlistMaxGroups),
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

      expect(watchlist.written, isEmpty);
      expect(find.textContaining('分组已达 $watchlistMaxGroups 个'), findsOneWidget);
      expect(find.textContaining('未登记'), findsNothing);
    });

    testWidgets('a conflict whose reload already satisfies the intent stops', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(value: emptyWatchlist()),
        reloadSnapshot: S5Answer<WatchlistSnapshot>(
          value: WatchlistSnapshot(
            version: 11,
            updatedAt: null,
            groups: <WatchlistGroup>[
              WatchlistGroup(
                key: watchlistDefaultGroupKey,
                name: watchlistDefaultGroupName,
                items: <WatchlistItem>[
                  WatchlistItem(assetId: s5WbnbAssetId, asset: s5Summary()),
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

      // The other device already added it. Writing again would say the same
      // thing twice, so the reload is the outcome.
      expect(watchlist.expectedVersions, <int>[4]);
      expect(watchlist.written.length, 1);
      expect(find.text('已加入自选'), findsOneWidget);
      expect(tester.widget<LoopIconButton>(star).label, '移出自选');
    });

    testWidgets('an unread list is neither watched nor unwatched', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(pending: true),
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
        settle: false,
      );

      final button = tester.widget<LoopIconButton>(star);
      expect(button.label, '加入自选');
      // No colour claim and no toggle claim while the answer is unknown.
      expect(button.color, isNull);
      expect(button.toggled, isNull);
      expect(button.onPressed, isNotNull);
      expect(
        tester.getSemantics(star),
        matchesSemantics(
          label: '加入自选',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      expect(watchlist.written, isEmpty);
      semantics.dispose();
    });

    testWidgets('a failed read is answered by the press, not assumed', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          failure: LoopChainFailureKind.offline,
        ),
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      // The read failed, so nothing is claimed and the star still invites a
      // press — which re-reads before it would write.
      expect(tester.widget<LoopIconButton>(star).label, '加入自选');
      expect(tester.widget<LoopIconButton>(star).toggled, isNull);

      await tester.tap(star);
      await tester.pumpAndSettle();

      expect(watchlist.written, isEmpty);
      expect(find.textContaining('设备已离线'), findsOneWidget);
    });

    testWidgets('a closed gateway disables the star even when the capability '
        'document says the module is available', (tester) async {
      final watchlist = FakeWatchlistGateway(
        mode: LoopChainGatewayMode.unavailable,
      );
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        watchlist: watchlist,
      );

      expect(tester.widget<LoopIconButton>(star).label, '自选当前不可用');
      expect(tester.widget<LoopIconButton>(star).onPressed, isNull);
      expect(tester.widget<LoopIconButton>(star).toggled, isNull);
      expect(watchlist.loads, 0);
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

    testWidgets('放弃修改 undoes a new group', (tester) async {
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
        '短线',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-group-name-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('短线 0'), findsOneWidget);

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-discard')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-discard')));
      await tester.pumpAndSettle();

      // The group only ever lived in the draft, so discarding removes it and
      // nothing was ever sent.
      expect(find.text('短线 0'), findsNothing);
      expect(find.text('Mining 3'), findsOneWidget);
      expect(watchlist.written, isEmpty);
    });

    testWidgets('a full group budget disables 新建分组', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 4,
              updatedAt: null,
              groups: <WatchlistGroup>[
                for (var index = 0; index < watchlistMaxGroups; index += 1)
                  WatchlistGroup(
                    key: 'g$index',
                    name: 'G$index',
                    items: const <WatchlistItem>[],
                  ),
              ],
            ),
          ),
        ),
      );

      final button = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('watchlist-new-group')),
      );
      expect(button.onPressed, isNull);
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

  group('watchlist membership controller', () {
    test('a committed write invalidates the market overview', () async {
      final watchlist = FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          value: WatchlistSnapshot(
            version: 4,
            updatedAt: null,
            groups: const <WatchlistGroup>[],
          ),
        ),
      );
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
      final membership = watchlistMembershipControllerProvider(s5WbnbAssetId);
      container.listen(membership, (_, _) {}, fireImmediately: true);

      await container.read(marketOverviewControllerProvider.notifier).load();
      expect(container.read(marketOverviewControllerProvider).isReady, isTrue);

      await container.read(membership.notifier).load();
      final result = await container.read(membership.notifier).toggle();

      expect(result.outcome, WatchlistToggleOutcome.added);
      // The overview projects the same resource, so the list it read before
      // this write is stale and must be read again.
      expect(container.read(marketOverviewControllerProvider).isReady, isFalse);
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
