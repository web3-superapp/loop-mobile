import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/dio_loop_v2_communication_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// Strict V2 transport for the `communication` module. Reading a provider
/// issues no request.
final loopV2CommunicationApiProvider = Provider<LoopV2CommunicationApi?>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  return dio == null ? null : DioLoopV2CommunicationApi(dio);
});

/// One adapter serves both communication ports so a single keyring owns every
/// write identity for the module.
final _loopV2CommunicationGatewayProvider =
    Provider<DioLoopV2CommunicationGateway?>((ref) {
      final api = ref.watch(loopV2CommunicationApiProvider);
      final metadata = ref.watch(loopV2ClientMetadataProvider);
      final session = ref.watch(loopAuthenticatedSessionProvider);
      if (api == null || metadata == null || session == null) return null;
      return DioLoopV2CommunicationGateway(
        api: api,
        clientMetadata: metadata,
        session: session,
      );
    });

/// Production chat gateway for the current verified principal. It stays
/// unavailable, never a fixture, while any input is absent.
final loopV2ChatGatewayProvider = Provider<ChatV2Gateway>((ref) {
  return ref.watch(_loopV2CommunicationGatewayProvider) ??
      const UnavailableChatV2Gateway();
});

final loopV2VoiceRoomGatewayProvider = Provider<VoiceRoomGateway>((ref) {
  return ref.watch(_loopV2CommunicationGatewayProvider) ??
      const UnavailableVoiceRoomGateway();
});
