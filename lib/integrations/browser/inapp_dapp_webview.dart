import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';

/// The DApp browser's WebView (S342 · decision 0270), on
/// `flutter_inappwebview` 6.1.5.
///
/// Hardening: `https` main-frame navigations only (the page decides through
/// [DappWebViewConfig.shouldAllowNavigation]), no new windows — a
/// `window.open` loads in this WebView through the same check — no file or
/// content access, mixed content never allowed, Safe Browsing / fraudulent
/// site warnings on, and every camera, microphone, location or other device
/// permission a page asks for is denied. Cleartext `http` is refused by the
/// platform itself (Android network security default from API 28, iOS ATS);
/// a navigation that reached the main frame without
/// `shouldOverrideUrlLoading` (an Android POST form) is checked again when
/// it starts and stopped there, and the bridge never admits a document the
/// page did not allow (S346 · M12).
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
        _providerScript(config.documentStartScript),
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
        controller.addJavaScriptHandler(
          handlerName: config.readyHandlerName,
          callback: (arguments) =>
              config.onReady(List<Object?>.from(arguments)),
        );
        config.onCreated(_Controller(controller));
      },
      onLoadStart: (controller, url) {
        if (url != null) config.onLoadStart(url);
      },
      onLoadStop: (controller, url) {
        if (url != null) config.onLoadStop(url);
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
      // A `window.open` (iOS reaches here on a user gesture) loads in this
      // WebView, through the same check as any main-frame navigation.
      onCreateWindow: (controller, action) async {
        final url = action.request.url;
        if (url != null && config.shouldAllowNavigation(url)) {
          await controller.loadUrl(urlRequest: URLRequest(url: url));
        }
        return false;
      },
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

const String _providerGroup = 'loop-dapp-provider';

UserScript _providerScript(String source) => UserScript(
  groupName: _providerGroup,
  source: source,
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  forMainFrameOnly: true,
);

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

  @override
  Future<void> stop() => _controller.stopLoading();

  @override
  Future<void> setDocumentStartScript(String source) async {
    await _controller.removeUserScriptsByGroupName(groupName: _providerGroup);
    await _controller.addUserScript(userScript: _providerScript(source));
  }
}
