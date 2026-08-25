import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/perp/positions/perp_positions_controller.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';

void main() {
  group('PerpPositionsController', () {
    test('production default is unavailable and performs no request', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(perpPositionsControllerProvider);
      expect(state.mode, PerpGatewayMode.unavailable);
      expect(state.phase, PerpPositionsPhase.unavailable);
      expect(state.items, isEmpty);
      expect(state.failureCode, 'perp_unavailable');

      await container.read(perpPositionsControllerProvider.notifier).load();
      expect(
        container.read(perpPositionsControllerProvider).phase,
        PerpPositionsPhase.unavailable,
      );
    });

    test('all position reads share one single-flight', () async {
      final now = DateTime.utc(2026, 8, 25, 10);
      final initialGate = Completer<PerpPage<PerpPosition>>();
      final continuationGate = Completer<PerpPage<PerpPosition>>();
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) =>
            cursor == null ? initialGate.future : continuationGate.future,
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      final first = fixture.controller.load();
      final second = fixture.controller.load();
      final refresh = fixture.controller.refresh();

      expect(identical(first, second), isTrue);
      expect(identical(first, refresh), isTrue);
      expect(gateway.requests, <_PageRequest>[
        (limit: PerpPositionsController.initialLimit, cursor: null),
      ]);
      expect(fixture.state.phase, PerpPositionsPhase.loading);

      initialGate.complete(
        _page(
          now: now,
          expiresAt: now.add(const Duration(seconds: 2)),
          items: <PerpPosition>[
            _position(PerpCoin.btc),
            _position(PerpCoin.eth),
          ],
          nextCursor: 'single-flight-cursor',
        ),
      );
      await first;

      expect(fixture.state.phase, PerpPositionsPhase.ready);
      final firstMore = fixture.controller.loadMore();
      final secondMore = fixture.controller.loadMore();
      final refreshDuringMore = fixture.controller.refresh();

      expect(identical(firstMore, secondMore), isTrue);
      expect(identical(firstMore, refreshDuringMore), isTrue);
      expect(gateway.requests, hasLength(2));

      continuationGate.complete(
        _page(
          now: now,
          expiresAt: now.add(const Duration(seconds: 2)),
          items: <PerpPosition>[_position(PerpCoin.sol)],
        ),
      );
      await firstMore;

      expect(fixture.state.items.map((item) => item.coin), <PerpCoin>[
        PerpCoin.btc,
        PerpCoin.eth,
        PerpCoin.sol,
      ]);
    });

    test(
      'initial read uses bounded limit and continuation uses cursor only',
      () async {
        final now = DateTime.utc(2026, 8, 25, 10);
        final scheduler = _FakeExpiryScheduler();
        final gateway = _Gateway(
          onListPositions: ({limit, cursor}) async {
            if (cursor == null) {
              return _page(
                now: now,
                expiresAt: now.add(const Duration(seconds: 2)),
                items: <PerpPosition>[
                  _position(PerpCoin.btc),
                  _position(PerpCoin.eth, side: PerpPositionSide.short),
                ],
                nextCursor: 'opaque-owner-cursor',
              );
            }
            return _page(
              now: now.add(const Duration(milliseconds: 250)),
              expiresAt: now.add(const Duration(seconds: 1)),
              items: <PerpPosition>[_position(PerpCoin.sol)],
            );
          },
        );
        final fixture = _fixture(gateway, now: now, scheduler: scheduler);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        await fixture.controller.loadMore();

        expect(gateway.requests, <_PageRequest>[
          (limit: PerpPositionsController.initialLimit, cursor: null),
          (limit: null, cursor: 'opaque-owner-cursor'),
        ]);
        expect(fixture.state.items.map((item) => item.coin), <PerpCoin>[
          PerpCoin.btc,
          PerpCoin.eth,
          PerpCoin.sol,
        ]);
        expect(fixture.state.pageCount, 2);
        expect(fixture.state.nextCursor, isNull);
        expect(fixture.state.expiresAt, now.add(const Duration(seconds: 1)));
        expect(scheduler.activeDelays, <Duration>[const Duration(seconds: 1)]);
      },
    );

    test('load-more timeout preserves only a fresh first page', () async {
      final now = DateTime.utc(2026, 8, 25, 10);
      var continuationCalls = 0;
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) async {
          if (cursor == null) {
            return _page(
              now: now,
              expiresAt: now.add(const Duration(seconds: 2)),
              items: <PerpPosition>[
                _position(PerpCoin.btc),
                _position(PerpCoin.eth),
              ],
              nextCursor: 'cursor-a',
            );
          }
          continuationCalls += 1;
          if (continuationCalls == 1) {
            throw const PerpGatewayException(
              PerpGatewayFailureKind.timeout,
              requestId: '00000000-0000-4000-8000-000000000091',
            );
          }
          return _page(
            now: now,
            expiresAt: now.add(const Duration(seconds: 2)),
            items: <PerpPosition>[_position(PerpCoin.sol)],
          );
        },
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      await fixture.controller.loadMore();

      expect(fixture.state.phase, PerpPositionsPhase.ready);
      expect(fixture.state.items, hasLength(2));
      expect(fixture.state.pageFailureKind, PerpGatewayFailureKind.timeout);
      expect(
        fixture.state.pageRequestId,
        '00000000-0000-4000-8000-000000000091',
      );

      await fixture.controller.loadMore();
      expect(fixture.state.items, hasLength(3));
      expect(fixture.state.pageFailureKind, isNull);
    });

    test('invalid continuation ordering clears all position facts', () async {
      final now = DateTime.utc(2026, 8, 25, 10);
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) async => cursor == null
            ? _page(
                now: now,
                expiresAt: now.add(const Duration(seconds: 2)),
                items: <PerpPosition>[
                  _position(PerpCoin.btc),
                  _position(PerpCoin.eth),
                ],
                nextCursor: 'cursor-b',
              )
            : _page(
                now: now,
                expiresAt: now.add(const Duration(seconds: 2)),
                items: <PerpPosition>[_position(PerpCoin.eth)],
              ),
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      await fixture.controller.loadMore();

      expect(fixture.state.phase, PerpPositionsPhase.failure);
      expect(fixture.state.failureKind, PerpGatewayFailureKind.invalidData);
      expect(fixture.state.items, isEmpty);
      expect(fixture.state.nextCursor, isNull);
    });

    test(
      'malformed dataset coverage and cursor pages clear all facts',
      () async {
        final now = DateTime.utc(2026, 8, 25, 10);
        final cases = <({String name, _ListPositions loader})>[
          (
            name: 'wrong dataset',
            loader: ({limit, cursor}) async => _page(
              now: now,
              expiresAt: now.add(const Duration(seconds: 2)),
              items: <PerpPosition>[_position(PerpCoin.btc)],
              dataset: PerpSourceDataset.account,
            ),
          ),
          (
            name: 'coverage on positions',
            loader: ({limit, cursor}) async => _page(
              now: now,
              expiresAt: now.add(const Duration(seconds: 2)),
              items: <PerpPosition>[_position(PerpCoin.btc)],
              coverage: PerpRecentWindowCoverage(
                kind: PerpCoverageKind.recentWindow,
                startedAt: now,
                endedAt: now,
                truncated: false,
              ),
            ),
          ),
          (
            name: 'empty page with continuation',
            loader: ({limit, cursor}) async => _page(
              now: now,
              expiresAt: now.add(const Duration(seconds: 2)),
              items: const <PerpPosition>[],
              nextCursor: 'cursor-without-progress',
            ),
          ),
          (
            name: 'repeated continuation cursor',
            loader: ({limit, cursor}) async => cursor == null
                ? _page(
                    now: now,
                    expiresAt: now.add(const Duration(seconds: 2)),
                    items: <PerpPosition>[
                      _position(PerpCoin.btc),
                      _position(PerpCoin.eth),
                    ],
                    nextCursor: 'same-cursor',
                  )
                : _page(
                    now: now,
                    expiresAt: now.add(const Duration(seconds: 2)),
                    items: <PerpPosition>[_position(PerpCoin.sol)],
                    nextCursor: 'same-cursor',
                  ),
          ),
        ];

        for (final testCase in cases) {
          final fixture = _fixture(
            _Gateway(onListPositions: testCase.loader),
            now: now,
          );
          await fixture.controller.load();
          if (fixture.state.nextCursor != null) {
            await fixture.controller.loadMore();
          }

          expect(
            fixture.state.phase,
            PerpPositionsPhase.failure,
            reason: testCase.name,
          );
          expect(
            fixture.state.failureKind,
            PerpGatewayFailureKind.invalidData,
            reason: testCase.name,
          );
          expect(fixture.state.items, isEmpty, reason: testCase.name);
          expect(fixture.state.nextCursor, isNull, reason: testCase.name);
          fixture.container.dispose();
        }
      },
    );

    test('expiry clears nonempty and empty position facts', () async {
      final loadedAt = DateTime.utc(2026, 8, 25, 10);
      for (final items in <List<PerpPosition>>[
        <PerpPosition>[_position(PerpCoin.eth)],
        const <PerpPosition>[],
      ]) {
        var currentTime = loadedAt;
        final scheduler = _FakeExpiryScheduler();
        final gateway = _Gateway(
          onListPositions: ({limit, cursor}) async => _page(
            now: loadedAt,
            expiresAt: loadedAt.add(const Duration(seconds: 2)),
            items: items,
          ),
        );
        final fixture = _fixture(
          gateway,
          now: loadedAt,
          clock: () => currentTime,
          scheduler: scheduler,
        );

        await fixture.controller.load();
        expect(fixture.state.phase, PerpPositionsPhase.ready);
        expect(fixture.state.isEmpty, items.isEmpty);

        currentTime = loadedAt.add(const Duration(seconds: 2));
        scheduler.fireNext();

        expect(fixture.state.phase, PerpPositionsPhase.stale);
        expect(fixture.state.items, isEmpty);
        expect(fixture.state.expiresAt, isNull);
        expect(fixture.state.nextCursor, isNull);
        fixture.container.dispose();
      }
    });

    test(
      'clock validation clears facts when a suspended timer never fires',
      () async {
        final loadedAt = DateTime.utc(2026, 8, 25, 10);
        var currentTime = loadedAt;
        final gateway = _Gateway(
          onListPositions: ({limit, cursor}) async => _page(
            now: loadedAt,
            expiresAt: loadedAt.add(const Duration(seconds: 2)),
            items: <PerpPosition>[_position(PerpCoin.eth)],
          ),
        );
        final fixture = _fixture(
          gateway,
          now: loadedAt,
          clock: () => currentTime,
        );
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        currentTime = loadedAt.add(const Duration(seconds: 3));
        fixture.controller.expireIfNeeded();

        expect(fixture.state.phase, PerpPositionsPhase.stale);
        expect(fixture.state.items, isEmpty);
      },
    );

    test(
      'gateway rotation retires late positions from the previous owner',
      () async {
        final now = DateTime.utc(2026, 8, 25, 10);
        final oldPage = Completer<PerpPage<PerpPosition>>();
        final oldGateway = _Gateway(
          onListPositions: ({limit, cursor}) => oldPage.future,
        );
        final newGateway = _Gateway(
          onListPositions: ({limit, cursor}) async => _page(
            now: now,
            expiresAt: now.add(const Duration(seconds: 2)),
            items: <PerpPosition>[_position(PerpCoin.sol)],
          ),
        );
        final scheduler = _FakeExpiryScheduler();
        final fixture = _fixture(oldGateway, now: now, scheduler: scheduler);
        addTearDown(fixture.container.dispose);

        final retired = fixture.controller.load();
        fixture.container.updateOverrides([
          perpPrivateGatewayProvider.overrideWithValue(newGateway),
          perpPositionsClockProvider.overrideWithValue(() => now),
          perpPositionsExpirySchedulerProvider.overrideWithValue(
            scheduler.schedule,
          ),
        ]);
        expect(fixture.state.phase, PerpPositionsPhase.initial);

        await fixture.controller.load();
        expect(fixture.state.items.single.coin, PerpCoin.sol);

        oldPage.complete(
          _page(
            now: now,
            expiresAt: now.add(const Duration(seconds: 2)),
            items: <PerpPosition>[_position(PerpCoin.btc)],
          ),
        );
        await retired;

        expect(fixture.state.phase, PerpPositionsPhase.ready);
        expect(fixture.state.items.single.coin, PerpCoin.sol);
      },
    );

    test('expiry during load-more retires its late result', () async {
      final loadedAt = DateTime.utc(2026, 8, 25, 10);
      var currentTime = loadedAt;
      final continuation = Completer<PerpPage<PerpPosition>>();
      final gateway = _Gateway(
        onListPositions: ({limit, cursor}) async {
          if (cursor != null) return continuation.future;
          return _page(
            now: loadedAt,
            expiresAt: loadedAt.add(const Duration(seconds: 2)),
            items: <PerpPosition>[
              _position(PerpCoin.btc),
              _position(PerpCoin.eth),
            ],
            nextCursor: 'cursor-c',
          );
        },
      );
      final fixture = _fixture(
        gateway,
        now: loadedAt,
        clock: () => currentTime,
      );
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      final loadingMore = fixture.controller.loadMore();
      currentTime = loadedAt.add(const Duration(seconds: 3));
      fixture.controller.expireIfNeeded();
      continuation.complete(
        _page(
          now: currentTime,
          expiresAt: currentTime.add(const Duration(seconds: 2)),
          items: <PerpPosition>[_position(PerpCoin.sol)],
        ),
      );
      await loadingMore;

      expect(fixture.state.phase, PerpPositionsPhase.stale);
      expect(fixture.state.items, isEmpty);
    });

    test(
      'expired load-more releases single-flight for a fresh initial read',
      () async {
        final loadedAt = DateTime.utc(2026, 8, 25, 10);
        var currentTime = loadedAt;
        var initialCalls = 0;
        final continuation = Completer<PerpPage<PerpPosition>>();
        final gateway = _Gateway(
          onListPositions: ({limit, cursor}) async {
            if (cursor != null) return continuation.future;
            initialCalls += 1;
            if (initialCalls == 1) {
              return _page(
                now: loadedAt,
                expiresAt: loadedAt.add(const Duration(seconds: 2)),
                items: <PerpPosition>[
                  _position(PerpCoin.btc),
                  _position(PerpCoin.eth),
                ],
                nextCursor: 'retired-cursor',
              );
            }
            return _page(
              now: currentTime,
              expiresAt: currentTime.add(const Duration(seconds: 2)),
              items: <PerpPosition>[_position(PerpCoin.sol)],
            );
          },
        );
        final fixture = _fixture(
          gateway,
          now: loadedAt,
          clock: () => currentTime,
        );
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        final retiredLoadMore = fixture.controller.loadMore();
        currentTime = loadedAt.add(const Duration(seconds: 3));
        fixture.controller.expireIfNeeded();

        final freshRead = fixture.controller.refresh();
        await freshRead;

        expect(initialCalls, 2);
        expect(fixture.state.phase, PerpPositionsPhase.ready);
        expect(fixture.state.items.single.coin, PerpCoin.sol);

        continuation.complete(
          _page(
            now: currentTime,
            expiresAt: currentTime.add(const Duration(seconds: 2)),
            items: <PerpPosition>[_position(PerpCoin.sol)],
          ),
        );
        await retiredLoadMore;

        expect(fixture.state.phase, PerpPositionsPhase.ready);
        expect(fixture.state.items.single.coin, PerpCoin.sol);
      },
    );

    test(
      'wallet binding rejection never attempts a binding mutation',
      () async {
        final gateway = _Gateway(
          onListPositions: ({limit, cursor}) async =>
              throw const PerpGatewayException(
                PerpGatewayFailureKind.walletBindingRequired,
                requestId: '00000000-0000-4000-8000-000000000099',
              ),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();

        expect(fixture.state.phase, PerpPositionsPhase.bindingRequired);
        expect(fixture.state.items, isEmpty);
        expect(gateway.bindCalls, 0);
        expect(gateway.requests, hasLength(1));
      },
    );
  });
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
      Future<PerpConfig>.error(StateError('unexpected config read'));

  @override
  Future<PerpAccount> getAccount() =>
      Future<PerpAccount>.error(StateError('unexpected account read'));

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      Future<PerpPage<PerpOrder>>.error(StateError('unexpected orders read'));

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      Future<PerpPage<PerpFill>>.error(StateError('unexpected fills read'));

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => Future<PerpPage<PerpFundingEntry>>.error(
    StateError('unexpected funding read'),
  );
}

