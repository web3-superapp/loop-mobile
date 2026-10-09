import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The lists 行情 offers, in the order the chips are drawn (decision 0118).
///
/// 自选 is the Watchlist block of the overview; 主流, MEME and 社区代币 are
/// the three server categories (decision 0100), each read a page at a time
/// and ordered by the server. 新币 is drawn only while
/// [LoopFeatureSwitchValues.outboundMarketListsVisible] is on.
enum MarketTab {
  watchlist('自选'),
  major('主流'),
  meme('MEME'),
  community('社区代币'),
  newPairs('新币');

  const MarketTab(this.label);

  final String label;

  /// The chip's sprite glyph (decision 0122).
  String get icon => switch (this) {
    MarketTab.watchlist => 'star',
    MarketTab.major => 'globe',
    MarketTab.meme => 'launch',
    MarketTab.community => 'community',
    MarketTab.newPairs => 'clock',
  };

  /// The server category this chip reads, or `null` for 自选 and 新币.
  MarketCategory? get category => switch (this) {
    MarketTab.major => MarketCategory.major,
    MarketTab.meme => MarketCategory.meme,
    MarketTab.community => MarketCategory.community,
    MarketTab.watchlist || MarketTab.newPairs => null,
  };
}

/// `market` · the 行情 list, and the 行情 segment of 情报.
///
/// A price list read the way the approved reference reads one (Fomo,
/// 2026-10-08): a strip of running promotions when there are any, the
/// chips, and then one continuous table of 64pt rows — ticker over market
/// cap, price over the 24-hour move in rise / fall. Every list scrolls on to
/// its last page and says when there is nothing more. The source and time of
/// the figures are one weak line under the table, which opens the full
/// statement (AGENTS rule 25).
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({
    super.key,
    this.onNavigate,
    this.onBack,
    this.embedded = false,
    this.onOpenPromotion,
  });

  final void Function(String location)? onNavigate;

  /// Where a promotion card's in-app location is opened. `null` pushes it
  /// like any other location.
  final ValueChanged<String>? onOpenPromotion;

  /// Set when 行情 is opened as a page of its own rather than as a tab.
  final VoidCallback? onBack;

  /// The 行情 segment of 情报 (decision 0110): no bar of its own, and the
  /// promotion strip on top.
  final bool embedded;

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  MarketTab _tab = MarketTab.watchlist;

  /// Whether this page drew the Watchlist as a skeleton. Only then does the
  /// list fade in when it lands (decision 0095).
  bool _sawSkeleton = false;

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  void _select(MarketTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final mode = ref.watch(marketReadGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final switches = ref.watch(loopFeatureSwitchesProvider);
    final outbound = switches.outboundMarketListsVisible;
    final tabs = <MarketTab>[
      for (final tab in MarketTab.values)
        if (tab != MarketTab.newPairs || outbound) tab,
    ];
    if (!tabs.contains(_tab)) _tab = MarketTab.watchlist;

    final state = ref.watch(marketOverviewControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(marketOverviewControllerProvider.notifier).load());
        }
      });
    }
    final overview = state.value;
    if (!blocked &&
        overview == null &&
        state.phase == LoopChainViewPhase.loading) {
      _sawSkeleton = true;
    }
    final controller = ref.read(marketOverviewControllerProvider.notifier);
    final category = _tab.category;
    final categoryState = category == null || blocked
        ? null
        : ref.watch(marketCategoryControllerProvider(category));
    if (category != null &&
        categoryState != null &&
        categoryState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(marketCategoryControllerProvider(category).notifier)
                .load(),
          );
        }
      });
    }

    return LoopDashboardPage(
      key: const ValueKey<String>('market-screen'),
      archetype: LoopPageArchetype.listing,
      title: '行情',
      onBack: widget.onBack,
      tabPage: widget.onBack == null,
      embedded: widget.embedded,
      updating: state.refreshing || (categoryState?.refreshing ?? false),
      // Pull to re-read what is on screen: the overview always (自选 and the
      // freshness line come from it), and the chosen category from its first
      // page.
      onRefresh: () async {
        final reads = <Future<void>>[
          ref.read(marketOverviewControllerProvider.notifier).reload(),
          if (category != null)
            ref
                .read(marketCategoryControllerProvider(category).notifier)
                .reload(),
          if (widget.embedded)
            ref.read(intelPromotionsControllerProvider.notifier).reload(),
        ];
        await Future.wait(reads);
      },
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('market-capability-block'),
              title: '行情模块当前不可用',
              capability: capability,
              fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
            )
          : null,
      framedTools: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('market-alerts-action'),
          icon: 'bell',
          label: '价格提醒',
          framed: true,
          onPressed: () => _open(MarketAssetRoute.alertsPath),
        ),
      ],
      sections: <Widget>[
        LoopFreshnessStrip(
          key: const ValueKey<String>('market-freshness'),
          restoredAt: controller.restoredObservedAt,
          readAt: controller.valueObservedAt,
          refreshing: state.refreshing,
          refreshFailed: overview != null && state.failureKind != null,
          onRetry: () => unawaited(controller.reload()),
        ),
        if (widget.embedded)
          _IntelPromotions(onOpen: widget.onOpenPromotion ?? _open)
        else
          MarketSearchField(onPressed: () => _open('/search')),
        LoopSegBar(
          key: const ValueKey<String>('market-tabs'),
          labels: <String>[for (final tab in tabs) tab.label],
          icons: <String>[for (final tab in tabs) tab.icon],
          selectedIndex: tabs.indexOf(_tab),
          onSelected: (index) => _select(tabs[index]),
        ),
        ...switch (_tab) {
          MarketTab.watchlist => _watchlistSections(state),
          MarketTab.major ||
          MarketTab.meme ||
          MarketTab.community => _categorySections(category!, categoryState),
          MarketTab.newPairs => <Widget>[
            MarketNewPairsList(
              key: const ValueKey<String>('market-new-pairs-tab'),
              onOpenAsset: (assetId) => _open(MarketAssetRoute.token(assetId)),
              onOpenPage: () => _open('/market/new'),
            ),
          ],
        },
        if (outbound && overview != null && _tab != MarketTab.newPairs)
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('market-smart-money-entry'),
                title: '聪明钱追踪',
                subtitle: loopReasonCodeText(overview.smartMoney.reasonCode),
                trailingBadge: const LoopBadge('不可用'),
                onTap: () => _open('/market/smart-money'),
              ),
            ],
          ),
      ],
    );
  }

  /// 自选: the Watchlist block of the overview, as rows.
  List<Widget> _watchlistSections(
    LoopChainResourceState<MarketOverview> state,
  ) {
    final overview = state.value;
    if (overview == null && state.phase == LoopChainViewPhase.loading) {
      // Rows of the list's own fixed height, so nothing moves when the
      // prices land (decision 0095).
      return const <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('market-state-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 6,
          rowHeight: marketFomoRowHeight,
          leadingSize: marketFomoLogoSize,
        ),
      ];
    }
    if (!state.isReady || overview == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: 'market',
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '暂时没有可展示的行情',
          onRetry: () => unawaited(
            ref.read(marketOverviewControllerProvider.notifier).reload(),
          ),
        ),
      ];
    }
    final block = overview.watchlist;
    if (block is MarketWatchlistUnavailable) {
      return <Widget>[
        LoopInlineUnavailable(
          key: const ValueKey<String>('market-watchlist-unavailable'),
          message: '自选行情暂时读不到 · ${loopReasonCodeText(block.reasonCode)}',
          onRetry: () => unawaited(
            ref.read(marketOverviewControllerProvider.notifier).reload(),
          ),
        ),
      ];
    }
    final items = (block as MarketWatchlistAvailable).items;
    if (items.isEmpty) {
      return <Widget>[
        LoopEmptyState(
          key: const ValueKey<String>('market-watchlist-empty'),
          illustration: LoopIllustration.watchlist,
          title: '还没有自选',
          message: '在代币页点右上角的星标，就能加进自选',
          action: LoopButton(
            key: const ValueKey<String>('market-watchlist-browse-major'),
            label: '去主流看看',
            icon: 'globe',
            primary: true,
            onPressed: () => _select(MarketTab.major),
          ),
        ),
      ];
    }
    return <Widget>[
      for (final row in items)
        LoopContentArrival(
          key: ValueKey<String>('market-asset-${row.assetId}'),
          animate: _sawSkeleton,
          child: MarketFomoRow.watchlist(
            row,
            onTap: () => _open(MarketAssetRoute.token(row.assetId)),
          ),
        ),
      LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('market-watchlist-manage'),
            title: '管理自选',
            subtitle: '排序、分组与移除',
            onTap: () => _open('/market/watchlist'),
          ),
        ],
      ),
      const MarketListEnd(key: ValueKey<String>('market-list-end')),
      _provenanceOfRows(items),
    ];
  }

  /// One of the three server categories, a page at a time.
  List<Widget> _categorySections(
    MarketCategory category,
    LoopChainResourceState<MarketCategoryPage>? state,
  ) {
    final keyBase = 'market-category-${category.wireName}';
    if (state == null) return const <Widget>[];
    final page = state.value;
    final controller = ref.read(
      marketCategoryControllerProvider(category).notifier,
    );
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('$keyBase-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 6,
          rowHeight: marketFomoRowHeight,
          leadingSize: marketFomoLogoSize,
        ),
      ];
    }
    if (page == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: keyBase,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '这个分类还没有代币',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    if (page.items.isEmpty) {
      return <Widget>[
        LoopEmpty(
          key: ValueKey<String>('$keyBase-empty'),
          message: '「${category.label}」里还没有代币',
          reason: switch (category) {
            MarketCategory.major => '主流资产名单里暂时没有可展示的资产。',
            MarketCategory.meme => '还没有已登记的 Launch 项目代币。',
            MarketCategory.community => '还没有已认证社区绑定代币。',
          },
        ),
      ];
    }
    final cursor = page.nextCursor;
    return <Widget>[
      for (final row in page.items)
        MarketFomoRow.category(
          row,
          key: ValueKey<String>('market-asset-${row.assetId}'),
          onTap: () => _open(MarketAssetRoute.token(row.assetId)),
        ),
      if (controller.appendFailed && !state.busy)
        LoopInlineUnavailable(
          key: ValueKey<String>('$keyBase-more-failed'),
          message: '下一页没有读到',
          onRetry: () => unawaited(controller.loadMore()),
        )
      else if (cursor != null) ...<Widget>[
        LoopLoadMoreSentinel(
          key: ValueKey<String>('$keyBase-load-more'),
          cursor: cursor,
          onLoadMore: () => unawaited(controller.loadMore()),
        ),
        if (state.busy)
          MarketListLoadingMore(key: ValueKey<String>('$keyBase-loading-more')),
      ] else
        const MarketListEnd(key: ValueKey<String>('market-list-end')),
      LoopProvenanceLine(
        key: const ValueKey<String>('market-list-provenance'),
        sources: <String>[
          for (final row in page.items)
            if (row.quote case final quote?) loopFactSourceLabel(quote.source),
        ],
        observedAt: _oldestQuote(page.items) ?? page.observedAt,
        detail:
            '${page.rules.orderingLabel}。'
            '读不到报价的代币排在最后，并写明原因；不会显示 0。',
      ),
    ];
  }

  static DateTime? _oldestQuote(List<MarketCategoryRow> rows) {
    DateTime? oldest;
    for (final row in rows) {
      final at = row.quote?.observedAt;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    return oldest;
  }

  /// The source line of the Watchlist rows: every provider the readable
  /// prices name, and the oldest of their observation times.
  static Widget _provenanceOfRows(List<MarketAssetRow> rows) {
    final sources = <String>[];
    DateTime? oldest;
    for (final row in rows) {
      final price = row.price;
      if (!price.isAvailable) continue;
      final source = price.source;
      if (source != null) sources.add(loopFactSourceLabel(source));
      final at = price.fetchedAt;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    return LoopProvenanceLine(
      key: const ValueKey<String>('market-list-provenance'),
      sources: sources,
      observedAt: oldest,
      detail: '自选的价格与 24 小时涨跌，读不到的行写明原因；不会显示 0。',
    );
  }
}

/// The promotion strip, read on its own: a strip that cannot be read, or
/// that has no running card, is simply not drawn.
class _IntelPromotions extends ConsumerStatefulWidget {
  const _IntelPromotions({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  ConsumerState<_IntelPromotions> createState() => _IntelPromotionsState();
}

class _IntelPromotionsState extends ConsumerState<_IntelPromotions> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(intelPromotionsControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(intelPromotionsControllerProvider.notifier).load(),
          );
        }
      });
    }
    final items = state.value?.items ?? const <IntelPromotion>[];
    if (items.isEmpty) {
      return const SizedBox.shrink(
        key: ValueKey<String>('intel-promotions-hidden'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntelPromotionStrip(promotions: items, onOpen: widget.onOpen),
    );
  }
}
