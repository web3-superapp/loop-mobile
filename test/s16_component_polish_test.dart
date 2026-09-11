import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Decision 0071 · the S16-C component and motion contract.
///
/// Three user complaints are pinned here: a state block must be a line of
/// copy rather than a framed panel, a skeleton must be the shape of the thing
/// it is loading, and a block that already has data must keep it while it
/// re-reads.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('inline state strips', () {
    testWidgets('LoopEmpty is one line of copy, not a framed panel', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[LoopEmpty(message: '还没有内容')],
        ),
      );

      final block = find.byKey(const ValueKey<String>('loop-empty'));
      expect(block, findsOneWidget);
      // No full-height frame: nothing here draws a border or a card ground.
      expect(
        find.descendant(of: block, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      // The glyph stays inline-sized (`.ico-sm`), never the 34px panel mark.
      expect(
        tester
            .widgetList<LoopIcon>(
              find.descendant(of: block, matching: find.byType(LoopIcon)),
            )
            .single
            .size,
        LoopEmpty.compactIconSize,
      );
      // One line of copy plus its padding, and nothing else.
      expect(tester.getSize(block).height, lessThan(48));
    });

    testWidgets('the block grows only with what it actually says', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const LoopEmpty(
              key: ValueKey<String>('one-line'),
              message: '还没有内容',
            ),
          ],
        ),
      );
      final oneLine = tester
          .getSize(find.byKey(const ValueKey<String>('loop-empty')))
          .height;

      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopEmpty(
              key: const ValueKey<String>('with-action'),
              message: '还没有内容',
              reason: '这个列表暂时读不到。',
              action: LoopButton(label: '重试', onPressed: () {}),
            ),
          ],
        ),
      );
      final withAction = tester
          .getSize(find.byKey(const ValueKey<String>('loop-empty')))
          .height;

      expect(find.text('这个列表暂时读不到。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(withAction, greaterThan(oneLine));
    });

    testWidgets('LoopUnavailableCard keeps its key, semantics and next step', (
      tester,
    ) async {
      var retries = 0;
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopUnavailableCard(
              label: '余额当前不可用',
              reasonCode: 'BALANCE_SOURCE_DEFERRED',
              action: LoopButton(label: '重试', onPressed: () => retries += 1),
            ),
          ],
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('unavailable-BALANCE_SOURCE_DEFERRED'),
        ),
        findsOneWidget,
      );
      expect(find.text('余额当前不可用'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retries, 1);
    });

    testWidgets('LoopPageBlock is the one whole-page state', (tester) async {
      await _pump(
        tester,
        LoopPageBlock(
          title: '这个页面当前不可用',
          message: '这项功能还没有开放。',
          action: LoopButton(label: '返回', onPressed: () {}),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-block')),
        findsOneWidget,
      );
      expect(find.text('这个页面当前不可用'), findsOneWidget);
      expect(find.byType(LoopBrandMark), findsOneWidget);
    });
  });

  group('skeletons take the shape of what is arriving', () {
    testWidgets('row, card and figure are three different shapes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopSkeleton.row(rows: 2),
            SizedBox(height: 12),
            LoopSkeleton.card(),
            SizedBox(height: 12),
            LoopSkeleton.figure(),
          ],
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-figure')),
        findsOneWidget,
      );
      // A skeleton claims nothing: no copy, only shapes.
      expect(find.byType(Text), findsNothing);
      expect(find.bySemanticsLabel('卡片加载中'), findsOneWidget);
      expect(find.bySemanticsLabel('数字加载中'), findsOneWidget);
      // Two rows of two blocks, three card lines, two figure lines.
      expect(find.byType(LoopSkeletonBlock), findsNWidgets(2 * 2 + 3 + 2));
      semantics.dispose();
    });

    testWidgets('an inline row placeholder stays inline-sized', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[LoopSkeleton.row(rows: 1)],
        ),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('loop-skeleton-row')))
            .height,
        lessThan(40),
      );
    });
  });

  group('a re-read keeps the data it already has', () {
    test('chain and community states mark a refresh over a cached value', () {
      const ready = LoopChainResourceState<int>(
        mode: LoopChainGatewayMode.production,
        phase: LoopChainViewPhase.ready,
        value: 7,
      );
      final refreshing = ready.loading();
      expect(refreshing.phase, LoopChainViewPhase.ready);
      expect(refreshing.value, 7, reason: 'the read value survives the reload');
      expect(refreshing.refreshing, isTrue);
      expect(refreshing.ready(8).refreshing, isFalse);
      expect(
        refreshing.failed(LoopChainFailureKind.unexpected).refreshing,
        isFalse,
      );

      // No cached value: this is a first load, and it renders as a skeleton.
      const cold = LoopChainResourceState<int>(
        mode: LoopChainGatewayMode.production,
        phase: LoopChainViewPhase.loading,
      );
      expect(cold.loading().phase, LoopChainViewPhase.loading);
      expect(cold.loading().refreshing, isFalse);

      const communityReady = CommunityResourceState<int>(
        mode: CommunityGatewayMode.production,
        phase: CommunityViewPhase.ready,
        value: 3,
      );
      expect(communityReady.loading().refreshing, isTrue);
      expect(communityReady.loading().value, 3);
      expect(
        const CommunityResourceState<int>(
          mode: CommunityGatewayMode.production,
          phase: CommunityViewPhase.loading,
        ).loading().refreshing,
        isFalse,
      );
    });

    testWidgets('the ready block wears 更新中 instead of a skeleton', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'demo',
              phase: LoopChainViewPhase.ready,
              failureKind: null,
              refreshing: true,
            ),
            CommunityStateBlock(
              phase: CommunityViewPhase.ready,
              failureKind: null,
              refreshing: true,
            ),
          ],
        ),
      );

      expect(find.text('更新中'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey<String>('loop-skeleton-list')),
        findsNothing,
      );
    });

    testWidgets('a settled block wears nothing at all', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopChainStateBlock(
              keyPrefix: 'demo',
              phase: LoopChainViewPhase.ready,
              failureKind: null,
            ),
          ],
        ),
      );
      expect(find.text('更新中'), findsNothing);
    });

    testWidgets('a page marks the refresh in its topbar', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[LoopTopbar(title: '钱包', updating: true)],
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-updating-badge')),
        findsOneWidget,
      );
      expect(find.text('钱包'), findsOneWidget);
    });
  });

  group('chat header strip', () {
    testWidgets('states presence and the announcement on one line', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopChatHeaderStrip(segments: <String>['在线 128', '公告 今晚 20:00 开播']),
          ],
        ),
      );

      final strip = find.byKey(
        const ValueKey<String>('loop-chat-header-strip'),
      );
      expect(strip, findsOneWidget);
      expect(find.text('在线 128 · 公告 今晚 20:00 开播'), findsOneWidget);
      // One line of context, not two cards: it costs the list almost nothing.
      expect(tester.getSize(strip).height, lessThan(40));
    });

    testWidgets('an unstated fact renders no row at all', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[LoopChatHeaderStrip(), Text('消息')],
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-chat-header-strip')),
        findsNothing,
      );
      expect(find.text('消息'), findsOneWidget);
    });

    testWidgets('an empty segment is not a fact either', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopChatHeaderStrip(segments: <String>['', '   ']),
          ],
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-chat-header-strip')),
        findsNothing,
      );
    });

    testWidgets('the raised keyboard folds the header away', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopChatHeaderStrip(segments: <String>['在线 128'], collapsed: true),
            LoopChatHeaderFold(collapsed: true, child: Text('群规则')),
            Text('消息'),
          ],
        ),
        keyboard: 336,
      );

      expect(
        find.byKey(const ValueKey<String>('loop-chat-header-strip')),
        findsNothing,
      );
      expect(find.text('群规则'), findsNothing);
      expect(find.text('消息'), findsOneWidget);
    });

    testWidgets('lowering the keyboard brings the header back', (tester) async {
      Widget header({required bool keyboardUp}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopChatHeaderStrip(
            segments: const <String>['在线 128'],
            collapsed: keyboardUp,
          ),
          LoopChatHeaderFold(collapsed: keyboardUp, child: const Text('群规则')),
        ],
      );
      await _pump(tester, header(keyboardUp: true), keyboard: 336);
      expect(find.text('群规则'), findsNothing);
      await _pump(tester, header(keyboardUp: false));
      expect(find.text('在线 128'), findsOneWidget);
      expect(find.text('群规则'), findsOneWidget);
    });

    testWidgets(
      'the screen reads the keyboard above its Scaffold, not under it',
      (tester) async {
        // A Scaffold body's MediaQuery has already had `viewInsets.bottom`
        // removed, so the reading has to happen where the screen is built.
        late bool insideBody;
        late bool aboveScaffold;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: LoopTheme.dark,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                viewInsets: EdgeInsets.only(bottom: 336),
              ),
              child: Builder(
                builder: (context) {
                  aboveScaffold = loopChatKeyboardIsUp(context);
                  return Scaffold(
                    body: Builder(
                      builder: (context) {
                        insideBody = loopChatKeyboardIsUp(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(aboveScaffold, isTrue);
        expect(insideBody, isFalse);
      },
    );
  });

  group('topbar with tools', () {
    Widget toolbar({required bool dense, required int titleMaxLines}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopTopbar(
          title: 'Builders Guild',
          onBack: () {},
          minHeight: 72,
          dense: dense,
          titleMaxLines: titleMaxLines,
          actions: <Widget>[
            for (final tool in <String>['search', 'shuffle', 'voice', 'info'])
              LoopIconButton(icon: tool, label: tool, onPressed: () {}),
          ],
        ),
      ],
    );

    testWidgets('four tools leave a wrapped title half the bar', (
      tester,
    ) async {
      await _pump(tester, toolbar(dense: false, titleMaxLines: 2));
      final wrapped = tester.getSize(find.text('Builders Guild'));

      await _pump(tester, toolbar(dense: true, titleMaxLines: 1));
      final single = tester.getSize(find.text('Builders Guild'));

      // One line instead of two, and a wider column to spend it in.
      expect(single.height, lessThan(wrapped.height));
      expect(single.width, greaterThan(wrapped.width));
      // The bar keeps its own height either way, so nothing below it moves.
      expect(
        tester.getSize(find.byType(LoopTopbar)).height,
        greaterThanOrEqualTo(72),
      );
    });

    testWidgets('a page with room keeps the two-line default', (tester) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[LoopTopbar(title: '社区官方群与语音房设置')],
        ),
      );

      final title = tester.widget<Text>(find.text('社区官方群与语音房设置'));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });

  group('folio primary', () {
    // The mining hero, verbatim: the caption the stamp was crushing.
    const String caption = '算力、今日预估、累计与待领取都要等挖矿公式版本被批准后才能计算。';

    /// The card's own content box, which both prototype ceilings measure
    /// against: the folio's page margin plus its padding taken off the width
    /// the keyed Container reports (`.folio-primary{margin:0 16px;padding:18px}`).
    double contentWidth(WidgetTester tester, {double padding = 18}) =>
        tester
            .getSize(find.byKey(const ValueKey<String>('loop-folio-primary')))
            .width -
        LoopSpacing.page * 2 -
        padding * 2;

    Future<Rect> pumpFolio(WidgetTester tester, {String? stamp}) async {
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopFolioPrimary(
              kicker: 'MINING POWER',
              heading: '暂无数值',
              caption: caption,
              stamp: stamp,
              archetype: LoopFolioArchetype.record,
            ),
          ],
        ),
      );
      return tester.getRect(find.text(caption));
    }

    testWidgets('a two-character stamp costs the caption only its own width', (
      tester,
    ) async {
      final captionRect = await pumpFolio(tester, stamp: '待批准');
      final content = contentWidth(tester);

      // The flat 57% budget (`.folio-primary:has(>.folio-stamp)
      // .folio-caption`) is the room a stamp at its 42% ceiling needs. A
      // short stamp must not cost that much.
      expect(captionRect.width, greaterThan(content * 0.57));
      // And never more than the caption's own ceiling (`max-width:80%`).
      expect(captionRect.width, lessThanOrEqualTo(content * 0.8 + 0.5));
      // Two lines of the mining copy, not three at half the card's width.
      expect(captionRect.height, lessThan(40));
    });

    testWidgets('the caption gives way to exactly what the stamp uses', (
      tester,
    ) async {
      final narrow = await pumpFolio(tester, stamp: '待批准');
      final wide = await pumpFolio(tester, stamp: 'PENDING CONFIRMATION');
      final content = contentWidth(tester);

      // The wider stamp takes more room away, and the two never share a
      // column: the caption stops before the pill starts.
      expect(wide.width, lessThan(narrow.width));
      expect(wide.width, greaterThan(content * 0.5));
      final stampRect = tester.getRect(find.text('PENDING CONFIRMATION'));
      expect(wide.right, lessThanOrEqualTo(stampRect.left));
    });

    testWidgets('an unstamped caption keeps the prototype ceiling', (
      tester,
    ) async {
      final captionRect = await pumpFolio(tester);
      final content = contentWidth(tester);

      expect(captionRect.width, greaterThan(content * 0.57));
      expect(captionRect.width, lessThanOrEqualTo(content * 0.8 + 0.5));
      expect(find.byType(LoopFolioPrimary), findsOneWidget);
    });

    testWidgets('a long stamp stays inside its own 42% ceiling', (
      tester,
    ) async {
      await pumpFolio(tester, stamp: 'PENDING FORMULA APPROVAL FOR THIS ROUND');
      final content = contentWidth(tester);
      final stampRect = tester.getRect(
        find.text('PENDING FORMULA APPROVAL FOR THIS ROUND'),
      );

      expect(stampRect.width, lessThanOrEqualTo(content * 0.42 + 0.5));
      // One line, ellipsised: the pill never becomes a paragraph.
      expect(stampRect.height, lessThan(20));
    });

    testWidgets('a compact hero with a trailing figure stays out of the pill', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopFolioPrimary(
              kicker: 'WALLET',
              heading: '暂无数值',
              caption: caption,
              stamp: 'NET WORTH',
              compact: true,
              trailing: Text('+2.4%'),
            ),
          ],
        ),
      );

      final captionRect = tester.getRect(find.text(caption));
      final stampRect = tester.getRect(find.text('NET WORTH'));
      expect(captionRect.right, lessThanOrEqualTo(stampRect.left));
      expect(find.text('+2.4%'), findsOneWidget);
      // The compact card pads by 14, so its content box is wider than the
      // 18px one; the caption still stops at its own ceiling.
      expect(
        captionRect.width,
        lessThanOrEqualTo(contentWidth(tester, padding: 14) * 0.8 + 0.5),
      );
    });
  });
}
