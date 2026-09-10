import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

/// Authenticated V2 adapter for the `community` module.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. This adapter owns no credential cache and no generic
/// transport retry; it owns only the idempotency key of each write.
final class DioLoopV2CommunityGateway implements CommunityGateway {
  DioLoopV2CommunityGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2CommunityApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2CommandKeyring _keyring;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  String get _clientVersion => _clientMetadata.clientVersion;

  Future<T> _read<T>(Future<T> Function(String accessToken) request) =>
      executeCommunityRequest(_session, request);

  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeCommunityRequest(
        _session,
        (accessToken) => request(accessToken, key),
      );
      _keyring.release(signature);
      return result;
    } on CommunityGatewayException catch (failure) {
      // Only an unresolved outcome keeps the key for an identical retry.
      if (!communityOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<CommunityHome> loadHome() => _read(
    (accessToken) =>
        _api.getHome(accessToken: accessToken, clientVersion: _clientVersion),
  );

  @override
  Future<CommunityDirectoryPage> listCommunities({
    CommunityDirectorySort sort = CommunityDirectorySort.members,
    CommunityVerificationFilter verification =
        CommunityVerificationFilter.verified,
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
    String? cursor,
  }) => _read(
    (accessToken) => _api.listCommunities(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      sort: sort,
      verification: verification,
      membership: membership,
      cursor: cursor,
    ),
  );

  @override
  Future<CommunityDetail> createCommunity(CommunityApplication application) {
    if (application.invalidField != null) {
      return Future<CommunityDetail>.error(
        const CommunityGatewayException(CommunityFailureKind.validationFailed),
      );
    }
    // A changed application is a new logical operation and gets a fresh key.
    return _write(
      'create:${application.slug}:${application.name}',
      (accessToken, key) => _api.createCommunity(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        application: application,
      ),
    );
  }

  @override
  Future<CommunityDetail> loadCommunity(String communityId) => _read(
    (accessToken) => _api.getCommunity(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      communityId: communityId,
    ),
  );

  @override
  Future<CommunityDetail> join(String communityId) => _write(
    'join:$communityId',
    (accessToken, key) => _api.join(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
    ),
  );

  @override
  Future<CommunityDetail> leave(String communityId) => _write(
    'leave:$communityId',
    (accessToken, key) => _api.leave(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
    ),
  );

  @override
  Future<CommunityDetail> editProfile(
    String communityId,
    CommunityProfileEdit edit,
  ) {
    if (edit.isEmpty) {
      return Future<CommunityDetail>.error(
        const CommunityGatewayException(CommunityFailureKind.validationFailed),
      );
    }
    final body = <String, Object?>{
      if (edit.name != null) 'name': edit.name,
      if (edit.clearDescription)
        'description': null
      else if (edit.description != null)
        'description': edit.description,
      if (edit.clearLogoRef)
        'logoRef': null
      else if (edit.logoRef != null)
        'logoRef': edit.logoRef,
    };
    // A changed body is a new logical edit and receives a fresh key.
    final signature =
        'edit:$communityId:${body.keys.join(',')}:${body.values.join(' ')}';
    return _write(
      signature,
      (accessToken, key) => _api.patchCommunity(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        communityId: communityId,
        body: body,
      ),
    );
  }

  @override
  Future<CommunityMemberDirectory> listMembers(
    String communityId, {
    CommunityMemberFilter role = CommunityMemberFilter.all,
    String? q,
    String? cursor,
  }) => _read(
    (accessToken) => _api.listMembers(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      communityId: communityId,
      role: role,
      q: q,
      cursor: cursor,
    ),
  );

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) => _write(
    'role:$communityId:$publicProfileId:${role.wireName}',
    (accessToken, key) => _api.changeMemberRole(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
      publicProfileId: publicProfileId,
      role: role,
    ),
  );

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) => _write(
    'mute:$communityId:$publicProfileId:$muted',
    (accessToken, key) => _api.setMuted(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
      publicProfileId: publicProfileId,
      muted: muted,
    ),
  );

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) => _write(
    'ban:$communityId:$publicProfileId:$banned',
    (accessToken, key) => _api.setBanned(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
      publicProfileId: publicProfileId,
      banned: banned,
    ),
  );

  @override
  Future<ReferralRules> loadReferralRules() => _read(
    (accessToken) => _api.getReferralRules(
      accessToken: accessToken,
      clientVersion: _clientVersion,
    ),
  );
}

/// Runs one authenticated S3 request and maps every transport failure onto the
/// narrow feature-facing kind. No provider detail ever escapes.
Future<T> executeCommunityRequest<T>(
  LoopAuthenticatedSession session,
  Future<T> Function(String accessToken) request,
) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    throw CommunityGatewayException(communityFailureKindForV2(failure));
  } on CommunityGatewayException {
    rethrow;
  } catch (_) {
    throw const CommunityGatewayException(CommunityFailureKind.unexpected);
  }
}
