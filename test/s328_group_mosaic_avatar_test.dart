import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/features/chat/widgets/group_mosaic_avatar.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const _communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _communityCid =
    'messaging:loop_community_3fa85f6457174562b3fc2c963f66afa6';
const _groupCid = 'messaging:loop_group_0123456789abcdef0123456789abcdef';
const _directCid = 'messaging:loop_direct_fedcba9876543210fedcba9876543210';

List<GroupMosaicMember> _members(int count, {bool images = false}) =>
    <GroupMosaicMember>[
      for (var index = 0; index < count; index++)
        (
          id: 'user-$index',
          name: 'Member $index',
          imageUrl: images ? 'https://media.example/u$index.png' : null,
        ),
    ];

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

/// Cell top-left offsets, relative to the tile, grouped into rows.
List<List<Rect>> _rowsOf(WidgetTester tester, int count) {
  final origin = tester.getTopLeft(
    find.byKey(const ValueKey<String>('group-mosaic-avatar')),
  );
  final rects = <Rect>[
    for (var index = 0; index < count; index++)
      tester
          .getRect(find.byKey(ValueKey<String>('group-mosaic-cell-$index')))
          .shift(-origin),
  ];
  final rows = <List<Rect>>[];
  for (final rect in rects) {
    if (rows.isEmpty || (rows.last.first.top - rect.top).abs() > 0.01) {
      rows.add(<Rect>[rect]);
    } else {
      rows.last.add(rect);
    }
  }
  return rows;
}

