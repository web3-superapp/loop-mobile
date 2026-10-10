import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The sentence a closed `launch2` capability is explained with.
String launch2CapabilityText(LoopCapabilityProjection capability) {
  if (capability.isUnobserved) {
    return capability.unreachable ? '暂时连不上 LOOP' : 'MEME v2 状态还没有读到';
  }
  return launch2ReasonText(
    capability.reasonCode ?? 'LAUNCH2_RUNTIME_UNAVAILABLE',
  );
}

/// MEME · 「v2 发射」 / 「已毕业」 (archetype `index`, layout `dashboard`,
/// decision 0139).
///
/// One row per instance in the OKX quote shape, read a page at a time as the
/// reader scrolls, pulled to re-read. An empty list is a line illustration,
/// a title and the one next step; a closed capability is one inline line,
/// never an empty list. The list ends on space, never on 「没有更多」.
class Launch2ListSegment extends ConsumerWidget {
  const Launch2ListSegment({
    required this.scope,
    required this.onNavigate,
    super.key,
    this.onEmptyAction,
  });

  final Launch2ListScope scope;
  final void Function(String location) onNavigate;

  /// The empty list's one next step (another segment of the MEME Tab).
  final VoidCallback? onEmptyAction;

  String get _keyBase => 'launch2-list-${scope.name}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    final blocked = launch2ReadsBlocked(ref);
    final provider = launch2ListControllerProvider(scope);
    final state = blocked ? null : ref.watch(provider);
    if (state != null) {
      launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    }
    final controller = ref.read(provider.notifier);
    return LoopDashboardPage(
      key: ValueKey<String>(_keyBase),
      archetype: LoopPageArchetype.listing,
      title: scope == Launch2ListScope.all ? 'v2 发射' : '已毕业',
      embedded: true,
      tabPage: true,
      onRefresh: blocked ? null : controller.reload,
      sections: <Widget>[
        if (state == null)
          LoopInlineUnavailable(
            key: ValueKey<String>('$_keyBase-unavailable'),
            message: 'MEME v2 暂时不可用 · ${launch2CapabilityText(capability)}',
          )
        else
          ..._rows(state, controller),
      ],
    );
  }

  List<Widget> _rows(
    LoopChainResourceState<Launch2InstancePage> state,
    Launch2ListController controller,
  ) {
    final page = state.value;
    if (page == null && state.phase == LoopChainViewPhase.loading) {
      return <Widget>[
        LoopSkeleton(
          key: ValueKey<String>('$_keyBase-loading'),
          type: LoopSkeletonType.priceRow,
          rows: 6,
          rowHeight: memeCardHeight,
          leadingSize: memeCardLogoSize,
        ),
      ];
    }
    if (page == null) {
      return <Widget>[
        LoopChainStateBlock(
          keyPrefix: _keyBase,
          phase: state.phase,
          failureKind: state.failureKind,
          emptyMessage: '还没有 v2 项目',
          onRetry: () => unawaited(controller.reload()),
        ),
      ];
    }
    if (page.items.isEmpty) {
      final graduated = scope == Launch2ListScope.graduated;
      return <Widget>[
        LoopEmptyState(
          key: ValueKey<String>('$_keyBase-empty'),
          illustration: LoopIllustration.launchpad,
          title: graduated ? '还没有毕业的 v2 项目' : '还没有 v2 项目',
          message: graduated ? '内盘卖满后自动建官方池，会出现在这里' : 'NFT 预售开始后会出现在这里',
          action: onEmptyAction == null
              ? null
              : LoopButton(
                  key: ValueKey<String>('$_keyBase-empty-action'),
                  label: graduated ? '看正在发射的' : '看经典发射',
                  primary: true,
                  onPressed: onEmptyAction,
                ),
        ),
      ];
    }
    final cursor = page.nextCursor;
    return <Widget>[
      const SizedBox(height: 2),
      for (final row in page.items)
        Launch2InstanceTile(
          key: ValueKey<String>('launch2-tile-${row.instanceId}'),
          row: row,
          onTap: () => onNavigate(Launch2Route.instance(row.instanceId)),
          // A row whose stage time passed: the server says what it is now.
          onElapsed: () => unawaited(controller.reload()),
        ),
      if (controller.appendFailed && !state.busy)
        LoopInlineUnavailable(
          key: ValueKey<String>('$_keyBase-more-failed'),
          message: '下一页没有读到',
          onRetry: () => unawaited(controller.loadMore()),
        )
      else if (cursor != null) ...<Widget>[
        LoopLoadMoreSentinel(
          key: ValueKey<String>('$_keyBase-load-more'),
          cursor: cursor,
          onLoadMore: () => unawaited(controller.loadMore()),
        ),
        if (state.busy)
          LoopSkeleton(
            key: ValueKey<String>('$_keyBase-loading-more'),
            type: LoopSkeletonType.priceRow,
            rows: 2,
            rowHeight: memeCardHeight,
            leadingSize: memeCardLogoSize,
          ),
      ] else
        MarketListEnd(key: ValueKey<String>('$_keyBase-end')),
      LoopProvenanceLine(
        key: ValueKey<String>('$_keyBase-provenance'),
        sources: const <String>['LOOP 链上索引'],
        observedAt: controller.valueObservedAt,
        detail:
            '阶段与倒计时由服务端按链上时间给出，到点后重新读取；'
            '内盘进度按已售 / 8 亿计，价格以 USD1 计。',
      ),
    ];
  }
}
