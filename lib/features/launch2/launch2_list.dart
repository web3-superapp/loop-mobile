import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_hero.dart';
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
///
/// Decision 0148: while the list is on screen (its route is the top one and
/// its tab is active) the first page is re-read every 60 s, and once more the
/// moment the reader comes back from a project page; both keep the rows
/// already scrolled to. A pull still starts the list over.
class Launch2ListSegment extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<Launch2ListSegment> createState() => _Launch2ListSegmentState();
}

class _Launch2ListSegmentState extends ConsumerState<Launch2ListSegment> {
  Timer? _poll;
  bool _visible = false;

  /// Something hid the list (a project page, another tab) since it was last
  /// on screen: coming back re-reads at once.
  bool _hidden = false;

  Launch2ListScope get scope => widget.scope;

  String get _keyBase => 'launch2-list-${scope.name}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        (ModalRoute.isCurrentOf(context) ?? true) &&
        TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      _hidden = true;
      _stopPolling();
      return;
    }
    if (_hidden) {
      _hidden = false;
      scheduleMicrotask(_refresh);
    }
    _armPoll();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _armPoll() {
    _stopPolling();
    final interval = ref.read(launch2PollingProvider).listInterval;
    _poll = Timer.periodic(interval, (_) => _refresh());
  }

  void _refresh() {
    if (!mounted || !_visible || launch2ReadsBlocked(ref)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final provider = launch2ListControllerProvider(scope);
    final state = ref.read(provider);
    // Nothing read yet (the first read is the page's own) or a read already
    // running: the tick has nothing to add.
    if (state.value == null || state.busy || state.refreshing) return;
    unawaited(ref.read(provider.notifier).refresh());
  }

  void _openInstance(String instanceId) {
    widget.onNavigate(Launch2Route.instance(instanceId));
  }

  @override
  Widget build(BuildContext context) {
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
          action: widget.onEmptyAction == null
              ? null
              : LoopButton(
                  key: ValueKey<String>('$_keyBase-empty-action'),
                  label: graduated ? '看正在发射的' : '看经典发射',
                  primary: true,
                  onPressed: widget.onEmptyAction,
                ),
        ),
      ];
    }
    final cursor = page.nextCursor;
    // Decision 0163: the hero over 「v2 发射」, picked from the rows already
    // read; nothing over 「已毕业」 and nothing when no row qualifies.
    final hero = scope == Launch2ListScope.all
        ? launch2HeroRows(
            page.items.take(launch2HeroFirstPageRows).toList(growable: false),
          )
        : const <Launch2InstanceRow>[];
    return <Widget>[
      if (hero.isNotEmpty)
        Launch2HeroPager(
          rows: hero,
          onNavigate: widget.onNavigate,
          onElapsed: () => unawaited(controller.reload()),
        ),
      const SizedBox(height: 2),
      for (final row in launch2ListOrder(page.items))
        Launch2InstanceTile(
          key: ValueKey<String>('launch2-tile-${row.instanceId}'),
          row: row,
          onTap: () => _openInstance(row.instanceId),
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
            '列表在屏幕上时每分钟刷新一次；'
            '内盘进度按已售 / 8 亿计，价格以 USD1 计。',
      ),
    ];
  }
}

/// The order a v2 list draws its rows in (decision 0142): the server's own
/// order (newest activation first), except that `closed_no_holders` rows —
/// terminal, never tradable — sink below every other row read so far, in
/// their own server order. The 「已毕业」 list is `stage=graduated` and never
/// holds one. A later page's live rows therefore land above the closed ones
/// already on screen.
List<Launch2InstanceRow> launch2ListOrder(List<Launch2InstanceRow> rows) {
  if (!rows.any((row) => row.stage == Launch2Stage.closedNoHolders)) {
    return rows;
  }
  return <Launch2InstanceRow>[
    for (final row in rows)
      if (row.stage != Launch2Stage.closedNoHolders) row,
    for (final row in rows)
      if (row.stage == Launch2Stage.closedNoHolders) row,
  ];
}
