// S187-6 · decision 0178: the global search drawn as docs/35 「搜索」 —
// 全部 / 代币 / 社区 / 用户 segments, 「最近搜索」 cards and rows, result rows
// and the bottom input bar with 「粘贴」.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_recent.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_search_recent_store.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const String _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

SearchResult _asset() => const SearchResult(
  resultType: SearchResultType.asset,
  stableId: _assetId,
  title: 'USDT',
  subtitle: 'Tether USD',
  avatarRef: null,
  memberCount: null,
  verificationStatus: 'pending',
  destination: SearchAssetDestination(_assetId),
);

SearchResult _community() => const SearchResult(
  resultType: SearchResultType.community,
  stableId: testCommunityId,
  title: 'Frog Holders',
  subtitle: 'frog-holders',
  avatarRef: null,
  memberCount: 128,
  verificationStatus: 'verified',
  destination: SearchCommunityProfileDestination(),
);

SearchResult _user() => const SearchResult(
  resultType: SearchResultType.user,
  stableId: testMemberId,
  title: 'frog_maxi',
  subtitle: 'LOOP-7HJKMNPQ',
  avatarRef: null,
  memberCount: null,
  verificationStatus: null,
  destination: SearchPublicProfileDestination(),
);

SearchPage _page(
  SearchDomain domain,
  List<SearchResult> results, {
  String? nextCursor,
}) => SearchPage(
  domain: domain,
  available: true,
  reasonCode: null,
  results: results,
  nextCursor: nextCursor,
);

FakeSearchGateway _gateway({
  CommunityGatewayMode mode = CommunityGatewayMode.production,
  String? userCursor,
}) => FakeSearchGateway(
  mode: mode,
  pages: <SearchDomain, SearchPage>{
    SearchDomain.assets: _page(SearchDomain.assets, <SearchResult>[_asset()]),
    SearchDomain.communities: _page(SearchDomain.communities, <SearchResult>[
      _community(),
    ]),
    SearchDomain.users: _page(SearchDomain.users, <SearchResult>[
      _user(),
    ], nextCursor: userCursor),
  },
);

final class _MemoryRecentStore implements SearchRecentStore {
  _MemoryRecentStore([this.stored = const <SearchRecentEntry>[]]);

  List<SearchRecentEntry> stored;
  final List<List<SearchRecentEntry>> writes = <List<SearchRecentEntry>>[];

  @override
  bool get persistent => true;

  @override
  Future<List<SearchRecentEntry>> read() async => stored;

  @override
  Future<void> write(List<SearchRecentEntry> entries) async {
    writes.add(entries);
    stored = entries;
  }
}

const List<SearchRecentEntry> _seed = <SearchRecentEntry>[
  SearchRecentEntry(
    type: SearchResultType.user,
    stableId: testMemberId,
    title: 'frog_maxi',
  ),
  SearchRecentEntry(
    type: SearchResultType.community,
    stableId: testCommunityId,
    title: 'Frog Holders',
  ),
  SearchRecentEntry(
    type: SearchResultType.asset,
    stableId: _assetId,
    title: 'USDT',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required FakeSearchGateway search,
  required SearchRecentStore store,
  FakeSocialGateway? social,
  String? initialQuery,
  ValueChanged<String>? onOpenAsset,
  ValueChanged<String>? onOpenCommunity,
}) => pumpCommunityPage(
  tester,
  GlobalSearchScreen(
    initialQuery: initialQuery,
    onOpenAsset: onOpenAsset,
    onOpenCommunity: onOpenCommunity,
  ),
  search: search,
  social: social ?? FakeSocialGateway(),
  size: const Size(390, 900),
  overrides: <Override>[searchRecentStoreProvider.overrideWithValue(store)],
);

/// Every solid Lime fill on screen: a Material, a box or a container.
int _solidLime(WidgetTester tester) {
  var count = 0;
  for (final material in tester.widgetList<Material>(find.byType(Material))) {
    if (material.color == LoopColors.lime) count += 1;
  }
  for (final box in tester.widgetList<DecoratedBox>(
    find.byType(DecoratedBox),
  )) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration && decoration.color == LoopColors.lime) {
      count += 1;
    }
  }
  return count;
}

