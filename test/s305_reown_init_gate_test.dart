import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';

/// Decision 0245: a non-timeout Reown initialization failure no longer locks
/// the gate until restart, and the excluded-wallet set survives AppKit's
/// in-place `addAll`.
void main() {
  test('excluded wallet ids are a fresh growable set AppKit can addAll to', () {
    final first = ReownExternalWalletConnector.excludedWalletIds();
    expect(first, hasLength(3));
    // Same mutation AppKit 1.8.4 ExplorerService._excludedWalletsParam does.
    expect(
      () => first
        ..addAll(<String>{'installed-wallet'})
        ..addAll(<String>{'featured-wallet'}),
      returnsNormally,
    );
    expect(first, hasLength(5));
    // Mutating one call's set never leaks into the next modal.
    expect(ReownExternalWalletConnector.excludedWalletIds(), hasLength(3));
  });

  group('ExternalWalletInitializationGate after initialize throws', () {
    late List<String> failures;
    late ExternalWalletInitializationGate<_Owner> gate;
    late List<_Owner> created;
    late List<_Owner> disposed;

    setUp(() {
      failures = <String>[];
      created = <_Owner>[];
      disposed = <_Owner>[];
      gate = ExternalWalletInitializationGate<_Owner>(
        timeout: const Duration(seconds: 1),
        onFailure: (stage, error, _) =>
            failures.add('$stage ${error.runtimeType}'),
      );
    });

    Future<_Owner> acquire({required bool fail, bool throwSync = false}) =>
        gate.acquire(
          create: () {
            final owner = _Owner();
            created.add(owner);
            return owner;
          },
          initialize: (owner) {
            if (throwSync) throw StateError('sync');
            if (fail) {
              return Future<void>.error(
                UnsupportedError('Cannot change an unmodifiable set'),
              );
            }
            owner.isReady = true;
            return Future<void>.value();
          },
          reconnect: (_) async {},
          isReady: (owner) => owner.isReady,
          dispose: (owner) async => disposed.add(owner),
        );

    Matcher initFailure(ExternalWalletConnectorFailure kind) => throwsA(
      isA<ExternalWalletConnectorException>().having(
        (error) => error.kind,
        'kind',
        kind,
      ),
    );

    test(
      'logs the real error, disposes the owner and recreates on retry',
      () async {
        await expectLater(
          acquire(fail: true),
          initFailure(ExternalWalletConnectorFailure.callback),
        );
        expect(failures, <String>['initialize UnsupportedError']);
        expect(gate.hasRetainedOwner, isFalse);
        await pumpEventQueue();
        expect(disposed, <_Owner>[created.single]);

        final owner = await acquire(fail: false);
        expect(created, hasLength(2));
        expect(owner, same(created.last));
        expect(owner.isReady, isTrue);
      },
    );

    test('a synchronous initialize throw also unlocks the gate', () async {
      await expectLater(
        acquire(fail: true, throwSync: true),
        initFailure(ExternalWalletConnectorFailure.callback),
      );
      expect(failures, <String>['create StateError']);
      expect(gate.hasRetainedOwner, isFalse);

      final owner = await acquire(fail: false);
      expect(created, hasLength(2));
      expect(owner, same(created.last));
      await pumpEventQueue();
      expect(disposed, <_Owner>[created.first]);
    });

    test('retry waits for the failed owner to finish disposing', () async {
      final teardown = Completer<void>();
      final order = <String>[];
      Future<_Owner> run({required bool fail}) => gate.acquire(
        create: () {
          order.add('create');
          final owner = _Owner();
          created.add(owner);
          return owner;
        },
        initialize: (owner) {
          if (fail) return Future<void>.error(StateError('boom'));
          owner.isReady = true;
          return Future<void>.value();
        },
        reconnect: (_) async {},
        isReady: (owner) => owner.isReady,
        dispose: (_) async {
          order.add('dispose-start');
          await teardown.future;
          order.add('dispose-end');
        },
      );

      await expectLater(
        run(fail: true),
        initFailure(ExternalWalletConnectorFailure.callback),
      );
      final retry = run(fail: false);
      await pumpEventQueue();
      expect(order, <String>['create', 'dispose-start']);
      teardown.complete();
      await retry;
      expect(order, <String>[
        'create',
        'dispose-start',
        'dispose-end',
        'create',
      ]);
    });

    test(
      'concurrent callers share one owner while initialization runs',
      () async {
        final completion = Completer<void>();
        var creates = 0;
        Future<_Owner> run() => gate.acquire(
          create: () {
            creates += 1;
            return _Owner();
          },
          initialize: (owner) => completion.future.then((_) {
            owner.isReady = true;
          }),
          reconnect: (_) async {},
          isReady: (owner) => owner.isReady,
        );

        final a = run();
        final b = run();
        completion.complete();
        expect(await a, same(await b));
        expect(creates, 1);
      },
    );
  });
}

class _Owner {
  bool isReady = false;
}
