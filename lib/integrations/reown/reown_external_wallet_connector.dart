import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:reown_appkit/reown_appkit.dart';

@immutable
class ExternalWalletIdentity {
  const ExternalWalletIdentity({
    required this.address,
    required this.chainId,
    required this.walletClientType,
    required this.walletLabel,
  });

  final String address;
  final String chainId;
  final String walletClientType;
  final String walletLabel;
}

@immutable
class ExternalWalletProof {
  const ExternalWalletProof({
    required this.identity,
    required this.message,
    required this.signature,
  });

  final ExternalWalletIdentity identity;
  final String message;
  final String signature;
}

@immutable
class EvmCaip10Account {
  const EvmCaip10Account({required this.chainId, required this.address});

  final String chainId;
  final String address;

  String get caip2 => 'eip155:$chainId';
}

abstract final class ExternalWalletProtocol {
  static EvmCaip10Account? parseCaip10(String value) {
    final match = RegExp(r'^eip155:([1-9][0-9]*):(0x[0-9a-fA-F]{40})$')
        .firstMatch(value);
    if (match == null) return null;
    return EvmCaip10Account(chainId: match.group(1)!, address: match.group(2)!);
  }

  static String personalSignPayload(String message) =>
      '0x${utf8.encode(message).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';

  static bool isSignature(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{128,}$').hasMatch(value) && value.length.isEven;

  static ExternalWalletConnectorException mapModalError(ModalError error) {
    if (error is UserRejectedConnection || error is UserRejectedRequest) {
      return const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.rejected,
        '已拒绝钱包连接或签名请求。',
      );
    }
    if (error is WalletNotInstalled) {
      return const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.notInstalled,
        '未找到该钱包 App，请先安装后重试。',
      );
    }
    if (error is ErrorOpeningWallet) {
      return const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        '无法打开钱包 App 或返回 LOOP，请重试。',
      );
    }
    final normalized = '${error.message} ${error.description ?? ''}'
        .toLowerCase();
    if (normalized.contains('network') ||
        normalized.contains('socket') ||
        normalized.contains('relay')) {
      return const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.network,
        '钱包连接网络不可用，请稍后重试。',
      );
    }
    return const ExternalWalletConnectorException(
      ExternalWalletConnectorFailure.callback,
      '钱包连接或回跳未完成，请重试。',
    );
  }
}

enum ExternalWalletConnectorFailure {
  configuration,
  cancelled,
  rejected,
  notInstalled,
  callback,
  network,
  invalidResponse,
}

class ExternalWalletConnectorException implements Exception {
  const ExternalWalletConnectorException(this.kind, this.userMessage);

  final ExternalWalletConnectorFailure kind;
  final String userMessage;

  @override
  String toString() => userMessage;
}

/// Serializes Reown's non-cancellable initialization without ever constructing
/// a second AppKit owner over a partially registered GetIt service graph.
///
/// A timeout releases the UI operation lease but retains the same owner and
/// initialization future. A later retry asks that owner to reconnect and waits
/// again. A terminal initialization error remains fail-closed until restart.
class ExternalWalletInitializationGate<T extends Object> {
  ExternalWalletInitializationGate({required this.timeout});

  final Duration timeout;
  T? _owner;
  Future<void>? _initialization;
  Object? _terminalFailure;

  bool get hasRetainedOwner => _owner != null;

  Future<T> acquire({
    required T Function() create,
    required Future<void> Function(T owner) initialize,
    required Future<void> Function(T owner) reconnect,
    required bool Function(T owner) isReady,
  }) async {
    if (_terminalFailure != null) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        'Reown 初始化未完成，请重启 LOOP 后重试。',
      );
    }

    var owner = _owner;
    var initialization = _initialization;
    if (owner == null || initialization == null) {
      try {
        owner = create();
        _owner = owner;
        initialization = initialize(owner);
        _initialization = initialization;
      } catch (error) {
        _terminalFailure = error;
        throw const ExternalWalletConnectorException(
          ExternalWalletConnectorFailure.callback,
          'Reown 初始化失败，请重启 LOOP 后重试。',
        );
      }
    } else {
      unawaited(Future<void>.sync(() => reconnect(owner!)).catchError((_) {}));
    }

    try {
      await initialization.timeout(timeout);
    } on TimeoutException {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.network,
        'Reown 服务连接超时，请检查网络后重试。',
      );
    } on ExternalWalletConnectorException {
      rethrow;
    } catch (error) {
      _terminalFailure = error;
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        'Reown 初始化失败，请重启 LOOP 后重试。',
      );
    }

    if (!isReady(owner)) {
      _terminalFailure = StateError(
        'Reown initialization did not become ready.',
      );
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.network,
        'Reown 服务尚未就绪，请重启 LOOP 后重试。',
      );
    }
    return owner;
  }

  void release(T owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _initialization = null;
    _terminalFailure = null;
  }
}

abstract interface class ExternalWalletConnector {
  Future<ExternalWalletProof> connectAndSign({
    required BuildContext context,
    required Future<String> Function(ExternalWalletIdentity identity)
    createMessage,
  });
}

