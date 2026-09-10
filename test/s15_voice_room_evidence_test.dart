import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/calls/stream_voice_room_page.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

import 'support/community_test_harness.dart';
import 'support/communication_test_harness.dart';

/// Decision 0068 gives `evidence.status` a third value. `pending` was the only
/// answer the voice-room precondition could ever have, so the page had no way
/// back: these tests pin the new `confirmed` answer, the reference that is the
/// whole of its proof, and the fact that a document which claims one without
/// the other is refused rather than read as the closest valid shape.
void main() {
  group('capabilities · voiceRooms.evidence.confirmed', () {
    test(
      'a confirmed evidence carries its reference and opens the gate',
      () async {
        final repository = DioLoopV2MetaRepository.withClient(
          _metaDio(_capabilitiesBody(reference: _reference)),
        );

        final capabilities = await repository.getCapabilities();

        final evidence = capabilities[LoopV2CapabilityId.voiceRooms].evidence;
        expect(evidence.status, LoopV2CapabilityEvidenceStatus.confirmed);
        expect(evidence.reference, _reference);
        expect(evidence.reasonCode, isNull);

        final projection = LoopCapabilityProjector.of(
          capabilities,
          LoopV2CapabilityId.voiceRooms,
        );
        expect(projection.evidencePending, isFalse);
        expect(projection.isUsable, isTrue);
      },
    );

    test('every other capability keeps the evidence it had', () async {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(reference: _reference)),
      );

      final capabilities = await repository.getCapabilities();

      for (final id in LoopV2CapabilityId.values) {
        if (id == LoopV2CapabilityId.voiceRooms) continue;
        final evidence = capabilities[id].evidence;
        expect(evidence.status, LoopV2CapabilityEvidenceStatus.pending);
        expect(evidence.reference, isNull);
      }
    });

    test('a document with no confirmed evidence parses unchanged', () async {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody()),
      );

      final capabilities = await repository.getCapabilities();

      final evidence = capabilities[LoopV2CapabilityId.voiceRooms].evidence;
      expect(evidence.status, LoopV2CapabilityEvidenceStatus.pending);
      expect(evidence.reference, isNull);
      expect(
        LoopCapabilityProjector.of(
          capabilities,
          LoopV2CapabilityId.voiceRooms,
        ).evidencePending,
        isTrue,
      );
    });

    // `confirmed` is a claim about a recorded fact; the reference is the
    // record. A confirmation without one is not a weaker confirmation, it is
    // an unsupported one.
    test('a confirmed evidence without a reference is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(confirmedWithoutReference: true)),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('a reference beside pending evidence is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(
            reference: _reference,
            status: 'pending',
            reasonCode: 'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
          ),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('a reference beside notApplicable evidence is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(reference: _reference, status: 'notApplicable'),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('a reference on any other capability is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(
            reference: _reference,
            onCapability: LoopV2CapabilityId.communityChat,
          ),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('a confirmed evidence that also names a reason is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(
          _capabilitiesBody(
            reference: _reference,
            reasonCode: 'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
          ),
        ),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('an empty reference is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(reference: '')),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('a reference of 120 characters is the accepted maximum', () async {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(reference: 'r' * 120)),
      );

      final capabilities = await repository.getCapabilities();

      expect(
        capabilities[LoopV2CapabilityId.voiceRooms].evidence.reference,
        'r' * 120,
      );
    });

    test('a reference of 121 characters is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(reference: 'r' * 121)),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('an explicit null reference is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(explicitNullReference: true)),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });

    test('an unknown evidence status is invalid', () {
      final repository = DioLoopV2MetaRepository.withClient(
        _metaDio(_capabilitiesBody(status: 'satisfied')),
      );

      expect(repository.getCapabilities(), throwsA(_invalidPayload));
    });
  });

  group('voiceroom · confirmed evidence', () {
    testWidgets('the pending page is gone and the room is read', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-evidence-pending')),
        findsNothing,
      );
      expect(find.textContaining('语音房还在验证中'), findsNothing);
      expect(voice.commands, contains('current:$testCommunityId'));
    });

    testWidgets('a read in flight keeps the loading state', (tester) async {
      final voice = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot())
        ..pending = true;
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        meta: _confirmedMeta,
        settle: false,
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('no live room stays the server answer, never a fixture', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          notLiveReasonCode: 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
        ),
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
      expect(find.text('该社区当前没有进行中的语音房。'), findsOneWidget);
    });

    testWidgets('an offline read keeps the offline state', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(failure: CommunityFailureKind.offline),
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('a refused read keeps the permission state', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          failure: CommunityFailureKind.permissionDenied,
        ),
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-permission')),
        findsOneWidget,
      );
    });

    testWidgets('an unexpected failure keeps the error state', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          failure: CommunityFailureKind.unexpected,
        ),
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
    });

    // Confirmed evidence opens the page; it does not authorize a room. The
    // locator contract is unchanged: the room the server pre-created is handed
    // to the reviewed lobby as a constructor argument, and the viewer's role
    // is still the server's answer.
    testWidgets('the pre-created room reaches the lobby unchanged', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.speaker),
        ),
        meta: _confirmedMeta,
      );

      final media = find.byKey(const ValueKey<String>('voiceroom-media'));
      await scrollToCommunitySection(tester, media);
      final lobby = tester.widget<StreamVoiceRoomPage>(
        find.byType(StreamVoiceRoomPage),
      );
      expect(lobby.target, isNotNull);
      expect(lobby.target!.roomId, 'loop_voice_$testChannelHex');
    });

    testWidgets('a listener still gets the member controls, not host ones', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.listener),
        ),
        meta: _confirmedMeta,
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-host-controls')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-raise-hand')),
        findsOneWidget,
      );
    });

    // Evidence and availability are two separate answers, and the narrower one
    // still wins.
    testWidgets('an unavailable capability still closes the page', (
      tester,
    ) async {
      final voice = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: voice,
        meta: testMetaSnapshot(
          voiceRooms: LoopV2CapabilityAvailability.unavailable,
          voiceRoomEvidence: LoopV2CapabilityEvidenceStatus.confirmed,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('voiceroom-capability-unavailable')),
        findsOneWidget,
      );
      expect(voice.commands, isEmpty);
    });
  });
}

