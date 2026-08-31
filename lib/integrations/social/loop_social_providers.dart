import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/social/dio_loop_social_friend_gateway.dart';
import 'package:loop_mobile/integrations/social/loop_social_repository.dart';

final loopSocialRepositoryProvider = Provider<DioLoopSocialRepository?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopSocialRepository(dio);
});

/// Production Social port for the current verified principal.
///
/// A missing backend configuration or verified principal remains fail-closed.
/// Merely reading this provider performs no network or token request.
final loopProductionFriendGatewayProvider = Provider<FriendGateway>((ref) {
  final session = ref.watch(loopAuthenticatedSessionProvider);
  final repository = ref.watch(loopSocialRepositoryProvider);
  if (session == null || repository == null) {
    return const UnavailableFriendGateway();
  }

  final gateway = DioLoopSocialFriendGateway(session, repository);
  ref.onDispose(gateway.dispose);
  return gateway;
});
