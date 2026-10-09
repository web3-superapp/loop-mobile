import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/meme/meme_create_screen.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/shell/loop_orientation.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';
import 'support/meme_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S123a · the navigation shell (decision 0128)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(LoopTabBar)));
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.path;

/// A tab page long enough to scroll, on the inherited primary controller.
Widget _longList(String slug) => ListView.builder(
  key: ValueKey<String>('$slug-list'),
  itemCount: 200,
  itemBuilder: (context, index) =>
      SizedBox(height: 60, child: Text('$slug row $index')),
);

/// The App's shape with list pages: five branches, one pushed page.
GoRouter _mirrorRouter() => GoRouter(
  initialLocation: '/chat',
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => LoopShell(
        location: state.uri.path,
        navigationShell: navigationShell,
        child: LoopTabSwitchFade(
          index: navigationShell.currentIndex,
          child: navigationShell,
        ),
      ),
      branches: <StatefulShellBranch>[
        for (final slug in <String>['chat', 'square', 'meme', 'intel'])
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/$slug',
                builder: (context, state) => _longList(slug),
              ),
            ],
          ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/wallet',
              builder: (context, state) => Center(
                child: Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey<String>('open-sheet'),
                    onPressed: () => unawaited(
                      showLoopSheet<void>(
                        context,
                        builder: (context) => const SizedBox(
                          key: ValueKey<String>('sheet-body'),
                          height: 200,
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

Future<GoRouter> _pumpMirror(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  _phone(tester);
  final router = _mirrorRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: LoopTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

ScrollPosition _position(WidgetTester tester, String slug) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _key('$slug-list'),
        matching: find.byType(Scrollable),
        skipOffstage: false,
      ),
    )
    .position;

/// Answers nothing: the create flow's first two steps never call it.
final class _IdleMeme implements MemeGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

LoopV2MetaSnapshot _memeOpen() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.meme)
            const LoopV2Capability(
              id: LoopV2CapabilityId.meme,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.confirmed,
                reasonCode: 'MEME_CONTRACT_OBSERVED',
              ),
            )
          else
            capability,
      ],
    ),
  );
}

Future<void> _pumpCreate(WidgetTester tester, VoidCallback onBack) =>
    pumpS7Page(
      tester,
      MemeCreateScreen(onBack: onBack),
      meta: _memeOpen(),
      wallet: FakeWalletDirectory(
        activeWalletId: memeWalletId,
        wallets: <LoopWalletAccount>[
          LoopWalletAccount(
            walletId: memeWalletId,
            address: memeWalletAddress,
            kind: LoopWalletKind.embedded,
            status: LoopWalletStatus.active,
            isActive: true,
            firstSeenAt: DateTime.utc(2026, 9),
            lastSeenAt: DateTime.utc(2026, 10, 8),
          ),
        ],
      ),
      overrides: [memeGatewayProvider.overrideWithValue(_IdleMeme())],
    );

