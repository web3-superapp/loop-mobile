import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/social/memory_friend_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';

FriendProfileRef _profileRef(String value) => FriendProfileRef.fromWire(value);

void main() {
  test(
    'friend inputs reject unsafe aliases, duplicate refs, and non-v4 IDs',
    () {
      expect(normalizeFriendAliasQuery('  NightOwl  '), 'NightOwl');
      expect(
        () => normalizeFriendAliasQuery('unsafe\u202Ealias'),
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
      expect(
        () => validateFriendSearchResults(<FriendSearchResult>[
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
        ]),
        throwsA(isA<InvalidFriendContractException>()),
      );
    },
  );

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
    await _pumpPage(tester, const AddFriendPage());
    expect(
      find.byKey(const ValueKey<String>('friend-search-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('开发预览'), findsNothing);

    await _pumpPage(tester, const CreateFriendGroupPage());
    expect(
      find.byKey(const ValueKey<String>('friend-group-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(Checkbox), findsNothing);

    await _pumpPage(tester, const FriendListPage());
    expect(
      find.byKey(const ValueKey<String>('friends-service-unavailable')),
      findsOneWidget,
    );
    expect(find.text('NightOwl'), findsNothing);
  });

  testWidgets('gateway rotation clears visible friend and group text', (
    tester,
  ) async {
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
        child: const MaterialApp(home: AddFriendPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('friend-alias-search-input')),
      'previous-account-alias',
    );
    container.updateOverrides([
      friendGatewayProvider.overrideWithValue(MemoryFriendGateway()),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('friend-alias-search-input')),
          )
          .controller
          ?.text,
      isEmpty,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreateFriendGroupPage()),
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

  testWidgets('unknown friend query restores after route disposal', (
    tester,
  ) async {
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
    final controller = container.read(friendSearchControllerProvider.notifier);
    await controller.search('mia');
    await controller.sendRequest(
      container
          .read(friendSearchControllerProvider)
          .results
          .single
          .identity
          .profileRef,
    );
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
        child: const MaterialApp(home: AddFriendPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('friend-alias-search-input')),
          )
          .controller
          ?.text,
      'mia',
    );
    expect(find.text('结果待确认'), findsOneWidget);
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
        child: const MaterialApp(home: CreateFriendGroupPage()),
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

  testWidgets('definitive friend rejection copy never claims unknown outcome', (
    tester,
  ) async {
    final gateway = _FailFirstFriendGateway();
    await _pumpPage(tester, const AddFriendPage(), gateway: gateway);
    await tester.enterText(
      find.byKey(const ValueKey<String>('friend-alias-search-input')),
      'mia',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('friend-alias-search-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('friend-add-result-0')));
    await tester.pumpAndSettle();

    expect(find.text('好友请求未发送'), findsOneWidget);
    expect(find.text('服务暂时无法完成请求；没有好友关系或群组被修改。'), findsOneWidget);
    expect(find.textContaining('无法确认'), findsNothing);
  });

  testWidgets('Preview can search an alias and send a pending request', (
    tester,
  ) async {
    final gateway = MemoryFriendGateway();
    await _pumpPage(tester, const AddFriendPage(), gateway: gateway);

    await tester.enterText(
      find.byKey(const ValueKey<String>('friend-alias-search-input')),
      'mia',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('friend-alias-search-submit')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('friend-alias-search-submit')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('friend-alias-search-submit')),
    );
    await tester.pumpAndSettle();

    final searchState = ProviderScope.containerOf(
      tester.element(find.byType(AddFriendPage)),
    ).read(friendSearchControllerProvider);
    expect(searchState.phase, FriendSearchPhase.ready);
    expect(searchState.results, hasLength(1));

    expect(find.text('onchain.mia'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('friend-add-result-0')));
    await tester.pumpAndSettle();

    expect(find.text('已发送'), findsOneWidget);
    expect(
      (await gateway.searchByAlias('mia')).single.relationship,
      FriendRelationship.requestPending,
    );
    expect(
      (await gateway.loadFriends()).map((friend) => friend.alias),
      isNot(contains('onchain.mia')),
    );
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
            .widget<FilledButton>(
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
      expect(find.text('opened-messaging:loop-created-1'), findsOneWidget);
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
        GoRoute(
          path: '/chat/friends/add',
          builder: (context, state) => const Text('friend-route'),
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
    expect(find.text('创建群组'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
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
    expect(find.text('friend-route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile exposes 我的好友 and application routes stay truthful', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? destination;
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: ProviderScope(
          child: ProfileSurfaceScreen.fromId(
            'profile',
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('我的好友'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的好友'));
    expect(destination, 'friends');
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
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    router.go('/profile/friends');
    await tester.pumpAndSettle();
    expect(find.byType(FriendListPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('friends-service-unavailable')),
      findsOneWidget,
    );

    router.go('/chat/friends/add');
    await tester.pumpAndSettle();
    expect(find.byType(AddFriendPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('friend-search-unavailable')),
      findsOneWidget,
    );
  });
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
  _ProductionGroupGateway({this.streamCid = 'messaging:loop-created-1'});

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
