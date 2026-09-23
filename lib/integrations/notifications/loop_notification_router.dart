import 'dart:collection';

import 'package:loop_mobile/core/navigation/market_asset_route.dart';

/// The only delivery contexts the centralized provider ingress may pass into
/// LOOP's notification router.
enum LoopNotificationIngress { foreground, background, interaction }

/// Session eligibility is supplied by the application composition root.
///
/// Only [authenticated] may resolve an interaction. Preview, signed-out, and
/// authenticated-unverified sessions map to [ineligible]. Restoring may be
/// retried by the ingress coordinator, but this router never queues data.
enum LoopNotificationSessionMode { restoring, ineligible, authenticated }

final class LoopNotificationSessionContext {
  const LoopNotificationSessionContext._(this.mode);

  const LoopNotificationSessionContext.restoring()
    : this._(LoopNotificationSessionMode.restoring);

  const LoopNotificationSessionContext.ineligible()
    : this._(LoopNotificationSessionMode.ineligible);

  /// The composition root has a real LOOP session **and** a backend-verified
  /// bootstrap identity.
  ///
  /// Decision 0067 removed the recipient field from the payload, so there is
  /// no longer anything in a notification to compare an account against. The
  /// binding moved somewhere stronger: the token is issued to one device
  /// session and voided with it, and the destination is confirmed by re-reading
  /// the *current* account's feed after the tap. A pointer that account cannot
  /// see never opens a page that names anything.
  const LoopNotificationSessionContext.authenticated()
    : this._(LoopNotificationSessionMode.authenticated);

  final LoopNotificationSessionMode mode;
}

enum LoopNotificationDisposition {
  malformed,
  sessionDeferred,
  sessionRejected,
  foregroundObserved,
  backgroundDeferred,
  pointerReady,
  duplicateInteraction,
}

/// The events the push dictionary carries (decision 0067 §7.3, extended by
/// backend decision 0073).
///
/// Each one owns exactly one destination family. The pairing is checked rather
/// than trusted: a payload whose `type` and `contextRoute` disagree is not a
/// new combination to honour, it is a payload nobody wrote. Two types may
/// share a destination family — a verdict and a refusal both open the
/// community they are about — because the destination is a place to read, not
/// the answer itself.
enum LoopPushNotificationType {
  priceAlertTriggered(
    'price_alert_triggered',
    'priceAlert',
    LoopNotificationContextRoute.token,
  ),
  securityEvent(
    'security_event',
    'deviceSession',
    LoopNotificationContextRoute.devices,
  ),
  communityVoiceRoomStarted(
    'community_voice_room_started',
    'voiceRoom',
    LoopNotificationContextRoute.voiceRoom,
  ),
  communityApplicationVerified(
    'community_application_verified',
    'community',
    LoopNotificationContextRoute.communityProfile,
  ),
  communityApplicationRejected(
    'community_application_rejected',
    'community',
    LoopNotificationContextRoute.communityProfile,
  );

  const LoopPushNotificationType(
    this.wireName,
    this.entityPrefix,
    this.contextRoute,
  );

  final String wireName;

  /// The `<kind>` half of `entityRef`. It is part of the identity, not a
  /// label: `priceAlert:<uuid>` and `voiceRoom:<uuid>` are different things
  /// even when the UUID matches.
  final String entityPrefix;

  final LoopNotificationContextRoute contextRoute;

  static LoopPushNotificationType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// The destination slugs the server may name.
enum LoopNotificationContextRoute {
  token('token'),
  devices('devices'),
  voiceRoom('voice-room'),
  communityProfile('community-profile');

  const LoopNotificationContextRoute(this.wireName);

  final String wireName;

  static LoopNotificationContextRoute? tryParse(String value) {
    for (final route in values) {
      if (route.wireName == value) return route;
    }
    return null;
  }
}

/// What a push actually is: a pointer at something to go and read.
///
/// It is never a result. The notification says a price alert fired; it does
/// not say which asset, at what price, or that anything is still true. That
/// comes from the account's own feed after the tap.
final class LoopNotificationPointer {
  const LoopNotificationPointer._(this.type, this.entityRef);

