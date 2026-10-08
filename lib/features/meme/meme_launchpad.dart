import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Whether the `meme` reads are closed for this build: no transport, or the
/// server said the capability is not available.
bool memeReadsBlocked(WidgetRef ref) {
  final capability = ref.watch(loopCapabilityProvider(LoopV2CapabilityId.meme));
  final mode = ref.watch(memeGatewayProvider.select((g) => g.mode));
  return loopChainCapabilityBlocks(mode, capability);
}

/// The sentence a closed `meme` capability is explained with.
String memeCapabilityText(LoopCapabilityProjection capability) {
  if (capability.isUnobserved) {
    return capability.unreachable ? '暂时连不上 LOOP，发射台读不到' : '发射台状态还没有读到';
  }
  return memeReasonText(capability.reasonCode ?? 'MEME_RUNTIME_UNAVAILABLE');
}

/// MEME · 发射台 (archetype `index`, layout `dashboard`, S115–S118 §3).
///
/// One line of tools — the search entry and the Lime 「创建代币」 — then the
/// four chips and the rows of the chosen chip, read a page at a time as the
/// reader scrolls. An empty chip says so and offers the create entry; a
/// closed capability is one inline line, never an empty list.
class MemeLaunchpadSegment extends ConsumerStatefulWidget {
  const MemeLaunchpadSegment({required this.onNavigate, super.key});

  final void Function(String location) onNavigate;

  @override
  ConsumerState<MemeLaunchpadSegment> createState() =>
      _MemeLaunchpadSegmentState();
}

class _MemeLaunchpadSegmentState extends ConsumerState<MemeLaunchpadSegment> {
  MemeListTab _tab = MemeListTab.fresh;

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.meme),
    );
    final blocked = memeReadsBlocked(ref);
    final provider = memeListControllerProvider(_tab);
    final state = blocked ? null : ref.watch(provider);
    if (state != null && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(ref.read(provider.notifier).load());
      });
    }
    return LoopDashboardPage(
      key: const ValueKey<String>('meme-launchpad'),
      archetype: LoopPageArchetype.listing,
      title: '发射台',
      embedded: true,
      tabPage: true,
      onRefresh: blocked ? null : () => ref.read(provider.notifier).reload(),
      sections: <Widget>[
        _LaunchpadTools(
          createEnabled: !blocked,
          onSearch: () => widget.onNavigate('/search'),
          onCreate: () => widget.onNavigate(MemeRoute.createPath),
        ),
        LoopSegBar(
          key: const ValueKey<String>('meme-list-chips'),
          labels: <String>[for (final tab in MemeListTab.values) tab.label],
          selectedIndex: MemeListTab.values.indexOf(_tab),
          onSelected: (index) =>
              setState(() => _tab = MemeListTab.values[index]),
        ),
        if (blocked)
          LoopInlineUnavailable(
            key: const ValueKey<String>('meme-launchpad-unavailable'),
            message: '发射台暂时不可用 · ${memeCapabilityText(capability)}',
          )
        else
          ..._rows(state!),
      ],
    );
  }

  List<Widget> _rows(LoopChainResourceState<MemeTokenPage> state) {
    final keyBase = 'meme-list-${_tab.wireName}';
    final controller = ref.read(memeListControllerProvider(_tab).notifier);
    final page = state.value;
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('$keyBase-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 6,
          rowHeight: memeRowHeight,
          leadingSize: memeLogoSize,
        ),
      ];
    }
    if (page == null) {
      if (state.phase == LoopChainViewPhase.unavailable) {
        return <Widget>[
          LoopInlineUnavailable(
            key: ValueKey<String>('$keyBase-unavailable'),
            message: '发射台暂时不可用 · ${loopChainFailureReason(state.failureKind)}',
            onRetry: () => unawaited(controller.reload()),
          ),
        ];
      }
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: keyBase,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '还没有代币，来创建第一个',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    if (page.items.isEmpty) {
      return <Widget>[
        LoopEmpty(
          key: ValueKey<String>('$keyBase-empty'),
          icon: 'plus',
          message: _tab == MemeListTab.fresh
              ? '还没有代币，来创建第一个'
              : '「${_tab.label}」里还没有代币',
          action: LoopButton(
            key: const ValueKey<String>('meme-empty-create'),
            label: '创建代币',
            primary: true,
            onPressed: () => widget.onNavigate(MemeRoute.createPath),
          ),
        ),
      ];
    }
    final cursor = page.nextCursor;
    return <Widget>[
      for (final row in page.items)
        MemeTokenRowTile(
          row: row,
          onTap: () => widget.onNavigate(MemeRoute.token(row.memeTokenId)),
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
          LoopSkeleton(
            key: ValueKey<String>('$keyBase-loading-more'),
            type: LoopSkeletonType.priceRow,
            rows: 2,
            rowHeight: memeRowHeight,
            leadingSize: memeLogoSize,
          ),
      ] else
        const MarketListEnd(key: ValueKey<String>('meme-list-end')),
      MemeProvenance(
        key: const ValueKey<String>('meme-list-provenance'),
        sources: <String>{
          for (final row in page.items)
            if (row.priceSource case final source?) source.source.label,
        }.toList(),
        observedAt: page.observedAt,
        detail:
            '内盘代币的价格与市值读自 LOOP 曲线，已毕业代币读自 DexScreener；'
            '读不到价格的代币写明原因，不会显示 0。',
      ),
    ];
  }
}

