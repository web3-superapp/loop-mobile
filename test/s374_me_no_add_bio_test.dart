// S374 · decision 0298: the 我的 identity card draws no 「+ Add a bio」 link.
// An empty bio leaves nothing under the LOOP ID — the card closes on the
// LOOP ID row and the counts line follows it; a written bio shows as before.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/social_models.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';

ProfileResource _resource({String? bio}) => ProfileResource(
  version: 1,
  values: ProfileValues(alias: 'Boo123133', avatarRef: null, bio: bio),
  updatedAt: DateTime.utc(2026, 10, 9),
  loopId: 'LOOP-GBZM3XAT',
  profileStatus: ProfileStatus.active,
  activatedAt: DateTime.utc(2026, 10, 9, 12),
);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Future<int> _pump(WidgetTester tester, {String? bio}) async {
  var edits = 0;
  await pumpS5Page(
    tester,
    SingleChildScrollView(
      child: ProfileIdentityCard(
        resource: _resource(bio: bio),
        counts: const ConnectionCounts(following: 3, followers: 12),
        onEdit: () => edits++,
        onOpenConnections: () {},
      ),
    ),
  );
  await tester.tap(_key('profile-open-edit'));
  return edits;
}

void main() {
  loopWatchGround();

  testWidgets('an empty bio draws no add-bio link and no gap', (tester) async {
    final edits = await _pump(tester);

    expect(_key('profile-add-bio'), findsNothing);
    expect(find.text('+ Add a bio'), findsNothing);
    expect(find.text('＋ 添加个人简介'), findsNothing);
    expect(_key('profile-bio'), findsNothing);
    expect(find.bySemanticsLabel('Add a bio'), findsNothing);

    // The row ends at the taller of the avatar and the LOOP ID line (its
    // 44 copy target); the counts line starts right there — no empty row.
    final avatar = tester.getRect(_key('profile-open-edit'));
    final loopIdLine = tester.getRect(_key('profile-copy-loop-id'));
    final meta = tester.getRect(_key('profile-meta'));
    final rowBottom = avatar.bottom > loopIdLine.bottom
        ? avatar.bottom
        : loopIdLine.bottom;
    expect(meta.top, moreOrLessEquals(rowBottom, epsilon: 0.5));

    // The bio is still edited from profile-edit, through the avatar.
    expect(edits, 1);
  });

  testWidgets('a written bio still shows under the LOOP ID', (tester) async {
    await _pump(tester, bio: '只买 meme');

    expect(tester.widget<Text>(_key('profile-bio')).data, '只买 meme');
    expect(_key('profile-add-bio'), findsNothing);
    final loopIdLine = tester.getRect(_key('profile-copy-loop-id'));
    final bio = tester.getRect(_key('profile-bio'));
    expect(bio.top, moreOrLessEquals(loopIdLine.bottom + 6, epsilon: 0.5));
  });
}
