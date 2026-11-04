import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// `support` models (decision 0037).
///
/// A ticket is a record, never a channel: status is advanced only by a LOOP
/// operator script, attachments are permanently unavailable, and the urgent
/// escalation entry is copy rather than a second transport.
enum LoopSupportCategory {
  account('account'),
  security('security'),
  wallet('wallet'),
  trade('trade'),
  launch('launch'),
  mining('mining'),
  community('community'),
  other('other');

  const LoopSupportCategory(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LoopSupportCategory.account =>
      LoopL10n.current.profileSupport_modelsAccount,
    LoopSupportCategory.security => LoopL10n.current.common_security,
    LoopSupportCategory.wallet => LoopL10n.current.profileSupport_modelsWallet,
    LoopSupportCategory.trade => LoopL10n.current.common_trade,
    LoopSupportCategory.launch => 'Launch',
    LoopSupportCategory.mining => LoopL10n.current.common_mining,
    LoopSupportCategory.community => LoopL10n.current.common_community,
    LoopSupportCategory.other => LoopL10n.current.profileSupport_modelsOther,
  };

  static LoopSupportCategory? tryParse(String value) {
    for (final category in values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

enum LoopSupportTicketStatus {
  open('open'),
  answered('answered'),
  closed('closed');

  const LoopSupportTicketStatus(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LoopSupportTicketStatus.open => LoopL10n.current.profileSupport_modelsOpen,
    LoopSupportTicketStatus.answered =>
      LoopL10n.current.profileSupport_modelsAnswered,
    LoopSupportTicketStatus.closed =>
      LoopL10n.current.profileSupport_modelsClosed,
  };

  static LoopSupportTicketStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopSupportEventType {
  created('created'),
  answered('answered'),
  closed('closed');

  const LoopSupportEventType(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LoopSupportEventType.created => LoopL10n.current.common_submitted,
    LoopSupportEventType.answered =>
      LoopL10n.current.profileSupport_modelsAnswered2,
    LoopSupportEventType.closed => LoopL10n.current.profileSupport_modelsClosed,
  };

  static LoopSupportEventType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

enum LoopSupportActor {
  user('user'),
  operator('operator');

  const LoopSupportActor(this.wireName);

  final String wireName;
  String get label => switch (this) {
    LoopSupportActor.user => LoopL10n.current.profileSupport_modelsUser,
    LoopSupportActor.operator => LoopL10n.current.profileSupport_modelsOperator,
  };

  static LoopSupportActor? tryParse(String value) {
    for (final actor in values) {
      if (actor.wireName == value) return actor;
    }
    return null;
  }
}

@immutable
final class LoopSupportEvent {
  const LoopSupportEvent({
    required this.eventVersion,
    required this.eventType,
    required this.actor,
    required this.note,
    required this.occurredAt,
  });

  final int eventVersion;
  final LoopSupportEventType eventType;
  final LoopSupportActor actor;

  /// The operator's reply, when there is one. It is display text only.
  final String? note;
  final DateTime occurredAt;
}

@immutable
final class LoopSupportTicket {
  LoopSupportTicket({
    required this.ticketId,
    required this.category,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastEventAt,
    required List<LoopSupportEvent> events,
  }) : events = List<LoopSupportEvent>.unmodifiable(events);

  final String ticketId;
  final LoopSupportCategory category;
  final String body;
  final LoopSupportTicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastEventAt;
  final List<LoopSupportEvent> events;

  /// The latest operator note, or `null` when nobody has replied yet.
  String? get latestOperatorNote {
    for (var index = events.length - 1; index >= 0; index -= 1) {
      final event = events[index];
      if (event.actor == LoopSupportActor.operator && event.note != null) {
        return event.note;
      }
    }
    return null;
  }
}

/// Response-window promise published with every ticket response.
@immutable
final class LoopSupportPolicy {
  const LoopSupportPolicy({
    required this.configVersion,
    required this.responseWindowHours,
    required this.businessDaysOnly,
    required this.escalationChannel,
  });

  /// The server's own bound, counted in code points.
  static const maximumBodyLength = 2000;

  /// The same bound expressed in UTF-16 units, which is what `String.length`
  /// measures: one code point above the BMP is two units, so a body the server
  /// accepts can be twice as long on the wire.
  static const maximumWireBodyLength = maximumBodyLength * 2;

  final String configVersion;
  final int responseWindowHours;
  final bool businessDaysOnly;

  /// `copy`: the urgent path is a sentence, not a separate channel.
  final String escalationChannel;
}

@immutable
final class LoopSupportTicketPage {
  LoopSupportTicketPage({
    required List<LoopSupportTicket> items,
    required this.nextCursor,
    required this.attachments,
    required this.policy,
  }) : items = List<LoopSupportTicket>.unmodifiable(items);

  final List<LoopSupportTicket> items;
  final String? nextCursor;

  /// Always unavailable.
  final LoopUnavailable attachments;
  final LoopSupportPolicy policy;
}

@immutable
final class LoopSupportTicketResult {
  const LoopSupportTicketResult({
    required this.ticket,
    required this.attachments,
    required this.policy,
  });

  final LoopSupportTicket ticket;
  final LoopUnavailable attachments;
  final LoopSupportPolicy policy;
}

/// Why a typed body is not yet sendable. Every value names the server rule it
/// would break, so the page never shows a disabled button without a reason.
enum LoopSupportDraftProblem {
  empty(),
  tooLong(),
  unsafeCharacters();

  const LoopSupportDraftProblem();

  String get explanation => switch (this) {
    LoopSupportDraftProblem.empty =>
      LoopL10n.current.profileSupport_modelsEmpty,

    LoopSupportDraftProblem.tooLong =>
      LoopL10n.current.profileSupport_modelsTooLong,

    LoopSupportDraftProblem.unsafeCharacters =>
      LoopL10n.current.profileSupport_modelsUnsafeCharacters,
  };
}

/// A validated draft. Length is counted in code points, exactly as the server
/// does, and unsafe control characters are rejected before dispatch.
@immutable
final class LoopSupportDraft {
  factory LoopSupportDraft({
    required LoopSupportCategory category,
    required String body,
  }) {
    final trimmed = body.trim();
    final runes = trimmed.runes.length;
    if (runes < 1 || runes > LoopSupportPolicy.maximumBodyLength) {
      throw const InvalidLoopChainContractException();
    }
    if (_unsafeText.hasMatch(trimmed)) {
      throw const InvalidLoopChainContractException();
    }
    return LoopSupportDraft._(category: category, body: trimmed);
  }

  const LoopSupportDraft._({required this.category, required this.body});

  static final RegExp _unsafeText = RegExp(
    r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
    unicode: true,
  );

  /// Why [body] cannot be sent, or `null` when it can. The page renders the
  /// reason instead of leaving a disabled button unexplained; the same rule
  /// decides the request, so the two can never disagree.
  static LoopSupportDraftProblem? problemFor(String body) {
    final trimmed = body.trim();
    final runes = trimmed.runes.length;
    if (runes < 1) return LoopSupportDraftProblem.empty;
    if (runes > LoopSupportPolicy.maximumBodyLength) {
      return LoopSupportDraftProblem.tooLong;
    }
    if (_unsafeText.hasMatch(trimmed)) {
      return LoopSupportDraftProblem.unsafeCharacters;
    }
    return null;
  }

  /// Whether [body] would be accepted, without throwing. Used to enable the
  /// submit button rather than to decide the request.
  static bool isSubmittable(String body) => problemFor(body) == null;

  static int lengthOf(String body) => body.trim().runes.length;

  final LoopSupportCategory category;
  final String body;
}
