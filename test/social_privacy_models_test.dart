import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';

void main() {
  group('Social Privacy models', () {
    test('uses the exact fail-closed backend defaults', () {
      const values = SocialPrivacyValues.defaults();
      final resource = SocialPrivacyResource.empty();

      expect(values.friendRequests, FriendRequestsPreference.disabled);
      expect(values.groupInvites, GroupInvitesPreference.disabled);
      expect(values.directMessages, DirectMessagesPreference.disabled);
      expect(resource.version, 0);
      expect(resource.values, values);
      expect(resource.updatedAt, isNull);
    });

    test('round-trips only the reviewed wire values', () {
      const friendRequests = <FriendRequestsPreference, String>{
        FriendRequestsPreference.enabled: 'enabled',
        FriendRequestsPreference.disabled: 'disabled',
      };
      const groupInvites = <GroupInvitesPreference, String>{
        GroupInvitesPreference.friends: 'friends',
        GroupInvitesPreference.disabled: 'disabled',
      };
      const directMessages = <DirectMessagesPreference, String>{
        DirectMessagesPreference.friends: 'friends',
        DirectMessagesPreference.disabled: 'disabled',
      };

      for (final entry in friendRequests.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(FriendRequestsPreference.fromWire(entry.value), entry.key);
      }
      for (final entry in groupInvites.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(GroupInvitesPreference.fromWire(entry.value), entry.key);
      }
      for (final entry in directMessages.entries) {
        expect(entry.key.wireValue, entry.value);
        expect(DirectMessagesPreference.fromWire(entry.value), entry.key);
      }

      for (final invalid in <String>['', 'Enabled', 'friend', 'friends ']) {
        expect(
          () => FriendRequestsPreference.fromWire(invalid),
          throwsA(isA<InvalidSocialPrivacyContractException>()),
        );
        expect(
          () => GroupInvitesPreference.fromWire(invalid),
          throwsA(isA<InvalidSocialPrivacyContractException>()),
        );
        expect(
          () => DirectMessagesPreference.fromWire(invalid),
          throwsA(isA<InvalidSocialPrivacyContractException>()),
        );
      }
    });

    test('edits one exact preference without mutating the source', () {
      const defaults = SocialPrivacyValues.defaults();
      final friendRequests = defaults.withFriendRequests(
        FriendRequestsPreference.enabled,
      );
      final groupInvites = friendRequests.withGroupInvites(
        GroupInvitesPreference.friends,
      );
      final directMessages = groupInvites.withDirectMessages(
        DirectMessagesPreference.friends,
      );

      expect(defaults, const SocialPrivacyValues.defaults());
      expect(friendRequests.groupInvites, GroupInvitesPreference.disabled);
      expect(groupInvites.directMessages, DirectMessagesPreference.disabled);
      expect(
        directMessages,
        const SocialPrivacyValues(
          friendRequests: FriendRequestsPreference.enabled,
          groupInvites: GroupInvitesPreference.friends,
          directMessages: DirectMessagesPreference.friends,
        ),
      );
    });

    test('normalizes timestamps to UTC and copies values defensively', () {
      const values = SocialPrivacyValues(
        friendRequests: FriendRequestsPreference.enabled,
        groupInvites: GroupInvitesPreference.friends,
        directMessages: DirectMessagesPreference.disabled,
      );
      final resource = SocialPrivacyResource(
        version: 3,
        values: values,
        updatedAt: DateTime.parse('2026-08-31T09:02:03+08:00'),
      );
      final copied = SocialPrivacyResource.copyOf(resource);

      expect(resource.updatedAt, DateTime.utc(2026, 8, 31, 1, 2, 3));
      expect(copied, resource);
      expect(copied.hashCode, resource.hashCode);
      expect(identical(resource.values, values), isFalse);
      expect(identical(copied, resource), isFalse);
      expect(identical(copied.values, resource.values), isFalse);
    });

    test('enforces the version and timestamp biconditional', () {
      for (final action in <void Function()>[
        () => SocialPrivacyResource(
          version: 0,
          values: const SocialPrivacyValues.defaults(),
          updatedAt: DateTime.utc(2026),
        ),
        () => SocialPrivacyResource(
          version: 1,
          values: const SocialPrivacyValues.defaults(),
          updatedAt: null,
        ),
        () => SocialPrivacyResource(
          version: -1,
          values: const SocialPrivacyValues.defaults(),
          updatedAt: null,
        ),
        () => SocialPrivacyResource(
          version: socialPrivacyMaximumVersion + 1,
          values: const SocialPrivacyValues.defaults(),
          updatedAt: DateTime.utc(2026),
        ),
      ]) {
        expect(action, throwsA(isA<InvalidSocialPrivacyContractException>()));
      }
    });

    test('keeps contract failures sanitized', () {
      const failure = InvalidSocialPrivacyContractException();

      expect(failure.code, 'invalid_social_privacy_contract');
      expect(
        failure.toString(),
        'The Social Privacy contract value is invalid',
      );
      expect(failure.toString(), isNot(contains('friends')));
    });
  });
}
