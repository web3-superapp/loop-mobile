import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

void main() {
  test(
    'selected Stream integration remains fail-closed when unconfigured',
    () async {
      const gateway = StreamCommunicationGateway.unconfigured();

      expect(gateway.isConfigured, isFalse);

      final conversations = await gateway.loadConversations();
      expect(conversations.isSuccess, isFalse);
      expect(
        conversations.failure?.code,
        CommunicationFailure.notConfigured.code,
      );

      final voiceRoom = await gateway.joinVoiceRoom(
        roomId: 'room-preview',
        microphoneMuted: true,
      );
      expect(voiceRoom.isSuccess, isFalse);
      expect(voiceRoom.failure?.code, CommunicationFailure.notConfigured.code);
    },
  );
}
