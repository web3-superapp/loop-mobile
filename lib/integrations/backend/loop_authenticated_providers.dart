import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';

/// One authenticated request executor for the current verified Privy owner.
/// Reading it performs no token or network request.
final loopAuthenticatedSessionProvider = Provider<LoopAuthenticatedSession?>((
  ref,
) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  final bootstrapSession = ref.watch(loopBootstrapSessionProvider);
  if (principalKey == null || bootstrapSession == null) return null;

  final session = LoopAuthenticatedSession(
    principalKey: principalKey,
    bootstrapSession: bootstrapSession,
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
  );
  ref.onDispose(session.dispose);
  return session;
});
