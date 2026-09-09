import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/notifications/notification_controllers.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// `token` · one registry asset's facts.
///
/// The route identity is the canonical `assetId`; a missing or malformed one
/// fails closed instead of substituting another asset. Every figure carries
/// its source and observation time, and the Swap entry point is rendered only
/// when the server says `capability.swappable` — which it never does before
/// D15.
class TokenDetailScreen extends ConsumerStatefulWidget {
  const TokenDetailScreen({
    required this.assetId,
    super.key,
    this.onNavigate,
    this.onBack,
  });

  final String? assetId;
  final void Function(String location)? onNavigate;
  final VoidCallback? onBack;

  @override
  ConsumerState<TokenDetailScreen> createState() => _TokenDetailScreenState();
}

class _TokenDetailScreenState extends ConsumerState<TokenDetailScreen> {
  LoopCandleInterval _interval = LoopCandleInterval.oneHour;

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
    final assetId = widget.assetId;
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return LoopFocusPage(
        key: const ValueKey<String>('token-invalid-route'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这个资产',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmpty(
            key: ValueKey<String>('token-invalid-identity'),
            icon: 'warn',
            message: '路由中没有可用的资产标识',
            reason: 'Token 页只接受规范的 CAIP assetId。未请求任何行情，也没有回退到其他资产。',
          ),
        ],
      );
    }

    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final mode = ref.watch(marketReadGatewayProvider).mode;
    final blocked = loopChainCapabilityBlocks(mode, capability);
    final state = ref.watch(marketAssetControllerProvider(assetId));
    if (!blocked && state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketAssetControllerProvider(assetId).notifier).load(),
          );
        }
      });
    }
    final detail = state.value;

    return LoopDashboardPage(
      key: ValueKey<String>('token-screen-$assetId'),
      archetype: LoopPageArchetype.record,
      title: detail?.asset.symbol ?? 'Token',
      kicker: detail?.asset.name,
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('token-alerts-action'),
          icon: 'bell',
          label: '价格提醒',
          onPressed: () => _open(MarketAssetRoute.alerts(assetId)),
        ),
        LoopIconButton(
          key: const ValueKey<String>('token-watchlist-action'),
          icon: 'star',
          label: '管理自选',
          onPressed: () => _open('/market/watchlist'),
        ),
      ],
      primary: _TokenHero(assetId: assetId, detail: detail),
      sections: <Widget>[
        if (blocked)
          LoopUnavailableCard(
            key: const ValueKey<String>('token-capability-block'),
            label: '行情模块当前不可用',
            reasonCode: capability.reasonCode ?? 'MARKET_RUNTIME_UNAVAILABLE',
          )
        else if (!state.isReady || detail == null)
          LoopChainStateBlock(
            keyPrefix: 'token',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '这个资产还没有可展示的事实',
            onRetry: () => unawaited(
              ref
                  .read(marketAssetControllerProvider(assetId).notifier)
                  .reload(),
            ),
          )
        else if (detail.capability.blocksEntirePage)
          LoopUnavailableCard(
            key: const ValueKey<String>('token-asset-blocked'),
            label: '该资产已被标记为不可展示',
            reasonCode: detail.capability.reasonCode ?? 'ASSET_BLOCKED',
          )
        else ...<Widget>[
          if (detail.capability.suppressesLiveFigures)
            LoopUnavailableCard(
              key: const ValueKey<String>('token-live-suppressed'),
              label: '链上读取暂时不可用',
              reasonCode:
                  detail.capability.reasonCode ??
                  'BSC_CHAIN_RUNTIME_UNAVAILABLE',
            ),
          // `.tcard.tcard-signature.tcard-token-hero`. The card carries the
          // identity and the small close line only: the price, the change and
          // the three metrics are rendered once each, with their own source and
          // observation time, in the hero and the fact list below. Repeating
          // them here would put the same figure on screen three times without
          // its provenance.
          LoopTokenCard(
            key: const ValueKey<String>('token-card'),
            state: detail.capability.suppressesLiveFigures
                ? LoopTokenCardState.partial
                : LoopTokenCardState.normal,
            model: LoopTokenCardModel(
              symbol: detail.asset.symbol,
              identifier: loopTruncatedAssetId(assetId),
              chartRangeLabel: '1H · 最近 $loopSparklineWindow 根收盘价',
              chart: TokenCardSparkline(
                assetId: assetId,
                keyPrefix: 'token-card-chart',
              ),
            ),
            actions: <LoopTokenCardAction>[
              LoopTokenCardAction(
                '图表',
                onTap: () => _open(MarketAssetRoute.chart(assetId)),
              ),
              if (detail.community case MarketCommunityBound(
                communityId: final communityId,
              ))
                LoopTokenCardAction(
                  '社区',
                  onTap: () => _open('/community/profile?id=$communityId'),
                ),
            ],
          ),
          const LoopLabel('K 线'),
          _TokenCandleBlock(
            assetId: assetId,
            interval: _interval,
            onIntervalChanged: (value) => setState(() => _interval = value),
            onExpand: () => _open(MarketAssetRoute.chart(assetId)),
          ),
          const LoopLabel('行情事实'),
          LoopSurfaceCard(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopFactLine(label: '市值', fact: detail.marketCap),
                LoopFactLine(label: '完全稀释估值', fact: detail.fdv),
                LoopFactLine(label: '流动性', fact: detail.liquidityUsd),
                LoopFactLine(label: '24H 成交额', fact: detail.volume24h),
                LoopFactLine(label: '持有人数', fact: detail.holderCount),
              ],
            ),
          ),
          _PrimaryPairCard(pair: detail.primaryPair),
          const LoopLabel('社区'),
          _CommunityBlock(
            block: detail.community,
            onOpenCommunity: (communityId) =>
                _open('/community/profile?id=$communityId'),
          ),
          const LoopLabel('挖矿数据'),
          const LoopUnavailableCard(
            key: ValueKey<String>('token-mining-unavailable'),
            label: 'Mining Weight 与预估收益不可用',
            reasonCode: 'MINING_RUNTIME_DEFERRED',
          ),
          const LoopLabel('合约事实'),
          _SecurityBlock(block: detail.security),
          const LoopNotice(
            key: ValueKey<String>('token-facts-notice'),
            title: '只给带来源与时间的事实',
            body: '这里不输出评级、评分或综合结论。缺少某一项表示来源没有报告它，不代表安全或不安全。',
          ),
          const LoopLabel('通知'),
          _TokenNotificationFeed(assetId: assetId),
          const LoopLabel('更多'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('token-holders-entry'),
                title: '持有人分布',
                subtitle: '持有人总数来自 GoPlus；分布与集中度本步没有来源',
                onTap: () => _open(MarketAssetRoute.holders(assetId)),
              ),
              LoopRecordRow(
                key: const ValueKey<String>('token-trades-entry'),
                title: '交易活动',
                subtitle: '已登记池的链上成交，带确认状态',
                onTap: () => _open(MarketAssetRoute.trades(assetId)),
              ),
            ],
          ),
          // The only gate for a Swap entry point. The backend pins it to false
          // until D15, so no buy/sell control is rendered here.
          if (detail.capability.swappable)
            LoopButton(
              key: const ValueKey<String>('token-swap-entry'),
              label: '兑换',
              primary: true,
              block: true,
              onPressed: () => _open('/wallet/swap'),
            )
          else
            LoopUnavailableCard(
              key: const ValueKey<String>('token-swap-unavailable'),
              label: '买入 / 卖出入口未开放',
              reasonCode:
                  detail.capability.reasonCode ?? 'SWAP_MODULE_NOT_DELIVERED',
            ),
        ],
      ],
    );
  }
}

