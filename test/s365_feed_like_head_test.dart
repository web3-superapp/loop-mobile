// S365 · decision 0289: 广场 · 动态 — ♡ and its count stand at the head's
// right end on the name line; no foot line under the post.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';

import 'support/loop_shots.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final DateTime _now = DateTime.utc(2026, 11, 5, 12);

SquareFeedPost _post({
  String alias = 'pollak',
  int likes = 3,
  bool liked = false,
  bool pinned = false,
  bool system = false,
  SquareFeedToken? token,
}) => SquareFeedPost(
  postId: '00000000-0000-4000-8000-000000000001',
  kind: system ? SquareFeedPostKind.system : SquareFeedPostKind.opinion,
  author: system
      ? null
      : SquareFeedAuthor(
          publicProfileId: 'pp_author01',
          loopId: 'LOOP-AUTHOR01',
          alias: alias,
        ),
  text: 'Bottom in',
  token: token,
  likeCount: likes,
  likedByViewer: liked,
  pinned: pinned,
  createdAt: _now.subtract(const Duration(minutes: 3)),
);

final SquareFeedToken _token = SquareFeedToken(
  kind: SquareFeedTokenKind.meme,
  memeTokenId: '00000000-0000-4000-8000-000000000077',
  symbol: 'FROG',
  priceUsd1: Decimal.parse('0.00004173'),
  change1hPct: Decimal.parse('14.4'),
  marketCapUsd1: Decimal.parse('666700'),
);

Future<void> _host(
  WidgetTester tester,
  SquareFeedPost post, {
  double width = 390,
  VoidCallback? onLike,
}) async {
  await tester.runAsync(loopLoadShotFonts);
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          // The feed is a scroll view: posts take their own height.
          body: ListView(
            children: <Widget>[
              SquareFeedPostRow(
                post: post,
                now: _now,
                onLike: onLike ?? () {},
                onOpen: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('♡ sits on the name line at the right end, 44 × 44', (
    tester,
  ) async {
    var taps = 0;
    await _host(tester, _post(liked: true), onLike: () => taps++);
    final name = tester.getRect(_key('square-post-name'));
    final age = tester.getRect(_key('square-post-age'));
    final like = tester.getRect(_key('square-post-like'));
    final count = tester.getRect(_key('square-post-like-count'));
    expect((like.center.dy - name.center.dy).abs(), lessThan(1.5));
    expect(like.top, lessThan(age.top));
    expect(like.width, greaterThanOrEqualTo(LoopTouch.minimum));
    expect(like.height, greaterThanOrEqualTo(LoopTouch.minimum));
    // The count ends flush with the post's right edge (the page gutter).
    expect(count.right, closeTo(390 - LoopSpacing.page, 0.5));
    expect(like.right, closeTo(390 - LoopSpacing.page, 0.5));
    // The target lies wholly inside the card, so all of it takes the tap.
    final card = tester.getRect(_key('square-post-card'));
    expect(like.top, greaterThanOrEqualTo(card.top));
    await tester.tapAt(like.topLeft + const Offset(1, 1));
    await tester.tapAt(like.bottomRight - const Offset(1, 1));
    expect(taps, 2);
    final text = tester.widget<Text>(_key('square-post-like-count'));
    expect(text.style?.color, LoopColors.yellow);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no foot line: the post closes 12 under the quote card', (
    tester,
  ) async {
    await _host(tester, _post(token: _token));
    final card = tester.getRect(_key('square-post-card'));
    final quote = tester.getRect(_key('square-post-quote'));
    final like = tester.getRect(_key('square-post-like'));
    final text = tester.getRect(_key('square-post-text'));
    expect(like.bottom, lessThanOrEqualTo(text.top));
    expect(quote.top, greaterThan(text.bottom));
    // 12 of room above the 1 px hairline, nothing else under the quote.
    expect(card.bottom - 1 - quote.bottom, closeTo(squareFeedPostGap, 0.5));
    // The face starts 12 under the post's top, as before.
    final face = tester.getRect(_key('square-post-author'));
    expect(face.top - card.top, closeTo(squareFeedPostGap, 0.5));
    expect(_key('square-post-like'), findsOneWidget);
  });

  testWidgets('a long name ellipsizes first; ♡ and the tag stay', (
    tester,
  ) async {
    await _host(
      tester,
      _post(
        alias: 'averyveryverylongauthornamethatneverends' * 2,
        pinned: true,
        likes: 0,
      ),
      width: 320,
    );
    expect(tester.takeException(), isNull);
    final name = tester.getRect(_key('square-post-name'));
    final like = tester.getRect(_key('square-post-like'));
    expect(like.right, closeTo(320 - LoopSpacing.page, 0.5));
    expect(name.right, lessThan(like.left));
    final nameText = tester.widget<Text>(_key('square-post-name'));
    expect(nameText.overflow, TextOverflow.ellipsis);
    final tag = tester.getRect(_key('square-post-badge-opinion'));
    expect(tag.left, greaterThanOrEqualTo(name.right));
    expect(tag.right, lessThan(like.left));
    final count = tester.widget<Text>(_key('square-post-like-count'));
    expect(count.data, '0');
  });

  testWidgets('the official recap carries ♡ in its head too', (tester) async {
    await _host(tester, _post(system: true, likes: 12));
    final face = tester.getRect(_key('square-post-official-avatar'));
    final like = tester.getRect(_key('square-post-like'));
    expect(like.top, lessThan(face.bottom));
    expect(tester.widget<Text>(_key('square-post-like-count')).data, '12');
    expect(tester.takeException(), isNull);
  });
}
