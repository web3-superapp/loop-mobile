import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// `support` models (decision 0037).
///
/// A ticket is a record, never a channel: status is advanced only by a LOOP
/// operator script, attachments are permanently unavailable, and the urgent
/// escalation entry is copy rather than a second transport.
enum LoopSupportCategory {
  account('account', '账号'),
  security('security', '安全'),
  wallet('wallet', '钱包'),
  trade('trade', '交易'),
  launch('launch', 'Launch'),
  mining('mining', '挖矿'),
  community('community', '社区'),
  other('other', '其他');

  const LoopSupportCategory(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopSupportCategory? tryParse(String value) {
    for (final category in values) {
      if (category.wireName == value) return category;
    }
    return null;
  }
}

enum LoopSupportTicketStatus {
  open('open', '待处理'),
  answered('answered', '已回复'),
  closed('closed', '已关闭');

  const LoopSupportTicketStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopSupportTicketStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopSupportEventType {
  created('created', '已提交'),
  answered('answered', '客服回复'),
  closed('closed', '已关闭');

  const LoopSupportEventType(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopSupportEventType? tryParse(String value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

enum LoopSupportActor {
  user('user', '你'),
  operator('operator', 'LOOP 客服');

  const LoopSupportActor(this.wireName, this.label);

  final String wireName;
  final String label;

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
  empty('请先描述你遇到的问题。'),
  tooLong('正文超过 2000 码点，请精简后再提交。'),
  unsafeCharacters('正文含有控制字符或不可见字符（例如换行、方向控制符），请删除后再提交。');

  const LoopSupportDraftProblem(this.explanation);

  final String explanation;
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
