import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/social/dio_loop_group_alias_gateway.dart';

/// Production group-Alias port for the current verified Privy principal.
///
/// Backend configuration and owner/session rotation replace this adapter.
/// Reading it is lazy and performs no token, bootstrap, or HTTP request.
final loopGroupAliasGatewayProvider = Provider<GroupAliasGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || session == null) {
    return const UnavailableGroupAliasGateway();
  }
  return DioLoopGroupAliasGateway(dio: dio, session: session);
});