  final LoopPushNotificationType type;

  /// `<kind>:<uuid>`, exactly as the server sent it.
  final String entityRef;

  LoopNotificationContextRoute get contextRoute => type.contextRoute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopNotificationPointer &&
          other.type == type &&
          other.entityRef == entityRef;

  @override
  int get hashCode => Object.hash(type, entityRef);

  @override
  String toString() => 'LoopNotificationPointer(${type.wireName})';
}

/// The authoritative destination, read back from `GET /v2/notifications/feed`
/// after the tap.
///
/// `contextRoute` and `assetId` here are the *server's record of the
/// notification*, not the push payload. They are what a page may be opened
/// with; the payload only decided which record to look for.
final class LoopNotificationContext {
  const LoopNotificationContext({
    required this.contextRoute,
    this.assetId,
    this.communityId,
  });

  final String contextRoute;
  final String? assetId;

  /// `contextParams.communityId` of the account's own record, for the two
  /// application-review events. As with [assetId], it is the server's record
  /// and never the push payload: the payload only decided which record to
  /// look for.
  final String? communityId;
}

/// A fixed application destination produced only after strict validation.
sealed class LoopNotificationNavigationIntent {
  const LoopNotificationNavigationIntent();

  String get location;
}

/// A triggered price alert whose asset the feed confirmed.
///
/// The `assetId` is validated against the canonical CAIP identity: the token
/// page addresses one contract, and a page that recovered its subject from
/// anything looser would show a different asset's facts.
final class LoopPriceAlertNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopPriceAlertNotificationIntent._(this.assetId);

  final String assetId;

  @override
  String get location => MarketAssetRoute.token(assetId);
}

/// A triggered price alert whose asset the feed did not confirm.
///
/// The alerts page is where price alerts live and it reads its own authority,
/// so it is the honest destination when the notification cannot be matched to
/// a record: the reader still lands on their alerts instead of on a token
/// chosen from an unverified payload, or on nothing at all.
final class LoopPriceAlertListNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopPriceAlertListNotificationIntent._();

  @override
  String get location => MarketAssetRoute.alertsPath;
}

/// A reviewed community application whose record the feed confirmed.
///
/// It opens that community, which re-reads its own record — including the
/// owner's `application` block — so the verdict on the screen is the one the
/// server holds now and not the one a notification carried.
final class LoopCommunityApplicationNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopCommunityApplicationNotificationIntent._(this.communityId);

  final String communityId;

  @override
  String get location =>
      '/community/profile?id=${Uri.encodeQueryComponent(communityId)}';
}

/// A reviewed community application the feed did not confirm.
///
/// The community tab is where the reader's own communities are, and it names
/// nothing chosen from an unverified payload: 我的 → 我的社区 → 我创建的 is one
/// tap from it. Opening a record addressed by the payload alone would be a
/// page about a community this account may not even own.
final class LoopCommunityIndexNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopCommunityIndexNotificationIntent._();

  @override
  String get location => '/community';
}

/// A new sign-in or a revoked device session opens device management, which
/// re-reads `GET /v2/devices` for itself.
final class LoopSecurityEventNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopSecurityEventNotificationIntent._();

  @override
  String get location => '/profile/devices';
}

/// Audio notifications can only open the foreground lobby. A notification can
/// never choose a call type, room ID, join state, or microphone state.
final class LoopVoiceRoomNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopVoiceRoomNotificationIntent._();

  @override
  String get location => '/chat/voice';
}

/// A provider-neutral result that never retains the untrusted input map.
final class LoopNotificationDecision {
  const LoopNotificationDecision._(this.disposition, this.pointer);

  const LoopNotificationDecision._withoutPointer(
    LoopNotificationDisposition disposition,
  ) : this._(disposition, null);

  const LoopNotificationDecision._ready(LoopNotificationPointer pointer)
    : this._(LoopNotificationDisposition.pointerReady, pointer);

  final LoopNotificationDisposition disposition;

  /// Present only for an accepted interaction. It still has to be resolved
  /// against the account's own feed before it can become a location.
  final LoopNotificationPointer? pointer;
}

