import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/friends/friend_screens.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';

const _firstProfileId = '11111111-1111-4111-8111-111111111111';
const _secondProfileId = '22222222-2222-4222-8222-222222222222';
const _groupIdValue = '33333333-3333-4333-8333-333333333333';
const _groupAliasIdValue = '44444444-4444-4444-8444-444444444444';

void main() {
  group('server-created Chat intent safety', () {
    testWidgets(
      'group operator-required survives route disposal and blocks reset or a second UUID',
      (tester) async {
        final gateway = _OperatorSocialGateway();
        final container = ProviderContainer(
          overrides: [friendGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);

        await _pumpWithContainer(
          tester,
          container,
          const CreateFriendGroupPage(),
        );
        final controller = container.read(
          friendGroupControllerProvider.notifier,
        );
        controller.editName('Spot Research');
        controller.toggleFriend(_profileRef(_firstProfileId));
        controller.toggleFriend(_profileRef(_secondProfileId));
        await controller.create();
        await tester.pumpAndSettle();

        final frozen = container.read(friendGroupControllerProvider);
        expect(frozen.failureKind, FriendGatewayFailureKind.operatorRequired);
        expect(frozen.canCreate, isFalse);
        expect(frozen.canResumeEditing, isFalse);
        expect(frozen.canReconcile, isFalse);
        expect(gateway.groupOperationIds, hasLength(1));
        expect(validateFriendOperationId(frozen.requestId!), frozen.requestId);
        expect(
          find.byKey(const ValueKey<String>('friend-group-create-failure')),
          findsOneWidget,
        );
        expect(find.text('群组创建需人工核对'), findsOneWidget);
        expect(find.textContaining('频道需要后台人工核对；不会自动创建第二个频道。'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('friend-group-resume-editing')),
          findsNothing,
        );

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();

        expect(
          container.read(friendGroupControllerProvider).requestId,
          frozen.requestId,
        );
        expect(
          container.read(friendGroupControllerProvider).failureKind,
          FriendGatewayFailureKind.operatorRequired,
        );

        await _pumpWithContainer(
          tester,
          container,
          const CreateFriendGroupPage(),
        );
        final restoredController = container.read(
          friendGroupControllerProvider.notifier,
        );
        restoredController.reset();
        await restoredController.create();
        await tester.pumpAndSettle();

        final restored = container.read(friendGroupControllerProvider);
        expect(restored.requestId, frozen.requestId);
        expect(restored.failureKind, FriendGatewayFailureKind.operatorRequired);
        expect(gateway.groupOperationIds, <String>[frozen.requestId!]);
        expect(find.textContaining('频道需要后台人工核对；不会自动创建第二个频道。'), findsOneWidget);
      },
    );

    testWidgets(
      'direct operator-required is target-scoped and never allocates a second intent for that target',
      (tester) async {
        final gateway = _OperatorSocialGateway();
        final container = ProviderContainer(
          overrides: [friendGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        final firstListener = container.listen(
          friendDirectControllerProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        final controller = container.read(
          friendDirectControllerProvider.notifier,
        );
        final firstTarget = _profileRef(_firstProfileId);
        final secondTarget = _profileRef(_secondProfileId);

        await controller.open(firstTarget);
        final blocked = container.read(friendDirectControllerProvider);
        expect(blocked.failureKind, FriendGatewayFailureKind.operatorRequired);
        expect(
          validateFriendOperationId(blocked.operationId!),
          blocked.operationId,
        );
        expect(gateway.directOperationIds[firstTarget], hasLength(1));

        firstListener.close();
        await tester.pump();
        final secondListener = container.listen(
          friendDirectControllerProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(secondListener.close);
        expect(
          container.read(friendDirectControllerProvider).operationId,
          blocked.operationId,
        );

        await container
            .read(friendDirectControllerProvider.notifier)
            .open(firstTarget);
        expect(gateway.directOperationIds[firstTarget], <String>[
          blocked.operationId!,
        ]);

        await container
            .read(friendDirectControllerProvider.notifier)
            .open(secondTarget);
        final opened = container.read(friendDirectControllerProvider);
        expect(opened.phase, FriendDirectPhase.opened);
        expect(gateway.directOperationIds[secondTarget], hasLength(1));
        expect(
          gateway.directOperationIds[secondTarget]!.single,
          isNot(blocked.operationId),
        );

        container
            .read(friendDirectControllerProvider.notifier)
            .consumeReceipt();
        await container
            .read(friendDirectControllerProvider.notifier)
            .open(firstTarget);
        final restoredBlocked = container.read(friendDirectControllerProvider);
        expect(
          restoredBlocked.failureKind,
          FriendGatewayFailureKind.operatorRequired,
        );
        expect(restoredBlocked.operationId, blocked.operationId);
        expect(gateway.directOperationIds[firstTarget], <String>[
          blocked.operationId!,
        ]);

        await _pumpWithContainer(tester, container, const FriendListPage());
        expect(
          find.byKey(const ValueKey<String>('friend-direct-failure')),
          findsOneWidget,
        );
        expect(find.text('频道需要后台人工核对；不会自动创建第二个频道。'), findsOneWidget);
      },
    );
  });

  group('group Alias presentation safety', () {
    testWidgets('invalid route group ID fails closed with zero gateway calls', (
      tester,
    ) async {
      final gateway = _ScenarioGroupAliasGateway();

      await _pumpAliasRoute(
        tester,
        gateway,
        const GroupAliasRoutePage(routeGroupId: 'messaging:loop_group_unsafe'),
      );

      expect(find.text('群组引用无效'), findsOneWidget);
      expect(find.textContaining('没有发起网络请求'), findsOneWidget);
      expect(gateway.loadCalls, 0);
      expect(gateway.putCalls, 0);
      expect(gateway.searchCalls, 0);
    });

    for (final scenario in _AliasPutScenario.values) {
      testWidgets(
        '404 allows first Alias reservation and ${scenario.name} stays truthful',
        (tester) async {
          final gateway = _ScenarioGroupAliasGateway(putScenario: scenario);
          await _pumpAliasRoute(
            tester,
            gateway,
            const GroupAliasRoutePage(routeGroupId: _groupIdValue),
          );

          expect(gateway.loadCalls, 1);
          expect(
            find.byKey(const ValueKey<String>('group-alias-input')),
            findsOneWidget,
          );
          await tester.enterText(
            find.byKey(const ValueKey<String>('group-alias-input')),
            '  Night Owl  ',
          );
          await _tap(
            tester,
            find.byKey(const ValueKey<String>('group-alias-submit')),
          );

          expect(gateway.putAliases, <String>['Night Owl']);
          switch (scenario) {
            case _AliasPutScenario.confirmed:
              expect(
                find.byKey(const ValueKey<String>('group-alias-reserved')),
                findsOneWidget,
              );
              expect(find.textContaining('已在当前群永久保留，不能修改'), findsOneWidget);
              expect(
                find.byKey(
                  const ValueKey<String>('group-alias-retry-projection'),
                ),
                findsNothing,
              );
            case _AliasPutScenario.pending:
              expect(
                find.byKey(const ValueKey<String>('group-alias-reserved')),
                findsOneWidget,
              );
              expect(find.textContaining('Stream 成员投影仍待确认'), findsOneWidget);
              expect(
                find.byKey(
                  const ValueKey<String>('group-alias-retry-projection'),
                ),
                findsOneWidget,
              );
            case _AliasPutScenario.outcomeUnknown:
              expect(
                find.byKey(
                  const ValueKey<String>('group-alias-outcome-unknown'),
                ),
                findsOneWidget,
              );
              expect(find.textContaining('可能已经永久保留'), findsOneWidget);
              expect(
                find.byKey(const ValueKey<String>('group-alias-reserved')),
                findsNothing,
              );
              expect(
                find.byKey(const ValueKey<String>('group-alias-retry-pending')),
                findsOneWidget,
              );
          }
        },
      );
    }

    testWidgets(
      'group Alias search renders only the Alias and no identity fields',
      (tester) async {
        final gateway = _ScenarioGroupAliasGateway(
          searchPage: GroupAliasSearchPage(
            items: <GroupAliasSearchItem>[
              GroupAliasSearchItem(
                groupAliasId: GroupAliasId.fromWire(_groupAliasIdValue),
                alias: 'Night Owl',
              ),
            ],
            truncated: false,
          ),
        );
        await _pumpAliasRoute(
          tester,
          gateway,
          const GroupAliasRoutePage(routeGroupId: _groupIdValue),
        );

        await tester.enterText(
          find.byKey(const ValueKey<String>('group-alias-search-input')),
          'Ni',
        );
        await _tap(
          tester,
          find.byKey(const ValueKey<String>('group-alias-search-submit')),
        );

        final row = find.byKey(const ValueKey<String>('group-alias-result-0'));
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text('Night Owl')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('当前群内昵称')),
          findsOneWidget,
        );
        expect(find.text(_groupAliasIdValue), findsNothing);
        expect(find.text(_groupIdValue), findsNothing);
        expect(find.textContaining('LOOP #'), findsNothing);
        expect(
          find.text('0x1111111111111111111111111111111111111111'),
          findsNothing,
        );
        expect(find.text('stream-user-private'), findsNothing);
        expect(gateway.searchPrefixes, <String>['Ni']);
      },
    );
  });
}

FriendProfileRef _profileRef(String value) =>
    FriendProfileRef.fromPublicProfileId(value);

FriendIdentity _friend({
  required String profileId,
  required String profileCode,
  required String alias,
}) => FriendIdentity.fromBackend(
  publicProfileId: _profileRef(profileId),
  profileCode: profileCode,
  alias: alias,
  avatarRef: null,
);

Future<void> _pumpWithContainer(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: LoopTheme.dark, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAliasRoute(
  WidgetTester tester,
  GroupAliasGateway gateway,
  Widget page,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [groupAliasGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(theme: LoopTheme.dark, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _OperatorSocialGateway implements LoopSocialFriendGateway {
  final List<FriendIdentity> _friends = <FriendIdentity>[
    _friend(
      profileId: _firstProfileId,
      profileCode: 'MAY0000001',
      alias: 'Maya',
    ),
    _friend(
      profileId: _secondProfileId,
      profileCode: 'SAGE000001',
      alias: 'Sage',
    ),
  ];

  final List<String> groupOperationIds = <String>[];
  final Map<FriendProfileRef, List<String>> directOperationIds =
      <FriendProfileRef, List<String>>{};

  @override
  FriendGatewayMode get mode => FriendGatewayMode.production;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    groupOperationIds.add(requestId);
    throw FriendGatewayException(
      FriendGatewayFailureKind.operatorRequired,
      operationId: requestId,
    );
  }

  @override
  Future<CreatedDirectFriendChannel> createDirectChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    directOperationIds
        .putIfAbsent(targetProfileRef, () => <String>[])
        .add(operationId);
    if (targetProfileRef == _profileRef(_firstProfileId)) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.operatorRequired,
        operationId: operationId,
      );
    }
    return CreatedDirectFriendChannel(
      operationId: operationId,
      targetProfileRef: targetProfileRef,
      streamCid: 'messaging:loop_direct_second_friend',
    );
  }

  @override
  Future<FriendDirectoryPage> loadFriendPage({String? cursor}) async =>
      FriendDirectoryPage(items: _friends, nextCursor: null);

  @override
  Future<List<FriendIdentity>> loadFriends() async =>
      List<FriendIdentity>.of(_friends);

  @override
  Future<FriendRequestPage> loadFriendRequests({
    required FriendRequestDirection direction,
    String? cursor,
  }) async =>
      FriendRequestPage(items: const <FriendRequestRecord>[], nextCursor: null);

  @override
  Future<FriendSearchPage> searchByAliasPage(String normalizedQuery) async =>
      FriendSearchPage(items: const <FriendSearchResult>[], truncated: false);

  @override
  Future<List<FriendSearchResult>> searchByAlias(
    String normalizedQuery,
  ) async => const <FriendSearchResult>[];

  @override
  Future<FriendRequestDecisionReceipt> decideFriendRequest({
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  }) => Future<FriendRequestDecisionReceipt>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) => Future<FriendRequestSendReceipt>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) => Future<FriendSearchResult>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );
}

