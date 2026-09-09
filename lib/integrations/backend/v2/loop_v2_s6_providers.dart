import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/approvals/loop_v2_approvals_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s6_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/swap/loop_v2_swap_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_wallet_intents_api.dart';

/// Strict V2 transports for the two S6 money-action modules. Reading a
/// provider issues no request; a missing Dio client, client metadata or
/// authenticated session keeps the feature port at its fail-closed default.
final loopV2WalletIntentsApiProvider = Provider<LoopV2WalletIntentsApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2WalletIntentsApi(dio);
});

final loopV2SwapApiProvider = Provider<LoopV2SwapApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SwapApi(dio);
});

final loopV2ApprovalsApiProvider = Provider<LoopV2ApprovalsApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2ApprovalsApi(dio);
});

final loopV2WalletIntentsGatewayProvider = Provider<WalletIntentsGateway>((
  ref,
) {
  final api = ref.watch(loopV2WalletIntentsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableWalletIntentsGateway();
  }
  return DioLoopV2WalletIntentsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2SwapQuoteGatewayProvider = Provider<SwapQuoteGateway>((ref) {
  final api = ref.watch(loopV2SwapApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableSwapQuoteGateway();
  }
  return DioLoopV2SwapQuoteGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2ApprovalsGatewayProvider = Provider<ApprovalsGateway>((ref) {
  final api = ref.watch(loopV2ApprovalsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableApprovalsGateway();
  }
  return DioLoopV2ApprovalsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});