enum _LoopNotificationParseFailure { malformed }

final class _LoopNotificationParseResult {
  const _LoopNotificationParseResult.pointer(this.pointer) : failure = null;

  const _LoopNotificationParseResult.failure(this.failure) : pointer = null;

  final LoopNotificationPointer? pointer;
  final _LoopNotificationParseFailure? failure;
}

/// Strictly classifies the four-key push envelope of decision 0067.
///
/// This is deliberately not a parser for raw Firebase, Stream Chat, Stream
/// Video, APNs, or PushKit payloads. The centralized ingress hands it
/// `RemoteMessage.data` and nothing else; a Stream chat push, whose data
/// carries its own sender and channel keys, fails closed here rather than
/// being half-understood. Unknown data produces no SDK call, no navigation, no
/// persistence and no payload logging.
final class LoopNotificationRouter {
  LoopNotificationRouter({
    DateTime Function()? clock,
    int openedPointerCapacity = 128,
    this.duplicateWindow = const Duration(seconds: 60),
  }) : _clock = clock ?? DateTime.now,
       _openedPointerCapacity = openedPointerCapacity {
    if (openedPointerCapacity < 1 || openedPointerCapacity > 1024) {
      throw ArgumentError.value(
        openedPointerCapacity,
        'openedPointerCapacity',
        'must be between 1 and 1024',
      );
    }
    if (duplicateWindow <= Duration.zero ||
        duplicateWindow > const Duration(minutes: 10)) {
      throw ArgumentError.value(
        duplicateWindow,
        'duplicateWindow',
        'must be greater than zero and at most ten minutes',
      );
    }
  }

  /// The exact four keys, and their only accepted version.
  static const String eventVersion = '1';
  static const Set<String> payloadKeys = <String>{
    'type',
    'entityRef',
    'contextRoute',
    'eventVersion',
  };

  /// How long the same pointer is treated as the same tap arriving twice.
  ///
  /// The server already guarantees one push per event per device, permanently,
  /// so this is not an event history: it is the window in which a duplicate
  /// callback is a duplicate callback. Beyond it, the same alert firing again
  /// is a new thing to open.
  final Duration duplicateWindow;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  // Written with escapes rather than the characters themselves: a bidi
  // override pasted into source is exactly the trick this pattern exists
  // to reject, and it would sit here looking like nothing at all.
  static final RegExp _forbiddenTextControlPattern = RegExp(
    '[\\u0000-\\u001f\\u007f-\\u009f\\u200b-\\u200f'
    '\\u2028-\\u202e\\u2060-\\u2069\\ufeff]',
  );

  final DateTime Function() _clock;
  final int _openedPointerCapacity;
  final LinkedHashMap<String, DateTime> _openedPointers =
      LinkedHashMap<String, DateTime>();

  LoopNotificationDecision route({
    required Map<String, Object?> data,
    required LoopNotificationIngress ingress,
    required LoopNotificationSessionContext session,
  }) {
    final parsed = _parse(data);
    if (parsed.failure != null) {
      return const LoopNotificationDecision._withoutPointer(
        LoopNotificationDisposition.malformed,
      );
    }
    final pointer = parsed.pointer!;

    switch (session.mode) {
      case LoopNotificationSessionMode.restoring:
        return const LoopNotificationDecision._withoutPointer(
          LoopNotificationDisposition.sessionDeferred,
        );
      case LoopNotificationSessionMode.ineligible:
        return const LoopNotificationDecision._withoutPointer(
          LoopNotificationDisposition.sessionRejected,
        );
      case LoopNotificationSessionMode.authenticated:
        break;
    }

    switch (ingress) {
      case LoopNotificationIngress.foreground:
        return const LoopNotificationDecision._withoutPointer(
          LoopNotificationDisposition.foregroundObserved,
        );
      case LoopNotificationIngress.background:
        return const LoopNotificationDecision._withoutPointer(
          LoopNotificationDisposition.backgroundDeferred,
        );
      case LoopNotificationIngress.interaction:
        break;
    }

    if (!_claimOpenedPointer(pointer.entityRef)) {
      return const LoopNotificationDecision._withoutPointer(
        LoopNotificationDisposition.duplicateInteraction,
      );
    }
    return LoopNotificationDecision._ready(pointer);
  }

