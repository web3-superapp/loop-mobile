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
import 'package:loop_mobile/features/community/search_recent.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `search` · the global search: 全部 / 代币 / 社区 / 用户 (decision 0121
/// hides Launch and DApp behind `searchOutboundDomainsVisible`). Decision 0178
/// lays it out as docs/35 「搜索」: segments on top, 「最近搜索」, result rows,
/// and the input bar at the bottom.
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

  /// The server's answer to a 「关注」 made from a recent card, this run only.
  final Map<String, bool> _follows = <String, bool>{};
  final Set<String> _followPending = <String>{};

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

  /// Opens [result] and records it in 「最近搜索」 (decision 0178).
  void _open(SearchResult result) {
    ref.read(searchRecentControllerProvider.notifier).record(result);
    _openResult(result);
  }

  /// 「关注」 on a recent person's card. The entry stores no follow state, so
  /// the capsule says 「关注」 until the server's own answer says otherwise.
  Future<void> _follow(SearchRecentEntry entry) async {
    final id = entry.stableId;
    if (_followPending.contains(id)) return;
    setState(() => _followPending.add(id));
    try {
      final outcome = await ref
          .read(socialGatewayProvider)
          .setFollowing(publicProfileId: id, following: true);
      if (!mounted) return;
      setState(() => _follows[id] = outcome.viewerFollows);
      LoopToast.show(
        context,
        message: outcome.viewerFollows ? '已关注' : '没有关注成功',
        kind: outcome.viewerFollows ? LoopToastKind.ok : LoopToastKind.warn,
      );
    } on CommunityGatewayException catch (error) {
      if (!mounted) return;
      LoopToast.show(
        context,
        message: communityFailureReason(error.kind),
        kind: LoopToastKind.err,
      );
    } catch (_) {
      if (!mounted) return;
      LoopToast.show(
        context,
        message: communityFailureReason(CommunityFailureKind.unexpected),
        kind: LoopToastKind.err,
      );
    } finally {
      if (mounted) setState(() => _followPending.remove(id));
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
    final recents = ref.watch(searchRecentControllerProvider);
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
    final submittable = searchQueryIsSubmittable(state.query);

    // Decision 0170: a page of OKX person rows is a flat page.
    return LoopFlat(
      child: LoopStreamPage(
        key: const ValueKey<String>('global-search-screen'),
        archetype: LoopPageArchetype.listing,
        title: '搜索',
        kicker: communityPreviewKicker(mode),
        onBack: widget.onBack,
        // Decision 0178 (docs/35 「搜索」): one row of segments — 全部 first —
        // under the top bar. The chosen one is the screen's one solid Lime;
        // the others are the quiet words of the family (decision 0170).
        filters: SingleChildScrollView(
          key: const ValueKey<String>('search-segs'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: <Widget>[
              _seg(
                key: 'search-seg-all',
                label: '全部',
                selected: state.all,
                onSelected: controller.selectAll,
              ),
              for (final domain in visibleSearchDomains(
                outboundVisible: switches.searchOutboundDomainsVisible,
              ))
                _seg(
                  key: 'search-seg-${domain.wireName}',
                  label: domain.label,
                  selected: !state.all && state.domain == domain,
                  onSelected: () => controller.selectDomain(domain),
                ),
            ],
          ),
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
        collection: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ListView(
                key: const ValueKey<String>('search-results'),
                padding: const EdgeInsets.only(bottom: 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  CommunityPreviewNotice(mode: mode, resource: '搜索结果'),
                  if (!submittable && recents.isNotEmpty)
                    ..._recentSection(recents)
                  else if (state.domainUnavailable)
                    LoopInlineUnavailable(
                      key: ValueKey<String>(
                        'search-domain-unavailable-${state.domain.wireName}',
                      ),
                      message: '${state.domain.label} 暂时搜不到',
                      detail: communityUnavailableReason(state.reasonCode!),
                      detailMaxLines: 3,
                    )
                  else if (state.phase != CommunityViewPhase.ready) ...<Widget>[
                    ..._failedLines(state),
                    CommunityStateBlock(
                      phase: state.phase,
                      failureKind: state.failureKind,
                      emptyMessage: submittable
                          ? '没有匹配的结果'
                          : '输入至少 $searchMinimumRunes 个字符开始搜索',
                      emptyReason: submittable
                          ? '这个分类下没有结果。'
                          : '搜索按开头匹配，只显示允许被搜到的账号与已验证的社区。',
                      // Decision 0122: the centred search illustration.
                      empty: LoopEmptyState(
                        key: const ValueKey<String>('search-empty'),
                        illustration: LoopIllustration.search,
                        title: submittable ? '没有找到匹配的结果' : '搜索代币、社区与用户',
                        message: submittable
                            ? '换个关键词，或切换上面的分类试试'
                            : '输入至少 $searchMinimumRunes 个字符开始搜索',
                      ),
                      onRetry: () => unawaited(controller.submit(state.query)),
                    ),
                  ] else if (state.all)
                    ..._allSections(state, controller)
                  else ...<Widget>[
                    for (final result in state.results) _resultRow(result),
                    LoopLoadMoreFooter(
                      key: const ValueKey<String>('search-footer'),
                      keyPrefix: 'search',
                      cursor: state.nextCursor,
                      canLoadMore: state.canLoadMore,
                      loading: state.loadingMore,
                      onLoadMore: controller.loadMore,
                    ),
                  ],
                ],
              ),
            ),
            _searchBar(controller),
          ],
        ),
      ),
    );
  }

  /// Decision 0210 (S241b): every segment is quiet; the chosen one carries
  /// the looplabs selected state (purple 9 % ground, purple underline, yellow
  /// text) instead of a solid yellow block.
  Widget _seg({
    required String key,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: LoopSeg(
      key: ValueKey<String>(key),
      label: label,
      quiet: true,
      selected: selected,
      onSelected: onSelected,
    ),
  );

  /// 「最近搜索」: people and communities as a strip of cards, tokens as rows.
  List<Widget> _recentSection(List<SearchRecentEntry> recents) {
    final recentController = ref.read(searchRecentControllerProvider.notifier);
    final cards = recents
        .where((entry) => entry.type != SearchResultType.asset)
        .toList();
    final rows = recents
        .where((entry) => entry.type == SearchResultType.asset)
        .toList();
    return <Widget>[
      _labelRow(
        key: const ValueKey<String>('search-recent-label'),
        label: '最近搜索',
        action: '清除全部',
        actionKey: const ValueKey<String>('search-recent-clear'),
        onAction: recentController.clear,
      ),
      if (cards.isNotEmpty)
        SingleChildScrollView(
          key: const ValueKey<String>('search-recent-cards'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var index = 0; index < cards.length; index += 1) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                _recentCard(cards[index], recentController),
              ],
            ],
          ),
        ),
      for (final entry in rows)
        LoopPersonRow(
          key: ValueKey<String>(_recentKey(entry)),
          leading: _assetLogo(entry.title, null),
          title: entry.title,
          tag: const LoopBadge('代币'),
          trailing: _RecentDismiss(
            key: ValueKey<String>('search-recent-remove-${_recentId(entry)}'),
            name: entry.title,
            onPressed: () => recentController.remove(entry),
          ),
          onTap: () => _open(entry.toResult()),
          semanticLabel: '${entry.title}，代币，最近搜索',
        ),
    ];
  }

  static String _recentId(SearchRecentEntry entry) =>
      '${entry.type.wireName}-${entry.stableId}';

  static String _recentKey(SearchRecentEntry entry) =>
      'search-recent-${_recentId(entry)}';

  Widget _recentCard(
    SearchRecentEntry entry,
    SearchRecentController recentController,
  ) {
    final user = entry.type == SearchResultType.user;
    final id = entry.stableId;
    final followed = _follows[id] ?? false;
    final pending = _followPending.contains(id);
    final social = ref.watch(socialGatewayProvider).mode;
    final LoopPillAction pill;
    if (!user) {
      pill = LoopPillAction(
        key: ValueKey<String>('search-recent-enter-${_recentId(entry)}'),
        label: '进入',
        soft: true,
        onPressed: () => _open(entry.toResult()),
      );
    } else if (followed) {
      pill = LoopPillAction(
        key: ValueKey<String>('search-recent-follow-${_recentId(entry)}'),
        label: '已关注',
        primary: false,
        onPressed: () => _open(entry.toResult()),
      );
    } else {
      pill = LoopPillAction(
        key: ValueKey<String>('search-recent-follow-${_recentId(entry)}'),
        label: pending ? '关注中' : '关注',
        soft: true,
        onPressed: pending || social == CommunityGatewayMode.unavailable
            ? null
            : () => unawaited(_follow(entry)),
      );
    }
    return SizedBox(
      width: _recentCardWidth,
      child: LoopRecordCard(
        key: ValueKey<String>(_recentKey(entry)),
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        onTap: () => _open(entry.toResult()),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: 4),
                if (user)
                  LoopProfileAvatar(
                    avatarRef: null,
                    alias: entry.title,
                    size: _recentAvatarSize,
                  )
                else
                  _communityLogo(id, entry.title, null, _recentAvatarSize),
                const SizedBox(height: 8),
                // The entry keeps the name only (decision 0178): no member
                // count or return line is drawn from a stored copy.
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  // L15 R4 title 15/600 (decision 0191).
                  style: LoopType.title,
                ),
                const SizedBox(height: 6),
                pill,
              ],
            ),
            Positioned(
              top: -14,
              right: -12,
              child: _RecentDismiss(
                key: ValueKey<String>(
                  'search-recent-remove-${_recentId(entry)}',
                ),
                name: entry.title,
                onPressed: () => recentController.remove(entry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _recentCardWidth = 150;
  static const double _recentAvatarSize = 56;

  /// `.label-row`: a section label with one Lime word at its end.
  Widget _labelRow({
    required Key key,
    required String label,
    String? action,
    Key? actionKey,
    VoidCallback? onAction,
    bool tight = false,
  }) => Row(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Expanded(child: LoopLabel(label, tight: tight)),
      if (action != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            button: true,
            label: action,
            excludeSemantics: true,
            child: LoopPressable(
              key: actionKey,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LoopTouch.minimum,
                  minWidth: LoopTouch.minimum,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      action,
                      style: LoopTypography.withWeight(
                        LoopType.label,
                        FontWeight.w600,
                      ).copyWith(color: LoopColors.lime),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  /// 全部: one section per domain that answered, in segment order.
  List<Widget> _allSections(SearchState state, SearchController controller) {
    final sections = <Widget>[];
    for (final domain in searchableDomains) {
      final type = switch (domain) {
        SearchDomain.assets => SearchResultType.asset,
        SearchDomain.communities => SearchResultType.community,
        _ => SearchResultType.user,
      };
      final rows = state.results
          .where((result) => result.resultType == type)
          .toList();
      if (rows.isEmpty) continue;
      final more = state.truncated.contains(domain);
      sections
        ..add(
          _labelRow(
            key: ValueKey<String>('search-section-${domain.wireName}'),
            label: domain.label,
            action: more ? '更多' : null,
            actionKey: ValueKey<String>('search-more-${domain.wireName}'),
            onAction: () => controller.selectDomain(domain),
            tight: true,
          ),
        )
        ..addAll(rows.map(_resultRow));
    }
    return <Widget>[...sections, ..._failedLines(state)];
  }

  /// 全部: a domain that refused while another answered says so on its own
  /// line; its refusal is never read as 「没有结果」.
  List<Widget> _failedLines(SearchState state) => <Widget>[
    if (state.all)
      for (final domain in searchableDomains)
        if (state.failedDomains.contains(domain))
          LoopInlineUnavailable(
            key: ValueKey<String>('search-domain-failed-${domain.wireName}'),
            message: '${domain.label}暂时搜不到',
          ),
  ];

  /// The bottom input bar (`.searchbar`): a capsule field and 「粘贴」. It
  /// sits under the list, so the keyboard lifts it with the page.
  Widget _searchBar(SearchController controller) => DecoratedBox(
    key: const ValueKey<String>('search-bar'),
    decoration: const BoxDecoration(
      color: LoopColors.ink,
      border: Border(top: BorderSide(color: LoopColors.line)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        8,
        LoopSpacing.page,
        12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // S121a · decision 0121: one line says what a nickname search can
          // reach. The switch is the privacy centre's 「可被发现」 (decision
          // 0105); a LOOP ID is always found exactly.
          Padding(
            key: const ValueKey<String>('search-scope-hint'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(searchScopeHint, style: LoopType.captionSm),
          ),
          Row(
            children: <Widget>[
              Expanded(child: _field(controller)),
              const SizedBox(width: 8),
              LoopSeg(
                key: const ValueKey<String>('search-paste-loop-id'),
                label: '粘贴',
                selected: false,
                onSelected: () => unawaited(_paste(controller)),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _field(SearchController controller) {
    // UX-008 (decision 0254): the field's corners and focus edge are every
    // field's.
    const border = OutlineInputBorder(
      borderRadius: LoopRadius.control,
      borderSide: BorderSide.none,
    );
    return TextField(
      key: const ValueKey<String>('search-field'),
      controller: _query,
      textInputAction: TextInputAction.search,
      onChanged: controller.type,
      onSubmitted: (value) => unawaited(controller.submit(value)),
      style: LoopType.body,
      decoration: InputDecoration(
        // The field promises only the domains that answer (device
        // walkthrough 2026-09-23 · a55–a65), not 「任何内容」.
        hintText: '$searchFieldLabel…',
        hintStyle: LoopType.body.copyWith(color: LoopColors.text3),
        filled: true,
        fillColor: LoopColors.card2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: LoopRadius.control,
          borderSide: BorderSide(color: LoopColors.purple),
        ),
        prefixIcon: LoopIconButton(
          key: const ValueKey<String>('search-submit'),
          icon: 'search',
          label: '搜索',
          color: LoopColors.text3,
          onPressed: () => unawaited(controller.submit(_query.text)),
        ),
      ),
    );
  }

  /// Reads the clipboard once, on the reader's tap.
  ///
  /// A LOOP ID inside the pasted text is lifted out and asked of 用户
  /// (decision 0104). Otherwise the text itself is the query when it is one
  /// line the server would accept; anything else never enters the field or a
  /// request.
  Future<void> _paste(SearchController controller) async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      data = null;
    }
    if (!mounted) return;
    final loopId = loopIdFromText(data?.text);
    if (loopId != null) {
      _fill(loopId);
      await controller.submit(loopId, domain: SearchDomain.users);
      return;
    }
    final pasted = data?.text?.trim();
    if (pasted == null ||
        pasted.contains('\n') ||
        !searchQueryIsSubmittable(pasted)) {
      LoopToast.show(
        context,
        message: '剪贴板里没有可以搜索的内容',
        kind: LoopToastKind.warn,
      );
      return;
    }
    _fill(pasted);
    await controller.submit(pasted);
  }

  void _fill(String text) {
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    FocusScope.of(context).unfocus();
  }

  /// A community's own face — its preset, or the ground its id is always
  /// given — never bare initials. `stableId` is the community's id.
  Widget _communityLogo(
    String identity,
    String name,
    String? logoRef,
    double size,
  ) => CommunityLogo(
    identity: identity,
    name: name,
    logoRef: logoRef,
    size: size,
  );

  Widget _assetLogo(String symbol, String? logoUrl) => LoopTokenLogo(
    assetSymbol: symbol,
    logoUrl: logoUrl,
    fallbackMonogram: symbol,
    size: 44,
    cornerRadius: LoopRadius.tileValue,
  );

  Widget _resultRow(SearchResult result) {
    final semantic =
        '${result.title}${result.subtitle == null ? '' : '，${result.subtitle}'}';
    return switch (result.resultType) {
      // `.row` with a 44 tile: ticker, a mute type badge, the token's name.
      // The search snapshot carries no price, change or market cap, so the
      // right edge states that instead of printing a figure (AGENTS rule 25).
      SearchResultType.asset => LoopPersonRow(
        key: ValueKey<String>('search-result-${result.stableId}'),
        leading: _assetLogo(result.title, result.logoUrl),
        title: result.title,
        tag: const LoopBadge('代币'),
        subtitle: result.subtitle,
        trailing: Text(
          searchPriceAbsentText,
          key: ValueKey<String>('search-result-price-${result.stableId}'),
          style: LoopType.captionSm.copyWith(color: LoopColors.text3),
        ),
        onTap: () => _open(result),
        semanticLabel: '$semantic，$searchPriceAbsentText',
      ),
      // A community's subtitle is its slug — 「mock-vol-01」 under 「Alpha
      // Signals 1」 — and names nothing a reader can use. The row keeps the
      // member count instead, and only when the server sent one.
      SearchResultType.community => LoopPersonRow(
        key: ValueKey<String>('search-result-${result.stableId}'),
        leading: _communityLogo(
          result.stableId,
          result.title,
          result.avatarRef,
          44,
        ),
        title: result.title,
        subtitle: result.memberCount == null
            ? null
            : '${result.memberCount} 位成员',
        chevron: true,
        onTap: () => _open(result),
        semanticLabel: result.memberCount == null
            ? result.title
            : '${result.title}，${result.memberCount} 位成员',
      ),
      SearchResultType.user => LoopPersonRow(
        key: ValueKey<String>('search-result-${result.stableId}'),
        leading: LoopProfileAvatar(
          avatarRef: result.avatarRef,
          alias: result.title,
          size: 44,
        ),
        title: result.title,
        subtitle: result.subtitle,
        chevron: true,
        onTap: () => _open(result),
        semanticLabel: semantic,
      ),
    };
  }
}

/// What a token row says where a price would be: the search snapshot has
/// none (backend decision 0071), and a figure is never invented for it.
const String searchPriceAbsentText = '搜索不含价格';

/// The × on a recent entry: removes that one entry, 44 square.
class _RecentDismiss extends StatelessWidget {
  const _RecentDismiss({
    required this.name,
    required this.onPressed,
    super.key,
  });

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '从最近搜索移除 $name',
    excludeSemantics: true,
    child: LoopPressable(
      onTap: onPressed,
      child: const SizedBox.square(
        dimension: LoopTouch.minimum,
        child: Center(
          child: LoopIcon('close', size: 14, color: LoopColors.text3),
        ),
      ),
    ),
  );
}
