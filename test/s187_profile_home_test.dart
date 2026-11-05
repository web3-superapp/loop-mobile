// Decision 0175 (S187-5): 我 in docs/35's 「我的」 layout. S343 · decision
// 0271: the person stands at the head of the 我的 tab (`/wallet`), and the
// net worth it hides is 我的's 总资产.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_balance_visibility_store.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const _loopId = 'LOOP-GBZM3XAT';

ProfileResource _resource({String? bio, bool activated = true}) =>
    ProfileResource(
      version: 1,
      values: ProfileValues(alias: 'Boo123133', avatarRef: null, bio: bio),
      updatedAt: DateTime.utc(2026, 10, 9),
      loopId: _loopId,
      profileStatus: activated ? ProfileStatus.active : ProfileStatus.pending,
      activatedAt: activated ? DateTime.utc(2026, 10, 9, 12) : null,
    );

final class _Profile implements ProfileGateway {
  _Profile(this.resource);

  final ProfileResource resource;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async => resource;

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async => resource;
}

/// An in-memory store with the failure seams the controller is pinned by.
final class _Store implements LoopBalanceVisibilityStore {
  _Store({this.value, this.failRead = false, this.failWrite = false});

  bool? value;
  final bool failRead;
  final bool failWrite;
  final List<bool> writes = <bool>[];

  @override
  Future<bool?> readHideBalance() async {
    if (failRead) throw StateError('read refused');
    return value;
  }

  @override
  Future<void> writeHideBalance(bool next) async {
    writes.add(next);
    if (failWrite) throw StateError('write refused');
    value = next;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  ProfileResource? resource,
  LoopWalletBalances? balances,
  ConnectionCounts? counts,
  LoopBalanceVisibilityStore? store,
  ValueChanged<String>? onNavigate,
}) => pumpS5Page(
  tester,
  WalletScreen(onNavigate: onNavigate),
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: balances ?? s5Balances()),
  ),
  overrides: [
    profileGatewayProvider.overrideWithValue(_Profile(resource ?? _resource())),
    if (counts != null)
      socialGatewayProvider.overrideWithValue(
        FakeSocialGateway(
          connections: ConnectionPage(
            direction: ConnectionDirection.following,
            items: const <ConnectionEntry>[],
            counts: counts,
            nextCursor: null,
          ),
        ),
      ),
    if (store != null)
      loopBalanceVisibilityStoreProvider.overrideWithValue(store),
  ],
);

Finder _key(String key) => find.byKey(ValueKey<String>(key));

/// Whether 总资产 is masked.
bool _eyeHidden(WidgetTester tester) =>
    tester
        .widget<Text>(find.byKey(const ValueKey<String>('wallet-total-figure')))
        .data ==
    '****';

