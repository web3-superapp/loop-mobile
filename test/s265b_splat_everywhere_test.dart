// S265b · 选中态黄喷点全局统一 (client decision 0222): every solid Purple
// choice wears the Yellow splat on its top-left corner — the shared
// segments, the choice buttons, the market tab strip, the wallet's asset
// tabs, MEME's stage chips — and nothing else does: the plain buttons, the
// top text tabs and the tab bar stay as they were.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_atmosphere.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final Finder _splat = _key('loop-seg-splat');

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(children: <Widget>[child]),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The splat sits on the top-left corner of [chosen]: its centre is above
/// and left of the chosen box's top-left quarter.
void _onTopLeft(WidgetTester tester, Finder chosen) {
  final splat = tester.getRect(find.descendant(of: chosen, matching: _splat));
  final box = tester.getRect(chosen);
  expect(splat.center.dx, lessThan(box.left + box.width / 2));
  expect(splat.center.dy, lessThan(box.top + box.height / 2));
}

void main() {
  testWidgets('LoopSegBar: the chosen capsule wears the splat by default', (
    tester,
  ) async {
    await _pump(
      tester,
      LoopSegBar(
        labels: const <String>['全部', '社区', '好友'],
        selectedIndex: 1,
        onSelected: (_) {},
      ),
    );
    final chips = find.byType(LoopSeg);
    expect(chips, findsNWidgets(3));
    expect(find.descendant(of: chips.at(0), matching: _splat), findsNothing);
    expect(find.descendant(of: chips.at(1), matching: _splat), findsOneWidget);
    expect(find.descendant(of: chips.at(2), matching: _splat), findsNothing);
    _onTopLeft(tester, chips.at(1));
  });

  testWidgets('LoopSeg without a capsule height wears it too; `splat: false` '
      'is the one way out', (tester) async {
    await _pump(
      tester,
      Row(
        children: <Widget>[
          LoopSeg(
            key: const ValueKey<String>('on'),
            label: '我加入的',
            quiet: true,
            selected: true,
            onSelected: () {},
          ),
          LoopSeg(
            key: const ValueKey<String>('off'),
            label: '全部',
            quiet: true,
            selected: false,
            onSelected: () {},
          ),
          LoopSeg(
            key: const ValueKey<String>('opted-out'),
            label: '新建',
            selected: true,
            splat: false,
            onSelected: () {},
          ),
        ],
      ),
    );
    expect(find.descendant(of: _key('on'), matching: _splat), findsOneWidget);
    expect(find.descendant(of: _key('off'), matching: _splat), findsNothing);
    expect(
      find.descendant(of: _key('opted-out'), matching: _splat),
      findsNothing,
    );
  });

  testWidgets('a chosen LoopButton wears it; a primary, a secondary and an '
      'unchosen choice do not', (tester) async {
    await _pump(
      tester,
      Wrap(
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('chosen'),
            label: '0.5%',
            selected: true,
            onPressed: () {},
          ),
          LoopButton(
            key: const ValueKey<String>('unchosen'),
            label: '1%',
            selected: false,
            onPressed: () {},
          ),
          LoopButton(
            key: const ValueKey<String>('primary'),
            label: '去参与',
            primary: true,
            onPressed: () {},
          ),
          LoopButton(
            key: const ValueKey<String>('secondary'),
            label: '取消',
            onPressed: () {},
          ),
        ],
      ),
    );
    expect(
      find.descendant(of: _key('chosen'), matching: _splat),
      findsOneWidget,
    );
    for (final key in <String>['unchosen', 'primary', 'secondary']) {
      expect(
        find.descendant(of: _key(key), matching: _splat),
        findsNothing,
        reason: key,
      );
    }
  });

  testWidgets('MarketTabBar (行情 / 代币 / MEME home strips): the chosen tab '
      'wears it', (tester) async {
    await _pump(
      tester,
      MarketTabBar(
        labels: const <String>['自选', '主流', 'MEME'],
        selectedIndex: 2,
        onSelected: (_) {},
      ),
    );
    expect(_splat, findsOneWidget);
    final chosen = find.ancestor(
      of: find.text('MEME'),
      matching: find.byType(Container),
    );
    final splat = tester.getRect(_splat);
    final word = tester.getRect(find.text('MEME'));
    expect(splat.center.dx, lessThan(word.center.dx));
    expect(splat.center.dy, lessThan(word.center.dy));
    expect(chosen, findsWidgets);
  });

  testWidgets('钱包 代币 / NFT: the chosen tab wears it, with no flag passed', (
    tester,
  ) async {
    await _pump(
      tester,
      WalletAssetTabs(selectedIndex: WalletAssetTabs.nft, onSelected: (_) {}),
    );
    expect(
      find.descendant(of: _key('wallet-asset-tab-nft'), matching: _splat),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('wallet-asset-tab-tokens'), matching: _splat),
      findsNothing,
    );
  });

  testWidgets('MEME stage chips keep their own splat', (tester) async {
    await _pump(
      tester,
      Launch2StageChips(
        chips: const <Launch2ChipSpec>[
          (id: 'public', title: '内盘', count: 3, selected: true),
          (id: 'upcoming', title: '预告', count: 0, selected: false),
        ],
        onSelected: (_) {},
      ),
    );
    expect(_key('launch2-desk-seg-splat-public'), findsOneWidget);
    expect(_key('launch2-desk-seg-splat-upcoming'), findsNothing);
  });

  testWidgets('the top text tabs (Yellow dash) wear no splat', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: LoopSegmentedTabPage(
            tabKey: 'probe',
            title: '情报',
            segments: const <String>['算力榜', '行情'],
            builder: (context, index) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_key('probe-segment-0'), findsOneWidget);
    expect(_splat, findsNothing);
  });
}
