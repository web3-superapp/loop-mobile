/// One picture download (decisions 0112, 0215).
///
/// A plain GET with no credentials — exactly what `NetworkImage` sent — so a
/// picture address never carries the session. Anything but a 200 with a
/// bounded, non-empty body is a failure; an HTTP status is reported as a
/// [NetworkImageLoadException] so `LoopTokenLogo` can still tell a definite
/// answer (4xx / 5xx) from a slow network (decision 0101).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The largest picture this client keeps. A logo is ~4 KiB, an avatar a few
/// tens.
const int loopImageMaxBytes = 4 * 1024 * 1024;

/// How long the first byte may take before the download is a failure.
const Duration loopImageConnectTimeout = Duration(seconds: 15);

/// A downloaded picture and what the server said about its lifetime.
@immutable
final class LoopImageDownload {
  const LoopImageDownload({
    required this.bytes,
    this.maxAge,
    this.noStore = false,
  });

  final Uint8List bytes;

  /// `Cache-Control: max-age`; `null` when absent. `s-maxage` is for shared
  /// caches and is not read.
  final Duration? maxAge;

  /// `Cache-Control: no-store`: the copy is drawn but never kept on disk.
  final bool noStore;
}

/// Parses the parts of `Cache-Control` the image cache honours.
///
/// `no-cache` keeps the copy but makes it stale at once (it is drawn, then
/// asked again); `no-store` keeps nothing; `max-age=N` is the lifetime.
({Duration? maxAge, bool noStore}) loopParseCacheControl(String? header) {
  if (header == null || header.trim().isEmpty) {
    return (maxAge: null, noStore: false);
  }
  Duration? maxAge;
  var noStore = false;
  var noCache = false;
  for (final raw in header.split(',')) {
    final part = raw.trim().toLowerCase();
    if (part == 'no-store') noStore = true;
    if (part == 'no-cache') noCache = true;
    final match = RegExp(r'^max-age\s*=\s*"?(\d+)"?$').firstMatch(part);
    if (match != null) {
      final seconds = int.tryParse(match.group(1)!);
      if (seconds != null) maxAge = Duration(seconds: seconds);
    }
  }
  if (noCache) maxAge = Duration.zero;
  return (maxAge: maxAge, noStore: noStore);
}

/// Replaces the network in tests. Each call is one download.
@visibleForTesting
Future<LoopImageDownload> Function(Uri uri)? debugLoopImageFetcher;

/// Downloads the picture at [uri].
Future<LoopImageDownload> loopImageDownload(Uri uri) async {
  final override = debugLoopImageFetcher;
  if (override != null) return override(uri);
  final client = HttpClient()..connectionTimeout = loopImageConnectTimeout;
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > loopImageMaxBytes) {
        throw HttpException('image too large', uri: uri);
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) throw HttpException('image empty', uri: uri);
    final control = loopParseCacheControl(
      response.headers.value(HttpHeaders.cacheControlHeader),
    );
    return LoopImageDownload(
      bytes: bytes,
      maxAge: control.maxAge,
      noStore: control.noStore,
    );
  } finally {
    client.close(force: false);
  }
}
