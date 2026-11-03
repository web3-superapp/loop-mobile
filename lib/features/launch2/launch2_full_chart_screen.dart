import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_chart.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/shell/loop_orientation.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `chart-full` for a MEME v2 project (decision 0273): the market's
/// full-screen chart page (`/market/chart?launch2=<instanceId>`) with the
/// project page's own K line block — the same toolbar, the six MEME periods,
/// the 毕业 rule and the page-back to older buckets.
///
/// Archetype `record`, layout `focus`. Loading / error / offline /
/// permission come from the instance read; empty is the block's own
/// 「还没有成交」.
class Launch2FullChartScreen extends ConsumerStatefulWidget {
  const Launch2FullChartScreen({
    required this.instanceId,
    super.key,
    this.onBack,
  });

  final String? instanceId;
  final VoidCallback? onBack;

  @override
  ConsumerState<Launch2FullChartScreen> createState() =>
      _Launch2FullChartScreenState();
}

class _Launch2FullChartScreenState
    extends ConsumerState<Launch2FullChartScreen> {
  /// Everything on this page that is not the plot (the market page's own
  /// figure, `FullChartScreen`).
  static const double _chromeHeight = 210;
  static const double _minimumChartHeight = 160;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setPreferredOrientations(loopChartOrientations));
  }

  @override
  void dispose() {
    unawaited(loopLockPortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.instanceId;
    if (!Launch2Route.isInstanceId(id)) {
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-chart-full-invalid'),
        archetype: LoopPageArchetype.record,
        title: '无法打开这张图表',
        onBack: widget.onBack,
        body: const <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('launch2-chart-full-invalid-identity'),
            illustration: LoopIllustration.launchpad,
            title: '路由中没有可用的项目标识',
            message: '没有请求任何数据，也没有回退到其他项目。',
            compact: true,
          ),
        ],
      );
    }
    final instanceId = id!;
    final blocked = launch2ReadsBlocked(ref);
    if (blocked) {
      final capability = ref.watch(
        loopCapabilityProvider(LoopV2CapabilityId.launch2),
      );
      return LoopFocusPage(
        key: const ValueKey<String>('launch2-chart-full-blocked'),
        archetype: LoopPageArchetype.record,
        title: '全屏图表',
        onBack: widget.onBack,
        block: LoopPageBlock(
          key: const ValueKey<String>('launch2-chart-full-capability-block'),
          title: 'MEME v2 暂时不可用',
          message: launch2CapabilityText(capability),
        ),
        body: const <Widget>[],
      );
    }
    final provider = launch2InstanceControllerProvider(instanceId);
    final state = ref.watch(provider);
    launch2LoadOnce(ref, state, () => ref.read(provider.notifier).load());
    final detail = state.value;
    final media = MediaQuery.of(context);
    final chartHeight = math.max(
      _minimumChartHeight,
      media.size.height - media.padding.vertical - _chromeHeight,
    );
    final price = detail == null
        ? null
        : detail.stage == Launch2Stage.graduated
        ? detail.pool?.lastPriceUsd1
        : detail.row.curve.priceUsd1;
    return LoopFocusPage(
      key: ValueKey<String>('launch2-chart-full-$instanceId'),
      archetype: LoopPageArchetype.record,
      title: detail == null ? '全屏图表' : loopTickerLabel(detail.row.ticker),
      subtitle: price == null ? null : '${launch2PriceLabel(price)} USD1',
      onBack: widget.onBack,
      body: <Widget>[
        if (detail == null)
          LoopChainStateBlock(
            keyPrefix: 'launch2-chart-full',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.chart,
            emptyMessage: '项目不存在',
            onRetry: () => unawaited(ref.read(provider.notifier).reload()),
          )
        else
          Launch2CandleCard(
            key: ValueKey<String>('launch2-chart-full-candles-$instanceId'),
            detail: detail,
            height: chartHeight,
          ),
      ],
    );
  }
}
