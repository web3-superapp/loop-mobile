import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_application_flow.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/community/plaza_controller.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_incremental_list.dart';

class PlazaScreen extends ConsumerStatefulWidget {
  const PlazaScreen({super.key});
  @override
  ConsumerState<PlazaScreen> createState() => _PlazaScreenState();
}

class _PlazaScreenState extends ConsumerState<PlazaScreen> {
  PlazaController? _activeController;
  bool _rooms = false;
  bool _started = false;
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(plazaControllerProvider);
    if (!identical(controller, _activeController)) {
      _activeController = controller;
      _started = false;
    }
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final blocked = communityCapabilityBlocks(
      ref.watch(communityGatewayProvider).mode,
      capability,
    );
    if (!_started && !blocked) {
      _started = true;
      scheduleMicrotask(() => unawaited(controller.reload()));
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rows = controller.items;
        final live = rows
            .where((row) => controller.voices[row.communityId]?.isLive == true)
            .toList();
        final unknown = rows
            .where(
              (row) =>
                  controller.voices[row.communityId] == null ||
                  controller.voices[row.communityId]!.status !=
                      CommunityVoiceStatus.available,
            )
            .length;
        final visible = _rooms ? live : rows;
        return LoopIncrementalList(
          canLoadMore: !blocked && controller.canNext,
          loading: controller.loading,
          failed: controller.failed,
          onLoadMore: () => unawaited(controller.next()),
          child: LoopDashboardPage(
            title: '广场',
            tabPage: true,
            archetype: LoopPageArchetype.listing,
            onRefresh: blocked ? null : controller.reload,
            updating: controller.loading && rows.isNotEmpty,
            actions: [
              LoopIconButton(
                key: const ValueKey('plaza-my-community'),
                icon: 'users',
                label: '我的社区',
                onPressed: () => context.push('/community'),
              ),
              LoopIconButton(
                icon: 'plus',
                label: '创建社区',
                onPressed: blocked
                    ? null
                    : () => unawaited(openCommunityApplication(context, ref)),
              ),
            ],
            block: blocked
                ? LoopCapabilityPageBlock.of(
                    title: '广场当前不可用',
                    capability: capability,
                    fallbackReasonCode: 'COMMUNITY_RUNTIME_UNAVAILABLE',
                  )
                : null,
            sections: [
              MarketTabBar(
                key: const ValueKey('plaza-destinations'),
                keyPrefix: 'plaza-destination',
                expanded: true,
                labels: const ['社区', '语音房'],
                selectedIndex: _rooms ? 1 : 0,
                onSelected: (index) => setState(() => _rooms = index == 1),
              ),
              const SizedBox(height: 14),
              if (controller.loading && rows.isEmpty)
                const LoopSkeleton(type: LoopSkeletonType.record, rows: 6)
              else ...[
                if (controller.failed)
                  LoopEmpty(
                    message: '目录读取失败',
                    action: LoopButton(
                      label: '重试',
                      onPressed: () => unawaited(controller.retry()),
                    ),
                  ),
                if (_rooms) const LoopLabel('已加载社区的语音房'),
                if (visible.isNotEmpty) ...[
                  for (final row in visible)
                    _PlazaCommunityCard(
                      key: ValueKey('plaza-${row.communityId}'),
                      community: row,
                      liveRoom: _rooms,
                      onTap: () => context.push(
                        _rooms
                            ? voiceRoomLinkLocation(row.communityId)
                            : '/community/profile?id=${Uri.encodeQueryComponent(row.communityId)}',
                      ),
                    ),
                ] else if (!controller.failed && !controller.loading)
                  LoopEmpty(
                    message: controller.hasUnreadDirectory && rows.isEmpty
                        ? '上滑继续加载社区'
                        : _rooms
                        ? (unknown > 0 ? '部分房间状态暂不可读' : '已加载社区没有进行中的语音房')
                        : '暂时没有社区',
                  ),
                if (_rooms && unknown > 0 && live.isNotEmpty)
                  const LoopProvenanceFooter(text: '部分社区的房间状态暂不可读'),
              ],
              if (controller.loading && rows.isNotEmpty)
                const LoopListLoadingFooter()
              else if (!blocked && !controller.failed && controller.canNext)
                LoopListLoadMoreFooter(
                  onLoadMore: () => unawaited(controller.next()),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A community has its own identity and description, so each is one card.
/// Membership and room availability remain the controller's own readings.
class _PlazaCommunityCard extends StatelessWidget {
  const _PlazaCommunityCard({
    required this.community,
    required this.liveRoom,
    required this.onTap,
    super.key,
  });

  final CommunitySummary community;
  final bool liveRoom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = community.description?.trim();
    return LoopSurfaceCard(
      background: LoopColors.graphite,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      semanticLabel:
          '${community.name}，${community.memberCount} 位成员'
          '${liveRoom ? '，正在进行，查看房间' : ''}'
          '${!liveRoom && description != null && description.isNotEmpty ? '，$description' : ''}',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CommunityLogo(
                identity: community.communityId,
                name: community.name,
                logoRef: community.logoRef,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.heading(18),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      liveRoom ? '正在进行 · 查看房间' : '${community.memberCount} 位成员',
                      style: LoopTypography.caption(
                        13,
                        color: LoopColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LoopIcon('chevron', size: 18, color: LoopColors.text3),
            ],
          ),
          if (!liveRoom && description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.body(14, color: LoopColors.text2),
            ),
          ],
        ],
      ),
    );
  }
}
