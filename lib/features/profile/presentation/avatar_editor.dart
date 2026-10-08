import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// The edge of the square the device uploads. The server re-encodes to
/// 512 px WebP; a little headroom keeps the downscale sharp.
const int avatarCropOutputEdge = 768;

/// The region of the picture a square viewport shows.
///
/// [viewport] is the square's edge in logical pixels and [transform] the
/// viewer's matrix (picture → viewport). The answer is in picture pixels,
/// clamped to the picture — the viewer's own bounds already keep it inside,
/// the clamp only absorbs rounding.
@visibleForTesting
Rect avatarCropRect({
  required double viewport,
  required Matrix4 transform,
  required Size image,
}) {
  final inverse = Matrix4.inverted(transform);
  final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
  final bottomRight = MatrixUtils.transformPoint(
    inverse,
    Offset(viewport, viewport),
  );
  final rect = Rect.fromPoints(topLeft, bottomRight);
  return Rect.fromLTRB(
    rect.left.clamp(0, image.width),
    rect.top.clamp(0, image.height),
    rect.right.clamp(0, image.width),
    rect.bottom.clamp(0, image.height),
  );
}

/// The matrix that shows the centre square of [image] filling [viewport].
@visibleForTesting
Matrix4 avatarCropInitialTransform({
  required double viewport,
  required Size image,
}) {
  final scale = avatarCropCoverScale(viewport: viewport, image: image);
  final dx = (viewport - image.width * scale) / 2;
  final dy = (viewport - image.height * scale) / 2;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

/// The smallest scale at which the picture still covers the whole square.
@visibleForTesting
double avatarCropCoverScale({required double viewport, required Size image}) =>
    math.max(viewport / image.width, viewport / image.height);

/// Opens the square crop over [bytes] and returns the PNG of the chosen
/// square, or `null` when the person cancelled or the picture could not be
/// read.
Future<Uint8List?> showAvatarCropDialog(
  BuildContext context,
  Uint8List bytes,
) async {
  final ui.Image image;
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    image = (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
  if (!context.mounted) {
    image.dispose();
    return null;
  }
  try {
    return await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      barrierColor: LoopColors.ink,
      builder: (dialogContext) => _AvatarCropDialog(image: image),
    );
  } finally {
    image.dispose();
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});

  final ui.Image image;

  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  final _transform = TransformationController();
  double? _viewport;
  var _busy = false;

  Size get _imageSize =>
      Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final viewport = _viewport;
    if (viewport == null || _busy) return;
    setState(() => _busy = true);
    final source = avatarCropRect(
      viewport: viewport,
      transform: _transform.value,
      image: _imageSize,
    );
    final recorder = ui.PictureRecorder();
    const edge = avatarCropOutputEdge;
    Canvas(recorder).drawImageRect(
      widget.image,
      source,
      const Rect.fromLTWH(0, 0, edge * 1.0, edge * 1.0),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(edge, edge);
    picture.dispose();
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (!mounted) return;
    Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('avatar-crop-dialog'),
      color: LoopColors.ink,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '裁剪头像',
                style: LoopTypography.title(17, color: LoopColors.chalk),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '拖动、双指缩放，方框里的部分就是头像。',
                style: LoopTypography.caption(12, color: LoopColors.text2),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = math.min(
                    constraints.maxWidth - 32,
                    constraints.maxHeight - 16,
                  );
                  if (_viewport != viewport) {
                    _viewport = viewport;
                    _transform.value = avatarCropInitialTransform(
                      viewport: viewport,
                      image: _imageSize,
                    );
                  }
                  final cover = avatarCropCoverScale(
                    viewport: viewport,
                    image: _imageSize,
                  );
                  return Center(
                    child: Container(
                      width: viewport,
                      height: viewport,
                      decoration: BoxDecoration(
                        border: Border.all(color: LoopColors.lime, width: 2),
                      ),
                      child: ClipRect(
                        child: InteractiveViewer(
                          key: const ValueKey<String>('avatar-crop-viewer'),
                          transformationController: _transform,
                          constrained: false,
                          minScale: cover,
                          maxScale: cover * 6,
                          boundaryMargin: EdgeInsets.zero,
                          child: SizedBox(
                            width: _imageSize.width,
                            height: _imageSize.height,
                            child: RawImage(image: widget.image),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: LoopButton(
                      key: const ValueKey<String>('avatar-crop-cancel'),
                      label: '取消',
                      block: true,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LoopButton(
                      key: const ValueKey<String>('avatar-crop-confirm'),
                      label: _busy ? '处理中…' : '使用这张',
                      primary: true,
                      block: true,
                      onPressed: _busy ? null : () => unawaited(_confirm()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the crop step in a page test, which has no image codec to run
/// the real one with. Tests only.
@visibleForTesting
Future<Uint8List?> Function(BuildContext context, Uint8List bytes)?
debugAvatarCropOverride;

/// Whether this account may upload a picture now.
///
/// Production needs both halves: the server's `avatarUpload` capability and
/// an assembled transport. The labelled Preview runs on its in-memory
/// gateway and needs neither. Without a picker there is nothing to open.
bool avatarUploadUsable(WidgetRef ref) {
  final gateway = ref.watch(avatarUploadGatewayProvider);
  final picker = ref.watch(avatarImagePickerProvider);
  if (!picker.available) return false;
  return switch (gateway.mode) {
    AvatarUploadMode.unavailable => false,
    AvatarUploadMode.preview => true,
    AvatarUploadMode.production =>
      ref
          .watch(loopCapabilityProvider(LoopV2CapabilityId.avatarUpload))
          .isUsable,
  };
}

/// The one avatar control registration and profile editing share
/// (S107 §4, decision 0112).
///
/// The face is the monogram until a picture is uploaded. 「上传头像」 opens the
/// library, then the square crop, then sends the square; only an answered
/// upload changes [avatarRef]. 「用默认头像」 goes back to the monogram. While
/// upload is closed the button stays visible but disabled, and one line says
/// why.
class LoopAvatarEditor extends ConsumerStatefulWidget {
  const LoopAvatarEditor({
    required this.avatarRef,
    required this.alias,
    required this.enabled,
    required this.onChanged,
    super.key,
    this.size = 88,
  });

  final String? avatarRef;
  final String? alias;
  final bool enabled;

  /// The new reference: an uploaded `avatar:media/…`, or `null` for the
  /// monogram.
  final ValueChanged<String?> onChanged;
  final double size;

  @override
  ConsumerState<LoopAvatarEditor> createState() => _LoopAvatarEditorState();
}

class _LoopAvatarEditorState extends ConsumerState<LoopAvatarEditor> {
  var _uploading = false;
  AvatarUploadFailureKind? _failure;

  Future<void> _upload() async {
    if (_uploading) return;
    setState(() {
      _failure = null;
      _uploading = true;
    });
    try {
      final picked = await ref.read(avatarImagePickerProvider).pick();
      if (picked == null || !mounted) return;
      final crop = debugAvatarCropOverride ?? showAvatarCropDialog;
      final square = await crop(context, picked.bytes);
      if (square == null || !mounted) return;
      final uploaded = await ref
          .read(avatarUploadGatewayProvider)
          .upload(bytes: square, contentType: 'image/png');
      if (!mounted) return;
      widget.onChanged(uploaded.avatarRef);
    } on AvatarUploadException catch (error) {
      if (mounted) setState(() => _failure = error.kind);
    } catch (_) {
      if (mounted) {
        setState(() => _failure = AvatarUploadFailureKind.unexpected);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usable = avatarUploadUsable(ref);
    final failure = _failure;
    final custom = widget.avatarRef != null;
    return Column(
      key: const ValueKey<String>('loop-avatar-editor'),
      children: <Widget>[
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            LoopProfileAvatar(
              avatarRef: widget.avatarRef,
              alias: widget.alias,
              size: widget.size,
            ),
            if (_uploading)
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: LoopColors.veil,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('loop-avatar-upload'),
              label: _uploading ? '上传中…' : '上传头像',
              icon: 'camera',
              onPressed: widget.enabled && usable && !_uploading
                  ? () => unawaited(_upload())
                  : null,
            ),
            if (custom)
              LoopButton(
                key: const ValueKey<String>('loop-avatar-reset'),
                label: '用默认头像',
                onPressed: widget.enabled && !_uploading
                    ? () => widget.onChanged(null)
                    : null,
              ),
          ],
        ),
        if (!usable) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            key: const ValueKey<String>('loop-avatar-upload-unavailable'),
            '头像上传暂未开放，先用默认头像。',
            textAlign: TextAlign.center,
            style: LoopTypography.caption(
              12,
              color: LoopGround.auxiliaryOf(context),
            ),
          ),
        ] else if (failure != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            key: ValueKey<String>('loop-avatar-upload-failure-${failure.name}'),
            avatarUploadFailureReason(failure),
            textAlign: TextAlign.center,
            style: LoopTypography.caption(12, color: LoopColors.danger),
          ),
        ],
      ],
    );
  }
}
