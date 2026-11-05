// S377 · decision 0301: the Figma's 11-05 revision lifts the token,
// community and holdings rows' name from 14 to 16 (docs/58 §5.4 / §5.8 /
// §5.13, §9.6) and the holdings amount from 14 / 600 to 16 / 600. Board rows
// (§5.16) keep their 14. Row heights stay 71 / 86 / 51; a long name ellipses
// at 360 without overflowing.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_quote_row.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s269_pages.dart';
import 'support/s350b_pages.dart';
import 'support/s5_fixtures.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

TextStyle _painted(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!;

bool _cut(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).didExceedMaxLines;

Future<void> _host(WidgetTester tester, Widget child, {double width = 360}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[child],
          ),
        ),
      ),
    ),
  );
}

const String _long =
    'A Remarkably Long Community Or Token Name That Never Ends Here';

CommunityDirectoryPage _page(List<CommunitySummary> items) =>
    CommunityDirectoryPage(
      items: items,
      nextCursor: null,
      recommendation: const CommunityRecommendation(
        recommendationId: '22222222-2222-4222-8222-222222222222',
        ruleVersion: 'rule:verified-members-v1',
      ),
      ordering: const CommunityOrderingApplied(
        sort: CommunityDirectorySort.members,
        basis: CommunityStoredBasis(),
      ),
    );