enum _AliasPutScenario { confirmed, pending, outcomeUnknown }

final class _ScenarioGroupAliasGateway implements GroupAliasGateway {
  _ScenarioGroupAliasGateway({
    this.putScenario = _AliasPutScenario.confirmed,
    GroupAliasSearchPage? searchPage,
  }) : searchPage = searchPage ?? GroupAliasSearchPage.empty();

  final _AliasPutScenario putScenario;
  final GroupAliasSearchPage searchPage;
  int loadCalls = 0;
  int putCalls = 0;
  int searchCalls = 0;
  final List<String> putAliases = <String>[];
  final List<String> searchPrefixes = <String>[];

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.production;

  @override
  Future<GroupAliasResource> loadCurrentAlias(GroupId groupId) async {
    loadCalls += 1;
    throw const GroupAliasGatewayException(
      GroupAliasGatewayFailureKind.notFound,
    );
  }

  @override
  Future<GroupAliasResource> putCurrentAlias({
    required GroupId groupId,
    required String normalizedAlias,
  }) async {
    putCalls += 1;
    putAliases.add(normalizedAlias);
    if (putScenario == _AliasPutScenario.outcomeUnknown) {
      throw const GroupAliasGatewayException(
        GroupAliasGatewayFailureKind.outcomeUnknown,
      );
    }
    return GroupAliasResource(
      groupAliasId: GroupAliasId.fromWire(_groupAliasIdValue),
      alias: normalizedAlias,
      projectionState: putScenario == _AliasPutScenario.pending
          ? GroupAliasProjectionState.pending
          : GroupAliasProjectionState.confirmed,
    );
  }

  @override
  Future<GroupAliasSearchPage> searchAliases({
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  }) async {
    searchCalls += 1;
    searchPrefixes.add(normalizedPrefix);
    return searchPage;
  }
}
