import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// The side every remote avatar is decoded at, whatever size it is drawn at
/// (decision 0132).
///
/// The decode used to be sized to the slot, and Flutter's image cache keys a
/// resized image by its size: the 40 face at the head of 聊天 and the 56 face
/// on 我 were two decodes and two downloads of the same picture, so one could
/// be a picture while the other was still the monogram (audit 2026-10-09
/// m19). One size means one cache entry, shared by every slot. 256 covers the
/// largest slot (72) at a 3x screen.
const int loopMediaDecodeSide = 256;

/// An uploaded picture, read from this device's own copy when there is one.
///
/// Media addresses are content-addressed and immutable
/// (`/v2/media/{mediaId}.webp`), so a copy kept on disk is the picture for as
/// long as it is kept. The first frame after a cold start then draws the
/// picture instead of the monogram that a download would have put there
/// first. The copy lives in the application cache directory, which the system
/// may clear; a missing copy is simply downloaded again.
@immutable
final class LoopMediaImage extends ImageProvider<LoopMediaImage> {
  const LoopMediaImage(this.url);

  final String url;

  @override
  Future<LoopMediaImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<LoopMediaImage>(this);

  @override
  ImageStreamCompleter loadImage(
    LoopMediaImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: url,
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await LoopMediaDiskCache.instance.read(url) ?? await _fetch();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  Future<Uint8List> _fetch() async {
    final bytes = await loopMediaDownload(Uri.parse(url));
    unawaited(LoopMediaDiskCache.instance.write(url, bytes));
    return bytes;
  }

  @override
  bool operator ==(Object other) => other is LoopMediaImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'LoopMediaImage("$url")';
}

/// The largest picture this client keeps. An avatar is a few kilobytes.
const int loopMediaMaxBytes = 4 * 1024 * 1024;

/// Downloads one picture: a plain GET with no credentials, exactly what
/// `NetworkImage` sent before (decision 0112). Anything but a 200 with a
/// bounded body is a failure, and the caller keeps its fallback face.
Future<Uint8List> loopMediaDownload(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('media ${response.statusCode}', uri: uri);
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > loopMediaMaxBytes) {
        throw HttpException('media too large', uri: uri);
      }
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) throw HttpException('media empty', uri: uri);
    return bytes;
  } finally {
    client.close(force: false);
  }
}

/// The on-disk copies of downloaded pictures, one file per address.
///
/// Every step is best effort: a directory that cannot be found, a file that
/// cannot be read or written, all simply mean "no copy". Nothing here can
/// fail the picture — at worst it is downloaded, as it always was.
final class LoopMediaDiskCache {
  LoopMediaDiskCache._();

  static final LoopMediaDiskCache instance = LoopMediaDiskCache._();

  static const String _folder = 'loop_media_v1';

  static Future<Directory?> Function()? _debugDirectory;

  /// Replaced by tests. Setting it forgets the directory already resolved.
  @visibleForTesting
  static Future<Directory?> Function()? get debugDirectory => _debugDirectory;

  @visibleForTesting
  static set debugDirectory(Future<Directory?> Function()? value) {
    _debugDirectory = value;
    instance._directory = null;
  }

  Future<Directory?>? _directory;

  Future<Directory?> _resolve() => _directory ??= _open();

  Future<Directory?> _open() async {
    try {
      final override = _debugDirectory;
      final base = override != null
          ? await override()
          : await getApplicationCacheDirectory();
      if (base == null) return null;
      final directory = Directory(
        '${base.path}${Platform.pathSeparator}$_folder',
      );
      await directory.create(recursive: true);
      return directory;
    } on Object {
      return null;
    }
  }

  /// The file name for [url]: FNV-1a over its bytes, so the name carries no
  /// address.
  static String fileNameFor(String url) {
    var hash = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    for (final byte in utf8.encode(url)) {
      hash ^= byte;
      hash *= prime;
    }
    String half(int value) => value.toRadixString(16).padLeft(8, '0');
    return '${half((hash >>> 32) & 0xFFFFFFFF)}${half(hash & 0xFFFFFFFF)}.img';
  }

  Future<Uint8List?> read(String url) async {
    try {
      final directory = await _resolve();
      if (directory == null) return null;
      final file = File(
        '${directory.path}${Platform.pathSeparator}${fileNameFor(url)}',
      );
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } on Object {
      return null;
    }
  }

  Future<void> write(String url, Uint8List bytes) async {
    try {
      final directory = await _resolve();
      if (directory == null) return;
      final path =
          '${directory.path}${Platform.pathSeparator}${fileNameFor(url)}';
      final staging = File('$path.tmp');
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(path);
    } on Object {
      // A copy that cannot be kept is downloaded again next time.
    }
  }
}
