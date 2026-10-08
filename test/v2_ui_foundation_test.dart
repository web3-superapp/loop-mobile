import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

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
      expect(find.textContaining('社区还没有准备好'), findsOne);
      // A closed gate takes the whole page, so there is no folio left to put a
      // figure in — not even the em dash that stands in for one.
      expect(
        find.byKey(const ValueKey<String>('community-folio')),
        findsNothing,
      );
      expect(find.textContaining('个已加入的社区'), findsNothing);

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

    testWidgets('the retired search and message panels are gone', (
      tester,
    ) async {
      // Decision 0110: 聊天 owns conversations, requests and search, so the
      // community index no longer carries either panel or a profile button.
      await _pumpCommunity(tester);
      for (final key in <String>[
        'community-search-toggle',
        'community-message-toggle',
        'community-profile-action',
        'community-search-panel',
        'community-message-panel',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsNothing, reason: key);
      }
    });

    testWidgets('opened as a child page it offers the way back', (
      tester,
    ) async {
      var backs = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: ProviderScope(child: CommunityScreen(onBack: () => backs++)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('loop-topbar-back')));
      expect(backs, 1);
    });

    testWidgets('remains usable at phone width and 2x text scale', (
      tester,
    ) async {
      await _pumpCommunity(
        tester,
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      final notice = find.textContaining('社区还没有准备好');
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
      // Decision 0110: no longer a tab; the page stays mounted.
      expect(mining.first.tab, isFalse);
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
