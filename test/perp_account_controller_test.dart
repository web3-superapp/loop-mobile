import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/perp/account/perp_account_controller.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';

void main() {
  group('PerpAccountController', () {
    test('production default is unavailable and performs no request', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(perpAccountControllerProvider);
      expect(initial.mode, PerpGatewayMode.unavailable);
      expect(initial.phase, PerpAccountPhase.unavailable);
      expect(initial.failureCode, 'perp_unavailable');
      expect(initial.config, isNull);
      expect(initial.account, isNull);

      await container.read(perpAccountControllerProvider.notifier).load();
      expect(
        container.read(perpAccountControllerProvider).phase,
        PerpAccountPhase.unavailable,
      );
    });

    test(
      'reads binding first and stops when explicit binding is required',
      () async {
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: false, version: '4'),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();

        final state = fixture.state;
        expect(gateway.calls, <String>['binding']);
        expect(state.phase, PerpAccountPhase.bindingRequired);
        expect(state.binding!.bindingVersion, '4');
        expect(state.canBind, isTrue);
        expect(state.config, isNull);
        expect(state.account, isNull);
      },
    );

    test(
      'loads bound account facts in binding, config, account order',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: true, version: '8'),
          onGetConfig: () async => _config(now),
          onGetAccount: () async => _account(now),
        );
        final fixture = _fixture(gateway, now: now);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();

        expect(gateway.calls, <String>['binding', 'config', 'account']);
        expect(fixture.state.phase, PerpAccountPhase.ready);
        expect(fixture.state.hasFreshFactsAt(now), isTrue);
        expect(fixture.state.binding!.isBound, isTrue);
        expect(fixture.state.config, isNotNull);
        expect(fixture.state.account, isNotNull);
      },
    );

    test('all reads and binding actions share one single-flight', () async {
      final bindingGate = Completer<PerpWalletBinding>();
      final gateway = _TestPerpGateway(onGetBinding: () => bindingGate.future);
      final fixture = _fixture(gateway);
      addTearDown(fixture.container.dispose);

      final first = fixture.controller.load();
      final second = fixture.controller.load();
      final bindWhileLoading = fixture.controller.bind();

      expect(identical(first, second), isTrue);
      expect(identical(first, bindWhileLoading), isTrue);
      expect(gateway.calls, <String>['binding']);
      expect(fixture.state.phase, PerpAccountPhase.loadingBinding);

      bindingGate.complete(_binding(bound: false, version: '0'));
      await first;
      expect(fixture.state.phase, PerpAccountPhase.bindingRequired);
    });

    test('bind is explicit and uses only the last observed version', () async {
      final now = DateTime.utc(2026, 8, 25, 8);
      final gateway = _TestPerpGateway(
        onGetBinding: () async => _binding(bound: false, version: '11'),
        onBind: (version) async => _binding(bound: true, version: '12'),
        onGetConfig: () async => _config(now),
        onGetAccount: () async => _account(now),
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      expect(gateway.bindVersions, isEmpty);
      expect(gateway.calls, <String>['binding']);

      await fixture.controller.bind();

      expect(gateway.bindVersions, <String>['11']);
      expect(gateway.calls, <String>[
        'binding',
        'bind:11',
        'config',
        'account',
      ]);
      expect(fixture.state.phase, PerpAccountPhase.ready);
    });

    test('timeout reconciles a committed bind without replaying it', () async {
      final now = DateTime.utc(2026, 8, 25, 8);
      var bindingCalls = 0;
      final gateway = _TestPerpGateway(
        onGetBinding: () async {
          bindingCalls += 1;
          return _binding(
            bound: bindingCalls > 1,
            version: bindingCalls > 1 ? '22' : '21',
          );
        },
        onBind: (version) async => throw const PerpGatewayException(
          PerpGatewayFailureKind.timeout,
          requestId: '00000000-0000-4000-8000-000000000021',
        ),
        onGetConfig: () async => _config(now),
        onGetAccount: () async => _account(now),
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      await fixture.controller.bind();

      expect(gateway.bindVersions, <String>['21']);
      expect(gateway.calls, <String>[
        'binding',
        'bind:21',
        'binding',
        'config',
        'account',
      ]);
      expect(fixture.state.phase, PerpAccountPhase.ready);
      expect(fixture.state.failureKind, isNull);
    });

    test(
      'timeout does not accept a skipped binding epoch as its result',
      () async {
        var bindingCalls = 0;
        final gateway = _TestPerpGateway(
          onGetBinding: () async {
            bindingCalls += 1;
            return _binding(
              bound: bindingCalls > 1,
              version: bindingCalls > 1 ? '24' : '22',
            );
          },
          onBind: (_) async => throw const PerpGatewayException(
            PerpGatewayFailureKind.timeout,
            requestId: '00000000-0000-4000-8000-000000000022',
          ),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        await fixture.controller.bind();

        expect(fixture.state.phase, PerpAccountPhase.conflict);
        expect(fixture.state.binding?.bindingVersion, '24');
        expect(fixture.state.canBind, isFalse);
        expect(gateway.calls, <String>['binding', 'bind:22', 'binding']);
      },
    );

    test('ambiguous unbound result requires another explicit bind', () async {
      final now = DateTime.utc(2026, 8, 25, 8);
      var bindingCalls = 0;
      var bindCalls = 0;
      final gateway = _TestPerpGateway(
        onGetBinding: () async {
          bindingCalls += 1;
          return _binding(
            bound: false,
            version: bindingCalls == 1 ? '31' : '32',
          );
        },
        onBind: (version) async {
          bindCalls += 1;
          if (bindCalls == 1) {
            throw const PerpGatewayException(
              PerpGatewayFailureKind.connection,
              requestId: '00000000-0000-4000-8000-000000000031',
            );
          }
          return _binding(bound: true, version: '33');
        },
        onGetConfig: () async => _config(now),
        onGetAccount: () async => _account(now),
      );
      final fixture = _fixture(gateway, now: now);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      await fixture.controller.bind();

      var state = fixture.state;
      expect(gateway.bindVersions, <String>['31']);
      expect(state.phase, PerpAccountPhase.mutationUnknown);
      expect(state.binding!.bindingVersion, '32');
      expect(state.canBind, isTrue);
      expect(state.failureKind, PerpGatewayFailureKind.connection);
      expect(state.requestId, '00000000-0000-4000-8000-000000000031');
      expect(state.config, isNull);
      expect(state.account, isNull);

      await fixture.controller.bind();

      state = fixture.state;
      expect(gateway.bindVersions, <String>['31', '32']);
      expect(state.phase, PerpAccountPhase.ready);
    });

    test(
      'version conflict refreshes binding before another confirmation',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        var bindingCalls = 0;
        var bindCalls = 0;
        final gateway = _TestPerpGateway(
          onGetBinding: () async {
            bindingCalls += 1;
            return _binding(
              bound: false,
              version: bindingCalls == 1 ? '40' : '41',
            );
          },
          onBind: (version) async {
            bindCalls += 1;
            if (bindCalls == 1) {
              throw const PerpGatewayException(
                PerpGatewayFailureKind.versionConflict,
                requestId: '00000000-0000-4000-8000-000000000040',
              );
            }
            return _binding(bound: true, version: '42');
          },
          onGetConfig: () async => _config(now),
          onGetAccount: () async => _account(now),
        );
        final fixture = _fixture(gateway, now: now);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        await fixture.controller.bind();

        var state = fixture.state;
        expect(state.phase, PerpAccountPhase.conflict);
        expect(state.failureKind, PerpGatewayFailureKind.versionConflict);
        expect(state.binding!.bindingVersion, '41');
        expect(state.requiresBindingConfirmation, isTrue);
        expect(state.canBind, isTrue);
        expect(gateway.bindVersions, <String>['40']);

        await fixture.controller.bind();

        state = fixture.state;
        expect(gateway.bindVersions, <String>['40', '41']);
        expect(state.phase, PerpAccountPhase.ready);
      },
    );

    test('bind success fails closed when the epoch skips forward', () async {
      final gateway = _TestPerpGateway(
        onGetBinding: () async => _binding(bound: false, version: '45'),
        onBind: (_) async => _binding(bound: true, version: '47'),
      );
      final fixture = _fixture(gateway);
      addTearDown(fixture.container.dispose);

      await fixture.controller.load();
      await fixture.controller.bind();

      expect(fixture.state.phase, PerpAccountPhase.failure);
      expect(fixture.state.failureKind, PerpGatewayFailureKind.invalidData);
      expect(gateway.calls, <String>['binding', 'bind:45']);
    });

    test(
      'wallet binding rejection clears facts and re-reads binding',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        var bindingCalls = 0;
        var accountCalls = 0;
        final gateway = _TestPerpGateway(
          onGetBinding: () async {
            bindingCalls += 1;
            return _binding(
              bound: bindingCalls < 3,
              version: bindingCalls < 3 ? '50' : '51',
            );
          },
          onGetConfig: () async => _config(now),
          onGetAccount: () async {
            accountCalls += 1;
            if (accountCalls == 2) {
              throw const PerpGatewayException(
                PerpGatewayFailureKind.walletBindingRequired,
                requestId: '00000000-0000-4000-8000-000000000050',
              );
            }
            return _account(now);
          },
        );
        final fixture = _fixture(gateway, now: now);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        expect(fixture.state.hasFreshFactsAt(now), isTrue);

        await fixture.controller.refresh();

        final state = fixture.state;
        expect(gateway.calls, <String>[
          'binding',
          'config',
          'account',
          'binding',
          'config',
          'account',
          'binding',
        ]);
        expect(state.phase, PerpAccountPhase.bindingRequired);
        expect(state.binding!.bindingVersion, '51');
        expect(state.config, isNull);
        expect(state.account, isNull);
        expect(state.failureKind, PerpGatewayFailureKind.walletBindingRequired);
        expect(state.requestId, '00000000-0000-4000-8000-000000000050');
      },
    );

    test(
      'a private-read rejection can explicitly refresh a stored bound version',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        var accountCalls = 0;
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: true, version: '55'),
          onBind: (_) async => _binding(bound: true, version: '55'),
          onGetConfig: () async => _config(now),
          onGetAccount: () async {
            accountCalls += 1;
            if (accountCalls == 1) {
              throw const PerpGatewayException(
                PerpGatewayFailureKind.walletBindingRequired,
                requestId: '00000000-0000-4000-8000-000000000055',
              );
            }
            return _account(now);
          },
        );
        final fixture = _fixture(gateway, now: now);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();

        expect(fixture.state.phase, PerpAccountPhase.bindingRequired);
        expect(fixture.state.binding?.isBound, isTrue);
        expect(fixture.state.binding?.bindingVersion, '55');
        expect(fixture.state.canBind, isTrue);
        expect(fixture.state.account, isNull);

        await fixture.controller.bind();

        expect(fixture.state.phase, PerpAccountPhase.ready);
        expect(gateway.bindVersions, <String>['55']);
        expect(gateway.calls, <String>[
          'binding',
          'config',
          'account',
          'binding',
          'bind:55',
          'config',
          'account',
        ]);
      },
    );

    test(
      'bind rejection reconciles binding before another explicit action',
      () async {
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: false, version: '56'),
          onBind: (_) async => throw const PerpGatewayException(
            PerpGatewayFailureKind.walletBindingRequired,
            requestId: '00000000-0000-4000-8000-000000000056',
          ),
        );
        final fixture = _fixture(gateway);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        await fixture.controller.bind();

        expect(gateway.calls, <String>['binding', 'bind:56', 'binding']);
        expect(fixture.state.phase, PerpAccountPhase.bindingRequired);
        expect(fixture.state.canBind, isTrue);
        expect(fixture.state.requestId, '00000000-0000-4000-8000-000000000056');
      },
    );

    test(
      'clears config and account exactly when the earliest source expires',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        final scheduler = _FakeExpiryScheduler();
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: true, version: '60'),
          onGetConfig: () async => _config(now),
          onGetAccount: () async => _account(now),
        );
        final fixture = _fixture(gateway, now: now, scheduler: scheduler);
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        expect(fixture.state.phase, PerpAccountPhase.ready);
        expect(scheduler.activeDelays, <Duration>[const Duration(seconds: 2)]);

        scheduler.fireNext();

        final state = fixture.state;
        expect(state.phase, PerpAccountPhase.stale);
        expect(state.binding!.isBound, isTrue);
        expect(state.config, isNull);
        expect(state.account, isNull);
        expect(state.hasFreshFactsAt(now), isFalse);
      },
    );

    test(
      'clock validation expires facts even when the timer never fires',
      () async {
        final loadedAt = DateTime.utc(2026, 8, 25, 8);
        var currentTime = loadedAt;
        final scheduler = _FakeExpiryScheduler();
        final gateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: true, version: '61'),
          onGetConfig: () async => _config(loadedAt),
          onGetAccount: () async => _account(loadedAt),
        );
        final fixture = _fixture(
          gateway,
          now: loadedAt,
          scheduler: scheduler,
          clock: () => currentTime,
        );
        addTearDown(fixture.container.dispose);

        await fixture.controller.load();
        expect(fixture.state.hasFreshFactsAt(currentTime), isTrue);

        currentTime = loadedAt.add(const Duration(seconds: 3));
        expect(fixture.state.hasFreshFactsAt(currentTime), isFalse);
        fixture.controller.expireIfNeeded();

        expect(fixture.state.phase, PerpAccountPhase.stale);
        expect(fixture.state.config, isNull);
        expect(fixture.state.account, isNull);
        expect(scheduler.activeDelays, isEmpty);
      },
    );

    test(
      'gateway rotation retires late facts from the previous owner',
      () async {
        final now = DateTime.utc(2026, 8, 25, 8);
        final oldBinding = Completer<PerpWalletBinding>();
        final oldGateway = _TestPerpGateway(
          onGetBinding: () => oldBinding.future,
        );
        final newGateway = _TestPerpGateway(
          onGetBinding: () async => _binding(bound: true, version: '71'),
          onGetConfig: () async => _config(now),
          onGetAccount: () async => _account(now),
        );
        final scheduler = _FakeExpiryScheduler();
        final fixture = _fixture(oldGateway, now: now, scheduler: scheduler);
        addTearDown(fixture.container.dispose);

        final retired = fixture.controller.load();
        fixture.container.updateOverrides([
          perpPrivateGatewayProvider.overrideWithValue(newGateway),
          perpAccountClockProvider.overrideWithValue(() => now),
          perpAccountExpirySchedulerProvider.overrideWithValue(
            scheduler.schedule,
          ),
        ]);
        expect(fixture.state.phase, PerpAccountPhase.initial);

        final active = fixture.controller.load();
        await active;
        expect(fixture.state.phase, PerpAccountPhase.ready);
        expect(fixture.state.binding!.bindingVersion, '71');

        oldBinding.complete(_binding(bound: false, version: '70'));
        await retired;
        expect(fixture.state.phase, PerpAccountPhase.ready);
        expect(fixture.state.binding!.bindingVersion, '71');
      },
    );
  });
}

