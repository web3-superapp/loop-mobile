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
    // Decision 0052 adds `communityName` to the frozen key set: the banner and
    // the room title name the community from the room resource itself, so a
    // response without it is not the room this client reads.
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'voiceRoomId',
      'communityId',
      'communityName',
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
      communityName: LoopV2ProjectionCodec.requireText(map, 'communityName'),
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
    // Decision 0051 adds `joinedCount` here and `participantCount` inside
    // `observed`. Both are read as optional for the one release in which a
    // client can meet either server; a room whose counts are missing states
    // that rather than failing the whole page.
    final map = LoopV2Contract.strictMapWithOptional(
      raw,
      const <String>{'speakerCount', 'listenerCount', 'observed'},
      const <String>{'joinedCount'},
    );
    final rawObserved = map['observed'];
    if (rawObserved is! Map) _invalid();
    final status = rawObserved['status'];
    final VoiceRoomObservedParticipants observed;
    if (status == 'available') {
      final observedMap = LoopV2Contract.strictMapWithOptional(
        rawObserved,
        const <String>{'status', 'memberCount', 'observedAt'},
        const <String>{'participantCount'},
      );
      observed = VoiceRoomObservedParticipants.observed(
        memberCount: LoopV2ProjectionCodec.requireCount(
          observedMap,
          'memberCount',
        ),
        participantCount: observedMap.containsKey('participantCount')
            ? LoopV2ProjectionCodec.requireCount(
                observedMap,
                'participantCount',
              )
            : null,
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
      joinedCount: map.containsKey('joinedCount')
          ? LoopV2ProjectionCodec.requireCount(map, 'joinedCount')
          : null,
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

  static const anonymousMemberKey = 'voiceRoom.member.anonymousMember';
  static const memberDisplayRuleKey =
      'voiceRoom.member.display.anonymousModeOnly';

  static const memberPageKeys = <String>{
    'role',
    'items',
    'nextCursor',
    'display',
    'contractVersion',
  };

  /// One roster row's name, under the mining board's display rule (decision
  /// 0049): an alias with its audience, or the server's anonymous label.
  static VoiceRoomMemberName memberName(Object? raw) {
    if (raw is! Map) _invalid();
    if (raw['kind'] == 'anonymous') {
      final map = LoopV2Contract.strictMap(raw, const <String>{
        'kind',
        'labelKey',
      });
      final labelKey = map['labelKey'];
      if (labelKey != anonymousMemberKey) _invalid();
      return const VoiceRoomMemberAnonymousName(anonymousMemberKey);
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'kind',
      'alias',
      'publicProfileId',
      'audience',
    });
    if (map['kind'] != 'alias') _invalid();
    final rawAudience = map['audience'];
    if (rawAudience is! String) _invalid();
    final audience = VoiceRoomMemberAudience.tryParse(rawAudience);
    if (audience == null) _invalid();
    return VoiceRoomMemberAlias(
      alias: LoopV2ProjectionCodec.requireText(map, 'alias'),
      publicProfileId: LoopV2Contract.requiredString(
        map,
        'publicProfileId',
        pattern: LoopV2Contract.uuidPattern,
      ),
      audience: audience,
    );
  }

  /// The two server-owned display keys a roster page and the hand-raise queue
  /// are both published under (decision 0053). They are the same rule, so a
  /// response that states a different one is not this contract.
  static void requireDisplayRule(Object? raw) {
    final display = LoopV2Contract.strictMap(raw, const <String>{
      'anonymousMemberKey',
      'ruleKey',
    });
    if (display['anonymousMemberKey'] != anonymousMemberKey ||
        display['ruleKey'] != memberDisplayRuleKey) {
      _invalid();
    }
  }

  /// One row's command list, in the server's order.
  ///
  /// An unknown command is not ignored: a row whose command list this client
  /// cannot render exactly is not a row it may act on.
  static List<VoiceRoomMemberCommand> rowCommands(Object? raw) {
    final commands = <VoiceRoomMemberCommand>[];
    for (final rawCommand in LoopV2ProjectionCodec.requireList(
      raw,
      maximum: 3,
    )) {
      if (rawCommand is! String) _invalid();
      final command = VoiceRoomMemberCommand.tryParse(rawCommand);
      if (command == null || commands.contains(command)) _invalid();
      commands.add(command);
    }
    return List<VoiceRoomMemberCommand>.unmodifiable(commands);
  }

  static VoiceRoomMemberPage members(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    final rawRole = root['role'];
    if (rawRole is! String) _invalid();
    final view = VoiceRoomRosterView.tryParse(rawRole);
    if (view == null) _invalid();

    requireDisplayRule(root['display']);

    final items = <VoiceRoomMember>[];
    final seen = <String>{};
    for (final raw in LoopV2ProjectionCodec.requireList(
      root['items'],
      maximum: 100,
    )) {
      final item = LoopV2Contract.strictMap(raw, const <String>{
        'publicProfileId',
        'display',
        'role',
        'joinedAt',
        'handRaised',
        'muted',
        'isSelf',
        'commands',
      });
      final rawRowRole = item['role'];
      if (rawRowRole is! String) _invalid();
      // The cursor is bound to one view, so a row of the other role in this
      // page is not the list that was asked for.
      if (VoiceRoomRosterView.tryParse(rawRowRole) != view) _invalid();
      final commands = rowCommands(item['commands']);
      final publicProfileId = LoopV2ProjectionCodec.optionalPattern(
        item,
        'publicProfileId',
        LoopV2Contract.uuidPattern,
      );
      // A command with no target could only be run against a guess.
      if (publicProfileId == null && commands.isNotEmpty) _invalid();
      if (publicProfileId != null && !seen.add(publicProfileId)) _invalid();
      items.add(
        VoiceRoomMember(
          publicProfileId: publicProfileId,
          name: memberName(item['display']),
          view: view,
          joinedAt: LoopV2ProjectionCodec.requireTimestamp(item, 'joinedAt'),
          handRaised: LoopV2ProjectionCodec.requireBool(item, 'handRaised'),
          muted: LoopV2ProjectionCodec.requireBool(item, 'muted'),
          isSelf: LoopV2ProjectionCodec.requireBool(item, 'isSelf'),
          commands: commands,
        ),
      );
    }
    return VoiceRoomMemberPage(
      view: view,
      items: items,
      nextCursor: LoopV2ProjectionCodec.cursor(root, 'nextCursor'),
      display: const VoiceRoomMemberDisplayRule(
        anonymousMemberKey: anonymousMemberKey,
        ruleKey: memberDisplayRuleKey,
      ),
    );
  }

  static const handRaisePageKeys = <String>{
    'items',
    'display',
    'contractVersion',
  };

  /// The queue under the roster's identity projection (decision 0053).
  ///
  /// `profile` is gone: a queue row is named, addressed and acted on by
  /// exactly the rules one roster row is, so an anonymous member in the queue
  /// is as unaddressable to a plain member as it is in the roster.
  static List<VoiceRoomHandRaiseEntry> handRaises(Map<String, Object?> root) {
    LoopV2ProjectionCodec.requireContractVersion(root);
    requireDisplayRule(root['display']);
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
        'publicProfileId',
        'display',
        'isSelf',
        'commands',
      });
      final commands = rowCommands(item['commands']);
      final publicProfileId = LoopV2ProjectionCodec.optionalPattern(
        item,
        'publicProfileId',
        LoopV2Contract.uuidPattern,
      );
      // A command with no target could only be run against a guess.
      if (publicProfileId == null && commands.isNotEmpty) _invalid();
      final entry = VoiceRoomHandRaiseEntry(
        handRaise: handRaise(item),
        publicProfileId: publicProfileId,
        name: memberName(item['display']),
        isSelf: LoopV2ProjectionCodec.requireBool(item, 'isSelf'),
        commands: commands,
      );
      if (!seen.add(entry.handRaise.handRaiseId)) _invalid();
      entries.add(entry);
    }
    return List<VoiceRoomHandRaiseEntry>.unmodifiable(entries);
  }
}
