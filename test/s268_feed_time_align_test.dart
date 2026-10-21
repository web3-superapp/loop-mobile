import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';

// ---------------------------------------------------------------------------
// S268 · 广场「动态」: the age sits on the row's trailing edge (decision 0228)
// ---------------------------------------------------------------------------

final DateTime _now = DateTime.utc(2026, 10, 21, 12);

const double _rowWidth = 390;
const double _page = 16;

SquareFeedPost _post(
  int n, {
  required String alias,
  required SquareFeedPostKind kind,
}) => SquareFeedPost(
  postId: '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}',
  kind: kind,
  author: SquareFeedAuthor(
    publicProfileId: 'pp_author0$n',
    loopId: 'LOOP-AUTHOR0$n',
    alias: alias,
  ),
  text: 'Bottom in',
  likeCount: 0,
  likedByViewer: false,
  pinned: false,
  createdAt: _now.subtract(const Duration(days: 3)),
);

Future<void> _pumpRows(WidgetTester tester, List<SquareFeedPost> posts) async {
  tester.view.physicalSize = const Size(_rowWidth, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final post in posts)
                SquareFeedPostRow(
                  key: ValueKey<String>('row-${post.postId}'),
                  post: post,
                  now: _now,
                  onLike: () {},
                  onOpen: (_) {},
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('every post puts its age on the same trailing edge', (
    tester,
  ) async {
    final posts = <SquareFeedPost>[
      _post(1, alias: 'al', kind: SquareFeedPostKind.opinion),
      _post(2, alias: 'pollak.base', kind: SquareFeedPostKind.buy),
      _post(3, alias: '一个中等长度的昵称', kind: SquareFeedPostKind.graduation),
    ];
    await _pumpRows(tester, posts);

    final ages = find.byKey(const ValueKey<String>('square-post-age'));
    expect(ages, findsNWidgets(3));
    final rights = <double>[
      for (var i = 0; i < 3; i += 1) tester.getRect(ages.at(i)).right,
    ];
    for (final right in rights) {
      expect(right, moreOrLessEquals(_rowWidth - _page));
    }
    for (var i = 0; i < 3; i += 1) {
      expect(find.text('3d').at(i), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a very long name ellipsizes; the badge and the age stay', (
    tester,
  ) async {
    final long = _post(
      4,
      alias: 'averyveryveryveryveryveryverylongnicknamethatneverends',
      kind: SquareFeedPostKind.buy,
    );
    await _pumpRows(tester, <SquareFeedPost>[long]);

    expect(tester.takeException(), isNull);
    final name = tester.widget<Text>(
      find.byKey(const ValueKey<String>('square-post-name')),
    );
    expect(name.overflow, TextOverflow.ellipsis);
    expect(name.maxLines, 1);

    final badge = find.byKey(const ValueKey<String>('square-post-badge-buy'));
    expect(badge, findsOneWidget);
    final age = find.byKey(const ValueKey<String>('square-post-age'));
    final ageRect = tester.getRect(age);
    expect(ageRect.right, moreOrLessEquals(_rowWidth - _page));

    final badgeRect = tester.getRect(badge);
    final nameRect = tester.getRect(
      find.byKey(const ValueKey<String>('square-post-name')),
    );
    expect(badgeRect.width, greaterThan(0));
    expect(nameRect.right, lessThanOrEqualTo(badgeRect.left));
    expect(badgeRect.right, lessThanOrEqualTo(ageRect.left));
  });
}
