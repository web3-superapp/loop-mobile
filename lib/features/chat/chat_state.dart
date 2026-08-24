import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

/// Production-safe default. Preview data must be injected at a composition root.
final communicationGatewayProvider = Provider<CommunicationGateway>(
  (ref) => const StreamCommunicationGateway.unconfigured(),
);

final conversationListProvider = FutureProvider<List<ConversationSummary>>((
  ref,
) async {
  final result = await ref
      .watch(communicationGatewayProvider)
      .loadConversations();
  if (!result.isSuccess) {
    throw CommunicationException(result.failure!);
  }
  return result.value!;
});

final conversationMessagesProvider =
    FutureProvider.family<List<ConversationMessage>, String>((ref, id) async {
      final result = await ref
          .watch(communicationGatewayProvider)
          .loadMessages(id);
      if (!result.isSuccess) {
        throw CommunicationException(result.failure!);
      }
      return result.value!;
    });

final messageRequestsProvider = FutureProvider<List<MessageRequestSummary>>((
  ref,
) async {
  final result = await ref
      .watch(communicationGatewayProvider)
      .loadMessageRequests();
  if (!result.isSuccess) {
    throw CommunicationException(result.failure!);
  }
  return result.value!;
});

class CommunicationException implements Exception {
  const CommunicationException(this.failure);

  final CommunicationFailure failure;

  @override
  String toString() => failure.message;
}

@immutable
class VoiceSessionState {
  const VoiceSessionState({
    required this.phase,
    required this.microphoneMuted,
    this.room,
    this.errorMessage,
  });

  const VoiceSessionState.idle()
    : phase = VoiceConnectionPhase.idle,
      microphoneMuted = true,
      room = null,
      errorMessage = null;

  final VoiceConnectionPhase phase;
  final bool microphoneMuted;
  final VoiceRoomSummary? room;
  final String? errorMessage;

  bool get showsMiniBar =>
      room != null &&
      (phase == VoiceConnectionPhase.joining ||
          phase == VoiceConnectionPhase.joined ||
          phase == VoiceConnectionPhase.reconnecting ||
          phase == VoiceConnectionPhase.error);

  VoiceSessionState copyWith({
    VoiceConnectionPhase? phase,
    bool? microphoneMuted,
    VoiceRoomSummary? room,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceSessionState(
      phase: phase ?? this.phase,
      microphoneMuted: microphoneMuted ?? this.microphoneMuted,
      room: room ?? this.room,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class VoiceSessionController extends Notifier<VoiceSessionState> {
  @override
  VoiceSessionState build() => const VoiceSessionState.idle();

  Future<void> join([VoiceRoomSummary room = ChatContent.voiceRoom]) async {
    final gateway = ref.read(communicationGatewayProvider);
    // Until Stream CallState is projected directly into Riverpod, this local
    // controller is strictly an offline-preview interaction model. Production
    // must not invent joining/joined/reconnecting state.
    if (gateway.mode != CommunicationMode.preview) return;
    if (state.phase == VoiceConnectionPhase.joining ||
        (state.phase == VoiceConnectionPhase.joined &&
            state.room?.id == room.id)) {
      return;
    }
    state = VoiceSessionState(
      phase: VoiceConnectionPhase.joining,
      microphoneMuted: true,
      room: room,
    );
    final result = await gateway.joinVoiceRoom(
      roomId: room.id,
      microphoneMuted: true,
    );
    if (result.isSuccess) {
      state = VoiceSessionState(
        phase: VoiceConnectionPhase.joined,
        microphoneMuted: true,
        room: result.value,
      );
      return;
    }
    state = VoiceSessionState(
      phase: VoiceConnectionPhase.error,
      microphoneMuted: true,
      room: room,
      errorMessage: result.failure!.message,
    );
  }

  Future<void> retry() async {
    final room = state.room;
    if (room == null) return;
    await join(room);
  }

  Future<void> toggleMicrophone() async {
    final gateway = ref.read(communicationGatewayProvider);
    if (gateway.mode != CommunicationMode.preview) return;
    final room = state.room;
    if (room == null || state.phase != VoiceConnectionPhase.joined) return;
    final nextMuted = !state.microphoneMuted;
    final result = await gateway.setMicrophoneMuted(
      roomId: room.id,
      muted: nextMuted,
    );
    if (result.isSuccess) {
      state = state.copyWith(microphoneMuted: nextMuted, clearError: true);
      return;
    }
    state = state.copyWith(
      phase: VoiceConnectionPhase.error,
      microphoneMuted: true,
      errorMessage: result.failure!.message,
    );
  }

  Future<void> leave() async {
    final gateway = ref.read(communicationGatewayProvider);
    if (gateway.mode != CommunicationMode.preview) return;
    final room = state.room;
    if (room != null) {
      await gateway.leaveVoiceRoom(room.id);
    }
    state = const VoiceSessionState.idle();
  }
}

final voiceSessionControllerProvider =
    NotifierProvider<VoiceSessionController, VoiceSessionState>(
      VoiceSessionController.new,
    );
