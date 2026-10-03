import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/scoped_assets_controller.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_incremental_list.dart';

export 'scoped_assets_controller.dart' show ScopedAssetsScope;

/// Six source records per batch. A record confirms membership in a scope;
/// only the separate market read can publish a price or a token identity.
class ScopedAssetsScreen extends ConsumerWidget {
  const ScopedAssetsScreen({
    required this.scope,
    super.key,
    this.title = '情报',
    this.titleWidget,
    this.tabPage = true,
    this.onNavigate,
    this.sectionsPrefix = const [],
    this.actions = const [],
  });
  final ScopedAssetsScope scope;
  final String title;
  final Widget? titleWidget;
  final bool tabPage;
  final void Function(String)? onNavigate;
  final List<Widget> sectionsPrefix;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = scope == ScopedAssetsScope.platform;
    final provider = platform
        ? platformScopedAssetsControllerProvider
        : communityScopedAssetsControllerProvider;
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final sourceCapability = ref.watch(
      loopCapabilityProvider(
        platform ? LoopV2CapabilityId.launch : LoopV2CapabilityId.community,
      ),
    );
    final marketCapability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.marketRead),
    );
    final sourceBlocked = platform
        ? launchCapabilityBlocks(sourceCapability)
        : communityCapabilityBlocks(
            ref.watch(communityGatewayProvider).mode,
            sourceCapability,
          );
    // Watch the source gateway even for Launch so a pending authenticated
    // adapter is rebuilt before this screen starts the read.
    if (platform) ref.watch(launchGatewayProvider);
    final marketBlocked = loopChainCapabilityBlocks(
      ref.watch(marketReadGatewayProvider).mode,
      marketCapability,
    );
    final blocked = sourceBlocked || marketBlocked;
    if (!blocked && !state.initialized && !state.loading) {
      scheduleMicrotask(() {
        if (context.mounted) unawaited(controller.load());
      });
    }
    final prefix = platform ? 'platform-assets' : 'community-assets';
    final pageBlock = blocked
        ? LoopCapabilityPageBlock.of(
            title: '${platform ? '平台 MEME' : '社区资产'}当前不可用',
            capability: sourceBlocked ? sourceCapability : marketCapability,
            fallbackReasonCode: sourceBlocked
                ? (platform
                      ? 'LAUNCH_RUNTIME_UNAVAILABLE'
                      : 'COMMUNITY_RUNTIME_UNAVAILABLE')
                : 'MARKET_RUNTIME_UNAVAILABLE',
          )
        : null;

    return LoopIncrementalList(
      canLoadMore: !blocked && state.hasNext,
      loading: state.loading,
      failed: state.failure != null,
      onLoadMore: () => unawaited(controller.next()),
      child: LoopDashboardPage(
        key: ValueKey(prefix),
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        tabPage: tabPage,
        archetype: LoopPageArchetype.listing,
        onRefresh: blocked ? null : controller.reload,
        updating: state.loading && state.items.isNotEmpty,
        block: pageBlock == null
            ? null
            : sectionsPrefix.isEmpty
            ? pageBlock
            : Column(
                children: [
                  ...sectionsPrefix,
                  Expanded(child: pageBlock),
                ],
              ),
        sections: [
          ...sectionsPrefix,
          if (sectionsPrefix.isEmpty) LoopLabel(platform ? '平台 MEME' : '社区资产'),
          const SizedBox(height: 8),
          if (state.notice != null)
            LoopNotice(icon: 'info', body: state.notice!),
          if (state.failure != null)
            LoopEmpty(
              message: '目录暂时读不到',
              reason: state.failure,
              action: LoopButton(
                label: '重试',
                onPressed: state.loading
                    ? null
                    : () => unawaited(controller.retry()),
              ),
            ),
          if (state.loading && state.items.isEmpty)
            const LoopSkeleton(type: LoopSkeletonType.priceRow, rows: 6)
          else if (state.items.isEmpty && state.failure == null)
            LoopEmpty(
              message: !state.initialized
                  ? '资料尚未读取'
                  : state.continuationPending
                  ? '上滑继续加载资产'
                  : platform
                  ? '已读取的目录没有发射项目'
                  : '已读取的目录没有社区',
            ),
          for (final entry in state.items) ...[
            _entry(context, entry),
            LoopProvenanceFooter(
              text: '${platform ? '发射项目' : '绑定社区'}：${entry.label}',
            ),
          ],
          if (state.items.isNotEmpty)
            LoopProvenanceFooter(
              text: platform ? '归属读自已加载发射项目的链上代币配置' : '归属读自已加载社区的绑定资产',
            ),
          if (state.loading && state.items.isNotEmpty)
            const LoopListLoadingFooter()
          else if (!blocked && state.failure == null && state.hasNext)
            LoopListLoadMoreFooter(
              onLoadMore: () => unawaited(controller.next()),
            ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, ScopedAssetEntry entry) {
    final detail = entry.detail;
    if (detail == null) {
      return LoopRecordGroup(
        rows: [
          LoopRecordRow(
            key: ValueKey('scoped-asset-${entry.sourceId}'),
            title: entry.assetId == null
                ? entry.label
                : loopTruncatedAssetId(entry.assetId!),
            subtitle: entry.reason ?? '行情暂时读不到',
            subtitleMaxLines: 2,
            chevron: false,
          ),
        ],
      );
    }
    final asset = detail.asset.settled;
    final row = MarketAssetRow(
      assetId: detail.assetId,
      asset:
          asset?.symbol != null &&
              asset?.name != null &&
              asset?.decimals != null
          ? LoopAssetSummary(
              symbol: asset!.symbol!,
              name: asset.name!,
              decimals: asset.decimals!,
              status: asset.status,
            )
          : null,
      logoUrl: detail.logoUrl,
      price: detail.price,
      priceChange24h: detail.priceChange24h,
      volume24h: detail.volume24h,
      liquidityUsd: detail.liquidityUsd,
    );
    return Column(
      children: [
        MarketAssetTile(
          key: ValueKey('scoped-asset-${entry.sourceId}'),
          row: row,
          onTap: detail.capability.viewable
              ? () {
                  final location = MarketAssetRoute.token(detail.assetId);
                  if (onNavigate != null) {
                    onNavigate!(location);
                  } else {
                    context.push(location);
                  }
                }
              : null,
        ),
        MarketBlockProvenance.ofRows(rows: [row]),
        if (!detail.price.isAvailable)
          LoopProvenanceFooter(
            text: loopReasonCodeText(detail.price.reasonCode),
          ),
      ],
    );
  }
}