  /// Turns an accepted pointer into a destination, using the account's own
  /// notification record rather than the payload.
  ///
  /// [context] is what `GET /v2/notifications/feed` says about this
  /// `entityRef` for the account that is signed in now. `null` — the read
  /// failed, or that account has no such notification — is not a reason to
  /// follow the payload instead: a price alert then opens the alerts page,
  /// which names no asset, and the two parameterless destinations are
  /// unchanged because there was never anything in the payload to choose them
  /// with.
  static LoopNotificationNavigationIntent resolve(
    LoopNotificationPointer pointer, {
    LoopNotificationContext? context,
  }) {
    final confirmed =
        context != null &&
        context.contextRoute == pointer.contextRoute.wireName;
    return switch (pointer.type) {
      LoopPushNotificationType.priceAlertTriggered => _priceAlertIntent(
        confirmed ? context.assetId : null,
      ),
      LoopPushNotificationType.securityEvent =>
        const LoopSecurityEventNotificationIntent._(),
      LoopPushNotificationType.communityVoiceRoomStarted =>
        const LoopVoiceRoomNotificationIntent._(),
      LoopPushNotificationType.communityApplicationVerified ||
      LoopPushNotificationType.communityApplicationRejected =>
        _communityApplicationIntent(confirmed ? context.communityId : null),
    };
  }

  static LoopNotificationNavigationIntent _communityApplicationIntent(
    String? communityId,
  ) {
    if (communityId == null || !_uuidPattern.hasMatch(communityId)) {
      return const LoopCommunityIndexNotificationIntent._();
    }
    return LoopCommunityApplicationNotificationIntent._(communityId);
  }

  static LoopNotificationNavigationIntent _priceAlertIntent(String? assetId) {
    if (assetId == null || !MarketAssetRoute.isCanonical(assetId)) {
      return const LoopPriceAlertListNotificationIntent._();
    }
    return LoopPriceAlertNotificationIntent._(assetId);
  }

  bool _claimOpenedPointer(String entityRef) {
    final now = _clock().toUtc();
    final opened = _openedPointers[entityRef];
    if (opened != null && now.difference(opened) < duplicateWindow) {
      return false;
    }
    _openedPointers.remove(entityRef);
    if (_openedPointers.length >= _openedPointerCapacity) {
      _openedPointers.remove(_openedPointers.keys.first);
    }
    _openedPointers[entityRef] = now;
    return true;
  }

  _LoopNotificationParseResult _parse(Map<String, Object?> data) {
    // Exactly four keys, every value a String. A payload with a fifth key is
    // not a richer notification, it is a different sender's.
    if (data.length != payloadKeys.length ||
        !data.keys.every(payloadKeys.contains) ||
        !data.values.every((value) => value is String)) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }
    if (data['eventVersion'] != eventVersion) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }

    final type = LoopPushNotificationType.tryParse(data['type']! as String);
    final contextRoute = LoopNotificationContextRoute.tryParse(
      data['contextRoute']! as String,
    );
    // The dictionary pairs each type with one destination family. A payload
    // that pairs them differently is refused rather than resolved by one of
    // the two halves.
    if (type == null ||
        contextRoute == null ||
        contextRoute != type.contextRoute) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }

    final entityRef = data['entityRef']! as String;
    if (!_isEntityRef(entityRef, type)) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }
    return _LoopNotificationParseResult.pointer(
      LoopNotificationPointer._(type, entityRef),
    );
  }

  static bool _isEntityRef(String value, LoopPushNotificationType type) {
    if (value.isEmpty ||
        value.length > 128 ||
        value.trim() != value ||
        _forbiddenTextControlPattern.hasMatch(value)) {
      return false;
    }
    final prefix = '${type.entityPrefix}:';
    if (!value.startsWith(prefix)) return false;
    return _uuidPattern.hasMatch(value.substring(prefix.length));
  }
}