final class _ControllerFixture {
  const _ControllerFixture(this.container);

  final ProviderContainer container;

  PerpAccountController get controller =>
      container.read(perpAccountControllerProvider.notifier);

  PerpAccountState get state => container.read(perpAccountControllerProvider);
}

_ControllerFixture _fixture(
  PerpPrivateGateway gateway, {
  DateTime? now,
  _FakeExpiryScheduler? scheduler,
  PerpAccountClock? clock,
}) {
  final fixedNow = now ?? DateTime.utc(2026, 8, 25, 8);
  final expiryScheduler = scheduler ?? _FakeExpiryScheduler();
  return _ControllerFixture(
    ProviderContainer(
      overrides: [
        perpPrivateGatewayProvider.overrideWithValue(gateway),
        perpAccountClockProvider.overrideWithValue(clock ?? () => fixedNow),
        perpAccountExpirySchedulerProvider.overrideWithValue(
          expiryScheduler.schedule,
        ),
      ],
    ),
  );
}

PerpWalletBinding _binding({required bool bound, required String version}) {
  return PerpWalletBinding(
    state: bound
        ? PerpWalletBindingState.bound
        : PerpWalletBindingState.unbound,
    bindingVersion: version,
    accountKind: bound ? PerpAccountKind.master : null,
    lastVerifiedAt: bound ? DateTime.utc(2026, 8, 25, 8) : null,
  );
}

