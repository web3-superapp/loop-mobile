import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show immutable;
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
    required String origin,
    DappTxRequest? tx,
    DappSignRequest? sign,
  });

  /// Closes an open confirmation that has not reached the wallet, as a
  /// decline: the document that asked for it is gone (S346 · M1 / M5).
  void dismissSigning();

  /// One short line on screen.
  void toast(String message);

  /// Raises one EIP-1193 event on the page.
  Future<void> emit(String event, Object? data);

  /// The page's chain changed (top bar).
  void chainChanged(String chainId);

  /// The next document's boot nonce or chain changed: the page installs a
  /// new document-start script (S346 · M1 / M6).
  void documentScriptChanged();
}

/// The toast a signing request on BSC Mainnet shows (docs/55 §一).
const String dappMainnetSigningText = '暂不支持在这个网络签名';

/// The toast for `409 INTENT_BUSY`: another wallet action is open (S346).
const String dappIntentBusyText = '钱包有待处理的操作';

/// 128 random bits, hex.
String dappRandomSecret() {
  final random = Random.secure();
  return List<String>.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// One document's bridge credentials (S346 · M1): the token its requests
/// carry, the token its events carry, and the origin its own script read at
/// document start.
@immutable
final class _DappDocument {
  const _DappDocument({
    required this.token,
    required this.emitToken,
    required this.origin,
    required this.loadSeq,
  });

  final String token;
  final String emitToken;
  final String origin;

  /// How many documents had finished loading when this one shook hands.
  final int loadSeq;
}

/// Routes the EIP-1193 requests of one browser page.
///
/// It owns the page's chain and the bridge credentials of the document on
/// screen, and reads the connected sites from [isConnected] /
/// [setConnected]; it never decides an outcome on its own that the owner or
/// the server should decide.
///
/// Document lifecycle (S346 · M1). Each document's provider shakes hands
/// once with the boot nonce of the script it was given; the nonce is
/// replaced at once, so no other document — and no frame, which never gets
/// the script — can present it again. The answer is a token bound to the
/// origin that document read for itself. The token is honoured only once
/// the WebView reported that origin loaded ([documentLoaded]); from the
/// moment a main-frame navigation starts ([documentStarting]) every request
/// is refused (4100), in-flight signing is called off and its server intent
/// released.
final class DappBridge {
  DappBridge({
    required this.host,
    required this.intents,
    required this.reader,
    required this.isConnected,
    required this.setConnected,
    String chainId = loopLaunchTestnetChainId,
    String Function()? secrets,
  }) : _chainId = chainId, // ignore: prefer_initializing_formals
       _secret = secrets ?? dappRandomSecret {
    _boot = _secret();
  }

  final DappBridgeHost host;
  final DappIntentsGateway intents;
  final DappRpcReader reader;

  /// Whether [origin] is connected to the wallet [walletId] (S346 · M3).
  final bool Function(String walletId, String origin) isConnected;
  final Future<void> Function(
    String walletId,
    String origin, {
    required bool connected,
  })
  setConnected;

  final String Function() _secret;
  String _chainId;
  late String _boot;

  _DappDocument? _active;
  _DappDocument? _pending;
  String? _committedOrigin;
  bool _transitioning = false;
  bool _disposed = false;
  int _loadSeq = 0;

  /// Moves at every navigation start, new document and disposal; a signing
  /// request admitted under an older generation is called off.
  int _generation = 0;

  /// Requests refused by the admission check, for diagnostics and tests.
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

  /// The boot nonce the next document's script carries.
  String get bootNonce => _boot;

  /// The origin of the document the WebView last reported loaded, while no
  /// navigation is under way.
  String? get committedOrigin => _transitioning ? null : _committedOrigin;

  static const _signingMethods = <String>{
    'eth_sendTransaction',
    'personal_sign',
    'eth_signTypedData_v4',
  };

  static final RegExp _originPattern = RegExp(r'^https://[^/\s]{1,253}$');

  static const Map<String, Object?> _refusedHandshake = <String, Object?>{
    'ok': false,
  };

  // ---- document lifecycle -----------------------------------------------

  /// The handshake handler. [args] is what `callHandler` passed after the
  /// handler name: boot nonce, origin.
  Map<String, Object?> ready(List<Object?> args) {
    if (_disposed || args.length != 2) return _refusedHandshake;
    final boot = args[0];
    final origin = args[1];
    if (boot is! String || boot != _boot) {
      refusedFrames += 1;
      return _refusedHandshake;
    }
    // Spent: the next document gets a new one.
    _boot = _secret();
    host.documentScriptChanged();
    if (origin is! String || !_originPattern.hasMatch(origin)) {
      return _refusedHandshake;
    }
    _callOff();
    final document = _DappDocument(
      token: _secret(),
      emitToken: _secret(),
      origin: origin,
      loadSeq: _loadSeq,
    );
    _active = null;
    if (!_transitioning && _committedOrigin == origin) {
      // A page whose bridge came up after its load finished.
      _active = document;
    } else {
      _pending = document;
    }
    return <String, Object?>{
      'ok': true,
      'token': document.token,
      'emitToken': document.emitToken,
      'chainId': DappChains.hexOf(_chainId),
    };
  }

  /// A main-frame navigation to [url] started: nothing is admitted until a
  /// document finishes loading, and in-flight signing is called off.
  void documentStarting(Uri url) {
    if (_disposed) return;
    final active = _active;
    // On Android the start is reported after the new document already
    // shook hands; that document keeps its place.
    if (_pending == null &&
        active != null &&
        active.loadSeq == _loadSeq &&
        _originOf(url) == active.origin) {
      _pending = active;
    }
    _active = null;
    _transitioning = true;
    _callOff();
  }

  /// The WebView reports [url] loaded in the main frame.
  void documentLoaded(Uri url) {
    if (_disposed) return;
    _loadSeq += 1;
    _transitioning = false;
    _committedOrigin = _originOf(url);
    final pending = _pending;
    if (pending != null && pending.origin == _committedOrigin) {
      _active = pending;
      _pending = null;
    }
  }

  /// The page is closing.
  void dispose() {
    _disposed = true;
    _active = null;
    _pending = null;
    _callOff();
  }

  void _callOff() {
    _generation += 1;
    host.dismissSigning();
  }

  static String? _originOf(Uri url) {
    if (url.scheme != 'https' || url.host.isEmpty) return null;
    final origin = url.origin;
    return _originPattern.hasMatch(origin) ? origin : null;
  }

  // ---- requests -----------------------------------------------------------

  /// The JavaScript handler. [args] is what `callHandler` passed after the
  /// handler name: token, origin, isTopFrame, requestJson.
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

  /// The origin a request may act for, or `null`: no navigation under way,
  /// the token this document was handed, the top frame, and the origin that
  /// document read for itself — which must also be the origin the WebView
  /// reported loaded.
  String? _admittedOrigin(List<Object?> args) {
    if (_disposed || _transitioning) return null;
    final document = _active;
    if (document == null || args.length != 4) return null;
    if (args[0] != document.token) return null;
    if (args[2] != true) return null;
    if (args[1] != document.origin) return null;
    if (_committedOrigin != document.origin) return null;
    if (args[3] is! String) return null;
    return document.origin;
  }

  static const DappRpcError _calledOff = DappRpcError(
    DappRpcErrorCode.unauthorized,
    'Request refused',
  );

  void _stillCurrent(int generation) {
    if (generation != _generation) throw _calledOff;
  }

  /// One request, already admitted for [origin].
  Future<Object?> route({
    required String origin,
    required String method,
    required List<Object?> params,
  }) async {
    final generation = _generation;
    switch (method) {
      case 'eth_chainId':
        return DappChains.hexOf(_chainId);
      case 'net_version':
        return '${loopChainReference(_chainId)}';
      case 'eth_accounts':
        final wallet = host.wallet;
        if (wallet == null || !isConnected(wallet.walletId, origin)) {
          return const <String>[];
        }
        return <String>[wallet.address];
      case 'eth_requestAccounts':
        return _requestAccounts(origin, generation);
      case 'wallet_switchEthereumChain':
        return _switchChain(params);
      // The two chains are built in: adding one of them is switching to it,
      // any other chain is unrecognized (4902).
      case 'wallet_addEthereumChain':
        return _addChain(params);
      case 'eth_sendTransaction':
      case 'personal_sign':
      case 'eth_signTypedData_v4':
        return _serialSigning(() {
          // A request queued behind one the page navigated away from is
          // called off before it prepares anything.
          _stillCurrent(generation);
          return _sign(origin, method, params, generation);
        });
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
      // S346: the node provider refused on quota or rate grounds.
      if (failure.reasonCode == 'RPC_UPSTREAM_LIMITED') {
        throw const DappRpcError(
          DappRpcErrorCode.limitExceeded,
          'Request limit exceeded',
        );
      }
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

  Future<List<String>> _requestAccounts(String origin, int generation) async {
    final wallet = host.wallet;
    if (wallet == null) {
      throw const DappRpcError(
        DappRpcErrorCode.unauthorized,
        'Wallet unavailable',
      );
    }
    if (isConnected(wallet.walletId, origin)) return <String>[wallet.address];
    final agreed = await host.confirmConnection(origin: origin, wallet: wallet);
    // The owner agreed to the page that asked; a page that has gone since
    // is not connected by it.
    _stillCurrent(generation);
    if (!agreed) {
      throw const DappRpcError(
        DappRpcErrorCode.userRejected,
        'User rejected the request',
      );
    }
    await setConnected(wallet.walletId, origin, connected: true);
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
    // S346 · M6: documents that start from now on read the new chain.
    host.documentScriptChanged();
    await host.emit('chainChanged', DappChains.hexOf(chainId));
  }

  /// The owner disconnected [origin] from the menu.
  Future<void> disconnect(String origin) async {
    final wallet = host.wallet;
    if (wallet == null) return;
    await setConnected(wallet.walletId, origin, connected: false);
    if (committedOrigin == origin) {
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
    int generation,
  ) async {
    assert(_signingMethods.contains(method));
    final wallet = host.wallet;
    if (wallet == null || !isConnected(wallet.walletId, origin)) {
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
    // S346 · M5: from here every way out that is not a produced hash or
    // signature releases the server's intent.
    DappSignOutcome? outcome;
    try {
      _stillCurrent(generation);
      if (intent.origin != origin) {
        throw const DappRpcError(
          DappRpcErrorCode.internal,
          'REVIEW_PAYLOAD_MISMATCH',
        );
      }
      outcome = await host.confirmIntent(
        intent: intent,
        wallet: wallet,
        origin: origin,
        tx: tx,
        sign: sign,
      );
    } finally {
      if (outcome?.status != DappSignStatus.produced) {
        unawaited(
          intents.cancel(intentId: intent.intentId).catchError((Object _) {}),
        );
      }
    }
    final answer = outcome;
    switch (answer.status) {
      case DappSignStatus.produced:
        return answer.value;
      case DappSignStatus.rejected:
        throw const DappRpcError(
          DappRpcErrorCode.userRejected,
          'User rejected the request',
        );
      case DappSignStatus.failed:
        throw DappRpcError(DappRpcErrorCode.internal, answer.reasonCode);
    }
  }

  DappRpcError _prepareFailure(LoopChainException failure) {
    // S346: a send, swap, approval or NFT send is open on the wallet; the
    // server does not let a page displace it.
    if (failure.reasonCode == 'INTENT_BUSY') {
      host.toast(dappIntentBusyText);
      return const DappRpcError(
        DappRpcErrorCode.userRejected,
        'The wallet has a pending request',
      );
    }
    // S346: typed data the server cannot hash, or whose domain names another
    // chain, is the page's own malformed request — never a network to
    // switch to.
    if (failure.reasonCode == 'TYPED_DATA_INVALID' ||
        failure.reasonCode == 'TYPED_DATA_CHAIN_MISMATCH') {
      host.toast(dappPrepareFailureText(failure) ?? '这笔请求没有通过检查');
      return const DappRpcError(
        DappRpcErrorCode.invalidParams,
        'Invalid typed data',
      );
    }
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

  /// The script that raises [event] on the document on screen, or `null`
  /// when no document holds a token.
  String? emitScript(String event, Object? data) {
    final document = _active;
    if (document == null || _transitioning) return null;
    return DappBridgeProtocol.emitScript(document.emitToken, event, data);
  }
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
