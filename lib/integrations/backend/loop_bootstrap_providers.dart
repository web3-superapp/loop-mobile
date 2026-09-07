import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

export 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';

final loopBootstrapRepositoryProvider = Provider<LoopBootstrapRepository?>((
  ref,
) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  final api = ref.watch(loopV2SessionApiProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  if (principalKey == null || api == null || metadata == null) return null;
  final repository = LoopV2BootstrapRepository(
    principalKey: principalKey,
    clientMetadata: metadata,
    api: api,
    store: ref.watch(loopV2SessionJournalStoreProvider),
  );
  ref.onDispose(repository.retire);
  return repository;
});

/// Opaque account-rotation key; never a LOOP or Stream user ID.
final loopBootstrapPrincipalKeyProvider = Provider<String?>((ref) {
  return ref.watch(
    loopSessionProvider.select((session) {
      if (!session.canUseProviderBackedFeatures) return null;
      return session.account?.privyUserId;
    }),
  );
});

/// Lazily creates one bootstrap owner for the current verified principal.
///
/// Merely reading this provider performs no token or network request.
final loopBootstrapSessionProvider = Provider<LoopBootstrapSession?>((ref) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  final repository = ref.watch(loopBootstrapRepositoryProvider);
  if (principalKey == null || repository == null) return null;

  final session = LoopBootstrapSession(
    principalKey: principalKey,
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
    repository: repository,
  );
  ref.onDispose(session.dispose);
  return session;
});

final loopBootstrapAuthorizationProvider =
    FutureProvider.autoDispose<LoopBootstrapAuthorization>((ref) async {
      final session = ref.watch(loopBootstrapSessionProvider);
      if (session == null) return LoopBootstrapAuthorization.unavailable;
      return session.authorize();
    }, retry: (retryCount, error) => null);