PerpConfig _config(DateTime now) {
  return PerpConfig(
    scope: PerpScope(coins: PerpCoin.values),
    assets: const <PerpAssetConfig>[],
    fees: const PerpFees(
      makerRate: PerpDecimalFact.unavailable(),
      takerRate: PerpDecimalFact.unavailable(),
    ),
    capabilities: const PerpCapabilities(
      privateReadsAvailable: true,
      tradingMutationsEnabled: false,
    ),
    source: PerpDataSource(
      dataset: PerpSourceDataset.config,
      fetchedAt: now,
      expiresAt: now.add(const Duration(seconds: 60)),
    ),
  );
}

PerpAccount _account(DateTime now) {
  final summary = PerpMarginSummary(
    accountValue: Decimal.parse('100.25'),
    totalMarginUsed: Decimal.parse('12.5'),
    totalNotionalPosition: Decimal.parse('25'),
    totalRawUsd: Decimal.parse('87.75'),
  );
  return PerpAccount(
    marginSummary: summary,
    crossMarginSummary: summary,
    withdrawable: Decimal.parse('87.75'),
    crossMaintenanceMarginUsed: Decimal.parse('1.5'),
    source: PerpDataSource(
      dataset: PerpSourceDataset.account,
      fetchedAt: now,
      expiresAt: now.add(const Duration(seconds: 2)),
    ),
  );
}

