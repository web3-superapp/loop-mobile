import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:uuid/uuid.dart';

/// 广场「动态」 (decision 0177, loop-api decision 0143): one timeline of user
/// opinions, system events (a member's buy, a reward claim, a graduation) and
/// pinned official posts, each optionally quoting one token.

/// `scope`: every visible post, or the accounts the viewer follows.
enum SquareFeedScope {
  global('global', '全球'),
  following('following', '已关注');

  const SquareFeedScope(this.wireName, this.label);

  final String wireName;
  final String label;
}

/// `kind`. `opinion` is a person's post; `buy` / `claim` / `graduation` are
/// written by the server from indexed events; `system` is LOOP's own.
enum SquareFeedPostKind {
  opinion('opinion'),
  buy('buy'),
  claim('claim'),
  graduation('graduation'),
  system('system');

  const SquareFeedPostKind(this.wireName);

  final String wireName;

  static SquareFeedPostKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// `token.kind`: a MEME v1 token or a MEME v2 (launch2) instance.
enum SquareFeedTokenKind {
  meme('meme'),
  launch2('launch2');

  const SquareFeedTokenKind(this.wireName);

  final String wireName;

  static SquareFeedTokenKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// The author, as the public identity projection names them.
@immutable
final class SquareFeedAuthor {
  const SquareFeedAuthor({
    required this.publicProfileId,
    required this.loopId,
    this.alias,
    this.avatarRef,
  });

  final String publicProfileId;
  final String loopId;
  final String? alias;

  /// The stored `avatar:` reference, drawn by the public-profile rules.
  final String? avatarRef;

  /// The alias, else the LOOP ID.
  String get displayName {
    final value = alias?.trim();
    return value == null || value.isEmpty ? loopId : value;
  }
}

/// The quote line. Every figure the server could not read is `null` and is
/// not drawn; none of them is ever replaced by a zero.
@immutable
final class SquareFeedToken {
  const SquareFeedToken({
    required this.kind,
    required this.symbol,
    this.memeTokenId,
    this.instanceId,
    this.logoUrl,
    this.priceUsd1,
    this.change1hPct,
    this.marketCapUsd1,
  });

  final SquareFeedTokenKind kind;
  final String? memeTokenId;
  final String? instanceId;
  final String symbol;

  /// The address this build loads the picture from, or `null`.
  final String? logoUrl;
  final Decimal? priceUsd1;
  final Decimal? change1hPct;
  final Decimal? marketCapUsd1;

  /// The id the token page and a post's `tokenRef` use.
  String? get id => switch (kind) {
    SquareFeedTokenKind.meme => memeTokenId,
    SquareFeedTokenKind.launch2 => instanceId,
  };
}

/// One post on the timeline.
@immutable
final class SquareFeedPost {
  SquareFeedPost({
    required this.postId,
    required this.kind,
    required this.likeCount,
    required this.likedByViewer,
    required this.pinned,
    required this.createdAt,
    this.author,
    this.text,
    this.token,
    Map<String, String> event = const <String, String>{},
  }) : event = Map<String, String>.unmodifiable(event);

  /// The most characters a post may hold (code points, as the server counts).
  static const int textMax = 500;

  final String postId;
  final SquareFeedPostKind kind;

  /// `null` only for LOOP's own [SquareFeedPostKind.system] posts.
  final SquareFeedAuthor? author;
  final String? text;
  final SquareFeedToken? token;

  /// The event's string facts (`amountUsd1`, `roundId`, `weightPct`, …);
  /// only the keys the server sent with a value.
  final Map<String, String> event;
  final int likeCount;
  final bool likedByViewer;
  final bool pinned;
  final DateTime createdAt;

  /// A decimal event fact, or `null` when it is absent or not a number.
  Decimal? eventDecimal(String key) {
    final value = event[key];
    return value == null ? null : Decimal.tryParse(value);
  }

  SquareFeedPost withLike({required int count, required bool liked}) =>
      SquareFeedPost(
        postId: postId,
        kind: kind,
        author: author,
        text: text,
        token: token,
        event: event,
        likeCount: count < 0 ? 0 : count,
        likedByViewer: liked,
        pinned: pinned,
        createdAt: createdAt,
      );
}

/// One page of `GET /v2/square/feed`.
@immutable
final class SquareFeedPage {
  SquareFeedPage({
    required this.scope,
    required List<SquareFeedPost> items,
    required this.nextCursor,
    required this.observedAt,
  }) : items = List<SquareFeedPost>.unmodifiable(items);

