import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

/// Strict decoders for the `communication` module (loop-api decision 0032).
///
/// Every decoder goes through [LoopV2Contract.strictMap] against the frozen
/// key set, so an unknown or a missing field is an invalid payload rather than
/// a partially trusted projection.
abstract final class LoopV2CommunicationCodec {
  static final RegExp directCidPattern = RegExp(
    r'^messaging:loop_direct_[0-9a-f]{32}$',
  );
  static final RegExp groupCidPattern = RegExp(
    r'^messaging:loop_group_[0-9a-f]{32}$',
  );
  static final RegExp callCidPattern = RegExp(
    r'^audio_room:loop_voice_[0-9a-f]{32}$',
  );
  static final RegExp sequencePattern = RegExp(r'^[1-9][0-9]{0,18}$');
  static final RegExp errorCodePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  static const operationKeys = <String>{
    'operationId',
    'kind',
    'status',
    'terminal',
    'retryAfterMs',
    'result',
    'error',
    'createdAt',
    'updatedAt',
    'contractVersion',
  };

  static const snapshotKeys = <String>{
    'room',
    'viewer',
    'participants',
    'providerSync',
    'contractVersion',
  };

  static Never _invalid() => LoopV2ProjectionCodec.invalid();

  static ChatOperation operation(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    final rawKind = root['kind'];
    final rawStatus = root['status'];
    if (rawKind is! String || rawStatus is! String) _invalid();
    final kind = ChatOperationKind.tryParse(rawKind);
    final status = ChatOperationStatus.tryParse(rawStatus);
    if (kind == null || status == null) _invalid();
    final terminal = LoopV2ProjectionCodec.requireBool(root, 'terminal');
    final rawRetry = root['retryAfterMs'];
    int? retryAfterMs;
    if (rawRetry != null) {
      if (rawRetry is! int || rawRetry < 1 || rawRetry > 60000) _invalid();
      retryAfterMs = rawRetry;
    }
    // A non-terminal operation must say when to poll again; a terminal one
    // must not, so a resolved outcome can never look like a pending retry.
    if (terminal != (retryAfterMs == null)) _invalid();

    ChatDirectChannelResult? directResult;
    ChatGroupResult? groupResult;
    final rawResult = root['result'];
    if (rawResult != null) {
      if (status != ChatOperationStatus.succeeded) _invalid();
      switch (kind) {
        case ChatOperationKind.directGetOrCreate:
          final map = LoopV2Contract.strictMap(rawResult, const <String>{
            'targetPublicProfileId',
            'streamCid',
          });
          directResult = ChatDirectChannelResult(
            targetPublicProfileId: LoopV2Contract.requiredString(
              map,
              'targetPublicProfileId',
              pattern: LoopV2Contract.uuidPattern,
            ),
            streamCid: LoopV2Contract.requiredString(
              map,
              'streamCid',
              pattern: directCidPattern,
            ),
          );
        case ChatOperationKind.groupCreate:
          final map = LoopV2Contract.strictMap(rawResult, const <String>{
            'groupId',
            'name',
            'friendPublicProfileIds',
            'streamCid',
          });
          final ids = <String>[];
          for (final raw in LoopV2ProjectionCodec.requireList(
            map['friendPublicProfileIds'],
            maximum: 29,
          )) {
            if (raw is! String ||
                !LoopV2Contract.uuidPattern.hasMatch(raw) ||
                ids.contains(raw)) {
              _invalid();
            }
            ids.add(raw);
          }
          if (ids.length < 2) _invalid();
          groupResult = ChatGroupResult(
            groupId: LoopV2Contract.requiredString(
              map,
              'groupId',
              pattern: LoopV2Contract.uuidPattern,
            ),
            name: LoopV2ProjectionCodec.requireText(map, 'name'),
            friendPublicProfileIds: List<String>.unmodifiable(ids),
            streamCid: LoopV2Contract.requiredString(
              map,
              'streamCid',
              pattern: groupCidPattern,
            ),
          );
      }
    } else if (status == ChatOperationStatus.succeeded) {
      _invalid();
    }

    String? errorCode;
    final rawError = root['error'];
    if (rawError != null) {
      final map = LoopV2Contract.strictMap(rawError, const <String>{'code'});
      errorCode = LoopV2Contract.requiredString(
        map,
        'code',
        pattern: errorCodePattern,
      );
    }
    // Only the two rejecting terminal states carry an error object.
    final rejecting =
        status == ChatOperationStatus.failed ||
        status == ChatOperationStatus.operatorRequired;
    if (rejecting != (errorCode != null)) _invalid();

    // The two timestamps are shape-checked so a malformed envelope fails.
    LoopV2ProjectionCodec.requireTimestamp(root, 'createdAt');
    LoopV2ProjectionCodec.requireTimestamp(root, 'updatedAt');

    return ChatOperation(
      operationId: LoopV2Contract.requiredString(
        root,
        'operationId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      kind: kind,
      status: status,
      terminal: terminal,
      retryAfterMs: retryAfterMs,
      directResult: directResult,
      groupResult: groupResult,
      errorCode: errorCode,
    );
  }

  static VoiceRoomRecord room(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'voiceRoomId',
      'communityId',
      'callCid',
      'state',
      'provisionState',
      'backstage',
      'createdAt',
      'endedAt',
    });
    final rawState = map['state'];
    final rawProvision = map['provisionState'];
    if (rawState is! String || rawProvision is! String) _invalid();
    final state = VoiceRoomState.tryParse(rawState);
    final provisionState = VoiceRoomProvisionState.tryParse(rawProvision);
    if (state == null || provisionState == null) _invalid();
    final rawEndedAt = map['endedAt'];
    return VoiceRoomRecord(
      voiceRoomId: LoopV2Contract.requiredString(
        map,
        'voiceRoomId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      communityId: LoopV2Contract.requiredString(
        map,
        'communityId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      callCid: LoopV2Contract.requiredString(
        map,
        'callCid',
        pattern: callCidPattern,
      ),
      state: state,
      provisionState: provisionState,
      backstage: LoopV2ProjectionCodec.requireBool(map, 'backstage'),
      createdAt: LoopV2ProjectionCodec.requireTimestamp(map, 'createdAt'),
      endedAt: rawEndedAt == null
          ? null
          : LoopV2ProjectionCodec.requireTimestamp(map, 'endedAt'),
    );
  }

  static VoiceRoomHandRaise handRaise(Map<String, Object?> map) {
    final rawState = map['state'];
    if (rawState is! String) _invalid();
    final state = VoiceRoomHandRaiseState.tryParse(rawState);
    if (state == null) _invalid();
    return VoiceRoomHandRaise(
      handRaiseId: LoopV2Contract.requiredString(
        map,
        'handRaiseId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      sequence: LoopV2Contract.requiredString(
        map,
        'sequence',
        pattern: sequencePattern,
      ),
      state: state,
      createdAt: LoopV2ProjectionCodec.requireTimestamp(map, 'createdAt'),
    );
  }

  static VoiceRoomViewer viewer(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'role',
      'canInviteSpeakers',
      'canMuteAll',
      'canEndRoom',
      'handRaise',
      'expiresAt',
    });
    final rawRole = map['role'];
    VoiceRoomRole? role;
    if (rawRole != null) {
      if (rawRole is! String) _invalid();
      role = VoiceRoomRole.tryParse(rawRole);
      if (role == null) _invalid();
    }
    final rawHandRaise = map['handRaise'];
    final rawExpiresAt = map['expiresAt'];
    return VoiceRoomViewer(
      role: role,
      canInviteSpeakers: LoopV2ProjectionCodec.requireBool(
        map,
        'canInviteSpeakers',
      ),
      canMuteAll: LoopV2ProjectionCodec.requireBool(map, 'canMuteAll'),
      canEndRoom: LoopV2ProjectionCodec.requireBool(map, 'canEndRoom'),
      handRaise: rawHandRaise == null
          ? null
          : handRaise(
              LoopV2Contract.strictMap(rawHandRaise, const <String>{
                'handRaiseId',
                'sequence',
                'state',
                'createdAt',
              }),
            ),
      expiresAt: rawExpiresAt == null
          ? null
          : LoopV2ProjectionCodec.requireTimestamp(map, 'expiresAt'),
    );
  }

  static VoiceRoomParticipants participants(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'speakerCount',
      'listenerCount',
      'observed',
    });
    final rawObserved = map['observed'];
    if (rawObserved is! Map) _invalid();
    final status = rawObserved['status'];
    final VoiceRoomObservedParticipants observed;
    if (status == 'available') {
      final observedMap = LoopV2Contract.strictMap(rawObserved, const <String>{
        'status',
        'memberCount',
        'observedAt',
      });
      observed = VoiceRoomObservedParticipants.observed(
        memberCount: LoopV2ProjectionCodec.requireCount(
          observedMap,
          'memberCount',
        ),
        observedAt: LoopV2ProjectionCodec.requireTimestamp(
          observedMap,
          'observedAt',
        ),
      );
    } else {
      observed = VoiceRoomObservedParticipants.unavailable(
        LoopV2ProjectionCodec.unavailable(rawObserved),
      );
    }
    return VoiceRoomParticipants(
      speakerCount: LoopV2ProjectionCodec.requireCount(map, 'speakerCount'),
      listenerCount: LoopV2ProjectionCodec.requireCount(map, 'listenerCount'),
      observed: observed,
    );
  }

  static VoiceRoomProviderSync providerSync(Object? raw) {
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'reasonCode',
    });
    final status = map['status'];
    if (status != 'confirmed' && status != 'unconfirmed') _invalid();
    final reason = LoopV2ProjectionCodec.reasonCode(map, 'reasonCode');
    final confirmed = status == 'confirmed';
    // A confirmed write has nothing left to explain.
    if (confirmed && reason != null) _invalid();
    return VoiceRoomProviderSync(confirmed: confirmed, reason: reason);
  }

  static VoiceRoomSnapshot snapshot(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    return VoiceRoomSnapshot(
      room: room(root['room']),
      viewer: viewer(root['viewer']),
      participants: participants(root['participants']),
      providerSync: providerSync(root['providerSync']),
    );
  }

  static VoiceRoomCurrent current(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    final rawCurrent = root['current'];
    final reason = LoopV2ProjectionCodec.reasonCode(root, 'reasonCode');
    if (rawCurrent == null) {
      if (reason == null) _invalid();
      return VoiceRoomCurrent(snapshot: null, reasonCode: reason);
    }
    if (reason != null) _invalid();
    return VoiceRoomCurrent(
      snapshot: snapshot(LoopV2Contract.strictMap(rawCurrent, snapshotKeys)),
      reasonCode: null,
    );
  }

  static List<VoiceRoomHandRaiseEntry> handRaises(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    final entries = <VoiceRoomHandRaiseEntry>[];
    final seen = <String>{};
    for (final raw in LoopV2ProjectionCodec.requireList(
      root['items'],
      maximum: 50,
    )) {
      final item = LoopV2Contract.strictMap(raw, const <String>{
        'handRaiseId',
        'sequence',
        'state',
        'createdAt',
        'profile',
      });
      final entry = VoiceRoomHandRaiseEntry(
        handRaise: handRaise(item),
        profile: LoopV2ProjectionCodec.profile(item['profile']),
      );
      if (!seen.add(entry.handRaise.handRaiseId)) _invalid();
      entries.add(entry);
    }
    return List<VoiceRoomHandRaiseEntry>.unmodifiable(entries);
  }
}
