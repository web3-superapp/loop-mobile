import 'package:flutter/material.dart';
import 'package:loop_mobile/widgets/loop_media_image.dart';

/// Replaces the remote image provider (before resizing). Tests only.
@visibleForTesting
ImageProvider<Object> Function(String url)? debugLoopRemoteAvatarImageProvider;

/// A person's uploaded picture, drawn over the face LOOP would otherwise draw.
///
/// [fallback] — the monogram, the preset illustration, the neutral tile — is
/// on screen from the first frame and stays there until the picture's first
/// frame arrives; a failed or refused download simply leaves it in place. No
/// spinner and no layout shift: the slot is always [size] square.
///
/// Decoded pictures are held by Flutter's own [ImageCache], keyed by the
/// address alone: every slot decodes at [loopMediaDecodeSide], so a picture
/// decoded once in a chat row is the same cache entry on the profile page and
/// the member list, and is drawn there from the first frame (decision 0132).
/// Avatar addresses are content-addressed and immutable
/// (`/v2/media/{mediaId}.webp`), so the bytes are also kept on disk
/// ([LoopMediaImage]) and a cold start draws the picture, not the monogram.
class LoopRemoteAvatar extends StatelessWidget {
  const LoopRemoteAvatar({
    required this.url,
    required this.fallback,
    super.key,
    this.size = 34,
    this.shape = BoxShape.circle,
    this.radius,
    this.semanticLabel,
  });

  /// An address the caller already validated.
  final String url;
  final Widget fallback;
  final double size;
  final BoxShape shape;

  /// Corner radius when [shape] is [BoxShape.rectangle].
  final double? radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final source =
        debugLoopRemoteAvatarImageProvider?.call(url) ?? LoopMediaImage(url);
    final image = Image(
      key: const ValueKey<String>('loop-remote-avatar-image'),
      image: loopRemoteAvatarImage(source),
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          wasSynchronouslyLoaded || frame != null ? child : fallback,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
    return SizedBox(
      width: size,
      height: size,
      child: shape == BoxShape.circle
          ? ClipOval(child: image)
          : ClipRRect(
              borderRadius: BorderRadius.circular(radius ?? size / 4),
              child: image,
            ),
    );
  }
}

/// The one decode every remote avatar slot shares (decision 0132).
ImageProvider<Object> loopRemoteAvatarImage(ImageProvider<Object> source) =>
    ResizeImage(
      source,
      width: loopMediaDecodeSide,
      height: loopMediaDecodeSide,
      policy: ResizeImagePolicy.fit,
    );
