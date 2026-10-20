/// Where every remote picture's bytes come from (decision 0215).
///
/// Order: memory (Flutter's `ImageCache`, in front of this) → this device's
/// copy ([LoopImageDiskCache]) → the network. A copy within its server-given
/// lifetime is the answer. A stale copy is still the answer — it is drawn at
/// once — and the address is asked again in the background; the new bytes,
/// if any, replace it. When the network fails the stale copy simply stays.
/// Only an address with no copy at all waits on the network, and only then
/// does a failure reach the caller (which keeps its placeholder).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/cache/loop_image_disk_cache.dart';
import 'package:loop_mobile/integrations/media/loop_image_fetch.dart';

/// The lifetime given to a copy when the server sent no `max-age`.
const Duration loopImageDefaultMaxAge = Duration(days: 1);

/// What one load produced: the bytes to draw now and, when those were a
/// stale copy, the background refresh (completing with new bytes, or `null`
/// when nothing changed or the network failed).
@immutable
final class LoopImageLoad {
  const LoopImageLoad(this.bytes, {this.refreshed, this.fromDisk = false});

  final Uint8List bytes;

  /// Whether [bytes] are this device's copy rather than a download.
  final bool fromDisk;
  final Future<Uint8List?>? refreshed;
}

final class LoopImageLoader {
  LoopImageLoader({
    LoopImageDiskCache? cache,
    DateTime Function()? clock,
    Future<LoopImageDownload> Function(Uri uri)? download,
  }) : _cacheOverride = cache,
       _clock = clock ?? DateTime.now,
       _download = download ?? loopImageDownload;

  /// The process-wide loader every remote picture reads through.
  static LoopImageLoader instance = LoopImageLoader();

  final LoopImageDiskCache? _cacheOverride;
  final DateTime Function() _clock;
  final Future<LoopImageDownload> Function(Uri uri) _download;

  LoopImageDiskCache get cache => _cacheOverride ?? LoopImageDiskCache.instance;

  /// Downloads in flight, by address, so a row, a page and the prefetch
  /// asking for one picture at once share one request.
  final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};

  /// The bytes for [url]: a fresh copy, a stale copy (with a refresh), or a
  /// download. Throws only when there is no copy and the download fails.
  Future<LoopImageLoad> load(String url) async {
    final kept = await cache.read(url);
    if (kept != null) {
      if (kept.isFreshAt(_clock())) {
        return LoopImageLoad(kept.bytes, fromDisk: true);
      }
      final refreshed = fetch(url).then<Uint8List?>(
        (bytes) => listEquals(bytes, kept.bytes) ? null : bytes,
        onError: (Object _) => null,
      );
      return LoopImageLoad(kept.bytes, refreshed: refreshed, fromDisk: true);
    }
    return LoopImageLoad(await fetch(url));
  }

  /// Downloads [url] and keeps the copy (unless the server said
  /// `no-store`). Concurrent calls for one address share the request.
  Future<Uint8List> fetch(String url) {
    final running = _inFlight[url];
    if (running != null) return running;
    // The callback must not return the removed future: `whenComplete` would
    // then wait on the request it belongs to.
    final request = _fetch(url).whenComplete(() {
      _inFlight.remove(url);
    });
    _inFlight[url] = request;
    return request;
  }

  Future<Uint8List> _fetch(String url) async {
    final download = await _download(Uri.parse(url));
    if (!download.noStore) {
      // Awaited so a reader right after sees the copy; never throws.
      await cache.write(
        url,
        download.bytes,
        maxAge: download.maxAge ?? loopImageDefaultMaxAge,
      );
    }
    return download.bytes;
  }

  /// Makes sure each of [urls] has a fresh copy on this device, at most
  /// [concurrency] downloads at a time and at most [limit] addresses (the
  /// first ones — the rows a list shows first). Addresses with a fresh copy
  /// cost one file read. Failures are ignored: the row will ask again.
  Future<void> prefetch(
    Iterable<String> urls, {
    int concurrency = loopImagePrefetchConcurrency,
    int limit = loopImagePrefetchLimit,
  }) async {
    final queue = urls
        .where((url) => url.isNotEmpty)
        .toSet()
        .take(limit)
        .toList();
    if (queue.isEmpty) return;
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final url = queue[next++];
        try {
          final kept = await cache.read(url);
          if (kept != null && kept.isFreshAt(_clock())) continue;
          await fetch(url);
        } on Object {
          continue;
        }
      }
    }

    final workers = concurrency < 1 ? 1 : concurrency;
    await Future.wait<void>(<Future<void>>[
      for (var i = 0; i < workers && i < queue.length; i++) worker(),
    ]);
  }
}

/// At most this many prefetch downloads run at once.
const int loopImagePrefetchConcurrency = 4;

/// A prefetch looks at no more than this many addresses: the first screen of
/// a list, not the whole list.
const int loopImagePrefetchLimit = 24;

/// Prefetches the pictures at [urls] (decision 0215 §4): what a list is about
/// to show, in the order it shows them. Fire and forget.
void loopPrefetchImages(Iterable<String?> urls) {
  final wanted = <String>[
    for (final url in urls)
      if (url != null && loopImageAddressAllowed(url)) url,
  ];
  if (wanted.isEmpty) return;
  unawaited(LoopImageLoader.instance.prefetch(wanted));
}

/// Whether [url] is an address this client fetches pictures from: HTTPS, or
/// HTTP to this machine in a debug build (the same rule as the logo rows).
bool loopImageAddressAllowed(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;
  if (uri.scheme == 'https') return true;
  final host = uri.host.toLowerCase();
  final loopback = host == 'localhost' || host == '127.0.0.1' || host == '::1';
  return uri.scheme == 'http' && loopback && !kReleaseMode;
}
