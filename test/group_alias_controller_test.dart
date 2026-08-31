import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_controller.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';

const _groupIdValue = 'e464386d-cd85-472d-9b22-2d94412ad413';
const _aliasIdValue = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';
const _secondAliasIdValue = 'a36c5221-ea25-4577-89e8-825b376fd12d';

void main() {
  group('GroupAliasGateway', () {
    test('production-safe provider defaults unavailable', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final groupId = _groupId();
      final provider = groupAliasControllerProvider(groupId);

      expect(
        container.read(groupAliasGatewayProvider),
        isA<UnavailableGroupAliasGateway>(),
      );
      expect(container.read(provider).mode, GroupAliasGatewayMode.unavailable);
      expect(container.read(provider).phase, GroupAliasPhase.unavailable);
      expect(container.read(provider).canReserveNewAlias, isFalse);

      await container.read(provider.notifier).load();
      expect(container.read(provider).failureCode, 'group_alias_unavailable');
    });

    test('exposes only sanitized stable failure codes', () {
      const expected = <GroupAliasGatewayFailureKind, String>{
        GroupAliasGatewayFailureKind.unavailable: 'group_alias_unavailable',
        GroupAliasGatewayFailureKind.notFound: 'group_alias_not_found',
        GroupAliasGatewayFailureKind.immutable: 'group_alias_immutable',
        GroupAliasGatewayFailureKind.taken: 'group_alias_taken',
        GroupAliasGatewayFailureKind.invalidData: 'invalid_group_alias_data',
        GroupAliasGatewayFailureKind.outcomeUnknown:
            'group_alias_outcome_unknown',
        GroupAliasGatewayFailureKind.unexpected: 'group_alias_request_failed',
      };

      for (final entry in expected.entries) {
        final error = GroupAliasGatewayException(entry.key);
        expect(error.code, entry.value);
        expect(error.toString(), entry.value);
        expect(error.toString(), isNot(contains(_groupIdValue)));
      }
    });
  });

  group('GroupAliasController', () {
    test('loads and defensively publishes a current immutable Alias', () async {
      final resource = _resource('Night Owl');
      final gateway = _FakeGroupAliasGateway(onLoad: (_) async => resource);
      final fixture = _fixture(gateway);
      addTearDown(fixture.dispose);

      await fixture.controller.load();
      final state = fixture.state;

      expect(state.phase, GroupAliasPhase.ready);
      expect(state.resource, resource);
      expect(identical(state.resource, resource), isFalse);
      expect(state.hasImmutableAlias, isTrue);
      expect(state.canReserveNewAlias, isFalse);
      expect(gateway.loadCalls, 1);
    });

    test(
      '404 stays non-assertive but permits backend-validated first PUT',
      () async {
        final gateway = _FakeGroupAliasGateway(
          onLoad: (_) async => throw const GroupAliasGatewayException(
            GroupAliasGatewayFailureKind.notFound,
          ),
          onPut: (_, alias) async => _resource(alias),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.load();
        expect(fixture.state.phase, GroupAliasPhase.notFound);
        expect(fixture.state.resource, isNull);
        expect(fixture.state.canReserveNewAlias, isTrue);

        await fixture.controller.reserveAlias('  Night Owl  ');
        expect(gateway.putAliases, <String>['Night Owl']);
        expect(fixture.state.phase, GroupAliasPhase.ready);
        expect(fixture.state.resource?.alias, 'Night Owl');
      },
    );

    test(
      'confirmed same value is a no-op and different value is immutable',
      () async {
        final gateway = _FakeGroupAliasGateway(
          onLoad: (_) async => _resource('Night Owl'),
          onPut: (_, alias) async => _resource(alias),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);
        await fixture.controller.load();

        await fixture.controller.reserveAlias('Night Owl');
        expect(gateway.putCalls, 0);
        expect(fixture.state.phase, GroupAliasPhase.ready);

        await fixture.controller.reserveAlias('Another Alias');
        expect(gateway.putCalls, 0);
        expect(fixture.state.phase, GroupAliasPhase.failure);
        expect(
          fixture.state.failureKind,
          GroupAliasGatewayFailureKind.immutable,
        );
        expect(fixture.state.resource?.alias, 'Night Owl');
      },
    );

    test(
      'replays the exact committed Alias to confirm pending projection',
      () async {
        final gateway = _FakeGroupAliasGateway(
          onLoad: (_) async => _resource(
            'Night Owl',
            projectionState: GroupAliasProjectionState.pending,
          ),
          onPut: (_, alias) async => _resource(alias),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);
        await fixture.controller.load();

        expect(fixture.state.resource?.requiresProjectionRetry, isTrue);
        await fixture.controller.reserveAlias('Night Owl');

        expect(gateway.putAliases, <String>['Night Owl']);
        expect(
          fixture.state.resource?.projectionState,
          GroupAliasProjectionState.confirmed,
        );
      },
    );

    test(
      'retains unknown PUT and permits only exact-value convergence',
      () async {
        var attempts = 0;
        final gateway = _FakeGroupAliasGateway(
          onPut: (_, alias) async {
            attempts += 1;
            if (attempts == 1) {
              throw const GroupAliasGatewayException(
                GroupAliasGatewayFailureKind.outcomeUnknown,
              );
            }
            return _resource(alias);
          },
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.reserveAlias('Night Owl');
        expect(fixture.state.phase, GroupAliasPhase.outcomeUnknown);
        expect(fixture.state.pendingAlias, 'Night Owl');
        expect(fixture.state.canRetryPendingAlias, isTrue);
        expect(fixture.state.canReserveNewAlias, isFalse);

        await fixture.controller.reserveAlias('Different Alias');
        expect(gateway.putCalls, 1);
        expect(fixture.state.pendingAlias, 'Night Owl');

        await fixture.controller.reserveAlias('bad\u200Balias');
        expect(gateway.putCalls, 1);
        expect(fixture.state.phase, GroupAliasPhase.outcomeUnknown);
        expect(fixture.state.pendingAlias, 'Night Owl');

        await fixture.controller.retryPendingAlias();
        expect(gateway.putAliases, <String>['Night Owl', 'Night Owl']);
        expect(fixture.state.phase, GroupAliasPhase.ready);
        expect(fixture.state.pendingAlias, isNull);
        expect(fixture.state.resource?.alias, 'Night Owl');
      },
    );

    test('reload cannot erase an unresolved exact PUT candidate', () async {
      final gateway = _FakeGroupAliasGateway(
        onLoad: (_) async => throw const GroupAliasGatewayException(
          GroupAliasGatewayFailureKind.notFound,
        ),
        onPut: (_, _) async => throw const GroupAliasGatewayException(
          GroupAliasGatewayFailureKind.outcomeUnknown,
        ),
      );
      final fixture = _fixture(gateway);
      addTearDown(fixture.dispose);

      await fixture.controller.reserveAlias('Night Owl');
      await fixture.controller.reload();

      expect(fixture.state.phase, GroupAliasPhase.outcomeUnknown);
      expect(fixture.state.pendingAlias, 'Night Owl');
      expect(
        fixture.state.failureKind,
        GroupAliasGatewayFailureKind.outcomeUnknown,
      );
    });

    test(
      'a taken name is definitive and a different name can be attempted',
      () async {
        var attempts = 0;
        final gateway = _FakeGroupAliasGateway(
          onPut: (_, alias) async {
            attempts += 1;
            if (attempts == 1) {
              throw const GroupAliasGatewayException(
                GroupAliasGatewayFailureKind.taken,
              );
            }
            return _resource(alias);
          },
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.reserveAlias('Night Owl');
        expect(fixture.state.failureKind, GroupAliasGatewayFailureKind.taken);
        expect(fixture.state.pendingAlias, isNull);
        expect(fixture.state.canReserveNewAlias, isTrue);

        await fixture.controller.reserveAlias('Night Fox');
        expect(fixture.state.phase, GroupAliasPhase.ready);
        expect(fixture.state.resource?.alias, 'Night Fox');
      },
    );

    test(
      'server immutable failure requires reload before another PUT',
      () async {
        final gateway = _FakeGroupAliasGateway(
          onPut: (_, _) async => throw const GroupAliasGatewayException(
            GroupAliasGatewayFailureKind.immutable,
          ),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.reserveAlias('Night Owl');
        expect(fixture.state.canReserveNewAlias, isFalse);
        await fixture.controller.reserveAlias('Another Alias');
        expect(gateway.putCalls, 1);
      },
    );

    test(
      'rejects malformed/mismatched adapter results without claiming save',
      () async {
        final gateway = _FakeGroupAliasGateway(
          onPut: (_, _) async => _resource('Different Alias'),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.reserveAlias('Night Owl');

        expect(fixture.state.resource, isNull);
        expect(
          fixture.state.failureKind,
          GroupAliasGatewayFailureKind.invalidData,
        );
      },
    );

    test('single-flights duplicate PUT gestures', () async {
      final gate = Completer<GroupAliasResource>();
      final gateway = _FakeGroupAliasGateway(onPut: (_, _) => gate.future);
      final fixture = _fixture(gateway);
      addTearDown(fixture.dispose);

      final first = fixture.controller.reserveAlias('Night Owl');
      final second = fixture.controller.reserveAlias('Night Owl');
      expect(identical(first, second), isTrue);
      expect(gateway.putCalls, 1);

      gate.complete(_resource('Night Owl'));
      await first;
      expect(fixture.state.phase, GroupAliasPhase.ready);
    });

    test(
      'retains an in-flight PUT after its last listener is removed',
      () async {
        final gate = Completer<GroupAliasResource>();
        final gateway = _FakeGroupAliasGateway(onPut: (_, _) => gate.future);
        final groupId = _groupId();
        final provider = groupAliasControllerProvider(groupId);
        final container = ProviderContainer(
          overrides: [groupAliasGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          provider,
          (previous, next) {},
          fireImmediately: true,
        );
        final controller = container.read(provider.notifier);

        final operation = controller.reserveAlias('Night Owl');
        expect(container.read(provider).phase, GroupAliasPhase.setting);
        expect(gateway.putCalls, 1);

        subscription.close();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(provider).phase, GroupAliasPhase.setting);
        expect(container.read(provider.notifier), same(controller));

        gate.completeError(
          const GroupAliasGatewayException(
            GroupAliasGatewayFailureKind.outcomeUnknown,
          ),
        );
        await operation;

        expect(container.read(provider).phase, GroupAliasPhase.outcomeUnknown);
        expect(container.read(provider).pendingAlias, 'Night Owl');
        expect(container.read(provider.notifier), same(controller));
      },
    );
  });

  group('GroupAliasSearchController', () {
    test(
      'normalizes a bounded prefix and publishes only group-local items',
      () async {
        final page = GroupAliasSearchPage(
          items: <GroupAliasSearchItem>[
            _searchItem(_aliasIdValue, 'Night Owl'),
          ],
          truncated: true,
        );
        final gateway = _FakeGroupAliasGateway(
          onSearch: (_, prefix, limit) async => page,
        );
        final fixture = _searchFixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.search('  Ni  ', limit: 7);
        final state = fixture.state;

        expect(gateway.searchPrefixes, <String>['Ni']);
        expect(gateway.searchLimits, <int>[7]);
        expect(state.phase, GroupAliasSearchPhase.ready);
        expect(state.prefix, 'Ni');
        expect(state.limit, 7);
        expect(state.page, page);
        expect(state.page.truncated, isTrue);
      },
    );

    test(
      'invalid prefix and limit fail locally with zero gateway calls',
      () async {
        final gateway = _FakeGroupAliasGateway();
        final fixture = _searchFixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.search('N');
        expect(
          fixture.state.failureKind,
          GroupAliasGatewayFailureKind.invalidData,
        );
        expect(fixture.state.prefix, isEmpty);
        await fixture.controller.search('Night', limit: 21);
        expect(
          fixture.state.failureKind,
          GroupAliasGatewayFailureKind.invalidData,
        );
        expect(gateway.searchCalls, 0);
      },
    );

    test('rejects a response that exceeds the requested limit', () async {
      final gateway = _FakeGroupAliasGateway(
        onSearch: (_, _, _) async => GroupAliasSearchPage(
          items: <GroupAliasSearchItem>[
            _searchItem(_aliasIdValue, 'Night Owl'),
            _searchItem(_secondAliasIdValue, 'Nina'),
          ],
          truncated: false,
        ),
      );
      final fixture = _searchFixture(gateway);
      addTearDown(fixture.dispose);

      await fixture.controller.search('Ni', limit: 1);

      expect(fixture.state.page.items, isEmpty);
      expect(
        fixture.state.failureKind,
        GroupAliasGatewayFailureKind.invalidData,
      );
    });

    test('search is single-flight and maps typed unavailability', () async {
      final gate = Completer<GroupAliasSearchPage>();
      final gateway = _FakeGroupAliasGateway(
        onSearch: (_, _, _) => gate.future,
      );
      final fixture = _searchFixture(gateway);
      addTearDown(fixture.dispose);

      final first = fixture.controller.search('Ni');
      final second = fixture.controller.search('Other');
      expect(identical(first, second), isTrue);
      expect(gateway.searchCalls, 1);

      gate.completeError(
        const GroupAliasGatewayException(
          GroupAliasGatewayFailureKind.unavailable,
        ),
      );
      await first;
      expect(fixture.state.phase, GroupAliasSearchPhase.unavailable);
      expect(
        fixture.state.failureKind,
        GroupAliasGatewayFailureKind.unavailable,
      );
    });
  });
}

GroupId _groupId() => GroupId.fromWire(_groupIdValue);

GroupAliasResource _resource(
  String alias, {
  GroupAliasProjectionState projectionState =
      GroupAliasProjectionState.confirmed,
}) => GroupAliasResource(
  groupAliasId: GroupAliasId.fromWire(_aliasIdValue),
  alias: alias,
  projectionState: projectionState,
);

GroupAliasSearchItem _searchItem(String id, String alias) =>
    GroupAliasSearchItem(groupAliasId: GroupAliasId.fromWire(id), alias: alias);

_ControllerFixture _fixture(GroupAliasGateway gateway) {
  final groupId = _groupId();
  final provider = groupAliasControllerProvider(groupId);
  final container = ProviderContainer(
    overrides: [groupAliasGatewayProvider.overrideWithValue(gateway)],
  );
  final subscription = container.listen(
    provider,
    (previous, next) {},
    fireImmediately: true,
  );
  return _ControllerFixture(container, provider, subscription);
}

_SearchControllerFixture _searchFixture(GroupAliasGateway gateway) {
  final groupId = _groupId();
  final provider = groupAliasSearchControllerProvider(groupId);
  final container = ProviderContainer(
    overrides: [groupAliasGatewayProvider.overrideWithValue(gateway)],
  );
  final subscription = container.listen(
    provider,
    (previous, next) {},
    fireImmediately: true,
  );
  return _SearchControllerFixture(container, provider, subscription);
}

final class _ControllerFixture {
  const _ControllerFixture(this.container, this.provider, this.subscription);

  final ProviderContainer container;
  final NotifierProvider<GroupAliasController, GroupAliasState> provider;
  final ProviderSubscription<GroupAliasState> subscription;

  GroupAliasController get controller => container.read(provider.notifier);
  GroupAliasState get state => container.read(provider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

final class _SearchControllerFixture {
  const _SearchControllerFixture(
    this.container,
    this.provider,
    this.subscription,
  );

  final ProviderContainer container;
  final NotifierProvider<GroupAliasSearchController, GroupAliasSearchState>
  provider;
  final ProviderSubscription<GroupAliasSearchState> subscription;

  GroupAliasSearchController get controller =>
      container.read(provider.notifier);
  GroupAliasSearchState get state => container.read(provider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

final class _FakeGroupAliasGateway implements GroupAliasGateway {
  _FakeGroupAliasGateway({
    Future<GroupAliasResource> Function(GroupId groupId)? onLoad,
    Future<GroupAliasResource> Function(GroupId groupId, String alias)? onPut,
    Future<GroupAliasSearchPage> Function(
      GroupId groupId,
      String prefix,
      int limit,
    )?
    onSearch,
  }) : onLoad =
           onLoad ??
           ((_) async => throw const GroupAliasGatewayException(
             GroupAliasGatewayFailureKind.notFound,
           )),
       onPut =
           onPut ??
           ((_, _) async => throw const GroupAliasGatewayException(
             GroupAliasGatewayFailureKind.unavailable,
           )),
       onSearch =
           onSearch ??
           ((_, _, _) async => throw const GroupAliasGatewayException(
             GroupAliasGatewayFailureKind.unavailable,
           ));

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.preview;
  final Future<GroupAliasResource> Function(GroupId groupId) onLoad;
  final Future<GroupAliasResource> Function(GroupId groupId, String alias)
  onPut;
  final Future<GroupAliasSearchPage> Function(
    GroupId groupId,
    String prefix,
    int limit,
  )
  onSearch;

  int loadCalls = 0;
  int putCalls = 0;
  int searchCalls = 0;
  final List<String> putAliases = <String>[];
  final List<String> searchPrefixes = <String>[];
  final List<int> searchLimits = <int>[];

  @override
  Future<GroupAliasResource> loadCurrentAlias(GroupId groupId) {
    loadCalls += 1;
    return onLoad(groupId);
  }

  @override
  Future<GroupAliasResource> putCurrentAlias({
    required GroupId groupId,
    required String normalizedAlias,
  }) {
    putCalls += 1;
    putAliases.add(normalizedAlias);
    return onPut(groupId, normalizedAlias);
  }

  @override
  Future<GroupAliasSearchPage> searchAliases({
    required GroupId groupId,
    required String normalizedPrefix,
    required int limit,
  }) {
    searchCalls += 1;
    searchPrefixes.add(normalizedPrefix);
    searchLimits.add(limit);
    return onSearch(groupId, normalizedPrefix, limit);
  }
}
