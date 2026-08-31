import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_controller.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';

const _groupIdValue = 'e464386d-cd85-472d-9b22-2d94412ad413';
const _groupCid = 'messaging:legacy_group-01';

void main() {
  group('GroupAliasStreamChannelId', () {
    test('keeps only the validated messaging channel ID', () {
      final channelId = GroupAliasStreamChannelId.fromCid(_groupCid);

      expect(channelId.wireValue, 'legacy_group-01');
      expect(channelId.wireValue, isNot(contains('messaging:')));
      expect(channelId.cid, _groupCid);
      expect(GroupAliasStreamChannelId.copyOf(channelId), channelId);
      expect(
        GroupAliasStreamChannelId.copyOf(channelId).hashCode,
        channelId.hashCode,
      );
    });

    testWidgets(
      'rejects direct, malformed, unsafe, and oversized CIDs with zero resolver calls',
      (tester) async {
        final gateway = _FakeResolverGateway();
        _configurePhoneView(tester);
        final invalidCids = <String>[
          'messaging:loop_direct_friend-01',
          'loop_group_missing_type',
          'livestream:loop_group_wrong_type',
          'messaging:',
          'messaging:loop_group_extra:segment',
          ' messaging:loop_group_space',
          'messaging:loop_group_space ',
          'messaging:loop/group',
          'messaging:loop.group',
          'messaging:loop group',
          'messaging:_leading',
          'messaging:群聊',
          'messaging:${List<String>.filled(65, 'a').join()}',
        ];

        for (final cid in invalidCids) {
          expect(
            () => GroupAliasStreamChannelId.fromCid(cid),
            throwsA(isA<InvalidGroupAliasContractException>()),
            reason: cid,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                groupAliasResolverGatewayProvider.overrideWithValue(gateway),
              ],
              child: MaterialApp(
                theme: LoopTheme.dark,
                home: GroupAliasChannelRoutePage(routeCid: cid),
              ),
            ),
          );
          await tester.pump();
          expect(
            find.byKey(const ValueKey<String>('group-alias-channel-invalid')),
            findsOneWidget,
            reason: cid,
          );
          expect(find.textContaining('没有发起网络请求'), findsOneWidget);
          expect(find.byType(GroupAliasPage), findsNothing);
        }

        expect(gateway.calls, isEmpty);
      },
    );
  });

  group('GroupAliasResolverController', () {
    test(
      'single-flights resolution and publishes a copied 200 group ID',
      () async {
        final gate = Completer<GroupId>();
        final gateway = _FakeResolverGateway(onResolve: (_) => gate.future);
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        final first = fixture.controller.resolve();
        final second = fixture.controller.resolve();

        expect(identical(first, second), isTrue);
        expect(gateway.calls, hasLength(1));
        expect(gateway.calls.single.wireValue, 'legacy_group-01');
        expect(fixture.state.phase, GroupAliasResolverPhase.resolving);

        final response = GroupId.fromWire(_groupIdValue);
        gate.complete(response);
        await first;

        expect(fixture.state.phase, GroupAliasResolverPhase.resolved);
        expect(fixture.state.groupId, response);
        expect(identical(fixture.state.groupId, response), isFalse);
        expect(fixture.state.failureKind, isNull);
      },
    );

    final failureCases =
        <
          ({
            String name,
            Object error,
            GroupAliasResolverPhase phase,
            GroupAliasGatewayFailureKind kind,
          })
        >[
          (
            name: '404',
            error: const GroupAliasGatewayException(
              GroupAliasGatewayFailureKind.notFound,
            ),
            phase: GroupAliasResolverPhase.notFound,
            kind: GroupAliasGatewayFailureKind.notFound,
          ),
          (
            name: 'unavailable',
            error: const GroupAliasGatewayException(
              GroupAliasGatewayFailureKind.unavailable,
            ),
            phase: GroupAliasResolverPhase.unavailable,
            kind: GroupAliasGatewayFailureKind.unavailable,
          ),
          (
            name: 'invalid contract',
            error: const InvalidGroupAliasContractException(),
            phase: GroupAliasResolverPhase.failure,
            kind: GroupAliasGatewayFailureKind.invalidData,
          ),
        ];
    for (final testCase in failureCases) {
      test('maps ${testCase.name} without publishing a group ID', () async {
        final gateway = _FakeResolverGateway(
          onResolve: (_) => Future<GroupId>.error(testCase.error),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.dispose);

        await fixture.controller.resolve();

        expect(fixture.state.phase, testCase.phase);
        expect(fixture.state.failureKind, testCase.kind);
        expect(fixture.state.groupId, isNull);
        expect(gateway.calls, hasLength(1));
      });
    }

    test('an unavailable-mode gateway fails closed without a call', () async {
      final gateway = _FakeResolverGateway(
        mode: GroupAliasGatewayMode.unavailable,
        onResolve: (_) => throw StateError('must not resolve'),
      );
      final fixture = _fixture(gateway);
      addTearDown(fixture.dispose);

      expect(fixture.state.phase, GroupAliasResolverPhase.unavailable);
      await fixture.controller.resolve();

      expect(fixture.state.phase, GroupAliasResolverPhase.unavailable);
      expect(
        fixture.state.failureKind,
        GroupAliasGatewayFailureKind.unavailable,
      );
      expect(gateway.calls, isEmpty);
    });

    test('a failed resolution can retry the same channel', () async {
      var attempt = 0;
      final gateway = _FakeResolverGateway(
        onResolve: (_) async {
          attempt += 1;
          if (attempt == 1) {
            throw const GroupAliasGatewayException(
              GroupAliasGatewayFailureKind.notFound,
            );
          }
          return GroupId.fromWire(_groupIdValue);
        },
      );
      final fixture = _fixture(gateway);
      addTearDown(fixture.dispose);

      await fixture.controller.resolve();
      expect(fixture.state.phase, GroupAliasResolverPhase.notFound);

      await fixture.controller.resolve();

      expect(fixture.state.phase, GroupAliasResolverPhase.resolved);
      expect(fixture.state.groupId?.wireValue, _groupIdValue);
      expect(gateway.calls, hasLength(2));
      expect(
        gateway.calls.map((channel) => channel.wireValue),
        everyElement('legacy_group-01'),
      );
    });
  });

  group('GroupAliasChannelRoutePage', () {
    testWidgets('enters GroupAliasPage after successful resolution', (
      tester,
    ) async {
      final gateway = _FakeResolverGateway();

      await _pumpResolverPage(tester, gateway);

      expect(find.byType(GroupAliasPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('group-alias-resolver-state')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('group-alias-unavailable')),
        findsOneWidget,
      );
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.wireValue, 'legacy_group-01');
    });

    testWidgets('shows an error and retries into GroupAliasPage', (
      tester,
    ) async {
      var attempt = 0;
      final gateway = _FakeResolverGateway(
        onResolve: (_) async {
          attempt += 1;
          if (attempt == 1) {
            throw const GroupAliasGatewayException(
              GroupAliasGatewayFailureKind.notFound,
            );
          }
          return GroupId.fromWire(_groupIdValue);
        },
      );

      await _pumpResolverPage(tester, gateway);

      expect(find.text('群组不可用'), findsOneWidget);
      final retry = find.byKey(
        const ValueKey<String>('group-alias-resolver-retry'),
      );
      expect(retry, findsOneWidget);
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
      expect(find.byType(GroupAliasPage), findsNothing);

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.byType(GroupAliasPage), findsOneWidget);
      expect(gateway.calls, hasLength(2));
      expect(
        gateway.calls.map((channel) => channel.wireValue),
        everyElement('legacy_group-01'),
      );
    });
  });
}

