import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider-neutral delivery contexts emitted only after a future ingress has
/// normalized a provider payload into LOOP's owned notification envelope.
enum LoopNotificationSourceEventKind { foreground, background, interaction }

/// One untrusted, normalized notification candidate.
///
/// The defensive copy prevents an ingress from mutating a queued interaction.
/// Its string representation deliberately omits the payload.
final class LoopNotificationSourceEvent {
  LoopNotificationSourceEvent({
    required this.kind,
    required Map<String, Object?> data,
  }) : data = Map<String, Object?>.unmodifiable(data);

  final LoopNotificationSourceEventKind kind;
  final Map<String, Object?> data;

  @override
  String toString() => 'LoopNotificationSourceEvent($kind)';
}

/// The single application-facing source for future normalized notifications.
///
/// Firebase, Stream, APNs and PushKit payloads must be translated by the one
/// approved ingress before they can reach this interface. This port never
/// grants delivery, navigation, identity or provider truth by itself.
abstract interface class LoopNotificationEventSource {
  Future<LoopNotificationSourceEvent?> loadInitialInteraction();

  Stream<LoopNotificationSourceEvent> get events;
}

/// Production default while no reviewed provider ingress exists.
final class DisabledLoopNotificationEventSource
    implements LoopNotificationEventSource {
  const DisabledLoopNotificationEventSource();

  @override
  Future<LoopNotificationSourceEvent?> loadInitialInteraction() async => null;

  @override
  Stream<LoopNotificationSourceEvent> get events =>
      const Stream<LoopNotificationSourceEvent>.empty();
}

/// [LoopApp] reads this source once and owns its subscription for the lifetime
/// of that app root. A future provider-backed implementation must therefore
/// remain stable for that ProviderScope and release its own resources on
/// provider disposal.
final loopNotificationEventSourceProvider =
    Provider<LoopNotificationEventSource>(
      (ref) => const DisabledLoopNotificationEventSource(),
    );
