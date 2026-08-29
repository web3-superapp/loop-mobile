import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';

/// Retained public Testnet client for the unmounted legacy perpetual adapter.
///
/// It intentionally does not share the mounted Spot client's lifecycle.
final hyperliquidMarketDioProvider = Provider<Dio>((ref) {
  final dio = LoopDioFactory.createCredentialFreePublic(
    origin: Uri.https('api.hyperliquid-testnet.xyz', '/'),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final hyperliquidMarketRepositoryProvider =
    Provider<HyperliquidMarketRepository>((ref) {
      return DioHyperliquidMarketRepository(
        ref.watch(hyperliquidMarketDioProvider),
      );
    });

/// Cached-unverified and development-preview sessions stay offline. Public
/// Testnet reads start only after Privy reports a fully verified session.
final hyperliquidMarketNetworkAllowedProvider = Provider<bool>((ref) {
  return ref.watch(
    loopSessionProvider.select(
      (session) => session.mode == LoopSessionMode.authenticated,
    ),
  );
});

final hyperliquidMarketsProvider =
    FutureProvider.autoDispose<List<HyperliquidMarket>>(
      (ref) {
        if (!ref.watch(hyperliquidMarketNetworkAllowedProvider)) {
          throw const HyperliquidMarketFailure(
            HyperliquidMarketFailureKind.restrictedSession,
          );
        }
        return ref.watch(hyperliquidMarketRepositoryProvider).fetchMarkets();
      },
      // A refresh is explicit user intent. Avoid Riverpod's default sequence
      // of automatic retries against a public provider during an outage.
      retry: (retryCount, error) => null,
    );
