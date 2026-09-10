import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';

void main() {
  test('Lime Ledger foundation keeps the four canonical V2 colors', () {
    expect(LoopColors.ink, const Color(0xFF050604));
    expect(LoopColors.lime, const Color(0xFFB8FF20));
    expect(LoopColors.chalk, const Color(0xFFF3F5EF));
    expect(LoopColors.graphite, const Color(0xFF171A16));
    expect(
      _contrastRatio(LoopColors.muted, LoopColors.graphite),
      greaterThanOrEqualTo(4.5),
    );

    final navigation = LoopTheme.dark.navigationBarTheme;
    final background = navigation.backgroundColor!;
    final indicator = navigation.indicatorColor!;
    final selected = <WidgetState>{WidgetState.selected};
    final unselected = <WidgetState>{};
    final selectedIcon = navigation.iconTheme!.resolve(selected)!.color!;
    final unselectedIcon = navigation.iconTheme!.resolve(unselected)!.color!;
    final selectedLabel = navigation.labelTextStyle!.resolve(selected)!.color!;
    final unselectedLabel = navigation.labelTextStyle!
        .resolve(unselected)!
        .color!;

    expect(background, LoopColors.chalk);
    expect(indicator, LoopColors.lime);
    expect(
      _contrastRatio(Color.alphaBlend(selectedIcon, indicator), indicator),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(Color.alphaBlend(unselectedIcon, background), background),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(Color.alphaBlend(selectedLabel, background), background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(Color.alphaBlend(unselectedLabel, background), background),
      greaterThanOrEqualTo(4.5),
    );
  });

  group('Community UI foundation', () {
    testWidgets('stays truthful while the community capability is unknown', (
      tester,
    ) async {
      await _pumpCommunity(tester);

      expect(find.byKey(const ValueKey<String>('community-screen')), findsOne);
      // No capability document has been observed, so the page issues no
      // request and states that instead of showing a figure.
      expect(
        find.byKey(const ValueKey<String>('community-capability-unavailable')),
        findsOne,
      );
      expect(find.text('社区模块当前不可用'), findsOne);
      expect(find.textContaining('尚未读取到能力清单'), findsOne);
      expect(find.text('—'), findsWidgets);

      for (final inventedFact in <String>[
        '38 VERIFIED',
        '4 个社区在挖矿',
        '48,120 成员',
        '12 LIVE',
        'PEPE Community',
        'BONK Community',
        'MOONCAT',
        '3 条未读',
        '演示数据',
      ]) {
        expect(
          find.textContaining(inventedFact),
          findsNothing,
          reason: inventedFact,
        );
      }
    });

    testWidgets('search and message panels are mutually exclusive', (
      tester,
    ) async {
      await _pumpCommunity(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-search-toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-search-panel')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('community-message-panel')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-search-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-message-panel')),
        findsOne,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-close')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-message-panel')),
        findsNothing,
      );
    });

    testWidgets('floating panels are opaque and close from the scrim', (
      tester,
    ) async {
      await _pumpCommunity(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-toggle')),
      );
      await tester.pumpAndSettle();
      final panel = tester.widget<LoopSurfaceCard>(
        find.byKey(const ValueKey<String>('community-message-panel')),
      );
      // The page card fill is translucent by design; a panel floating over
      // page content must paint an opaque surface so nothing shows through.
      expect(panel.background, LoopColors.elevated);
      expect(panel.background!.a, 1.0);
      expect(
        find.byKey(const ValueKey<String>('community-panel-scrim')),
        findsOne,
      );

      await tester.tapAt(
        tester
            .getRect(
              find.byKey(const ValueKey<String>('community-panel-scrim')),
            )
            .bottomCenter
            .translate(0, -8),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-message-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-panel-scrim')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-search-toggle')),
      );
      await tester.pumpAndSettle();
      final search = tester.widget<LoopSurfaceCard>(
        find.byKey(const ValueKey<String>('community-search-panel')),
      );
      expect(search.background, LoopColors.elevated);
    });

    testWidgets('the search panel names the only global search entry', (
      tester,
    ) async {
      await _pumpCommunity(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-search-toggle')),
      );
      await tester.pumpAndSettle();

      // 01 §3 / §12.2: the one sentence a user must be able to read here.
      expect(
        find.byKey(const ValueKey<String>('community-search-entry-note')),
        findsOne,
      );
      expect(find.textContaining('全局资产与社区搜索从社区 Tab 顶部进入'), findsOne);
      // The retired Home entry must not be described anywhere.
      expect(find.textContaining('从首页'), findsNothing);
    });

    testWidgets('the profile action reaches the profile domain', (
      tester,
    ) async {
      final destinations = <String>[];
      await _pumpCommunity(tester, onNavigate: destinations.add);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-profile-action')),
      );
      expect(destinations, <String>['/profile']);
    });

    testWidgets('remains usable at phone width and 2x text scale', (
      tester,
    ) async {
      await _pumpCommunity(
        tester,
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      final notice = find.textContaining('尚未读取到能力清单');
      await tester.scrollUntilVisible(notice, 240);
      expect(notice, findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mining UI foundation', () {
    // The D19 placeholder this group used to assert was retired with decision
    // 0058: `mining` now reads the V2 module and renders the server's own
    // unavailable reasons. Its five states, its em-dash metrics and its
    // disabled claim live in `test/s7_mining_pages_test.dart`.
    test('Mining is a mounted V2 destination, not a placeholder', () {
      final mining = LoopRouteManifest.forModule(LoopRouteModule.mining);

      expect(mining, hasLength(6));
      expect(mining.first.slug, 'mining');
      expect(mining.first.tab, isTrue);
      expect(
        mining.every((entry) => entry.status == LoopRouteStatus.implemented),
        isTrue,
      );
    });
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pumpCommunity(
  WidgetTester tester, {
  CommunityNavigation? onNavigate,
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: ProviderScope(child: CommunityScreen(onNavigate: onNavigate)),
    ),
  );
  await tester.pumpAndSettle();
}
