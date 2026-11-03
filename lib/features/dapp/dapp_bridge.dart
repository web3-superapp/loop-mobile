import 'dart:async';
import 'dart:convert';

import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_models.dart';
import 'package:loop_mobile/features/dapp/dapp_provider_script.dart';

/// What the bridge asks of the page that owns it (S342 · decision 0270).
///
/// The page implements it with the WebView, the sheets and the toast; a test
/// implements it with a double. Nothing here touches a widget.
abstract interface class DappBridgeHost {
  /// The origin of the top-level document the WebView reports right now, or
  /// `null` while no page is loaded. It is the only origin a request may
  /// claim.
  String? get topOrigin;

  /// The wallet pages connect to, or `null` while it is not known.
  DappWalletIdentity? get wallet;

  /// The connection sheet: site, icon, address. True when the owner agreed.
  Future<bool> confirmConnection({
    required String origin,
    required DappWalletIdentity wallet,
  });

  /// The confirmation sheet for one prepared intent. It signs (or declines)
  /// and answers with the outcome.
  Future<DappSignOutcome> confirmIntent({
    required DappIntent intent,
    required DappWalletIdentity wallet,
    DappTxRequest? tx,
    DappSignRequest? sign,
  });

  /// One short line on screen.
  void toast(String message);

  /// Raises one EIP-1193 event on the page.
  Future<void> emit(String event, Object? data);

  /// The page's chain changed (top bar).
  void chainChanged(String chainId);
}

/// The toast a signing request on BSC Mainnet shows (docs/55 §一).
const String dappMainnetSigningText = '暂不支持在这个网络签名';

/// Routes the EIP-1193 requests of one browser page.
///
/// It owns the page's chain and reads the connected origins from
/// [isConnected] / [setConnected]; it never decides an outcome on its own
/// that the owner or the server should decide.
final class DappBridge {
  DappBridge({
    required this.nonce,
    required this.host,
    required this.intents,
    required this.reader,
    required this.isConnected,
    required this.setConnected,
    String chainId = loopLaunchTestnetChainId,
  }) : _chainId = chainId; // ignore: prefer_initializing_formals

  final String nonce;
  final DappBridgeHost host;
  final DappIntentsGateway intents;
  final DappRpcReader reader;
  final bool Function(String origin) isConnected;
  final Future<void> Function(String origin, {required bool connected})
  setConnected;

  String _chainId;

  /// Requests refused by the origin check, for diagnostics and tests.
  int refusedFrames = 0;

  /// The tail of the signing queue. The server keeps one open intent per
  /// wallet and a new prepare supersedes the previous one (with the same
  /// nonce for a transaction), so a page that fires two signing requests at
  /// once is served one at a time: the second prepares only after the first
  /// was signed, declined or refused.
  Future<void> _signingTail = Future<void>.value();

  /// Identical reads in flight share one request to the read channel; the
  /// server limits reads per account and pages repeat the same poll.
  final Map<String, Future<Object?>> _readsInFlight =
      <String, Future<Object?>>{};

  Future<T> _serialSigning<T>(Future<T> Function() task) {
    final previous = _signingTail;
    final done = Completer<void>();
    _signingTail = done.future;
    return previous.then((_) => task()).whenComplete(done.complete);
  }

  String get chainId => _chainId;

  static const _signingMethods = <String>{
    'eth_sendTransaction',
    'personal_sign',
    'eth_signTypedData_v4',
  };

