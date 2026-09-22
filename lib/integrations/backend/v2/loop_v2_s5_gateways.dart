import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_gateway.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_gateway.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/notifications/push_device_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/alerts/loop_v2_alerts_api.dart';
import 'package:loop_mobile/integrations/backend/v2/chain/loop_v2_chain_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_id_source.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_write_origin_source.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_push_device_api.dart';
import 'package:loop_mobile/integrations/backend/v2/security/loop_v2_security_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/integrations/backend/v2/watchlist/loop_v2_watchlist_api.dart';
import 'package:uuid/uuid.dart';

/// Shared plumbing for the six authenticated S5 adapters.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. These adapters own no credential cache and no generic
/// transport retry; they own only the idempotency key of each idempotent
/// write.
base mixin _LoopV2S5Adapter {
  LoopV2ClientMetadata get clientMetadata;

  LoopAuthenticatedSession get session;

  LoopV2WriteOriginSource? get originSource;

  String get clientVersion => clientMetadata.clientVersion;

  Future<T> read<T>(Future<T> Function(String accessToken) request) =>
      executeChainRequest(session, request, write: false);

  Future<LoopV2WriteOrigin?> origin() async =>
      originSource == null ? null : await originSource!.resolve();

  /// A compare-and-set write. There is no idempotency key: the version is what
  /// makes the write safe to repeat.
  Future<T> cas<T>(Future<T> Function(String accessToken) request) =>
      executeChainRequest(session, request, write: true);

  /// An idempotent write. One logical operation reserves exactly one key; the
  /// key is replayed only while the outcome stays unresolved.
  Future<T> idempotent<T>(
    LoopV2CommandKeyring keyring,
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = keyring.reserve(signature);
    try {
      final result = await executeChainRequest(
        session,
        (accessToken) => request(accessToken, key),
        write: true,
      );
      keyring.release(signature);
      return result;
    } on LoopChainException catch (failure) {
      if (!loopChainOutcomeIsUnresolved(failure.kind)) {
        keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      keyring.release(signature);
      rethrow;
    }
  }
}

final class DioLoopV2ChainGateway
    with _LoopV2S5Adapter
    implements ChainGateway {
  DioLoopV2ChainGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2ChainApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopChainStatus> loadStatus() => read(
    (accessToken) =>
        _api.getStatus(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<LoopChainAssetView> loadAsset(String assetId) => read(
    (accessToken) => _api.getAsset(
      accessToken: accessToken,
      clientVersion: clientVersion,
      assetId: assetId,
    ),
  );
}

final class DioLoopV2WalletReadGateway
    with _LoopV2S5Adapter
    implements WalletReadGateway {
  DioLoopV2WalletReadGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2WalletApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopWalletDirectory> loadWallets() => read(
    (accessToken) =>
        _api.getWallets(accessToken: accessToken, clientVersion: clientVersion),
  );

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) async {
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.putActiveWallet(
        accessToken: accessToken,
        clientVersion: clientVersion,
        walletId: walletId,
        expectedActiveWalletId: expectedActiveWalletId,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) => read(
    (accessToken) => _api.getBalances(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
    ),
  );

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => read(
    (accessToken) => _api.getActivity(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
      cursor: cursor,
    ),
  );

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) => read(
    (accessToken) => _api.getReceive(
      accessToken: accessToken,
      clientVersion: clientVersion,
      walletId: walletId,
    ),
  );
}

final class DioLoopV2MarketReadGateway
    with _LoopV2S5Adapter
    implements MarketReadGateway {
  DioLoopV2MarketReadGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2MarketApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MarketOverview> loadOverview() => read(
    (accessToken) => _api.getOverview(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) => read(
    (accessToken) => _api.getAsset(
      accessToken: accessToken,
      clientVersion: clientVersion,
      assetId: assetId,
    ),
  );

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) => read(
    (accessToken) => _api.getCandles(
      accessToken: accessToken,
      clientVersion: clientVersion,
      assetId: assetId,
      interval: interval,
      limit: limit,
    ),
  );

  @override
  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor}) => read(
    (accessToken) => _api.getTrades(
      accessToken: accessToken,
      clientVersion: clientVersion,
      assetId: assetId,
      cursor: cursor,
    ),
  );

  @override
  Future<MarketHolders> loadHolders(String assetId) => read(
    (accessToken) => _api.getHolders(
      accessToken: accessToken,
      clientVersion: clientVersion,
      assetId: assetId,
    ),
  );

  @override
  Future<MarketNewPairsPage> loadNewPairs() => read(
    (accessToken) => _api.getNewPairs(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<LoopUnavailable> loadSmartMoney() => read(
    (accessToken) => _api.getSmartMoney(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );
}

final class DioLoopV2WatchlistGateway
    with _LoopV2S5Adapter
    implements WatchlistGateway {
  DioLoopV2WatchlistGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
  });

  final LoopV2WatchlistApi _api;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<WatchlistSnapshot> load() => read(
    (accessToken) => _api.getWatchlist(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<WatchlistSnapshot> replace({
    required int expectedVersion,
    required List<WatchlistGroup> groups,
  }) async {
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.putWatchlist(
        accessToken: accessToken,
        clientVersion: clientVersion,
        expectedVersion: expectedVersion,
        groups: groups,
        origin: writeOrigin,
      ),
    );
  }
}

final class DioLoopV2AlertsGateway
    with _LoopV2S5Adapter
    implements AlertsGateway {
  DioLoopV2AlertsGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2AlertsApi _api;
  final LoopV2CommandKeyring _keyring;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopAlertPage> listAlerts({String? cursor}) => read(
    (accessToken) => _api.listAlerts(
      accessToken: accessToken,
      clientVersion: clientVersion,
      cursor: cursor,
    ),
  );

  @override
  Future<LoopPriceAlert> createAlert(LoopAlertDraft draft) async {
    if (draft.invalidField != null) {
      throw const LoopChainException(LoopChainFailureKind.validationFailed);
    }
    final writeOrigin = await origin();
    // A changed draft is a new logical operation and gets a fresh key.
    return idempotent(
      _keyring,
      'alert:create:${draft.signature}',
      (accessToken, key) => _api.createAlert(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        draft: draft,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopPriceAlert> updateAlert({
    required String alertId,
    required int expectedVersion,
    required LoopAlertDraft draft,
  }) async {
    if (draft.invalidField != null) {
      throw const LoopChainException(LoopChainFailureKind.validationFailed);
    }
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.updateAlert(
        accessToken: accessToken,
        clientVersion: clientVersion,
        alertId: alertId,
        expectedVersion: expectedVersion,
        draft: draft,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<void> deleteAlert({
    required String alertId,
    required int expectedVersion,
  }) async {
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.deleteAlert(
        accessToken: accessToken,
        clientVersion: clientVersion,
        alertId: alertId,
        expectedVersion: expectedVersion,
        origin: writeOrigin,
      ),
    );
  }
}

final class DioLoopV2NotificationsGateway
    with _LoopV2S5Adapter
    implements NotificationsGateway {
  DioLoopV2NotificationsGateway({
    required this._api,
    required this.clientMetadata,
    required this.session,
    this.originSource,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2NotificationsApi _api;
  final LoopV2CommandKeyring _keyring;

  @override
  final LoopV2ClientMetadata clientMetadata;
  @override
  final LoopAuthenticatedSession session;
  @override
  final LoopV2WriteOriginSource? originSource;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopNotificationFeed> loadFeed({String? cursor}) => read(
    (accessToken) => _api.getFeed(
      accessToken: accessToken,
      clientVersion: clientVersion,
      cursor: cursor,
    ),
  );

  @override
  Future<LoopNotificationEntry> markRead(String notificationId) async {
    final writeOrigin = await origin();
    return idempotent(
      _keyring,
      'notification:read:$notificationId',
      (accessToken, key) => _api.markRead(
        accessToken: accessToken,
        clientVersion: clientVersion,
        idempotencyKey: key,
        notificationId: notificationId,
        origin: writeOrigin,
      ),
    );
  }

  @override
  Future<LoopNotificationPreferences> loadPreferences() => read(
    (accessToken) => _api.getPreferences(
      accessToken: accessToken,
      clientVersion: clientVersion,
    ),
  );

  @override
  Future<LoopNotificationPreferences> replacePreferences({
    required int expectedVersion,
    required Map<LoopNotificationCategory, bool> categories,
  }) async {
    final writeOrigin = await origin();
    return cas(
      (accessToken) => _api.putPreferences(
        accessToken: accessToken,
        clientVersion: clientVersion,
        expectedVersion: expectedVersion,
        categories: categories,
        origin: writeOrigin,
      ),
    );
  }
}

/// The account's push device registration (decision 0067).
///
/// It is deliberately not part of the notification-preferences resource: the
/// preferences say what the account wants to hear about, and this says where a
/// message could be delivered. Neither implies the other, and an accepted
/// token is still not a delivered notification.
///
/// This is a `/v2/devices` command, not an S5 read: it needs the caller's own
/// session id and a fresh idempotency key per attempt, which is why it does
/// not use the S5 adapter's `cas`/`idempotent` helpers.
final class DioLoopV2PushDeviceGateway implements PushDeviceGateway {
  DioLoopV2PushDeviceGateway({
    required LoopV2PushDeviceApi api,
    required LoopV2ClientMetadata clientMetadata,
    required LoopAuthenticatedSession session,
    required LoopV2SessionIdSource sessionIds,
    Uuid uuid = const Uuid(),
    // ignore: prefer_initializing_formals
  }) : _api = api,
       // ignore: prefer_initializing_formals
       _clientMetadata = clientMetadata,
       // ignore: prefer_initializing_formals
       _session = session,
       // ignore: prefer_initializing_formals
       _sessionIds = sessionIds,
       // ignore: prefer_initializing_formals
       _uuid = uuid;

  final LoopV2PushDeviceApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2SessionIdSource _sessionIds;
  final Uuid _uuid;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  }) async {
    final command = await _command();
    return executeChainRequest(
      _session,
      (accessToken) => _api.registerToken(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        platform: platform,
        token: token,
        appVersion: appVersion,
        command: command,
      ),
      write: true,
    );
  }

  @override
  Future<LoopPushTokenRevocation> revokeToken() async {
    final command = await _command();
    return executeChainRequest(
      _session,
      (accessToken) => _api.revokeToken(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        command: command,
      ),
      write: true,
    );
  }

  /// One command annotation per attempt.
  ///
  /// The key is fresh every time rather than reserved per logical operation:
  /// the server keys the registration by `(session, token)` itself, and
  /// replaying a key whose body has changed is `409 IDEMPOTENCY_CONFLICT`. A
  /// device command with no session of its own cannot be issued at all.
  Future<LoopV2SessionCommand> _command() async {
    final sessionId = await _sessionIds.resolve();
    final deviceId = await _sessionIds.resolveDeviceId();
    if (sessionId == null || deviceId == null) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    return LoopV2SessionCommand(
      platform: _clientMetadata.platform,
      deviceId: deviceId,
      sessionId: sessionId,
      idempotencyKey: _uuid.v4(),
    );
  }
}
