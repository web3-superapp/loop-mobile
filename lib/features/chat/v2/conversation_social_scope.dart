// 开发交接 S-02：DM 可使用后端 direct-channel 的公开 peer；
// 群消息尚缺经授权的公开身份映射，不能从 Stream ID 或 Alias 推断。
// 详见 docs/handoff/2026-10-03-social-development-handoff.md。

import 'package:flutter/widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Public context supplied by the page's authoritative LOOP resource, never
/// inferred from a Stream user ID, a channel name or QR query parameters.
class ConversationSocialScope extends InheritedWidget {
  const ConversationSocialScope({
    required super.child,
    this.peer,
    this.community,
    super.key,
  });
  final LoopPublicProfile? peer;
  final ConversationCommunityShare? community;
  static ConversationSocialScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConversationSocialScope>();
  @override
  bool updateShouldNotify(ConversationSocialScope old) =>
      old.peer != peer || old.community != community;
}

class ConversationCommunityShare {
  const ConversationCommunityShare({
    required this.id,
    required this.name,
    required this.cid,
  });
  final String id;
  final String name;
  final String cid;
}