final externalWalletConnectorProvider = Provider<ExternalWalletConnector>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  if (!config.canConnectExternalWallet) {
    return const UnconfiguredExternalWalletConnector();
  }
  return ReownExternalWalletConnector(projectId: config.reownProjectId.trim());
});

class UnconfiguredExternalWalletConnector implements ExternalWalletConnector {
  const UnconfiguredExternalWalletConnector();

  @override
  Future<ExternalWalletProof> connectAndSign({
    required BuildContext context,
    required Future<String> Function(ExternalWalletIdentity identity)
    createMessage,
  }) {
    throw const ExternalWalletConnectorException(
      ExternalWalletConnectorFailure.configuration,
      'Reown Project ID 尚未配置，外部钱包暂不可用。',
    );
  }
}

class ReownExternalWalletConnector implements ExternalWalletConnector {
  ReownExternalWalletConnector({
    required this.projectId,
    this.initializationTimeout = const Duration(seconds: 30),
  }) : _initializationGate = ExternalWalletInitializationGate(
         timeout: initializationTimeout,
       );

  final String projectId;
  final Duration initializationTimeout;
  final ExternalWalletInitializationGate<ReownAppKitModal> _initializationGate;
  bool _active = false;

  static const _phantomWalletId =
      'a797aa35c0fadbfc1a53e7f675162ed5226968b44a19ee3d24385c64d1d3c393';
  static const _solflareWalletId =
      '1ca0bdd4747578705b1939af023d120677c64fe6ca76add81fda36e350605e79';
  static const _coinbaseWalletId =
      'fd20dc426fb37566d803205b19bbc1d4096b248ac04548e3cfb6b3a38bd033aa';

