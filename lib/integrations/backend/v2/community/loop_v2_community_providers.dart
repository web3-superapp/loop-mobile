import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/search/dio_loop_v2_search_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';
import 'package:loop_mobile/integrations/backend/v2/social/dio_loop_v2_social_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_social_api.dart';

/// Strict V2 transports for the `community` and `search` modules. Reading a
/// provider issues no request.
final loopV2CommunityApiProvider = Provider<LoopV2CommunityApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2CommunityApi(dio);
});

final loopV2SocialApiProvider = Provider<LoopV2SocialApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SocialApi(dio);
});

final loopV2SearchApiProvider = Provider<LoopV2SearchApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SearchApi(dio);
});

/// Production `community` gateway for the current verified Privy principal.
/// It stays unavailable, never a fixture, while any input is absent.
final loopV2CommunityGatewayProvider = Provider<CommunityGateway>((ref) {
  final api = ref.watch(loopV2CommunityApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableCommunityGateway();
  }
  return DioLoopV2CommunityGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2SocialGatewayProvider = Provider<SocialGateway>((ref) {
  final api = ref.watch(loopV2SocialApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableSocialGateway();
  }
  return DioLoopV2SocialGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

final loopV2SearchGatewayProvider = Provider<SearchGateway>((ref) {
  final api = ref.watch(loopV2SearchApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableSearchGateway();
  }
  return DioLoopV2SearchGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});
