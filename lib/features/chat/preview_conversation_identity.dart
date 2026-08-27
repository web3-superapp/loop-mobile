import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';

@immutable
class PreviewConversationTarget {
  const PreviewConversationTarget({
    required this.id,
    required this.title,
    required this.kind,
    required this.routePath,
    required this.supportsMessageSearch,
  });

  final String id;
  final String title;
  final ConversationKind kind;
  final String routePath;
  final bool supportsMessageSearch;

  String get location => Uri(
    path: routePath,
    queryParameters: <String, String>{'conversationId': id},
  ).toString();

  String get searchLocation => Uri(
    path: '/chat/search',
    queryParameters: <String, String>{'conversationId': id},
  ).toString();
}

/// Exact allowlist for the local, process-only Chat Preview.
///
/// Production Stream navigation uses the official full CID route and does not
/// consult this registry. A Preview identifier is never trimmed, inferred from
/// its kind, or replaced by another fixture when it is unknown.
abstract final class PreviewConversationIdentity {
  static const maxIdLength = 128;
  static const meetingId = 'weekly-briefing';

  static const group = PreviewConversationTarget(
    id: ChatContent.groupId,
    title: 'Glyph Hunters',
    kind: ConversationKind.group,
    routePath: '/chat/group',
    supportsMessageSearch: true,
  );
  static const direct = PreviewConversationTarget(
    id: ChatContent.directId,
    title: '0xSable',
    kind: ConversationKind.direct,
    routePath: '/chat/dm',
    supportsMessageSearch: true,
  );
  static const targets = <PreviewConversationTarget>[group, direct];

  static PreviewConversationTarget? resolve({
    required String conversationId,
    required ConversationKind kind,
  }) {
    final target = resolveId(conversationId);
    return target?.kind == kind ? target : null;
  }

  static PreviewConversationTarget? resolveId(String conversationId) {
    if (!_hasSafeShape(conversationId)) return null;
    return switch (conversationId) {
      ChatContent.groupId => group,
      ChatContent.directId => direct,
      _ => null,
    };
  }

  static PreviewConversationTarget? resolveMessage(String conversationId) {
    final target = resolveId(conversationId);
    return target != null && target.supportsMessageSearch ? target : null;
  }

  static bool hasConversationIdQuery(Uri uri) =>
      uri.queryParametersAll.containsKey('conversationId');

  static String? readSingleConversationId(Uri uri) {
    final values = uri.queryParametersAll['conversationId'];
    if (values == null || values.length != 1) return null;
    final conversationId = values.single;
    return _hasSafeShape(conversationId) ? conversationId : null;
  }

  static String? locationForSummary({
    required String conversationId,
    required ConversationKind kind,
  }) {
    final messageTarget = resolve(conversationId: conversationId, kind: kind);
    if (messageTarget != null) return messageTarget.location;
    return switch ((conversationId, kind)) {
      (ChatContent.voiceRoomId, ConversationKind.voice) => '/chat/voice',
      (meetingId, ConversationKind.meeting) => '/chat/meeting',
      _ => null,
    };
  }

  static String? groupInfoLocation(String conversationId) {
    final target = resolve(
      conversationId: conversationId,
      kind: ConversationKind.group,
    );
    if (target == null) return null;
    return Uri(
      path: '/chat/group-info',
      queryParameters: <String, String>{'conversationId': target.id},
    ).toString();
  }

  static bool _hasSafeShape(String conversationId) {
    if (conversationId.isEmpty || conversationId.length > maxIdLength) {
      return false;
    }
    for (final codeUnit in conversationId.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7f) return false;
    }
    return true;
  }
}