class _TokenHero extends StatelessWidget {
  const _TokenHero({required this.assetId, required this.detail});

  final String assetId;
  final MarketAssetDetail? detail;

  @override
  Widget build(BuildContext context) {
    final resolved = detail;
    // A blocked asset shows no fact at all, not even in the hero.
    if (resolved != null && resolved.capability.blocksEntirePage) {
      return LoopFolioPrimary(
        key: const ValueKey<String>('token-folio-blocked'),
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.record,
        kicker: 'TOKEN FACTS',
        heading: resolved.asset.symbol,
        caption: loopReasonCodeText(
          resolved.capability.reasonCode ?? 'ASSET_BLOCKED',
        ),
      );
    }
    if (resolved == null) {
      return LoopFolioPrimary(
        key: const ValueKey<String>('token-folio-pending'),
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.record,
        kicker: 'TOKEN FACTS',
        heading: loopTruncatedAssetId(assetId),
        caption: '资产事实尚未读取成功，本页不展示任何推测数字。',
      );
    }
    final price = resolved.price;
    final change = resolved.priceChange24h;
    final priceValue = price.value;
    final changeValue = change.value;
    return LoopFolioPrimary(
      key: const ValueKey<String>('token-folio'),
      variant: LoopFolioVariant.lime,
      archetype: LoopFolioArchetype.record,
      kicker: 'TOKEN FACTS',
      heading: priceValue == null
          ? resolved.asset.symbol
          : loopFormatUsd(priceValue),
      caption: priceValue == null
          ? loopReasonCodeText(price.reasonCode)
          : '${resolved.asset.name} · ${loopFactProvenance(price)}',
      stamp: changeValue == null ? null : loopFormatPercent(changeValue),
      trailing: LoopTokenLogo(
        assetSymbol: resolved.asset.symbol,
        fallbackMonogram: resolved.asset.symbol,
        size: 44,
      ),
    );
  }
}

