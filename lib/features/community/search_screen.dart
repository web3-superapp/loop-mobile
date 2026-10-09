import 'dart:async';

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/community/search_controller.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `search` · the global search: 资产 / 社区 / 用户 (decision 0121 hides
/// Launch and DApp behind `searchOutboundDomainsVisible`).
///
/// A result is opened only through its `destination.kind`; a route is never
/// assembled from the display copy, a ticker or a domain name.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({
    super.key,
    this.initialQuery,
    this.onBack,
    this.onOpenCommunity,
    this.onOpenDirectMessage,
    this.onOpenAsset,
    this.onOpenProfile,
  });

  final String? initialQuery;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenCommunity;

  /// Opens the direct conversation with the account whose card is open.
  ///
  /// `#scr-search`'s `USERS` row is a `dm` entry in the prototype. The result
  /// opens the shared public-profile card, and the card carries the control;
  /// the route stays with the shell.
  final PublicProfileDirectMessageHandler? onOpenDirectMessage;

  /// Opens the token page for an `assetDetail` result, by `assetId`.
  final ValueChanged<String>? onOpenAsset;

  /// Opens `user-profile` for a `publicProfile` result, by its `stableId`
  /// (decision 0112). Without it the result opens the shared sheet.
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

  /// Navigation is decided by `destination.kind` alone. LOOP has no page for
  /// another account, so a `publicProfile` result opens the shared sheet
  /// instead of routing somewhere that would have to be invented.
  void _openResult(SearchResult result) {
    switch (result.destination) {
      case SearchCommunityProfileDestination():
        widget.onOpenCommunity?.call(result.stableId);
      // The token page is opened with the server's own `assetId`, never with
      // the row's symbol: two contracts may share a ticker.
      case SearchAssetDestination(:final assetId):
        widget.onOpenAsset?.call(assetId);
      case SearchPublicProfileDestination() when widget.onOpenProfile != null:
        widget.onOpenProfile!(result.stableId);
      case SearchPublicProfileDestination():
        unawaited(
          showPublicProfileSheet<Object>(
            context,
            // The snapshot is display copy: only `stableId` is a command
            // target, and a subtitle is accepted as a LOOP ID only when it
            // actually is one.
            identity: PublicProfileIdentity.fromSearchSnapshot(
              stableId: result.stableId,
              title: result.title,
              subtitle: result.subtitle,
              avatarRef: result.avatarRef,
            ),
            onOpenDirectMessage: widget.onOpenDirectMessage,
          ),
        );
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
    final switches = ref.watch(loopFeatureSwitchesProvider);
    final initial = widget.initialQuery;
    if (!communityCapabilityBlocks(mode, capability) &&
        !_submittedInitialQuery &&
        initial != null &&
        searchQueryIsSubmittable(initial)) {
      _submittedInitialQuery = true;
      // A profile link (`/u/{loopId}`, decision 0104) arrives here as a LOOP
      // ID, which names a person: it is asked of 用户 first.
      final domain = isLoopIdQuery(initial) ? SearchDomain.users : null;
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.submit(initial, domain: domain));
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
            child: Row(
              children: <Widget>[
                Expanded(child: _field(controller)),
                const SizedBox(width: 8),
                // Decision 0104: a LOOP ID usually arrives in a chat message
                // or a shared note. Pasting lifts the ID out of whatever came
                // with it and asks 用户 directly.
                LoopButton(
                  key: const ValueKey<String>('search-paste-loop-id'),
                  label: '粘贴',
                  semanticLabel: '粘贴 LOOP ID 并搜索',
                  onPressed: () => unawaited(_pasteLoopId(controller)),
                ),
              ],
            ),
          ),
          // S121a · decision 0121: one line under the field says what a
          // nickname search can reach, in place of the 「搜索范围」 card that
          // sat under the results. The switch is the privacy centre's
          // 「可被发现」 (decision 0105); a LOOP ID is always found exactly.
          Padding(
            key: const ValueKey<String>('search-scope-hint'),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(searchScopeHint, style: LoopType.captionSm),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final domain in visibleSearchDomains(
                    outboundVisible: switches.searchOutboundDomainsVisible,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: LoopSubChip(
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
      // A search is a query the user submits, not a feed: there is nothing to
      // pull down on, so the page takes no refresh gesture.
      block: communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>('search-capability-unavailable'),
              capability: capability,
              title: '搜索当前不可用',
            )
          : null,
      collection: ListView(
        key: const ValueKey<String>('search-results'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '搜索结果'),
          if (state.domainUnavailable)
            LoopEmpty(
              key: ValueKey<String>(
                'search-domain-unavailable-${state.domain.wireName}',
              ),
              icon: 'warn',
              message: '${state.domain.label} 暂时搜不到',
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
                  ? '这个分类下没有结果。'
                  : '搜索按开头匹配，只显示允许被搜到的账号与已验证的社区。',
              // Decision 0122: the centred search illustration, not a strip.
              empty: LoopEmptyState(
                key: const ValueKey<String>('search-empty'),
                illustration: LoopIllustration.search,
                title: searchQueryIsSubmittable(state.query)
                    ? '没有找到匹配的结果'
                    : '搜索资产、社区与用户',
                message: searchQueryIsSubmittable(state.query)
                    ? '换个关键词，或切换上面的分类试试'
                    : '输入至少 $searchMinimumRunes 个字符开始搜索',
              ),
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
        ],
      ),
    );
  }

  Widget _field(SearchController controller) => TextField(
    key: const ValueKey<String>('search-field'),
    controller: _query,
    textInputAction: TextInputAction.search,
    onChanged: controller.type,
    onSubmitted: (value) => unawaited(controller.submit(value)),
    decoration: InputDecoration(
      labelText: searchFieldLabel,
      hintText: '至少 $searchMinimumRunes 个字符',
      suffixIcon: IconButton(
        key: const ValueKey<String>('search-submit'),
        tooltip: '搜索',
        icon: const Icon(Icons.search_rounded),
        onPressed: () => unawaited(controller.submit(_query.text)),
      ),
    ),
  );

  /// Reads the clipboard once, on the reader's tap, and keeps only a LOOP ID
  /// from it: the rest of the pasted text never enters the field or a request.
  Future<void> _pasteLoopId(SearchController controller) async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    final loopId = loopIdFromText(data?.text);
    if (loopId == null) {
      LoopToast.show(
        context,
        message: '剪贴板里没有 LOOP ID',
        kind: LoopToastKind.warn,
      );
      return;
    }
    _query.value = TextEditingValue(
      text: loopId,
      selection: TextSelection.collapsed(offset: loopId.length),
    );
    FocusScope.of(context).unfocus();
    await controller.submit(loopId, domain: SearchDomain.users);
  }

  LoopRecordRow _resultRow(SearchResult result, int index, int length) {
    // A user's subtitle is the alias or LOOP ID the reader searched for, and
    // an asset's is the token's name under its symbol. A community's is its
    // slug, which reached the screen bare — 「mock-vol-01」 under 「Alpha
    // Signals 1」 — and names nothing a reader can use. The row keeps the
    // community's name and member count instead.
    final subtitle = result.resultType == SearchResultType.community
        ? null
        : result.subtitle;
    return LoopRecordRow(
      key: ValueKey<String>('search-result-${result.stableId}'),
      // Results arrived as bare text, so a page of communities and a page of
      // people read as one undifferentiated list. Each result carries the
      // identity it stands for: a community its own logo — or, where the
      // preset has no local image, the face its id is always given — and a
      // person their avatar. `stableId` is the community's id on this wire.
      leading: switch (result.resultType) {
        SearchResultType.community => CommunityLogo(
          identity: result.stableId,
          name: result.title,
          logoRef: result.avatarRef,
        ),
        // `avatarRef` is always null on an asset row: the registry's artwork
        // arrives in its own `logo` block (decision 0072), and the symbol's
        // bundled face and then the monogram stand in when none was published.
        SearchResultType.asset => LoopTokenLogo(
          assetSymbol: result.title,
          logoUrl: result.logoUrl,
          fallbackMonogram: result.title,
          size: 44,
        ),
        SearchResultType.user => LoopProfileAvatar(
          avatarRef: result.avatarRef,
          alias: result.title,
          size: 44,
        ),
      },
      title: result.title,
      subtitle: subtitle,
      trailing: result.memberCount == null ? null : '${result.memberCount}',
      trailingCaption: result.memberCount == null ? null : '成员',
      position: communityRowPosition(index, length),
      onTap: () => _openResult(result),
      semanticLabel: '${result.title}${subtitle == null ? '' : '，$subtitle'}',
    );
  }
}

/// A secondary chip on the OKX reference (S121 §1.1.1 · 3, decision 0121): a
/// small outlined pill, filled dark grey when chosen — Lime stays for the
/// primary action. The pill is 32 tall inside a 44 touch target.
class LoopSubChip extends StatelessWidget {
  const LoopSubChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? LoopColors.card2 : null,
                border: selected ? null : Border.all(color: LoopColors.line),
                borderRadius: LoopRadius.pill,
              ),
              child: Text(
                label,
                style:
                    LoopTypography.withWeight(
                      LoopType.body,
                      selected ? FontWeight.w600 : FontWeight.w400,
                    ).copyWith(
                      color: selected ? LoopColors.chalk : LoopColors.text2,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
