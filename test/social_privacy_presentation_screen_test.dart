import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';

void main() {
  testWidgets('default Social Privacy stays unavailable and fail-closed', (
    tester,
  ) async {
    await _pumpSocialPrivacy(tester);

    expect(find.text('Production connection unavailable'), findsOneWidget);
    expect(find.text('Social Privacy is not connected'), findsOneWidget);
    expect(find.textContaining('fail-closed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('social-privacy-friend-requests')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('social-privacy-group-invites')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('social-privacy-direct-messages')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('social-privacy-apply')),
      findsNothing,
    );
    expect(find.textContaining('开发预览'), findsNothing);
  });

  for (final mode in <SocialPrivacyMode>[
    SocialPrivacyMode.preview,
    SocialPrivacyMode.production,
  ]) {
    testWidgets(
      '${mode.name} loads all three preferences and applies one complete replacement',
      (tester) async {
        final gateway = _FakeSocialPrivacyGateway(
          mode: mode,
          resource: _resource(3),
        );
        await _pumpSocialPrivacy(tester, gateway: gateway);

        expect(gateway.loadCalls, 1);
        expect(find.text('VERSION 3'), findsOneWidget);
        expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
        expect(
          _socialSwitch(tester, 'social-privacy-friend-requests').value,
          isFalse,
        );
        expect(
          _socialSwitch(tester, 'social-privacy-group-invites').value,
          isFalse,
        );
        expect(
          _socialSwitch(tester, 'social-privacy-direct-messages').value,
          isFalse,
        );
        expect(
          find.text(
            mode == SocialPrivacyMode.preview
                ? '开发预览 · in-memory Social Privacy'
                : 'Account Social Privacy preferences',
          ),
          findsOneWidget,
        );

        await _tapSocialSwitch(tester, 'social-privacy-friend-requests');
        await _tapSocialSwitch(tester, 'social-privacy-group-invites');
        await _tapSocialSwitch(tester, 'social-privacy-direct-messages');

        expect(find.text('UNSAVED DRAFT'), findsOneWidget);
        await _tap(
          tester,
          find.byKey(const ValueKey<String>('social-privacy-apply')),
        );

        expect(gateway.replaceCalls, 1);
        expect(gateway.expectedVersions, <int>[3]);
        expect(
          gateway.candidates.single,
          const SocialPrivacyValues(
            friendRequests: FriendRequestsPreference.enabled,
            groupInvites: GroupInvitesPreference.friends,
            directMessages: DirectMessagesPreference.friends,
          ),
        );
        expect(gateway.resource.version, 4);
        expect(find.text('VERSION 4'), findsOneWidget);
        expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
        expect(
          _socialSwitch(tester, 'social-privacy-friend-requests').value,
          isTrue,
        );
        expect(
          _socialSwitch(tester, 'social-privacy-group-invites').value,
          isTrue,
        );
        expect(
          _socialSwitch(tester, 'social-privacy-direct-messages').value,
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'CAS conflict preserves the unsaved draft and requires an explicit reload',
    (tester) async {
      final gateway = _FakeSocialPrivacyGateway(
        mode: SocialPrivacyMode.production,
        resource: _resource(4),
      );
      await _pumpSocialPrivacy(tester, gateway: gateway);

      await _tapSocialSwitch(tester, 'social-privacy-friend-requests');
      await _tapSocialSwitch(tester, 'social-privacy-group-invites');
      await _tapSocialSwitch(tester, 'social-privacy-direct-messages');

      gateway.resource = _resource(5, directMessages: true);
      await _tap(
        tester,
        find.byKey(const ValueKey<String>('social-privacy-apply')),
      );

      expect(gateway.replaceCalls, 1);
      expect(gateway.expectedVersions, <int>[4]);
      expect(
        find.byKey(const ValueKey<String>('social-privacy-conflict')),
        findsOneWidget,
      );
      expect(find.text('VERSION 4'), findsOneWidget);
      expect(find.text('UNSAVED DRAFT'), findsOneWidget);
      expect(
        _socialSwitch(tester, 'social-privacy-friend-requests').value,
        isTrue,
      );
      expect(
        _socialSwitch(tester, 'social-privacy-group-invites').value,
        isTrue,
      );
      expect(
        _socialSwitch(tester, 'social-privacy-direct-messages').value,
        isTrue,
      );
      expect(_filledButton(tester, 'social-privacy-apply').onPressed, isNull);
      expect(
        _outlinedButton(tester, 'social-privacy-discard').onPressed,
        isNull,
      );
      expect(gateway.resource.version, 5);

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('social-privacy-conflict-reload')),
      );

      expect(gateway.loadCalls, 2);
      expect(
        find.byKey(const ValueKey<String>('social-privacy-conflict')),
        findsNothing,
      );
      expect(find.text('VERSION 5'), findsOneWidget);
      expect(find.text('NO LOCAL CHANGES'), findsOneWidget);
      expect(
        _socialSwitch(tester, 'social-privacy-friend-requests').value,
        isFalse,
      );
      expect(
        _socialSwitch(tester, 'social-privacy-group-invites').value,
        isFalse,
      );
      expect(
        _socialSwitch(tester, 'social-privacy-direct-messages').value,
        isTrue,
      );
    },
  );

  testWidgets('social-privacy is a registered Profile surface', (tester) async {
    expect(ProfileSurfaceScreen.supportedIds, contains('social-privacy'));

    await _pumpSocialPrivacy(tester);

    expect(find.text('Social privacy'), findsOneWidget);
    expect(find.text('Unknown profile surface'), findsNothing);
  });
}

Future<void> _pumpSocialPrivacy(
  WidgetTester tester, {
  SocialPrivacyGateway? gateway,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialPrivacyGatewayProvider.overrideWithValue(
          gateway ?? const UnavailableSocialPrivacyGateway(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const ProfileSurfaceScreen.fromId('social-privacy'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSocialSwitch(WidgetTester tester, String key) async {
  await _tap(tester, find.byKey(ValueKey<String>(key)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

SwitchListTile _socialSwitch(WidgetTester tester, String key) {
  return tester.widget<SwitchListTile>(
    find.descendant(
      of: find.byKey(ValueKey<String>(key)),
      matching: find.byType(SwitchListTile),
    ),
  );
}

FilledButton _filledButton(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey<String>(key)));

OutlinedButton _outlinedButton(WidgetTester tester, String key) =>
    tester.widget<OutlinedButton>(find.byKey(ValueKey<String>(key)));

SocialPrivacyResource _resource(
  int version, {
  bool friendRequests = false,
  bool groupInvites = false,
  bool directMessages = false,
}) {
  return SocialPrivacyResource(
    version: version,
    values: SocialPrivacyValues(
      friendRequests: friendRequests
          ? FriendRequestsPreference.enabled
          : FriendRequestsPreference.disabled,
      groupInvites: groupInvites
          ? GroupInvitesPreference.friends
          : GroupInvitesPreference.disabled,
      directMessages: directMessages
          ? DirectMessagesPreference.friends
          : DirectMessagesPreference.disabled,
    ),
    updatedAt: version == 0 ? null : DateTime.utc(2026, 8, 31, 8, version % 60),
  );
}

final class _FakeSocialPrivacyGateway implements SocialPrivacyGateway {
  _FakeSocialPrivacyGateway({required this.mode, required this.resource});

  @override
  final SocialPrivacyMode mode;
  SocialPrivacyResource resource;
  int loadCalls = 0;
  int replaceCalls = 0;
  final List<int> expectedVersions = <int>[];
  final List<SocialPrivacyValues> candidates = <SocialPrivacyValues>[];

  @override
  Future<SocialPrivacyResource> load() async {
    loadCalls += 1;
    return SocialPrivacyResource.copyOf(resource);
  }

  @override
  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) async {
    replaceCalls += 1;
    expectedVersions.add(expectedVersion);
    candidates.add(SocialPrivacyValues.copyOf(values));
    if (expectedVersion != resource.version) {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.versionConflict,
      );
    }
    resource = SocialPrivacyResource(
      version: resource.version + 1,
      values: values,
      updatedAt: DateTime.utc(2026, 8, 31, 9, resource.version % 60),
    );
    return SocialPrivacyResource.copyOf(resource);
  }
}
