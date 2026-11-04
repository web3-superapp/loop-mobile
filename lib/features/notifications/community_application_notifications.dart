import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// The two review outcomes the feed carries for a community applicant.
///
/// They arrive as `community.announcement` rows whose `payload.event` names
/// which of the two it is (backend decision 0073). The category is shared with
/// every other community announcement, so the event — not the category — is
/// what selects the sentence, and a row whose event this build does not know
/// is not one of these.
enum CommunityApplicationEvent {
  verified('community.application.verified'),
  rejected('community.application.rejected');

  const CommunityApplicationEvent(this.wireName);

  final String wireName;

  static CommunityApplicationEvent? tryParse(String? value) {
    if (value == null) return null;
    for (final event in values) {
      if (event.wireName == value) return event;
    }
    return null;
  }
}

/// One review result as the in-app feed states it.
///
/// Unlike the push copy — which may name nothing, because it travels outside
/// LOOP — this is read inside an authenticated session against the account's
/// own feed, so it may name the community and quote the reason. Every word of
/// it comes from the row: nothing is inferred from the category, the time or
/// the destination.
class CommunityApplicationNotification {
  const CommunityApplicationNotification({
    required this.entry,
    required this.event,
    required this.communityId,
    required this.communityName,
    required this.reason,
  });

  /// Reads an entry as a review result, or answers null when it is not one.
  ///
  /// `communityId` is required: it is what the row opens, and a result that
  /// cannot be opened is not shown as one. The name and the reason are both
  /// optional — the row states what it has.
  static CommunityApplicationNotification? read(LoopNotificationEntry entry) {
    if (entry.type != LoopNotificationCategory.communityAnnouncement) {
      return null;
    }
    final event = CommunityApplicationEvent.tryParse(entry.payload['event']);
    if (event == null) return null;
    final communityId =
        entry.contextParams['communityId'] ?? entry.payload['communityId'];
    if (communityId == null || communityId.isEmpty) return null;
    final name = entry.payload['communityName']?.trim();
    final reason = entry.payload['reason']?.trim();
    return CommunityApplicationNotification(
      entry: entry,
      event: event,
      communityId: communityId,
      communityName: name == null || name.isEmpty ? null : name,
      reason: reason == null || reason.isEmpty ? null : reason,
    );
  }

  final LoopNotificationEntry entry;
  final CommunityApplicationEvent event;
  final String communityId;

  /// The community's name as the row carried it. Null is a row that carried
  /// none; the sentence then says 「你的社区」 without naming one, rather than
  /// printing an opaque identifier at a reader.
  final String? communityName;

  /// The operator's own words, for a refusal that carried them.
  final String? reason;

  /// 「你的社区「Frog Holders」已通过审核」.
  String get title {
    final subject = communityName == null
        ? LoopL10n.current.notifications_applicationSubject
        : LoopL10n.current.notifications_applicationSubjectNamed(communityName);
    return switch (event) {
      CommunityApplicationEvent.verified =>
        LoopL10n.current.notifications_applicationVerified(subject),
      CommunityApplicationEvent.rejected =>
        LoopL10n.current.notifications_applicationRejected(subject),
    };
  }

  /// What the verdict changes, or why it was refused.
  String get body => switch (event) {
    CommunityApplicationEvent.verified =>
      LoopL10n.current.notifications_applicationVerifiedBody,
    CommunityApplicationEvent.rejected =>
      reason == null
          ? LoopL10n.current.notifications_applicationNoReason
          : LoopL10n.current.notifications_applicationReason(reason),
  };
}

/// Every review result on a feed page, in the server's order.
List<CommunityApplicationNotification> communityApplicationNotifications(
  LoopNotificationFeed feed,
) => <CommunityApplicationNotification>[
  for (final entry in feed.items) ?CommunityApplicationNotification.read(entry),
];