  final SquareFeedScope scope;
  final List<SquareFeedPost> items;
  final String? nextCursor;
  final DateTime observedAt;
}

/// `{postId, likeCount, likedByViewer}` after a like write.
@immutable
final class SquareFeedLike {
  const SquareFeedLike({
    required this.postId,
    required this.likeCount,
    required this.likedByViewer,
  });

  final String postId;
  final int likeCount;
  final bool likedByViewer;
}

/// A post's optional token reference on `POST /v2/square/posts`.
@immutable
final class SquareFeedTokenRef {
  const SquareFeedTokenRef({
    required this.kind,
    required this.id,
    required this.symbol,
    this.logoUrl,
  });

  final SquareFeedTokenKind kind;
  final String id;

  /// Shown in the composer only; never sent.
  final String symbol;
  final String? logoUrl;

  @override
  bool operator ==(Object other) =>
      other is SquareFeedTokenRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Feature-facing port. No transport type and no route literal crosses it.
abstract interface class SquareFeedGateway {
  LoopChainGatewayMode get mode;

  /// One page. `cursor` and a page size are exclusive on the server, so a
  /// paging read carries the cursor alone.
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor});

  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  });

  Future<void> deletePost(String postId);

  Future<SquareFeedLike> setLike(String postId, {required bool liked});
}

/// Production default: unavailable, so the segment is not drawn.
final class UnavailableSquareFeedGateway implements SquareFeedGateway {
  const UnavailableSquareFeedGateway();

  static const _closed = LoopChainException(LoopChainFailureKind.unavailable);

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) =>
      Future<SquareFeedPage>.error(_closed);

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) => Future<SquareFeedPost>.error(_closed);

  @override
  Future<void> deletePost(String postId) => Future<void>.error(_closed);

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) =>
      Future<SquareFeedLike>.error(_closed);
}

/// Overridden by the composition root with the authenticated V2 adapter.
final squareFeedGatewayProvider = Provider<SquareFeedGateway>(
  (ref) => const UnavailableSquareFeedGateway(),
);

/// Whether 广场 draws its 「动态」 segment: the server's `squareFeed`
/// capability is usable and an adapter is mounted to ask. Otherwise the page
/// is exactly what it was before (社区 / 语音房).
bool squareFeedVisible(WidgetRef ref) {
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.squareFeed),
  );
  final mode = ref.watch(squareFeedGatewayProvider.select((g) => g.mode));
  return capability.isUsable && mode != LoopChainGatewayMode.unavailable;
}

/// How often the timeline on screen re-reads its first page.
const Duration squareFeedPollInterval = Duration(seconds: 60);

