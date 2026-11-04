import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/shell/loop_orientation.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';

/// Shared capability gate for the four secondary market pages.
bool _marketBlocked(WidgetRef ref) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.marketRead),
  );
  final mode = ref.watch(marketReadGatewayProvider).mode;
  return loopChainCapabilityBlocks(mode, capability);
}

/// The whole-page block a closed market gate renders. It keeps the server's
/// own reason when the server answered, and says the client never reached LOOP
/// when it did not.
Widget _marketPageBlock(
  WidgetRef ref, {
  required Key key,
  required String title,
}) => LoopCapabilityPageBlock.of(
  key: key,
  title: title,
  capability: ref.watch(loopCapabilityProvider(LoopV2CapabilityId.marketRead)),
  fallbackReasonCode: 'MARKET_RUNTIME_UNAVAILABLE',
);

Widget _invalidAssetPage(
  String id,
  String title,
  VoidCallback? onBack,
) => LoopFocusPage(
  key: ValueKey<String>('invalid-asset-$id'),
  archetype: LoopPageArchetype.record,
  title: title,
  onBack: onBack,
  body: <Widget>[
    LoopEmptyState(
      key: ValueKey<String>('invalid-asset-identity'),
      illustration: LoopIllustration.search,
      title: LoopL10n.current.market_secondaryScreensInvalidAssetIdentityTitle,
      message:
          LoopL10n.current.market_secondaryScreensInvalidAssetIdentityMessage,
      compact: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// chart-full
// ---------------------------------------------------------------------------

/// `chart-full` · the full-screen chart for one asset.
///
/// The interval segments map one-to-one onto the contract's `interval` values.
/// The prototype's `1m` segment and its MA / EMA / MACD / RSI / drawing tools
/// have no backend, so they are rendered as unavailable rather than as
/// controls that would silently do nothing.
class FullChartScreen extends ConsumerStatefulWidget {
  const FullChartScreen({required this.assetId, super.key, this.onBack});

  final String? assetId;
  final VoidCallback? onBack;

  @override
  ConsumerState<FullChartScreen> createState() => _FullChartScreenState();
}

class _FullChartScreenState extends ConsumerState<FullChartScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;

  /// Everything on this page that is not the plot: the top bar, the chart
  /// toolbar, the interval row and the source line under it. The plot takes
  /// whatever is left.
  static const double _chromeHeight = 210;

  /// Below this the plot stops being a chart and becomes a stripe, so the
  /// page scrolls instead of shrinking further.
  static const double _minimumChartHeight = 160;

  @override
  void initState() {
    super.initState();
    // `chart-full` is the token chart turned sideways (decision 0118).
    unawaited(SystemChrome.setPreferredOrientations(loopChartOrientations));
  }

  @override
  void dispose() {
    // Back to the App's portrait lock (decision 0128), not to "any": an
    // empty list would let every other page turn sideways again.
    unawaited(loopLockPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage(
        'chart',
        context.l10n.market_secondaryScreensInvalidAssetPage,
        widget.onBack,
      );
    }
    if (_marketBlocked(ref)) {
      return LoopFocusPage(
        key: const ValueKey<String>('chart-full-blocked'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.market_secondaryScreensChartFullBlockedTitle,
        onBack: widget.onBack,
        block: _marketPageBlock(
          ref,
          key: const ValueKey<String>('chart-full-capability-block'),
          title: context.l10n.market_screenMarketCapabilityBlockTitle,
        ),
        body: const <Widget>[],
      );
    }
    // The bar names the asset and its quote, from the asset read this page
    // shares with the token page behind it.
    final identity = ref.watch(marketAssetControllerProvider(assetId));
    if (identity.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketAssetControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final detail = identity.value;
    final price = detail?.price;
    final change = detail?.priceChange24h;
    final quote = <String>[
      if (price != null && price.isAvailable) marketRowPrice(price.value!),
      if (change != null && change.isAvailable) marketMoveLabel(change.value!),
    ].join(' ');

    final media = MediaQuery.of(context);
    final chartHeight = math.max(
      _minimumChartHeight,
      media.size.height - media.padding.vertical - _chromeHeight,
    );

    return LoopFocusPage(
      key: ValueKey<String>('chart-full-$assetId'),
      archetype: LoopPageArchetype.record,
      title: detail == null
          ? loopTruncatedAssetId(assetId)
          : marketAssetIdentityLabel(detail.asset),
      subtitle: quote.isEmpty ? loopTruncatedAssetId(assetId) : quote,
      onBack: widget.onBack,
      body: <Widget>[
        TokenCandleSection(
          key: const ValueKey<String>('chart-full-candles'),
          assetId: assetId,
          interval: _interval,
          height: chartHeight,
          onIntervalChanged: (value) => setState(() => _interval = value),
        ),
        // S278 · decision 0236: an explanation, behind (i).
        LoopProvenanceFooter(
          key: ValueKey<String>('chart-full-interval-notice'),
          label: context.l10n.common_about,
          title:
              context.l10n.market_secondaryScreensChartFullIntervalNoticeTitle,
          text: context.l10n.market_secondaryScreensChartFullIntervalNoticeText,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// token-holders
// ---------------------------------------------------------------------------

/// `token-holders` · only the holder count has a source in this step.
class HolderDistributionScreen extends ConsumerStatefulWidget {
  const HolderDistributionScreen({
    required this.assetId,
    super.key,
    this.onBack,
  });

  final String? assetId;
  final VoidCallback? onBack;

  @override
  ConsumerState<HolderDistributionScreen> createState() =>
      _HolderDistributionScreenState();
}

class _HolderDistributionScreenState
    extends ConsumerState<HolderDistributionScreen> {
  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage(
        'holders',
        context.l10n.market_secondaryScreensInvalidAssetPage2,
        widget.onBack,
      );
    }
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketHoldersControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketHoldersControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final holders = state.value;
    final count = holders?.holderCount;
    // Distribution is unavailable for the whole of this step, so a holder
    // count the server could not give leaves the page with nothing but two
    // refusals under a heading that repeats one of them (C-19). That is a
    // whole-page state, and it belongs in the page's own block rather than in
    // a card with a screen of black under it.
    final nothingToShow = holders != null && !holders.holderCount.isAvailable;

    return LoopDashboardPage(
      key: ValueKey<String>('token-holders-$assetId'),
      onRefresh: ref
          .read(marketHoldersControllerProvider(assetId).notifier)
          .reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: context.l10n.market_secondaryScreensTokenHoldersFolioTitle,
      onBack: widget.onBack,
      // `.folio-primary.chalk-card`: the prototype's Chalk hero. LOOP drew
      // the same Lime hero it uses everywhere, so the whole module read as
      // one colour (audit 2026-09-21 §G.4, §D item 2).
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-holders-folio'),
        variant: LoopFolioVariant.quiet,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketHoldersKicker,
        heading: count == null || count.value == null
            ? context.l10n.market_secondaryScreensTokenHoldersFolioHeading
            : context.l10n.market_secondaryScreensTokenHoldersFolioHeading2(
                loopFormatDecimal(count.value!, maxFractionDigits: 0),
              ),
        // S278 · decision 0236: the count's source and time sit behind the
        // kicker's (i); a count that could not be read keeps its reason.
        caption: count == null
            ? context.l10n.market_secondaryScreensTokenHoldersFolioCaption
            : count.isAvailable
            ? null
            : loopReasonCodeText(count.reasonCode),
        kickerTrailing: count != null && count.isAvailable
            // S325 · decision 0255 (UX-009): the page's one (i) in its bar.
            ? LoopProvenanceReport(
                entry: LoopProvenanceEntry(
                  heading: context.l10n.common_holders,
                  notes: <LoopInfoNote>[
                    LoopInfoNote(body: loopFactProvenance(count)),
                  ],
                ),
                fallback: LoopInfoTrigger(
                  key: const ValueKey<String>('token-holders-provenance'),
                  semanticsLabel: context.l10n
                      .market_secondaryScreensTokenHoldersProvenanceSemanticsLabel(
                        loopFactProvenance(count),
                      ),
                  onTap: () => unawaited(
                    showLoopInfoSheet(
                      context,
                      title: context.l10n.common_dataSource,
                      sheetKey: 'token-holders-provenance-sheet',
                      notes: <LoopInfoNote>[
                        LoopInfoNote(body: loopFactProvenance(count)),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        stamp: count != null && count.isAvailable
            ? loopFormatDecimal(count.value!, maxFractionDigits: 0)
            : null,
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('token-holders-capability-block'),
              title: context.l10n.market_screenMarketCapabilityBlockTitle,
            )
          : nothingToShow
          ? LoopPageBlock(
              key: const ValueKey<String>('token-holders-page-block'),
              title: context
                  .l10n
                  .market_secondaryScreensTokenHoldersPageBlockTitle,
              message: loopReasonCodeText(holders.holderCount.reasonCode),
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || holders == null)
          LoopChainStateBlock(
            keyPrefix: 'token-holders',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref
                  .read(marketHoldersControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else ...<Widget>[
          // `.stat-grid`: the prototype's two cells. The concentration half
          // has no source in this step and says so in the figure's place,
          // which keeps the grid's shape without printing a zero.
          // Decision 0171 (docs/33 L6): the shared `LoopStatGrid`, not a
          // one-row copy of it.
          LoopStatGrid(
            key: const ValueKey<String>('token-holders-stats'),
            stats: <LoopStat>[
              MarketStatCell.fact(
                context.l10n.market_secondaryScreensFact,
                holders.holderCount,
                formatter: (value) =>
                    loopFormatDecimal(value, maxFractionDigits: 0),
              ).toStat(),
              MarketStatCell(
                label: context.l10n.market_secondaryScreensLabel,
                value: loopReasonCodeSummaryText(
                  holders.distribution.reasonCode,
                ),
                available: false,
              ).toStat(),
            ],
          ),
          LoopLabel(context.l10n.market_secondaryScreensFact),
          LoopRecordCard(
            child: LoopFactLine(
              id: 'holder-count',
              label: context.l10n.market_secondaryScreensFact,
              fact: holders.holderCount,
              emphasize: true,
              formatter: (value) =>
                  loopFormatDecimal(value, maxFractionDigits: 0),
            ),
          ),
          LoopLabel(context.l10n.market_secondaryScreensLoopLabel),
          _MarketUnavailableLine(
            key: const ValueKey<String>('token-holders-distribution'),
            label: context
                .l10n
                .market_secondaryScreensTokenHoldersDistributionLabel,
            reasonCode: holders.distribution.reasonCode,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// token-trades
// ---------------------------------------------------------------------------

/// `token-trades` · the indexed pool swap tape.
///
/// The backend sends no counterparty address: `isOwn` is the only identity
/// fact. The prototype's 大单 segment is a local threshold filter on
/// `amountQuote`; its 聪明钱 segment has no backend and stays disabled.
class TradingActivityScreen extends ConsumerStatefulWidget {
  const TradingActivityScreen({required this.assetId, super.key, this.onBack});

  final String? assetId;
  final VoidCallback? onBack;

  /// The local threshold that marks a trade as 大单. It is a client-side view
  /// filter, never a server fact.
  static final Decimal largeTradeQuoteThreshold = Decimal.fromInt(10000);

  @override
  ConsumerState<TradingActivityScreen> createState() =>
      _TradingActivityScreenState();
}

class _TradingActivityScreenState extends ConsumerState<TradingActivityScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return _invalidAssetPage(
        'trades',
        context.l10n.market_secondaryScreensInvalidAssetPage3,
        widget.onBack,
      );
    }
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketTradesControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketTradesControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final page = state.value;
    final block = page?.trades;

    return LoopDashboardPage(
      key: ValueKey<String>('token-trades-$assetId'),
      onRefresh: ref
          .read(marketTradesControllerProvider(assetId).notifier)
          .reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: context.l10n.market_secondaryScreensTokenTradesFolioTitle,
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('token-trades-folio'),
        variant: LoopFolioVariant.quiet,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketTradesKicker,
        heading: block is MarketTradesAvailable
            ? context.l10n.market_secondaryScreensTokenTradesFolioHeading(
                block.items.length,
              )
            : context.l10n.market_secondaryScreensTokenTradesFolioHeading2,
        caption: context.l10n.market_secondaryScreensTokenTradesFolioCaption,
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('token-trades-capability-block'),
              title: context.l10n.market_screenMarketCapabilityBlockTitle,
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || block == null)
          LoopChainStateBlock(
            keyPrefix: 'token-trades',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref
                  .read(marketTradesControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else
          ...switch (block) {
            MarketTradesUnavailable(reasonCode: final reasonCode) => <Widget>[
              _MarketUnavailableLine(
                key: const ValueKey<String>('token-trades-unavailable'),
                label: context
                    .l10n
                    .market_secondaryScreensTokenTradesUnavailableLabel,
                reasonCode: reasonCode,
              ),
            ],
            MarketTradesAvailable() => _tradeSections(
              block,
              more: _morePages(assetId, block, state),
            ),
          },
      ],
    );
  }

  /// The trades scroll on to the last page (decision 0118).
  List<Widget> _morePages(
    String assetId,
    MarketTradesAvailable block,
    LoopChainResourceState<MarketTradesPage> state,
  ) {
    final controller = ref.read(
      marketTradesControllerProvider(assetId).notifier,
    );
    final cursor = block.nextCursor;
    if (controller.appendFailed && !state.busy) {
      return <Widget>[
        LoopInlineUnavailable(
          key: const ValueKey<String>('token-trades-more-failed'),
          message: LoopL10n
              .current
              .market_secondaryScreensTokenTradesMoreFailedMessage,
          onRetry: () => unawaited(controller.loadMore()),
        ),
      ];
    }
    if (cursor == null) {
      return const <Widget>[
        MarketListEnd(key: ValueKey<String>('token-trades-end')),
      ];
    }
    return <Widget>[
      LoopLoadMoreSentinel(
        key: const ValueKey<String>('token-trades-load-more'),
        cursor: cursor,
        onLoadMore: () => unawaited(controller.loadMore()),
      ),
      if (state.busy)
        const LoopSkeleton(
          key: ValueKey<String>('token-trades-loading-more'),
          type: LoopSkeletonType.record,
          rows: 2,
        ),
    ];
  }

  List<Widget> _tradeSections(
    MarketTradesAvailable block, {
    List<Widget> more = const <Widget>[],
  }) {
    final visible = _segment == 1
        ? block.items
              .where(
                (trade) =>
                    trade.amountQuote >=
                    TradingActivityScreen.largeTradeQuoteThreshold,
              )
              .toList(growable: false)
        : block.items;
    return <Widget>[
      MarketSegmentBar(
        ids: const <String>['all', 'large', 'smartMoney'],
        labels: <String>[
          LoopL10n.current.common_all,
          LoopL10n.current.market_secondaryScreensMarketSegmentBar,
          LoopL10n.current.market_secondaryScreensMarketSegmentBar2,
        ],
        selectedIndex: _segment,
        enabled: const <bool>[true, true, false],
        onSelected: (index) => setState(() => _segment = index),
        blockedMessages: <String?>[
          null,
          null,
          loopReasonCodeText('SMART_MONEY_RUNTIME_DEFERRED'),
        ],
      ),
      if (_segment == 2)
        _MarketUnavailableLine(
          key: ValueKey<String>('token-trades-smart-money'),
          label: LoopL10n
              .current
              .market_secondaryScreensTokenTradesSmartMoneyLabel,
          reasonCode: 'SMART_MONEY_RUNTIME_DEFERRED',
        )
      else if (visible.isEmpty)
        LoopEmptyState(
          key: const ValueKey<String>('token-trades-empty'),
          illustration: LoopIllustration.history,
          compact: true,
          title: _segment == 1
              ? LoopL10n.current.market_secondaryScreensTokenTradesEmptyTitle
              : LoopL10n.current.market_secondaryScreensTokenTradesEmptyTitle2,
          message: _segment == 1
              ? LoopL10n.current.market_secondaryScreensTokenTradesEmptyMessage
              : LoopL10n
                    .current
                    .market_secondaryScreensTokenTradesEmptyMessage2,
        )
      else
        LoopRecordGroup(
          rows: <LoopRecordRow>[for (final trade in visible) _tradeRow(trade)],
        ),
      ...more,
      _FreshnessFooter(freshness: block.freshness),
    ];
  }

  LoopRecordRow _tradeRow(MarketTrade trade) {
    final isBuy = trade.direction == MarketTradeDirection.buy;
    final isLarge =
        trade.amountQuote >= TradingActivityScreen.largeTradeQuoteThreshold;
    return LoopRecordRow(
      key: ValueKey<String>('trade-${trade.tradeId}'),
      // `.row-ico` with the direction arrow: the prototype's tape is read by
      // its leading marks before it is read by its words.
      leading: MarketDirectionAvatar(inbound: isBuy),
      title:
          '${isBuy ? LoopL10n.current.common_buy : LoopL10n.current.common_sell} '
          '${loopFormatDecimal(trade.amountQuote, maxFractionDigits: 2)} '
          '${trade.quoteSymbol}',
      subtitle: <String>[
        if (trade.isOwn) LoopL10n.current.common_me,
        loopConfirmationLabel(trade.status),
        if (trade.confirmations != null)
          LoopL10n.current.market_secondaryScreensLoopRecordRow(
            loopGroupedFigure(trade.confirmations.toString()),
          ),
        LoopL10n.current.market_secondaryScreensLoopRecordRow2(
          loopGroupedFigure(trade.blockNumber.toString()),
        ),
        loopRelativeTime(trade.blockTimestamp),
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: loopFormatDecimal(trade.amountAsset),
      trailingCaptionUp: isBuy,
      trailingCaption: isBuy
          ? LoopL10n.current.market_secondaryScreensTrailingCaption
          : LoopL10n.current.market_secondaryScreensTrailingCaption2,
      trailingBadge: trade.status == LoopConfirmationStatus.reorged
          ? LoopBadge(
              LoopL10n.current.common_reverted,
              kind: LoopBadgeKind.down,
            )
          : isLarge
          ? LoopBadge(LoopL10n.current.market_secondaryScreensMarketSegmentBar)
          : null,
    );
  }
}

class _FreshnessFooter extends StatelessWidget {
  const _FreshnessFooter({required this.freshness});

  final LoopIndexerFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final lag = freshness.lagBlocks;
    return LoopProvenanceFooter(
      key: const ValueKey<String>('indexer-freshness'),
      text: <String>[
        // The block number on the same line already groups; a figure that
        // does not reads as a different kind of number.
        context.l10n.market_secondaryScreensLoopProvenanceFooter(
          loopGroupedFigure(freshness.indexerBlockNumber.toString()),
        ),
        if (lag != null)
          context.l10n.market_secondaryScreensLoopProvenanceFooter2(
            loopGroupedFigure(lag.toString()),
          ),
        context.l10n.community_aiBuild2(loopRelativeTime(freshness.observedAt)),
      ].join(' · '),
    );
  }
}

// ---------------------------------------------------------------------------
// new-pairs
// ---------------------------------------------------------------------------

/// `new-pairs` · GeckoTerminal is disabled by default, so the whole page is
/// unavailable and states the server's `reasonCode`.
class NewPairsScreen extends ConsumerStatefulWidget {
  const NewPairsScreen({super.key, this.onBack, this.onNavigate});

  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  @override
  ConsumerState<NewPairsScreen> createState() => _NewPairsScreenState();
}

class _NewPairsScreenState extends ConsumerState<NewPairsScreen> {
  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketNewPairsControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(marketNewPairsControllerProvider.notifier).load());
        }
      });
    }
    final page = state.value;
    final block = page?.newPairs;

    return LoopDashboardPage(
      key: const ValueKey<String>('new-pairs-screen'),
      onRefresh: ref.read(marketNewPairsControllerProvider.notifier).reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      title: context.l10n.market_secondaryScreensNewPairsScreenTitle,
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        key: const ValueKey<String>('new-pairs-folio'),
        variant: LoopFolioVariant.quiet,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketNewPairsKicker,
        // While the list is still being read the hero states that, rather
        // than repeating the page's own name back at the reader (walkthrough
        // 2026-09-23, d05).
        heading: block is MarketNewPairsAvailable
            ? context.l10n.market_secondaryScreensNewPairsFolioHeading(
                block.items.length,
              )
            : state.isReady
            ? context.l10n.market_secondaryScreensNewPairsFolioHeading2
            : context.l10n.market_secondaryScreensNewPairsFolioHeading3,
        caption: context.l10n.market_secondaryScreensNewPairsFolioCaption,
        // `.folio-stamp`: this page's subject is the risk, and the stamp is
        // where the prototype states it.
        stamp: marketNewPairsStamp,
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('new-pairs-capability-block'),
              title: context.l10n.market_screenMarketCapabilityBlockTitle,
            )
          : null,
      sections: <Widget>[
        if (!state.isReady || page == null || block == null)
          LoopChainStateBlock(
            keyPrefix: 'new-pairs',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref.read(marketNewPairsControllerProvider.notifier).reload(),
            ),
          )
        else
          ...switch (block) {
            // No provider means the whole page is unavailable, with the
            // server's reason — never an empty list.
            MarketNewPairsUnavailable(reasonCode: final reasonCode) => <Widget>[
              _MarketUnavailableLine(
                key: const ValueKey<String>('new-pairs-unavailable'),
                label: context
                    .l10n
                    .market_secondaryScreensNewPairsUnavailableLabel,
                reasonCode: reasonCode,
              ),
            ],
            MarketNewPairsAvailable() => <Widget>[
              if (block.items.isEmpty)
                LoopEmptyState(
                  key: ValueKey<String>('new-pairs-empty'),
                  illustration: LoopIllustration.search,
                  compact: true,
                  title: context.l10n.market_secondaryScreensNewPairsEmptyTitle,
                  message:
                      context.l10n.market_secondaryScreensNewPairsEmptyMessage,
                )
              else
                LoopRecordGroup(
                  rows: <LoopRecordRow>[
                    for (final pair in block.items)
                      marketNewPairRow(
                        pair,
                        // The star is this page's write, so this page is the
                        // one that hands it.
                        watchAction: pair.registryAssetId == null
                            ? null
                            : _NewPairWatchAction(
                                assetId: pair.registryAssetId!,
                              ),
                        onTap: !pair.opensDetail
                            ? null
                            : () => _open(
                                MarketAssetRoute.token(pair.registryAssetId!),
                              ),
                      ),
                  ],
                ),
              // Both identifier forms are listed now, so what is left out is
              // a row the provider sent in neither shape. It is normally zero;
              // when it is not, saying so keeps the page from passing a
              // partial list off as all of it.
              if (block.omittedCount > 0)
                LoopNotice(
                  key: const ValueKey<String>('new-pairs-omitted'),
                  title: context.l10n
                      .market_secondaryScreensNewPairsOmittedTitle(
                        block.omittedCount,
                      ),
                  body: context.l10n.market_secondaryScreensNewPairsOmittedBody,
                ),
              LoopProvenanceFooter(
                text: context.l10n.market_secondaryScreensText(
                  loopFactSourceLabel(block.source),
                  loopRelativeTime(block.fetchedAt),
                ),
              ),
            ],
          },
        if (page != null) ...<Widget>[
          LoopLabel(context.l10n.market_secondaryScreensLoopLabel2),
          _MarketUnavailableLine(
            key: const ValueKey<String>('new-pairs-risk-screening'),
            label:
                context.l10n.market_secondaryScreensNewPairsRiskScreeningLabel,
            reasonCode: page.riskScreening.reasonCode,
          ),
        ],
        LoopNotice(
          key: ValueKey<String>('new-pairs-notice'),
          title: context.l10n.market_secondaryScreensNewPairsNoticeTitle,
          body: context.l10n.market_secondaryScreensNewPairsNoticeBody,
          tone: LoopNoticeTone.warn,
        ),
      ],
    );
  }
}

/// The 加自选 action on one 新币发现 row.
///
/// The row could only be read before this. It writes through the same
/// controller the Token page's star does, so both say the same thing about
/// the same outcome, and it appears only where LOOP already knows which
/// registry asset the row's base token is: an address alone is not an asset
/// id, and the write would be refused as an unregistered asset.
///
/// The list is not read when the page opens. One document holds every
/// membership on this screen, and reading it once per row would be a hundred
/// reads of the same thing; the star therefore starts in its third state —
/// not known — and the first press reads before it writes, which is the
/// behaviour the star already documents.
class _NewPairWatchAction extends ConsumerWidget {
  const _NewPairWatchAction({required this.assetId});

  final String assetId;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(watchlistMembershipControllerProvider(assetId).notifier)
        .toggle();
    if (!context.mounted) return;
    showWatchlistToggleToast(context, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The watchlist is a different resource from the market read this page
    // ran on: its own capability and its own gateway decide this control, so
    // a market outage never claims an asset is unwatched.
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.watchlist),
    );
    final mode = ref.watch(watchlistGatewayProvider).mode;
    final membership = ref.watch(
      watchlistMembershipControllerProvider(assetId),
    );
    final blocked =
        loopChainCapabilityBlocks(mode, capability) ||
        membership.phase == LoopChainViewPhase.unavailable;
    return LoopIconButton(
      key: ValueKey<String>('new-pair-watchlist-$assetId'),
      icon: 'star',
      label: blocked
          ? context.l10n.market_secondaryScreensLabel2
          : membership.actionLabel,
      color: membership.isWatched ? LoopColors.yellow : null,
      // An unread list has no on/off state to report; claiming `false` would
      // say the asset is not watched.
      toggled: blocked || !membership.isKnown ? null : membership.isWatched,
      onPressed: blocked || membership.busy
          ? null
          : () => unawaited(_toggle(context, ref)),
    );
  }
}

// ---------------------------------------------------------------------------
// smart-money
// ---------------------------------------------------------------------------

/// `smart-money` · always unavailable in this step (D21).
class SmartMoneyScreen extends ConsumerStatefulWidget {
  const SmartMoneyScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<SmartMoneyScreen> createState() => _SmartMoneyScreenState();
}

class _SmartMoneyScreenState extends ConsumerState<SmartMoneyScreen> {
  @override
  Widget build(BuildContext context) {
    final blocked = _marketBlocked(ref);
    final state = ref.watch(marketSmartMoneyControllerProvider);
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketSmartMoneyControllerProvider.notifier).load(),
          );
        }
      });
    }
    final fact = state.value;

    return LoopFocusPage(
      key: const ValueKey<String>('smart-money-screen'),
      archetype: LoopPageArchetype.listing,
      title: context.l10n.market_screenMarketSmartMoneyEntryTitle,
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: ValueKey<String>('smart-money-folio'),
        variant: LoopFolioVariant.quiet,
        ring: false,
        archetype: LoopFolioArchetype.listing,
        kicker: marketSmartMoneyKicker,
        heading: context.l10n.market_secondaryScreensSmartMoneyFolioHeading,
        caption: context.l10n.market_secondaryScreensSmartMoneyFolioCaption,
      ),
      block: blocked
          ? _marketPageBlock(
              ref,
              key: const ValueKey<String>('smart-money-capability-block'),
              title: context.l10n.market_screenMarketCapabilityBlockTitle,
            )
          : null,
      body: <Widget>[
        if (!state.isReady || fact == null)
          LoopChainStateBlock(
            keyPrefix: 'smart-money',
            phase: state.phase,
            failureKind: state.failureKind,
            rows: 1,
            onRetry: () => unawaited(
              ref.read(marketSmartMoneyControllerProvider.notifier).reload(),
            ),
          )
        else ...<Widget>[
          // The prototype's two groups, in its order. Neither is invented:
          // both state the server's own reason where its rows would be, so
          // the page keeps the shape it will have once the data exists.
          LoopLabel(context.l10n.market_secondaryScreensLoopLabel3),
          _MarketUnavailableLine(
            key: const ValueKey<String>('smart-money-unavailable'),
            label:
                context.l10n.market_secondaryScreensSmartMoneyUnavailableLabel,
            reasonCode: fact.reasonCode,
          ),
          LoopLabel(context.l10n.market_secondaryScreensLoopLabel4),
          // The server's own sentence is stated once, by the block above.
          // This one says what it depends on instead of repeating it.
          LoopEmptyState(
            key: ValueKey<String>('smart-money-moves-unavailable'),
            illustration: LoopIllustration.rank,
            compact: true,
            title: context
                .l10n
                .market_secondaryScreensSmartMoneyMovesUnavailableTitle,
            message: context
                .l10n
                .market_secondaryScreensSmartMoneyMovesUnavailableMessage,
          ),
        ],
        // S278 · decision 0236: an explanation, behind (i).
        LoopProvenanceFooter(
          key: ValueKey<String>('smart-money-notice'),
          label: context.l10n.common_about,
          title: context.l10n.market_secondaryScreensSmartMoneyNoticeTitle,
          text: context.l10n.market_secondaryScreensSmartMoneyNoticeText,
        ),
      ],
    );
  }
}

/// One block LOOP could not read, said in one weak line (decision 0171,
/// docs/33 L6): what is missing, then the server's own reason. It replaces
/// the block-sized `LoopUnavailableLine` strip on the data-dense market
/// pages; it never renders a figure, a zero or a dash.
class _MarketUnavailableLine extends StatelessWidget {
  const _MarketUnavailableLine({
    required this.label,
    required this.reasonCode,
    super.key,
  });

  final String label;

  /// `null` when the server stated none; the neutral sentence is used then.
  final String? reasonCode;

  @override
  Widget build(BuildContext context) => LoopInlineUnavailable(
    message: '$label · ${loopReasonCodeText(reasonCode)}',
    maxLines: 3,
  );
}
