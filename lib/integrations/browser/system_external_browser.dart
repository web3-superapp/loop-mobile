import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an `https` page in the system browser, outside LOOP (decision 0196).
///
/// Returns false when the platform could not open it. It is called only on a
/// tap: nothing is prefetched, nothing is embedded, and LOOP learns nothing
/// about the page once it is handed over.
typedef LoopExternalBrowser = Future<bool> Function(Uri uri);

Future<bool> _openInSystemBrowser(Uri uri) async {
  if (uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

final loopExternalBrowserProvider = Provider<LoopExternalBrowser>(
  (ref) => _openInSystemBrowser,
);