void main() {
  setUp(debugResetGroupMosaicCache);

  test('row counts follow the WeChat layout for one to nine members', () {
    expect(groupMosaicRowCounts(0), isEmpty);
    expect(groupMosaicRowCounts(1), <int>[1]);
    expect(groupMosaicRowCounts(2), <int>[2]);
    expect(groupMosaicRowCounts(3), <int>[1, 2]);
    expect(groupMosaicRowCounts(4), <int>[2, 2]);
    expect(groupMosaicRowCounts(5), <int>[2, 3]);
    expect(groupMosaicRowCounts(6), <int>[3, 3]);
    expect(groupMosaicRowCounts(7), <int>[1, 3, 3]);
    expect(groupMosaicRowCounts(8), <int>[2, 3, 3]);
    expect(groupMosaicRowCounts(9), <int>[3, 3, 3]);
    expect(groupMosaicRowCounts(30), <int>[3, 3, 3]);
  });

  const expected = <int, List<int>>{
    1: <int>[1],
    2: <int>[2],
    3: <int>[1, 2],
    4: <int>[2, 2],
    5: <int>[2, 3],
    6: <int>[3, 3],
    7: <int>[1, 3, 3],
    8: <int>[2, 3, 3],
    9: <int>[3, 3, 3],
  };
  for (final entry in expected.entries) {
    testWidgets(
      '${entry.key} members: rows ${entry.value}, centred, 2 px gaps',
      (tester) async {
        const size = 92.0;
        await _pump(
          tester,
          GroupMosaicAvatar(members: _members(entry.key), size: size),
        );
        expect(
          find.byKey(ValueKey<String>('group-mosaic-cell-${entry.key - 1}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('group-mosaic-cell-${entry.key}')),
          findsNothing,
        );
        final rows = _rowsOf(tester, entry.key);
        expect(rows.map((row) => row.length).toList(), entry.value);
        final side = rows.first.first.width;
        if (entry.key == 1) {
          // One member fills the tile inside its 2 px margin.
          expect(side, closeTo(size - 2 * groupMosaicGap, 0.01));
        }
        for (final row in rows) {
          // Every row is centred across the tile.
          final left = row.first.left;
          final right = size - row.last.right;
          expect(left, closeTo(right, 0.01));
          for (var index = 1; index < row.length; index++) {
            expect(
              row[index].left - row[index - 1].right,
              closeTo(groupMosaicGap, 0.01),
            );
          }
        }
        // The block of rows is centred down.
        final top = rows.first.first.top;
        final bottom = size - rows.last.first.bottom;
        expect(top, closeTo(bottom, 0.01));
        for (var index = 1; index < rows.length; index++) {
          expect(
            rows[index].first.top - rows[index - 1].first.bottom,
            closeTo(groupMosaicGap, 0.01),
          );
        }
      },
    );
  }

  testWidgets('more than nine members draws only the first nine', (
    tester,
  ) async {
    await _pump(tester, GroupMosaicAvatar(members: _members(14), size: 60));
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-cell-8')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-cell-9')),
      findsNothing,
    );
    expect(_rowsOf(tester, 9).map((row) => row.length).toList(), <int>[
      3,
      3,
      3,
    ]);
  });

  testWidgets('a member with no picture is an initial cell', (tester) async {
    final members = <GroupMosaicMember>[
      (id: 'a', name: 'Alice', imageUrl: 'https://media.example/a.png'),
      (id: 'b', name: 'Bob', imageUrl: null),
    ];
    await _pump(tester, GroupMosaicAvatar(members: members, size: 60));
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-image-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-image-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-initials-1')),
      findsOneWidget,
    );
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('a group with no member known draws its own initial', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupMosaicAvatar(members: <GroupMosaicMember>[], label: 'Night'),
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-initials-0')),
      findsOneWidget,
    );
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('the tile is a rounded square', (tester) async {
    await _pump(tester, GroupMosaicAvatar(members: _members(4), size: 40));
    final tile = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey<String>('group-mosaic-avatar')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, isNotNull);
  });

  testWidgets('the same member set is laid out once; a change re-lays it', (
    tester,
  ) async {
    await _pump(tester, GroupMosaicAvatar(members: _members(5), size: 40));
    await _pump(tester, GroupMosaicAvatar(members: _members(5), size: 40));
    expect(debugGroupMosaicBuilds, 1);
    await _pump(tester, GroupMosaicAvatar(members: _members(6), size: 40));
    expect(debugGroupMosaicBuilds, 2);
    expect(
      groupMosaicCacheKey(_members(5), 40, 10),
      isNot(groupMosaicCacheKey(_members(6), 40, 10)),
    );
  });

  testWidgets('a community with a logo wears the logo, not the mosaic', (
    tester,
  ) async {
    await _pump(
      tester,
      loopGroupChannelFace(
        communityId: _communityId,
        logoRef: 'avatar:preset/community-03',
        label: 'DeFi',
        members: _members(4),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('loop-community-channel-logo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-logo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-avatar')),
      findsNothing,
    );
  });

  testWidgets('a community without a logo wears the mosaic', (tester) async {
    await _pump(
      tester,
      loopGroupChannelFace(
        communityId: _communityId,
        logoRef: null,
        label: 'DeFi',
        members: _members(4),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('loop-group-channel-mosaic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-avatar')),
      findsOneWidget,
    );
  });

  testWidgets('a direct row stays a circle, a group row is a square', (
    tester,
  ) async {
    const direct = ConversationSummary(
      id: 'd',
      title: 'Night Owl',
      preview: 'hi',
      timeLabel: '10:00',
      kind: ConversationKind.direct,
    );
    const group = ConversationSummary(
      id: 'g',
      title: 'Glyph Hunters',
      preview: 'gm',
      timeLabel: '10:00',
      kind: ConversationKind.group,
    );
    await _pump(
      tester,
      Column(
        children: <Widget>[
          ConversationRow(conversation: direct, onTap: () {}),
          ConversationRow(conversation: group, onTap: () {}),
        ],
      ),
    );
    expect(find.byType(ChatAvatar), findsOneWidget);
    final disc = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ChatAvatar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((disc.decoration as BoxDecoration).shape, BoxShape.circle);
    expect(find.byType(GroupMosaicAvatar), findsOneWidget);
  });

  testWidgets('forward targets: direct is a circle, group the mosaic', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Column(
          children: <Widget>[
            SizedBox(
              child: chatForwardTargetFace(
                context,
                const ChatForwardTarget(
                  cid: _directCid,
                  label: 'Night Owl',
                  detail: '私聊',
                ),
                faces: const {},
                size: 44,
                radius: 15,
              ),
            ),
            SizedBox(
              child: chatForwardTargetFace(
                context,
                ChatForwardTarget(
                  cid: _groupCid,
                  label: '周末爬山群',
                  detail: '群聊',
                  members: _members(3),
                ),
                faces: const {},
                size: 44,
                radius: 15,
              ),
            ),
            SizedBox(
              child: chatForwardTargetFace(
                context,
                const ChatForwardTarget(
                  cid: _communityCid,
                  label: 'DeFi',
                  detail: '社区官方群',
                ),
                faces: const {},
                size: 44,
                radius: 15,
              ),
            ),
          ],
        ),
      ),
    );
    final direct = tester.widget<LoopInitialsAvatar>(
      find.byKey(ValueKey<String>('chat-forward-direct-face-$_directCid')),
    );
    expect(direct.shape, BoxShape.circle);
    expect(find.byType(GroupMosaicAvatar), findsNWidgets(2));
    expect(find.byType(LoopRemoteAvatar), findsNothing);
  });

  group('loopGroupMosaicMembers', () {
    Member member(
      String id, {
      required DateTime joined,
      String? name,
      String? image,
      Map<String, Object?> extra = const <String, Object?>{},
      Map<String, Object?> memberExtra = const <String, Object?>{},
    }) => Member(
      userId: id,
      createdAt: joined,
      extraData: memberExtra,
      user: User(
        id: id,
        extraData: <String, Object?>{'name': ?name, 'image': ?image, ...extra},
      ),
    );

    test('earliest joined first, feed bot out, nine at most', () {
      final base = DateTime.utc(2026, 10, 1);
      final rows = <Member>[
        for (var index = 11; index >= 0; index--)
          member(
            'u$index',
            joined: base.add(Duration(minutes: index)),
            name: 'Name $index',
          ),
        member(
          loopFeedBotUserId,
          joined: base.subtract(const Duration(days: 1)),
          name: 'Bot',
          extra: <String, Object?>{loopFeedBotFlagField: true},
        ),
      ];
      final picked = loopGroupMosaicMembers(rows, realIdentity: true);
      expect(picked.map((m) => m.id).toList(), <String>[
        for (var index = 0; index < 9; index++) 'u$index',
      ]);
    });

    test('real identity draws the account face; alias mode draws none', () {
      final rows = <Member>[
        member(
          'u1',
          joined: DateTime.utc(2026),
          name: 'Alice',
          image: 'https://media.example/alice.png',
        ),
      ];
      final real = loopGroupMosaicMembers(rows, realIdentity: true).single;
      expect(real.name, 'Alice');
      expect(real.imageUrl, 'https://media.example/alice.png');
      final alias = loopGroupMosaicMembers(rows, realIdentity: false).single;
      expect(alias.name, loopGroupMemberNeutralLabel);
      expect(alias.imageUrl, isNull);
    });
  });
}
