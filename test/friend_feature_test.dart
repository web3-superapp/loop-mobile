import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart'
    show LoopSelectionCheck;
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/friends/friend_screens.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/social/memory_friend_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';

FriendProfileRef _profileRef(String value) => FriendProfileRef.fromWire(value);

void main() {
  testWidgets('创建群组 (decision 0127): no English eyebrow, OKX pick rows, '
      'one Lime button', (tester) async {
    await _pumpPage(
      tester,
      const CreateFriendGroupPage(),
      gateway: MemoryFriendGateway(),
    );
    await tester.pumpAndSettle();
    expect(find.text('NEW GROUP'), findsNothing);
    expect(find.textContaining('NEW GROUP'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Divider), findsNothing);
    final submit = find.byKey(
      const ValueKey<String>('friend-group-create-submit'),
    );
    await tester.ensureVisible(submit);
    expect(tester.widget<LoopButton>(submit).label, '创建群组');
    expect(tester.widget<LoopButton>(submit).block, isTrue);
    expect(tester.widget<LoopButton>(submit).primary, isTrue);
    // Decision 0168: the flow is the prototype's — a quiet folio, a labelled
    // group of pickable rows with the shared round check, one block button —
    // and no retired shell is left on it.
    expect(find.byType(LoopFocusPage), findsOneWidget);
    final folio = tester.widget<LoopFolioPrimary>(
      find.byType(LoopFolioPrimary),
    );
    expect(folio.variant, LoopFolioVariant.quiet);
    expect(find.byType(LoopRecordGroup), findsOneWidget);
    expect(find.byType(LoopSelectionCheck), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('friend-preview-banner')),
      findsOneWidget,
    );
    expect(find.byType(LoopNotice), findsWidgets);
    expect(find.byType(LoopFlatField), findsOneWidget);
    expect(find.byType(LoopPage), findsNothing);
    expect(find.byType(LoopStateCard), findsNothing);
    expect(find.byType(LoopStatusPill), findsNothing);
    expect(find.byType(LoopSectionLabel), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  test('friend inputs allow shared aliases but reject duplicate identities and non-v4 IDs', () {
    expect(normalizeFriendAliasQuery('  NightOwl  '), 'NightOwl');
    final foldedSpaceQuery = 'A${List<String>.filled(40, ' ').join()}B';
    expect(normalizeFriendAliasQuery(foldedSpaceQuery), foldedSpaceQuery);
    expect(
      () => normalizeFriendAliasQuery('unsafe\u202Ealias'),
      throwsA(isA<InvalidFriendContractException>()),
    );
    expect(
      () => normalizeFriendAliasQuery('unsafe\u00ADalias'),
      throwsA(isA<InvalidFriendContractException>()),
    );
    expect(
      () => validateSelectedFriendRefs(<FriendProfileRef>[
        _profileRef('only-one'),
      ]),
      throwsA(isA<InvalidFriendContractException>()),
    );
    expect(
      () => validateSelectedFriendRefs(<FriendProfileRef>[
        _profileRef('same'),
        _profileRef('same'),
      ]),
      throwsA(isA<InvalidFriendContractException>()),
    );
    expect(validateFriendOperationId(_requestId), _requestId);
    expect(
      () => validateFriendOperationId('not-a-v4-id'),
      throwsA(isA<InvalidFriendContractException>()),
    );
    final maximumCursor = List<String>.filled(1024, 'c').join();
    expect(
      FriendDirectoryPage(
        items: const <FriendIdentity>[],
        nextCursor: maximumCursor,
      ).nextCursor,
      maximumCursor,
    );
    expect(
      () => FriendRequestPage(
        items: const <FriendRequestRecord>[],
        nextCursor: '${maximumCursor}c',
      ),
      throwsA(isA<InvalidFriendContractException>()),
    );
    expect(
      FriendIdentity.fromBackend(
        publicProfileId: FriendProfileRef.fromPublicProfileId(
          'aaaaaaaa-1111-4111-8111-111111111111',
        ),
        profileCode: 'ABCDEFGHJK',
        alias: 'Alias',
        avatarRef: 'avatar:users/example.png',
      ).avatarRef,
      'avatar:users/example.png',
    );
    expect(
      () => FriendIdentity.fromBackend(
        publicProfileId: FriendProfileRef.fromPublicProfileId(
          'aaaaaaaa-1111-4111-8111-111111111111',
        ),
        profileCode: 'ABCDEFGHJK',
        alias: 'Alias',
        avatarRef: 'https://example.invalid/avatar.png',
      ),
      throwsA(isA<InvalidFriendContractException>()),
    );
    final sharedAliasResults = validateFriendSearchResults(<FriendSearchResult>[
      FriendSearchResult(
        identity: FriendIdentity(
          profileRef: _profileRef('search-result-one'),
          alias: 'SameAlias',
        ),
        relationship: FriendRelationship.none,
      ),
      FriendSearchResult(
        identity: FriendIdentity(
          profileRef: _profileRef('search-result-two'),
          alias: 'samealias',
        ),
        relationship: FriendRelationship.none,
      ),
    ]);
    expect(sharedAliasResults, hasLength(2));
    expect(
      () => validateFriendSearchResults(<FriendSearchResult>[
        FriendSearchResult(
          identity: FriendIdentity(
            profileRef: _profileRef('search-result-three'),
            alias: 'First',
            profileCode: '0123456789',
          ),
          relationship: FriendRelationship.none,
        ),
        FriendSearchResult(
          identity: FriendIdentity(
            profileRef: _profileRef('search-result-four'),
            alias: 'Second',
            profileCode: '0123456789',
          ),
          relationship: FriendRelationship.none,
        ),
      ]),
      throwsA(isA<InvalidFriendContractException>()),
    );
  });

  test(
    'Preview request becomes pending but never becomes an accepted friend',
    () async {
      final gateway = MemoryFriendGateway();
      final before = await gateway.loadFriends();
      final results = await gateway.searchByAlias('mia');

      expect(results, hasLength(1));
      expect(results.single.relationship, FriendRelationship.none);

      final requested = await gateway.sendFriendRequest(
        requestId: _requestId,
        profileRef: results.single.identity.profileRef,
      );
      final repeated = await gateway.sendFriendRequest(
        requestId: _requestId,
        profileRef: results.single.identity.profileRef,
      );

      expect(requested.relationship, FriendRelationship.requestPending);
      expect(repeated, requested);
      expect(await gateway.loadFriends(), before);
    },
  );

  test('search results retire after the page stops listening', () async {
    final gateway = MemoryFriendGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final first = container.listen(
      friendSearchControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    await container.read(friendSearchControllerProvider.notifier).search('mia');
    expect(
      container.read(friendSearchControllerProvider).results,
      hasLength(1),
    );

    first.close();
    await container.pump();

    final second = container.listen(
      friendSearchControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(second.close);
    expect(
      container.read(friendSearchControllerProvider).phase,
      FriendSearchPhase.idle,
    );
    expect(container.read(friendSearchControllerProvider).results, isEmpty);
  });

  test('unknown friend request stays frozen after a search refresh', () async {
    final gateway = _OutcomeUnknownFriendGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendSearchControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(friendSearchControllerProvider.notifier);

    await controller.search('mia');
    final profileRef = container
        .read(friendSearchControllerProvider)
        .results
        .single
        .identity
        .profileRef;
    await controller.sendRequest(profileRef);
    expect(gateway.requestCount, 1);
    expect(
      container.read(friendSearchControllerProvider).outcomeUnknownProfileRefs,
      contains(profileRef),
    );

    await controller.search('mia');
    expect(
      container.read(friendSearchControllerProvider).outcomeUnknownProfileRefs,
      contains(profileRef),
    );
    await controller.sendRequest(profileRef);
    expect(gateway.requestCount, 1);
  });

  test(
    'unknown friend request survives route disposal in this session',
    () async {
      final gateway = _OutcomeUnknownFriendGateway();
      final container = ProviderContainer(
        overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final first = container.listen(
        friendSearchControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      final controller = container.read(
        friendSearchControllerProvider.notifier,
      );
      await controller.search('mia');
      final profileRef = container
          .read(friendSearchControllerProvider)
          .results
          .single
          .identity
          .profileRef;
      await controller.sendRequest(profileRef);

      first.close();
      await container.pump();
      final second = container.listen(
        friendSearchControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(second.close);

      final restored = container.read(friendSearchControllerProvider);
      expect(restored.failureKind, FriendGatewayFailureKind.outcomeUnknown);
      expect(restored.outcomeUnknownProfileRefs, contains(profileRef));
      await container
          .read(friendSearchControllerProvider.notifier)
          .sendRequest(profileRef);
      expect(gateway.requestCount, 1);
    },
  );

  test(
    'friend request accepts only pending and treats friend as unknown',
    () async {
      final gateway = _AcceptedResponseFriendGateway();
      final container = ProviderContainer(
        overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        friendSearchControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(
        friendSearchControllerProvider.notifier,
      );
      await controller.search('mia');
      final profileRef = container
          .read(friendSearchControllerProvider)
          .results
          .single
          .identity
          .profileRef;

      await controller.sendRequest(profileRef);

      final state = container.read(friendSearchControllerProvider);
      expect(state.failureKind, FriendGatewayFailureKind.outcomeUnknown);
      expect(state.outcomeUnknownProfileRefs, contains(profileRef));
    },
  );

  test('explicit unexpected friend rejection remains retryable', () async {
    final gateway = _FailFirstFriendGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendSearchControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(friendSearchControllerProvider.notifier);
    await controller.search('mia');
    final profileRef = container
        .read(friendSearchControllerProvider)
        .results
        .single
        .identity
        .profileRef;

    await controller.sendRequest(profileRef);
    expect(
      container.read(friendSearchControllerProvider).failureKind,
      FriendGatewayFailureKind.unexpected,
    );
    expect(
      container.read(friendSearchControllerProvider).outcomeUnknownProfileRefs,
      isEmpty,
    );
    await controller.sendRequest(profileRef);

    expect(gateway.requestIds, hasLength(2));
    expect(gateway.requestIds.toSet(), hasLength(2));
    expect(
      container
          .read(friendSearchControllerProvider)
          .results
          .single
          .relationship,
      FriendRelationship.requestPending,
    );
  });

  test(
    'Preview group creation is idempotent and never returns a Stream CID',
    () async {
      final gateway = MemoryFriendGateway();
      final friends = await gateway.loadFriends();
      final selected = friends
          .take(2)
          .map((friend) => friend.profileRef)
          .toList();

      final first = await gateway.createGroup(
        requestId: _requestId,
        normalizedName: 'Spot Research',
        friendRefs: selected,
      );
      final repeated = await gateway.createGroup(
        requestId: _requestId,
        normalizedName: 'Spot Research',
        friendRefs: selected,
      );

      expect(repeated, first);
      expect(first.streamCid, isNull);
      expect(gateway.createdGroups, hasLength(1));
      await expectLater(
        gateway.createGroup(
          requestId: _requestId,
          normalizedName: 'Changed draft',
          friendRefs: selected,
        ),
        throwsA(
          isA<FriendGatewayException>().having(
            (error) => error.kind,
            'kind',
            FriendGatewayFailureKind.conflict,
          ),
        ),
      );
    },
  );

  test(
    'unknown group outcome freezes the draft and is never resubmitted',
    () async {
      final gateway = _OutcomeUnknownGroupGateway();
      final container = ProviderContainer(
        overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        friendGroupControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(friendGroupControllerProvider.notifier);

      controller.editName('Spot Research');
      controller.toggleFriend(_profileRef('preview-profile-nightowl'));
      controller.toggleFriend(_profileRef('preview-profile-sable'));
      await controller.create();

      final failed = container.read(friendGroupControllerProvider);
      expect(failed.phase, FriendGroupPhase.failure);
      expect(failed.requestId, isNotNull);
      expect(failed.failureKind, FriendGatewayFailureKind.outcomeUnknown);
      expect(failed.canCreate, isFalse);
      expect(failed.canResumeEditing, isFalse);
      controller.editName('Changed after unknown result');
      expect(
        container.read(friendGroupControllerProvider).name,
        'Spot Research',
      );

      await controller.create();
      expect(gateway.requestIds, hasLength(1));
    },
  );

  test('unknown group draft survives route disposal in this session', () async {
    final gateway = _OutcomeUnknownGroupGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final first = container.listen(
      friendGroupControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    final controller = container.read(friendGroupControllerProvider.notifier);
    controller.editName('Spot Research');
    controller.toggleFriend(_profileRef('preview-profile-nightowl'));
    controller.toggleFriend(_profileRef('preview-profile-sable'));
    await controller.create();
    final requestId = container.read(friendGroupControllerProvider).requestId;

    first.close();
    await container.pump();
    final second = container.listen(
      friendGroupControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(second.close);

    final restored = container.read(friendGroupControllerProvider);
    expect(restored.name, 'Spot Research');
    expect(restored.requestId, requestId);
    expect(restored.failureKind, FriendGatewayFailureKind.outcomeUnknown);
    container.read(friendGroupControllerProvider.notifier).reset();
    await container.read(friendGroupControllerProvider.notifier).create();
    expect(gateway.requestIds, hasLength(1));
  });

  test('definitive group rejection can be edited as a new intent', () async {
    final gateway = _FailFirstGroupGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendGroupControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(friendGroupControllerProvider.notifier);

    controller.editName('Spot Research');
    controller.toggleFriend(_profileRef('preview-profile-nightowl'));
    controller.toggleFriend(_profileRef('preview-profile-sable'));
    await controller.create();

    final failed = container.read(friendGroupControllerProvider);
    expect(failed.phase, FriendGroupPhase.failure);
    expect(failed.failureKind, FriendGatewayFailureKind.permissionDenied);
    expect(failed.canResumeEditing, isTrue);
    controller.resumeEditing();
    controller.editName('Spot Research 2');
    await controller.create();

    final created = container.read(friendGroupControllerProvider);
    expect(created.phase, FriendGroupPhase.created);
    expect(created.receipt?.streamCid, isNull);
    expect(gateway.requestIds, hasLength(2));
    expect(gateway.requestIds.toSet(), hasLength(2));
  });

  test('explicit unexpected group rejection remains editable', () async {
    final gateway = _FailFirstGroupGateway(
      failureKind: FriendGatewayFailureKind.unexpected,
    );
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendGroupControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(friendGroupControllerProvider.notifier);
    controller.editName('Spot Research');
    controller.toggleFriend(_profileRef('preview-profile-nightowl'));
    controller.toggleFriend(_profileRef('preview-profile-sable'));

    await controller.create();
    expect(
      container.read(friendGroupControllerProvider).failureKind,
      FriendGatewayFailureKind.unexpected,
    );
    expect(
      container.read(friendGroupControllerProvider).canResumeEditing,
      isTrue,
    );
    controller.resumeEditing();
    await controller.create();

    expect(gateway.requestIds, hasLength(2));
    expect(gateway.requestIds.toSet(), hasLength(2));
    expect(
      container.read(friendGroupControllerProvider).phase,
      FriendGroupPhase.created,
    );
  });

  test(
    'production group receipt without a Chat CID stays unconfirmed',
    () async {
      final gateway = _ProductionGroupGateway(streamCid: null);
      final container = ProviderContainer(
        overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        friendGroupControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(friendGroupControllerProvider.notifier);

      controller.editName('Spot Research');
      controller.toggleFriend(_profileRef('preview-profile-nightowl'));
      controller.toggleFriend(_profileRef('preview-profile-sable'));
      await controller.create();

      final state = container.read(friendGroupControllerProvider);
      expect(state.phase, FriendGroupPhase.failure);
      expect(state.failureKind, FriendGatewayFailureKind.outcomeUnknown);
      expect(state.canCreate, isFalse);
    },
  );

  testWidgets('production friend surfaces fail closed without controls', (
    tester,
  ) async {
    await _pumpPage(tester, const CreateFriendGroupPage());
    expect(
      find.byKey(const ValueKey<String>('friend-group-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('开发预览'), findsNothing);
  });

  testWidgets('gateway rotation clears the visible group text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        friendGatewayProvider.overrideWithValue(MemoryFriendGateway()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: CreateFriendGroupPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('friend-group-name-input')),
      'Previous account group',
    );
    container.updateOverrides([
      friendGatewayProvider.overrideWithValue(MemoryFriendGateway()),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('friend-group-name-input')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('unknown group name restores after route disposal', (
    tester,
  ) async {
    final gateway = _OutcomeUnknownGroupGateway();
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendGroupControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    final controller = container.read(friendGroupControllerProvider.notifier);
    controller.editName('Spot Research');
    controller.toggleFriend(_profileRef('preview-profile-nightowl'));
    controller.toggleFriend(_profileRef('preview-profile-sable'));
    await controller.create();
    subscription.close();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: CreateFriendGroupPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('friend-group-name-input')),
          )
          .controller
          ?.text,
      'Spot Research',
    );
    expect(find.text('群组创建结果待确认'), findsOneWidget);
  });

  testWidgets(
    'Preview selects accepted friends and creates no Stream channel',
    (tester) async {
      final gateway = MemoryFriendGateway();
      await _pumpPage(tester, const CreateFriendGroupPage(), gateway: gateway);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('friend-group-name-input')),
        'Spot Research',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('friend-select-result-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('friend-select-result-0')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('friend-select-result-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('friend-select-result-1')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('friend-group-create-submit')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('friend-group-create-submit')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('friend-group-create-submit')),
      );
      await tester.pumpAndSettle();

      final groupState = ProviderScope.containerOf(
        tester.element(find.byType(CreateFriendGroupPage)),
      ).read(friendGroupControllerProvider);
      expect(groupState.phase, FriendGroupPhase.created);

      expect(
        find.byKey(const ValueKey<String>('friend-group-created-preview')),
        findsOneWidget,
      );
      expect(find.textContaining('未创建 Stream 频道'), findsOneWidget);
      expect(gateway.createdGroups, hasLength(1));
      expect(gateway.createdGroups.single.streamCid, isNull);
    },
  );

  testWidgets(
    'production group success requires a canonical CID and routes to guarded Chat',
    (tester) async {
      final gateway = _ProductionGroupGateway();
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const CreateFriendGroupPage(),
          ),
          GoRoute(
            path: '/chat/channel/:cid',
            builder: (context, state) =>
                Text('opened-${state.pathParameters['cid']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [friendGatewayProvider.overrideWithValue(gateway)],
          child: MaterialApp.router(
            theme: LoopTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('friend-group-name-input')),
        'Spot Research',
      );
      for (final index in <int>[0, 1]) {
        final friend = find.byKey(
          ValueKey<String>('friend-select-result-$index'),
        );
        await tester.ensureVisible(friend);
        await tester.tap(friend);
        await tester.pump();
      }
      final submit = find.byKey(
        const ValueKey<String>('friend-group-create-submit'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('friend-group-created')),
        findsOneWidget,
      );
      expect(find.text('群组已创建'), findsOneWidget);
      expect(find.textContaining('开发预览群组'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('friend-group-open-channel')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('opened-messaging:loop_group_created_1'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Chat add menu exposes create-group and add-friend routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const ChatInboxPage()),
        GoRoute(
          path: '/chat/groups/create',
          builder: (context, state) => const Text('group-route'),
        ),
        // `/chat/friends/add` was retired in step 3; the add-friend menu
        // item now opens the V2 global search.
        GoRoute(
          path: '/search',
          builder: (context, state) => const Text('search-route'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('chat-create-menu')));
    await tester.pumpAndSettle();
    // Decision 0110: 「＋」 is one sheet with every way to start something.
    expect(find.text('创建群聊'), findsOneWidget);
    expect(find.text('搜索 / 添加用户'), findsOneWidget);
    expect(find.text('创建社区'), findsOneWidget);
    expect(find.text('扫一扫'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-create-group-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(find.text('group-route'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('chat-create-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-add-friend-menu-item')),
    );
    await tester.pumpAndSettle();
    expect(find.text('search-route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Profile exposes 陌生人请求 and the retired friend routes fail closed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: ProviderScope(
            // Decision 0175: the row hangs on 设置, behind 我's gear.
            child: ProfileSurfaceScreen.fromId(
              'settings',
              onNavigate: (value) => destination = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('陌生人请求'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Decision 0133: the row carries the name of the page it opens.
      await tester.ensureVisible(find.text('陌生人请求'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('陌生人请求'));
      expect(destination, 'friend-requests');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

      // Both locations were folded into `search` + `connections`: they are no
      // longer mounted and land back on Community as informational retirements.
      router.go('/profile/friends');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/chat');

      router.go('/chat/friends/add');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/chat');

      // Step 4 folded the V1 request inbox into `dm-requests`: the legacy
      // location is no longer mounted and lands back on Community.
      router.go('/chat/friends/requests');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/chat');
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget page, {
  FriendGateway? gateway,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gateway != null) friendGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(theme: LoopTheme.dark, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

final class _OutcomeUnknownFriendGateway implements FriendGateway {
  final MemoryFriendGateway _delegate = MemoryFriendGateway();
  var requestCount = 0;

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) => _delegate.createGroup(
    requestId: requestId,
    normalizedName: normalizedName,
    friendRefs: friendRefs,
  );

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    requestCount += 1;
    throw const FriendGatewayException(FriendGatewayFailureKind.outcomeUnknown);
  }
}

final class _AcceptedResponseFriendGateway implements FriendGateway {
  final MemoryFriendGateway _delegate = MemoryFriendGateway();

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) => _delegate.createGroup(
    requestId: requestId,
    normalizedName: normalizedName,
    friendRefs: friendRefs,
  );

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    final result = (await _delegate.searchByAlias('mia')).single;
    return FriendSearchResult(
      identity: result.identity,
      relationship: FriendRelationship.friend,
    );
  }
}

final class _FailFirstFriendGateway implements FriendGateway {
  final MemoryFriendGateway _delegate = MemoryFriendGateway();
  final List<String> requestIds = <String>[];
  var _failed = false;

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) => _delegate.createGroup(
    requestId: requestId,
    normalizedName: normalizedName,
    friendRefs: friendRefs,
  );

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    requestIds.add(requestId);
    if (!_failed) {
      _failed = true;
      throw const FriendGatewayException(FriendGatewayFailureKind.unexpected);
    }
    return _delegate.sendFriendRequest(
      requestId: requestId,
      profileRef: profileRef,
    );
  }
}

final class _FailFirstGroupGateway implements FriendGateway {
  _FailFirstGroupGateway({
    this.failureKind = FriendGatewayFailureKind.permissionDenied,
  });

  final MemoryFriendGateway _delegate = MemoryFriendGateway();
  final List<String> requestIds = <String>[];
  final FriendGatewayFailureKind failureKind;
  var _failed = false;

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    requestIds.add(requestId);
    if (!_failed) {
      _failed = true;
      throw FriendGatewayException(failureKind);
    }
    return _delegate.createGroup(
      requestId: requestId,
      normalizedName: normalizedName,
      friendRefs: friendRefs,
    );
  }

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) =>
      _delegate.sendFriendRequest(requestId: requestId, profileRef: profileRef);
}

final class _OutcomeUnknownGroupGateway implements FriendGateway {
  final MemoryFriendGateway _delegate = MemoryFriendGateway();
  final List<String> requestIds = <String>[];

  @override
  FriendGatewayMode get mode => FriendGatewayMode.preview;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    requestIds.add(requestId);
    throw const FriendGatewayException(FriendGatewayFailureKind.outcomeUnknown);
  }

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) =>
      _delegate.sendFriendRequest(requestId: requestId, profileRef: profileRef);
}

final class _ProductionGroupGateway implements FriendGateway {
  _ProductionGroupGateway({this.streamCid = 'messaging:loop_group_created_1'});

  final MemoryFriendGateway _delegate = MemoryFriendGateway();
  final String? streamCid;

  @override
  FriendGatewayMode get mode => FriendGatewayMode.production;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async => CreatedFriendGroup(
    requestId: requestId,
    groupId: streamCid == null ? null : '22222222-2222-4222-8222-222222222222',
    name: normalizedName,
    friendRefs: friendRefs,
    streamCid: streamCid,
  );

  @override
  Future<List<FriendIdentity>> loadFriends() => _delegate.loadFriends();

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      _delegate.searchByAlias(normalizedQuery);

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) =>
      _delegate.sendFriendRequest(requestId: requestId, profileRef: profileRef);
}
