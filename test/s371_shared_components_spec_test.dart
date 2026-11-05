// S371 · decision 0297: the shared components the second-level sweeps
// (S370a / b / c, decisions 0293–0295) could not reach — the 20 page margin
// as every default, the Figma row heights on `LoopRecordRow`, ruled groups,
// ruled person rows and the 9-corner function glyph, the one search field,
// the 19 / 700 sheet title and the quiet empty-state step — each with a
// measurement and a check that an untouched caller keeps what it had.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_search_entry.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';

import 'support/loop_ground_probe.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _host(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  bool flat = false,
}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final body = SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[child],
    ),
  );
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: flat ? LoopFlat(child: body) : body),
    ),
  );
}

String _source(String path) => File(path).readAsStringSync();

void main() {
  loopWatchGround();

  group('1 · default margins are the 20 page margin', () {
    test('every shared default that stood at 16 is 20 now', () {
      const page = LoopSpacing.page;
      expect(const LoopNotice(body: 'b').margin.left, page);
      expect(const LoopNotice(body: 'b').margin.right, page);
      expect(
        LoopSegBar(
          labels: const <String>['a'],
          selectedIndex: 0,
          onSelected: (_) {},
        ).padding.left,
        page,
      );
      expect(const LoopErrorState(reason: 'r').margin.left, page);
      expect(const LoopOfflineState().margin.left, page);
      expect(
        const LoopPermissionState(title: 't', purpose: 'p').margin.left,
        page,
      );
      expect(
        LoopLoadMoreFooter(
          keyPrefix: 'k',
          cursor: null,
          canLoadMore: false,
          loading: false,
          onLoadMore: () async {},
        ).padding.left,
        page,
      );
    });

    testWidgets('a default notice starts on the page margin', (tester) async {
      await _host(
        tester,
        const LoopNotice(key: ValueKey<String>('n'), body: 'b'),
      );
      final rect = tester.getRect(_key('n'));
      final card = find.descendant(
        of: _key('n'),
        matching: find.byType(DecoratedBox),
      );
      expect(rect.left, 0);
      expect(tester.getTopLeft(card.first).dx, LoopSpacing.page);
    });

    test('a caller that passes its own margin keeps it', () {
      const own = EdgeInsets.fromLTRB(4, 0, 4, 0);
      expect(const LoopNotice(body: 'b', margin: own).margin, own);
    });

    test('no shared widget writes a 16 page edge any more', () {
      for (final path in <String>[
        'lib/widgets/loop_load_more.dart',
        'lib/widgets/loop_info_sheet.dart',
        'lib/widgets/loop_provenance_scope.dart',
        'lib/widgets/loop_sign_steps.dart',
      ]) {
        final text = _source(path);
        expect(text.contains('fromLTRB(16,'), isFalse, reason: path);
        expect(text.contains('horizontal: 16'), isFalse, reason: path);
      }
    });
  });

  group('2 · LoopRecordRow height and title step', () {
    testWidgets('a kind takes the Figma height, its divider inside it', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: const <Widget>[
            LoopRecordRow(
              key: ValueKey<String>('person'),
              title: 'Alias',
              subtitle: 'LOOP #1',
              kind: LoopRecordRowKind.person,
              divider: true,
            ),
            LoopRecordRow(
              key: ValueKey<String>('community'),
              title: 'Club',
              subtitle: '12 members',
              kind: LoopRecordRowKind.community,
            ),
            LoopRecordRow(
              key: ValueKey<String>('token'),
              title: 'Token',
              kind: LoopRecordRowKind.token,
            ),
          ],
        ),
      );
      expect(tester.getSize(_key('person')).height, LoopRowHeight.chat);
      expect(tester.getSize(_key('community')).height, LoopRowHeight.community);
      expect(tester.getSize(_key('token')).height, LoopRowHeight.token);
    });

    testWidgets('function / holdings kinds on a flat page: 56 / 51', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: const <Widget>[
            LoopRecordRow(
              key: ValueKey<String>('fn'),
              title: 'Settings',
              kind: LoopRecordRowKind.function,
              divider: true,
            ),
            LoopRecordRow(
              key: ValueKey<String>('hold'),
              title: 'USD1',
              kind: LoopRecordRowKind.holdings,
            ),
          ],
        ),
        flat: true,
      );
      expect(tester.getSize(_key('fn')).height, LoopRowHeight.management);
      expect(tester.getSize(_key('hold')).height, LoopRowHeight.holdings);
    });

    testWidgets('titleStyle sets the name step', (tester) async {
      await _host(
        tester,
        LoopRecordRow(
          title: 'Group chat',
          kind: LoopRecordRowKind.person,
          titleStyle: LoopType.rowTitleLg,
        ),
      );
      final text = tester.widget<Text>(find.text('Group chat'));
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w500);
    });

    testWidgets('regression: no kind keeps 72 / 80 and LoopType.title', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: const <Widget>[
            LoopRecordRow(key: ValueKey<String>('one'), title: 'One'),
            LoopRecordRow(
              key: ValueKey<String>('two'),
              title: 'Two',
              subtitle: 'line',
            ),
          ],
        ),
      );
      expect(tester.getSize(_key('one')).height, LoopSpacing.rowMin);
      expect(tester.getSize(_key('two')).height, LoopSpacing.rowMinWithSub);
      expect(
        tester.widget<Text>(find.text('One')).style!.fontSize,
        LoopType.title.fontSize,
      );
    });

    testWidgets('regression: a flat row without a kind stays 56', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordRow(key: ValueKey<String>('f'), title: 'Flat'),
        flat: true,
      );
      expect(tester.getSize(_key('f')).height, LoopFlat.rowHeight);
    });

    for (final width in <double>[360, 390]) {
      testWidgets('a long badge beside a 44 face shrinks at $width', (
        tester,
      ) async {
        await _host(
          tester,
          const LoopRecordRow(
            key: ValueKey<String>('badge-row'),
            title: 'A project with a long name',
            subtitle: 'Pending review · submitted',
            kind: LoopRecordRowKind.token,
            leading: SizedBox(width: 44, height: 44),
            trailingBadge: LoopBadge('Pending review by the operator team'),
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
        // Squeezed: the title keeps its reserve beside the 44 face.
        final title = tester.getSize(find.text('A project with a long name'));
        expect(
          title.width,
          greaterThanOrEqualTo(LoopRecordRow.badgeTitleReserve - 1),
        );
      });
    }

    testWidgets('regression: a short badge keeps its own width', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordRow(title: 'Row', trailingBadge: LoopBadge('On')),
      );
      final badge = tester.getSize(find.byType(LoopBadge)).width;
      expect(badge, lessThan(60));
    });
  });

  group('3 · LoopRecordGroup rules its function rows', () {
    List<LoopRecordRow> rows() => <LoopRecordRow>[
      for (var i = 0; i < 3; i++)
        LoopRecordRow(
          key: ValueKey<String>('g$i'),
          title: 'Row $i',
          onTap: () {},
        ),
    ];

    testWidgets('a group draws a line between rows, not under the last', (
      tester,
    ) async {
      await _host(tester, LoopRecordGroup(rows: rows()), flat: true);
      expect(find.byKey(LoopRecordRow.dividerKey), findsNWidgets(2));
      // The line is counted inside the row: a flat row stays 56.
      expect(tester.getSize(_key('g0')).height, LoopFlat.rowHeight);
      expect(tester.getSize(_key('g2')).height, LoopFlat.rowHeight);
      final line = tester.getRect(find.byKey(LoopRecordRow.dividerKey).first);
      expect(line.height, 1);
      // Across the block's content: page margin + the block's 16 inset.
      expect(line.left, LoopSpacing.page + LoopSpacing.card);
      expect(line.right, 390 - LoopSpacing.page - LoopSpacing.card);
    });

    testWidgets('a holdings group passes divided: false and draws none', (
      tester,
    ) async {
      await _host(
        tester,
        LoopRecordGroup(divided: false, rows: rows()),
        flat: true,
      );
      expect(find.byKey(LoopRecordRow.dividerKey), findsNothing);
    });

    testWidgets('the group copies kind and titleStyle onto its rows', (
      tester,
    ) async {
      await _host(
        tester,
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('k'),
              title: 'Kind',
              kind: LoopRecordRowKind.person,
              titleStyle: LoopType.rowTitleLg,
            ),
          ],
        ),
      );
      expect(tester.getSize(_key('k')).height, LoopRowHeight.chat);
      expect(tester.widget<Text>(find.text('Kind')).style!.fontSize, 16);
    });

    testWidgets('regression: LoopRecordGroup.children is drawn as given', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordGroup.children(
          children: <Widget>[
            LoopRecordRow(title: 'a'),
            LoopRecordRow(title: 'b'),
          ],
        ),
      );
      expect(find.byKey(LoopRecordRow.dividerKey), findsNothing);
    });
  });

  group('4 · LoopPersonRow divider / padding and LoopEntryIcon shape', () {
    testWidgets('a ruled person row is 67 with its line inside', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopPersonRow(
          key: ValueKey<String>('p'),
          leading: SizedBox(width: 48, height: 48),
          title: 'Member',
          subtitle: 'Owner',
          height: LoopRowHeight.chat,
          divider: true,
          padding: EdgeInsets.symmetric(
            horizontal: LoopSpacing.page,
            vertical: 6,
          ),
        ),
      );
      expect(tester.getSize(_key('p')).height, LoopRowHeight.chat);
      final line = tester.getRect(find.byKey(LoopPersonRow.dividerKey));
      expect(line.height, 1);
      expect(line.left, LoopSpacing.page);
      expect(line.right, 390 - LoopSpacing.page);
    });

    testWidgets('regression: the default person row is 64, unruled', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopPersonRow(
          key: ValueKey<String>('p'),
          leading: SizedBox(width: 40, height: 40),
          title: 'Member',
        ),
      );
      expect(tester.getSize(_key('p')).height, 64);
      expect(find.byKey(LoopPersonRow.dividerKey), findsNothing);
    });

    testWidgets('a function glyph is a 9-corner square; default stays round', (
      tester,
    ) async {
      await _host(
        tester,
        Row(
          children: const <Widget>[
            LoopEntryIcon(
              'id',
              key: ValueKey<String>('sq'),
              size: 34,
              shape: LoopEntryIconShape.square,
            ),
            LoopEntryIcon('id', key: ValueKey<String>('round')),
          ],
        ),
      );
      BoxDecoration deco(String key) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: _key(key),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco('sq').borderRadius, LoopRadius.glyphGround);
      expect(LoopRadius.glyphGroundValue, 9);
      expect(deco('sq').shape, BoxShape.rectangle);
      expect(deco('round').shape, BoxShape.circle);
      expect(tester.getSize(_key('round')).width, 40);
    });

    testWidgets('a flat page row glyph is the square; a record mark is round', (
      tester,
    ) async {
      await _host(
        tester,
        Row(
          children: const <Widget>[
            LoopRowIcon(icon: 'id'),
            LoopRowIcon(icon: 'id', circle: true),
          ],
        ),
        flat: true,
      );
      final icons = tester
          .widgetList<LoopEntryIcon>(find.byType(LoopEntryIcon))
          .toList();
      expect(icons[0].shape, LoopEntryIconShape.square);
      expect(icons[1].shape, LoopEntryIconShape.circle);
    });
  });

  group('5 · the one search field', () {
    testWidgets('44 high, r12, searchBg, 1 px cardEdge, searchHint', (
      tester,
    ) async {
      await _host(
        tester,
        TextField(
          key: const ValueKey<String>('f'),
          decoration: loopSearchFieldDecoration(hint: 'Search members'),
        ),
      );
      expect(tester.getSize(_key('f')).height, LoopTouch.searchField);
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(decoration.fillColor, LoopColors.searchBg);
      expect(decoration.hintStyle, LoopType.searchHint);
      final edge = decoration.enabledBorder! as OutlineInputBorder;
      expect(edge.borderRadius, LoopRadius.control);
      expect(edge.borderSide.color, LoopColors.cardEdge);
      expect(edge.borderSide.width, 1);
    });

    test('the member search, rename, picker and search pages use it', () {
      for (final path in <String>[
        'lib/features/community/community_members_screen.dart',
        'lib/features/chat/v2/group_screens.dart',
        'lib/features/chat/v2/chat_search_screen.dart',
        'lib/features/chat/group_alias/group_alias_screen.dart',
        'lib/features/wallet/money_asset_picker.dart',
        'lib/features/community/search_screen.dart',
      ]) {
        expect(
          _source(path).contains('loopSearchFieldDecoration('),
          isTrue,
          reason: path,
        );
      }
    });

    testWidgets('regression: a plain form field keeps the theme', (
      tester,
    ) async {
      await _host(tester, const TextField());
      final theme = Theme.of(tester.element(find.byType(TextField)));
      expect(theme.inputDecorationTheme.fillColor, LoopColors.input);
    });
  });

  group('6 · sheet title is headline 19 / 700', () {
    testWidgets('LoopSheetHeading', (tester) async {
      await _host(tester, const LoopSheetHeading('Sheet'));
      final style = tester.widget<Text>(find.text('Sheet')).style!;
      expect(style.fontSize, 19);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('self-drawn sheet titles follow; pages keep heading', () {
      for (final path in <String>[
        'lib/widgets/loop_sheet.dart',
        'lib/widgets/loop_sign_sheet.dart',
        'lib/features/dapp/dapp_signing.dart',
        'lib/features/security/mfa/mfa_sheet.dart',
        'lib/features/security/mfa/passkey_sheet.dart',
      ]) {
        expect(
          RegExp(r'LoopType\.heading[^A-Za-z]').hasMatch(_source(path)),
          isFalse,
          reason: path,
        );
      }
    });
  });

  group('需求方 11-05 · the empty state step is the quiet secondary button', () {
    for (final width in <double>[360, 390]) {
      for (final label in <String>['Launch a token', '发射代币']) {
        testWidgets('LoopAtmoEmpty「$label」at $width', (tester) async {
          await _host(
            tester,
            LoopAtmoEmpty(
              message: 'No projects in the queue yet',
              actionLabel: label,
              actionKey: const ValueKey<String>('go'),
              onAction: () {},
            ),
            width: width,
          );
          final face = find.byKey(LoopEmptyActionButton.faceKey);
          expect(tester.getSize(face).height, LoopEmptyActionButton.height);
          final box =
              tester.widget<Container>(face).decoration! as BoxDecoration;
          expect(box.borderRadius, LoopRadius.button);
          expect(box.color, LoopColors.white8);
          final text = tester.widget<Text>(find.text(label));
          expect(text.overflow, isNot(TextOverflow.ellipsis));
          expect(text.maxLines, isNull);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(text.style!.fontSize, 14);
          expect(text.style!.fontWeight, FontWeight.w500);
          // Sized by its words, never wider than the content.
          expect(tester.getSize(face).width, lessThan(width - 40));
          expect(tester.getSize(_key('go')).height, greaterThanOrEqualTo(44));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a LoopButton handed to LoopEmptyState draws the same face', (
      tester,
    ) async {
      await _host(
        tester,
        LoopEmptyState(
          title: 'Nothing yet',
          action: LoopButton(
            key: const ValueKey<String>('cta'),
            label: 'Launch a token',
            primary: true,
            onPressed: () {},
          ),
        ),
      );
      expect(_key('cta'), findsOneWidget);
      final face = find.byKey(LoopEmptyActionButton.faceKey);
      expect(tester.getSize(face).height, LoopEmptyActionButton.height);
      // 16 under the title.
      final title = tester.getRect(_key('loop-empty-title'));
      final hit = tester.getRect(_key('cta'));
      expect(hit.top - title.bottom, LoopEmptyActionButton.titleGap);
      var tapped = 0;
      await _host(
        tester,
        LoopEmptyState(
          title: 'Nothing yet',
          action: LoopButton(label: 'Go', onPressed: () => tapped++),
        ),
      );
      await tester.tap(find.text('Go'));
      expect(tapped, 1);
    });

    testWidgets('a long word wraps instead of being cut', (tester) async {
      const long = 'Launch a token for this community and invite members';
      await _host(
        tester,
        LoopAtmoEmpty(message: 'Empty', actionLabel: long, onAction: () {}),
        width: 360,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        tester.getSize(find.byKey(LoopEmptyActionButton.faceKey)).height,
        greaterThan(LoopEmptyActionButton.height),
      );
    });

    testWidgets('regression: a LoopButton outside an empty state is 48', (
      tester,
    ) async {
      await _host(
        tester,
        LoopButton(
          key: const ValueKey<String>('b'),
          label: 'Save',
          primary: true,
          block: true,
          onPressed: () {},
        ),
      );
      expect(find.byKey(LoopEmptyActionButton.faceKey), findsNothing);
      expect(tester.getSize(_key('b')).height, LoopTouch.primaryButton);
    });
  });

  group('wired callers', () {
    test('rows S370a / b / c reported now take the Figma kinds', () {
      expect(
        _source('lib/features/community/community_widgets.dart'),
        contains('kind: LoopRecordRowKind.community'),
      );
      expect(
        _source('lib/features/community/community_screen.dart'),
        contains('kind: LoopRecordRowKind.community'),
      );
      for (final path in <String>[
        'lib/features/chat/v2/chat_search_screen.dart',
        'lib/features/chat/v2/chat_forward_screens.dart',
      ]) {
        final text = _source(path);
        expect(text, contains('kind: LoopRecordRowKind.person'), reason: path);
        expect(text, contains('titleStyle: LoopType.rowTitleLg'), reason: path);
      }
      expect(
        _source('lib/features/social/blocklist_screen.dart'),
        contains('kind: LoopRecordRowKind.person'),
      );
      expect(
        _source('lib/features/chat/friends/friend_screens.dart'),
        contains('kind: LoopRecordRowKind.person'),
      );
      final projects = _source(
        'lib/features/launch2/creator/launch2_projects_screen.dart',
      );
      expect(projects, contains('kind: LoopRecordRowKind.token'));
      expect(projects, contains('Launch2SecondaryMetrics.tokenFace'));
      final holdings = _source('lib/features/launch2/launch2_wallet_rows.dart');
      expect(holdings, contains('height: LoopRowHeight.holdings'));
      expect(holdings, contains('valueStyle: LoopType.figureSm'));
      final manage = _source(
        'lib/features/community/community_manage_screen.dart',
      );
      expect('shape: LoopEntryIconShape.square'.allMatches(manage).length, 8);
      expect('divider: true'.allMatches(manage).length, 8);
    });
  });
}
