import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_http_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';

final hyperliquidSpotMarketRepositoryProvider =
    Provider<HyperliquidSpotMarketRepository>((ref) {
      return DioHyperliquidSpotMarketRepository(
        ref.watch(hyperliquidPublicDioProvider),
      );
    });

/// Public Testnet spot facts do not require identity or account data.
///
/// The request starts only after the user has entered a product session, but
/// remains available to explicit Preview and cached-unverified sessions. This
/// exception is read-only: private account, order, signing, and Stream paths
/// continue to require a fully verified, backend-authorized session.
final hyperliquidSpotMarketNetworkAllowedProvider = Provider<bool>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) => session.canEnterProduct),
  );
});

final hyperliquidSpotMarketsProvider =
    FutureProvider.autoDispose<HyperliquidSpotSnapshot>((ref) {
      if (!ref.watch(hyperliquidSpotMarketNetworkAllowedProvider)) {
        throw const HyperliquidMarketFailure(
          HyperliquidMarketFailureKind.restrictedSession,
        );
      }
      return ref.watch(hyperliquidSpotMarketRepositoryProvider).fetchMarkets();
    }, retry: (retryCount, error) => null);