void main() {
  loopWatchGround();

  group('B1 · each tab keeps its page', () {
    testWidgets('the App routes its five tabs through one StatefulShellRoute', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      final shell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;
      expect(
        shell.branches.map((branch) => (branch.routes.single as GoRoute).path),
        <String>['/chat', '/square', '/meme', '/intel', '/wallet'],
      );
      expect(router.configuration.routes.whereType<ShellRoute>(), isEmpty);

      // 广场 is built once: leaving it for 钱包 and coming back shows the
      // same page, not a new one.
      await tester.tap(find.widgetWithText(LoopTabItem, '广场'));
      await tester.pumpAndSettle();
      final square = tester.element(find.byType(SquareScreen));
      await tester.tap(find.widgetWithText(LoopTabItem, '钱包'));
      await tester.pumpAndSettle();
      expect(_location(router), '/wallet');
      expect(find.byType(SquareScreen), findsNothing);
      expect(
        find.byType(SquareScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'the left tab stays mounted offstage',
      );
      await tester.tap(find.widgetWithText(LoopTabItem, '广场'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(SquareScreen)), same(square));
    });

    testWidgets('scroll 广场, switch to 钱包, come back: the offset holds', (
      tester,
    ) async {
      final router = await _pumpMirror(tester);
      await tester.tap(find.widgetWithText(LoopTabItem, '广场'));
      await tester.pumpAndSettle();
      await tester.drag(_key('square-list'), const Offset(0, -900));
      await tester.pumpAndSettle();
      final offset = _position(tester, 'square').pixels;
      expect(offset, greaterThan(500));

      await tester.tap(find.widgetWithText(LoopTabItem, '钱包'));
      await tester.pumpAndSettle();
      expect(_location(router), '/wallet');
      await tester.tap(find.widgetWithText(LoopTabItem, '广场'));
      await tester.pumpAndSettle();
      expect(_location(router), '/square');
      expect(_position(tester, 'square').pixels, offset);
      expect(find.text('square row 0'), findsNothing);
    });

    testWidgets('m21 · tapping the showing tab scrolls it to the top', (
      tester,
    ) async {
      await _pumpMirror(tester);
      await tester.drag(_key('chat-list'), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(_position(tester, 'chat').pixels, greaterThan(500));

      await tester.tap(find.widgetWithText(LoopTabItem, '聊天'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = _position(tester, 'chat').pixels;
      expect(midway, greaterThan(0), reason: 'animated, not a jump');
      await tester.pumpAndSettle();
      expect(_position(tester, 'chat').pixels, 0);
    });

    testWidgets('m21 · under reduced motion the return is a jump', (
      tester,
    ) async {
      await _pumpMirror(tester, reduceMotion: true);
      await tester.drag(_key('chat-list'), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(LoopTabItem, '聊天'));
      await tester.pump();
      expect(_position(tester, 'chat').pixels, 0);
    });
  });

  group('B2 · back on a tab', () {
    testWidgets('back on 广场 goes to 聊天, not out of the App', (tester) async {
      final router = await _pumpApp(tester);
      await tester.tap(find.widgetWithText(LoopTabItem, '广场'));
      await tester.pumpAndSettle();
      expect(_location(router), '/square');

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(_location(router), '/chat');
      expect(find.byType(LoopTabBar), findsOneWidget);
    });

    testWidgets('the shell lets 聊天 close the App and holds every other tab', (
      tester,
    ) async {
      final router = await _pumpMirror(tester);
      PopScope<dynamic> scope() => tester.widget<PopScope<dynamic>>(
        find
            .ancestor(
              of: find.byType(LoopTabBar),
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .first,
      );
      expect(scope().canPop, isTrue);
      for (final path in <String>['/square', '/meme', '/intel', '/wallet']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(scope().canPop, isFalse, reason: path);
      }
    });
  });

  testWidgets('B3 · a sheet from a tab page opens over the tab bar', (
    tester,
  ) async {
    await _pumpMirror(tester);
    await tester.tap(find.widgetWithText(LoopTabItem, '钱包'));
    await tester.pumpAndSettle();
    final rootNavigator = Navigator.of(
      tester.element(find.byType(LoopTabBar)),
      rootNavigator: true,
    );
    await tester.tap(_key('open-sheet'));
    await tester.pumpAndSettle();
    expect(
      Navigator.of(tester.element(_key('sheet-body'))),
      same(rootNavigator),
    );
    // The bar is under the veil: a tap on it reaches the barrier instead.
    await tester.tap(
      find.widgetWithText(LoopTabItem, '聊天'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('chat row 0'), findsNothing);
  });

  group('M1 · 创建代币 back', () {
    testWidgets('back on step 2 returns to step 1', (tester) async {
      var left = 0;
      await _pumpCreate(tester, () => left += 1);
      await tester.enterText(_key('meme-create-name'), 'Frog');
      await tester.enterText(_key('meme-create-symbol'), 'FROG');
      await tester.pump();
      await tester.tap(_key('meme-create-next'));
      await tester.pumpAndSettle();
      expect(_key('meme-create-step-2'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_key('meme-create-step-1'), findsOneWidget);
      expect(find.text('Frog'), findsOneWidget, reason: 'nothing is cleared');
      expect(left, 0);
    });

    testWidgets('back on a typed step 1 asks 放弃创建？ first', (tester) async {
      var left = 0;
      await _pumpCreate(tester, () => left += 1);
      await tester.enterText(_key('meme-create-name'), 'Frog');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_key('meme-create-abandon-sheet'), findsOneWidget);
      expect(find.text('放弃创建？'), findsOneWidget);

      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(left, 0);
      expect(find.text('Frog'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();
      expect(left, 1);
    });

    testWidgets('an empty step 1 lets the system leave at once', (
      tester,
    ) async {
      await _pumpCreate(tester, () {});
      final scope = tester.widget<PopScope<dynamic>>(
        find
            .ancestor(
              of: _key('meme-create-screen'),
              matching: find.byWidgetPredicate((widget) => widget is PopScope),
            )
            .first,
      );
      expect(scope.canPop, isTrue);
    });
  });

  testWidgets('M5 · 进群聊 knows when the chat is the page below', (tester) async {
    const id = '11111111-2222-3333-4444-555555555555';
    final answers = <bool>[];
    Widget profile(String communityId) => Builder(
      builder: (context) => TextButton(
        key: const ValueKey<String>('ask'),
        onPressed: () =>
            answers.add(communityChatIsBelow(context, communityId)),
        child: const Text('ask'),
      ),
    );
    final router = GoRouter(
      initialLocation: '/start',
      routes: <RouteBase>[
        GoRoute(path: '/start', builder: (context, state) => const Text('s')),
        GoRoute(
          path: '/community/chat',
          builder: (context, state) => const Text('chat'),
        ),
        GoRoute(
          path: '/community/profile',
          builder: (context, state) =>
              profile(state.uri.queryParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/community/chat?id=$id'));
    await tester.pumpAndSettle();
    unawaited(router.push('/community/profile?id=$id'));
    await tester.pumpAndSettle();
    await tester.tap(_key('ask'));

    // Another community's record over the same chat is not a way back to it.
    unawaited(router.push('/community/profile?id=other'));
    await tester.pumpAndSettle();
    await tester.tap(_key('ask'));

    // Opened from 广场 (nothing under it but the start page).
    router.go('/community/profile?id=$id');
    await tester.pumpAndSettle();
    await tester.tap(_key('ask'));

    expect(answers, <bool>[true, false, false]);
  });

  testWidgets('M13 · the App is held in portrait', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await loopLockPortrait();
    final call = calls.singleWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    expect(call.arguments, <String>['DeviceOrientation.portraitUp']);
    expect(loopAppOrientations, <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    expect(
      loopChartOrientations,
      everyElement(
        isIn(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      ),
    );
  });
}
