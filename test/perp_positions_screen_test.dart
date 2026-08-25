import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/perp/perp_portfolio_screens.dart';
import 'package:loop_mobile/features/perp/positions/perp_positions_controller.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  testWidgets('explicit Preview is labelled and performs no private read', (
    tester,
  ) async {
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async => throw StateError('unused'),
    );

    await tester.pumpWidget(
      _app(gateway: gateway, session: _SignedOutSession.new, preview: true),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('perp-preview-positions')),
      findsOne,
    );
    expect(find.textContaining('开发预览'), findsOne);
    expect(find.text('32.4%'), findsOne);
    expect(gateway.requests, isEmpty);
  });

  testWidgets('production Positions fails closed without preview facts', (
    tester,
  ) async {
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async => throw StateError('unused'),
    );

    await tester.pumpWidget(
      _app(gateway: gateway, session: _SignedOutSession.new),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('perp-live-positions')), findsOne);
    expect(find.text('Verified Privy session required'), findsOne);
    expect(find.text('32.4%'), findsNothing);
    expect(find.text('1 preview'), findsNothing);
    expect(find.text('ETH-PERP'), findsNothing);
    expect(gateway.requests, isEmpty);
  });

  testWidgets(
    'production renders Decimal-backed positions without fixture facts',
    (tester) async {
      final now = DateTime.utc(2026, 8, 25, 10);
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) async =>
            _page(now: now, items: <PerpPosition>[_position(PerpCoin.eth)]),
      );

      await tester.pumpWidget(
        _app(
          gateway: gateway,
          session: _AuthenticatedSession.new,
          clock: () => now,
        ),
      );
      await _pumpLive(tester);

      expect(gateway.requests, <_PageRequest>[
        (limit: PerpPositionsController.initialLimit, cursor: null),
      ]);
      expect(
        find.byKey(const ValueKey<String>('perp-live-position-eth')),
        findsOne,
      );
      expect(find.text('ETH-PERP'), findsOne);
      expect(find.text('1 LOADED · FRESH'), findsOne);
      expect(find.text('+548.26 USDC'), findsOne);
      expect(find.text('+17.28%'), findsOne);
      expect(find.text('1.25 ETH'), findsOne);
      expect(find.text('4580.2 USDC'), findsOne);
      expect(find.text('4410 USDC'), findsOne);
      expect(find.text('5725.25 USDC'), findsOne);
      expect(find.text('32.4%'), findsNothing);
      expect(find.text('Mark price'), findsNothing);
      expect(find.text('Close position unavailable'), findsNothing);
      expect(find.text('View management preview'), findsNothing);
    },
  );

  testWidgets('fresh empty and retryable failure stay truthful', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 25, 10);
    var calls = 0;
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async {
        calls += 1;
        if (calls == 1) {
          throw const PerpGatewayException(
            PerpGatewayFailureKind.connection,
            requestId: '00000000-0000-4000-8000-000000000111',
          );
        }
        return _page(now: now, items: const <PerpPosition>[]);
      },
    );

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        clock: () => now,
      ),
    );
    await _pumpLive(tester);

    expect(find.text('Position projection unavailable'), findsOne);
    expect(find.textContaining('Request ID:'), findsOne);
    expect(find.text('ETH-PERP'), findsNothing);

    await tester.tap(find.text('Try again'));
    await _pumpLive(tester);

    expect(
      find.byKey(const ValueKey<String>('perp-positions-empty')),
      findsOne,
    );
    expect(find.text('No open Core Perp positions'), findsOne);
    expect(find.text('EMPTY · FRESH'), findsOne);
    expect(find.text('Projection expires'), findsOne);
  });

  testWidgets(
    'production binding failure links to Perp account without binding',
    (tester) async {
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) async =>
            throw const PerpGatewayException(
              PerpGatewayFailureKind.walletBindingRequired,
              requestId: '00000000-0000-4000-8000-000000000112',
            ),
      );

      await tester.pumpWidget(
        _app(gateway: gateway, session: _AuthenticatedSession.new),
      );
      await _pumpLive(tester);

      expect(
        find.byKey(const ValueKey<String>('perp-positions-binding-required')),
        findsOne,
      );
      expect(find.text('Review in Perp account'), findsOne);
      expect(find.textContaining('never binds automatically'), findsOne);
      expect(gateway.bindCalls, 0);
    },
  );

  testWidgets('returning from Perp account retries positions without binding', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 25, 10);
    var calls = 0;
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async {
        calls += 1;
        if (calls == 1) {
          throw const PerpGatewayException(
            PerpGatewayFailureKind.walletBindingRequired,
          );
        }
        return _page(now: now, items: <PerpPosition>[_position(PerpCoin.eth)]);
      },
    );
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const PerpPositionsScreen(),
        ),
        GoRoute(
          path: '/perp/account',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Return to positions'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          developmentPreviewEnabledProvider.overrideWithValue(false),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          perpPrivateGatewayProvider.overrideWithValue(gateway),
          perpPositionsClockProvider.overrideWithValue(() => now),
          perpPositionsExpirySchedulerProvider.overrideWithValue(
            _NeverExpiryScheduler().schedule,
          ),
        ],
        child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      ),
    );
    await _pumpLive(tester);

    await tester.tap(find.text('Review in Perp account'));
    await tester.pumpAndSettle();
    expect(find.text('Return to positions'), findsOne);
    expect(gateway.bindCalls, 0);

    await tester.tap(find.text('Return to positions'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(gateway.bindCalls, 0);
    expect(
      find.byKey(const ValueKey<String>('perp-live-position-eth')),
      findsOne,
    );
  });

  testWidgets('resume clears expired position facts', (tester) async {
    final loadedAt = DateTime.utc(2026, 8, 25, 10);
    var currentTime = loadedAt;
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async =>
          _page(now: loadedAt, items: <PerpPosition>[_position(PerpCoin.eth)]),
    );

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        clock: () => currentTime,
      ),
    );
    await _pumpLive(tester);
    expect(
      find.byKey(const ValueKey<String>('perp-live-position-eth')),
      findsOne,
    );

    currentTime = loadedAt.add(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('perp-live-position-eth')),
      findsNothing,
    );
    expect(find.text('Position projection expired'), findsOne);
    expect(find.text('+548.26 USDC'), findsNothing);
    final liveRegion = tester.widget<Semantics>(
      find.byKey(const ValueKey<String>('perp-positions-status-live-region')),
    );
    expect(liveRegion.properties.liveRegion, isTrue);
  });

  testWidgets('production D5 fails closed without an ETH fixture', (
    tester,
  ) async {
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async => throw StateError('unused'),
    );

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        screen: const PerpPositionScreen(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('perp-position-live-unavailable')),
      findsOne,
    );
    expect(find.text('Live position detail unavailable'), findsOne);
    expect(find.text('ETH-PERP'), findsNothing);
    expect(find.text('4,630.50'), findsNothing);
    expect(find.text('4.76% preview'), findsNothing);
    expect(find.text('Close position unavailable'), findsNothing);
    expect(gateway.requests, isEmpty);
  });

  testWidgets('live Positions supports narrow width and large text', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 25, 10);
    final gateway = _Gateway(
      onListPositions: ({limit, cursor}) async =>
          _page(now: now, items: <PerpPosition>[_position(PerpCoin.eth)]),
    );

    await tester.pumpWidget(
      _app(
        gateway: gateway,
        session: _AuthenticatedSession.new,
        clock: () => now,
        mediaQuery: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );
    await _pumpLive(tester);

    expect(
      find.byKey(const ValueKey<String>('perp-live-position-eth')),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLive(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Widget _app({
  required _Gateway gateway,
  required LoopSessionController Function() session,
  bool preview = false,
  Widget screen = const PerpPositionsScreen(),
  PerpPositionsClock? clock,
  MediaQueryData? mediaQuery,
}) {
  return ProviderScope(
    overrides: [
      developmentPreviewEnabledProvider.overrideWithValue(preview),
      loopSessionProvider.overrideWith(session),
      perpPrivateGatewayProvider.overrideWithValue(gateway),
      if (clock != null) perpPositionsClockProvider.overrideWithValue(clock),
      perpPositionsExpirySchedulerProvider.overrideWithValue(
        _NeverExpiryScheduler().schedule,
      ),
    ],
    child: MaterialApp(
      theme: LoopTheme.dark,
      home: mediaQuery == null
          ? screen
          : MediaQuery(data: mediaQuery, child: screen),
    ),
  );
}

typedef _PageRequest = ({int? limit, String? cursor});
typedef _ListPositions = Future<PerpPage<PerpPosition>> Function({
  int? limit,
  String? cursor,
});

final class _Gateway implements PerpPrivateGateway {
  _Gateway({required this.onListPositions});

  final _ListPositions onListPositions;
  final List<_PageRequest> requests = <_PageRequest>[];
  var bindCalls = 0;

  @override
  PerpGatewayMode get mode => PerpGatewayMode.production;

  @override
  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor}) {
    requests.add((limit: limit, cursor: cursor));
    return onListPositions(limit: limit, cursor: cursor);
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  }) {
    bindCalls += 1;
    return Future<PerpWalletBinding>.error(StateError('unexpected bind'));
  }

  @override
  Future<PerpWalletBinding> getWalletBinding() =>
      Future<PerpWalletBinding>.error(StateError('unexpected binding read'));

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  }) => Future<PerpWalletBinding>.error(StateError('unexpected unbind'));

  @override
  Future<PerpConfig> getConfig() =>
      Future<PerpConfig>.error(StateError('unexpected config'));

  @override
  Future<PerpAccount> getAccount() =>
      Future<PerpAccount>.error(StateError('unexpected account'));

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      Future<PerpPage<PerpOrder>>.error(StateError('unexpected orders'));

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      Future<PerpPage<PerpFill>>.error(StateError('unexpected fills'));

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => Future<PerpPage<PerpFundingEntry>>.error(
    StateError('unexpected funding'),
  );
}

