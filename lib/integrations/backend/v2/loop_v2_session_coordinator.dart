import 'dart:async';

import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:uuid/uuid.dart';

/// Resolves a V2 LOOP account/device session while preserving the narrow
/// [LoopBootstrapRepository] facade consumed by frozen V1 feature adapters.
final class LoopV2BootstrapRepository implements LoopBootstrapRepository {
  factory LoopV2BootstrapRepository({
    required String principalKey,
    required LoopV2ClientMetadata clientMetadata,
    required LoopV2SessionApi api,
    required LoopV2SessionJournalStore store,
    Uuid uuid = const Uuid(),
  }) {
    return LoopV2BootstrapRepository._(
      LoopV2OwnerPartition.fromPrincipal(principalKey, uuid: uuid),
      clientMetadata,
      api,
      store,
      uuid,
    );
  }

  LoopV2BootstrapRepository._(
    this._ownerPartition,
    this._clientMetadata,
    this._api,
    this._store,
    this._uuid,
  );

  final String _ownerPartition;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopV2SessionApi _api;
  final LoopV2SessionJournalStore _store;
  final Uuid _uuid;

  Future<LoopBootstrapIdentity>? _inFlight;
  var _retired = false;

  /// Prevents new bootstrap work and waits for an already dispatched command
  /// to record its server result before logout reads the journal.
  ///
  /// This method marks retirement synchronously. The returned future absorbs
  /// bootstrap failures because logout still needs to inspect whatever exact
  /// durable state remains.
  Future<void> prepareForLogout() {
    _retired = true;
    return _waitForInFlight();
  }