_ResolverFixture _fixture(GroupAliasResolverGateway gateway) {
  final channelId = GroupAliasStreamChannelId.fromCid(_groupCid);
  final provider = groupAliasResolverControllerProvider(channelId);
  final container = ProviderContainer(
    overrides: [groupAliasResolverGatewayProvider.overrideWithValue(gateway)],
  );
  final subscription = container.listen(
    provider,
    (previous, next) {},
    fireImmediately: true,
  );
  return _ResolverFixture(container, provider, subscription);
}

Future<void> _pumpResolverPage(
  WidgetTester tester,
  GroupAliasResolverGateway gateway,
) async {
  _configurePhoneView(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [groupAliasResolverGatewayProvider.overrideWithValue(gateway)],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const GroupAliasChannelRoutePage(routeCid: _groupCid),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configurePhoneView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

typedef _ResolveHandler = Future<GroupId> Function(
  GroupAliasStreamChannelId channelId,
);

final class _FakeResolverGateway implements GroupAliasResolverGateway {
  _FakeResolverGateway({
    this.mode = GroupAliasGatewayMode.production,
    _ResolveHandler? onResolve,
  }) : onResolve = onResolve ?? ((_) async => GroupId.fromWire(_groupIdValue));

  @override
  final GroupAliasGatewayMode mode;
  final _ResolveHandler onResolve;
  final List<GroupAliasStreamChannelId> calls = <GroupAliasStreamChannelId>[];

  @override
  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId) {
    calls.add(GroupAliasStreamChannelId.copyOf(channelId));
    return onResolve(channelId);
  }
}

final class _ResolverFixture {
  const _ResolverFixture(this.container, this.provider, this.subscription);

  final ProviderContainer container;
  final NotifierProvider<GroupAliasResolverController, GroupAliasResolverState>
  provider;
  final ProviderSubscription<GroupAliasResolverState> subscription;

  GroupAliasResolverController get controller =>
      container.read(provider.notifier);
  GroupAliasResolverState get state => container.read(provider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}
