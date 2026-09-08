import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_providers.dart';
import 'package:loop_mobile/integrations/personalization/dio_loop_personalization_gateways.dart';

/// Production Profile gateway for the current verified Privy principal.
///
/// Reading the provider is lazy. Backend, principal, or authenticated-session
/// rotation replaces the gateway without issuing a request. The production
/// path is the V2 `profile` module; [DioLoopProfileGateway] stays in the tree
/// as frozen V1 history and is no longer mounted.
final loopProfileGatewayProvider = Provider<ProfileGateway>(
  (ref) => ref.watch(loopV2ProfileGatewayProvider),
);

/// Production one-time LOOP ID activation for the current principal.
final loopProfileActivationGatewayProvider = Provider<ProfileActivationGateway>(
  (ref) => ref.watch(loopV2ProfileActivationGatewayProvider),
);

/// Production Privacy gateway for the current verified Privy principal.
///
/// V1 `/v1/profile/privacy` has no V2 counterpart for `copy_trade_visibility`
/// and is not mounted.
final loopPrivacyGatewayProvider = Provider<PrivacyGateway>(
  (ref) => ref.watch(loopV2PrivacyGatewayProvider),
);

/// Public preset avatar catalog used by `loop-id-setup` and `profile-edit`.
final loopAvatarCatalogGatewayProvider = Provider<AvatarCatalogGateway>(
  (ref) => ref.watch(loopV2AvatarCatalogGatewayProvider),
);

/// Production Social Privacy gateway for the current verified Privy principal.
final loopSocialPrivacyGatewayProvider = Provider<SocialPrivacyGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || session == null) {
    return const UnavailableSocialPrivacyGateway();
  }
  return DioLoopSocialPrivacyGateway(dio: dio, session: session);
});
