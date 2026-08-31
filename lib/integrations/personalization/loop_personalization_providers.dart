import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/personalization/dio_loop_personalization_gateways.dart';

/// Production Profile gateway for the current verified Privy principal.
///
/// Reading the provider is lazy. Backend, principal, or authenticated-session
/// rotation replaces the gateway without issuing a request.
final loopProfileGatewayProvider = Provider<ProfileGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || session == null) {
    return const UnavailableProfileGateway();
  }
  return DioLoopProfileGateway(dio: dio, session: session);
});

/// Production Privacy gateway for the current verified Privy principal.
final loopPrivacyGatewayProvider = Provider<PrivacyGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || session == null) {
    return const UnavailablePrivacyGateway();
  }
  return DioLoopPrivacyGateway(dio: dio, session: session);
});

/// Production Social Privacy gateway for the current verified Privy principal.
final loopSocialPrivacyGatewayProvider = Provider<SocialPrivacyGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || session == null) {
    return const UnavailableSocialPrivacyGateway();
  }
  return DioLoopSocialPrivacyGateway(dio: dio, session: session);
});
