import 'dart:convert';

import 'package:loop_mobile/features/dapp/dapp_provider_icon.dart';

/// The JavaScript ↔ Dart bridge of the DApp browser (S342 · decision 0270).
///
/// Protocol, page → app: the injected provider calls
/// `window.flutter_inappwebview.callHandler(handlerName, nonce, origin,
/// isTopFrame, requestJson)`, where `requestJson` is
/// `{"method": …, "params": […]}`. The app answers with
/// `{"ok": true, "result": …}` or
/// `{"ok": false, "error": {"code": …, "message": …}}`.
///
/// App → page: `window["__loopEmit_" + nonce](eventName, dataJson)` raises
/// one EIP-1193 event (`accountsChanged`, `chainChanged`, `connect`,
/// `disconnect`).
///
/// The script runs at document start in the top frame only, and the nonce is
/// new for every browser page. A frame that never received the script — any
/// cross-origin iframe — cannot name the nonce, and the app also compares the
/// claimed origin with the origin of the top-level URL the WebView reports.
abstract final class DappBridgeProtocol {
  static const handlerName = 'loopEthereum';

  static const emitPrefix = '__loopEmit_';

  static const providerName = 'LOOP';

  static const providerRdns = 'cc.quant-dinger.loop';

  /// The JavaScript that raises [event] with [data] on the page.
  static String emitScript(String nonce, String event, Object? data) {
    final name = jsonEncode('$emitPrefix$nonce');
    return '(function(){var f=window[$name];'
        'if(typeof f==="function"){f(${jsonEncode(event)},'
        '${jsonEncode(jsonEncode(data))});}})();';
  }
}

/// The document-start provider script for one browser page.
///
/// [nonce] is the page's bridge secret, [chainIdHex] the chain the page
/// starts on (`0x61` / `0x38`) and [providerUuid] the EIP-6963 `info.uuid`.
String dappProviderScript({
  required String nonce,
  required String chainIdHex,
  required String providerUuid,
  String icon = dappProviderIconDataUri,
}) {
  final substitutions = <String, String>{
    '__LOOP_NONCE__': jsonEncode(nonce),
    '__LOOP_CHAIN__': jsonEncode(chainIdHex),
    '__LOOP_UUID__': jsonEncode(providerUuid),
    '__LOOP_ICON__': jsonEncode(icon),
    '__LOOP_HANDLER__': jsonEncode(DappBridgeProtocol.handlerName),
    '__LOOP_EMIT__': jsonEncode(DappBridgeProtocol.emitPrefix),
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
  var NONCE = __LOOP_NONCE__;
  var HANDLER = __LOOP_HANDLER__;
  var chainId = __LOOP_CHAIN__;
  var accounts = [];
  var listeners = {};
  var queue = [];
  function bridgeReady() {
    return !!(window.flutter_inappwebview &&
      typeof window.flutter_inappwebview.callHandler === "function");
  }
  window.addEventListener("flutterInAppWebViewPlatformReady", function () {
    var pending = queue; queue = [];
    for (var i = 0; i < pending.length; i++) { pending[i](); }
  });
  function rpcError(code, message) {
    var error = new Error(message); error.code = code; return error;
  }
  function call(payload) {
    return new Promise(function (resolve, reject) {
      function go() {
        window.flutter_inappwebview.callHandler(
          HANDLER, NONCE, window.location.origin, window.top === window.self,
          JSON.stringify(payload)
        ).then(function (answer) {
          if (answer && answer.ok === true) { resolve(answer.result); return; }
          var e = (answer && answer.error) || {};
          reject(rpcError(typeof e.code === "number" ? e.code : -32603,
            typeof e.message === "string" ? e.message : "Internal error"));
        }, function () { reject(rpcError(-32603, "Internal error")); });
      }
      if (bridgeReady()) { go(); } else { queue.push(go); }
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
  Object.defineProperty(window, __LOOP_EMIT__ + NONCE, {
    value: function (name, json) {
      var data = JSON.parse(json);
      if (name === "chainChanged") { chainId = data; }
      if (name === "accountsChanged") { accounts = Array.isArray(data) ? data : []; }
      emit(name, data);
    },
    enumerable: false, configurable: false, writable: false
  });
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
