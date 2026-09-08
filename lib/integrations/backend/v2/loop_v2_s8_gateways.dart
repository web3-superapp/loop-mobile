import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/about/about_gateway.dart';
import 'package:loop_mobile/features/profile/about/about_models.dart';
import 'package:loop_mobile/features/profile/security/security_gateway.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/settings/settings_gateway.dart';
import 'package:loop_mobile/features/profile/settings/settings_models.dart';
import 'package:loop_mobile/features/profile/support/support_gateway.dart';
import 'package:loop_mobile/features/profile/support/support_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_id_source.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/meta/loop_v2_about_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/backend/v2/settings/loop_v2_settings_api.dart';
import 'package:loop_mobile/integrations/backend/v2/support/loop_v2_support_api.dart';

/// The three authenticated S8 adapters plus the public `about` repository.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. These adapters own no credential cache and no generic
/// transport retry.
final class DioLoopV2SecurityGateway implements SecurityGateway {
  DioLoopV2SecurityGateway({
    required LoopV2SecurityApi api,
    required LoopV2ClientMetadata clientMetadata,
    required LoopAuthenticatedSession session,
    required LoopV2SessionIdSource sessionIds,
    LoopV2CommandKeyring? keyring,
    // ignore: prefer_initializing_formals
  }) : _api = api,
       // ignore: prefer_initializing_formals
       _clientMetadata = clientMetadata,
       // ignore: prefer_initializing_formals
       _session = session,
       // ignore: prefer_initializing_formals
       _sessionIds = sessionIds,
       _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2SecurityApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2SessionIdSource _sessionIds;
  final LoopV2CommandKeyring _keyring;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopDeviceDirectory> loadDevices() async {
    // The header is optional: without it the server marks nothing as current
    // rather than guessing, so a missing journal degrades the page instead of
    // failing it.
    final sessionId = await _sessionIds.resolve();
    return executeChainRequest(
      _session,
      (accessToken) => _api.getDevices(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        sessionId: sessionId,
      ),
    );
  }

  @override
  Future<LoopDeviceRevocation> revokeDevice(String sessionId) async {
    final callerSessionId = await _sessionIds.resolve();
    final deviceId = await _sessionIds.resolveDeviceId();
    // A device command needs the whole logout header set. Without the caller's
    // own session it cannot be issued at all; it is never sent without one.
    if (callerSessionId == null || deviceId == null) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    if (callerSessionId == sessionId) {
      // Signing this device out is `POST /v2/session/logout`; revoking it is a
      // step-up command the server always refuses.
      throw const LoopChainException(LoopChainFailureKind.stepUpRequired);
    }
    final signature = 'device-revoke:$sessionId';
    final idempotencyKey = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        _session,
        (accessToken) => _api.revokeDevice(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          sessionId: sessionId,
          command: LoopV2SessionCommand(
            platform: _clientMetadata.platform,
            deviceId: deviceId,
            sessionId: callerSessionId,
            idempotencyKey: idempotencyKey,
          ),
        ),
      );
      _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<LoopSecurityCapabilities> loadCapabilities() => executeChainRequest(
    _session,
    (accessToken) => _api.getCapabilities(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
  );

  @override
  Future<LoopSecuritySummary> loadSummary() => executeChainRequest(
    _session,
    (accessToken) => _api.getSummary(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
  );
}

final class DioLoopV2AccountSettingsGateway implements AccountSettingsGateway {
  DioLoopV2AccountSettingsGateway({
    required LoopV2SettingsApi api,
    required LoopV2ClientMetadata clientMetadata,
    required LoopAuthenticatedSession session,
    LoopV2WriteOriginSource? originSource,
    // ignore: prefer_initializing_formals
  }) : _api = api,
       // ignore: prefer_initializing_formals
       _clientMetadata = clientMetadata,
       // ignore: prefer_initializing_formals
       _session = session,
       // ignore: prefer_initializing_formals
       _originSource = originSource;

  final LoopV2SettingsApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopAccountSettings> load() => executeChainRequest(
    _session,
    (accessToken) => _api.getSettings(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
  );

  @override
  Future<LoopAccountSettings> replace({
    required int expectedVersion,
    required LoopAccountSettingsValues values,
  }) async {
    final origin = await _originSource?.resolve();
    return executeChainRequest(
      _session,
      (accessToken) => _api.putSettings(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        expectedVersion: expectedVersion,
        values: values,
        origin: origin,
      ),
    );
  }
}

final class DioLoopV2SupportGateway implements SupportGateway {
  DioLoopV2SupportGateway({
    required LoopV2SupportApi api,
    required LoopV2ClientMetadata clientMetadata,
    required LoopAuthenticatedSession session,
    LoopV2WriteOriginSource? originSource,
    LoopV2CommandKeyring? keyring,
    // ignore: prefer_initializing_formals
  }) : _api = api,
       // ignore: prefer_initializing_formals
       _clientMetadata = clientMetadata,
       // ignore: prefer_initializing_formals
       _session = session,
       // ignore: prefer_initializing_formals
       _originSource = originSource,
       _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2SupportApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2WriteOriginSource? _originSource;
  final LoopV2CommandKeyring _keyring;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopSupportTicketPage> listTickets({String? cursor}) =>
      executeChainRequest(
        _session,
        (accessToken) => _api.listTickets(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          cursor: cursor,
        ),
      );

  @override
  Future<LoopSupportTicketResult> createTicket(LoopSupportDraft draft) async {
    final origin = await _originSource?.resolve();
    // One logical ticket reserves exactly one key; a different body is a
    // different ticket and gets a new key.
    final signature = 'support-ticket:${draft.category.wireName}:${draft.body}';
    final idempotencyKey = _keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        _session,
        (accessToken) => _api.createTicket(
          accessToken: accessToken,
          clientVersion: _clientMetadata.clientVersion,
          idempotencyKey: idempotencyKey,
          draft: draft,
          origin: origin,
        ),
      );
      _keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }
}

/// Public `about` repository. There is no session and no access token.
final class LoopV2AboutRepository implements AboutGateway {
  const LoopV2AboutRepository(this._api);

  final LoopV2AboutApi _api;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopAbout> load() async {
    try {
      return await _api.getAbout();
    } on LoopBackendFailure catch (failure) {
      throw LoopChainException(loopChainFailureKindForV2(failure));
    } on LoopChainException {
      rethrow;
    } catch (_) {
      throw const LoopChainException(LoopChainFailureKind.unexpected);
    }
  }
}
