import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/group_rename.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_providers.dart';

/// `PATCH /v2/chat/groups/{groupId}` (S109b-api, decision 0113).
///
/// Body `{ name }`; bearer, `Idempotency-Key` and the contract version;
/// creator only. `200` answers the group resource
/// `{ groupId, name, nameVersion, updatedAt, contractVersion }`, and nothing
/// else is a confirmed rename.
final class DioLoopV2GroupProfileApi {
  DioLoopV2GroupProfileApi(this._dio);

  static const groupsPath = '/v2/chat/groups';

  static const writeErrors = <int, Set<String>>{
    ...LoopV2ModuleRequest.writeErrors,
    429: <String>{'RATE_LIMITED'},
  };

  final Dio _dio;

  Future<GroupRenamed> renameGroup({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String groupId,
    required String name,
  }) async {
    if (!LoopV2Contract.uuidPattern.hasMatch(groupId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.patch<Object?>(
        '$groupsPath/$groupId',
        data: <String, Object?>{'name': name},
        options: LoopV2ModuleRequest.writeOptions(
          accessToken,
          clientVersion,
          idempotencyKey,
          hasBody: true,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'groupId',
        'name',
        'nameVersion',
        'updatedAt',
        'contractVersion',
      });
      LoopV2ProjectionCodec.requireContractVersion(root);
      final renamed = GroupRenamed(
        groupId: LoopV2Contract.requiredString(
          root,
          'groupId',
          pattern: LoopV2Contract.uuidPattern,
        ),
        name: LoopV2ProjectionCodec.requireText(root, 'name'),
        nameVersion: LoopV2ProjectionCodec.requireCount(root, 'nameVersion'),
        updatedAt: LoopV2ProjectionCodec.requireTimestamp(root, 'updatedAt'),
      );
      // The server answers for the group it was asked about. The name it
      // returns is the name now in force — it may have normalised what it
      // was sent — so it is adopted as given rather than compared.
      if (renamed.groupId != groupId || renamed.nameVersion < 1) {
        LoopV2ProjectionCodec.invalid();
      }
      return renamed;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: writeErrors);
    }
  }
}

/// Authenticated adapter for [GroupProfileGateway].
///
/// Failures are classified by [groupRenameFailureKind].
final class DioLoopV2GroupProfileGateway implements GroupProfileGateway {
  DioLoopV2GroupProfileGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final DioLoopV2GroupProfileApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2CommandKeyring _keyring;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<GroupRenamed> rename(String groupId, String name) async {
    final signature = 'group-rename:$groupId:$name';
    final key = _keyring.reserve(signature);
    try {
      final result = await _session.execute(
        (accessToken) => _api.renameGroup(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          idempotencyKey: key,
          groupId: groupId,
          name: name,
        ),
      );
      _keyring.release(signature);
      return result;
    } on LoopBackendFailure catch (failure) {
      final kind = groupRenameFailureKind(failure);
      if (!communityOutcomeIsUnresolved(kind)) _keyring.release(signature);
      throw CommunityGatewayException(
        kind,
        reasonCode: failure.detailsSafe?.reasonCode,
        scope: failure.detailsSafe?.scope,
      );
    } catch (_) {
      _keyring.release(signature);
      throw const CommunityGatewayException(CommunityFailureKind.unexpected);
    }
  }
}

/// What one failed rename means.
///
/// A `404` in LOOP's own envelope (`NOT_FOUND`) is the server saying the
/// group is gone or the reader is no longer in it. A route the server does
/// not serve — `404` / `405` / `501` without the envelope — is unavailable:
/// never an unknown outcome a retry might finish, and never a success.
CommunityFailureKind groupRenameFailureKind(LoopBackendFailure failure) {
  if (failure.code == 'NOT_FOUND') return CommunityFailureKind.notFound;
  final status = failure.statusCode;
  if (status == 404 || status == 405 || status == 501) {
    return CommunityFailureKind.unavailable;
  }
  return communityFailureKindForV2(failure, write: true);
}

final loopV2GroupProfileGatewayProvider = Provider<GroupProfileGateway>((ref) {
  final dio = ref.watch(loopBackendDioProvider);
  final metadata = ref.watch(loopV2ClientMetadataProvider);
  final session = ref.watch(loopAuthenticatedSessionProvider);
  if (dio == null || metadata == null || session == null) {
    return const UnavailableGroupProfileGateway();
  }
  return DioLoopV2GroupProfileGateway(
    api: DioLoopV2GroupProfileApi(dio),
    clientMetadata: metadata,
    session: session,
  );
});
