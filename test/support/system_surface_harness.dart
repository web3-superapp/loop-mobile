import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'authenticated_test_privy_gateway.dart';

/// Pumps one system surface at the 390×844 baseline (optionally at 2× text).
Future<void> pumpSystemSurface(
  WidgetTester tester,
  Widget surface, {
  double textScale = 1,
  List<Object> overrides = const <Object>[],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: LoopToastHost(child: child!),
        ),
        home: surface,
      ),
    ),
  );
  await tester.pump();
}

/// Pumps the production LoopApp with an authenticated session and returns
/// its router, positioned on Community.
Future<GoRouter> pumpProductionApp(
  WidgetTester tester, {
  // Riverpod 3 does not export its `Override` type; callers pass the
  // results of `overrideWithValue` and they are cast back here.
  List<Object> overrides = const <Object>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
        ...overrides.cast(),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(LoopTabBar)));
}

/// Opens [location] in the production app and asserts the unavailable-state
/// contract shared by every system page: the notice with [unavailableKey]
/// is shown, none of [absentClaims] is rendered, and `返回 LOOP` lands on
/// Community with the tab bar back.
Future<void> expectProductionUnavailable(
  WidgetTester tester, {
  required String location,
  required String unavailableKey,
  List<String> absentClaims = const <String>[],
}) async {
  final router = await pumpProductionApp(tester);
  router.go(location);
  await tester.pumpAndSettle();

  expect(router.routeInformationProvider.value.uri.path, location);
  await scrollPageTo(tester, find.byKey(ValueKey<String>(unavailableKey)));
  expect(find.byKey(ValueKey<String>(unavailableKey)), findsOneWidget);
  expect(find.byType(LoopTabBar), findsNothing);
  for (final claim in absentClaims) {
    expect(find.textContaining(claim), findsNothing, reason: claim);
  }
  final back = find.byKey(const ValueKey<String>('system-return'));
  await tester.ensureVisible(back);
  await tester.tap(back);
  await tester.pumpAndSettle();
  expect(router.routeInformationProvider.value.uri.path, '/community');
  expect(find.byType(LoopTabBar), findsOneWidget);
}

/// Scrolls the page's body list until [target] is built and visible. Pages
/// are lazy lists, so a finder alone cannot see rows below the fold.
Future<void> scrollPageTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pump();
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 9, 7),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}
