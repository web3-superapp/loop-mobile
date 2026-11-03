import 'dart:convert';

import 'package:loop_mobile/features/dapp/dapp_provider_icon.dart';

/// The JavaScript ↔ Dart bridge of the DApp browser (S342 · decision 0270,
/// S346 amendment).
///
/// Handshake, page → app: at document start the injected provider calls
/// `callHandler(readyHandlerName, bootNonce, origin)`. The boot nonce is in
/// the provider's closure only, it is accepted once and replaced at every
/// document, and the answer is
/// `{"ok": true, "token": …, "emitToken": …, "chainId": …}`: this document's
/// own request token, the token its events carry, and the chain.
///
/// Requests, page → app: `callHandler(handlerName, token, origin,
/// isTopFrame, requestJson)`, where `requestJson` is
/// `{"method": …, "params": […]}`. The app answers with
/// `{"ok": true, "result": …}` or
/// `{"ok": false, "error": {"code": …, "message": …}}`.
///
/// Events, app → page: `window[dispatcherName](emitToken, event, dataJson)`.
/// The dispatcher's name is fixed and carries no secret; it drops any call
/// whose token is not the one the closure was handed.
///
/// No nonce or token is ever written to a property of `window`.
abstract final class DappBridgeProtocol {
  static const handlerName = 'loopEthereum';

  static const readyHandlerName = 'loopEthereumReady';

  static const dispatcherName = '__loopEthereumDispatch';

  static const providerName = 'LOOP';

  static const providerRdns = 'cc.quant-dinger.loop';

  /// The JavaScript that raises [event] with [data] on the document holding
  /// [emitToken].
  static String emitScript(String emitToken, String event, Object? data) {
    final name = jsonEncode(dispatcherName);
    return '(function(){var f=window[$name];'
        'if(typeof f==="function"){f(${jsonEncode(emitToken)},'
        '${jsonEncode(event)},${jsonEncode(jsonEncode(data))});}})();';
  }
}

/// The document-start provider script.
///
/// [bootNonce] is the one-time handshake secret of the next document,
/// [chainIdHex] the chain a page starts on (`0x61` / `0x38`) and
/// [providerUuid] the EIP-6963 `info.uuid`.
String dappProviderScript({
  required String bootNonce,
  required String chainIdHex,
  required String providerUuid,
  String icon = dappProviderIconDataUri,
}) {
  final substitutions = <String, String>{
    '__LOOP_BOOT__': jsonEncode(bootNonce),
    '__LOOP_CHAIN__': jsonEncode(chainIdHex),
    '__LOOP_UUID__': jsonEncode(providerUuid),
    '__LOOP_ICON__': jsonEncode(icon),
    '__LOOP_HANDLER__': jsonEncode(DappBridgeProtocol.handlerName),
    '__LOOP_READY__': jsonEncode(DappBridgeProtocol.readyHandlerName),
    '__LOOP_DISPATCH__': jsonEncode(DappBridgeProtocol.dispatcherName),
    '__LOOP_NAME__': jsonEncode(DappBridgeProtocol.providerName),
    '__LOOP_RDNS__': jsonEncode(DappBridgeProtocol.providerRdns),
  };
  var script = _template;
  substitutions.forEach((key, value) => script = script.replaceAll(key, value));
  return script;
}