class _LaunchpadTools extends StatelessWidget {
  const _LaunchpadTools({
    required this.createEnabled,
    required this.onSearch,
    required this.onCreate,
  });

  final bool createEnabled;
  final VoidCallback onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      4,
      LoopSpacing.page,
      8,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: '搜索代币',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey<String>('meme-search-entry'),
                onTap: onSearch,
                borderRadius: LoopRadius.inner,
                child: Container(
                  height: LoopTouch.minimum,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: LoopColors.card,
                    borderRadius: LoopRadius.inner,
                    border: Border.all(color: LoopColors.line),
                  ),
                  child: Row(
                    children: <Widget>[
                      const LoopIcon('search', size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '搜索代币',
                        style: LoopType.body.copyWith(color: LoopColors.text3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        LoopButton(
          key: const ValueKey<String>('meme-create-entry'),
          label: '创建代币',
          icon: 'plus',
          primary: true,
          onPressed: createEnabled ? onCreate : null,
        ),
      ],
    ),
  );
}

const String _marketFallbackReason = 'MARKET_RUNTIME_UNAVAILABLE';

/// MEME · 行情: the server's `meme` category (decision 0100), drawn with the
/// 行情 row of decision 0118. A row opens the asset's own token page.
class MemeMarketSegment extends ConsumerWidget {
  const MemeMarketSegment({required this.onNavigate, super.key});

  final void Function(String location) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final mode = ref.watch(marketReadGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    const category = MarketCategory.meme;
    final provider = marketCategoryControllerProvider(category);
    final state = blocked ? null : ref.watch(provider);
    if (state != null && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() => unawaited(ref.read(provider.notifier).load()));
    }
    final controller = ref.read(provider.notifier);
    final page = state?.value;
    final List<Widget> rows;
    if (state == null) {
      rows = <Widget>[
        LoopInlineUnavailable(
          key: const ValueKey<String>('meme-market-unavailable'),
          message:
              '行情暂时不可用 · ${loopReasonCodeText(capability.reasonCode ?? _marketFallbackReason)}',
        ),
      ];
    } else if (page == null) {
      rows = <Widget>[
        if (state.phase == LoopChainViewPhase.loading)
          const LoopSkeleton(
            key: ValueKey<String>('meme-market-loading'),
            type: LoopSkeletonType.priceRow,
            rows: 6,
            rowHeight: marketFomoRowHeight,
            leadingSize: marketFomoLogoSize,
          )
        else
          LoopChainStateBlock(
            keyPrefix: 'meme-market',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '平台 MEME 资产上线后在这里显示',
            onRetry: () => unawaited(controller.reload()),
          ),
      ];
    } else if (page.items.isEmpty) {
      rows = const <Widget>[
        LoopEmpty(
          key: ValueKey<String>('meme-market-empty'),
          message: '平台 MEME 资产上线后在这里显示',
        ),
      ];
    } else {
      final cursor = page.nextCursor;
      rows = <Widget>[
        for (final row in page.items)
          MarketFomoRow.category(
            row,
            key: ValueKey<String>('meme-market-${row.assetId}'),
            onTap: () => onNavigate(MarketAssetRoute.token(row.assetId)),
          ),
        if (controller.appendFailed && !state.busy)
          LoopInlineUnavailable(
            key: const ValueKey<String>('meme-market-more-failed'),
            message: '下一页没有读到',
            onRetry: () => unawaited(controller.loadMore()),
          )
        else if (cursor != null) ...<Widget>[
          LoopLoadMoreSentinel(
            key: const ValueKey<String>('meme-market-load-more'),
            cursor: cursor,
            onLoadMore: () => unawaited(controller.loadMore()),
          ),
          if (state.busy)
            const MarketListLoadingMore(
              key: ValueKey<String>('meme-market-loading-more'),
            ),
        ] else
          const MarketListEnd(key: ValueKey<String>('meme-market-end')),
        LoopProvenanceLine(
          key: const ValueKey<String>('meme-market-provenance'),
          sources: <String>[
            for (final row in page.items)
              if (row.quote case final quote?)
                loopFactSourceLabel(quote.source),
          ],
          observedAt: page.observedAt,
          detail:
              '${page.rules.orderingLabel}。内盘代币读自 LOOP 曲线，'
              '已毕业代币读自 DexScreener；读不到报价的代币写明原因。',
        ),
      ];
    }
    return LoopDashboardPage(
      key: const ValueKey<String>('meme-market'),
      archetype: LoopPageArchetype.listing,
      title: '行情',
      embedded: true,
      tabPage: true,
      onRefresh: blocked ? null : controller.reload,
      sections: rows,
    );
  }
}
