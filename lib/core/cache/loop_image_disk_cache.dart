/// The on-device copy of downloaded pictures (decision 0215).
///
/// One file per address, named by the SHA-256 of the address so no address
/// is written to disk, holding the downloaded bytes as they came. Beside it a
/// small sidecar records when the copy was taken and how long the server
/// said it stays fresh (`Cache-Control: max-age`). Reading touches the file,
/// and after a write the folder is trimmed, oldest-touched first, to
/// [LoopImageDiskCache.maxBytes] (64 MB) — a least-recently-used bound.
///
/// Every step is best effort: a directory that cannot be found, a file that
/// cannot be read or written, a sidecar that does not parse, all simply mean
/// "no copy" (or "a copy of unknown age", which counts as stale). Nothing
/// here can fail a picture — at worst it is downloaded, as it always was.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/crypto/loop_sha256.dart';
import 'package:path_provider/path_provider.dart';

/// One copy read from disk.
@immutable
final class LoopImageDiskEntry {
  const LoopImageDiskEntry({
    required this.bytes,
    required this.storedAt,
    required this.maxAge,
  });

  final Uint8List bytes;
  final DateTime storedAt;

  /// How long the server said the copy stays fresh; `null` means it gave no
  /// lifetime and the copy never goes stale on its own (content-addressed
  /// media).
  final Duration? maxAge;

  /// Whether the copy is still within its server-given lifetime at [now].
  bool isFreshAt(DateTime now) {
    final age = maxAge;
    if (age == null) return true;
    return now.difference(storedAt) < age;
  }
}

final class LoopImageDiskCache {
  LoopImageDiskCache({
    Future<Directory?> Function()? directory,
    this.maxBytes = defaultMaxBytes,
    DateTime Function()? clock,
  }) : _directoryOverride = directory,
       _clock = clock ?? DateTime.now;

  /// The process-wide cache every remote picture reads through.
  static LoopImageDiskCache instance = LoopImageDiskCache();

  /// The least-recently-used bound on the folder: 64 MB.
  static const int defaultMaxBytes = 64 * 1024 * 1024;

  /// The folder under the application cache directory. `v2` because the
  /// first copy (`loop_media_v1`, FNV names, no lifetime) is not read again;
  /// it is removed the first time this one opens.
  static const String folder = 'loop_images_v2';
  static const String _legacyFolder = 'loop_media_v1';

  final Future<Directory?> Function()? _directoryOverride;
  final DateTime Function() _clock;
  final int maxBytes;

  /// The folder, once a lookup has answered. Only the answer is kept, not
  /// the pending lookup: a lookup started in a zone that never runs again
  /// (a finished widget test) must not leave every later read waiting.
  Directory? _directory;
  bool _directoryKnown = false;
  Future<void>? _trimming;
  bool _trimAgain = false;

  /// The file name stem for [url]: the hex SHA-256 of its UTF-8 bytes.
  static String keyFor(String url) => loopSha256Hex(url);

  Future<Directory?> _resolve() async {
    if (_directoryKnown) return _directory;
    final directory = await _open();
    _directory = directory;
    _directoryKnown = true;
    return directory;
  }

  Future<Directory?> _open() async {
    try {
      final override = _directoryOverride;
      final base = override != null
          ? await override()
          : await getApplicationCacheDirectory();
      if (base == null) return null;
      final directory = Directory(_join(base.path, folder));
      await directory.create(recursive: true);
      if (override == null) {
        unawaited(_removeLegacy(base));
      }
      return directory;
    } on Object {
      return null;
    }
  }

  Future<void> _removeLegacy(Directory base) async {
    try {
      final legacy = Directory(_join(base.path, _legacyFolder));
      if (await legacy.exists()) await legacy.delete(recursive: true);
    } on Object {
      // Left for the system to clear with the rest of the cache directory.
    }
  }

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

