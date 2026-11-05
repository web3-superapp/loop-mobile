// S265b · 选中态黄喷点全局统一 (client decision 0222): every solid Purple
// choice wears the Yellow splat on its top-left corner — the shared
// segments, the choice buttons, the market tab strip, the wallet's asset
// tabs, MEME's stage chips — and nothing else does: the plain buttons, the
// top text tabs and the tab bar stay as they were.
//
// S367 · decision 0291: the spray is gone from every chip — `splat: true`
// and MEME's stage chips no longer draw it either.
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

void main() {
  // Decision 0277: the Figma's filter chip has no splat, so a LoopSeg /
  // LoopSegBar no longer wears it by default; `splat: true` is the way in.
  testWidgets('LoopSegBar: the chosen chip wears no splat, by default or '
      'opted in (0291)', (tester) async {
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
    expect(find.descendant(of: chips.at(1), matching: _splat), findsNothing);
    expect(find.descendant(of: chips.at(2), matching: _splat), findsNothing);
    await _pump(
      tester,
      LoopSegBar(
        labels: const <String>['全部', '社区', '好友'],
        selectedIndex: 1,
        splat: true,
        onSelected: (_) {},
      ),
    );
    // Decision 0291: `splat: true` draws nothing any more.
    final opted = find.byType(LoopSeg);
    expect(find.descendant(of: opted.at(1), matching: _splat), findsNothing);
  });

  testWidgets('LoopSeg without a capsule height wears none either, not even '
      'with `splat: true` (0291)', (tester) async {
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
            key: const ValueKey<String>('opted-in'),
            label: '新建',
            selected: true,
            splat: true,
            onSelected: () {},
          ),
        ],
      ),
    );
    expect(find.descendant(of: _key('on'), matching: _splat), findsNothing);
    expect(find.descendant(of: _key('off'), matching: _splat), findsNothing);
    expect(
      find.descendant(of: _key('opted-in'), matching: _splat),
      findsNothing,
    );
  });

  // S353a · decision 0278 (docs/58 §9.3): a chosen state is the white word
  // on white 10 %; the chosen LoopButton no longer wears the splat.
  testWidgets('no LoopButton wears it: chosen, unchosen, primary, secondary', (
    tester,
  ) async {
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
    for (final key in <String>['chosen', 'unchosen', 'primary', 'secondary']) {
      expect(
        find.descendant(of: _key(key), matching: _splat),
        findsNothing,
        reason: key,
      );
    }
  });

  testWidgets('MarketTabBar (行情 / 代币 / MEME home strips): the chosen tab '
      'is the white chip, no splat (S353a)', (tester) async {
    await _pump(
      tester,
      MarketTabBar(
        labels: const <String>['自选', '主流', 'MEME'],
        selectedIndex: 2,
        onSelected: (_) {},
      ),
    );
    expect(_splat, findsNothing);
    final chosen = tester.widget<Container>(
      find
          .ancestor(of: find.text('MEME'), matching: find.byType(Container))
          .first,
    );
    expect((chosen.decoration! as BoxDecoration).color, LoopColors.chipActive);
  });

  testWidgets('钱包 代币 / NFT: the Figma chips wear no splat (0277)', (
    tester,
  ) async {
    await _pump(
      tester,
      WalletAssetTabs(selectedIndex: WalletAssetTabs.nft, onSelected: (_) {}),
    );
    expect(
      find.descendant(of: _key('wallet-asset-tab-nft'), matching: _splat),
      findsNothing,
    );
    expect(
      find.descendant(of: _key('wallet-asset-tab-tokens'), matching: _splat),
      findsNothing,
    );
  });

  testWidgets('MEME stage chips wear no splat either (0291)', (tester) async {
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
    expect(_key('launch2-desk-seg-splat-public'), findsNothing);
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
