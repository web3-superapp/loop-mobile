import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

enum ConnectionDirection {
  following('following'),
  followers('followers');

  const ConnectionDirection(this.wireName);

  final String wireName;
}

@immutable
final class ConnectionEntry {
  const ConnectionEntry({
    required this.profile,
    required this.createdAt,
    required this.viewerFollows,
    required this.miningPower,
  });

  final LoopPublicProfile profile;
  final DateTime createdAt;
  final bool viewerFollows;
  final LoopUnavailableFact miningPower;
}

@immutable
final class ConnectionCounts {
  const ConnectionCounts({required this.following, required this.followers});

  final int following;
  final int followers;
}

@immutable
final class ConnectionPage {
  const ConnectionPage({
    required this.direction,
    required this.items,
    required this.counts,
    required this.nextCursor,
  });

  final ConnectionDirection direction;
  final List<ConnectionEntry> items;
  final ConnectionCounts counts;
  final String? nextCursor;
}

@immutable
final class FollowOutcome {
  const FollowOutcome({required this.profile, required this.viewerFollows});

  final LoopPublicProfile profile;
  final bool viewerFollows;
}

enum BlockKind {
  user('user'),
  contract('contract'),
  domain('domain');

  const BlockKind(this.wireName);

  final String wireName;

  /// Only `user` has a backend in this step; the other two are unavailable.
  bool get isSupported => this == BlockKind.user;
}

@immutable
final class BlockEntry {
  const BlockEntry({
    required this.kind,
    required this.stableId,
    required this.profile,
    required this.reasonCode,
    required this.createdAt,
  });

  final BlockKind kind;
  final String stableId;
  final LoopPublicProfile? profile;

  /// `user_request` or `message_request_report`.
  final String reasonCode;
  final DateTime createdAt;
}

@immutable
final class BlockPage {
  const BlockPage({
    required this.kind,
    required this.items,
    required this.userCount,
    required this.nextCursor,
  });

  final BlockKind kind;
  final List<BlockEntry> items;
  final int userCount;
  final String? nextCursor;
}

@immutable
final class MessageRequestEntry {
  const MessageRequestEntry({
    required this.messageRequestId,
    required this.profile,
    required this.createdAt,
    required this.expiresAt,
    required this.preview,
    required this.aiModeration,
  });

  final String messageRequestId;
  final LoopPublicProfile profile;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// The message body has no source in this step. The whole block renders
  /// unavailable; the prototype's sample copy must not appear.
  final LoopUnavailableFact preview;
  final LoopUnavailableFact aiModeration;
}

@immutable
final class MessageRequestPage {
  const MessageRequestPage({required this.items, required this.nextCursor});

  final List<MessageRequestEntry> items;
  final String? nextCursor;
}

enum MessageRequestDecision {
  accept('accept'),
  ignore('ignore'),
  report('report');

  const MessageRequestDecision(this.wireName);

  final String wireName;
}

@immutable
final class MessageRequestOutcome {
  const MessageRequestOutcome({
    required this.messageRequestId,
    required this.decision,
    required this.blocked,
  });

  final String messageRequestId;
  final MessageRequestDecision decision;

  /// Server-confirmed. The success Toast only ever repeats this value.
  final bool blocked;
}

String blockReasonText(String reasonCode) => switch (reasonCode) {
  'user_request' => '由你手动屏蔽',
  'message_request_report' => '举报陌生人请求时自动屏蔽',
  _ => '服务端记录的屏蔽原因',
};
