import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_manage_screen.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

// S302: loop-api decision 0182 「一币一社区」 answers create, profile edit and
// resubmit with `409 COMMUNITY_BOUND_ASSET_TAKEN` when the token is already
// bound by another community that was not rejected.

const _requestId = '3f2b8c1e-5d4a-4b6f-9a1c-2e7d8f0a1b2c';
const _code = 'COMMUNITY_BOUND_ASSET_TAKEN';

DioException _taken({Object? communityId}) {
  final options = RequestOptions(path: '/v2/communities');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: 409,
      data: <String, Object?>{
        'code': _code,
        'category': 'conflict',
        'retryable': false,
        'userMessageKey': 'errors.community.boundAssetTaken',
        'correlationId': _requestId,
        'detailsSafe': <String, Object?>{'communityId': communityId},
        'providerReferenceSafe': null,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': const <String>['no-store'],
        'x-request-id': const <String>[_requestId],
      }),
    ),
  );
}

void main() {
  group('COMMUNITY_BOUND_ASSET_TAKEN mapping', () {
    for (final communityId in <Object?>[
      '7c1d2e3f-4a5b-4c6d-8e9f-0a1b2c3d4e5f',
      null,
    ]) {
      test('decodes as a refusal (communityId: $communityId)', () {
        final failure = LoopV2Contract.mapDioFailure(
          _taken(communityId: communityId),
          allowedCodes: LoopV2ModuleRequest.communityBoundAssetWriteErrors,
        );
        expect(failure.kind, LoopBackendFailureKind.invalidRequest);
        expect(failure.code, _code);
        expect(failure.statusCode, 409);
        expect(
          communityFailureKindForV2(failure, write: true),
          CommunityFailureKind.boundAssetTaken,
        );
        expect(
          communityFailureKindForV2(failure, write: false),
          CommunityFailureKind.boundAssetTaken,
        );
      });
    }

    test('the bound-asset table extends the write catalogue by one code', () {
      const table = LoopV2ModuleRequest.communityBoundAssetWriteErrors;
      const base = LoopV2ModuleRequest.writeErrors;
      expect(table.keys.toSet(), base.keys.toSet());
      for (final status in base.keys) {
        final extra = table[status]!.difference(base[status]!);
        expect(
          extra,
          status == 409 ? <String>{_code} : <String>{},
          reason: '$status',
        );
        expect(base[status]!.difference(table[status]!), isEmpty);
      }
    });

    test('a route without the code still never crashes (old-build path)', () {
      // A build that predates the code reads it as an unlisted answer: an
      // unparseable payload, i.e. an unresolved write — not an exception.
      final failure = LoopV2Contract.mapDioFailure(
        _taken(communityId: null),
        allowedCodes: LoopV2ModuleRequest.writeErrors,
      );
      expect(failure.kind, LoopBackendFailureKind.invalidPayload);
      expect(
        communityFailureKindForV2(failure, write: true),
        CommunityFailureKind.outcomeUnknown,
      );
      // And an unknown code that did slip through falls to the kind switch.
      expect(
        communityFailureKindForV2(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidRequest,
            code: 'SOME_FUTURE_CODE',
          ),
          write: true,
        ),
        CommunityFailureKind.unexpected,
      );
    });
  });

  group('COMMUNITY_BOUND_ASSET_TAKEN copy', () {
    test('create, edit and resubmit each say it in one sentence', () {
      expect(
        communityApplyFailureReason(CommunityFailureKind.boundAssetTaken),
        '这个代币已被其他社区绑定，请换一个代币再提交。',
      );
      expect(
        communityProfileEditFailureText(
          const CommunityGatewayException(CommunityFailureKind.boundAssetTaken),
        ),
        '这个代币已被其他社区绑定，请换一个代币；资料没有修改。',
      );
      expect(
        communityResubmitFailureText(CommunityFailureKind.boundAssetTaken),
        '这个代币已被其他社区绑定，请先在资料里换一个代币再重新提交。',
      );
      expect(
        communityFailureReason(CommunityFailureKind.boundAssetTaken),
        '这个代币已被其他社区绑定，请换一个代币。',
      );
    });

    test('no sentence ever carries a community id', () {
      final uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}');
      for (final text in <String>[
        communityApplyFailureReason(CommunityFailureKind.boundAssetTaken),
        communityProfileEditFailureText(
          const CommunityGatewayException(CommunityFailureKind.boundAssetTaken),
        ),
        communityResubmitFailureText(CommunityFailureKind.boundAssetTaken),
      ]) {
        expect(uuid.hasMatch(text), isFalse);
      }
    });

    test('resubmit keeps its stale wording and the shared fallback', () {
      expect(
        communityResubmitFailureText(CommunityFailureKind.stale),
        '这份申请已经不是「已驳回」了，页面已刷新，请查看最新状态。',
      );
      expect(
        communityResubmitFailureText(CommunityFailureKind.unavailable),
        communityFailureReason(CommunityFailureKind.unavailable),
      );
    });
  });
}
