import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:loop_mobile/integrations/media/loop_image_loader.dart';

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

/// A remote picture — an uploaded avatar or a token logo — read from this
/// device's own copy when there is one (decision 0215).
///
/// Order: Flutter's [ImageCache] (memory, keyed by this provider) → the disk
/// copy → the network, through [LoopImageLoader]. A copy past its
/// `Cache-Control: max-age` is drawn at once and asked again in the
/// background; when new bytes arrive the stream's frame is replaced, so the
/// slot changes picture without passing through its placeholder. A slot
/// whose address has no copy and cannot be downloaded gets the error, and
/// keeps its fallback face, exactly as before.
///
/// Only the first frame of a picture is drawn: avatars (decision 0095) and
/// logos (decision 0161) are single-frame WebP.
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
  ) => LoopRefreshingImageCompleter(
    _load(decode),
    debugLabel: url,
    informationCollector: () => <DiagnosticsNode>[
      DiagnosticsProperty<ImageProvider>('Image provider', this),
    ],
  );

  Future<(ui.Codec, Future<ui.Codec?>?)> _load(
    ImageDecoderCallback decode,
  ) async {
    final loader = LoopImageLoader.instance;
    final load = await loader.load(url);
    ui.Codec codec;
    try {
      codec = await _decode(load.bytes, decode);
    } on Object {
      // A copy on disk that no longer decodes is replaced by a download.
      if (!load.fromDisk) rethrow;
      codec = await _decode(await loader.fetch(url), decode);
      return (codec, null);
    }
    final refreshed = load.refreshed?.then<ui.Codec?>(
      (bytes) => bytes == null ? null : _decode(bytes, decode),
      onError: (Object _) => null,
    );
    return (codec, refreshed);
  }

  static Future<ui.Codec> _decode(
    Uint8List bytes,
    ImageDecoderCallback decode,
  ) async => decode(await ui.ImmutableBuffer.fromUint8List(bytes));

  @override
  bool operator ==(Object other) => other is LoopMediaImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'LoopMediaImage("$url")';
}

/// A single-frame image stream whose frame may be replaced once: the first
/// codec is the picture drawn now, the optional second one (a background
/// refresh of a stale copy) replaces it when it arrives.
class LoopRefreshingImageCompleter extends ImageStreamCompleter {
  LoopRefreshingImageCompleter(
    Future<(ui.Codec, Future<ui.Codec?>?)> codecs, {
    String? debugLabel,
    InformationCollector? informationCollector,
  }) : _collector = informationCollector {
    this.debugLabel = debugLabel;
    codecs.then<void>((pair) async {
      final (first, later) = pair;
      await _show(first, reportErrors: true);
      if (later == null) return;
      final next = await later;
      if (next != null) await _show(next, reportErrors: false);
    }, onError: (Object error, StackTrace stack) => _report(error, stack));
  }

  final InformationCollector? _collector;
  bool _gone = false;

  Future<void> _show(ui.Codec codec, {required bool reportErrors}) async {
    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } on Object catch (error, stack) {
      if (reportErrors) _report(error, stack);
      return;
    } finally {
      codec.dispose();
    }
    if (_gone) {
      frame.image.dispose();
      return;
    }
    setImage(ImageInfo(image: frame.image, debugLabel: debugLabel));
  }

  void _report(Object error, StackTrace stack) {
    if (_gone) return;
    reportError(
      context: ErrorDescription('resolving a LOOP remote picture'),
      exception: error,
      stack: stack,
      informationCollector: _collector,
      silent: true,
    );
  }

  @override
  void onDisposed() {
    _gone = true;
    super.onDisposed();
  }
}