  /// The JavaScript handler. [args] is what `callHandler` passed after the
  /// handler name: nonce, origin, isTopFrame, requestJson.
  Future<Map<String, Object?>> handle(List<Object?> args) async {
    final origin = _admittedOrigin(args);
    if (origin == null) {
      refusedFrames += 1;
      return _error(
        const DappRpcError(DappRpcErrorCode.unauthorized, 'Request refused'),
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(args[3]! as String);
    } on Object {
      return _error(
        const DappRpcError(DappRpcErrorCode.invalidParams, 'Invalid request'),
      );
    }
    if (decoded is! Map || decoded['method'] is! String) {
      return _error(
        const DappRpcError(DappRpcErrorCode.invalidParams, 'Invalid request'),
      );
    }
    final rawParams = decoded['params'];
    final params = rawParams is List
        ? List<Object?>.from(rawParams)
        : rawParams == null
        ? const <Object?>[]
        : <Object?>[rawParams];
    try {
      final result = await route(
        origin: origin,
        method: decoded['method']! as String,
        params: params,
      );
      return <String, Object?>{'ok': true, 'result': result};
    } on DappRpcError catch (error) {
      return _error(error);
    } on Object {
      return _error(
        const DappRpcError(DappRpcErrorCode.internal, 'Internal error'),
      );
    }
  }

  static Map<String, Object?> _error(DappRpcError error) => <String, Object?>{
    'ok': false,
    'error': error.toJson(),
  };

  /// The origin a request may act for, or `null`: the nonce must be this
  /// page's, the frame the top one, and the claimed origin the origin of the
  /// top-level URL the WebView itself reports.
  String? _admittedOrigin(List<Object?> args) {
    if (args.length != 4) return null;
    if (args[0] != nonce) return null;
    if (args[2] != true) return null;
    final claimed = args[1];
    final top = host.topOrigin;
    if (claimed is! String || top == null || claimed != top) return null;
    if (!top.startsWith('https://')) return null;
    if (args[3] is! String) return null;
    return top;
  }

  /// One request, already admitted for [origin].
  Future<Object?> route({
    required String origin,
    required String method,
    required List<Object?> params,
  }) async {
    switch (method) {
      case 'eth_chainId':
        return DappChains.hexOf(_chainId);
      case 'net_version':
        return '${loopChainReference(_chainId)}';
      case 'eth_accounts':
        final wallet = host.wallet;
        if (wallet == null || !isConnected(origin)) return const <String>[];
        return <String>[wallet.address];
      case 'eth_requestAccounts':
        return _requestAccounts(origin);
      case 'wallet_switchEthereumChain':
        return _switchChain(params);
      // The two chains are built in: adding one of them is switching to it,
      // any other chain is unrecognized (4902).
      case 'wallet_addEthereumChain':
        return _addChain(params);
      case 'eth_sendTransaction':
      case 'personal_sign':
      case 'eth_signTypedData_v4':
        return _serialSigning(() => _sign(origin, method, params));
    }
    if (dappReadMethods.contains(method)) {
      return _read(method, params);
    }
    // `eth_sign` (a bare hash), `eth_signTransaction` and every method LOOP
    // does not serve.
    throw DappRpcError(
      DappRpcErrorCode.unsupportedMethod,
      'The method $method is not supported',
    );
  }

  Future<Object?> _read(String method, List<Object?> params) {
    final chainId = _chainId;
    final String key;
    try {
      key = '$chainId|$method|${jsonEncode(params)}';
    } on Object {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid params',
      );
    }
    final pending = _readsInFlight[key];
    if (pending != null) return pending;
    // The callback must not return the removed future: `whenComplete`
    // would then wait for the very request it belongs to.
    final request = _readOnce(chainId, method, params).whenComplete(() {
      _readsInFlight.remove(key);
    });
    _readsInFlight[key] = request;
    return request;
  }

  Future<Object?> _readOnce(
    String chainId,
    String method,
    List<Object?> params,
  ) async {
    try {
      return await reader.read(
        chainId: chainId,
        method: method,
        params: params,
      );
    } on DappRpcError {
      rethrow;
    } on LoopChainException catch (failure) {
      // A server whose allowlist is older than this build.
      if (failure.reasonCode == 'RPC_METHOD_NOT_ALLOWED') {
        throw DappRpcError(
          DappRpcErrorCode.unsupportedMethod,
          'The method $method is not supported',
        );
      }
      if (failure.reasonCode == 'RPC_LOG_RANGE_TOO_LARGE' ||
          failure.kind == LoopChainFailureKind.invalidData) {
        throw const DappRpcError(
          DappRpcErrorCode.invalidParams,
          'Invalid params',
        );
      }
      if (failure.kind == LoopChainFailureKind.rateLimited) {
        throw const DappRpcError(
          DappRpcErrorCode.limitExceeded,
          'Request limit exceeded',
        );
      }
      throw const DappRpcError(DappRpcErrorCode.internal, 'Read failed');
    } on Object {
      throw const DappRpcError(DappRpcErrorCode.internal, 'Read failed');
    }
  }

