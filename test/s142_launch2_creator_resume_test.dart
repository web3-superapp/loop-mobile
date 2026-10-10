import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_models.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2_creator/loop_v2_launch2_creator_codec.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_typed_data_signer.dart';

import 'support/s7_fixtures.dart';

// ---------------------------------------------------------------------------
// S142 · MEME v2 project side resumes from the server (client decision 0142,
// loop-api decision 0120)
// ---------------------------------------------------------------------------
//
// The samples under `test/fixtures/s135-launch2-creator/` are handwritten
// from loop-api `integration/v2` 548066c (contract §2, §4, §10 and OpenAPI);
// Development was not on that commit yet, so nothing here is a capture.

const String _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const String _instanceId = '8b9f3c1e-2d4a-4f6b-9c8d-1e2f3a4b5c6d';

Map<String, Object?> _body(String name) =>
    (jsonDecode(
          File('test/fixtures/s135-launch2-creator/$name.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['body']!
        as Map<String, Object?>;

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Launch2HooksConfig _decode(Object? raw) =>
    LoopV2Launch2CreatorCodec.configEnvelope(raw, projectId: _projectId);

Launch2HooksConfig _config(String name) => _decode(_body(name));

Matcher get _invalid => throwsA(isA<LoopBackendFailure>());

void main() {
  group('hooks-config envelope (decision 0120 fields)', () {
    test('approval, newest task and lead are read', () {
      final empty = _config('hooks_config_empty');
      expect(empty.draft, isNull);
      expect(empty.approval, isNull);
      expect(empty.latestDeployment, isNull);
      expect(empty.minSaleLead, const Duration(seconds: 86400));

      final awaiting = _config('hooks_config_draft');
      expect(awaiting.approval?.status, Launch2ApprovalStatus.awaitingApproval);
      expect(awaiting.approval?.approvedAt, isNull);
      expect(awaiting.minSaleLead, const Duration(seconds: 4200));

      final approved = _config('hooks_config_approved');
      expect(approved.approval?.approved, isTrue);
      expect(approved.approval?.approvedAt, DateTime.utc(2026, 10, 10, 1));
      expect(approved.approval?.configVersion, approved.draft?.version);

      final deploying = _config('hooks_config_deploying');
      expect(
        deploying.latestDeployment?.status,
        Launch2JobStatus.awaitingExecutor,
      );
      expect(deploying.currentJob, same(deploying.latestDeployment));
    });

    test('every new key is required; null only where the schema says', () {
      for (final key in <String>[
        'approval',
        'latestDeployment',
        'minSaleLeadSeconds',
      ]) {
        final missing = _copy(_body('hooks_config_approved'))..remove(key);
        expect(() => _decode(missing), _invalid, reason: key);
      }
      final extra = _copy(_body('hooks_config_approved'))..['surprise'] = 1;
      expect(() => _decode(extra), _invalid);
      final nullLead = _copy(_body('hooks_config_empty'))
        ..['minSaleLeadSeconds'] = null;
      expect(() => _decode(nullLead), _invalid);
    });

    test('approval agrees with the draft it is about', () {
      // A draft always carries its approval state …
      final noApproval = _copy(_body('hooks_config_draft'))
        ..['approval'] = null;
      expect(() => _decode(noApproval), _invalid);
      // … no draft never does.
      final orphan = _copy(_body('hooks_config_empty'))
        ..['approval'] = <String, Object?>{
          'configVersion': 1,
          'status': 'awaiting_approval',
          'approvedAt': null,
        };
      expect(() => _decode(orphan), _invalid);
      Map<String, Object?> approval(Map<String, Object?> body) =>
          body['approval']! as Map<String, Object?>;
      final otherVersion = _copy(_body('hooks_config_approved'));
      approval(otherVersion)['configVersion'] = 2;
      expect(() => _decode(otherVersion), _invalid);
      final rejected = _copy(_body('hooks_config_approved'));
      approval(rejected)['status'] = 'rejected';
      expect(() => _decode(rejected), _invalid);
      final undated = _copy(_body('hooks_config_approved'));
      approval(undated)['approvedAt'] = null;
      expect(() => _decode(undated), _invalid);
      final dated = _copy(_body('hooks_config_draft'));
      approval(dated)['approvedAt'] = '2026-10-10T01:00:00.000Z';
      expect(() => _decode(dated), _invalid);
      final extraKey = _copy(_body('hooks_config_approved'));
      approval(extraKey)['reason'] = 'ok';
      expect(() => _decode(extraKey), _invalid);
    });

    test('the lead stays in the server range; the task is this project', () {
      for (final lead in <int>[4199, 2592001]) {
        final out = _copy(_body('hooks_config_empty'))
          ..['minSaleLeadSeconds'] = lead;
        expect(() => _decode(out), _invalid, reason: '$lead');
      }
      final foreign = _copy(_body('hooks_config_deploying'));
      (foreign['latestDeployment']! as Map<String, Object?>)['projectId'] =
          '9fa85f64-5717-4562-b3fc-2c963f66afa6';
      expect(() => _decode(foreign), _invalid);
      final loose = _copy(_body('hooks_config_deploying'));
      (loose['latestDeployment']! as Map<String, Object?>)['surprise'] = 1;
      expect(() => _decode(loose), _invalid);
    });
  });

  group('signing request · explicit EIP712Domain', () {
    Map<String, Object?> types(Map<String, Object?> body) =>
        (body['typedData']! as Map<String, Object?>)['types']!
            as Map<String, Object?>;

    test('the domain type is required, exact and in EIP-712 order', () {
      final missing = _copy(_body('hooks_signing_request'));
      types(missing).remove('EIP712Domain');
      expect(() => LoopV2Launch2CreatorCodec.signingRequest(missing), _invalid);
      final reordered = _copy(_body('hooks_signing_request'));
      final fields = types(reordered)['EIP712Domain']! as List<Object?>;
      fields.insert(0, fields.removeAt(2));
      expect(
        () => LoopV2Launch2CreatorCodec.signingRequest(reordered),
        _invalid,
      );
      final salted = _copy(_body('hooks_signing_request'));
      (types(salted)['EIP712Domain']! as List<Object?>).add(<String, Object?>{
        'name': 'salt',
        'type': 'bytes32',
      });
      expect(() => LoopV2Launch2CreatorCodec.signingRequest(salted), _invalid);
      final extraType = _copy(_body('hooks_signing_request'));
      types(extraType)['Other'] = <Object?>[];
      expect(
        () => LoopV2Launch2CreatorCodec.signingRequest(extraType),
        _invalid,
      );
    });

    test('Privy receives the server object byte for byte, domain type '
        'included; a payload without it is refused, never completed', () {
      final request = LoopV2Launch2CreatorCodec.signingRequest(
        _body('hooks_signing_request'),
      );
      final json = launch2TypedDataJson(request.typedData);
      expect(json, jsonEncode(_body('hooks_signing_request')['typedData']));
      final sent = jsonDecode(json) as Map<String, Object?>;
      expect((sent['types']! as Map<String, Object?>).keys, <String>[
        'EIP712Domain',
        'LaunchRequest',
      ]);
      final bare = _copy(_body('hooks_signing_request')['typedData']);
      (bare['types']! as Map<String, Object?>).remove('EIP712Domain');
      expect(
        () => launch2TypedDataJson(bare),
        throwsA(isA<PrivySigningException>()),
      );
    });
  });

  group('resume decision table', () {
    Launch2CreatorProject project(
      String name, {
      LaunchReviewStatus review = LaunchReviewStatus.approved,
      Launch2HooksConfig? config,
      bool listed = false,
    }) => Launch2CreatorProject(
      project: s7Project(
        projectId: _projectId,
        reviewStatus: review,
        kind: LaunchProjectKind.launch2,
      ),
      config: config ?? _config(name),
      instance: listed
          ? const Launch2InstanceRef(
              instanceId: _instanceId,
              projectId: _projectId,
              stage: 'upcoming',
            )
          : null,
    );

    Launch2HooksConfig withJob(
      String status, {
      String base = 'hooks_config_deploying',
      int jobVersion = 1,
      int draftVersion = 1,
      bool retryable = false,
    }) {
      final body = _copy(_body(base));
      final job = body['latestDeployment']! as Map<String, Object?>;
      job['status'] = status;
      job['configVersion'] = jobVersion;
      if (status == 'failed') {
        job['failure'] = <String, Object?>{
          'code': 'HOOKS_ACTIVATION_WINDOW_CLOSED',
          'retryable': retryable,
        };
      }
      (body['draft']! as Map<String, Object?>)['version'] = draftVersion;
      (body['approval']! as Map<String, Object?>)['configVersion'] =
          draftVersion;
      if (draftVersion > jobVersion) {
        body['approval'] = <String, Object?>{
          'configVersion': draftVersion,
          'status': 'awaiting_approval',
          'approvedAt': null,
        };
      }
      return _decode(body);
    }

    String go(Launch2CreatorProject value) =>
        Launch2CreatorRoute.resume(value.projectId, value.resume);

    test('each server state lands on its own page', () {
      final rows =
          <(String, Launch2CreatorProject, Launch2CreatorStatus, String)>[
            (
              'no draft',
              project('hooks_config_empty'),
              Launch2CreatorStatus.draft,
              Launch2CreatorRoute.edit(_projectId),
            ),
            (
              'draft saved, never submitted',
              project('hooks_config_draft', review: LaunchReviewStatus.draft),
              Launch2CreatorStatus.draft,
              Launch2CreatorRoute.edit(_projectId),
            ),
            (
              'awaiting approval',
              project(
                'hooks_config_draft',
                review: LaunchReviewStatus.inReview,
              ),
              Launch2CreatorStatus.awaitingApproval,
              Launch2CreatorRoute.project(_projectId),
            ),
            (
              'catalogue approved, config awaiting',
              project('hooks_config_draft'),
              Launch2CreatorStatus.awaitingApproval,
              Launch2CreatorRoute.project(_projectId),
            ),
            (
              'approved, no task',
              project('hooks_config_approved'),
              Launch2CreatorStatus.approved,
              Launch2CreatorRoute.sign(_projectId),
            ),
            (
              'task queued',
              project('hooks_config_deploying'),
              Launch2CreatorStatus.deploying,
              Launch2CreatorRoute.deployment(
                _projectId,
                '00000000-0000-4000-8000-000000000011',
              ),
            ),
            (
              'task confirmed',
              project('', config: withJob('confirmed')),
              Launch2CreatorStatus.deployed,
              Launch2CreatorRoute.deployment(
                _projectId,
                '00000000-0000-4000-8000-000000000011',
              ),
            ),
            (
              'task failed for good',
              project('', config: withJob('failed')),
              Launch2CreatorStatus.deployFailed,
              Launch2CreatorRoute.deployment(
                _projectId,
                '00000000-0000-4000-8000-000000000011',
              ),
            ),
            (
              'activated, instance listed',
              project('hooks_config_activated', listed: true),
              Launch2CreatorStatus.active,
              '/launch2/instance?id=$_instanceId',
            ),
            (
              'activated, not listed yet',
              project('hooks_config_activated'),
              Launch2CreatorStatus.active,
              Launch2CreatorRoute.project(_projectId),
            ),
            (
              'catalogue returned',
              project(
                'hooks_config_draft',
                review: LaunchReviewStatus.returned,
              ),
              Launch2CreatorStatus.rejected,
              Launch2CreatorRoute.project(_projectId),
            ),
          ];
      for (final (name, value, status, location) in rows) {
        expect(value.status, status, reason: name);
        expect(go(value), location, reason: name);
      }
    });

    test('a cancelled task, or a final failure fixed by a newer draft, no '
        'longer describes the project', () {
      final cancelled = project('', config: withJob('cancelled'));
      expect(cancelled.job, isNull);
      expect(cancelled.status, Launch2CreatorStatus.approved);

      final fixed = project(
        '',
        config: withJob('failed', jobVersion: 1, draftVersion: 2),
      );
      expect(fixed.job, isNull);
      expect(fixed.status, Launch2CreatorStatus.awaitingApproval);

      // A retryable failure is still the platform's to finish.
      final retrying = project(
        '',
        config: withJob(
          'failed',
          jobVersion: 1,
          draftVersion: 2,
          retryable: true,
        ),
      );
      expect(retrying.status, Launch2CreatorStatus.deploying);
    });
  });

  test('the earliest sale start is now + lead, up to the next minute', () {
    final now = DateTime.utc(2026, 10, 10, 8, 0, 30);
    expect(
      launch2EarliestSaleStart(now, const Duration(seconds: 4200)),
      DateTime.utc(2026, 10, 10, 9, 11),
    );
    expect(
      launch2EarliestSaleStart(
        DateTime.utc(2026, 10, 10, 8),
        const Duration(hours: 24),
      ),
      DateTime.utc(2026, 10, 11, 8),
    );
  });
}
