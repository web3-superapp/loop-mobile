import 'dart:collection';

import 'package:loop_mobile/core/navigation/stream_channel_route.dart';

/// The only delivery contexts a future centralized provider adapter may pass
/// into LOOP's notification router.
enum LoopNotificationIngress { foreground, background, interaction }

/// Session eligibility is supplied by the application composition root.
///
/// Only [authenticated] may resolve an interaction. Preview, signed-out, and
/// authenticated-unverified sessions map to [ineligible]. Restoring may be
/// retried by a future ingress coordinator, but this router never queues data.
enum LoopNotificationSessionMode { restoring, ineligible, authenticated }

final class LoopNotificationSessionContext {
  const LoopNotificationSessionContext._(this.mode, this.streamUserId);

  const LoopNotificationSessionContext.restoring()
    : this._(LoopNotificationSessionMode.restoring, null);

  const LoopNotificationSessionContext.ineligible()
    : this._(LoopNotificationSessionMode.ineligible, null);

  const LoopNotificationSessionContext.authenticated(String streamUserId)
    : this._(LoopNotificationSessionMode.authenticated, streamUserId);

  final LoopNotificationSessionMode mode;
  final String? streamUserId;
}

enum LoopNotificationDisposition {
  malformed,
  invalidTime,
  expired,
  sessionDeferred,
  sessionRejected,
  recipientMismatch,
  foregroundObserved,
  backgroundDeferred,
  navigationReady,
  duplicateInteraction,
}

/// A fixed application destination produced only after strict validation.
sealed class LoopNotificationNavigationIntent {
  const LoopNotificationNavigationIntent();

  String get location;
}

final class LoopChatNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopChatNotificationIntent._(this.channel);

  final LoopStreamChannelAddress channel;

  @override
  String get location => '/chat/channel/${Uri.encodeComponent(channel.cid)}';
}

/// Audio notifications can only open the foreground lobby. A notification can
/// never choose a call type, room ID, join state, or microphone state.
final class LoopAudioRoomNotificationIntent
    extends LoopNotificationNavigationIntent {
  const LoopAudioRoomNotificationIntent._();

  @override
  String get location => '/chat/voice';
}

final class LoopNotificationCenterIntent
    extends LoopNotificationNavigationIntent {
  const LoopNotificationCenterIntent._();

  @override
  String get location => '/notifications';
}

/// A provider-neutral result that never retains the untrusted input map.
final class LoopNotificationDecision {
  const LoopNotificationDecision._(this.disposition, this.intent);

  const LoopNotificationDecision._withoutNavigation(
    LoopNotificationDisposition disposition,
  ) : this._(disposition, null);

  const LoopNotificationDecision._navigate(
    LoopNotificationNavigationIntent intent,
  ) : this._(LoopNotificationDisposition.navigationReady, intent);

  final LoopNotificationDisposition disposition;
  final LoopNotificationNavigationIntent? intent;
}

enum _LoopNotificationKind { chatMessage, audioRoomActivity, systemNotice }

final class _LoopNotificationEvent {
  const _LoopNotificationEvent({
    required this.eventId,
    required this.recipientStreamUserId,
    required this.kind,
    this.channel,
  });

  final String eventId;
  final String recipientStreamUserId;
  final _LoopNotificationKind kind;
  final LoopStreamChannelAddress? channel;
}

enum _LoopNotificationParseFailure { malformed, invalidTime, expired }

final class _LoopNotificationParseResult {
  const _LoopNotificationParseResult.event(this.event) : failure = null;

  const _LoopNotificationParseResult.failure(this.failure) : event = null;

  final _LoopNotificationEvent? event;
  final _LoopNotificationParseFailure? failure;
}

/// Strictly classifies LOOP-owned, normalized navigation envelopes.
///
/// This is deliberately not a parser for raw Firebase, Stream Chat, Stream
/// Video, APNs, or PushKit payloads. Their exact provider templates and names
/// must be verified before one centralized ingress adapter may map them into
/// this contract. Unknown data therefore fails closed with no SDK call,
/// navigation, persistence, or payload logging.
final class LoopNotificationRouter {
  LoopNotificationRouter({
    DateTime Function()? clock,
    int openedEventCapacity = 128,
  }) : _clock = clock ?? DateTime.now,
       _openedEventCapacity = openedEventCapacity {
    if (openedEventCapacity < 1 || openedEventCapacity > 1024) {
      throw ArgumentError.value(
        openedEventCapacity,
        'openedEventCapacity',
        'must be between 1 and 1024',
      );
    }
  }

  static const String schema = 'notification.v1';
  static const String chatMessageKind = 'chat.message';
  static const String audioRoomActivityKind = 'audio_room.activity';
  static const String systemNoticeKind = 'system.notice';