/// The timeline of one scope.
final class SquareFeedController
    extends LoopChainReadController<SquareFeedPage> {
  SquareFeedController(this.scope);

  final SquareFeedScope scope;

  @override
  LoopChainGatewayMode watchMode() =>
      ref.watch(squareFeedGatewayProvider.select((g) => g.mode));

  @override
  Future<SquareFeedPage> fetch() =>
      ref.read(squareFeedGatewayProvider).loadFeed(scope);

  var _loadingMore = false;

  /// Reads the page after the one on screen and appends it. A post already
  /// held is not added again; the order is the server's.
  Future<bool> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || _loadingMore) return false;
    _loadingMore = true;
    try {
      final page = await ref
          .read(squareFeedGatewayProvider)
          .loadFeed(scope, cursor: cursor);
      if (!ref.mounted) return false;
      final latest = state.value ?? current;
      final held = <String>{for (final post in latest.items) post.postId};
      state = state.ready(
        SquareFeedPage(
          scope: scope,
          items: <SquareFeedPost>[
            ...latest.items,
            for (final post in page.items)
              if (held.add(post.postId)) post,
          ],
          nextCursor: page.nextCursor,
          observedAt: latest.observedAt,
        ),
      );
      return true;
    } on LoopChainException catch (error) {
      if (ref.mounted) state = state.failed(error.kind);
      return false;
    } catch (_) {
      if (ref.mounted) state = state.failed(LoopChainFailureKind.readFailed);
      return false;
    } finally {
      _loadingMore = false;
    }
  }

  void _replace(SquareFeedPost Function(SquareFeedPost post)? map, String id) {
    final current = state.value;
    if (current == null) return;
    state = state.ready(
      SquareFeedPage(
        scope: current.scope,
        items: <SquareFeedPost>[
          for (final post in current.items)
            if (post.postId != id) post else if (map != null) map(post),
        ],
        nextCursor: current.nextCursor,
        observedAt: current.observedAt,
      ),
    );
  }

  SquareFeedPost? _find(String postId) {
    for (final post in state.value?.items ?? const <SquareFeedPost>[]) {
      if (post.postId == postId) return post;
    }
    return null;
  }

  final Set<String> _liking = <String>{};

  /// Flips the viewer's like at once and asks the server. A refusal puts the
  /// post back as it was and returns the failure; the server's answer, when
  /// it comes, is the count that stays.
  Future<LoopChainFailureKind?> toggleLike(String postId) async {
    final before = _find(postId);
    if (before == null || !_liking.add(postId)) return null;
    final liked = !before.likedByViewer;
    _replace(
      (post) =>
          post.withLike(count: post.likeCount + (liked ? 1 : -1), liked: liked),
      postId,
    );
    try {
      final answer = await ref
          .read(squareFeedGatewayProvider)
          .setLike(postId, liked: liked);
      if (!ref.mounted) return null;
      _replace(
        (post) =>
            post.withLike(count: answer.likeCount, liked: answer.likedByViewer),
        postId,
      );
      return null;
    } on LoopChainException catch (error) {
      if (ref.mounted) {
        _replace(
          (post) => post.withLike(
            count: before.likeCount,
            liked: before.likedByViewer,
          ),
          postId,
        );
      }
      return error.kind;
    } catch (_) {
      if (ref.mounted) {
        _replace(
          (post) => post.withLike(
            count: before.likeCount,
            liked: before.likedByViewer,
          ),
          postId,
        );
      }
      return LoopChainFailureKind.unexpected;
    } finally {
      _liking.remove(postId);
    }
  }

  /// Deletes one of the viewer's own posts. Only an answered delete takes the
  /// row off the list.
  Future<LoopChainFailureKind?> delete(String postId) async {
    try {
      await ref.read(squareFeedGatewayProvider).deletePost(postId);
      if (ref.mounted) _replace(null, postId);
      return null;
    } on LoopChainException catch (error) {
      // Already gone on the server: the row goes too.
      if (error.kind == LoopChainFailureKind.notFound && ref.mounted) {
        _replace(null, postId);
        return null;
      }
      return error.kind;
    } catch (_) {
      return LoopChainFailureKind.unexpected;
    }
  }

  /// Puts the viewer's new post under the pinned ones, where the server's
  /// own order would put it.
  void insertCreated(SquareFeedPost post) {
    final current = state.value;
    if (current == null) return;
    if (current.items.any((item) => item.postId == post.postId)) return;
    final pinned = current.items.takeWhile((item) => item.pinned).length;
    state = state.ready(
      SquareFeedPage(
        scope: current.scope,
        items: <SquareFeedPost>[
          ...current.items.take(pinned),
          post,
          ...current.items.skip(pinned),
        ],
        nextCursor: current.nextCursor,
        observedAt: current.observedAt,
      ),
    );
  }
}

final squareFeedControllerProvider = NotifierProvider.autoDispose
    .family<
      SquareFeedController,
      LoopChainResourceState<SquareFeedPage>,
      SquareFeedScope
    >(SquareFeedController.new);

/// Which scope the segment shows; it survives leaving the tab.
final squareFeedScopeProvider =
    NotifierProvider<SquareFeedScopeNotifier, SquareFeedScope>(
      SquareFeedScopeNotifier.new,
    );

final class SquareFeedScopeNotifier extends Notifier<SquareFeedScope> {
  @override
  SquareFeedScope build() => SquareFeedScope.global;

  void select(SquareFeedScope scope) => state = scope;
}

/// The posts this account wrote in this run. Long-press delete is offered on
/// them and on any post whose author is the viewer's own LOOP ID.
final squareOwnPostIdsProvider =
    NotifierProvider<SquareOwnPostIds, Set<String>>(SquareOwnPostIds.new);

final class SquareOwnPostIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(loopAccountScopeProvider);
    return const <String>{};
  }

  void add(String postId) => state = <String>{...state, postId};
}

/// The MEME tokens this account opened in this run, newest first. The
/// composer offers them as the post's token; nothing is stored on the device.
final squareRecentTokensProvider =
    NotifierProvider<SquareRecentTokens, List<SquareFeedTokenRef>>(
      SquareRecentTokens.new,
    );

final class SquareRecentTokens extends Notifier<List<SquareFeedTokenRef>> {
  static const int limit = 8;

  @override
  List<SquareFeedTokenRef> build() {
    ref.watch(loopAccountScopeProvider);
    return const <SquareFeedTokenRef>[];
  }

  void record(SquareFeedTokenRef token) {
    if (state.isNotEmpty &&
        state.first == token &&
        state.first.symbol == token.symbol &&
        state.first.logoUrl == token.logoUrl) {
      return;
    }
    state = <SquareFeedTokenRef>[
      token,
      ...state.where((held) => held != token),
    ].take(limit).toList(growable: false);
  }
}

