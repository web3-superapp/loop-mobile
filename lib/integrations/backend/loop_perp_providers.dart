import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_repository.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_session.dart';

final loopPerpRepositoryProvider = Provider<LoopPerpRepository?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopPerpRepository(dio);
});

/// Local-only owner identity for rotating the private Perp session.
///
/// The wallet address is deliberately used only as a Riverpod dependency. It
/// is never supplied to the backend repository: the backend derives and
/// verifies the embedded wallet from the authenticated Privy principal.
final _loopPerpOwnerProvider =
    Provider<({String principalKey, String wallet})?>((ref) {
      return ref.watch(
        loopSessionProvider.select((session) {
          if (!session.canUseProviderBackedFeatures) return null;
          final principalKey = session.account?.privyUserId;
          final wallet = session.account?.wallet?.address;
          if (principalKey == null ||
              principalKey.isEmpty ||
              principalKey != principalKey.trim() ||
              wallet == null ||
              wallet.isEmpty ||
              wallet != wallet.trim()) {
            return null;
          }
          return (principalKey: principalKey, wallet: wallet);
        }),
      );
    });

/// Lazily creates one private Perp request owner for the current verified
/// Privy principal and embedded wallet.
///
/// Reading this provider performs no token or network request. Principal,
/// wallet, sign-out, or backend endpoint rotation disposes the old session and
/// cancels its in-flight results.
final loopPerpSessionProvider = Provider<LoopPerpSession?>((ref) {
  final owner = ref.watch(_loopPerpOwnerProvider);
  final bootstrapSession = ref.watch(loopBootstrapSessionProvider);
  final repository = ref.watch(loopPerpRepositoryProvider);
  if (owner == null || bootstrapSession == null || repository == null) {
    return null;
  }

  // Watching [owner] above ensures wallet rotation invalidates the session;
  // only the opaque Privy principal key is needed by the session itself.
  final session = LoopPerpSession(
    principalKey: owner.principalKey,
    bootstrapSession: bootstrapSession,
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
    repository: repository,
  );
  ref.onDispose(session.dispose);
  return session;
});