  Future<List<String>> _requestAccounts(String origin) async {
    final wallet = host.wallet;
    if (wallet == null) {
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'Wallet unavailable',
      );
    }
    if (isConnected(origin)) return <String>[wallet.address];
    final agreed = await host.confirmConnection(origin: origin, wallet: wallet);
    if (!agreed) {
      throw const DappRpcError(
        DappRpcErrorCode.userRejected,
        'User rejected the request',
      );
    }
    await setConnected(origin, connected: true);
    unawaited(host.emit('accountsChanged', <String>[wallet.address]));
    return <String>[wallet.address];
  }

  Future<Object?> _switchChain(List<Object?> params) async {
    final first = params.isEmpty ? null : params.first;
    final target = first is Map ? DappChains.fromHex(first['chainId']) : null;
    if (target == null) {
      throw const DappRpcError(
        DappRpcErrorCode.unrecognizedChain,
        'Unrecognized chain',
      );
    }
    await switchChain(target);
    return null;
  }

  Future<Object?> _addChain(List<Object?> params) async {
    final first = params.isEmpty ? null : params.first;
    if (first is! Map || first['chainId'] is! String) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid params',
      );
    }
    return _switchChain(params);
  }

  /// Moves the page to [chainId] (top bar or `wallet_switchEthereumChain`).
  Future<void> switchChain(String chainId) async {
    if (!DappChains.supported.contains(chainId) || chainId == _chainId) return;
    _chainId = chainId;
    host.chainChanged(chainId);
    await host.emit('chainChanged', DappChains.hexOf(chainId));
  }

  /// The owner disconnected [origin] from the menu.
  Future<void> disconnect(String origin) async {
    await setConnected(origin, connected: false);
    if (host.topOrigin == origin) {
      await host.emit('accountsChanged', const <String>[]);
      await host.emit('disconnect', <String, Object?>{
        'code': 4900,
        'message': 'Disconnected',
      });
    }
  }

  Future<Object?> _sign(
    String origin,
    String method,
    List<Object?> params,
  ) async {
    assert(_signingMethods.contains(method));
    final wallet = host.wallet;
    if (wallet == null || !isConnected(origin)) {
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'The site is not connected',
      );
    }
    // docs/00 rule 8: BSC Mainnet signing and broadcasting stay closed.
    if (!DappChains.canSign(_chainId)) {
      host.toast(dappMainnetSigningText);
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'Signing is not available on this network',
      );
    }
    DappTxRequest? tx;
    DappSignRequest? sign;
    if (method == 'eth_sendTransaction') {
      tx = parseTxRequest(params, wallet.address);
    } else {
      sign = parseSignRequest(method, params, wallet.address);
    }
    final DappIntent intent;
    try {
      intent = tx != null
          ? await intents.prepareTx(
              walletId: wallet.walletId,
              chainId: _chainId,
              origin: origin,
              tx: tx,
            )
          : await intents.prepareSign(
              walletId: wallet.walletId,
              chainId: _chainId,
              origin: origin,
              request: sign!,
            );
    } on LoopChainException catch (failure) {
      throw _prepareFailure(failure);
    }
    final outcome = await host.confirmIntent(
      intent: intent,
      wallet: wallet,
      tx: tx,
      sign: sign,
    );
    switch (outcome.status) {
      case DappSignStatus.produced:
        return outcome.value;
      case DappSignStatus.rejected:
        throw const DappRpcError(
          DappRpcErrorCode.userRejected,
          'User rejected the request',
        );
      case DappSignStatus.failed:
        throw DappRpcError(DappRpcErrorCode.internal, outcome.reasonCode);
    }
  }

  DappRpcError _prepareFailure(LoopChainException failure) {
    if (failure.reasonCode == 'CHAIN_SIGNING_DISABLED') {
      host.toast(dappMainnetSigningText);
      return const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'Signing is not available on this network',
      );
    }
    final text = dappPrepareFailureText(failure);
    if (text != null) host.toast(text);
    return DappRpcError(
      DappRpcErrorCode.internal,
      failure.reasonCode ?? failure.kind.name,
    );
  }

  static final RegExp _address = RegExp(r'^0x[0-9a-fA-F]{40}$');
  static final RegExp _hexData = RegExp(r'^0x([0-9a-fA-F]{2})*$');
  static final RegExp _quantity = RegExp(r'^0x[0-9a-fA-F]{1,64}$');

  /// `eth_sendTransaction`'s one object. `from`, when present, must be the
  /// connected wallet; a contract creation (no `to`) is not served.
  static DappTxRequest parseTxRequest(List<Object?> params, String address) {
    final raw = params.isEmpty ? null : params.first;
    if (raw is! Map) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid transaction',
      );
    }
    final from = raw['from'];
    if (from != null &&
        (from is! String || from.toLowerCase() != address.toLowerCase())) {
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'The requested account is not connected',
      );
    }
    final to = raw['to'];
    if (to is! String || !_address.hasMatch(to)) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid transaction',
      );
    }
    final data = raw['data'] ?? raw['input'] ?? '0x';
    if (data is! String || !_hexData.hasMatch(data) || data.length > 65536) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid transaction',
      );
    }
    final value = raw['value'] ?? '0x0';
    if (value is! String || !_quantity.hasMatch(value)) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid transaction',
      );
    }
    return DappTxRequest(
      to: to.toLowerCase(),
      data: data.toLowerCase(),
      value: BigInt.parse(value.substring(2), radix: 16),
    );
  }

  /// `personal_sign` is `[message, address]`; `eth_signTypedData_v4` is
  /// `[address, typedData]`, the typed data as JSON text or an object.
  static DappSignRequest parseSignRequest(
    String method,
    List<Object?> params,
    String address,
  ) {
    if (params.length < 2) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid params',
      );
    }
    final Object? signer;
    final Object? payload;
    if (method == 'personal_sign') {
      payload = params[0];
      signer = params[1];
    } else {
      signer = params[0];
      payload = params[1] is Map ? jsonEncode(params[1]) : params[1];
    }
    if (signer is! String || signer.toLowerCase() != address.toLowerCase()) {
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'The requested account is not connected',
      );
    }
    if (payload is! String || payload.isEmpty || payload.length > 65536) {
      throw const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid params',
      );
    }
    if (method == 'eth_signTypedData_v4') {
      final Object? typed;
      try {
        typed = jsonDecode(payload);
      } on Object {
        throw const DappRpcError(
          DappRpcErrorCode.invalidParams,
          'Invalid typed data',
        );
      }
      if (typed is! Map || typed['domain'] is! Map || typed['types'] is! Map) {
        throw const DappRpcError(
          DappRpcErrorCode.invalidParams,
          'Invalid typed data',
        );
      }
    }
    return DappSignRequest(method: method, payload: payload);
  }

  /// The script that raises [event] on the page.
  String emitScript(String event, Object? data) =>
      DappBridgeProtocol.emitScript(nonce, event, data);
}

/// The short line for a prepare the server refused, or `null` when the page
/// alone hears about it.
String? dappPrepareFailureText(LoopChainException failure) =>
    switch (failure.kind) {
      LoopChainFailureKind.offline ||
      LoopChainFailureKind.timedOut => '网络不可用，请稍后再试',
      LoopChainFailureKind.unavailable => '暂不支持在这个页面签名',
      LoopChainFailureKind.insufficientBalance => '余额不足以支付这笔交易',
      _ => '这笔请求没有通过检查',
    };
