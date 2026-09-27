import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';

/// Which LOOP backend this build talks to, read from the build-time
/// `LOOP_BACKEND_BASE_URL` (decision 0100). Pure: no request is made, and the
/// value is the configured one even when the build-mode gate withholds it
/// from the network layer, so a misconfigured build can still be identified.

/// The host of [baseUrl], lower-cased, or `null` when none is configured or
/// the value is not an absolute URL.
String? loopBackendHost(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.toLowerCase() ?? '';
  return host.isEmpty ? null : host;
}

/// The short environment tag for [host]: `DEV`, `STAGING`, `LOCAL`, `PROD`,
/// or the first label (without an `api-` prefix) in upper case.
String loopBackendTier(String host) {
  final labels = host.split('.');
  final first = labels.first;
  final isIp = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  if (isIp || host == 'localhost' || host.endsWith('.local')) return 'LOCAL';
  final name = first.startsWith('api-') ? first.substring(4) : first;
  if (name == 'dev' || name.startsWith('dev-') || name.endsWith('-dev')) {
    return 'DEV';
  }
  if (name == 'staging' || name.contains('staging') || name == 'stg') {
    return 'STAGING';
  }
  if (name == 'api' || name == 'www') return 'PROD';
  final tag = name.toUpperCase();
  return tag.length > 10 ? tag.substring(0, 10) : tag;
}

/// The runtime mode of this binary, as Flutter compiled it.
String loopRuntimeBuildMode({bool? release, bool? profile}) {
  if (release ?? kReleaseMode) return 'release';
  if (profile ?? kProfileMode) return 'profile';
  return 'debug';
}

/// The tag drawn on the wallet hero, or `null` when none is drawn: a release
/// binary never shows one, and neither does a build with no backend.
String? loopEnvironmentTag(String baseUrl, {required bool release}) {
  if (release) return null;
  final host = loopBackendHost(baseUrl);
  return host == null ? null : loopBackendTier(host);
}

/// Whether this binary is a release build. A provider so a test can stand in
/// for `kReleaseMode`.
final loopReleaseBinaryProvider = Provider<bool>((ref) => kReleaseMode);

final loopEnvironmentTagProvider = Provider<String?>((ref) {
  final baseUrl = ref.watch(
    appConfigProvider.select((config) => config.backendBaseUrl),
  );
  return loopEnvironmentTag(
    baseUrl,
    release: ref.watch(loopReleaseBinaryProvider),
  );
});
