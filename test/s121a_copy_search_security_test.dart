// S121a · decision 0121: the device report of 2026-10-09 — search offers only
// the domains that answer, and the security page speaks the reader's words.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/community/search_controller.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

/// Development-build wording the reader must never see (decision 0121).
final RegExp _forbidden = RegExp(
  '仅开发环境|开发环境|还没有接入|还开不了|不会把|没有回退到演示数据|没有执行任何操作|'
  '域暂不可用|这一域搜不到东西|不会保存 PIN',
);

Iterable<String> _texts(WidgetTester tester) sync* {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    yield widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
}

void main() {
  loopWatchGround();

  group('search', () {
    testWidgets('offers 资产 / 社区 / 用户 and a one-line scope hint', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: FakeSearchGateway(),
      );

      final chips = tester
          .widgetList<LoopSubChip>(find.byType(LoopSubChip))
          .map((seg) => seg.label)
          .toList();
      expect(chips, <String>['资产', '社区', '用户']);
      // OKX secondary chips: the chosen one is solid dark grey, the others
      // outlined; none is Lime.
      for (final chip in tester.widgetList<Container>(
        find.descendant(
          of: find.byType(LoopSubChip),
          matching: find.byType(Container),
        ),
      )) {
        final decoration = chip.decoration as BoxDecoration?;
        if (decoration == null) continue;
        expect(decoration.color, isNot(LoopColors.lime));
        expect(
          decoration.color == LoopColors.card2 || decoration.border != null,
          isTrue,
        );
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('search-seg-users')))
            .height,
        greaterThanOrEqualTo(44),
      );
      for (final domain in <SearchDomain>[
        SearchDomain.launch,
        SearchDomain.dapps,
      ]) {
        expect(
          find.byKey(ValueKey<String>('search-seg-${domain.wireName}')),
          findsNothing,
        );
      }

      // The 「搜索范围」 card is gone; one 11px line under the field says it.
      expect(
        find.byKey(const ValueKey<String>('search-scope-notice')),
        findsNothing,
      );
      expect(find.text('搜索范围'), findsNothing);
      final hint = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('search-scope-hint')),
          matching: find.byType(Text),
        ),
      );
      expect(hint.data, '按昵称只能搜到允许被发现的账号，LOOP ID 可以精确搜索');
      expect(hint.style?.fontSize, 11);
      final field = tester.getRect(
        find.byKey(const ValueKey<String>('search-field')),
      );
      final line = tester.getRect(
        find.byKey(const ValueKey<String>('search-scope-hint')),
      );
      final firstChip = tester.getRect(
        find.byKey(const ValueKey<String>('search-seg-assets')),
      );
      expect(line.top, greaterThanOrEqualTo(field.bottom));
      expect(line.bottom, lessThanOrEqualTo(firstChip.top));

      for (final text in _texts(tester)) {
        expect(_forbidden.hasMatch(text), isFalse, reason: text);
      }
    });

    testWidgets('the switch brings Launch and DApp back', (tester) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: FakeSearchGateway(),
        overrides: <Override>[
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(searchOutboundDomainsVisible: true),
          ),
        ],
      );
      final chips = tester
          .widgetList<LoopSubChip>(find.byType(LoopSubChip))
          .map((seg) => seg.label)
          .toList();
      expect(chips, <String>['资产', '社区', '用户', 'Launch', 'DApp']);
    });

    test('the switch is off in this build', () {
      expect(LoopFeatureSwitches.searchOutboundDomainsVisible, isFalse);
      expect(visibleSearchDomains(outboundVisible: false), <SearchDomain>[
        SearchDomain.assets,
        SearchDomain.communities,
        SearchDomain.users,
      ]);
    });
  });

  group('security-setup', () {
    testWidgets('speaks the reader\'s words', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const AccountSurfaceScreen.fromId('security-setup'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('protection-setup-unavailable')),
        findsNothing,
      );
      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('security-大额交易二次验证')),
      );
      expect(row.subtitle, '超过阈值时再验一次身份 · 即将推出');
      expect(row.onTap, isNull);

      final fallback = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('security-biometric-fallback')),
          matching: find.byType(Text),
        ),
      );
      expect(fallback.style?.fontSize, 11);
      expect(fallback.maxLines, isNull);
      expect(find.byType(LoopNotice), findsNothing);

      for (final text in _texts(tester)) {
        expect(_forbidden.hasMatch(text), isFalse, reason: text);
      }

      // The page still moves on.
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('security-setup-continue')),
            )
            .onPressed,
        isNotNull,
      );
    });
  });
}