typedef _GetBinding = Future<PerpWalletBinding> Function();
typedef _Bind = Future<PerpWalletBinding> Function(String version);
typedef _GetConfig = Future<PerpConfig> Function();
typedef _GetAccount = Future<PerpAccount> Function();

final class _TestPerpGateway implements PerpPrivateGateway {
  _TestPerpGateway({
    required this.onGetBinding,
    this.onBind,
    this.onGetConfig,
    this.onGetAccount,
  });

  final _GetBinding onGetBinding;
  final _Bind? onBind;
  final _GetConfig? onGetConfig;
  final _GetAccount? onGetAccount;

  final List<String> calls = <String>[];
  final List<String> bindVersions = <String>[];

  @override
  PerpGatewayMode get mode => PerpGatewayMode.production;

  @override
  Future<PerpWalletBinding> getWalletBinding() {
    calls.add('binding');
    return onGetBinding();
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String expectedBindingVersion,
  }) {
    calls.add('bind:$expectedBindingVersion');
    bindVersions.add(expectedBindingVersion);
    final callback = onBind;
    if (callback == null) {
      return Future<PerpWalletBinding>.error(StateError('unexpected bind'));
    }
    return callback(expectedBindingVersion);
  }

  @override
  Future<PerpConfig> getConfig() {
    calls.add('config');
    final callback = onGetConfig;
    if (callback == null) {
      return Future<PerpConfig>.error(StateError('unexpected config read'));
    }
    return callback();
  }

  @override
  Future<PerpAccount> getAccount() {
    calls.add('account');
    final callback = onGetAccount;
    if (callback == null) {
      return Future<PerpAccount>.error(StateError('unexpected account read'));
    }
    return callback();
  }

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String expectedBindingVersion,
  }) => Future<PerpWalletBinding>.error(StateError('unexpected unbind'));

  @override
  Future<PerpPage<PerpPosition>> listPositions({int? limit, String? cursor}) =>
      Future<PerpPage<PerpPosition>>.error(
        StateError('unexpected positions read'),
      );

  @override
  Future<PerpPage<PerpOrder>> listOrders({int? limit, String? cursor}) =>
      Future<PerpPage<PerpOrder>>.error(StateError('unexpected orders read'));

  @override
  Future<PerpPage<PerpFill>> listFills({int? limit, String? cursor}) =>
      Future<PerpPage<PerpFill>>.error(StateError('unexpected fills read'));

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    int? limit,
    String? cursor,
  }) => Future<PerpPage<PerpFundingEntry>>.error(
    StateError('unexpected funding read'),
  );
}

final class _FakeExpiryScheduler {
  final List<_FakeExpiryHandle> _handles = <_FakeExpiryHandle>[];

  PerpAccountExpiryHandle schedule(Duration delay, void Function() callback) {
    final handle = _FakeExpiryHandle(delay, callback);
    _handles.add(handle);
    return handle;
  }

  List<Duration> get activeDelays => _handles
      .where((handle) => !handle.isCancelled && !handle.hasFired)
      .map((handle) => handle.delay)
      .toList(growable: false);

  void fireNext() {
    final handle = _handles.firstWhere(
      (candidate) => !candidate.isCancelled && !candidate.hasFired,
    );
    handle.fire();
  }
}

final class _FakeExpiryHandle implements PerpAccountExpiryHandle {
  _FakeExpiryHandle(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  bool isCancelled = false;
  bool hasFired = false;

  void fire() {
    if (isCancelled || hasFired) return;
    hasFired = true;
    _callback();
  }

  @override
  void cancel() => isCancelled = true;
}