  /// The copy for [url], or `null` when there is none. Touches the copy so
  /// the trim keeps it longer.
  Future<LoopImageDiskEntry?> read(String url) async {
    try {
      final directory = await _resolve();
      if (directory == null) return null;
      final stem = _join(directory.path, keyFor(url));
      final file = File('$stem.img');
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final now = _clock();
      unawaited(_touch(file, now));
      var storedAt = DateTime.fromMillisecondsSinceEpoch(0);
      Duration? maxAge = Duration.zero;
      try {
        final meta = jsonDecode(await File('$stem.meta').readAsString());
        if (meta is Map<String, Object?>) {
          final at = meta['storedAtMs'];
          final age = meta['maxAgeSeconds'];
          if (at is int) storedAt = DateTime.fromMillisecondsSinceEpoch(at);
          maxAge = age is int ? Duration(seconds: age) : null;
        }
      } on Object {
        // A copy of unknown age is used, and refreshed.
      }
      return LoopImageDiskEntry(
        bytes: bytes,
        storedAt: storedAt,
        maxAge: maxAge,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _touch(File file, DateTime now) async {
    try {
      await file.setLastModified(now);
    } on Object {
      // The order of the trim is a preference, not a promise.
    }
  }

  /// Keeps [bytes] as the copy for [url], fresh for [maxAge] from now
  /// (`null`: no server lifetime). Then trims the folder.
  Future<void> write(String url, Uint8List bytes, {Duration? maxAge}) async {
    try {
      if (bytes.isEmpty || bytes.length > maxBytes) return;
      final directory = await _resolve();
      if (directory == null) return;
      final stem = _join(directory.path, keyFor(url));
      final now = _clock();
      final meta = jsonEncode(<String, Object?>{
        'storedAtMs': now.millisecondsSinceEpoch,
        'maxAgeSeconds': maxAge?.inSeconds,
      });
      final stagingMeta = File('$stem.meta.tmp');
      await stagingMeta.writeAsString(meta, flush: true);
      await stagingMeta.rename('$stem.meta');
      final staging = File('$stem.img.tmp');
      await staging.writeAsBytes(bytes, flush: true);
      final file = await staging.rename('$stem.img');
      await _touch(file, now);
    } on Object {
      // A copy that cannot be kept is downloaded again next time.
      return;
    }
    await trim();
  }

  /// Removes the least-recently-touched copies until the folder holds at
  /// most [maxBytes]. Concurrent calls share one pass (and ask for one more
  /// when a write lands during it).
  Future<void> trim() {
    final running = _trimming;
    if (running != null) {
      _trimAgain = true;
      return running;
    }
    final pass = _trimPass().whenComplete(() => _trimming = null);
    return _trimming = pass;
  }

  Future<void> _trimPass() async {
    do {
      _trimAgain = false;
      try {
        final directory = await _resolve();
        if (directory == null) return;
        final copies = <({File file, int size, DateTime touched})>[];
        var total = 0;
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! File || !entity.path.endsWith('.img')) continue;
          try {
            final stat = await entity.stat();
            copies.add((file: entity, size: stat.size, touched: stat.modified));
            total += stat.size;
          } on Object {
            continue;
          }
        }
        if (total <= maxBytes) continue;
        copies.sort((a, b) => a.touched.compareTo(b.touched));
        for (final copy in copies) {
          if (total <= maxBytes) break;
          try {
            final path = copy.file.path;
            final stem = path.substring(0, path.length - '.img'.length);
            await copy.file.delete();
            final meta = File('$stem.meta');
            if (await meta.exists()) await meta.delete();
            total -= copy.size;
          } on Object {
            continue;
          }
        }
      } on Object {
        return;
      }
    } while (_trimAgain);
  }

  /// Forgets every copy. Tests and the 清除缓存 path only.
  Future<void> clear() async {
    try {
      final directory = await _resolve();
      if (directory == null) return;
      if (await directory.exists()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
    } on Object {
      return;
    }
  }
}
