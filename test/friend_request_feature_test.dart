import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/friends/friend_request_controller.dart';

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

final class _FakeLoopSocialFriendGateway implements LoopSocialFriendGateway {
  _FakeLoopSocialFriendGateway({
    this.mode = FriendGatewayMode.production,
    Map<String, FriendRequestPage> requestPages =
        const <String, FriendRequestPage>{},
    this.onDecision,
  }) : _requestPages = Map<String, FriendRequestPage>.unmodifiable(
         requestPages,
       );

  @override
  final FriendGatewayMode mode;

  final Map<String, FriendRequestPage> _requestPages;
  final _DecisionHandler? onDecision;
  final List<_RequestPageCall> requestPageCalls = <_RequestPageCall>[];
  final List<_DecisionCall> decisionCalls = <_DecisionCall>[];

  @override
  Future<FriendDirectoryPage> loadFriendPage({String? cursor}) async {
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