/// One token the composer offers (decision 0230): the ref a post carries,
/// plus the name the search reads. Never sent beyond [ref].
@immutable
final class SquareComposerTokenOption {
  const SquareComposerTokenOption({required this.ref, required this.name});

  final SquareFeedTokenRef ref;

  /// The project name; a token opened in this run has only its symbol.
  final String name;

  /// Whether [query] (already trimmed) is in the ticker or the name, any case.
  bool matches(String query) {
    final needle = query.toLowerCase();
    if (needle.isEmpty) return true;
    final ticker = ref.symbol.toLowerCase();
    return ticker.contains(needle) ||
        ticker.replaceFirst(r'$', '').contains(needle) ||
        name.toLowerCase().contains(needle);
  }
}

/// How many token capsules the composer draws before 「更多」.
const int squareComposerTokenChips = 8;

/// Decision 0230: the composer's token candidates, in order and without a
/// repeat — ① the MEME tokens opened in this run ([recent]); ② the MEME v2
/// tokens this account holds ([positions], a row the wallet would draw);
/// ③ the MEME v2 projects already read for the MEME Tab ([rows]). Nothing
/// here asks the server; every source is a read the app already makes.
List<SquareComposerTokenOption> squareComposerTokenOptions({
  List<SquareFeedTokenRef> recent = const <SquareFeedTokenRef>[],
  List<Launch2Position> positions = const <Launch2Position>[],
  List<Launch2InstanceRow> rows = const <Launch2InstanceRow>[],
}) {
  final out = <SquareComposerTokenOption>[];
  final seen = <SquareFeedTokenRef>{};
  void add(SquareComposerTokenOption option) {
    if (option.ref.id.isEmpty || option.ref.symbol.trim().isEmpty) return;
    if (seen.add(option.ref)) out.add(option);
  }

  for (final token in recent) {
    add(SquareComposerTokenOption(ref: token, name: token.symbol));
  }
  for (final position in positions) {
    if (!_squareComposerHeld(position)) continue;
    add(
      SquareComposerTokenOption(
        ref: SquareFeedTokenRef(
          kind: SquareFeedTokenKind.launch2,
          id: position.instanceId,
          symbol: position.ticker,
          logoUrl: position.logoUrl,
        ),
        name: position.name,
      ),
    );
  }
  for (final row in rows) {
    if (row.stage == Launch2Stage.closedNoHolders) continue;
    add(
      SquareComposerTokenOption(
        ref: SquareFeedTokenRef(
          kind: SquareFeedTokenKind.launch2,
          id: row.instanceId,
          symbol: row.ticker,
          logoUrl: row.logoUrl,
        ),
        name: row.name,
      ),
    );
  }
  return List<SquareComposerTokenOption>.unmodifiable(out);
}

/// The wallet's own rule for a held MEME v2 position (decision 0217): a
/// token balance, the curve's net, or a project NFT.
bool _squareComposerHeld(Launch2Position position) {
  final balance = position.holding?.memeBalance;
  if (balance != null) {
    if (balance > Decimal.zero) return true;
  } else if (position.curve.net > Decimal.zero) {
    return true;
  }
  return position.nftHeld > 0;
}

/// A fresh `Idempotency-Key` for one composed post. The composer keeps it
/// across retries of the same text and draws a new one when the text changes.
String squareFeedIdempotencyKey() => const Uuid().v4();

/// What a refused post says, by the server's rule.
String squareFeedPostFailureText(LoopChainException failure) =>
    switch (failure.reasonCode) {
      'SQUARE_POST_RATE_LIMITED' => '发得太快了，稍等一分钟再发',
      'SQUARE_POST_TEXT_EMPTY' => '写点内容再发布',
      'SQUARE_POST_TEXT_TOO_LONG' => '最多 500 字，删减一些再发布',
      'SQUARE_POST_TEXT_INVALID' => '内容里有不支持的字符，删掉后再发布',
      'SQUARE_TOKEN_REF_INVALID' => '引用的代币读不到了，换一个或不带代币',
      'PROFILE_ACTIVATION_REQUIRED' => '先完成开户设置再发帖',
      _ => switch (failure.kind) {
        LoopChainFailureKind.rateLimited => '发得太快了，稍等一分钟再发',
        LoopChainFailureKind.offline ||
        LoopChainFailureKind.timedOut => '网络不通，没有发出去',
        LoopChainFailureKind.outcomeUnknown ||
        LoopChainFailureKind.cancelled => '结果未确认，下拉刷新看看是否已发出',
        LoopChainFailureKind.idempotencyConflict => '这条已经提交过，下拉刷新看看',
        LoopChainFailureKind.unavailable => '动态暂时不可用，稍后再试',
        _ => '没有发出去，稍后再试',
      },
    };