void main() {
  loopWatchGround();
  setUpAll(loopLoadShotFonts);

  test('the steps: rowTitle 16 / 500 / 22, figure 16 / 600, body1 14', () {
    expect(LoopType.rowTitle.fontSize, 16);
    expect(LoopType.rowTitle.fontWeight, FontWeight.w500);
    expect(LoopType.rowTitle.height! * 16, closeTo(22, 0.001));
    expect(LoopType.figure.fontSize, 16);
    expect(LoopType.figure.fontWeight, FontWeight.w600);
    expect(LoopType.body1.fontSize, 14);
    expect(LoopType.body1.fontWeight, FontWeight.w500);
  });

  group('MEME token row · §5.4', () {
    for (final width in <double>[390, 360]) {
      testWidgets('the name is 16 / 500, the ticker 12 / 300 @$width', (
        tester,
      ) async {
        await pumpS279MemeHome(tester, size: Size(width, 1400));
        await tester.tap(_key('launch2-desk-tab-live'));
        await tester.pumpAndSettle();
        final row = find.byType(Launch2BoardRow).first;
        expect(tester.getSize(row).height, Launch2BoardRow.height);
        final name = find.descendant(of: row, matching: find.text('天才少年'));
        expect(name, findsOneWidget);
        final style = _painted(tester, name);
        expect(style.fontSize, 16);
        expect(style.fontWeight, FontWeight.w500);
        final ticker = find.descendant(of: row, matching: find.text('TC'));
        if (ticker.evaluate().isNotEmpty) {
          expect(_painted(tester, ticker).fontSize, 12);
          expect(_painted(tester, ticker).fontWeight, FontWeight.w300);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a token-kind record row defaults to 16 / 500 at 71', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordRow(
          key: ValueKey<String>('token'),
          title: 'Token',
          subtitle: 'line',
          kind: LoopRecordRowKind.token,
        ),
      );
      final text = tester.widget<Text>(find.text('Token'));
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(tester.getSize(_key('token')).height, LoopRowHeight.token);
    });
  });

  group('Community row · §5.8', () {
    testWidgets('a 广场 community card name is 16 / 500 in an 86 row', (
      tester,
    ) async {
      final base = testCommunity(
        communityId: '4b96a75e-6828-4a6b-8c1d-000000000000',
        name: '社区 0',
      );
      await pumpCommunityPage(
        tester,
        SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
        community: FakeCommunityGateway(
          directoryPage: _page(<CommunitySummary>[base]),
        ),
        size: const Size(390, 1400),
      );
      final id = base.communityId;
      final name = tester.widget<Text>(_key('square-community-name-$id'));
      expect(name.style?.fontSize, 16);
      expect(name.style?.fontWeight, FontWeight.w500);
      expect(tester.getSize(_key('square-community-card-$id')).height, 86);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 30));
    });

    testWidgets('a community-kind record row defaults to 16 / 500 at 86', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordRow(
          key: ValueKey<String>('community'),
          title: 'Community',
          subtitle: 'line',
          kind: LoopRecordRowKind.community,
        ),
      );
      final text = tester.widget<Text>(find.text('Community'));
      expect(text.style!.fontSize, 16);
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(tester.getSize(_key('community')).height, LoopRowHeight.community);
    });
  });

  group('Holdings row · §5.13', () {
    testWidgets('我的: name 16 / 500, amount 16 / 600, caption 12, 51 tall', (
      tester,
    ) async {
      await pumpMePage(tester, size: const Size(360, 1400));
      const assetId = s5NativeAssetId;
      expect(
        tester.getSize(_key('wallet-balance-head-$assetId')).height,
        LoopRowHeight.holdings,
      );
      final names = find.descendant(
        of: _key('wallet-balance-open-$assetId'),
        matching: find.text('BNB'),
      );
      final name = tester.widget<Text>(names.last);
      expect(name.style!.fontSize, 16);
      expect(name.style!.fontWeight, FontWeight.w500);
      final amount = tester.widget<Text>(
        _key('wallet-balance-amount-$assetId'),
      );
      expect(amount.style!.fontSize, 16);
      expect(amount.style!.fontWeight, FontWeight.w600);
      final value = tester.widget<Text>(_key('wallet-balance-value-$assetId'));
      expect(value.style!.fontSize, 12);
      expect(value.style!.fontWeight, FontWeight.w300);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a holdings quote row: name 16 / 500, amount 16 / 600', (
      tester,
    ) async {
      await _host(
        tester,
        LoopQuoteRow(
          key: const ValueKey<String>('hold'),
          leading: const SizedBox.square(dimension: 36),
          title: 'HOLD',
          subtitle: 'name',
          value: '1,234.56',
          valueCaption: const Text('≈ 12.00 USD1'),
          height: LoopRowHeight.holdings,
          titleStyle: LoopType.rowTitle,
          valueStyle: LoopType.figure,
        ),
      );
      expect(tester.widget<Text>(find.text('HOLD')).style!.fontSize, 16);
      final amount = tester.widget<Text>(find.text('1,234.56'));
      expect(amount.style!.fontSize, 16);
      expect(amount.style!.fontWeight, FontWeight.w600);
      expect(tester.getSize(_key('hold')).height, LoopRowHeight.holdings);
    });

    testWidgets('a holdings-kind record row defaults to 16 / 500 at 51', (
      tester,
    ) async {
      await _host(
        tester,
        const LoopRecordRow(
          key: ValueKey<String>('h'),
          title: 'Holding',
          kind: LoopRecordRowKind.holdings,
        ),
      );
      expect(tester.widget<Text>(find.text('Holding')).style!.fontSize, 16);
      expect(tester.getSize(_key('h')).height, LoopRowHeight.holdings);
    });
  });

  group('Board rows keep 14 · §5.16', () {
    testWidgets('算力榜 names stay 14', (tester) async {
      await s350bPumpRank(tester, size: const Size(390, 1500));
      expect(_painted(tester, _key('intel-rank-name-1')).fontSize, 14);
    });

    testWidgets('a function row and a row without kind keep 14', (
      tester,
    ) async {
      await _host(
        tester,
        const Column(
          children: <Widget>[
            LoopRecordRow(title: 'Fn', kind: LoopRecordRowKind.function),
            LoopRecordRow(title: 'Plain'),
          ],
        ),
      );
      expect(tester.widget<Text>(find.text('Fn')).style!.fontSize, 14);
      expect(tester.widget<Text>(find.text('Plain')).style!.fontSize, 14);
    });
  });

  group('360: a long name ellipses without overflowing', () {
    for (final kind in <LoopRecordRowKind>[
      LoopRecordRowKind.token,
      LoopRecordRowKind.community,
      LoopRecordRowKind.holdings,
    ]) {
      testWidgets('record row · ${kind.name}', (tester) async {
        await _host(
          tester,
          LoopRecordRow(
            title: _long,
            subtitle: 'line',
            kind: kind,
            leading: const SizedBox.square(dimension: 44),
            trailing: '1,234,567.89',
            onTap: () {},
          ),
        );
        expect(_cut(tester, find.text(_long)), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('holdings quote row', (tester) async {
      await _host(
        tester,
        LoopQuoteRow(
          leading: const SizedBox.square(dimension: 36),
          title: _long,
          subtitle: 'name',
          value: '1,234,567.891234',
          valueCaption: const Text('≈ 1,234,567.00 USD1'),
          height: LoopRowHeight.holdings,
          titleStyle: LoopType.rowTitle,
          valueStyle: LoopType.figure,
        ),
      );
      expect(_cut(tester, find.text(_long)), isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
