import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/community/search_controller.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `search` · the five-domain global search.
///
/// A result is opened only through its `destination.kind`; a route is never
/// assembled from the display copy, a ticker or a domain name.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({
    super.key,
    this.initialQuery,
    this.onBack,
    this.onOpenCommunity,
    this.onOpenProfile,
  });

  final String? initialQuery;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenCommunity;
  final ValueChanged<String>? onOpenProfile;

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery ?? '',
  );
  var _submittedInitialQuery = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openResult(SearchResult result) {
    switch (result.destination) {
      case SearchDestinationKind.communityProfile:
        widget.onOpenCommunity?.call(result.stableId);
      case SearchDestinationKind.publicProfile:
        widget.onOpenProfile?.call(result.stableId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.search),
    );
    final mode = ref.watch(searchGatewayProvider).mode;
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final initial = widget.initialQuery;
    if (capability.isAvailable &&
        !_submittedInitialQuery &&
        initial != null &&
        searchQueryIsSubmittable(initial)) {
      _submittedInitialQuery = true;
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.submit(initial));
      });
    }

    return LoopStreamPage(
      key: const ValueKey<String>('global-search-screen'),
      archetype: LoopPageArchetype.listing,
      title: '搜索',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      // The query field and the domain segments are pinned together above
      // the collection: `folio` only accepts a folio primary.
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              key: const ValueKey<String>('search-field'),
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => unawaited(controller.submit(value)),
              decoration: InputDecoration(
                labelText: '搜索社区或用户',
                hintText: '至少 $searchMinimumRunes 个字符',
                suffixIcon: IconButton(
                  key: const ValueKey<String>('search-submit'),
                  tooltip: '搜索',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => unawaited(controller.submit(_query.text)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final domain in searchDomainOrder)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: LoopSeg(
                        key: ValueKey<String>('search-seg-${domain.wireName}'),
                        label: domain.label,
                        selected: state.domain == domain,
                        onSelected: () => controller.selectDomain(domain),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      collection: ListView(
        key: const ValueKey<String>('search-results'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '搜索结果'),
          if (!capability.isAvailable)
            LoopEmpty(
              key: const ValueKey<String>('search-capability-unavailable'),
              icon: 'warn',
              message: '搜索当前不可用',
              reason: capability.reasonCode == null
                  ? '尚未读取到能力清单，本页不发起任何搜索请求。'
                  : '服务端原因：${capability.reasonCode}。',
            )
          else if (state.domainUnavailable)
            LoopEmpty(
              key: ValueKey<String>(
                'search-domain-unavailable-${state.domain.wireName}',
              ),
              icon: 'warn',
              message: '"${state.domain.label}" 域暂不可用',
              reason: communityUnavailableReason(state.reasonCode!),
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: searchQueryIsSubmittable(state.query)
                  ? '没有匹配的结果'
                  : '输入至少 $searchMinimumRunes 个字符开始搜索',
              emptyReason: searchQueryIsSubmittable(state.query)
                  ? '服务端在该域下没有返回任何结果。'
                  : '搜索按前缀匹配，只返回已激活且允许被发现的账号与已验证的社区。',
              onRetry: () => unawaited(controller.submit(state.query)),
            )
          else ...<Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.results.length; index += 1)
                  _resultRow(state.results[index], index, state.results.length),
              ],
            ),
            if (state.canLoadMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('search-load-more'),
                  label: '载入更多',
                  block: true,
                  onPressed: () => unawaited(controller.loadMore()),
                ),
              ),
          ],
          const LoopNotice(
            key: ValueKey<String>('search-scope-notice'),
            icon: 'info',
            title: '搜索范围',
            body:
                '聊天内容不进入本搜索。用户结果只包含已开启"可被发现"的账号；'
                '如果别人搜不到你，请在隐私设置里打开该开关。',
            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
        ],
      ),
    );
  }

  LoopRecordRow _resultRow(SearchResult result, int index, int length) {
    return LoopRecordRow(
      key: ValueKey<String>('search-result-${result.stableId}'),
      title: result.title,
      subtitle: result.subtitle,
      trailing: result.memberCount == null ? null : '${result.memberCount}',
      trailingCaption: result.memberCount == null ? null : '成员',
      position: communityRowPosition(index, length),
      onTap: () => _openResult(result),
      semanticLabel:
          '${result.title}${result.subtitle == null ? '' : '，${result.subtitle}'}',
    );
  }
}