  static const Set<String> _commonKeys = <String>{
    'loop_schema',
    'event_id',
    'recipient_stream_user_id',
    'kind',
    'occurred_at',
    'expires_at',
  };
  static const Set<String> _chatKeys = <String>{..._commonKeys, 'cid'};
  static final RegExp _eventIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');
  static final RegExp _timestampPattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
  );
  static final RegExp _forbiddenTextControlPattern = RegExp(
    r'[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]',
  );
  static const Duration _futureSkew = Duration(minutes: 5);
  static const Duration _maximumLifetime = Duration(days: 7);

  final DateTime Function() _clock;
  final int _openedEventCapacity;
  final LinkedHashSet<String> _openedEventKeys = LinkedHashSet<String>();

  LoopNotificationDecision route({
    required Map<String, Object?> data,
    required LoopNotificationIngress ingress,
    required LoopNotificationSessionContext session,
  }) {
    final parsed = _parse(data, _clock().toUtc());
    final failure = parsed.failure;
    if (failure != null) {
      return LoopNotificationDecision._withoutNavigation(switch (failure) {
        _LoopNotificationParseFailure.malformed =>
          LoopNotificationDisposition.malformed,
        _LoopNotificationParseFailure.invalidTime =>
          LoopNotificationDisposition.invalidTime,
        _LoopNotificationParseFailure.expired =>
          LoopNotificationDisposition.expired,
      });
    }
    final event = parsed.event!;

    switch (session.mode) {
      case LoopNotificationSessionMode.restoring:
        return const LoopNotificationDecision._withoutNavigation(
          LoopNotificationDisposition.sessionDeferred,
        );
      case LoopNotificationSessionMode.ineligible:
        return const LoopNotificationDecision._withoutNavigation(
          LoopNotificationDisposition.sessionRejected,
        );
      case LoopNotificationSessionMode.authenticated:
        final streamUserId = session.streamUserId;
        if (streamUserId == null ||
            !_streamUserIdPattern.hasMatch(streamUserId) ||
            streamUserId != event.recipientStreamUserId) {
          return const LoopNotificationDecision._withoutNavigation(
            LoopNotificationDisposition.recipientMismatch,
          );
        }
    }

    switch (ingress) {
      case LoopNotificationIngress.foreground:
        return const LoopNotificationDecision._withoutNavigation(
          LoopNotificationDisposition.foregroundObserved,
        );
      case LoopNotificationIngress.background:
        return const LoopNotificationDecision._withoutNavigation(
          LoopNotificationDisposition.backgroundDeferred,
        );
      case LoopNotificationIngress.interaction:
        break;
    }

    final receiptKey = '${event.recipientStreamUserId}\u0000${event.eventId}';
    if (!_claimOpenedEvent(receiptKey)) {
      return const LoopNotificationDecision._withoutNavigation(
        LoopNotificationDisposition.duplicateInteraction,
      );
    }

    return LoopNotificationDecision._navigate(switch (event.kind) {
      _LoopNotificationKind.chatMessage => LoopChatNotificationIntent._(
        event.channel!,
      ),
      _LoopNotificationKind.audioRoomActivity =>
        const LoopAudioRoomNotificationIntent._(),
      _LoopNotificationKind.systemNotice =>
        const LoopNotificationCenterIntent._(),
    });
  }

  bool _claimOpenedEvent(String receiptKey) {
    if (_openedEventKeys.contains(receiptKey)) return false;
    if (_openedEventKeys.length >= _openedEventCapacity) {
      _openedEventKeys.remove(_openedEventKeys.first);
    }
    _openedEventKeys.add(receiptKey);
    return true;
  }

  _LoopNotificationParseResult _parse(Map<String, Object?> data, DateTime now) {
    final rawKind = data['kind'];
    final kind = switch (rawKind) {
      chatMessageKind => _LoopNotificationKind.chatMessage,
      audioRoomActivityKind => _LoopNotificationKind.audioRoomActivity,
      systemNoticeKind => _LoopNotificationKind.systemNotice,
      _ => null,
    };
    if (kind == null) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }

    final allowedKeys = kind == _LoopNotificationKind.chatMessage
        ? _chatKeys
        : _commonKeys;
    if (data.length != allowedKeys.length ||
        !data.keys.every(allowedKeys.contains) ||
        !data.values.every((value) => value is String)) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }

    final rawSchema = data['loop_schema']! as String;
    final eventId = data['event_id']! as String;
    final recipientStreamUserId = data['recipient_stream_user_id']! as String;
    final rawOccurredAt = data['occurred_at']! as String;
    final rawExpiresAt = data['expires_at']! as String;
    if (rawSchema != schema ||
        !_eventIdPattern.hasMatch(eventId) ||
        !_streamUserIdPattern.hasMatch(recipientStreamUserId)) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.malformed,
      );
    }

    final occurredAt = _parseCanonicalTimestamp(rawOccurredAt);
    final expiresAt = _parseCanonicalTimestamp(rawExpiresAt);
    if (occurredAt == null ||
        expiresAt == null ||
        !expiresAt.isAfter(occurredAt) ||
        expiresAt.difference(occurredAt) > _maximumLifetime ||
        occurredAt.isAfter(now.add(_futureSkew))) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.invalidTime,
      );
    }
    if (!expiresAt.isAfter(now)) {
      return const _LoopNotificationParseResult.failure(
        _LoopNotificationParseFailure.expired,
      );
    }

    LoopStreamChannelAddress? channel;
    if (kind == _LoopNotificationKind.chatMessage) {
      final cid = data['cid']! as String;
      if (!_isBoundedText(cid, maxLength: 255)) {
        return const _LoopNotificationParseResult.failure(
          _LoopNotificationParseFailure.malformed,
        );
      }
      channel = parseLoopStreamChannelCid(cid);
      if (channel == null) {
        return const _LoopNotificationParseResult.failure(
          _LoopNotificationParseFailure.malformed,
        );
      }
    }

    return _LoopNotificationParseResult.event(
      _LoopNotificationEvent(
        eventId: eventId,
        recipientStreamUserId: recipientStreamUserId,
        kind: kind,
        channel: channel,
      ),
    );
  }

  static DateTime? _parseCanonicalTimestamp(String rawValue) {
    if (!_timestampPattern.hasMatch(rawValue)) return null;
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null ||
        !parsed.isUtc ||
        parsed.toIso8601String() != rawValue) {
      return null;
    }
    return parsed;
  }

  static bool _isBoundedText(String value, {required int maxLength}) {
    return value.isNotEmpty &&
        value.length <= maxLength &&
        value.trim() == value &&
        !_forbiddenTextControlPattern.hasMatch(value);
  }
}
