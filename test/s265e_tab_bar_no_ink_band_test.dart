// S265e · Tab 栏后面不再是一条黑底 (client decision 0226): on every tab with a
// wall the wall runs under the floating bar to the screen's edge, nothing
// opaque is painted over it below the bar, the bar is the card at 92 %, the
// system navigation bar is clear with no scrim, and each tab's list keeps
// the bar's height of room at its foot. A tab with no wall is unchanged.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

const Size _screen = Size(390, 844);
const double _safeBottom = 34;

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screen;
  tester.view.padding = const FakeViewPadding(bottom: _safeBottom);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(LoopTabBar)));
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 9, 2),
        markets: const <HyperliquidSpotMarket>[],
      );
}

/// The opaque fill a widget declares, if any.
Color? _fill(Widget widget) => switch (widget) {
  ColoredBox(:final color) => color,
  Material(:final color?) when widget.type != MaterialType.transparency =>
    color,
  DecoratedBox(:final BoxDecoration decoration) => decoration.color,
  Container(:final BoxDecoration? decoration) => decoration?.color,
  _ => null,
};

/// Every opaque box on screen that covers part of [band] and is neither
/// beneath [wall] (an ancestor, painted first) nor part of it.
List<String> _opaqueOver(WidgetTester tester, Element wall, Rect band) {
  final beneath = <Element>{};
  wall.visitAncestorElements((element) {
    beneath.add(element);
    return true;
  });
  // Any copy of the wall — the page's, and the one the sticky bar cuts to
  // its own box — is the wall itself.
  final walls = find
      .byType(LoopWallBackdrop, skipOffstage: false)
      .evaluate()
      .toSet();
  bool insideWall(Element element) {
    var inside = false;
    element.visitAncestorElements((ancestor) {
      if (walls.contains(ancestor)) inside = true;
      return !inside;
    });
    return inside;
  }

  final found = <String>[];
  // `find` skips what is offstage — the tabs kept in the indexed stack.
  final painted = find.byWidgetPredicate((widget) {
    final colour = _fill(widget);
    return colour != null && colour.a >= 0.9;
  });
  for (final element in painted.evaluate()) {
    if (beneath.contains(element) || insideWall(element)) continue;
    final render = element.renderObject;
    if (render is! RenderBox || !render.attached || !render.hasSize) continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    if (rect.overlaps(band) && rect.height > 1) {
      found.add('${element.widget.toStringShort()} $rect');
    }
  }
  return found;
}

void main() {
  // This file mounts the App through its own `pumpWidget`.
  loopWatchGround();

  testWidgets('聊天 / 广场 / 情报 / 钱包: the wall runs to the screen\'s edge '
      'and nothing opaque covers it below the bar', (tester) async {
    final router = await _pumpApp(tester);
    for (final (path, prefix) in <(String, String)>[
      ('/chat', 'chat'),
      ('/square', 'square'),
      ('/intel', 'intel'),
      ('/wallet', 'wallet'),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      final wall = _key('$prefix-atmo-backdrop').first;
      final wallRect = tester.getRect(wall);
      expect(wallRect.bottom, _screen.height, reason: prefix);
      expect(wallRect.left, 0, reason: prefix);
      expect(wallRect.right, _screen.width, reason: prefix);

      // The bar card, and the band from its bottom to the screen's edge (the
      // safe area) plus the strips beside it.
      final bar = tester.getRect(
        find.descendant(
          of: _key('loop-tab-bar'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                (widget.decoration as BoxDecoration?)?.color ==
                    loopTabBarGround,
          ),
        ),
      );
      final under = Rect.fromLTRB(0, bar.bottom + 1, _screen.width, 844);
      final beside = Rect.fromLTRB(0, bar.top, bar.left - 1, bar.bottom);
      final element = wall.evaluate().first;
      expect(_opaqueOver(tester, element, under), isEmpty, reason: prefix);
      expect(_opaqueOver(tester, element, beside), isEmpty, reason: prefix);

      // The page knows the bar is over its foot: the room it leaves under
      // its list is at least the bar and the safe area.
      final page = tester.element(_key('$prefix-atmo-backdrop').first);
      expect(
        MediaQuery.paddingOf(page).bottom,
        greaterThanOrEqualTo(LoopLayout.tabPageBottomReserve + _safeBottom),
        reason: prefix,
      );
    }
  });

  testWidgets('the wall\'s wash stops at Ink 45 % — the foot behind the bar '
      'is wall, not the old Ink 70 % band', (tester) async {
    await _pumpApp(tester);
    GoRouter.of(tester.element(find.byType(LoopTabBar))).go('/square');
    await tester.pumpAndSettle();
    final washes = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: _key('square-atmo-backdrop').first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).gradient)
        .whereType<LinearGradient>()
        .toList();
    expect(washes, hasLength(1));
    expect(washes.single.colors.last.a, closeTo(0.45, 0.01));
    expect(
      washes.single.colors
          .map((colour) => colour.a)
          .reduce((a, b) => a > b ? a : b),
      lessThan(0.5),
    );
  });

  testWidgets('the bar is the card at 92 %, the system navigation bar is '
      'clear with no scrim', (tester) async {
    await _pumpApp(tester);
    expect(loopTabBarGround.a, closeTo(0.92, 0.005));
    expect(loopTabBarGround.withValues(alpha: 1), LoopColors.card);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .ancestor(
            of: find.byType(LoopTabBar),
            matching: find.byWidgetPredicate(
              (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
            ),
          )
          .first,
    );
    expect(region.value.systemNavigationBarColor?.a, 0);
    expect(region.value.systemNavigationBarContrastEnforced, isFalse);
  });

  testWidgets('a tab with no wall keeps its own ground and the same room '
      'under its list', (tester) async {
    final router = await _pumpApp(tester);
    router.go('/meme');
    await tester.pumpAndSettle();
    expect(find.byType(MemeScreen), findsOneWidget);
    expect(find.byType(LoopWallBackdrop), findsNothing);
    final page = tester.element(find.byType(MemeScreen));
    expect(
      MediaQuery.paddingOf(page).bottom,
      LoopLayout.tabPageBottomReserve + _safeBottom,
    );
  });
}