class _TokenCandleBlock extends ConsumerWidget {
  const _TokenCandleBlock({
    required this.assetId,
    required this.interval,
    required this.onIntervalChanged,
    required this.onExpand,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final ValueChanged<LoopCandleInterval> onIntervalChanged;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TokenCandleSection(
      assetId: assetId,
      interval: interval,
      onIntervalChanged: onIntervalChanged,
      trailing: LoopIconButton(
        key: const ValueKey<String>('token-chart-expand'),
        icon: 'expand',
        label: '打开全屏 K 线',
        onPressed: onExpand,
      ),
    );
  }
}

/// The candle block shared by `token` and `chart-full`.
class TokenCandleSection extends ConsumerStatefulWidget {
  const TokenCandleSection({
    required this.assetId,
    required this.interval,
    required this.onIntervalChanged,
    super.key,
    this.trailing,
    this.height = 210,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final ValueChanged<LoopCandleInterval> onIntervalChanged;
  final Widget? trailing;
  final double height;

  @override
  ConsumerState<TokenCandleSection> createState() => _TokenCandleSectionState();
}

class _TokenCandleSectionState extends ConsumerState<TokenCandleSection> {
  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetId,
      interval: widget.interval,
    );
    final state = ref.watch(marketCandlesControllerProvider(request));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketCandlesControllerProvider(request).notifier).load(),
          );
        }
      });
    }
    final series = state.value;
    final block = series?.candles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopSurfaceCard(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      block is MarketCandlesAvailable ? block.priceUnit : 'K 线',
                      style: LoopMono.label,
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
              const SizedBox(height: 8),
              if (!state.isReady || block == null)
                LoopChainStateBlock(
                  keyPrefix: 'candles',
                  phase: state.phase,
                  failureKind: state.failureKind,
                  skeleton: LoopSkeletonType.chart,
                  emptyMessage: '这个区间没有成交',
                  onRetry: () => unawaited(
                    ref
                        .read(marketCandlesControllerProvider(request).notifier)
                        .reload(),
                  ),
                )
              else
                switch (block) {
                  MarketCandlesUnavailable(reasonCode: final reasonCode) =>
                    LoopUnavailableCard(
                      key: const ValueKey<String>('candles-unavailable'),
                      label: 'K 线不可用',
                      reasonCode: reasonCode,
                      margin: EdgeInsets.zero,
                    ),
                  MarketCandlesAvailable() => _CandleBody(
                    block: block,
                    height: widget.height,
                  ),
                },
            ],
          ),
        ),
        _IntervalBar(
          selected: widget.interval,
          onSelected: widget.onIntervalChanged,
        ),
      ],
    );
  }
}

