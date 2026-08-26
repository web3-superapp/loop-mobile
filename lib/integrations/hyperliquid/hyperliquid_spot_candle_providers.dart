import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';

final hyperliquidSpotCandleRepositoryProvider =
    Provider<HyperliquidSpotCandleRepository>((ref) {
      return DioHyperliquidSpotCandleRepository(
        ref.watch(hyperliquidSpotMarketDioProvider),
      );
    });

/// One bounded public Testnet candle request keyed by provider coin + period.
///
/// Riverpod coalesces concurrent readers of the same key. Successful results
/// remain warm for one minute so short period switches do not repeatedly spend
/// the provider's per-60-row candle rate-limit weight. There is no polling or
/// automatic retry; refresh remains an explicit user action.
final hyperliquidSpotCandlesProvider = FutureProvider.autoDispose
    .family<HyperliquidSpotCandleSnapshot, HyperliquidSpotCandleRequest>((
      ref,
      request,
    ) async {
      if (!ref.watch(hyperliquidSpotMarketNetworkAllowedProvider)) {
        throw const HyperliquidMarketFailure(
          HyperliquidMarketFailureKind.restrictedSession,
        );
      }
      final snapshot = await ref
          .watch(hyperliquidSpotCandleRepositoryProvider)
          .fetchCandles(
            providerCoin: request.providerCoin,
            interval: request.interval,
          );
      if (ref.mounted) {
        final cacheLink = ref.keepAlive();
        final cacheTimer = Timer(const Duration(minutes: 1), cacheLink.close);
        ref.onDispose(cacheTimer.cancel);
      }
      return snapshot;
    }, retry: (retryCount, error) => null);
