import 'package:flutter/foundation.dart';

const int socialPrivacyMaximumVersion = 2147483647;

/// Sanitized validation failure for data outside the backend Social Privacy
/// contract.
final class InvalidSocialPrivacyContractException implements Exception {
  const InvalidSocialPrivacyContractException();

  String get code => 'invalid_social_privacy_contract';

  @override
  String toString() => 'The Social Privacy contract value is invalid';
}

enum FriendRequestsPreference {
  enabled,
  disabled;

  String get wireValue => switch (this) {
    FriendRequestsPreference.enabled => 'enabled',
    FriendRequestsPreference.disabled => 'disabled',
  };

  static FriendRequestsPreference fromWire(String value) => switch (value) {
    'enabled' => FriendRequestsPreference.enabled,
    'disabled' => FriendRequestsPreference.disabled,
    _ => throw const InvalidSocialPrivacyContractException(),
  };
}

enum GroupInvitesPreference {
  friends,
  disabled;

  String get wireValue => switch (this) {
    GroupInvitesPreference.friends => 'friends',
    GroupInvitesPreference.disabled => 'disabled',
  };

  static GroupInvitesPreference fromWire(String value) => switch (value) {
    'friends' => GroupInvitesPreference.friends,
    'disabled' => GroupInvitesPreference.disabled,
    _ => throw const InvalidSocialPrivacyContractException(),
  };
}

enum DirectMessagesPreference {
  friends,
  disabled;

  String get wireValue => switch (this) {
    DirectMessagesPreference.friends => 'friends',
    DirectMessagesPreference.disabled => 'disabled',
  };

  static DirectMessagesPreference fromWire(String value) => switch (value) {
    'friends' => DirectMessagesPreference.friends,
    'disabled' => DirectMessagesPreference.disabled,
    _ => throw const InvalidSocialPrivacyContractException(),
  };
}

@immutable
final class SocialPrivacyValues {
  const SocialPrivacyValues({
    required this.friendRequests,
    required this.groupInvites,
    required this.directMessages,
  });

  const SocialPrivacyValues.defaults()
    : friendRequests = FriendRequestsPreference.disabled,
      groupInvites = GroupInvitesPreference.disabled,
      directMessages = DirectMessagesPreference.disabled;

  factory SocialPrivacyValues.copyOf(SocialPrivacyValues source) =>
      SocialPrivacyValues(
        friendRequests: source.friendRequests,
        groupInvites: source.groupInvites,
        directMessages: source.directMessages,
      );

  final FriendRequestsPreference friendRequests;
  final GroupInvitesPreference groupInvites;
  final DirectMessagesPreference directMessages;

  SocialPrivacyValues withFriendRequests(FriendRequestsPreference value) =>
      SocialPrivacyValues(
        friendRequests: value,
        groupInvites: groupInvites,
        directMessages: directMessages,
      );

  SocialPrivacyValues withGroupInvites(GroupInvitesPreference value) =>
      SocialPrivacyValues(
        friendRequests: friendRequests,
        groupInvites: value,
        directMessages: directMessages,
      );

  SocialPrivacyValues withDirectMessages(DirectMessagesPreference value) =>
      SocialPrivacyValues(
        friendRequests: friendRequests,
        groupInvites: groupInvites,
        directMessages: value,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialPrivacyValues &&
          other.friendRequests == friendRequests &&
          other.groupInvites == groupInvites &&
          other.directMessages == directMessages;

  @override
  int get hashCode => Object.hash(friendRequests, groupInvites, directMessages);
}

@immutable
final class SocialPrivacyResource {
  factory SocialPrivacyResource({
    required int version,
    required SocialPrivacyValues values,
    required DateTime? updatedAt,
  }) {
    if (version < 0 ||
        version > socialPrivacyMaximumVersion ||
        ((version == 0) != (updatedAt == null))) {
      throw const InvalidSocialPrivacyContractException();
    }
    return SocialPrivacyResource._(
      version,
      SocialPrivacyValues.copyOf(values),
      updatedAt?.toUtc(),
    );
  }

  const SocialPrivacyResource._(this.version, this.values, this.updatedAt);

  factory SocialPrivacyResource.empty() => SocialPrivacyResource(
    version: 0,
    values: const SocialPrivacyValues.defaults(),
    updatedAt: null,
  );

  factory SocialPrivacyResource.copyOf(SocialPrivacyResource source) =>
      SocialPrivacyResource(
        version: source.version,
        values: source.values,
        updatedAt: source.updatedAt,
      );

  final int version;
  final SocialPrivacyValues values;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialPrivacyResource &&
          other.version == version &&
          other.values == values &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(version, values, updatedAt);
}
