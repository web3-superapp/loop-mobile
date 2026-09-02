import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';

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
    testWidgets('stays truthful while D3 content is unavailable', (
      tester,
    ) async {
      await _pumpCommunity(tester);

      expect(find.byKey(const ValueKey<String>('community-screen')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('community-home-unavailable')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('community-index-unavailable')),
        findsOne,
      );
      expect(find.text('社区内容源待连接'), findsOne);
      expect(find.textContaining('将在后端 D3 提供真实来源'), findsOne);
      expect(find.textContaining('当前不展示社区数量'), findsOne);

      for (final inventedFact in <String>[
        '38 VERIFIED',
        '4 个社区在挖矿',
        '48,120 成员',
        '12 LIVE',
        'PEPE Community',
        'BONK Community',
        'MOONCAT',
        '3 条未读',
      ]) {
        expect(
          find.textContaining(inventedFact),
          findsNothing,
          reason: inventedFact,
        );
      }
    });

    testWidgets(
      'Community exposes implemented child flows without fixture facts',
      (tester) async {
        final destinations = <String>[];
        await _pumpCommunity(tester, onNavigate: destinations.add);

        await tester.tap(
          find.byKey(const ValueKey<String>('community-search-action')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('community-chat-action')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('community-profile-action')),
        );

        for (final (key, destination) in <(String, String)>[
          ('community-open-chat', '/chat'),
          ('community-open-friends', '/profile/friends'),
          ('community-add-friend', '/chat/friends/add'),
          ('community-create-group', '/chat/groups/create'),
        ]) {
          final finder = find.byKey(ValueKey<String>(key));
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          expect(destinations.last, destination);
        }

        expect(destinations, <String>[
          '/search',
          '/chat',
          '/profile',
          '/chat',
          '/profile/friends',
          '/chat/friends/add',
          '/chat/groups/create',
        ]);
      },
    );

    testWidgets('remains usable at phone width and 2x text scale', (
      tester,
    ) async {
      await _pumpCommunity(
        tester,
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      final notice = find.textContaining('本页没有请求或生成社区事实');
      await tester.scrollUntilVisible(notice, 240);
      expect(notice, findsOne);
      expect(tester.takeException(), isNull);
    });
  });

  group('Mining UI foundation', () {
    testWidgets('Mining stays unavailable without D19 facts', (tester) async {
      await _pumpMining(tester);

      expect(find.byKey(const ValueKey<String>('mining-screen')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('mining-unavailable')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-dependency-ledger')),
        findsOne,
      );
      expect(find.text('MINING / D19'), findsOne);
      expect(find.text('尚未开放'), findsOne);
      expect(find.textContaining('客户端不进行本地估算'), findsOne);
      expect(find.text('D10'), findsOne);
      expect(find.text('D12'), findsOne);
      expect(find.text('D18'), findsOne);
      expect(find.text('D19'), findsOne);
      expect(find.textContaining('不会在本地累计积分'), findsOne);
      expect(
        tester.widget<Text>(find.text('01')).style?.color,
        LoopColors.muted,
      );

      for (final inventedFact in <String>[
        '50,000',
        '#1,284',
        '82.4 LOOP',
        '3,912 LOOP',
        '164.8 LOOP',
        '20,000',
        '4,347',
        r'$1.84B',
      ]) {
        expect(
          find.textContaining(inventedFact),
          findsNothing,
          reason: inventedFact,
        );
      }

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('remains usable at phone width and 2x text scale', (
      tester,
    ) async {
      await _pumpMining(
        tester,
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(2),
      );

      final notice = find.textContaining('此页面不会发起请求');
      await tester.scrollUntilVisible(notice, 240);
      expect(notice, findsOne);
      expect(tester.takeException(), isNull);
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
      home: CommunityScreen(onNavigate: onNavigate),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMining(
  WidgetTester tester, {
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
      home: const MiningScreen(),
    ),
  );
  await tester.pumpAndSettle();
}