void main() {
  loopWatchGround();

  group('我 · fomo layout (decision 0175)', () {
    testWidgets('the person: name, LOOP ID, joined month', (tester) async {
      final opened = <String>[];
      await _pump(tester, onNavigate: opened.add);

      expect(find.text('Boo123133'), findsOneWidget);
      expect(find.text(_loopId), findsOneWidget);
      // S374 · decision 0298: an empty bio draws no 「+ Add a bio」 link.
      expect(_key('profile-add-bio'), findsNothing);
      expect(find.text('+ Add a bio'), findsNothing);
      expect(
        tester.widget<Text>(_key('profile-joined')).data,
        'Joined Oct 2026',
      );
      // No source, so neither is drawn — not as zero, not as a dash.
      expect(find.textContaining('持有时长'), findsNothing);
      expect(find.textContaining('笔交易'), findsNothing);

      await tester.tap(_key('profile-open-edit'));
      await tester.tap(_key('profile-open-settings'));
      expect(opened, <String>[
        profileDestinationPath('profile-edit'),
        profileDestinationPath('settings'),
      ]);
    });

    testWidgets('a written bio shows; no activation, no month', (tester) async {
      await _pump(
        tester,
        resource: _resource(bio: '只买 meme', activated: false),
      );
      expect(tester.widget<Text>(_key('profile-bio')).data, '只买 meme');
      expect(_key('profile-add-bio'), findsNothing);
      expect(_key('profile-joined'), findsNothing);
    });

    testWidgets('follow counts come from the connections read and open it', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        counts: const ConnectionCounts(following: 3, followers: 12),
        onNavigate: opened.add,
      );
      expect(
        tester.getSemantics(_key('profile-following-count')).label,
        '3 Following',
      );
      expect(
        tester.getSemantics(_key('profile-followers-count')).label,
        '12 Followers',
      );
      await tester.tap(_key('profile-followers-count'));
      expect(opened, <String>[profileDestinationPath('connections')]);
    });

    testWidgets('an unread connections count draws no count line', (
      tester,
    ) async {
      await _pump(tester);
      expect(_key('profile-following-count'), findsNothing);
      expect(_key('profile-followers-count'), findsNothing);
    });
    // S343 · decision 0271: 我's own holdings, net worth and 充值 are gone;
    // 我的 lists 钱包's.
  });

  group('「隐藏余额」 persistence (decision 0175)', () {
    test('hide-balance adapter uses one namespaced Boolean key', () async {
      final reads = <String>[];
      final writes = <(String, bool)>[];
      final store = SharedPreferencesLoopBalanceVisibilityStore.forTesting((
        key,
      ) async {
        reads.add(key);
        return true;
      }, (key, value) async => writes.add((key, value)));
      expect(await store.readHideBalance(), isTrue);
      await store.writeHideBalance(false);
      expect(
        SharedPreferencesLoopBalanceVisibilityStore.hideBalanceKey,
        'loop.display.v1.hide_balance',
      );
      expect(reads, <String>['loop.display.v1.hide_balance']);
      expect(writes, <(String, bool)>[('loop.display.v1.hide_balance', false)]);
    });

    testWidgets('the capsule masks the figures and stores the choice', (
      tester,
    ) async {
      final store = _Store();
      await _pump(tester, store: store);
      expect(_eyeHidden(tester), isFalse);

      await tester.tap(_key('wallet-eye'));
      await tester.pumpAndSettle();
      expect(_eyeHidden(tester), isTrue);
      expect(tester.widget<Text>(_key('wallet-total-figure')).data, '****');
      // The asset rows are masked with it.
      expect(
        tester
            .widget<Text>(_key('wallet-balance-amount-$s5NativeAssetId'))
            .data,
        '****',
      );
      expect(store.writes, <bool>[true]);
    });

    testWidgets(
      'a stored hidden choice masks the net worth after reconstruction',
      (tester) async {
        final store = _Store(value: true);
        await _pump(tester, store: store);
        expect(tester.widget<Text>(_key('wallet-total-figure')).data, '****');
        expect(_eyeHidden(tester), isTrue);
        expect(store.writes, isEmpty);

        // A fresh scope — a cold start — reads the same stored choice.
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, store: store);
        expect(tester.widget<Text>(_key('wallet-total-figure')).data, '****');
      },
    );

    testWidgets('a failed read starts shown and stays run-local', (
      tester,
    ) async {
      final store = _Store(value: true, failRead: true, failWrite: true);
      await _pump(tester, store: store);
      // Fail-open: the figures are shown, and the capsule says the device
      // could not keep the choice.
      expect(
        tester.widget<Text>(_key('wallet-total-figure')).data,
        r'$6,352.82',
      );

      await tester.tap(_key('wallet-eye'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(_key('wallet-total-figure')).data, '****');
    });

    test(
      'a choice made before the read answers is never overwritten',
      () async {
        final read = Completer<bool?>();
        final store = _PendingStore(read.future);
        final container = ProviderContainer(
          overrides: [
            loopBalanceVisibilityStoreProvider.overrideWithValue(store),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(loopBalanceVisibilityProvider).hidden, isFalse);
        await container.read(loopBalanceVisibilityProvider.notifier).toggle();
        read.complete(false);
        await Future<void>.delayed(Duration.zero);
        final state = container.read(loopBalanceVisibilityProvider);
        expect(state.hidden, isTrue);
        expect(state.persistence, LoopBalanceVisibilityPersistence.available);
      },
    );
  });
}

final class _PendingStore implements LoopBalanceVisibilityStore {
  _PendingStore(this._read);

  final Future<bool?> _read;

  @override
  Future<bool?> readHideBalance() => _read;

  @override
  Future<void> writeHideBalance(bool value) async {}
}
