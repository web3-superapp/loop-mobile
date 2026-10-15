import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/profile_controller.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/public_profile/user_profile_screen.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_copy.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The 「动态」 segment of 广场 (decision 0177): docs/35 「动态（广场）」.
///
/// 全球 / 已关注 chalk-underlined tabs with 「发帖」 at the right, then the
/// timeline: pinned official posts first, then opinions and system events,
/// newest first. The list reads on as it is scrolled, is pulled to refresh,
/// and re-reads its first page every [squareFeedPollInterval] while shown.
class SquareFeedSegment extends ConsumerStatefulWidget {
  const SquareFeedSegment({super.key, this.onNavigate, this.now});

  /// Opens a location. Null pushes it on the router.
  final ValueChanged<String>? onNavigate;

  /// The clock post ages are measured against. Tests pin it.
  final DateTime Function()? now;

  @override
  ConsumerState<SquareFeedSegment> createState() => _SquareFeedSegmentState();
}

class _SquareFeedSegmentState extends ConsumerState<SquareFeedSegment> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(squareFeedPollInterval, (_) {
      if (!mounted) return;
      final scope = ref.read(squareFeedScopeProvider);
      final state = ref.read(squareFeedControllerProvider(scope));
      // A poll never replaces a failure card or a skeleton with another
      // one; it only refreshes rows already on screen.
      if (!state.isReady) return;
      unawaited(
        ref.read(squareFeedControllerProvider(scope).notifier).reload(),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    unawaited(context.push<void>(location));
  }

  Future<void> _compose() async {
    final post = await showLoopSheet<SquareFeedPost>(
      context,
      builder: (context) => const SquareFeedComposer(),
    );
    if (post == null || !mounted) return;
    ref.read(squareOwnPostIdsProvider.notifier).add(post.postId);
    ref
        .read(squareFeedControllerProvider(SquareFeedScope.global).notifier)
        .insertCreated(post);
    LoopToast.show(context, message: '已发布');
  }

  Future<void> _like(SquareFeedScope scope, SquareFeedPost post) async {
    final failure = await ref
        .read(squareFeedControllerProvider(scope).notifier)
        .toggleLike(post.postId);
    if (failure == null || !mounted) return;
    LoopToast.show(
      context,
      message: post.likedByViewer ? '没有取消点赞，请稍后再试' : '没有点上赞，请稍后再试',
      kind: LoopToastKind.warn,
    );
  }

  Future<void> _confirmDelete(
    SquareFeedScope scope,
    SquareFeedPost post,
  ) async {
    final confirmed = await showLoopSheet<bool>(
      context,
      builder: (context) => const _DeleteConfirm(),
    );
    if (confirmed != true || !mounted) return;
    final failure = await ref
        .read(squareFeedControllerProvider(scope).notifier)
        .delete(post.postId);
    if (!mounted) return;
    LoopToast.show(
      context,
      message: failure == null ? '已删除' : '没有删掉，请稍后再试',
      kind: failure == null ? LoopToastKind.ok : LoopToastKind.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(squareFeedScopeProvider);
    final provider = squareFeedControllerProvider(scope);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (state.phase == LoopChainViewPhase.loading && !state.refreshing) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final now = (widget.now ?? DateTime.now)().toUtc();
    final ownLoopId = ref.watch(
      profileControllerProvider.select((value) => value.resource?.loopId),
    );
    final ownPosts = ref.watch(squareOwnPostIdsProvider);
    final page = state.value;
    return LoopStreamPage(
      key: const ValueKey<String>('square-feed'),
      archetype: LoopPageArchetype.listing,
      title: '动态',
      embedded: true,
      tabPage: true,
      updating: state.refreshing,
      onRefresh: controller.reload,
      filters: _FeedTabs(
        scope: scope,
        onSelected: (next) =>
            ref.read(squareFeedScopeProvider.notifier).select(next),
        onCompose: () => unawaited(_compose()),
      ),
      collection: ListView(
        key: const ValueKey<String>('square-feed-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          if (page == null)
            _FeedStateBlock(
              state: state,
              onRetry: () => unawaited(controller.reload()),
            )
          else if (page.items.isEmpty)
            LoopEmptyState(
              key: const ValueKey<String>('square-feed-empty'),
              illustration: LoopIllustration.chat,
              title: '还没有动态',
              message: scope == SquareFeedScope.following
                  ? '你关注的人发帖、买入或领奖时会出现在这里'
                  : '有人发帖、买入、领奖或代币毕业时会出现在这里',
            )
          else ...<Widget>[
            LoopFreshnessStrip(
              key: const ValueKey<String>('square-feed-freshness'),
              refreshing: state.refreshing,
              refreshFailed:
                  state.failureKind != null && page.nextCursor == null,
              readAt: page.observedAt,
              onRetry: () => unawaited(controller.reload()),
            ),
            for (final post in page.items)
              SquareFeedPostRow(
                key: ValueKey<String>('square-post-${post.postId}'),
                post: post,
                now: now,
                onLike: () => unawaited(_like(scope, post)),
                onOpen: _open,
                onLongPress: _isOwn(post, ownLoopId, ownPosts)
                    ? () => unawaited(_confirmDelete(scope, post))
                    : null,
              ),
            if (page.nextCursor case final String cursor)
              if (state.failureKind != null && !state.refreshing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: LoopInlineUnavailable(
                    key: const ValueKey<String>('square-feed-more-failed'),
                    message: '下一页没有读到',
                    onRetry: () => unawaited(controller.loadMore()),
                  ),
                )
              else
                LoopLoadMoreSentinel(
                  key: const ValueKey<String>('square-feed-load-more'),
                  cursor: cursor,
                  onLoadMore: () => unawaited(controller.loadMore()),
                )
            else
              const SizedBox(
                key: ValueKey<String>('square-feed-end'),
                height: 12,
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: LoopProvenanceLine(
                key: const ValueKey<String>('square-feed-observed'),
                sources: const <String>['LOOP'],
                observedAt: page.observedAt,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _isOwn(
    SquareFeedPost post,
    String? ownLoopId,
    Set<String> ownPosts,
  ) {
    if (post.kind != SquareFeedPostKind.opinion) return false;
    if (ownPosts.contains(post.postId)) return true;
    return ownLoopId != null && post.author?.loopId == ownLoopId;
  }
}

/// 全球 / 已关注 and 「发帖」. The design's filter glyph is not drawn: the
/// timeline has no filter to offer yet.
class _FeedTabs extends StatelessWidget {
  const _FeedTabs({
    required this.scope,
    required this.onSelected,
    required this.onCompose,
  });

  final SquareFeedScope scope;
  final ValueChanged<SquareFeedScope> onSelected;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: LoopColors.line)),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: MarketTabBar(
              key: const ValueKey<String>('square-feed-tabs'),
              keyPrefix: 'square-feed-tab',
              labels: <String>[
                for (final value in SquareFeedScope.values) value.label,
              ],
              selectedIndex: scope.index,
              onSelected: (index) => onSelected(SquareFeedScope.values[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, LoopSpacing.page, 4),
            child: Center(
              child: LoopButton(
                key: const ValueKey<String>('square-feed-compose'),
                label: '发帖',
                icon: 'plus',
                onPressed: onCompose,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeedStateBlock extends StatelessWidget {
  const _FeedStateBlock({required this.state, required this.onRetry});

  final LoopChainResourceState<SquareFeedPage> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.phase == LoopChainViewPhase.loading) {
      return const Padding(
        key: ValueKey<String>('square-feed-loading'),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LoopSkeleton(type: LoopSkeletonType.record, rows: 4),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LoopInlineUnavailable(
        key: const ValueKey<String>('square-feed-unavailable'),
        message: '动态暂时读不到',
        detail: loopChainFailureReason(state.failureKind),
        detailMaxLines: 3,
        onRetry: state.phase == LoopChainViewPhase.unavailable ? null : onRetry,
      ),
    );
  }
}

/// `.feed-post` (decision 0187, docs/35 body4 「动态 A」): a 32 avatar, the
/// name, the kind badge and the age on one line; the text (or, for an event,
/// the sentence [squareFeedPostSentence] writes); the token's quote capsule;
/// ♡. Everything under the head is indented past the avatar.
class SquareFeedPostRow extends StatelessWidget {
  const SquareFeedPostRow({
    required this.post,
    required this.now,
    required this.onLike,
    required this.onOpen,
    super.key,
    this.onLongPress,
  });

  final SquareFeedPost post;
  final DateTime now;
  final VoidCallback onLike;
  final ValueChanged<String> onOpen;

  /// Offered on the viewer's own posts only: asks to delete.
  final VoidCallback? onLongPress;

  /// The avatar column; the rows under the head are indented past it.
  static const double avatarSize = 32;
  static const double indent = avatarSize + 8;

  /// `.feed-token`: the quote capsule's fixed height.
  static const double capsuleHeight = 40;

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    final name = author?.displayName ?? 'LOOP 官方';
    final token = post.token;
    final badge = squareFeedBadge(post);
    final sentence = squareFeedPostSentence(post);
    final content = Container(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        12,
        LoopSpacing.page,
        4,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: avatarSize,
            child: Row(
              children: <Widget>[
                Flexible(
                  child: InkWell(
                    key: const ValueKey<String>('square-post-author'),
                    borderRadius: LoopRadius.inner,
                    onTap: author == null
                        ? null
                        : () => onOpen(
                            userProfileLocation(author.publicProfileId),
                          ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (author == null)
                          const _OfficialAvatar()
                        else
                          LoopProfileAvatar(
                            avatarRef: author.avatarRef,
                            alias: author.displayName,
                            size: avatarSize,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            key: const ValueKey<String>('square-post-name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // L14 R4 the author at title 15 (decision 0191).
                            style: LoopType.title,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (badge != null) ...<Widget>[const SizedBox(width: 8), badge],
                const Spacer(),
                const SizedBox(width: 8),
                Text(
                  squareFeedAgeLabel(post.createdAt, now: now),
                  key: const ValueKey<String>('square-post-age'),
                  maxLines: 1,
                  style: LoopType.figureXs.copyWith(color: LoopColors.text3),
                ),
              ],
            ),
          ),
          if (sentence != null)
            Padding(
              padding: const EdgeInsets.only(left: indent, top: 6),
              child: post.kind == SquareFeedPostKind.system
                  ? _OfficialRecap(text: sentence)
                  : SquareFeedText(
                      key: const ValueKey<String>('square-post-text'),
                      text: sentence,
                      style: LoopType.bodySm.copyWith(color: LoopColors.chalk),
                    ),
            ),
          if (token != null)
            Padding(
              padding: const EdgeInsets.only(left: indent, top: 8),
              child: SquareFeedQuoteCapsule(
                token: token,
                onTap: () {
                  final location = squareFeedTokenLocation(token);
                  if (location != null) onOpen(location);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: indent - 8, top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _LikeButton(post: post, onTap: onLike),
            ),
          ),
        ],
      ),
    );
    if (onLongPress == null) return content;
    return Semantics(
      onLongPressHint: '删除这条动态',
      child: GestureDetector(
        key: const ValueKey<String>('square-post-own'),
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: content,
      ),
    );
  }
}

/// `.feed-token`: one Card-ground capsule, 40 high — a 24 logo, the ticker,
/// the market cap in text2, then the price (zeros folded, one line) and the
/// 1 h move in its rise / fall colour. A figure the server did not read is
/// not drawn at all.
class SquareFeedQuoteCapsule extends StatelessWidget {
  const SquareFeedQuoteCapsule({required this.token, super.key, this.onTap});

  final SquareFeedToken token;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cap = token.marketCapUsd1;
    final price = token.priceUsd1;
    final move = squareFeedQuoteMove(token);
    return Material(
      color: LoopColors.card,
      borderRadius: LoopRadius.control,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey<String>('square-post-token'),
        onTap: onTap,
        child: SizedBox(
          key: const ValueKey<String>('square-post-quote'),
          height: SquareFeedPostRow.capsuleHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Logo, its gap and a few letters of the ticker stay.
                final figuresMax = (constraints.maxWidth - 24 - 8 - 40).clamp(
                  0.0,
                  double.infinity,
                );
                return Row(
                  children: <Widget>[
                    MemeLogo(
                      symbol: token.symbol,
                      imageUrl: token.logoUrl,
                      identity: token.id,
                      size: 24,
                      radius: 12,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              token.symbol,
                              key: const ValueKey<String>('square-post-symbol'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // L14 capsule words at caption 12, figures at
                              // figure 13 / figureXs 11 (decision 0191).
                              style: LoopTypography.withWeight(
                                LoopType.caption,
                                FontWeight.w600,
                              ).copyWith(color: LoopColors.chalk),
                            ),
                          ),
                          if (cap != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '市值 ${memeCapLabel(cap)}',
                                key: const ValueKey<String>('square-post-cap'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopType.caption.copyWith(
                                  color: LoopColors.text2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (price != null || move != null)
                      ConstrainedBox(
                        // The figures come first and never wrap; on a phone too
                        // narrow for them they shrink, the ticker gives way first.
                        constraints: BoxConstraints(maxWidth: figuresMax),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(width: 8),
                              if (price != null)
                                Text(
                                  squareFeedQuotePrice(price),
                                  key: const ValueKey<String>(
                                    'square-post-price',
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: LoopType.figure,
                                ),
                              if (price != null && move != null)
                                const SizedBox(width: 6),
                              if (move != null)
                                Text(
                                  loopSignedPercent(move),
                                  key: const ValueKey<String>(
                                    'square-post-change',
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  style:
                                      LoopTypography.withWeight(
                                        LoopType.figureXs,
                                        FontWeight.w600,
                                      ).copyWith(
                                        color: LoopPriceMove.of(move).color,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The capsule's price: the list row's figure with a long zero run folded
/// (`$0.0₅4173`), so it fits one line.
String squareFeedQuotePrice(Decimal price) =>
    loopFoldedZerosPrice(memePriceLabel(price));

/// The capsule's 1 h move, or `null` when there is nothing to say: unread,
/// or exactly flat — TF 23 showed 「0.00%」 on every quiet token, which reads
/// as a figure while telling the reader nothing (decision 0187).
Decimal? squareFeedQuoteMove(SquareFeedToken token) {
  final change = token.change1hPct;
  if (change == null || change == Decimal.zero) return null;
  return change;
}

/// What a post says under its head (decision 0187 §3). A person's post and
/// LOOP's own say their text; an event the server wrote from the chain has
/// no text, so one sentence is made from its kind and facts:
///
/// - graduation 「X 打满内盘，官方池已建，回购开始。」
/// - claim 「在 X 第 N 轮领到 N USD1，权重 x%。」 (each missing fact left out)
/// - buy 「买入 N USD1 的 X。」
///
/// A fact that was not sent is left out of the sentence, never written as 0;
/// `null` when there is nothing true to say.
String? squareFeedPostSentence(SquareFeedPost post) {
  final text = post.text?.trim();
  if (text != null && text.isNotEmpty) return post.text;
  final symbol = post.token?.symbol.trim();
  final named = symbol == null || symbol.isEmpty ? null : symbol;
  String? usd1(String key) => switch (post.eventDecimal(key)) {
    final Decimal amount when amount > Decimal.zero =>
      '${loopFormatDecimal(amount, maxFractionDigits: 2)} USD1',
    _ => null,
  };
  switch (post.kind) {
    case SquareFeedPostKind.opinion:
    case SquareFeedPostKind.system:
      return null;
    case SquareFeedPostKind.graduation:
      return named == null ? '这个代币打满内盘，官方池已建，回购开始。' : '$named 打满内盘，官方池已建，回购开始。';
    case SquareFeedPostKind.buy:
      final amount = usd1('amountUsd1');
      if (amount == null) return null;
      return named == null ? '买入 $amount。' : '买入 $amount 的 $named。';
    case SquareFeedPostKind.claim:
      final amount = usd1('amountUsd1');
      final roundText = post.event['roundId'];
      final round = roundText == null ? null : int.tryParse(roundText);
      final weight = post.eventDecimal('weightPct');
      final where = <String>[
        if (named != null) '在 $named',
        if (round != null && round > 0) '第 $round 轮',
      ].join(' ');
      final got = amount == null ? '领到奖励' : '领到 $amount';
      // 「第 2 轮领到」 runs on; a Latin ticker before 「领到」 keeps its space.
      final head = where.isEmpty
          ? got
          : where.endsWith('轮')
          ? '$where$got'
          : '$where $got';
      return weight == null || weight < Decimal.zero
          ? '$head。'
          : '$head，权重 ${loopFormatDecimal(weight, maxFractionDigits: 2)}%。';
  }
}

/// The kind badge (decisions 0177 §2, 0187). `system` carries one only when
/// pinned. The claim's amount moved into the sentence, so its badge is the
/// word alone.
Widget? squareFeedBadge(SquareFeedPost post) => switch (post.kind) {
  SquareFeedPostKind.opinion => const LoopBadge(
    '观点',
    key: ValueKey<String>('square-post-badge-opinion'),
  ),
  SquareFeedPostKind.buy => const LoopBadge(
    '买入',
    key: ValueKey<String>('square-post-badge-buy'),
    kind: LoopBadgeKind.launch,
  ),
  SquareFeedPostKind.claim => const LoopBadge(
    '领奖',
    key: ValueKey<String>('square-post-badge-claim'),
    kind: LoopBadgeKind.up,
  ),
  SquareFeedPostKind.graduation => const LoopBadge(
    '毕业',
    key: ValueKey<String>('square-post-badge-graduation'),
    kind: LoopBadgeKind.launch,
  ),
  SquareFeedPostKind.system =>
    post.pinned
        ? const LoopBadge(
            '置顶',
            key: ValueKey<String>('square-post-badge-pinned'),
          )
        : null,
};

/// Where a quoted token opens: its MEME or MEME v2 page.
String? squareFeedTokenLocation(SquareFeedToken token) {
  final id = token.id;
  if (id == null) return null;
  return switch (token.kind) {
    SquareFeedTokenKind.meme => MemeRoute.token(id),
    SquareFeedTokenKind.launch2 => Launch2Route.instance(id),
  };
}

/// 「43s」「12m」「5h」「3d」, then the date: the design's compact ages.
String squareFeedAgeLabel(DateTime createdAt, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final age = reference.difference(createdAt.toUtc());
  if (age.inSeconds < 1) return '刚刚';
  if (age.inMinutes < 1) return '${age.inSeconds}s';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 30) return '${age.inDays}d';
  final local = createdAt.toLocal();
  return '${local.month} 月 ${local.day} 日';
}

/// LOOP's own face on an official post: the flat brand mark on Card2.
class _OfficialAvatar extends StatelessWidget {
  const _OfficialAvatar();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('square-post-official-avatar'),
    width: SquareFeedPostRow.avatarSize,
    height: SquareFeedPostRow.avatarSize,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: LoopColors.card2,
    ),
    child: const LoopBrandMark(
      kind: LoopBrandMarkKind.appIcon,
      height: 18,
      vector: true,
      semanticLabel: 'LOOP 官方',
    ),
  );
}

/// `.recap`: an official post in a record card; past three lines it folds
/// behind a Lime 「展开」.
class _OfficialRecap extends StatefulWidget {
  const _OfficialRecap({required this.text});

  final String text;

  static const int foldedLines = 3;

  @override
  State<_OfficialRecap> createState() => _OfficialRecapState();
}

class _OfficialRecapState extends State<_OfficialRecap> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lines = widget.text.split('\n');
    final title = lines.length > 1 ? lines.first.trim() : null;
    final body = title == null ? widget.text : lines.skip(1).join('\n').trim();
    final style = LoopType.caption.copyWith(color: LoopColors.text2);
    return LoopRecordCard(
      key: const ValueKey<String>('square-post-recap'),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                title,
                style: LoopTypography.withWeight(
                  LoopType.titleSm,
                  FontWeight.w600,
                ),
              ),
            ),
          if (body.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: body, style: style),
                  maxLines: _OfficialRecap.foldedLines,
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout(maxWidth: constraints.maxWidth);
                final overflows = painter.didExceedMaxLines;
                painter.dispose();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SquareFeedText(
                      key: const ValueKey<String>('square-post-text'),
                      text: body,
                      style: style,
                      maxLines: _expanded ? null : _OfficialRecap.foldedLines,
                    ),
                    if (overflows && !_expanded)
                      Semantics(
                        button: true,
                        child: InkWell(
                          key: const ValueKey<String>('square-post-expand'),
                          onTap: () => setState(() => _expanded = true),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 32),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1,
                              child: Text(
                                '展开',
                                style: LoopTypography.withWeight(
                                  LoopType.label,
                                  FontWeight.w600,
                                ).copyWith(color: LoopColors.lime),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Post text with its links in Lime, underlined. A tap on a link copies it
/// and says so; LOOP never opens a browser from a post.
class SquareFeedText extends StatefulWidget {
  const SquareFeedText({
    required this.text,
    required this.style,
    super.key,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;

  /// `https://…`, or a bare host with a path (`x.com/status/…`).
  static final RegExp linkPattern = RegExp(
    r'(?:https?://[^\s]+|(?<![@\w.$])(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}/[^\s]*)',
  );

  @override
  State<SquareFeedText> createState() => _SquareFeedTextState();
}

class _SquareFeedTextState extends State<SquareFeedText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in SquareFeedText.linkPattern.allMatches(widget.text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      final link = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () =>
            unawaited(LoopCopy.text(context, link, message: '已复制链接'));
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: link,
          recognizer: recognizer,
          style: const TextStyle(
            color: LoopColors.lime,
            decoration: TextDecoration.underline,
            decorationColor: LoopColors.lime,
          ),
        ),
      );
      start = match.end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// ♡ and the count; Lime while the viewer likes the post.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.post, required this.onTap});

  /// The foot line (`.feed-foot`): 32 high, so a post stays near the design's
  /// 90 dp; the full row width beside it is free for the long-press.
  static const double likeHeight = 32;

  final SquareFeedPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = post.likedByViewer ? LoopColors.lime : LoopColors.text3;
    return Semantics(
      button: true,
      toggled: post.likedByViewer,
      label: post.likedByViewer ? '取消点赞' : '点赞',
      value: '${post.likeCount}',
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('square-post-like'),
        borderRadius: LoopRadius.inner,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: likeHeight,
            minWidth: likeHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopIcon('react-heart', size: 15, color: color),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  key: const ValueKey<String>('square-post-like-count'),
                  style: LoopTypography.withWeight(
                    LoopType.figureSm,
                    FontWeight.w500,
                  ).copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm();

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('square-post-delete-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const LoopSheetHeading('删除这条动态？'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          '删除后所有人都看不到它，也不能恢复。',
          // M18 R19 sheet support copy: bodySm 13 (decision 0191).
          style: LoopType.bodySm,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: LoopButton(
          key: const ValueKey<String>('square-post-delete-confirm'),
          label: '删除',
          primary: true,
          block: true,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LoopButton(
          key: const ValueKey<String>('square-post-delete-cancel'),
          label: '取消',
          block: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
    ],
  );
}

/// The 发帖 sheet: the text (n/500), an optional token from the MEME tokens
/// opened in this run, and 「发布」 — the sheet's one Lime body.
class SquareFeedComposer extends ConsumerStatefulWidget {
  const SquareFeedComposer({super.key});

  @override
  ConsumerState<SquareFeedComposer> createState() => _SquareFeedComposerState();
}

class _SquareFeedComposerState extends ConsumerState<SquareFeedComposer> {
  final TextEditingController _text = TextEditingController();
  SquareFeedTokenRef? _token;
  bool _sending = false;
  String? _error;

  /// One key per (text, token) attempt: a retry of the same post replays,
  /// an edited post is a new one.
  String? _keyFor;
  String _key = squareFeedIdempotencyKey();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _length => _text.text.trim().runes.length;

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _length > SquareFeedPost.textMax || _sending) return;
    final attempt = '${_token?.kind.name}:${_token?.id}:$text';
    if (_keyFor != attempt) {
      _keyFor = attempt;
      _key = squareFeedIdempotencyKey();
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final post = await ref
          .read(squareFeedGatewayProvider)
          .createPost(text: text, idempotencyKey: _key, tokenRef: _token);
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } on LoopChainException catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = squareFeedPostFailureText(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = squareFeedPostFailureText(
          const LoopChainException(LoopChainFailureKind.unexpected),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(squareRecentTokensProvider);
    final length = _length;
    final over = length > SquareFeedPost.textMax;
    final canSend = length > 0 && !over && !_sending;
    final error = _error;
    return Column(
      key: const ValueKey<String>('square-composer'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSheetHeading('发帖'),
        LoopFlatField(
          label: '内容',
          footnote: '$length/${SquareFeedPost.textMax}',
          error: over,
          child: TextField(
            key: const ValueKey<String>('square-composer-field'),
            controller: _text,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            style: LoopType.bodyLg,
            decoration: loopFormFieldDecoration(hint: '说点什么…'),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        if (recent.isNotEmpty) ...<Widget>[
          const LoopLabel('引用代币（可不选）'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                LoopSeg(
                  key: const ValueKey<String>('square-composer-token-none'),
                  label: '不带代币',
                  quiet: true,
                  selected: _token == null,
                  onSelected: _sending
                      ? null
                      : () => setState(() => _token = null),
                ),
                for (final token in recent)
                  LoopSeg(
                    key: ValueKey<String>('square-composer-token-${token.id}'),
                    label: token.symbol,
                    quiet: true,
                    selected: _token == token,
                    onSelected: _sending
                        ? null
                        : () => setState(() => _token = token),
                  ),
              ],
            ),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LoopInlineUnavailable(
              key: const ValueKey<String>('square-composer-error'),
              message: error,
              maxLines: 2,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: LoopButton(
            key: const ValueKey<String>('square-composer-send'),
            label: _sending ? '发布中…' : '发布',
            primary: true,
            block: true,
            onPressed: canSend ? () => unawaited(_send()) : null,
          ),
        ),
      ],
    );
  }
}