const _reference = 'ops/stream/audio-room-role-2026-09-10';

final LoopV2MetaSnapshot _confirmedMeta = testMetaSnapshot(
  voiceRoomEvidence: LoopV2CapabilityEvidenceStatus.confirmed,
);

final Matcher _invalidPayload = isA<LoopBackendFailure>().having(
  (failure) => failure.kind,
  'kind',
  LoopBackendFailureKind.invalidPayload,
);

/// Every capability reads `pending` except the one under test, so a rule that
/// leaked to another id shows up as a parse failure rather than as a silent
/// pass.
Map<String, Object?> _capabilitiesBody({
  String? reference,
  bool confirmedWithoutReference = false,
  bool explicitNullReference = false,
  String status = 'confirmed',
  String? reasonCode,
  LoopV2CapabilityId onCapability = LoopV2CapabilityId.voiceRooms,
}) {
  final overrides =
      reference != null || confirmedWithoutReference || explicitNullReference;
  final evidence = <String, Object?>{
    'status': status,
    'reasonCode': reasonCode,
  };
  if (explicitNullReference) {
    evidence['reference'] = null;
  } else if (reference != null) {
    evidence['reference'] = reference;
  }
  return <String, Object?>{
    'contractVersion': '2.0',
    'configVersion': 'productPolicyV2.2026-09-01',
    'effectiveAt': '2026-09-01T00:00:00.000Z',
    'capabilities': <Object?>[
      for (final id in LoopV2CapabilityId.values)
        <String, Object?>{
          'capabilityId': id.wireName,
          'availability': 'available',
          'reasonCode': null,
          'evidence': id == onCapability && (overrides || status != 'confirmed')
              ? evidence
              : <String, Object?>{
                  'status': 'pending',
                  'reasonCode': 'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING',
                },
        },
    ],
  };
}

Dio _metaDio(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _StubAdapter(body);
  return dio;
}

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>['11111111-2222-4333-8444-555555555555'],
      },
    );
  }
}
