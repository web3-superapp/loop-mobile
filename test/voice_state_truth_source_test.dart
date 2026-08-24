import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';

void main() {
  test('production seam never invents Stream CallState', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(voiceSessionControllerProvider.notifier).join();

    expect(
      container.read(voiceSessionControllerProvider).phase,
      VoiceConnectionPhase.idle,
    );
    expect(container.read(voiceSessionControllerProvider).room, isNull);
  });

  test('offline preview can exercise the local voice layout state', () async {
    final container = ProviderContainer(
      overrides: [
        communicationGatewayProvider.overrideWithValue(
          MemoryCommunicationGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(voiceSessionControllerProvider.notifier).join();

    expect(
      container.read(voiceSessionControllerProvider).phase,
      VoiceConnectionPhase.joined,
    );
  });
}
