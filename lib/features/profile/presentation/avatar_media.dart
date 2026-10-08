import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Uploaded pictures (S107 §1, decision 0112).
///
/// A person's avatar and a community's logo are opaque references:
/// `avatar:media/{mediaId}` and `logo:media/{mediaId}`. The client never
/// stores an address; it resolves the reference against the backend it talks
/// to, through [LoopMediaUrlResolver], whose production implementation lives
/// with the other backend adapters.

const String _uuid =
    r'[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';

/// `avatar:media/{uuid}` — a picture the account uploaded itself.
final RegExp loopAvatarMediaRefPattern = RegExp('^avatar:media/($_uuid)\$');

/// `logo:media/{uuid}` — a picture a community's owner or admin uploaded.
final RegExp loopLogoMediaRefPattern = RegExp('^logo:media/($_uuid)\$');

/// The media id behind an `avatar:media/…` or `logo:media/…` reference, or
/// `null` for every other value (presets, the monogram, an unknown shape).
String? loopMediaIdOf(String? reference) {
  if (reference == null) return null;
  final match =
      loopAvatarMediaRefPattern.firstMatch(reference) ??
      loopLogoMediaRefPattern.firstMatch(reference);
  return match?.group(1);
}

/// Turns a media id into the address its bytes are served from.
abstract interface class LoopMediaUrlResolver {
  /// `null` when this build has no backend to ask.
  String? urlFor(String mediaId);
}

/// The default: no backend, no address. Every uploaded picture then falls
/// back to the face drawn without it.
final class NoLoopMediaUrlResolver implements LoopMediaUrlResolver {
  const NoLoopMediaUrlResolver();

  @override
  String? urlFor(String mediaId) => null;
}

final loopMediaUrlResolverProvider = Provider<LoopMediaUrlResolver>(
  (ref) => const NoLoopMediaUrlResolver(),
);

/// Publishes the resolver to widgets that have no `ref` — the avatar is drawn
/// inside Stream's builders and on plain stateless rows.
class LoopMediaScope extends InheritedWidget {
  const LoopMediaScope({
    required this.resolver,
    required super.child,
    super.key,
  });

  final LoopMediaUrlResolver resolver;

  static LoopMediaUrlResolver? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LoopMediaScope>()?.resolver;

  @override
  bool updateShouldNotify(LoopMediaScope oldWidget) =>
      !identical(oldWidget.resolver, resolver);
}

/// The address [reference] resolves to in this [context], or `null`.
String? loopMediaUrlFor(BuildContext context, String? reference) {
  final mediaId = loopMediaIdOf(reference);
  if (mediaId == null) return null;
  return LoopMediaScope.maybeOf(context)?.urlFor(mediaId);
}

// ---------------------------------------------------------------------------
// Upload
// ---------------------------------------------------------------------------

enum AvatarUploadMode { unavailable, preview, production }

enum AvatarUploadFailureKind {
  /// The route is not served yet (`404`) or the capability is closed (`503`).
  unavailable,
  offline,

  /// `429`: six uploads a minute per account.
  rateLimited,

  /// `413` / `415` / `422`: too large, not an image, or under 64 px.
  rejected,

  /// The server answered something this client could not read.
  invalidData,
  unexpected,
}

final class AvatarUploadException implements Exception {
  const AvatarUploadException(this.kind);

  final AvatarUploadFailureKind kind;

  @override
  String toString() => 'avatar_upload_${kind.name}';
}

/// What `POST /v2/media/avatars` answered.
@immutable
final class UploadedAvatar {
  const UploadedAvatar({
    required this.mediaId,
    required this.avatarRef,
    required this.width,
    required this.height,
  });

  final String mediaId;

  /// `avatar:media/{mediaId}`: the value a profile write submits.
  final String avatarRef;
  final int width;
  final int height;
}

/// Feature port for the avatar upload. The bytes are the cropped square the
/// device produced; the server re-encodes them to 512 px WebP.
abstract interface class AvatarUploadGateway {
  AvatarUploadMode get mode;

  Future<UploadedAvatar> upload({
    required Uint8List bytes,
    required String contentType,
  });
}

final class UnavailableAvatarUploadGateway implements AvatarUploadGateway {
  const UnavailableAvatarUploadGateway();

  @override
  AvatarUploadMode get mode => AvatarUploadMode.unavailable;

  @override
  Future<UploadedAvatar> upload({
    required Uint8List bytes,
    required String contentType,
  }) => Future<UploadedAvatar>.error(
    const AvatarUploadException(AvatarUploadFailureKind.unavailable),
  );
}

final avatarUploadGatewayProvider = Provider<AvatarUploadGateway>(
  (ref) => const UnavailableAvatarUploadGateway(),
);

/// The largest file the server accepts (S107 §1).
const int avatarUploadMaximumBytes = 5 * 1024 * 1024;

/// The smallest edge the server accepts (S107 §1).
const int avatarUploadMinimumEdge = 64;

String avatarUploadFailureReason(AvatarUploadFailureKind kind) =>
    switch (kind) {
      AvatarUploadFailureKind.unavailable => '头像上传暂不可用，先用默认头像。',
      AvatarUploadFailureKind.offline => '网络未连接，头像没有上传。',
      AvatarUploadFailureKind.rateLimited => '上传太频繁，请一分钟后再试。',
      AvatarUploadFailureKind.rejected =>
        '这张图片不能用：需要 JPG、PNG、WebP 或 HEIC，不超过 5 MB，边长至少 64 像素。',
      AvatarUploadFailureKind.invalidData => '上传结果无法确认，头像没有更换。',
      AvatarUploadFailureKind.unexpected => '头像没有上传成功，请重试。',
    };

// ---------------------------------------------------------------------------
// Picking
// ---------------------------------------------------------------------------

/// One picture the person picked from their library.
@immutable
final class PickedAvatarImage {
  const PickedAvatarImage({required this.bytes});

  final Uint8List bytes;
}

/// The system photo picker, behind a port so a page test never opens one.
abstract interface class AvatarImagePicker {
  /// Whether this build can open a picker at all.
  bool get available;

  /// `null` when the person closed the picker without choosing.
  Future<PickedAvatarImage?> pick();
}

final class UnavailableAvatarImagePicker implements AvatarImagePicker {
  const UnavailableAvatarImagePicker();

  @override
  bool get available => false;

  @override
  Future<PickedAvatarImage?> pick() => Future<PickedAvatarImage?>.value();
}

final avatarImagePickerProvider = Provider<AvatarImagePicker>(
  (ref) => const UnavailableAvatarImagePicker(),
);
