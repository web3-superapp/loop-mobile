import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';

void main() {
  test('restricted sessions never request public candle history', () async {
    final repository = _FakeSpotCandleRepository();
    final container = ProviderContainer(
      overrides: [
        hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(false),
        hyperliquidSpotCandleRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(hyperliquidSpotCandlesProvider(_request).future),
      throwsA(
        isA<HyperliquidMarketFailure>().having(
          (failure) => failure.kind,
          'kind',
          HyperliquidMarketFailureKind.restrictedSession,
        ),
      ),
    );
    expect(repository.requests, isEmpty);
  });

  test(
    'equal provider coin and interval readers share one in-flight request',
    () async {
      final repository = _FakeSpotCandleRepository(waitForCompletion: true);
      final container = ProviderContainer(
        overrides: [
          hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(true),
          hyperliquidSpotCandleRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final first = container.read(
        hyperliquidSpotCandlesProvider(_request).future,
      );
      final second = container.read(
        hyperliquidSpotCandlesProvider(
          const HyperliquidSpotCandleRequest(
            providerCoin: '@1035',
            interval: HyperliquidSpotCandleInterval.fourHours,
          ),
        ).future,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.requests, <HyperliquidSpotCandleRequest>[_request]);
      repository.complete();
      expect(await first, same(await second));
    },
  );

  test('different periods remain isolated family requests', () async {
    final repository = _FakeSpotCandleRepository();
    final container = ProviderContainer(
      overrides: [
        hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(true),
        hyperliquidSpotCandleRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    const oneHour = HyperliquidSpotCandleRequest(
      providerCoin: '@1035',
      interval: HyperliquidSpotCandleInterval.oneHour,
    );

    await container.read(hyperliquidSpotCandlesProvider(_request).future);
    await container.read(hyperliquidSpotCandlesProvider(oneHour).future);

    expect(repository.requests, <HyperliquidSpotCandleRequest>[
      _request,
      oneHour,
    ]);
  });
}

const _request = HyperliquidSpotCandleRequest(
  providerCoin: '@1035',
  interval: HyperliquidSpotCandleInterval.fourHours,
);

final class _FakeSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  _FakeSpotCandleRepository({this.waitForCompletion = false});

  final bool waitForCompletion;
  final List<HyperliquidSpotCandleRequest> requests =
      <HyperliquidSpotCandleRequest>[];
  final Completer<void> _completion = Completer<void>();

  void complete() {
    if (!_completion.isCompleted) _completion.complete();
  }

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) async {
    requests.add(
      HyperliquidSpotCandleRequest(
        providerCoin: providerCoin,
        interval: interval,
      ),
    );
    if (waitForCompletion) await _completion.future;
    final now = DateTime.utc(2026, 8, 26, 12);
    return HyperliquidSpotCandleSnapshot(
      providerCoin: providerCoin,
      interval: interval,
      requestedFrom: now.subtract(interval.lookback),
      requestedUntil: now,
      receivedAt: now,
      candles: const <HyperliquidSpotCandle>[],
    );
  }
}
