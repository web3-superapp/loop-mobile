import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s5_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s8_gateways.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_id_source.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/meta/loop_v2_about_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/backend/v2/settings/loop_v2_settings_api.dart';
import 'package:loop_mobile/integrations/backend/v2/support/loop_v2_support_api.dart';

/// Strict V2 transports for the three S8 modules plus public `about`. Reading
/// a provider issues no request; a missing Dio client, client metadata or
/// authenticated session keeps the feature port at its fail-closed default.
final loopV2SecurityApiProvider = Provider<LoopV2SecurityApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SecurityApi(dio);
});

final loopV2SettingsApiProvider = Provider<LoopV2SettingsApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SettingsApi(dio);
});

final loopV2SupportApiProvider = Provider<LoopV2SupportApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2SupportApi(dio);
});

final loopV2AboutApiProvider = Provider<LoopV2AboutApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2AboutApi(dio);
});

/// Reads the current session id out of the session module's own journal. It is
/// principal-bound, because the journal is partitioned per Privy owner.
final loopV2SessionIdSourceProvider = Provider<LoopV2SessionIdSource?>((ref) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  if (principalKey == null) return null;
  return LoopV2SessionIdSource(
    principalKey: principalKey,
    store: ref.watch(loopV2SessionJournalStoreProvider),
  );
});

final loopV2SecurityGatewayProvider = Provider<SecurityGateway>((ref) {
  final api = ref.watch(loopV2SecurityApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  final sessionIds = ref.watch(loopV2SessionIdSourceProvider);
  if (api == null ||
      metadata == null ||
      session == null ||
      sessionIds == null) {
    return const UnavailableSecurityGateway();
  }
  return DioLoopV2SecurityGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    sessionIds: sessionIds,
  );
});

final loopV2AccountSettingsGatewayProvider = Provider<AccountSettingsGateway>((
  ref,
) {
  final api = ref.watch(loopV2SettingsApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableAccountSettingsGateway();
  }
  return DioLoopV2AccountSettingsGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

final loopV2SupportGatewayProvider = Provider<SupportGateway>((ref) {
  final api = ref.watch(loopV2SupportApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (api == null || metadata == null || session == null) {
    return const UnavailableSupportGateway();
  }
  return DioLoopV2SupportGateway(
    api: api,
    clientMetadata: metadata,
    session: session,
    originSource: ref.watch(loopV2WriteOriginSourceProvider),
  );
});

/// The `about` resource is public: it needs no session, only a backend origin.
final loopV2AboutGatewayProvider = Provider<AboutGateway>((ref) {
  final api = ref.watch(loopV2AboutApiProvider);
  if (api == null) return const UnavailableAboutGateway();
  return LoopV2AboutRepository(api);
});
