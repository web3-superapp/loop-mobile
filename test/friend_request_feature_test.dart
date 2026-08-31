import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/friends/friend_request_controller.dart';
import 'package:loop_mobile/features/chat/friends/friend_request_screen.dart';
import 'package:loop_mobile/features/chat/friends/friend_screens.dart';

void main() {
  test('loads incoming and outgoing first pages and paginates each list independently', () async {
    final incomingOne = _request(
      requestIndex: 1,
      profileIndex: 101,
      alias: 'Incoming One',
      direction: FriendRequestDirection.incoming,
    );
    final incomingTwo = _request(
      requestIndex: 2,
      profileIndex: 102,
      alias: 'Incoming Two',
      direction: FriendRequestDirection.incoming,
    );
    final outgoingOne = _request(
      requestIndex: 3,
      profileIndex: 103,
      alias: 'Outgoing One',
      direction: FriendRequestDirection.outgoing,
    );
    final outgoingTwo = _request(
      requestIndex: 4,
      profileIndex: 104,
      alias: 'Outgoing Two',
      direction: FriendRequestDirection.outgoing,
    );
    final gateway = _FakeLoopSocialFriendGateway(
      requestPages: <String, FriendRequestPage>{
        _requestPageKey(
          FriendRequestDirection.incoming,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[incomingOne],
          nextCursor: 'incoming-page-2',
        ),
        _requestPageKey(
          FriendRequestDirection.incoming,
          'incoming-page-2',
        ): FriendRequestPage(
          items: <FriendRequestRecord>[incomingTwo],
          nextCursor: null,
        ),
        _requestPageKey(
          FriendRequestDirection.outgoing,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[outgoingOne],
          nextCursor: 'outgoing-page-2',
        ),
        _requestPageKey(
          FriendRequestDirection.outgoing,
          'outgoing-page-2',
        ): FriendRequestPage(
          items: <FriendRequestRecord>[outgoingTwo],
          nextCursor: null,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendRequestsControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      friendRequestsControllerProvider.notifier,
    );

    await controller.load();

    var state = container.read(friendRequestsControllerProvider);
    expect(state.phase, FriendRequestsPhase.ready);
    expect(state.incoming, <FriendRequestRecord>[incomingOne]);
    expect(state.outgoing, <FriendRequestRecord>[outgoingOne]);
    expect(state.incomingCursor, 'incoming-page-2');
    expect(state.outgoingCursor, 'outgoing-page-2');
    expect(gateway.requestPageCalls, hasLength(2));
    expect(
      gateway.requestPageCalls.map((call) => call.direction).toSet(),
      <FriendRequestDirection>{
        FriendRequestDirection.incoming,
        FriendRequestDirection.outgoing,
      },
    );
    expect(
      gateway.requestPageCalls.every((call) => call.cursor == null),
      isTrue,
    );

    await controller.loadMore(FriendRequestDirection.incoming);

    state = container.read(friendRequestsControllerProvider);
    expect(state.incoming, <FriendRequestRecord>[incomingOne, incomingTwo]);
    expect(state.outgoing, <FriendRequestRecord>[outgoingOne]);
    expect(state.incomingCursor, isNull);
    expect(state.outgoingCursor, 'outgoing-page-2');
    expect(
      gateway.requestPageCalls.last.direction,
      FriendRequestDirection.incoming,
    );
    expect(gateway.requestPageCalls.last.cursor, 'incoming-page-2');

    await controller.loadMore(FriendRequestDirection.outgoing);

    state = container.read(friendRequestsControllerProvider);
    expect(state.incoming, <FriendRequestRecord>[incomingOne, incomingTwo]);
    expect(state.outgoing, <FriendRequestRecord>[outgoingOne, outgoingTwo]);
    expect(state.incomingCursor, isNull);
    expect(state.outgoingCursor, isNull);
    expect(gateway.requestPageCalls, hasLength(4));
    expect(
      gateway.requestPageCalls.last.direction,
      FriendRequestDirection.outgoing,
    );
    expect(gateway.requestPageCalls.last.cursor, 'outgoing-page-2');
  });

  test('accept and reject remove only the decided incoming request', () async {
    final first = _request(
      requestIndex: 11,
      profileIndex: 111,
      alias: 'Accept Me',
      direction: FriendRequestDirection.incoming,
    );
    final second = _request(
      requestIndex: 12,
      profileIndex: 112,
      alias: 'Reject Me',
      direction: FriendRequestDirection.incoming,
    );
    final gateway = _FakeLoopSocialFriendGateway(
      requestPages: <String, FriendRequestPage>{
        _requestPageKey(
          FriendRequestDirection.incoming,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[first, second],
          nextCursor: null,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendRequestsControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      friendRequestsControllerProvider.notifier,
    );
    await controller.load();

    await controller.decide(
      first.friendRequestId,
      FriendRequestDecision.accept,
    );

    var state = container.read(friendRequestsControllerProvider);
    expect(state.phase, FriendRequestsPhase.ready);
    expect(state.incoming, <FriendRequestRecord>[second]);
    expect(state.decisionReceipt?.friendRequestId, first.friendRequestId);
    expect(state.decisionReceipt?.decision, FriendRequestDecision.accept);
    expect(gateway.decisionCalls, hasLength(1));
    expect(
      () => validateFriendOperationId(gateway.decisionCalls.single.operationId),
      returnsNormally,
    );

    controller.acknowledgeDecision();
    expect(
      container.read(friendRequestsControllerProvider).decisionReceipt,
      isNull,
    );
    await controller.decide(
      second.friendRequestId,
      FriendRequestDecision.reject,
    );

    state = container.read(friendRequestsControllerProvider);
    expect(state.phase, FriendRequestsPhase.ready);
    expect(state.incoming, isEmpty);
    expect(state.decisionReceipt?.friendRequestId, second.friendRequestId);
    expect(state.decisionReceipt?.decision, FriendRequestDecision.reject);
    expect(gateway.decisionCalls, hasLength(2));
    expect(
      gateway.decisionCalls.map((call) => call.operationId).toSet(),
      hasLength(2),
    );
  });

  test(
    'unknown decision keeps one operation and permits reconciliation only',
    () async {
      final incoming = _request(
        requestIndex: 21,
        profileIndex: 121,
        alias: 'Needs Reconciliation',
        direction: FriendRequestDirection.incoming,
      );
      final outgoing = _request(
        requestIndex: 22,
        profileIndex: 122,
        alias: 'Outgoing Pending',
        direction: FriendRequestDirection.outgoing,
      );
      var attempts = 0;
      final gateway = _FakeLoopSocialFriendGateway(
        requestPages: <String, FriendRequestPage>{
          _requestPageKey(
            FriendRequestDirection.incoming,
            null,
          ): FriendRequestPage(
            items: <FriendRequestRecord>[incoming],
            nextCursor: 'incoming-more',
          ),
          _requestPageKey(
            FriendRequestDirection.outgoing,
            null,
          ): FriendRequestPage(
            items: <FriendRequestRecord>[outgoing],
            nextCursor: 'outgoing-more',
          ),
        },
        onDecision: (call) async {
          attempts += 1;
          if (attempts == 1) {
            throw const FriendGatewayException(
              FriendGatewayFailureKind.outcomeUnknown,
            );
          }
          return FriendRequestDecisionReceipt(
            operationId: call.operationId,
            friendRequestId: call.friendRequestId,
            decision: call.decision,
          );
        },
      );
      final container = ProviderContainer(
        overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        friendRequestsControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final controller = container.read(
        friendRequestsControllerProvider.notifier,
      );
      await controller.load();

      await controller.decide(
        incoming.friendRequestId,
        FriendRequestDecision.accept,
      );

      var state = container.read(friendRequestsControllerProvider);
      expect(state.phase, FriendRequestsPhase.failure);
      expect(state.failureKind, FriendGatewayFailureKind.outcomeUnknown);
      expect(state.decidingRequestId, incoming.friendRequestId);
      expect(state.requiresDecisionReconciliation, isTrue);
      expect(state.canLoadMore(FriendRequestDirection.incoming), isFalse);
      expect(state.canLoadMore(FriendRequestDirection.outgoing), isFalse);
      expect(gateway.decisionCalls, hasLength(1));
      final retainedOperationId = gateway.decisionCalls.single.operationId;
      final loadCount = gateway.requestPageCalls.length;

      await controller.reload();
      await controller.loadMore(FriendRequestDirection.incoming);
      await controller.loadMore(FriendRequestDirection.outgoing);
      await controller.decide(
        incoming.friendRequestId,
        FriendRequestDecision.reject,
      );

      expect(gateway.requestPageCalls, hasLength(loadCount));
      expect(gateway.decisionCalls, hasLength(1));

      await controller.reconcileDecision(incoming.friendRequestId);

      state = container.read(friendRequestsControllerProvider);
      expect(gateway.decisionCalls, hasLength(2));
      expect(gateway.decisionCalls.last.operationId, retainedOperationId);
      expect(gateway.decisionCalls.last.decision, FriendRequestDecision.accept);
      expect(state.phase, FriendRequestsPhase.ready);
      expect(state.incoming, isEmpty);
      expect(state.failureKind, isNull);
    },
  );

  testWidgets('accept refreshes a mounted friend directory', (tester) async {
    final incoming = _request(
      requestIndex: 31,
      profileIndex: 131,
      alias: 'New Friend',
      direction: FriendRequestDirection.incoming,
    );
    var friendLoads = 0;
    final gateway = _FakeLoopSocialFriendGateway(
      requestPages: <String, FriendRequestPage>{
        _requestPageKey(
          FriendRequestDirection.incoming,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[incoming],
          nextCursor: null,
        ),
      },
      onFriendPage: (cursor) async {
        friendLoads += 1;
        return FriendDirectoryPage(
          items: friendLoads == 1
              ? const <FriendIdentity>[]
              : <FriendIdentity>[incoming.counterparty],
          nextCursor: null,
        );
      },
    );
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    _configurePhoneView(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const IndexedStack(
            index: 1,
            children: <Widget>[FriendListPage(), FriendRequestsPage()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(friendLoads, 1);
    expect(container.read(friendDirectoryControllerProvider).friends, isEmpty);

    await tester.tap(
      find.byKey(
        ValueKey<String>('friend-request-accept-${incoming.friendRequestId}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(friendLoads, 2);
    expect(
      container.read(friendDirectoryControllerProvider).friends,
      <FriendIdentity>[incoming.counterparty],
    );
  });

  test('providerless friend requests fail closed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendRequestsControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      friendRequestsControllerProvider.notifier,
    );

    await controller.load();
    await controller.reload();
    await controller.loadMore(FriendRequestDirection.incoming);
    await controller.decide(_entityId(41), FriendRequestDecision.accept);

    final state = container.read(friendRequestsControllerProvider);
    expect(state.mode, FriendGatewayMode.unavailable);
    expect(state.phase, FriendRequestsPhase.unavailable);
    expect(state.incoming, isEmpty);
    expect(state.outgoing, isEmpty);
    expect(state.failureKind, FriendGatewayFailureKind.unavailable);
  });

  test('Preview cannot opt into production friend-request behavior', () async {
    final gateway = _FakeLoopSocialFriendGateway(
      mode: FriendGatewayMode.preview,
      requestPages: <String, FriendRequestPage>{
        _requestPageKey(
          FriendRequestDirection.incoming,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[
            _request(
              requestIndex: 51,
              profileIndex: 151,
              alias: 'Must Stay Hidden',
              direction: FriendRequestDirection.incoming,
            ),
          ],
          nextCursor: null,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      friendRequestsControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(friendRequestsControllerProvider.notifier).load();

    final state = container.read(friendRequestsControllerProvider);
    expect(state.mode, FriendGatewayMode.preview);
    expect(state.phase, FriendRequestsPhase.unavailable);
    expect(state.incoming, isEmpty);
    expect(gateway.requestPageCalls, isEmpty);
  });

  testWidgets('renders incoming and outgoing cells with the correct actions', (
    tester,
  ) async {
    final incoming = _request(
      requestIndex: 61,
      profileIndex: 161,
      alias: 'Incoming Cell',
      direction: FriendRequestDirection.incoming,
    );
    final outgoing = _request(
      requestIndex: 62,
      profileIndex: 162,
      alias: 'Outgoing Cell',
      direction: FriendRequestDirection.outgoing,
    );
    final gateway = _FakeLoopSocialFriendGateway(
      requestPages: <String, FriendRequestPage>{
        _requestPageKey(
          FriendRequestDirection.incoming,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[incoming],
          nextCursor: null,
        ),
        _requestPageKey(
          FriendRequestDirection.outgoing,
          null,
        ): FriendRequestPage(
          items: <FriendRequestRecord>[outgoing],
          nextCursor: null,
        ),
      },
    );

    await _pumpRequestsPage(tester, gateway);

    expect(find.text('收到的申请'), findsOneWidget);
    expect(find.text('已发送'), findsOneWidget);
    expect(find.text('Incoming Cell'), findsOneWidget);
    expect(find.text('Outgoing Cell'), findsOneWidget);
    expect(
      find.text('LOOP #${incoming.counterparty.profileCode}'),
      findsOneWidget,
    );
    expect(
      find.text('LOOP #${outgoing.counterparty.profileCode}'),
      findsOneWidget,
    );
    final rejectFinder = find.byKey(
      ValueKey<String>('friend-request-reject-${incoming.friendRequestId}'),
    );
    final acceptFinder = find.byKey(
      ValueKey<String>('friend-request-accept-${incoming.friendRequestId}'),
    );
    expect(rejectFinder, findsOneWidget);
    expect(acceptFinder, findsOneWidget);
    expect(tester.widget<IconButton>(rejectFinder).onPressed, isNotNull);
    expect(tester.widget<IconButton>(acceptFinder).onPressed, isNotNull);
    expect(
      find.byKey(
        ValueKey<String>('friend-request-accept-${outgoing.friendRequestId}'),
      ),
      findsNothing,
    );
    expect(find.text('等待中'), findsOneWidget);
  });

  testWidgets(
    'unknown decision leaves reconciliation as the only enabled page action',
    (tester) async {
      final incoming = _request(
        requestIndex: 71,
        profileIndex: 171,
        alias: 'Unknown Outcome',
        direction: FriendRequestDirection.incoming,
      );
      final outgoing = _request(
        requestIndex: 72,
        profileIndex: 172,
        alias: 'Outgoing More',
        direction: FriendRequestDirection.outgoing,
      );
      final gateway = _FakeLoopSocialFriendGateway(
        requestPages: <String, FriendRequestPage>{
          _requestPageKey(
            FriendRequestDirection.incoming,
            null,
          ): FriendRequestPage(
            items: <FriendRequestRecord>[incoming],
            nextCursor: 'incoming-more',
          ),
          _requestPageKey(
            FriendRequestDirection.outgoing,
            null,
          ): FriendRequestPage(
            items: <FriendRequestRecord>[outgoing],
            nextCursor: 'outgoing-more',
          ),
        },
        onDecision: (call) async => throw const FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
        ),
      );
      await _pumpRequestsPage(tester, gateway);

      await tester.tap(
        find.byKey(
          ValueKey<String>('friend-request-accept-${incoming.friendRequestId}'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('处理结果待确认'), findsOneWidget);
      final reconcile = find.byKey(
        const ValueKey<String>('friend-decision-reconcile'),
      );
      expect(reconcile, findsOneWidget);
      expect(tester.widget<OutlinedButton>(reconcile).onPressed, isNotNull);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey<String>('friend-requests-refresh')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey<String>('friend-requests-incoming-more'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey<String>('friend-requests-outgoing-more'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(
          ValueKey<String>('friend-request-reject-${incoming.friendRequestId}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>('friend-request-accept-${incoming.friendRequestId}'),
        ),
        findsNothing,
      );
      expect(gateway.decisionCalls, hasLength(1));
    },
  );
}

Future<void> _pumpRequestsPage(
  WidgetTester tester,
  FriendGateway gateway,
) async {
  _configurePhoneView(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [friendGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const FriendRequestsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configurePhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

FriendRequestRecord _request({
  required int requestIndex,
  required int profileIndex,
  required String alias,
  required FriendRequestDirection direction,
}) => FriendRequestRecord(
  friendRequestId: _entityId(requestIndex),
  counterparty: _identity(profileIndex, alias),
  direction: direction,
  createdAt: DateTime.utc(2026, 8, 31, 1),
  expiresAt: DateTime.utc(2026, 9, 7, 1),
);

FriendIdentity _identity(int index, String alias) => FriendIdentity.fromBackend(
  publicProfileId: FriendProfileRef.fromPublicProfileId(_entityId(index)),
  profileCode: index.toString().padLeft(10, '0'),
  alias: alias,
  avatarRef: null,
);

String _entityId(int index) =>
    '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

String _requestPageKey(FriendRequestDirection direction, String? cursor) =>
    '${direction.name}:${cursor ?? '<first>'}';

typedef _DecisionHandler = Future<FriendRequestDecisionReceipt> Function(
  _DecisionCall call,
);
typedef _FriendPageHandler = Future<FriendDirectoryPage> Function(
  String? cursor,
);

final class _FakeLoopSocialFriendGateway implements LoopSocialFriendGateway {
  _FakeLoopSocialFriendGateway({
    this.mode = FriendGatewayMode.production,
    Map<String, FriendRequestPage> requestPages =
        const <String, FriendRequestPage>{},
    this.onDecision,
    this.onFriendPage,
  }) : _requestPages = Map<String, FriendRequestPage>.unmodifiable(
         requestPages,
       );

  @override
  final FriendGatewayMode mode;

  final Map<String, FriendRequestPage> _requestPages;
  final _DecisionHandler? onDecision;
  final _FriendPageHandler? onFriendPage;
  final List<_RequestPageCall> requestPageCalls = <_RequestPageCall>[];
  final List<_DecisionCall> decisionCalls = <_DecisionCall>[];

  @override
  Future<FriendDirectoryPage> loadFriendPage({String? cursor}) async {
    final handler = onFriendPage;
    if (handler != null) return handler(cursor);
    return FriendDirectoryPage(
      items: const <FriendIdentity>[],
      nextCursor: null,
    );
  }

  @override
  Future<FriendRequestPage> loadFriendRequests({
    required FriendRequestDirection direction,
    String? cursor,
  }) async {
    requestPageCalls.add(_RequestPageCall(direction, cursor));
    return _requestPages[_requestPageKey(direction, cursor)] ??
        FriendRequestPage(
          items: const <FriendRequestRecord>[],
          nextCursor: null,
        );
  }

  @override
  Future<FriendRequestDecisionReceipt> decideFriendRequest({
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  }) async {
    final call = _DecisionCall(
      operationId: operationId,
      friendRequestId: friendRequestId,
      decision: decision,
    );
    decisionCalls.add(call);
    final handler = onDecision;
    if (handler != null) return handler(call);
    return FriendRequestDecisionReceipt(
      operationId: operationId,
      friendRequestId: friendRequestId,
      decision: decision,
    );
  }

  @override
  Future<List<FriendIdentity>> loadFriends() async =>
      (await loadFriendPage()).items;

  @override
  Future<List<FriendSearchResult>> searchByAlias(
    String normalizedQuery,
  ) async => const <FriendSearchResult>[];

  @override
  Future<FriendSearchPage> searchByAliasPage(String normalizedQuery) async =>
      FriendSearchPage(items: const <FriendSearchResult>[], truncated: false);

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async => throw UnimplementedError();

  @override
  Future<CreatedDirectFriendChannel> createDirectChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async => throw UnimplementedError();

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async => throw UnimplementedError();

  @override
  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async => throw UnimplementedError();
}

final class _RequestPageCall {
  const _RequestPageCall(this.direction, this.cursor);

  final FriendRequestDirection direction;
  final String? cursor;
}

final class _DecisionCall {
  const _DecisionCall({
    required this.operationId,
    required this.friendRequestId,
    required this.decision,
  });

  final String operationId;
  final String friendRequestId;
  final FriendRequestDecision decision;
}
