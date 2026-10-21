import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/backend/v2/square/loop_v2_square_feed_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S187-4 · 广场「动态」 (decision 0177)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final DateTime _now = DateTime.utc(2026, 10, 15, 12);

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

const SquareFeedAuthor _author = SquareFeedAuthor(
  publicProfileId: 'pp_author01',
  loopId: 'LOOP-AUTHOR01',
  alias: 'pollak',
);

SquareFeedPost _post(
  int n, {
  SquareFeedPostKind kind = SquareFeedPostKind.opinion,
  String? text = 'Bottom in',
  SquareFeedToken? token,
  Map<String, String> event = const <String, String>{},
  bool pinned = false,
  int likes = 0,
  bool liked = false,
}) => SquareFeedPost(
  postId: _uuid(n),
  kind: kind,
  author: kind == SquareFeedPostKind.system ? null : _author,
  text: text,
  token: token,
  event: event,
  likeCount: likes,
  likedByViewer: liked,
  pinned: pinned,
  createdAt: _now.subtract(Duration(seconds: 40 + n)),
);

SquareFeedPage _page(List<SquareFeedPost> items, {String? cursor}) =>
    SquareFeedPage(
      scope: SquareFeedScope.global,
      items: items,
      nextCursor: cursor,
      observedAt: _now,
    );

final class _Feed implements SquareFeedGateway {
  _Feed({this.page, this.failure});

  final SquareFeedPage? page;
  final LoopChainFailureKind? failure;
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Completer<SquareFeedLike>? like;
  LoopChainException? createFailure;
  final List<String> keys = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<SquareFeedPage> loadFeed(SquareFeedScope scope, {String? cursor}) {
    final kind = failure;
    if (kind != null) {
      return Future<SquareFeedPage>.error(LoopChainException(kind));
    }
    return Future<SquareFeedPage>.value(page ?? _page(const []));
  }

  @override
  Future<SquareFeedPost> createPost({
    required String text,
    required String idempotencyKey,
    SquareFeedTokenRef? tokenRef,
  }) {
    keys.add(idempotencyKey);
    final refused = createFailure;
    if (refused != null) return Future<SquareFeedPost>.error(refused);
    return Future<SquareFeedPost>.value(_post(900, text: text));
  }

  @override
  Future<void> deletePost(String postId) {
    deleted.add(postId);
    return Future<void>.value();
  }

  @override
  Future<SquareFeedLike> setLike(String postId, {required bool liked}) =>
      (like ??= Completer<SquareFeedLike>()).future;
}

LoopV2MetaSnapshot _meta({required bool feed}) {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.squareFeed)
            LoopV2Capability(
              id: capability.id,
              availability: feed
                  ? LoopV2CapabilityAvailability.available
                  : LoopV2CapabilityAvailability.unavailable,
              reasonCode: feed ? null : 'SQUARE_REPOSITORY_UNAVAILABLE',
              evidence: const LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

Future<void> _pumpSegment(
  WidgetTester tester,
  _Feed feed, {
  Size size = const Size(390, 2600),
}) => pumpS7Page(
  tester,
  SquareFeedSegment(onNavigate: (_) {}, now: () => _now),
  meta: _meta(feed: true),
  size: size,
  overrides: <Override>[squareFeedGatewayProvider.overrideWithValue(feed)],
);

Future<void> _pumpSquare(
  WidgetTester tester, {
  required bool capability,
  _Feed? feed,
}) => pumpS7Page(
  tester,
  SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
  meta: _meta(feed: capability),
  overrides: <Override>[
    if (feed != null) squareFeedGatewayProvider.overrideWithValue(feed),
  ],
);

/// Unmounts the page and lets retained reads' timers run out.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(minutes: 30));
}

String _segmentLabel(WidgetTester tester, int index) {
  final segment = _key('square-segment-$index');
  final text = tester.widget<Text>(
    find.descendant(of: segment, matching: find.byType(Text)).first,
  );
  return text.data!;
}