final Finder _segs = find.byWidgetPredicate(
  (widget) =>
      widget is LoopSeg &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('search-seg-'),
);

void main() {
  loopWatchGround();

  group('segments', () {
    testWidgets('全部 / 代币 / 社区 / 用户, and only the chosen one is solid Lime', (
      tester,
    ) async {
      await _pump(tester, search: _gateway(), store: _MemoryRecentStore(_seed));

      final segs = tester.widgetList<LoopSeg>(_segs).toList();
      expect(segs.map((seg) => seg.label), <String>['全部', '代币', '社区', '用户']);
      final xs = <double>[
        for (final seg in segs) tester.getTopLeft(find.byWidget(seg)).dx,
      ];
      expect(xs, orderedEquals(List<double>.of(xs)..sort()));
      // 算力榜 has no search domain on the server, so it is not drawn.
      expect(find.text('算力榜'), findsNothing);
      // The recent cards' capsules are LimeSoft: the chosen segment is the
      // screen's one solid Lime.
      expect(
        find.byKey(const ValueKey<String>('search-recent-cards')),
        findsOneWidget,
      );
      expect(_solidLime(tester), 1);

      await tester.tap(find.byKey(const ValueKey<String>('search-seg-assets')));
      await tester.pumpAndSettle();
      final chosen = tester.widget<LoopSeg>(
        find.byKey(const ValueKey<String>('search-seg-assets')),
      );
      expect(chosen.selected, isTrue);
      expect(chosen.quiet, isFalse);
      final all = tester.widget<LoopSeg>(
        find.byKey(const ValueKey<String>('search-seg-all')),
      );
      expect(all.selected, isFalse);
      expect(all.quiet, isTrue);
      expect(_solidLime(tester), 1);
    });

    testWidgets('全部 offers 更多 into a domain that has another page', (
      tester,
    ) async {
      final gateway = _gateway(userCursor: 'next-1');
      await _pump(
        tester,
        search: gateway,
        store: _MemoryRecentStore(),
        initialQuery: 'frog',
      );
      expect(gateway.queries, <String>[
        'assets:frog',
        'communities:frog',
        'users:frog',
      ]);
      // One section per domain, in segment order.
      final sections = <String>['assets', 'communities', 'users'];
      final tops = <double>[
        for (final domain in sections)
          tester
              .getTopLeft(
                find.byKey(ValueKey<String>('search-section-$domain')),
              )
              .dy,
      ];
      expect(tops, orderedEquals(List<double>.of(tops)..sort()));
      expect(
        find.byKey(const ValueKey<String>('search-more-assets')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey<String>('search-more-users')));
      await tester.pumpAndSettle();
      expect(gateway.queries.last, 'users:frog');
      expect(
        tester
            .widget<LoopSeg>(
              find.byKey(const ValueKey<String>('search-seg-users')),
            )
            .selected,
        isTrue,
      );
    });
  });

  group('最近搜索', () {
    testWidgets('opening a result records it; × removes one; 清除全部 empties', (
      tester,
    ) async {
      final store = _MemoryRecentStore();
      final opened = <String>[];
      await _pump(
        tester,
        search: _gateway(),
        store: store,
        initialQuery: 'frog',
        onOpenAsset: opened.add,
        onOpenCommunity: opened.add,
      );

      await tester.tap(find.text('USDT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frog Holders'));
      await tester.pumpAndSettle();
      expect(opened, <String>[_assetId, testCommunityId]);
      expect(store.stored.map((entry) => entry.title), <String>[
        'Frog Holders',
        'USDT',
      ]);

      // Clearing the field shows 「最近搜索」 in place of the results.
      await tester.enterText(
        find.byKey(const ValueKey<String>('search-field')),
        '',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('search-recent-label')),
        findsOneWidget,
      );
      final card = find.byKey(
        const ValueKey<String>('search-recent-community-$testCommunityId'),
      );
      expect(tester.getSize(card).width, 150);
      expect(
        find.byKey(
          const ValueKey<String>(
            'search-recent-enter-community-$testCommunityId',
          ),
        ),
        findsOneWidget,
      );
      // The token is a row with its own ×.
      final row = find.byKey(
        const ValueKey<String>('search-recent-asset-$_assetId'),
      );
      expect(tester.widget(row), isA<LoopPersonRow>());

      await tester.tap(
        find.byKey(
          const ValueKey<String>('search-recent-remove-asset-$_assetId'),
        ),
      );
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(store.stored.map((entry) => entry.title), <String>[
        'Frog Holders',
      ]);

      await tester.tap(
        find.byKey(const ValueKey<String>('search-recent-clear')),
      );
      await tester.pumpAndSettle();
      expect(store.stored, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('search-recent-label')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('search-empty')),
        findsOneWidget,
      );
    });

    testWidgets('recent entries survive a restart through the store', (
      tester,
    ) async {
      final social = FakeSocialGateway();
      await _pump(
        tester,
        search: _gateway(),
        store: _MemoryRecentStore(_seed),
        social: social,
      );

      final user = find.byKey(
        const ValueKey<String>('search-recent-user-$testMemberId'),
      );
      expect(user, findsOneWidget);
      // Only the stored name is drawn: no member count or return line.
      for (final text in tester.widgetList<Text>(
        find.descendant(of: user, matching: find.byType(Text)),
      )) {
        final data = text.data ?? '';
        expect(RegExp(r'[0-9$]|成员').hasMatch(data), isFalse, reason: data);
      }
      final avatar = tester.getSize(
        find
            .descendant(
              of: user,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget.runtimeType.toString() == 'LoopProfileAvatar',
              ),
            )
            .first,
      );
      expect(avatar.width, 56);

      final follow = find.byKey(
        const ValueKey<String>('search-recent-follow-user-$testMemberId'),
      );
      final pill = tester.widget<LoopPillAction>(follow);
      expect(pill.label, '关注');
      expect(pill.soft, isTrue);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(social.commands, contains('follow:$testMemberId:true'));
      expect(tester.widget<LoopPillAction>(follow).label, '已关注');
    });

    testWidgets('a Preview result is never written to the store', (
      tester,
    ) async {
      final store = _MemoryRecentStore(_seed);
      await _pump(
        tester,
        search: _gateway(mode: CommunityGatewayMode.preview),
        store: store,
        initialQuery: 'frog',
      );
      // Preview reads nothing from the device either.
      await tester.tap(find.text('Frog Holders'));
      await tester.pumpAndSettle();
      expect(store.writes, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey<String>('search-field')),
        '',
      );
      await tester.pumpAndSettle();
      // The run keeps it; the seeded production entries never appear.
      expect(
        find.byKey(
          const ValueKey<String>('search-recent-community-$testCommunityId'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-recent-user-$testMemberId')),
        findsNothing,
      );
    });

    test('the store keeps ten entries under one key and fails open', () async {
      final values = <String, String>{};
      final store = SharedPreferencesSearchRecentStore.forTesting(
        (key) async => values[key],
        (key, value) async => values[key] = value,
        (key) async => values.remove(key),
      );
      final many = <SearchRecentEntry>[
        for (var index = 0; index < 12; index += 1)
          SearchRecentEntry(
            type: SearchResultType.user,
            stableId: 'id-$index',
            title: 'name $index',
          ),
      ];
      await store.write(many);
      expect(values.keys, <String>['loop.search.v1.recent']);
      expect(
        SharedPreferencesSearchRecentStore.recentKey,
        'loop.search.v1.recent',
      );
      final read = await store.read();
      expect(read, hasLength(searchRecentLimit));
      expect(read.first, many.first);
      // Only id, type and name are stored.
      expect(values['loop.search.v1.recent'], isNot(contains('avatar')));

      await store.write(const <SearchRecentEntry>[]);
      expect(values, isEmpty);

      values['loop.search.v1.recent'] = '{not json';
      expect(await store.read(), isEmpty);
      values['loop.search.v1.recent'] =
          '[{"t":"robot","id":"x","n":"y"},{"t":"asset","id":"a","n":"A"}]';
      expect((await store.read()).single.stableId, 'a');

      final throwing = SharedPreferencesSearchRecentStore.forTesting(
        (key) async => throw StateError('refused'),
        (key, value) async => throw StateError('refused'),
        (key) async => throw StateError('refused'),
      );
      expect(await throwing.read(), isEmpty);
      await throwing.write(many);

      final silent = SharedPreferencesSearchRecentStore.forTesting(
        (key) => Completer<String?>().future,
        (key, value) => Completer<void>().future,
        (key) => Completer<void>().future,
      );
      final watch = Stopwatch()..start();
      expect(await silent.read(), isEmpty);
      await silent.write(many);
      expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
    });
  });

  group('rows and bar', () {
    testWidgets('a token row states the missing price and never prints 0', (
      tester,
    ) async {
      await _pump(
        tester,
        search: _gateway(),
        store: _MemoryRecentStore(),
        initialQuery: 'usd',
      );
      final row = find.byKey(const ValueKey<String>('search-result-$_assetId'));
      expect(tester.widget(row), isA<LoopPersonRow>());
      final logo = tester.widget<LoopTokenLogo>(
        find.descendant(of: row, matching: find.byType(LoopTokenLogo)),
      );
      expect(logo.size, 44);
      expect(logo.cornerRadius, LoopRadius.tileValue);
      final badge = tester.widget<LoopBadge>(
        find.descendant(of: row, matching: find.byType(LoopBadge)),
      );
      expect(badge.text, '代币');
      expect(badge.kind, LoopBadgeKind.mute);
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(
            const ValueKey<String>('search-result-price-$_assetId'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(searchPriceAbsentText), findsOneWidget);
      for (final text in tester.widgetList<Text>(
        find.descendant(of: row, matching: find.byType(Text)),
      )) {
        final data = text.data ?? '';
        expect(RegExp(r'(^|\$)0([.,]0*)?$').hasMatch(data), isFalse);
        expect(data.contains('—'), isFalse);
      }
      // A × appears only in 「最近搜索」, never on a live result.
      expect(
        find.descendant(of: row, matching: find.bySemanticsLabel(RegExp('移除'))),
        findsNothing,
      );
    });

    testWidgets('the bar sits at the bottom and rises with the keyboard', (
      tester,
    ) async {
      await _pump(tester, search: _gateway(), store: _MemoryRecentStore());
      final bar = find.byKey(const ValueKey<String>('search-bar'));
      final segs = find.byKey(const ValueKey<String>('search-segs'));
      expect(tester.getRect(bar).top, greaterThan(tester.getRect(segs).bottom));
      final resting = tester.getRect(bar).bottom;
      expect(resting, greaterThan(800));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.getRect(bar).bottom, lessThanOrEqualTo(900 - 300));

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('search-field')),
      );
      expect(field.decoration?.hintText, '搜索代币、社区、用户…');
      final paste = find.byKey(const ValueKey<String>('search-paste-loop-id'));
      expect(tester.widget<LoopSeg>(paste).label, '粘贴');
      expect(
        tester.getRect(paste).left,
        greaterThan(
          tester
              .getRect(find.byKey(const ValueKey<String>('search-field')))
              .right,
        ),
      );
    });

    testWidgets('粘贴 fills the field with the clipboard and searches it', (
      tester,
    ) async {
      String? clipboard = 'frog';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': clipboard};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final gateway = _gateway();
      await _pump(tester, search: gateway, store: _MemoryRecentStore());
      await tester.tap(
        find.byKey(const ValueKey<String>('search-paste-loop-id')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('search-field')),
            )
            .controller
            ?.text,
        'frog',
      );
      expect(gateway.queries, <String>[
        'assets:frog',
        'communities:frog',
        'users:frog',
      ]);
      expect(find.text('frog_maxi'), findsOneWidget);
      clipboard = null;
    });
  });
}
