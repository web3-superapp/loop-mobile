import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/community_test_harness.dart';

CommunityDirectoryPage _directory() => CommunityDirectoryPage(
  ordering: const CommunityOrderingApplied(
    sort: CommunityDirectorySort.members,
    basis: CommunityStoredBasis(),
  ),

  items: <CommunitySummary>[testCommunity()],
  nextCursor: null,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

/// Fills the application form with a shape the server would accept.
Future<void> _fillApplication(
  WidgetTester tester, {
  String name = 'Frog Holders',
  String slug = 'frog-holders',
  String description = '',
  String assetKey = '',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('community-apply-name')),
    name,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('community-apply-slug')),
    slug,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('community-apply-description')),
    description,
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('community-apply-asset-key')),
    assetKey,
  );
  await tester.pump();
}

Future<void> _openApplyForm(WidgetTester tester) async {
  final action = find.byKey(const ValueKey<String>('community-apply-action'));
  await scrollToCommunitySection(tester, action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

/// Opens the shared public-profile card the way a page opens it.
class _PublicProfileSheetHost extends StatelessWidget {
  const _PublicProfileSheetHost({
    required this.identity,
    required this.onOpenDirectMessage,
  });

  final PublicProfileIdentity identity;
  final PublicProfileDirectMessageHandler onOpenDirectMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const ValueKey<String>('open-sheet'),
          onPressed: () => unawaited(
            showPublicProfileSheet<Object>(
              context,
              identity: identity,
              onOpenDirectMessage: onOpenDirectMessage,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  group('public profile sheet', () {
    testWidgets('shows only the four-field identity projection', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      expect(find.text('frog_member'), findsWidgets);
      expect(find.text('LOOP-3HJKMNPQ'), findsWidgets);
      // No wallet address, profile code or invented figure is on the panel.
      expect(find.textContaining('0x'), findsNothing);
      // No figure of any kind rides on the panel itself.
      expect(find.textContaining('2,840'), findsNothing);
    });

    testWidgets('the card opens the conversation with the member it drew', (
      tester,
    ) async {
      final opened = <PublicProfileIdentity>[];
      await pumpCommunityPage(
        tester,
        CommunityMembersScreen(
          communityId: testCommunityId,
          onOpenDirectMessage: opened.add,
        ),
        community: FakeCommunityGateway(members: testDirectory()),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-open-dm')),
      );
      await tester.pumpAndSettle();

      // The whole projection travels, so the conversation is named by the
      // same four fields this card drew.
      expect(opened.single.publicProfileId, testMemberId);
      expect(opened.single.displayName, 'frog_member');
      expect(opened.single.loopId, 'LOOP-3HJKMNPQ');
      expect(opened.single.profile?.alias, 'frog_member');
      expect(opened.single.profile?.loopId, 'LOOP-3HJKMNPQ');
      // The card closes with the command: the conversation is the next
      // surface, not something behind a panel that is still open.
      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsNothing,
      );
    });

    testWidgets('a card with nowhere to go offers no conversation', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      // No disabled control and no sentence about a path that does exist:
      // 「私聊还不能从这里发起」 stopped being true when the direct channel
      // and the message request were connected.
      expect(
        find.byKey(const ValueKey<String>('public-profile-open-dm')),
        findsNothing,
      );
      expect(find.textContaining('私聊还不能从这里发起'), findsNothing);
    });

    testWidgets('the viewer own card carries no conversation', (tester) async {
      final opened = <PublicProfileIdentity>[];
      await pumpCommunityPage(
        tester,
        _PublicProfileSheetHost(
          identity: PublicProfileIdentity.fromProfile(
            testProfile(),
            isSelf: true,
          ),
          onOpenDirectMessage: opened.add,
        ),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-sheet')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-open-dm')),
        findsNothing,
      );
      expect(opened, isEmpty);
    });

    test(
      'the viewer own LOOP ID closes the control without an isSelf fact',
      () {
        // The global search holds no `isSelf` fact, so the account signed in
        // now is identified by the one identifier both sides publish.
        const mine = 'LOOP-7HJKMNPQ';
        final identity = PublicProfileIdentity.fromSearchSnapshot(
          stableId: testOwnerId,
          title: 'frog_maxi',
          subtitle: mine,
        );
        expect(
          publicProfileDirectMessageOffered(
            identity: identity,
            hasHandler: true,
            viewerLoopId: mine,
          ),
          isFalse,
        );
        expect(
          publicProfileDirectMessageOffered(
            identity: identity,
            hasHandler: true,
            viewerLoopId: 'LOOP-3HJKMNPQ',
          ),
          isTrue,
        );
        // An unread profile answers nothing, and a card with no command target
        // is never a conversation.
        expect(
          publicProfileDirectMessageOffered(
            identity: identity,
            hasHandler: true,
            viewerLoopId: null,
          ),
          isTrue,
        );
        expect(
          publicProfileDirectMessageOffered(
            identity: const PublicProfileIdentity(
              publicProfileId: null,
              displayName: 'frog_maxi',
            ),
            hasHandler: true,
            viewerLoopId: null,
          ),
          isFalse,
        );
      },
    );

    testWidgets('the follow badge repeats the server answer', (tester) async {
      final social = FakeSocialGateway();
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
        social: social,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      // The relationship is not part of the member directory, so the sheet
      // says so instead of guessing a state.
      expect(
        find.byKey(const ValueKey<String>('public-profile-follow-unknown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-follow-state')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-follow')),
      );
      await tester.pumpAndSettle();

      expect(social.commands, contains('follow:$testMemberId:true'));
      expect(find.text('已关注'), findsOneWidget);
    });

    testWidgets('a refused follow keeps the state and explains', (
      tester,
    ) async {
      final social = FakeSocialGateway(
        writeFailure: CommunityFailureKind.notFound,
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
        social: social,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-follow')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已关注'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('public-profile-failure')),
        findsOneWidget,
      );
      expect(find.textContaining('目标不存在'), findsOneWidget);
    });

    testWidgets('a member without a profile row cannot be followed', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(
            items: <CommunityMemberEntry>[
              testMember(role: CommunityRole.member, publicProfileId: null),
            ],
          ),
        ),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-not-targetable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-follow')),
        findsNothing,
      );
    });

    testWidgets('governance commands ride on the same sheet', (tester) async {
      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-mute')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-action-mute')),
      );
      await tester.pumpAndSettle();
      // The second confirmation still stands between the sheet and the write.
      expect(
        find.byKey(const ValueKey<String>('member-confirm-sheet')),
        findsOneWidget,
      );
      expect(gateway.commands.where((c) => c.startsWith('mute:')), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands, contains('mute:$testMemberId:true'));
    });

    testWidgets('a member viewer is offered no governance command', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(
            viewer: testViewer(
              role: CommunityRole.member,
              canInviteAdmin: false,
              canMute: false,
              canBan: false,
            ),
            items: <CommunityMemberEntry>[
              // A plain member holds no governance right, so the server
              // publishes an empty command list for every row it sends them.
              testMember(
                role: CommunityRole.member,
                actions: const <CommunityGovernanceAction>[],
              ),
            ],
          ),
        ),
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      for (final action in CommunityGovernanceAction.values) {
        expect(
          find.byKey(ValueKey<String>('public-profile-action-${action.name}')),
          findsNothing,
          reason: action.name,
        );
      }
    });
  });

  group('community application', () {
    testWidgets('an invalid slug never leaves the device', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _directory(),
        createdDetail: testDetail(),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      await _openApplyForm(tester);
      await _fillApplication(tester, slug: 'NO');
      await tester.tap(
        find.byKey(const ValueKey<String>('community-apply-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('3–32 位小写字母'), findsOneWidget);
      expect(gateway.commands.where((c) => c.startsWith('create:')), isEmpty);
    });

    testWidgets('an accepted application opens the created community', (
      tester,
    ) async {
      final opened = <String>[];
      final gateway = FakeCommunityGateway(
        directoryPage: _directory(),
        createdDetail: testDetail(
          community: testCommunity(verification: CommunityVerification.pending),
        ),
      );
      await pumpCommunityPage(
        tester,
        CommunityDiscoverScreen(onOpenCommunity: opened.add),
        community: gateway,
      );

      await _openApplyForm(tester);
      await _fillApplication(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-apply-submit')),
      );
      await tester.pumpAndSettle();

      // The application is confirmed before it is submitted.
      expect(
        find.byKey(const ValueKey<String>('community-apply-confirm-sheet')),
        findsOneWidget,
      );
      expect(gateway.commands.where((c) => c.startsWith('create:')), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('create:frog-holders'));
      expect(find.text('社区申请已提交，状态为审核中'), findsOneWidget);
      expect(opened, <String>[testCommunityId]);
    });

    testWidgets('cancelling the confirmation submits nothing', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: _directory(),
        createdDetail: testDetail(),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      await _openApplyForm(tester);
      await _fillApplication(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-apply-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-cancel')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands.where((c) => c.startsWith('create:')), isEmpty);
    });

    testWidgets('each refusal code gets its own copy', (tester) async {
      for (final (kind, fragment) in <(CommunityFailureKind, String)>[
        (CommunityFailureKind.aliasReserved, 'LOOP 保留词'),
        (CommunityFailureKind.aliasBlocked, '运营屏蔽名单'),
        (CommunityFailureKind.resourceConflict, '短链接已经被另一个社区占用'),
        (CommunityFailureKind.validationFailed, '名称或简介太长'),
        (CommunityFailureKind.activationRequired, '先完成 LOOP ID 激活'),
      ]) {
        final opened = <String>[];
        final gateway = FakeCommunityGateway(
          directoryPage: _directory(),
          createdDetail: testDetail(),
          writeFailure: kind,
        );
        await pumpCommunityPage(
          tester,
          CommunityDiscoverScreen(onOpenCommunity: opened.add),
          community: gateway,
        );

        await _openApplyForm(tester);
        await _fillApplication(tester);
        await tester.tap(
          find.byKey(const ValueKey<String>('community-apply-submit')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('community-confirm-accept')),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(fragment), findsOneWidget, reason: '$kind');
        expect(find.text('社区申请已提交，状态为审核中'), findsNothing, reason: '$kind');
        expect(opened, isEmpty, reason: '$kind');
      }
    });

    testWidgets('a gated capability disables the application entry', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: FakeCommunityGateway(directoryPage: _directory()),
        meta: testMetaSnapshot(
          community: LoopV2CapabilityAvailability.deferred,
        ),
      );

      // A closed gate takes the whole page: the directory, the rule notice
      // and the application entry all go with it, so there is no entry left to
      // press rather than a disabled one.
      expect(
        find.byKey(
          const ValueKey<String>('community-discover-capability-unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-apply-action')),
        findsNothing,
      );
    });
  });

  group('community application shape', () {
    test('the local check mirrors the server field rules', () {
      CommunityApplicationField? invalid(CommunityApplication application) =>
          application.invalidField;

      expect(
        invalid(
          const CommunityApplication(name: 'Frogs', slug: 'frog-holders'),
        ),
        isNull,
      );
      expect(
        invalid(const CommunityApplication(name: '', slug: 'frog-holders')),
        CommunityApplicationField.name,
      );
      expect(
        invalid(CommunityApplication(name: 'a' * 41, slug: 'frog-holders')),
        CommunityApplicationField.name,
      );
      expect(
        invalid(const CommunityApplication(name: 'Frogs', slug: 'Frogs')),
        CommunityApplicationField.slug,
      );
      expect(
        invalid(
          CommunityApplication(
            name: 'Frogs',
            slug: 'frog-holders',
            description: 'x' * 281,
          ),
        ),
        CommunityApplicationField.description,
      );
      expect(
        invalid(
          const CommunityApplication(
            name: 'Frogs',
            slug: 'frog-holders',
            boundAssetKey: 'eip155:56:0xnothex',
          ),
        ),
        CommunityApplicationField.boundAssetKey,
      );
      expect(
        invalid(
          const CommunityApplication(
            name: 'Frogs',
            slug: 'frog-holders',
            boundAssetKey:
                'eip155:56:0x00000000000000000000000000000000000000aa',
          ),
        ),
        isNull,
      );
    });
  });
}