  @override
  Future<ExternalWalletProof> connectAndSign({
    required BuildContext context,
    required Future<String> Function(ExternalWalletIdentity identity)
    createMessage,
  }) async {
    if (_active) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.cancelled,
        '已有登录或钱包连接操作正在进行。',
      );
    }
    if (!context.mounted) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        '当前页面已关闭，请重新发起钱包连接。',
      );
    }

    _active = true;
    ReownAppKitModal? modal;
    void Function(ModalConnect)? connectListener;
    void Function(ModalError)? errorListener;
    try {
      modal = await _initializationGate.acquire(
        create: () => _createModal(context),
        initialize: (owner) => owner.init(),
        reconnect: (owner) => owner.reconnectRelay(),
        isReady: (owner) => owner.status.isInitialized,
      );
      final connected = Completer<ReownAppKitModalSession>();
      final modalFailure = Completer<ExternalWalletConnectorException>();

      void onConnect(ModalConnect event) {
        if (!connected.isCompleted) connected.complete(event.session);
      }

      void onError(ModalError event) {
        if (!modalFailure.isCompleted) {
          modalFailure.complete(ExternalWalletProtocol.mapModalError(event));
        }
      }

      connectListener = onConnect;
      errorListener = onError;
      modal.onModalConnect.subscribe(connectListener);
      modal.onModalError.subscribe(errorListener);

      final existingSession = modal.session;
      final session =
          existingSession ??
          await _openAndAwaitSession(
            modal: modal,
            connected: connected,
            failure: modalFailure,
          );
      if (modal.isOpen) modal.closeModal();

      final identity = _identityFrom(modal, session);
      final message = await createMessage(identity);
      if (message.isEmpty) {
        throw const ExternalWalletConnectorException(
          ExternalWalletConnectorFailure.invalidResponse,
          '登录消息为空，请重新连接钱包。',
        );
      }

      final signature = await _personalSign(
        modal: modal,
        session: session,
        identity: identity,
        message: message,
        failure: modalFailure,
      );
      return ExternalWalletProof(
        identity: identity,
        message: message,
        signature: signature,
      );
    } on ExternalWalletConnectorException {
      rethrow;
    } catch (_) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        '钱包连接或回跳未完成，请返回 LOOP 后重试。',
      );
    } finally {
      if (modal != null) {
        if (connectListener != null) {
          modal.onModalConnect.unsubscribe(connectListener);
        }
        if (errorListener != null) {
          modal.onModalError.unsubscribe(errorListener);
        }
        _initializationGate.release(modal);
        try {
          if (modal.isOpen) modal.closeModal();
          await modal.dispose();
        } catch (_) {
          // Credential success or its sanitized failure remains authoritative;
          // cleanup errors never turn an external session into app state.
        }
      }
      _active = false;
    }
  }

  ReownAppKitModal _createModal(BuildContext context) {
    final chains = ReownAppKitModalNetworks.getAllSupportedNetworks(
      namespace: NetworkUtils.eip155,
    ).map((network) => network.chainId).toList(growable: false);
    return ReownAppKitModal(
      context: context,
      projectId: projectId,
      metadata: const PairingMetadata(
        name: 'LOOP',
        description: 'LOOP external EVM sign-in credential',
        url: AppConfig.reownMetadataUrl,
        icons: <String>[AppConfig.reownIconUrl],
        redirect: Redirect(
          native: '${AppConfig.reownWalletScheme}://',
          linkMode: false,
        ),
      ),
      logLevel: LogLevel.nothing,
      enableAnalytics: false,
      siweConfig: null,
      featuresConfig: FeaturesConfig(
        // AppKit 1.8.4 defaults this deprecated compatibility flag to true.
        // It must be false in addition to an empty socials list.
        // ignore: deprecated_member_use
        email: false,
        socials: const <AppKitSocialOption>[],
        showMainWallets: true,
      ),
      optionalNamespaces: <String, RequiredNamespace>{
        NetworkUtils.eip155: RequiredNamespace(
          chains: chains,
          methods: const <String>['personal_sign'],
          events: const <String>['accountsChanged', 'chainChanged'],
        ),
      },
      excludedWalletIds: const <String>{
        _phantomWalletId,
        _solflareWalletId,
        _coinbaseWalletId,
      },
      disconnectOnDispose: true,
    );
  }

  Future<ReownAppKitModalSession> _openAndAwaitSession({
    required ReownAppKitModal modal,
    required Completer<ReownAppKitModalSession> connected,
    required Completer<ExternalWalletConnectorException> failure,
  }) async {
    final modalClosed = Completer<Never>();
    unawaited(
      modal.openModalView().then(
        (_) {
          if (!connected.isCompleted && !modalClosed.isCompleted) {
            modalClosed.completeError(
              const ExternalWalletConnectorException(
                ExternalWalletConnectorFailure.cancelled,
                '已取消钱包连接。',
              ),
            );
          }
        },
        onError: (_) {
          if (!modalClosed.isCompleted) {
            modalClosed.completeError(
              const ExternalWalletConnectorException(
                ExternalWalletConnectorFailure.callback,
                '钱包选择页未能打开，请重试。',
              ),
            );
          }
        },
      ),
    );
    return Future.any<ReownAppKitModalSession>(
      <Future<ReownAppKitModalSession>>[
        connected.future,
        failure.future.then<ReownAppKitModalSession>((error) => throw error),
        modalClosed.future,
      ],
    ).timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.callback,
        '钱包连接等待超时，请返回 LOOP 后重试。',
      ),
    );
  }

  ExternalWalletIdentity _identityFrom(
    ReownAppKitModal modal,
    ReownAppKitModalSession session,
  ) {
    final methods = session.getApprovedMethods(namespace: NetworkUtils.eip155);
    if (methods == null || !methods.contains('personal_sign')) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.invalidResponse,
        '该钱包会话没有授权 personal_sign，请重新连接。',
      );
    }
    final accounts =
        session.getAccounts(namespace: NetworkUtils.eip155) ?? const <String>[];
    final parsed = accounts
        .map(ExternalWalletProtocol.parseCaip10)
        .whereType<EvmCaip10Account>()
        .toList(growable: false);
    if (parsed.isEmpty) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.invalidResponse,
        '钱包没有返回可用的 EVM 地址。',
      );
    }

    final selectedChain = modal.selectedChain?.chainId ?? session.chainId;
    final selected = parsed
        .where((item) => item.caip2 == selectedChain)
        .toList();
    final account = selected.isNotEmpty ? selected.first : parsed.first;
    final label = _safeWalletLabel(session.connectedWalletName);
    return ExternalWalletIdentity(
      address: account.address,
      chainId: account.chainId,
      walletClientType: _walletClientType(label),
      walletLabel: label,
    );
  }

  Future<String> _personalSign({
    required ReownAppKitModal modal,
    required ReownAppKitModalSession session,
    required ExternalWalletIdentity identity,
    required String message,
    required Completer<ExternalWalletConnectorException> failure,
  }) async {
    final topic = session.topic;
    if (topic == null || topic.isEmpty) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.invalidResponse,
        '钱包会话无效，请重新连接。',
      );
    }
    final response =
        await Future.any<dynamic>(<Future<dynamic>>[
          modal.request(
            topic: topic,
            chainId: 'eip155:${identity.chainId}',
            request: SessionRequestParams(
              method: 'personal_sign',
              params: <String>[
                ExternalWalletProtocol.personalSignPayload(message),
                identity.address,
              ],
            ),
          ),
          failure.future.then<dynamic>((error) => throw error),
        ]).timeout(
          const Duration(minutes: 3),
          onTimeout: () => throw const ExternalWalletConnectorException(
            ExternalWalletConnectorFailure.callback,
            '钱包签名等待超时，请返回 LOOP 后重试。',
          ),
        );
    if (response is! String || !ExternalWalletProtocol.isSignature(response)) {
      throw const ExternalWalletConnectorException(
        ExternalWalletConnectorFailure.invalidResponse,
        '钱包没有返回有效签名。',
      );
    }
    return response;
  }

  String _safeWalletLabel(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || trimmed.length > 40) return 'External EVM wallet';
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9 ._()-]'), '');
    return sanitized.isEmpty ? 'External EVM wallet' : sanitized;
  }

  String _walletClientType(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('metamask')) return 'metamask';
    if (normalized.contains('trust')) return 'trust';
    if (normalized.contains('rainbow')) return 'rainbow';
    return 'other';
  }
}
