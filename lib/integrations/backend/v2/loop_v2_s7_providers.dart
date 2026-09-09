import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';

/// Strict V2 transports for the three S7 modules. Reading a provider issues no
/// request; a missing Dio client, client metadata or authenticated session
/// keeps the feature port at its fail-closed default.
final loopV2LaunchApiProvider = Provider<LoopV2LaunchApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2LaunchApi(dio);
});

final loopV2MiningApiProvider = Provider<LoopV2MiningApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2MiningApi(dio);
});

final loopV2ReferralApiProvider = Provider<LoopV2ReferralApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2ReferralApi(dio);
});

final loopV2LaunchGatewayProvider = Provider<LaunchGateway>((ref) {
  final api = ref.watch(loopV2LaunchApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableLaunchGateway();
  }
  return DioLoopV2LaunchGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2MiningGatewayProvider = Provider<MiningGateway>((ref) {
  final api = ref.watch(loopV2MiningApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableMiningGateway();
  }
  return DioLoopV2MiningGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2ReferralGatewayProvider = Provider<ReferralGateway>((ref) {
  final api = ref.watch(loopV2ReferralApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableReferralGateway();
  }
  return DioLoopV2ReferralGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});
