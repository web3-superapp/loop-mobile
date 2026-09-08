import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/dio_loop_v2_profile_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_activation_store.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';

/// Strict V2 transport for the `profile` module. Reading it issues no request.
final loopV2ProfileApiProvider = Provider<LoopV2ProfileApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2ProfileApi(dio);
});

final loopV2ActivationJournalStoreProvider =
    Provider<LoopV2ActivationJournalStore>((ref) {
      return FlutterSecureLoopV2ActivationJournalStore(
        deviceIds: ref.watch(loopV2SessionJournalStoreProvider),
      );
    });

/// Production V2 Profile gateway for the current verified Privy principal.
final loopV2ProfileGatewayProvider = Provider<ProfileGateway>((ref) {
  final api = ref.watch(loopV2ProfileApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableProfileGateway();
  }
  return DioLoopV2ProfileGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

/// Production V2 activation gateway. It is principal-bound because the durable
/// idempotency record is stored per Privy owner partition.
final loopV2ProfileActivationGatewayProvider =
    Provider<ProfileActivationGateway>((ref) {
      final api = ref.watch(loopV2ProfileApiProvider);
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final session = ref.watch(loopAuthenticatedSessionProvider);
      final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
      if (api == null ||
          metadata == null ||
          session == null ||
          principalKey == null) {
        return const UnavailableProfileActivationGateway();
      }
      return DioLoopV2ProfileActivationGateway(
        principalKey: principalKey,
        api: api,
        clientMetadata: metadata,
        store: ref.watch(loopV2ActivationJournalStoreProvider),
        session: session,
      );
    });

/// Production V2 Privacy gateway for the current verified Privy principal.
final loopV2PrivacyGatewayProvider = Provider<PrivacyGateway>((ref) {
  final api = ref.watch(loopV2ProfileApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailablePrivacyGateway();
  }
  return DioLoopV2PrivacyGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
  );
});

/// Public preset avatar catalog. No access token is required.
final loopV2AvatarCatalogGatewayProvider = Provider<AvatarCatalogGateway>((
  ref,
) {
  final api = ref.watch(loopV2ProfileApiProvider);
  if (api == null) return const UnavailableAvatarCatalogGateway();
  return LoopV2AvatarCatalogRepository(api);
});