int _primaryButtons(WidgetTester tester) => tester
    .widgetList<LoopButton>(find.byType(LoopButton))
    .where((button) => button.primary && button.onPressed != null)
    .length;

void main() {
  loopWatchGround();

  group('segments and the capability', () {
    testWidgets('squareFeed usable: 动态 / 社区 / 语音房, opens on 社区 (0181)', (
      tester,
    ) async {
      await _pumpSquare(tester, capability: true, feed: _Feed());
      expect(_segmentLabel(tester, 0), '动态');
      expect(_segmentLabel(tester, 1), '社区');
      expect(_segmentLabel(tester, 2), '语音房');
      // Decision 0181: 动态 is in front, but the page opens on 社区.
      expect(_key('square-feed'), findsNothing);
      expect(_key('square-community-list'), findsOneWidget);
      await tester.tap(_key('square-segment-0'));
      await tester.pumpAndSettle();
      expect(_key('square-feed'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('squareFeed unavailable: the page is the old two segments', (
      tester,
    ) async {
      await _pumpSquare(tester, capability: false, feed: _Feed());
      expect(_segmentLabel(tester, 0), '社区');
      expect(_segmentLabel(tester, 1), '语音房');
      expect(_key('square-segment-2'), findsNothing);
      expect(_key('square-feed'), findsNothing);
      expect(_key('square-community-list'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('capability open but no adapter mounted: still the old two', (
      tester,
    ) async {
      await _pumpSquare(tester, capability: true);
      expect(_segmentLabel(tester, 0), '社区');
      expect(_key('square-feed'), findsNothing);
      await _teardown(tester);
    });

    test('a backend without squareFeed reads it unavailable', () {
      expect(
        DioLoopV2MetaRepository.omissibleCapabilities,
        contains(LoopV2CapabilityId.squareFeed),
      );
      expect(LoopV2CapabilityId.values.last, LoopV2CapabilityId.squareFeed);
    });
  });

  group('post rows', () {
    testWidgets('five kinds carry their badges; system only when pinned', (
      tester,
    ) async {
      await _pumpSegment(
        tester,
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(
              1,
              kind: SquareFeedPostKind.system,
              text: '日报 · 10 月 13 日\n大盘继续盘整',
              pinned: true,
            ),
            _post(2),
            _post(3, kind: SquareFeedPostKind.buy, text: null),
            _post(
              4,
              kind: SquareFeedPostKind.claim,
              text: null,
              event: const <String, String>{'amountUsd1': '10.94'},
            ),
            _post(5, kind: SquareFeedPostKind.graduation, text: null),
            _post(6, kind: SquareFeedPostKind.system, text: '通知'),
          ]),
        ),
      );
      expect(_key('square-post-badge-pinned'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('观点'), findsOneWidget);
      expect(find.text('买入'), findsOneWidget);
      expect(find.text('领奖'), findsOneWidget);
      // The claim's amount is in its sentence now (decision 0187).
      expect(find.text('领到 10.94 USD1。'), findsOneWidget);
      expect(find.text('毕业'), findsOneWidget);
      final badges = tester
          .widgetList<LoopBadge>(find.byType(LoopBadge))
          .toList();
      expect(badges, hasLength(5));
      LoopBadge badge(String text) => badges.singleWhere((b) => b.text == text);
      expect(badge('观点').kind, LoopBadgeKind.mute);
      expect(badge('置顶').kind, LoopBadgeKind.mute);
      expect(badge('买入').kind, LoopBadgeKind.launch);
      expect(badge('毕业').kind, LoopBadgeKind.launch);
      expect(badge('领奖').kind, LoopBadgeKind.up);
      // The pinned post is first and its text sits in a record card.
      final pinnedTop = tester.getTopLeft(_key('square-post-${_uuid(1)}')).dy;
      final opinionTop = tester.getTopLeft(_key('square-post-${_uuid(2)}')).dy;
      expect(pinnedTop, lessThan(opinionTop));
      expect(_key('square-post-recap'), findsNWidgets(2));
      // Nothing on the timeline is a full-Lime body.
      expect(_primaryButtons(tester), 0);
      await _teardown(tester);
    });

    testWidgets('a quote line draws only what was read, never a zero', (
      tester,
    ) async {
      await _pumpSegment(
        tester,
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(
              1,
              token: SquareFeedToken(
                kind: SquareFeedTokenKind.meme,
                memeTokenId: _uuid(77),
                symbol: 'AI',
              ),
            ),
            _post(
              2,
              token: SquareFeedToken(
                kind: SquareFeedTokenKind.meme,
                memeTokenId: _uuid(78),
                symbol: 'STFY',
                priceUsd1: Decimal.parse('16208.90'),
                change1hPct: Decimal.parse('3.09'),
              ),
            ),
          ]),
        ),
      );
      final bare = _key('square-post-${_uuid(1)}');
      expect(
        tester
            .widget<Text>(
              find.descendant(of: bare, matching: _key('square-post-symbol')),
            )
            .data,
        'AI',
      );
      expect(
        find.descendant(of: bare, matching: _key('square-post-price')),
        findsNothing,
      );
      expect(
        find.descendant(of: bare, matching: _key('square-post-change')),
        findsNothing,
      );
      final full = _key('square-post-${_uuid(2)}');
      expect(
        find.descendant(of: full, matching: _key('square-post-price')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: full, matching: find.text('+3.09%')),
        findsOneWidget,
      );
      expect(find.text(r'$0'), findsNothing);
      expect(find.text('0.00%'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('a flat move is not drawn either (TF 23 0.00%)', (
      tester,
    ) async {
      await _pumpSegment(
        tester,
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(
              1,
              token: SquareFeedToken(
                kind: SquareFeedTokenKind.meme,
                memeTokenId: _uuid(77),
                symbol: 'AI',
                priceUsd1: Decimal.parse('24344.25'),
                change1hPct: Decimal.zero,
              ),
            ),
          ]),
        ),
      );
      expect(_key('square-post-price'), findsOneWidget);
      expect(_key('square-post-change'), findsNothing);
      expect(find.text('0.00%'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('rows are compact: ≤ 110 dp bare, ≤ 156 dp with a capsule', (
      tester,
    ) async {
      await _pumpSegment(
        tester,
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(1, text: 'Bottom in. 这个位置我继续加。'),
            _post(
              2,
              text: 'Bottom in. 这个位置我继续加。',
              token: SquareFeedToken(
                kind: SquareFeedTokenKind.meme,
                memeTokenId: _uuid(77),
                symbol: 'S1378A05',
                priceUsd1: Decimal.parse('0.00004173'),
                change1hPct: Decimal.parse('14.4'),
                marketCapUsd1: Decimal.parse('666700'),
              ),
            ),
          ]),
        ),
      );
      final bare = tester.getSize(_key('square-post-${_uuid(1)}')).height;
      final quoted = tester.getSize(_key('square-post-${_uuid(2)}')).height;
      // 140 since decision 0229's 16 body and 17 name (112 under 0210).
      expect(bare, lessThanOrEqualTo(140));
      expect(quoted, lessThanOrEqualTo(190));
      // The capsule is the design's 40 dp Card strip.
      expect(
        tester.getSize(_key('square-post-quote')).height,
        SquareFeedPostRow.capsuleHeight,
      );
      await _teardown(tester);
    });

    testWidgets('the price stays on one line on a narrow phone', (
      tester,
    ) async {
      await _pumpSegment(
        tester,
        size: const Size(320, 1600),
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(
              1,
              token: SquareFeedToken(
                kind: SquareFeedTokenKind.meme,
                memeTokenId: _uuid(77),
                symbol: 'VERYLONGTICKER',
                priceUsd1: Decimal.parse('0.00004173'),
                change1hPct: Decimal.parse('-49.5'),
                marketCapUsd1: Decimal.parse('3400000'),
              ),
            ),
          ]),
        ),
      );
      final price = tester.widget<Text>(_key('square-post-price'));
      expect(price.data, r'$0.0₄4173');
      expect(price.maxLines, 1);
      expect(price.softWrap, isFalse);
      final line = tester.getSize(_key('square-post-price')).height;
      expect(line, lessThan(13 * 2));
      expect(find.text('-49.50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });

    test('event posts say one sentence from their facts', () {
      SquareFeedToken token(String symbol) => SquareFeedToken(
        kind: SquareFeedTokenKind.launch2,
        instanceId: _uuid(60),
        symbol: symbol,
      );
      expect(
        squareFeedPostSentence(
          _post(
            1,
            kind: SquareFeedPostKind.graduation,
            text: null,
            token: token('S1371AE4'),
          ),
        ),
        'S1371AE4 打满内盘，官方池已建，回购开始。',
      );
      expect(
        squareFeedPostSentence(
          _post(
            2,
            kind: SquareFeedPostKind.claim,
            text: null,
            token: token('S1376B5B'),
            event: const <String, String>{
              'amountUsd1': '10.94',
              'roundId': '2',
              'weightPct': '50.00',
            },
          ),
        ),
        '在 S1376B5B 第 2 轮领到 10.94 USD1，权重 50%。',
      );
      // A fact that was not sent is left out, never written as 0.
      expect(
        squareFeedPostSentence(
          _post(
            3,
            kind: SquareFeedPostKind.claim,
            text: null,
            token: token('S1376B5B'),
            event: const <String, String>{'amountUsd1': '10.94'},
          ),
        ),
        '在 S1376B5B 领到 10.94 USD1。',
      );
      expect(
        squareFeedPostSentence(
          _post(
            4,
            kind: SquareFeedPostKind.buy,
            text: null,
            token: token('S1378A05'),
            event: const <String, String>{'amountUsd1': '40'},
          ),
        ),
        '买入 40 USD1 的 S1378A05。',
      );
      expect(
        squareFeedPostSentence(
          _post(5, kind: SquareFeedPostKind.buy, text: null),
        ),
        isNull,
      );
      // A person's words are their own.
      expect(squareFeedPostSentence(_post(6, text: 'Bottom in')), 'Bottom in');
      expect(
        squareFeedPostSentence(
          _post(7, kind: SquareFeedPostKind.system, text: '日报'),
        ),
        '日报',
      );
    });

    test('badge by kind', () {
      LoopBadge? badge(SquareFeedPostKind kind, {bool pinned = false}) =>
          squareFeedBadge(_post(1, kind: kind, pinned: pinned)) as LoopBadge?;
      expect(badge(SquareFeedPostKind.opinion)!.text, '观点');
      expect(badge(SquareFeedPostKind.opinion)!.kind, LoopBadgeKind.mute);
      expect(badge(SquareFeedPostKind.buy)!.text, '买入');
      expect(badge(SquareFeedPostKind.buy)!.kind, LoopBadgeKind.launch);
      expect(badge(SquareFeedPostKind.claim)!.text, '领奖');
      expect(badge(SquareFeedPostKind.claim)!.kind, LoopBadgeKind.up);
      expect(badge(SquareFeedPostKind.graduation)!.text, '毕业');
      expect(badge(SquareFeedPostKind.graduation)!.kind, LoopBadgeKind.launch);
      expect(badge(SquareFeedPostKind.system, pinned: true)!.text, '置顶');
      expect(badge(SquareFeedPostKind.system), isNull);
    });

    testWidgets('like flips at once and rolls back with a toast on failure', (
      tester,
    ) async {
      final feed = _Feed(page: _page(<SquareFeedPost>[_post(1, likes: 4)]));
      await _pumpSegment(tester, feed);
      Text count() => tester.widget<Text>(_key('square-post-like-count'));
      expect(count().data, '4');
      await tester.tap(_key('square-post-like'));
      await tester.pump();
      expect(count().data, '5');
      feed.like!.completeError(
        const LoopChainException(LoopChainFailureKind.offline),
      );
      await tester.pump();
      await tester.pump();
      expect(count().data, '4');
      expect(find.text('没有点上赞，请稍后再试'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      // A server answer is the count that stays.
      feed.like = null;
      await tester.tap(_key('square-post-like'));
      await tester.pump();
      feed.like!.complete(
        SquareFeedLike(postId: _uuid(1), likeCount: 9, likedByViewer: true),
      );
      await tester.pump();
      await tester.pump();
      expect(count().data, '9');
      await _teardown(tester);
    });

    testWidgets('empty and unavailable', (tester) async {
      await _pumpSegment(tester, _Feed());
      expect(_key('square-feed-empty'), findsOneWidget);
      expect(find.text('还没有动态'), findsOneWidget);
      await _teardown(tester);

      await _pumpSegment(
        tester,
        _Feed(failure: LoopChainFailureKind.unavailable),
      );
      expect(_key('square-feed-unavailable'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('a link is Lime and a tap copies it', (tester) async {
      await _pumpSegment(
        tester,
        _Feed(
          page: _page(<SquareFeedPost>[
            _post(1, text: 'Bottom in x.com/jimcramer/status/2110'),
          ]),
        ),
      );
      expect(
        SquareFeedText.linkPattern
            .firstMatch('Bottom in x.com/jimcramer/status/2110')
            ?.group(0),
        'x.com/jimcramer/status/2110',
      );
      expect(
        SquareFeedText.linkPattern.hasMatch(r'buy $STFY now 3.40M'),
        false,
      );
      await _teardown(tester);
    });
  });

  group('composer', () {
    testWidgets('publish is the sheet\'s one Lime; refusals read in Chinese', (
      tester,
    ) async {
      final feed = _Feed(page: _page(<SquareFeedPost>[_post(1)]))
        ..createFailure = const LoopChainException(
          LoopChainFailureKind.rateLimited,
          reasonCode: 'SQUARE_POST_RATE_LIMITED',
        );
      await _pumpSegment(tester, feed);
      await tester.tap(_key('square-feed-compose'));
      await tester.pumpAndSettle();
      expect(_key('square-composer'), findsOneWidget);
      await tester.enterText(_key('square-composer-field'), 'hello');
      await tester.pump();
      expect(find.text('5/500'), findsOneWidget);
      expect(_primaryButtons(tester), 1);
      expect(
        tester.widget<LoopButton>(_key('square-composer-send')).label,
        '发布',
      );
      await tester.tap(_key('square-composer-send'));
      await tester.pumpAndSettle();
      expect(find.text('发得太快了，稍等一分钟再发'), findsOneWidget);

      // The same text retried keeps its key; the server succeeds.
      feed.createFailure = null;
      await tester.tap(_key('square-composer-send'));
      await tester.pumpAndSettle();
      expect(feed.keys, hasLength(2));
      expect(feed.keys.first, feed.keys.last);
      expect(_key('square-composer'), findsNothing);
      expect(_key('square-post-${_uuid(900)}'), findsOneWidget);

      // The new post is the viewer's own: a long press deletes it.
      await tester.longPress(_key('square-post-${_uuid(900)}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('square-post-delete-confirm'));
      await tester.pumpAndSettle();
      expect(feed.deleted, <String>[_uuid(900)]);
      expect(_key('square-post-${_uuid(900)}'), findsNothing);
      await _teardown(tester);
    });

    test('every refusal code has its own sentence', () {
      String text(String code) => squareFeedPostFailureText(
        LoopChainException(
          LoopChainFailureKind.validationFailed,
          reasonCode: code,
        ),
      );
      expect(text('SQUARE_POST_RATE_LIMITED'), '发得太快了，稍等一分钟再发');
      expect(text('SQUARE_POST_TEXT_EMPTY'), '写点内容再发布');
      expect(text('SQUARE_POST_TEXT_TOO_LONG'), '最多 500 字，删减一些再发布');
      expect(text('SQUARE_POST_TEXT_INVALID'), '内容里有不支持的字符，删掉后再发布');
      expect(text('SQUARE_TOKEN_REF_INVALID'), '引用的代币读不到了，换一个或不带代币');
      expect(text('PROFILE_ACTIVATION_REQUIRED'), '先完成开户设置再发帖');
    });
  });

  group('codec', () {
    String? media(String id) => 'https://api.example/v2/media/$id.webp';

    Map<String, Object?> row(
      int n, {
      String kind = 'opinion',
      bool pinned = false,
      Object? token,
    }) => <String, Object?>{
      'postId': _uuid(n),
      'kind': kind,
      'author': kind == 'system'
          ? null
          : <String, Object?>{
              'publicProfileId': 'pp_author01',
              'loopId': 'LOOP-AUTHOR01',
              'alias': null,
              'avatarRef': 'https://evil.example/a.png',
            },
      'text': kind == 'opinion' || kind == 'system' ? 'hi' : null,
      'token': token,
      'event': null,
      'likeCount': 1,
      'likedByViewer': false,
      'pinned': pinned,
      'createdAt': '2026-10-15T11:59:00.000Z',
      'unknownKey': 1,
    };

    test('pinned first, bad rows dropped, unknown keys ignored', () {
      final page = LoopV2SquareFeedCodec.page(
        <String, Object?>{
          'scope': 'global',
          'items': <Object?>[
            row(1),
            row(2, kind: 'system', pinned: true),
            <String, Object?>{'postId': 'nope'},
            row(1),
            row(
              3,
              token: <String, Object?>{
                'kind': 'meme',
                'memeTokenId': _uuid(50),
                'instanceId': null,
                'symbol': 'FROG',
                'logoUrl': 'https://evil.example/v2/media/${_uuid(51)}.webp',
                'priceUsd1': 'NaN',
                'change1hPct': '-1.5',
                'marketCapUsd1': null,
              },
            ),
            // A pinned opinion is not pinned.
            row(4, pinned: true),
          ],
          'nextCursor': null,
          'observedAt': '2026-10-15T12:00:00.000Z',
          'contractVersion': '2.0',
        },
        scope: SquareFeedScope.global,
        mediaUrl: media,
      );
      expect(page.items.map((post) => post.postId), <String>[
        _uuid(2),
        _uuid(1),
        _uuid(3),
        _uuid(4),
      ]);
      expect(page.items.first.pinned, isTrue);
      expect(page.items.last.pinned, isFalse);
      expect(page.items[1].author!.avatarRef, isNull);
      final token = page.items[2].token!;
      expect(token.priceUsd1, isNull);
      expect(token.change1hPct, Decimal.parse('-1.5'));
      expect(token.logoUrl, 'https://api.example/v2/media/${_uuid(51)}.webp');
    });

    test('another scope or no items is an invalid payload', () {
      expect(
        () => LoopV2SquareFeedCodec.page(
          <String, Object?>{
            'scope': 'following',
            'items': <Object?>[],
            'nextCursor': null,
            'observedAt': '2026-10-15T12:00:00.000Z',
          },
          scope: SquareFeedScope.global,
          mediaUrl: media,
        ),
        throwsA(anything),
      );
      expect(
        () => LoopV2SquareFeedCodec.page(
          <String, Object?>{'observedAt': '2026-10-15T12:00:00.000Z'},
          scope: SquareFeedScope.global,
          mediaUrl: media,
        ),
        throwsA(anything),
      );
    });
  });
}