final class _Fixture {
  const _Fixture(this.container);

  final ProviderContainer container;

  PerpPositionsController get controller =>
      container.read(perpPositionsControllerProvider.notifier);

  PerpPositionsState get state =>
      container.read(perpPositionsControllerProvider);
}

_Fixture _fixture(
  PerpPrivateGateway gateway, {
  DateTime? now,
  PerpPositionsClock? clock,
  _FakeExpiryScheduler? scheduler,
}) {
  final fixedNow = now ?? DateTime.utc(2026, 8, 25, 10);
  final expiryScheduler = scheduler ?? _FakeExpiryScheduler();
  return _Fixture(
    ProviderContainer(
      overrides: [
        perpPrivateGatewayProvider.overrideWithValue(gateway),
        perpPositionsClockProvider.overrideWithValue(clock ?? () => fixedNow),
        perpPositionsExpirySchedulerProvider.overrideWithValue(
          expiryScheduler.schedule,
        ),
      ],
    ),
  );
}

PerpPage<PerpPosition> _page({
  required DateTime now,
  required DateTime expiresAt,
  required List<PerpPosition> items,
  String? nextCursor,
  PerpSourceDataset dataset = PerpSourceDataset.positions,
  PerpRecentWindowCoverage? coverage,
}) {
  return PerpPage<PerpPosition>(
    items: items,
    source: PerpDataSource(
      dataset: dataset,
      fetchedAt: now,
      expiresAt: expiresAt,
    ),
    nextCursor: nextCursor,
    coverage: coverage,
  );
}

PerpPosition _position(
  PerpCoin coin, {
  PerpPositionSide side = PerpPositionSide.long,
}) {
  return PerpPosition(
    coin: coin,
    side: side,
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

final class _FakeExpiryScheduler {
  final List<_FakeExpiryHandle> _handles = <_FakeExpiryHandle>[];

  PerpPositionsExpiryHandle schedule(Duration delay, void Function() callback) {
    final handle = _FakeExpiryHandle(delay, callback);
    _handles.add(handle);
    return handle;
  }

  List<Duration> get activeDelays => _handles
      .where((handle) => !handle.isCancelled && !handle.hasFired)
      .map((handle) => handle.delay)
      .toList(growable: false);

  void fireNext() {
    final handle = _handles.firstWhere(
      (candidate) => !candidate.isCancelled && !candidate.hasFired,
    );
    handle.fire();
  }
}

final class _FakeExpiryHandle implements PerpPositionsExpiryHandle {
  _FakeExpiryHandle(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool isCancelled = false;
  bool hasFired = false;

  void fire() {
    if (isCancelled || hasFired) return;
    hasFired = true;
    _callback();
  }

  @override
  void cancel() => isCancelled = true;
}