const String _template = r'''
(function () {
  "use strict";
  if (window.top !== window.self) { return; }
  if (window.ethereum && window.ethereum.isLoop) { return; }
  var BOOT = __LOOP_BOOT__;
  var HANDLER = __LOOP_HANDLER__;
  var READY = __LOOP_READY__;
  var ORIGIN = window.location.origin;
  var chainId = __LOOP_CHAIN__;
  var accounts = [];
  var listeners = {};
  var token = null;
  var emitToken = null;
  var handshake = null;
  var bridge = null;
  var queue = [];
  function capture() {
    if (bridge) { return true; }
    var host = window.flutter_inappwebview;
    if (!host || typeof host.callHandler !== "function") { return false; }
    var callHandler = host.callHandler;
    bridge = function () { return callHandler.apply(host, arguments); };
    return true;
  }
  capture();
  window.addEventListener("flutterInAppWebViewPlatformReady", function () {
    capture();
    var pending = queue; queue = [];
    for (var i = 0; i < pending.length; i++) { pending[i](); }
  });
  window.addEventListener("pageshow", function (event) {
    if (event.persisted) { window.location.reload(); }
  });
  function rpcError(code, message) {
    var error = new Error(message); error.code = code; return error;
  }
  function whenBridge(go) { if (capture()) { go(); } else { queue.push(go); } }
  function ready() {
    if (handshake) { return handshake; }
    var boot = BOOT; BOOT = null;
    handshake = new Promise(function (resolve) {
      whenBridge(function () {
        bridge(READY, boot, ORIGIN).then(function (answer) {
          if (answer && answer.ok === true && typeof answer.token === "string") {
            token = answer.token;
            emitToken = typeof answer.emitToken === "string" ? answer.emitToken : null;
            if (typeof answer.chainId === "string") { chainId = answer.chainId; }
          }
          resolve();
        }, function () { resolve(); });
      });
    });
    return handshake;
  }
  ready();
  function call(payload) {
    return ready().then(function () {
      if (token === null) { throw rpcError(4100, "Request refused"); }
      return bridge(HANDLER, token, ORIGIN, window.top === window.self,
        JSON.stringify(payload));
    }).then(function (answer) {
      if (answer && answer.ok === true) { return answer.result; }
      var e = (answer && answer.error) || {};
      throw rpcError(typeof e.code === "number" ? e.code : -32603,
        typeof e.message === "string" ? e.message : "Internal error");
    }, function (error) {
      if (error && typeof error.code === "number") { throw error; }
      throw rpcError(-32603, "Internal error");
    });
  }
  function emit(name, data) {
    var list = (listeners[name] || []).slice();
    for (var i = 0; i < list.length; i++) {
      try { list[i](data); } catch (ignored) {}
    }
  }
  var provider = {
    isLoop: true,
    isMetaMask: false,
    isConnected: function () { return true; },
    request: function (args) {
      if (!args || typeof args.method !== "string") {
        return Promise.reject(rpcError(-32600, "Invalid request"));
      }
      var params = args.params === undefined ? [] : args.params;
      return call({ method: args.method, params: params }).then(function (result) {
        if (args.method === "eth_requestAccounts" || args.method === "eth_accounts") {
          accounts = Array.isArray(result) ? result : [];
        }
        return result;
      });
    },
    enable: function () { return provider.request({ method: "eth_requestAccounts" }); },
    send: function (methodOrPayload, paramsOrCallback) {
      if (typeof methodOrPayload === "string") {
        return provider.request({ method: methodOrPayload, params: paramsOrCallback });
      }
      return provider.sendAsync(methodOrPayload, paramsOrCallback);
    },
    sendAsync: function (payload, callback) {
      provider.request({ method: payload.method, params: payload.params }).then(
        function (result) { callback(null, { id: payload.id, jsonrpc: "2.0", result: result }); },
        function (error) { callback(error, { id: payload.id, jsonrpc: "2.0", error: { code: error.code, message: error.message } }); }
      );
    },
    on: function (name, fn) {
      (listeners[name] = listeners[name] || []).push(fn); return provider;
    },
    removeListener: function (name, fn) {
      listeners[name] = (listeners[name] || []).filter(function (x) { return x !== fn; });
      return provider;
    },
    removeAllListeners: function (name) {
      if (name) { delete listeners[name]; } else { listeners = {}; }
      return provider;
    }
  };
  provider.addListener = provider.on;
  provider.off = provider.removeListener;
  Object.defineProperty(provider, "chainId", { get: function () { return chainId; } });
  Object.defineProperty(provider, "networkVersion", {
    get: function () { return String(parseInt(chainId, 16)); }
  });
  Object.defineProperty(provider, "selectedAddress", {
    get: function () { return accounts.length ? accounts[0] : null; }
  });
  try {
    Object.defineProperty(window, __LOOP_DISPATCH__, {
      value: function (presented, name, json) {
        if (emitToken === null || presented !== emitToken) { return; }
        var data = JSON.parse(json);
        if (name === "chainChanged") { chainId = data; }
        if (name === "accountsChanged") { accounts = Array.isArray(data) ? data : []; }
        emit(name, data);
      },
      enumerable: false, configurable: false, writable: false
    });
  } catch (ignored) {}
  Object.defineProperty(window, "ethereum", {
    value: provider, enumerable: true, configurable: true, writable: false
  });
  var info = Object.freeze({
    uuid: __LOOP_UUID__, name: __LOOP_NAME__, icon: __LOOP_ICON__, rdns: __LOOP_RDNS__
  });
  function announce() {
    window.dispatchEvent(new CustomEvent("eip6963:announceProvider", {
      detail: Object.freeze({ info: info, provider: provider })
    }));
  }
  window.addEventListener("eip6963:requestProvider", announce);
  announce();
  window.dispatchEvent(new Event("ethereum#initialized"));
  setTimeout(function () { emit("connect", { chainId: chainId }); }, 0);
})();
''';