  /// Retires this principal owner without authorizing any later write path.
  void retire() {
    _retired = true;
  }

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) {
    if (_retired) {
      return Future<LoopBootstrapIdentity>.error(
        const LoopBackendFailure(LoopBackendFailureKind.cancelled),
      );
    }
    final active = _inFlight;
    if (active != null) return active;

    late final Future<LoopBootstrapIdentity> operation;
    operation = _bootstrap(accessToken).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<LoopBootstrapIdentity> _bootstrap(String accessToken) async {
    final deviceId = await _store.loadOrCreateDeviceId();
    var journal = await _store.readOwnerJournal(_ownerPartition);

    LoopV2AccountProjection? account;
    var accountBootstrapRequired = false;
    try {
      account = await _api.getAccount(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
      );
    } on LoopBackendFailure catch (failure) {
      if (failure.statusCode != 409 ||
          failure.code != 'ACCOUNT_BOOTSTRAP_REQUIRED') {
        rethrow;
      }
      accountBootstrapRequired = true;
    }

    final local = journal?.activeSession;
    if (local != null) {
      if ((!accountBootstrapRequired && account == null) ||
          (account != null &&
              (local.accountId != account.accountId ||
                  local.streamUserId != account.streamUserId)) ||
          local.deviceId != deviceId) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
    }
    if (local != null &&
        !accountBootstrapRequired &&
        journal?.hasReusableActiveSession == true) {
      return local.identity;
    }

    // The backend explicitly rejected the old account mapping. Every local
    // projection that depends on that account, including an unconfirmed stale
    // logout, is no longer a valid reconciliation target.
    if (accountBootstrapRequired && local != null) {
      journal = null;
    }

    _rejectUndispatchedRetiredOperation();

    final pendingLogout = journal?.pendingLogout;
    if (pendingLogout != null) {
      if (local == null ||
          pendingLogout.deviceId != deviceId ||
          pendingLogout.platform != _clientMetadata.platform ||
          pendingLogout.contractVersion !=
              LoopV2ClientMetadata.contractVersion) {
        throw const LoopV2SessionStorageException();
      }
      await _reconcileLogout(
        accessToken: accessToken,
        sessionId: local.sessionId,
        command: pendingLogout,
      );
      await _store.deleteOwnerJournal(_ownerPartition);
      journal = null;
      _rejectUndispatchedRetiredOperation();
    }

    if (journal?.bootstrapRetirementRequested == true) {
      final pendingBootstrap = journal?.pendingBootstrap;
      if (pendingBootstrap == null) {
        throw const LoopV2SessionStorageException();
      }
      await _retirePendingBootstrap(
        accessToken: accessToken,
        account: account,
        deviceId: deviceId,
        command: pendingBootstrap,
      );
      journal = null;
      _rejectUndispatchedRetiredOperation();
    }

    final pending = journal?.pendingBootstrap;
    final command = pending ?? _newCommand(deviceId);
    if (command.deviceId != deviceId ||
        command.platform != _clientMetadata.platform ||
        command.contractVersion != LoopV2ClientMetadata.contractVersion) {
      throw const LoopV2SessionStorageException();
    }

    if (pending == null) {
      journal = (journal ?? const LoopV2OwnerJournal()).copyWith(
        pendingBootstrap: command,
      );
      await _store.writeOwnerJournal(_ownerPartition, journal);
    }

    _rejectUndispatchedRetiredOperation();

    // Once this call starts, a successful response must be recorded even if
    // local logout begins in flight. prepareForLogout waits for this operation
    // before reading the journal, so it can revoke the returned session.
    final result = await _api.bootstrap(
      accessToken: accessToken,
      command: command,
    );
    final active = result.activeSession;
    if (account != null &&
        (account.accountId != active.accountId ||
            account.streamUserId != active.streamUserId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    await _store.writeOwnerJournal(
      _ownerPartition,
      LoopV2OwnerJournal(activeSession: active),
    );
    return active.identity;
  }

  Future<void> _retirePendingBootstrap({
    required String accessToken,
    required LoopV2AccountProjection? account,
    required String deviceId,
    required LoopV2CommandMetadata command,
  }) async {
    if (command.deviceId != deviceId ||
        command.platform != _clientMetadata.platform ||
        command.contractVersion != LoopV2ClientMetadata.contractVersion) {
      throw const LoopV2SessionStorageException();
    }

    final result = await _api.bootstrap(
      accessToken: accessToken,
      command: command,
    );
    final active = result.activeSession;
    if (active.deviceId != deviceId ||
        (account != null &&
            (account.accountId != active.accountId ||
                account.streamUserId != active.streamUserId))) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final logoutCommand = _newCommand(deviceId);
    if (logoutCommand.idempotencyKey == command.idempotencyKey) {
      throw const LoopV2SessionStorageException();
    }
    final logoutJournal = LoopV2OwnerJournal(
      activeSession: active,
      pendingLogout: logoutCommand,
    );
    await _store.writeOwnerJournal(_ownerPartition, logoutJournal);
    try {
      await _reconcileLogout(
        accessToken: accessToken,
        sessionId: active.sessionId,
        command: logoutCommand,
      );
    } catch (_) {
      try {
        await _store.writeOwnerJournal(
          _ownerPartition,
          logoutJournal.copyWith(revocationUnconfirmed: true),
        );
      } catch (_) {
        // The exact active/logout state was already written before dispatch.
      }
      rethrow;
    }
    await _store.deleteOwnerJournal(_ownerPartition);
  }

  Future<void> _reconcileLogout({
    required String accessToken,
    required String sessionId,
    required LoopV2CommandMetadata command,
  }) async {
    try {
      await _api.logout(
        accessToken: accessToken,
        sessionId: sessionId,
        command: command,
      );
    } on LoopBackendFailure catch (failure) {
      if (failure.statusCode == 404 && failure.code == 'SESSION_NOT_FOUND') {
        return;
      }
      rethrow;
    }
  }

  void _rejectUndispatchedRetiredOperation() {
    if (_retired) {
      throw const LoopBackendFailure(LoopBackendFailureKind.cancelled);
    }
  }

  Future<void> _waitForInFlight() async {
    final active = _inFlight;
    if (active == null) return;
    try {
      await active;
    } catch (_) {
      // The exact pending command remains durable for later reconciliation.
    }
  }

  LoopV2CommandMetadata _newCommand(String deviceId) {
    return LoopV2CommandMetadata(
      deviceId: deviceId,
      idempotencyKey: _uuid.v4().toLowerCase(),
      clientVersion: _clientMetadata.clientVersion,
      platform: _clientMetadata.platform,
    );
  }
}

final class LoopV2LogoutCoordinator {
  factory LoopV2LogoutCoordinator({
    required LoopV2ClientMetadata clientMetadata,
    required LoopV2SessionApi api,
    required LoopV2SessionJournalStore store,
    required LoopBackendAccessTokenSource accessTokens,
    Uuid uuid = const Uuid(),
  }) {
    return LoopV2LogoutCoordinator._(
      clientMetadata,
      api,
      store,
      accessTokens,
      uuid,
    );
  }

  LoopV2LogoutCoordinator._(
    this._clientMetadata,
    this._api,
    this._store,
    this._accessTokens,
    this._uuid,
  );

  final LoopV2ClientMetadata _clientMetadata;
  final LoopV2SessionApi _api;
  final LoopV2SessionJournalStore _store;
  final LoopBackendAccessTokenSource _accessTokens;
  final Uuid _uuid;
  final Map<String, Future<LoopV2LogoutDisposition>> _operations =
      <String, Future<LoopV2LogoutDisposition>>{};

  Future<LoopV2LogoutDisposition> logout(String principalKey) {
    String ownerPartition;
    try {
      ownerPartition = LoopV2OwnerPartition.fromPrincipal(
        principalKey,
        uuid: _uuid,
      );
    } catch (_) {
      return Future<LoopV2LogoutDisposition>.value(
        LoopV2LogoutDisposition.unconfirmed,
      );
    }
    return _operations.putIfAbsent(ownerPartition, () {
      late final Future<LoopV2LogoutDisposition> operation;
      operation = _logout(ownerPartition).whenComplete(() {
        if (identical(_operations[ownerPartition], operation)) {
          _operations.remove(ownerPartition);
        }
      });
      return operation;
    });
  }

  Future<LoopV2LogoutDisposition> _logout(String ownerPartition) async {
    LoopV2OwnerJournal? journal;
    try {
      final deviceId = await _store.loadOrCreateDeviceId();
      journal = await _store.readOwnerJournal(ownerPartition);
      var active = journal?.activeSession;
      var token = '';
      if (active == null) {
        final pendingBootstrap = journal?.pendingBootstrap;
        if (pendingBootstrap == null) {
          return LoopV2LogoutDisposition.notRequired;
        }
        if (pendingBootstrap.deviceId != deviceId ||
            pendingBootstrap.platform != _clientMetadata.platform ||
            pendingBootstrap.contractVersion !=
                LoopV2ClientMetadata.contractVersion) {
          return LoopV2LogoutDisposition.unconfirmed;
        }

        if (journal?.bootstrapRetirementRequested != true) {
          journal = journal!.copyWith(bootstrapRetirementRequested: true);
          await _store.writeOwnerJournal(ownerPartition, journal);
        }

        token = await _loadToken();
        LoopV2BootstrapProjection recovered;
        try {
          recovered = await _api.bootstrap(
            accessToken: token,
            command: pendingBootstrap,
          );
        } on LoopBackendFailure catch (failure) {
          if (failure.kind != LoopBackendFailureKind.authentication ||
              failure.statusCode != 401) {
            rethrow;
          }
          token = await _loadToken();
          recovered = await _api.bootstrap(
            accessToken: token,
            command: pendingBootstrap,
          );
        }
        active = recovered.activeSession;
        if (active.deviceId != deviceId) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }

        final logoutCommand = _newCommand(deviceId);
        if (logoutCommand.idempotencyKey == pendingBootstrap.idempotencyKey) {
          throw const LoopV2SessionStorageException();
        }
        journal = LoopV2OwnerJournal(
          activeSession: active,
          pendingLogout: logoutCommand,
        );
        await _store.writeOwnerJournal(ownerPartition, journal);
      }
      if (active.deviceId != deviceId) {
        return LoopV2LogoutDisposition.unconfirmed;
      }

      final pending = journal?.pendingLogout;
      final command = pending ?? _newCommand(deviceId);
      if (command.deviceId != deviceId ||
          command.platform != _clientMetadata.platform ||
          command.contractVersion != LoopV2ClientMetadata.contractVersion) {
        return LoopV2LogoutDisposition.unconfirmed;
      }
      if (pending == null) {
        journal = journal!.copyWith(
          pendingLogout: command,
          revocationUnconfirmed: false,
        );
        await _store.writeOwnerJournal(ownerPartition, journal);
      }

      if (token.isEmpty) token = await _loadToken();
      try {
        await _logoutOnce(token, active.sessionId, command);
      } on LoopBackendFailure catch (failure) {
        if (failure.kind != LoopBackendFailureKind.authentication ||
            failure.statusCode != 401) {
          rethrow;
        }
        token = await _loadToken();
        await _logoutOnce(token, active.sessionId, command);
      }
      await _store.deleteOwnerJournal(ownerPartition);
      return LoopV2LogoutDisposition.confirmed;
    } catch (_) {
      final value = journal;
      if (value != null) {
        try {
          final retained = value.pendingLogout == null
              ? value
              : value.copyWith(revocationUnconfirmed: true);
          await _store.writeOwnerJournal(ownerPartition, retained);
        } catch (_) {
          // The local sign-out barrier still wins if the audit journal cannot
          // be updated. Never report backend revocation as confirmed.
        }
      }
      return LoopV2LogoutDisposition.unconfirmed;
    }
  }

  Future<String> _loadToken() async {
    final token = await _accessTokens.loadAccessToken();
    if (token.isEmpty || token != token.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
    return token;
  }

  Future<void> _logoutOnce(
    String accessToken,
    String sessionId,
    LoopV2CommandMetadata command,
  ) async {
    try {
      await _api.logout(
        accessToken: accessToken,
        sessionId: sessionId,
        command: command,
      );
    } on LoopBackendFailure catch (failure) {
      if (failure.statusCode == 404 && failure.code == 'SESSION_NOT_FOUND') {
        return;
      }
      rethrow;
    }
  }

  LoopV2CommandMetadata _newCommand(String deviceId) {
    return LoopV2CommandMetadata(
      deviceId: deviceId,
      idempotencyKey: _uuid.v4().toLowerCase(),
      clientVersion: _clientMetadata.clientVersion,
      platform: _clientMetadata.platform,
    );
  }
}
