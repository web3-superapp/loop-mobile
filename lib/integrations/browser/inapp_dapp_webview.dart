import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';

/// The DApp browser's WebView (S342 · decision 0270), on
/// `flutter_inappwebview` 6.1.5.
///
/// Hardening: `https` main-frame navigations only (the page decides through
/// [DappWebViewConfig.shouldAllowNavigation]), no new windows, no file or
/// content access, mixed content never allowed, Safe Browsing / fraudulent
/// site warnings on, and every camera, microphone, location or other device
/// permission a page asks for is denied.
final class InAppDappWebViewFactory implements DappWebViewFactory {
  const InAppDappWebViewFactory();

  @override
  bool get available => true;

  @override
  Widget build(DappWebViewConfig config) => _InAppDappWebView(config: config);
}

class _InAppDappWebView extends StatelessWidget {
  const _InAppDappWebView({required this.config});

  final DappWebViewConfig config;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: const ValueKey<String>('dapp-inapp-webview'),
      initialUrlRequest: URLRequest(url: WebUri.uri(config.initialUrl)),
      initialUserScripts: UnmodifiableListView<UserScript>(<UserScript>[
        UserScript(
          groupName: 'loop-dapp-provider',
          source: config.documentStartScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: false,
        allowFileAccess: false,
        allowContentAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
        safeBrowsingEnabled: true,
        isFraudulentWebsiteWarningEnabled: true,
        geolocationEnabled: false,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,
        allowsBackForwardNavigationGestures: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: config.handlerName,
          callback: (arguments) =>
              config.onBridgeCall(List<Object?>.from(arguments)),
        );
        config.onCreated(_Controller(controller));
      },
      onLoadStart: (controller, url) {
        if (url != null) config.onUrlChanged(url);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        if (url != null) config.onUrlChanged(url);
      },
      onTitleChanged: (controller, title) {
        if (title != null) config.onTitleChanged(title);
      },
      onProgressChanged: (controller, progress) =>
          config.onProgress(progress.clamp(0, 100) / 100),
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        final offline =
            error.type == WebResourceErrorType.HOST_LOOKUP ||
            error.type == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
            error.type == WebResourceErrorType.TIMEOUT;
        config.onLoadFailed(
          offline ? DappLoadFailure.offline : DappLoadFailure.error,
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        if (!action.isForMainFrame) {
          // A frame may load `https` and the inert schemes a page uses for
          // its own frames; anything else (an app link, `javascript:`, a
          // wallet deep link) is cancelled.
          final scheme = url?.scheme.toLowerCase();
          return scheme == 'https' ||
                  scheme == 'about' ||
                  scheme == 'data' ||
                  scheme == 'blob'
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL;
        }
        if (url == null) return NavigationActionPolicy.CANCEL;
        return config.shouldAllowNavigation(url)
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCreateWindow: (controller, action) async => false,
      onPermissionRequest: (controller, request) async => PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      ),
      onGeolocationPermissionsShowPrompt: (controller, origin) async =>
          GeolocationPermissionShowPromptResponse(
            origin: origin,
            allow: false,
            retain: false,
          ),
    );
  }
}

final class _Controller implements DappWebViewController {
  _Controller(this._controller);

  final InAppWebViewController _controller;

  @override
  Future<void> load(Uri url) =>
      _controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(url)));

  @override
  Future<void> goBack() => _controller.goBack();

  @override
  Future<void> goForward() => _controller.goForward();

  @override
  Future<void> reload() => _controller.reload();

  @override
  Future<bool> canGoBack() => _controller.canGoBack();

  @override
  Future<bool> canGoForward() => _controller.canGoForward();

  @override
  Future<void> evaluate(String source) async {
    await _controller.evaluateJavascript(source: source);
  }
}
