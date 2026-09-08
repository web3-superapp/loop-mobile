import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/alerts/loop_v2_alerts_api.dart';
import 'package:loop_mobile/integrations/backend/v2/chain/loop_v2_chain_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/watchlist/loop_v2_watchlist_api.dart';

/// Strict V2 transports for the six S5 modules. Reading a provider issues no
/// request; a missing Dio client, client metadata or authenticated session
/// keeps the feature port at its fail-closed default.
final loopV2ChainApiProvider = Provider<LoopV2ChainApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2ChainApi(dio);
});

final loopV2WalletApiProvider = Provider<LoopV2WalletApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2WalletApi(dio);
});

final loopV2MarketApiProvider = Provider<LoopV2MarketApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2MarketApi(dio);
});

final loopV2WatchlistApiProvider = Provider<LoopV2WatchlistApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2WatchlistApi(dio);
});

final loopV2AlertsApiProvider = Provider<LoopV2AlertsApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2AlertsApi(dio);
});

final loopV2NotificationsApiProvider = Provider<LoopV2NotificationsApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2NotificationsApi(dio);
});

/// The optional platform/device annotation attached to S5 writes. It reuses the
/// session module's installation identity rather than minting a second one.
final loopV2WriteOriginSourceProvider = Provider<LoopV2WriteOriginSource?>((
  ref,
) {
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  if (metadata == null) return null;
  return LoopV2WriteOriginSource(
    metadata.platform,
    ref.watch(loopV2SessionJournalStoreProvider),
  );
});

final loopV2ChainGatewayProvider = Provider<ChainGateway>((ref) {
  final api = ref.watch(loopV2ChainApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableChainGateway();
  }
  return DioLoopV2ChainGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2WalletReadGatewayProvider = Provider<WalletReadGateway>((ref) {
  final api = ref.watch(loopV2WalletApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableWalletReadGateway();
  }
  return DioLoopV2WalletReadGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2MarketReadGatewayProvider = Provider<MarketReadGateway>((ref) {
  final api = ref.watch(loopV2MarketApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableMarketReadGateway();
  }
  return DioLoopV2MarketReadGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2WatchlistGatewayProvider = Provider<WatchlistGateway>((ref) {
  final api = ref.watch(loopV2WatchlistApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableWatchlistGateway();
  }
  return DioLoopV2WatchlistGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2AlertsGatewayProvider = Provider<AlertsGateway>((ref) {
  final api = ref.watch(loopV2AlertsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableAlertsGateway();
  }
  return DioLoopV2AlertsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2NotificationsGatewayProvider = Provider<NotificationsGateway>((
  ref,
) {
  final api = ref.watch(loopV2NotificationsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableNotificationsGateway();
  }
  return DioLoopV2NotificationsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
