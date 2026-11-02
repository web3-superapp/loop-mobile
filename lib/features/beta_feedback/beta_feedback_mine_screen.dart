import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_controllers.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_copy.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_media_image.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Replaces the picture provider of a feedback thumbnail. Tests only.
@visibleForTesting
ImageProvider<Object> Function(String url)? debugBetaFeedbackImageProvider;

/// `beta-feedback-mine` · 我的反馈 (S332 · decision 0262): archetype
/// `index`, layout `dashboard`.
///
/// The account's own feedback, newest first: category, status, time, the
/// start of the text and the pictures. Loading is a skeleton; empty is one
/// line; a failed read is an offline, permission, unavailable or error
/// block with a retry where a retry can change the answer.
class BetaFeedbackMineScreen extends ConsumerStatefulWidget {
  const BetaFeedbackMineScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<BetaFeedbackMineScreen> createState() =>
      _BetaFeedbackMineScreenState();
}

class _BetaFeedbackMineScreenState
    extends ConsumerState<BetaFeedbackMineScreen> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(ref.read(betaFeedbackMineControllerProvider.notifier).load());
      }
    });
  }

  Future<void> _reload() =>
      ref.read(betaFeedbackMineControllerProvider.notifier).reload();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(betaFeedbackMineControllerProvider);
    final resource = state.resource;
    final page = resource.value;
    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('beta-feedback-mine-screen'),
        archetype: LoopPageArchetype.listing,
        title: '我的反馈',
        onBack: widget.onBack,
        updating: resource.refreshing,
        onRefresh: resource.mode == LoopChainGatewayMode.unavailable
            ? null
            : _reload,
        block: resource.phase == LoopChainViewPhase.unavailable
            ? const LoopPageBlock(
                key: ValueKey<String>('beta-feedback-mine-unavailable'),
                title: '意见反馈暂不可用',
                message: '现在读不到反馈记录。',
              )
            : null,
        sections: <Widget>[
          const SizedBox(height: 8),
          if (page == null)
            _stateBlock(resource)
          else if (page.items.isEmpty)
            Padding(
              key: const ValueKey<String>('beta-feedback-mine-empty'),
              padding: const EdgeInsets.symmetric(
                horizontal: LoopSpacing.page,
                vertical: 48,
              ),
              child: Text(
                '还没有提交过反馈',
                textAlign: TextAlign.center,
                style: LoopType.caption.copyWith(color: LoopColors.text3),
              ),
            )
          else ...<Widget>[
            for (final item in page.items) _FeedbackCard(item: item),
            LoopLoadMoreFooter(
              keyPrefix: 'beta-feedback-mine',
              cursor: page.nextCursor,
              canLoadMore: !state.loadingMore && !resource.refreshing,
              loading: state.loadingMore,
              onLoadMore: () => ref
                  .read(betaFeedbackMineControllerProvider.notifier)
                  .loadMore(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stateBlock(LoopChainResourceState<BetaFeedbackPage> resource) {
    return switch (resource.phase) {
      LoopChainViewPhase.offline => LoopOfflineState(
        key: const ValueKey<String>('beta-feedback-mine-offline'),
        cause: resource.failureKind == LoopChainFailureKind.timedOut
            ? LoopOfflineCause.timeout
            : LoopOfflineCause.connection,
        pausedActions: const <String>['提交反馈'],
        onRetry: () => unawaited(_reload()),
      ),
      LoopChainViewPhase.permission => LoopPermissionState(
        key: const ValueKey<String>('beta-feedback-mine-permission'),
        icon: 'lock',
        title: '没有权限',
        purpose: betaFeedbackFailureReason(resource.failureKind, write: false),
        denied: true,
      ),
      LoopChainViewPhase.error => LoopErrorState(
        key: const ValueKey<String>('beta-feedback-mine-error'),
        title: '没有读到反馈',
        reason: betaFeedbackFailureReason(resource.failureKind, write: false),
        onRetry: () => unawaited(_reload()),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(horizontal: LoopSpacing.page),
        child: LoopSkeleton(
          key: ValueKey<String>('beta-feedback-mine-loading'),
          type: LoopSkeletonType.card,
        ),
      ),
    };
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});

  final BetaFeedbackItem item;

  static const double thumbnail = 56;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      key: ValueKey<String>('beta-feedback-item-${item.id}'),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              LoopBadge(item.category.label),
              const SizedBox(width: 6),
              LoopBadge(
                item.status.label,
                kind: switch (item.status) {
                  BetaFeedbackStatus.open => LoopBadgeKind.mining,
                  BetaFeedbackStatus.triaged => LoopBadgeKind.launch,
                  BetaFeedbackStatus.resolved => LoopBadgeKind.up,
                  BetaFeedbackStatus.wontFix => LoopBadgeKind.mute,
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            betaFeedbackTime(item.createdAt),
            style: LoopType.figureXs.copyWith(color: LoopColors.text3),
          ),
          const SizedBox(height: 10),
          Text(
            item.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: LoopType.body,
          ),
          if (item.images.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (var index = 0; index < item.images.length; index++)
                  ClipRRect(
                    key: ValueKey<String>(
                      'beta-feedback-item-${item.id}-image-$index',
                    ),
                    borderRadius: LoopRadius.tile,
                    child: SizedBox.square(
                      dimension: thumbnail,
                      child: Image(
                        image:
                            debugBetaFeedbackImageProvider?.call(
                              item.images[index],
                            ) ??
                            LoopMediaImage(item.images[index]),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: LoopColors.card2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
