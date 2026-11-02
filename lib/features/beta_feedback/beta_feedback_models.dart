import 'package:flutter/foundation.dart';

/// S332 · decision 0262: the internal-test feedback (docs/52 §二).
///
/// `POST /v2/media/feedback-images` → `{ mediaId, url }`;
/// `POST /v2/feedback` `{ category, body, mediaIds, context }` →
/// `{ feedback: { id, status, createdAt } }`;
/// `GET /v2/feedback/mine?cursor=` → `{ items, nextCursor }`.

enum BetaFeedbackCategory {
  bug('bug', 'Bug'),
  suggestion('suggestion', '建议'),
  other('other', '其他');

  const BetaFeedbackCategory(this.wireName, this.label);

  final String wireName;
  final String label;

  static BetaFeedbackCategory? tryParse(String value) {
    for (final category in values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

enum BetaFeedbackStatus {
  open('open', '待处理'),
  triaged('triaged', '已确认'),
  resolved('resolved', '已解决'),
  wontFix('wont_fix', '暂不处理');

  const BetaFeedbackStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static BetaFeedbackStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// The form's limits (docs/52 §二).
abstract final class BetaFeedbackPolicy {
  /// The body, in Unicode code points.
  static const int maximumBodyLength = 2000;

  /// The server's bound on `body` in UTF-16 units: a code point is at most
  /// two of them.
  static const int maximumWireBodyLength = maximumBodyLength * 2;

  static const int maximumImages = 4;

  /// One picture, as uploaded (the media pipeline's own limit).
  static const int maximumImageBytes = 5 * 1024 * 1024;
}

enum BetaFeedbackBodyProblem { empty, tooLong }

/// Whether [body] may be sent, and why not.
BetaFeedbackBodyProblem? betaFeedbackBodyProblem(String body) {
  if (body.trim().isEmpty) return BetaFeedbackBodyProblem.empty;
  if (betaFeedbackBodyLength(body) > BetaFeedbackPolicy.maximumBodyLength) {
    return BetaFeedbackBodyProblem.tooLong;
  }
  return null;
}

/// The body's length as the server counts it: code points.
int betaFeedbackBodyLength(String body) => body.runes.length;

/// One picture the person chose, held on the device until it is uploaded.
@immutable
final class BetaFeedbackImage {
  const BetaFeedbackImage({
    required this.localId,
    required this.bytes,
    required this.contentType,
  });

  /// Unique within the form; it keys the thumbnail and the upload memo.
  final int localId;
  final Uint8List bytes;

  /// `image/jpeg`, `image/png`, `image/webp` or `image/heic`.
  final String contentType;
}

/// What the picker hands over, before the form numbers it.
@immutable
final class BetaFeedbackPickedImage {
  const BetaFeedbackPickedImage({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}

/// The content type of [bytes] read from its first bytes, or `null` when it
/// is not one the media pipeline accepts.
String? betaFeedbackSniffContentType(Uint8List bytes) {
  bool startsWith(List<int> prefix, [int offset = 0]) {
    if (bytes.length < offset + prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[offset + index] != prefix[index]) return false;
    }
    return true;
  }

  if (startsWith(const <int>[0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const <int>[0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith(const <int>[0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const <int>[0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  // ISO-BMFF `ftyp` with a HEIF brand.
  if (startsWith(const <int>[0x66, 0x74, 0x79, 0x70], 4) &&
      bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const <String>{
      'heic',
      'heix',
      'mif1',
      'msf1',
      'hevc',
    }.contains(brand)) {
      return 'image/heic';
    }
  }
  return null;
}

/// The facts of this build and device, read once.
@immutable
final class BetaFeedbackEnvironment {
  const BetaFeedbackEnvironment({
    required this.appVersion,
    required this.build,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
  });

  /// `1.0.0`; empty when the platform did not say.
  final String appVersion;

  /// `57`; empty when the platform did not say.
  final String build;

  /// `ios` / `android` / another `Platform.operatingSystem`.
  final String platform;
  final String osVersion;
  final String deviceModel;
}

/// Where the person was when they tapped 内测反馈, read at the tap.
@immutable
final class BetaFeedbackOrigin {
  const BetaFeedbackOrigin({required this.route, required this.locale});

  /// The router location under the entry, e.g. `/meme`.
  final String route;

  /// A BCP 47 tag, e.g. `zh-CN`.
  final String locale;
}

/// The `context` object of `POST /v2/feedback`.
@immutable
final class BetaFeedbackContext {
  const BetaFeedbackContext({
    required this.appVersion,
    required this.build,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.route,
    required this.locale,
  });

  factory BetaFeedbackContext.of(
    BetaFeedbackEnvironment environment,
    BetaFeedbackOrigin origin,
  ) => BetaFeedbackContext(
    appVersion: environment.appVersion,
    build: environment.build,
    platform: environment.platform,
    osVersion: environment.osVersion,
    deviceModel: environment.deviceModel,
    route: origin.route,
    locale: origin.locale,
  );

  final String appVersion;
  final String build;
  final String platform;
  final String osVersion;
  final String deviceModel;
  final String route;
  final String locale;

  Map<String, Object?> toJson() => <String, Object?>{
    'appVersion': appVersion,
    'build': build,
    'platform': platform,
    'osVersion': osVersion,
    'deviceModel': deviceModel,
    'route': route,
    'locale': locale,
  };
}

/// One `POST /v2/feedback`, after its pictures were uploaded.
@immutable
final class BetaFeedbackSubmission {
  BetaFeedbackSubmission({
    required this.category,
    required this.body,
    required List<String> mediaIds,
    required this.context,
  }) : mediaIds = List<String>.unmodifiable(mediaIds) {
    if (betaFeedbackBodyProblem(body) != null ||
        mediaIds.length > BetaFeedbackPolicy.maximumImages) {
      throw ArgumentError('invalid beta feedback submission');
    }
  }

  final BetaFeedbackCategory category;
  final String body;
  final List<String> mediaIds;
  final BetaFeedbackContext context;

  /// One logical submission: the same form sent twice is the same command.
  String get signature =>
      'beta-feedback:${category.wireName}:${mediaIds.join(',')}:$body';
}

@immutable
final class BetaFeedbackUploadedImage {
  const BetaFeedbackUploadedImage({required this.mediaId, required this.url});

  final String mediaId;
  final String url;
}

@immutable
final class BetaFeedbackReceipt {
  const BetaFeedbackReceipt({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final BetaFeedbackStatus status;
  final DateTime createdAt;
}

@immutable
final class BetaFeedbackItem {
  BetaFeedbackItem({
    required this.id,
    required this.category,
    required this.body,
    required this.status,
    required this.createdAt,
    required List<String> images,
  }) : images = List<String>.unmodifiable(images);

  final String id;
  final BetaFeedbackCategory category;
  final String body;
  final BetaFeedbackStatus status;
  final DateTime createdAt;

  /// Absolute picture addresses, in the order they were attached.
  final List<String> images;
}

@immutable
final class BetaFeedbackPage {
  BetaFeedbackPage({required List<BetaFeedbackItem> items, this.nextCursor})
    : items = List<BetaFeedbackItem>.unmodifiable(items);

  final List<BetaFeedbackItem> items;
  final String? nextCursor;
}
