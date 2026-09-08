import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_session.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_stream_token_repository.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// Decision 0055 moved token minting onto `POST /v2/chat/token` and
/// `POST /v2/video/token`. The V1 client stays in the repository as frozen
/// history and is no longer mounted.
final loopStreamTokenRepositoryProvider = Provider<LoopStreamTokenRepository?>((
  ref,
) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final apiKey = ref.watch(
    appConfigProvider.select((config) => config.streamApiKeyForCurrentBuild),
  );
  if (dio == null || metadata == null || apiKey.isEmpty) return null;
  return DioLoopV2StreamTokenRepository(
    dio,
    expectedApiKey: apiKey,
    clientVersion: metadata.clientVersion,
  );
});

/// One token loader for the current verified Privy principal.
///
/// Merely reading this provider performs no network or provider request.
final loopStreamTokenSessionProvider = Provider<LoopStreamTokenSession?>((ref) {
  final principalKey = ref.watch(loopBootstrapPrincipalKeyProvider);
  final bootstrapSession = ref.watch(loopBootstrapSessionProvider);
  final repository = ref.watch(loopStreamTokenRepositoryProvider);
  if (principalKey == null || bootstrapSession == null || repository == null) {
    return null;
  }

  final session = LoopStreamTokenSession(
    principalKey: principalKey,
    bootstrapSession: bootstrapSession,
    accessTokens: ref.watch(loopBackendAccessTokenSourceProvider),
    repository: repository,
  );
  ref.onDispose(session.dispose);
  return session;
});