class _CandleBody extends StatelessWidget {
  const _CandleBody({required this.block, required this.height});

  final MarketCandlesAvailable block;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (block.items.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('candles-empty'),
        message: '这个区间没有成交',
        reason: '只画有成交的桶，空桶不会补 0。',
        margin: EdgeInsets.zero,
      );
    }
    final last = block.items.last;
    final marker = loopFactQualityMarker(block.quality);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: <Widget>[
            Text('O ${loopFormatDecimal(last.open)}', style: LoopMono.body),
            Text('H ${loopFormatDecimal(last.high)}', style: LoopMono.body),
            Text('L ${loopFormatDecimal(last.low)}', style: LoopMono.body),
            Text(
              'C ${loopFormatDecimal(last.close)}',
              style: LoopMono.body.copyWith(
                color: last.isUp ? LoopColors.lime : LoopColors.chalk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LoopCandleChart(
          key: const ValueKey<String>('token-candle-chart'),
          candles: block.items,
          height: height,
          semanticLabel:
              '${block.items.length} 根 K 线，单位 ${block.priceUnit}'
              '${last.isOpen ? '，最后一根尚未收盘' : ''}',
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            if (marker != null) ...<Widget>[
              LoopBadge(
                marker,
                kind: block.isDerived ? LoopBadgeKind.mute : LoopBadgeKind.down,
              ),
              const SizedBox(width: 8),
            ],
            if (last.isOpen) ...<Widget>[
              const LoopBadge(
                '最后一根进行中',
                key: ValueKey<String>('candles-open-marker'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                <String>[
                  if (block.isDerived) marketCandleLabelText(block.labelKey),
                  '来源 ${loopFactSourceLabel(block.source)}',
                  '观察于 ${loopRelativeTime(block.fetchedAt)}',
                  '池 ${loopTruncatedAddress(block.pool.address)}',
                ].where((part) => part.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IntervalBar extends StatelessWidget {
  const _IntervalBar({required this.selected, required this.onSelected});

  final LoopCandleInterval selected;
  final ValueChanged<LoopCandleInterval> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: <Widget>[
          for (final interval in LoopCandleInterval.values) ...<Widget>[
            LoopSeg(
              key: ValueKey<String>('candle-interval-${interval.wireName}'),
              label: interval.label,
              selected: interval == selected,
              onSelected: () => onSelected(interval),
            ),
            if (interval != LoopCandleInterval.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PrimaryPairCard extends StatelessWidget {
  const _PrimaryPairCard({required this.pair});

  final MarketPrimaryPair? pair;

  @override
  Widget build(BuildContext context) {
    final resolved = pair;
    if (resolved == null) {
      return const LoopUnavailableCard(
        key: ValueKey<String>('token-primary-pair-unavailable'),
        label: '没有以该资产为 base 的交易对',
        reasonCode: 'MARKET_PAIR_NOT_FOUND',
      );
    }
    return LoopSurfaceCard(
      key: const ValueKey<String>('token-primary-pair'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('主交易对', style: LoopMono.label),
          const SizedBox(height: 6),
          Text(
            '${resolved.dexId} · 报价币 ${resolved.quoteTokenSymbol}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            loopTruncatedAddress(resolved.pairAddress),
            style: LoopMono.stamp,
          ),
        ],
      ),
    );
  }
}

class _CommunityBlock extends StatelessWidget {
  const _CommunityBlock({required this.block, required this.onOpenCommunity});

  final MarketCommunityBlock block;
  final void Function(String communityId) onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketCommunityUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('token-community-unavailable'),
          label: '还没有绑定的 LOOP 社区',
          reasonCode: reasonCode,
        );
      case MarketCommunityBound(
        communityId: final communityId,
        name: final name,
        memberCount: final memberCount,
      ):
        return LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('token-community-entry'),
              title: '进入 LOOP 社区',
              subtitle: '$name · $memberCount 名成员',
              onTap: () => onOpenCommunity(communityId),
            ),
          ],
        );
    }
  }
}

class _SecurityBlock extends StatelessWidget {
  const _SecurityBlock({required this.block});

  final MarketSecurityBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block) {
      case MarketSecurityUnavailable(reasonCode: final reasonCode):
        return LoopUnavailableCard(
          key: const ValueKey<String>('token-security-unavailable'),
          label: '合约事实不可用',
          reasonCode: reasonCode,
        );
      case MarketSecurityAvailable(facts: final facts):
        if (facts.isEmpty) {
          return const LoopEmpty(
            key: ValueKey<String>('token-security-empty'),
            message: '来源没有报告任何合约事实',
            reason: '缺少某一项只表示来源没有报告它，不代表安全或不安全。',
          );
        }
        return LoopSurfaceCard(
          key: const ValueKey<String>('token-security-facts'),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final fact in facts) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${marketSecurityFactText(fact)} —— '
                    '来源 ${loopFactSourceLabel(fact.source)}，'
                    '观察于 ${loopRelativeTime(fact.observedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// The context notification entry point on the token page.
///
/// There is no standalone notification centre: price-alert notifications are
/// read here and on the `alerts` page.
class _TokenNotificationFeed extends ConsumerStatefulWidget {
  const _TokenNotificationFeed({required this.assetId});

  final String assetId;

  @override
  ConsumerState<_TokenNotificationFeed> createState() =>
      _TokenNotificationFeedState();
}

class _TokenNotificationFeedState
    extends ConsumerState<_TokenNotificationFeed> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFeedControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(notificationFeedControllerProvider.notifier).load(),
          );
        }
      });
    }
    final feed = state.value;
    if (feed == null) {
      return LoopChainStateBlock(
        keyPrefix: 'token-feed',
        phase: state.phase,
        failureKind: state.failureKind,
        rows: 1,
        emptyMessage: '还没有与这个资产相关的通知',
        onRetry: () => unawaited(
          ref.read(notificationFeedControllerProvider.notifier).reload(),
        ),
      );
    }
    final entries = feed.priceAlerts
        .where((entry) => entry.contextParams['assetId'] == widget.assetId)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('token-feed-empty'),
        message: '还没有与这个资产相关的通知',
        reason: '价格提醒触发后会出现在这里；推送通道尚未接入。',
      );
    }
    return LoopRecordGroup(
      rows: <LoopRecordRow>[
        for (final entry in entries)
          LoopRecordRow(
            key: ValueKey<String>('token-feed-${entry.notificationId}'),
            title: _notificationTitle(entry),
            subtitle: _notificationDetail(entry),
            trailingBadge: entry.isUnread ? const LoopBadge('未读') : null,
            onTap: entry.isUnread
                ? () => unawaited(
                    ref
                        .read(notificationFeedControllerProvider.notifier)
                        .markRead(entry.notificationId),
                  )
                : null,
          ),
      ],
    );
  }
}

String _notificationTitle(LoopNotificationEntry entry) {
  final symbol = entry.payload['symbol'];
  final threshold = entry.payload['threshold'];
  final observed = entry.payload['observedValue'];
  if (symbol == null || threshold == null || observed == null) {
    return '价格提醒已触发';
  }
  return '$symbol 触发 $threshold（观察值 $observed）';
}

String _notificationDetail(LoopNotificationEntry entry) {
  final source = entry.source;
  final observedAt = entry.observedAt;
  return <String>[
    if (source != null) '来源 $source',
    if (observedAt != null) '观察于 ${loopRelativeTime(observedAt)}',
  ].join(' · ');
}
