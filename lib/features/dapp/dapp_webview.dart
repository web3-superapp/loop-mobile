import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page's handle on its WebView (S342 · decision 0270). The production
/// implementation wraps `flutter_inappwebview`; a test supplies a double.
abstract interface class DappWebViewController {
  Future<void> load(Uri url);

  Future<void> goBack();

  Future<void> goForward();

  Future<void> reload();

  Future<bool> canGoBack();

  Future<bool> canGoForward();

  Future<void> evaluate(String source);
}

/// Why a main-frame load failed.
enum DappLoadFailure { offline, error }

/// Everything one WebView needs from its page.
@immutable
final class DappWebViewConfig {
  const DappWebViewConfig({
    required this.initialUrl,
    required this.documentStartScript,
    required this.handlerName,
    required this.onBridgeCall,
    required this.onCreated,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.onProgress,
    required this.onLoadFailed,
    required this.shouldAllowNavigation,
  });

  final Uri initialUrl;

  /// Injected at document start, top frame only.
  final String documentStartScript;

  /// The JavaScript handler name the script calls.
  final String handlerName;

  /// The handler: the arguments after the handler name in, the JSON answer
  /// out.
  final Future<Object?> Function(List<Object?> args) onBridgeCall;

  final void Function(DappWebViewController controller) onCreated;

  /// The top-level URL the WebView now reports.
  final void Function(Uri url) onUrlChanged;

  final void Function(String title) onTitleChanged;

  /// 0 … 1.
  final void Function(double progress) onProgress;

  final void Function(DappLoadFailure failure) onLoadFailed;

  /// Asked for every main-frame navigation; `false` cancels it.
  final bool Function(Uri url) shouldAllowNavigation;
}

/// Builds the WebView widget for one config.
abstract interface class DappWebViewFactory {
  bool get available;

  Widget build(DappWebViewConfig config);
}

/// The fail-closed default: a build without a WebView opens no page.
final class UnavailableDappWebViewFactory implements DappWebViewFactory {
  const UnavailableDappWebViewFactory();

  @override
  bool get available => false;

  @override
  Widget build(DappWebViewConfig config) => const SizedBox.shrink();
}

final dappWebViewFactoryProvider = Provider<DappWebViewFactory>(
  (ref) => const UnavailableDappWebViewFactory(),
);