PerpPage<PerpPosition> _page({
  required DateTime now,
  required List<PerpPosition> items,
}) {
  return PerpPage<PerpPosition>(
    items: items,
    source: PerpDataSource(
      dataset: PerpSourceDataset.positions,
      fetchedAt: now,
      expiresAt: now.add(const Duration(seconds: 2)),
    ),
    nextCursor: null,
    coverage: null,
  );
}

PerpPosition _position(PerpCoin coin) {
  return PerpPosition(
    coin: coin,
    side: PerpPositionSide.long,
    size: Decimal.parse('1.25'),
    entryPrice: Decimal.parse('4580.20'),
    leverage: PerpLeverage(
      mode: PerpLeverageMode.isolated,
      value: Decimal.fromInt(20),
      rawUsd: Decimal.parse('289.41'),
    ),
    liquidationPrice: Decimal.parse('4410.00'),
    marginUsed: Decimal.parse('289.41'),
    positionValue: Decimal.parse('5725.25'),
    returnOnEquity: Decimal.parse('0.1728'),
    unrealizedPnl: Decimal.parse('548.26'),
    positionMode: PerpPositionMode.oneWay,
  );
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(
      privyUserId: 'did:privy:user-a',
      wallet: PrivyWalletSummary(
        address: '0x1111111111111111111111111111111111111111',
      ),
    ),
  );
}

class _SignedOutSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.signedOut();
}

final class _NeverExpiryScheduler {
  PerpPositionsExpiryHandle schedule(
    Duration delay,
    void Function() callback,
  ) => const _NeverExpiryHandle();
}

final class _NeverExpiryHandle implements PerpPositionsExpiryHandle {
  const _NeverExpiryHandle();

  @override
  void cancel() {}
}
