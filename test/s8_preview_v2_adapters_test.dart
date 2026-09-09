import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/integrations/market/memory_watchlist_gateway.dart';
import 'package:loop_mobile/integrations/notifications/memory_notifications_gateway.dart';

import 'support/s5_page_harness.dart';

/// Decision 0061 · the two Preview adapters step 5 deliberately deferred.
///
/// Preview is UI evidence, so an adapter that lied about the contract would be
/// worse than the unavailable surface it replaced. These tests hold the two
/// rewritten adapters to the same shape the V2 transports parse: a version
/// compare-and-set, all ten notification categories, a locked `security.event`
/// the server refuses to turn off, and delivery that stays unavailable whatever
/// is saved. They also hold the production composition to its side of the deal:
/// neither adapter is reachable without an explicit Preview override.
void main() {
  group('production is unreachable from either adapter', () {
    test('both ports stay fail-closed with no override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(watchlistGatewayProvider),
        isA<UnavailableWatchlistGateway>(),
      );
      expect(
        container.read(notificationsGatewayProvider),
        isA<UnavailableNotificationsGateway>(),
      );
      expect(
        container.read(watchlistGatewayProvider).mode,
        LoopChainGatewayMode.unavailable,
      );
      expect(
        container.read(notificationsGatewayProvider).mode,
        LoopChainGatewayMode.unavailable,
      );
    });

    test('only the Preview root composes them', () {
      // A production build must never be able to reach a fixture. The Preview
      // root is the one file allowed to name either class.
      const memoryClasses = <String>[
        'MemoryWatchlistGateway',
        'MemoryNotificationsGateway',
      ];
      final production = File('lib/main.dart').readAsStringSync();
      final preview = File('lib/main_preview.dart').readAsStringSync();
      for (final name in memoryClasses) {
        expect(production.contains(name), isFalse, reason: name);
        expect(preview.contains(name), isTrue, reason: name);
      }
    });
  });

  group('MemoryWatchlistGateway', () {
    test('is labelled Preview and replaces under a version CAS', () async {
      final gateway = MemoryWatchlistGateway();
      expect(gateway.mode, LoopChainGatewayMode.preview);

      final snapshot = await gateway.load();
      expect(snapshot.version, 1);
      expect(snapshot.itemCount, 4);
      // The contract's own "listed but unreadable" row survives a round trip:
      // the editor must still be able to remove it.
      final unreadable = snapshot.groups.last.items.last;
      expect(unreadable.isReadable, isFalse);
      expect(unreadable.reasonCode, 'ASSET_NOT_IN_REGISTRY');

      final replaced = await gateway.replace(
        expectedVersion: 1,
        groups: <WatchlistGroup>[snapshot.groups.first],
      );
      expect(replaced.version, 2);
      expect(replaced.groups, hasLength(1));
      expect((await gateway.load()).version, 2);
    });

    test('a stale expected version is a conflict, not an overwrite', () async {
      final gateway = MemoryWatchlistGateway();
      final snapshot = await gateway.load();
      await gateway.replace(expectedVersion: 1, groups: snapshot.groups);

      await expectLater(
        gateway.replace(expectedVersion: 1, groups: const <WatchlistGroup>[]),
        throwsA(
          isA<LoopChainException>().having(
            (error) => error.kind,
            'kind',
            LoopChainFailureKind.versionConflict,
          ),
        ),
      );
      expect((await gateway.load()).version, 2);
    });
  });

  group('MemoryNotificationsGateway', () {
    test(
      'answers with all ten categories and a locked security event',
      () async {
        final gateway = MemoryNotificationsGateway();
        expect(gateway.mode, LoopChainGatewayMode.preview);

        final preferences = await gateway.loadPreferences();
        expect(
          preferences.categories.keys.toSet(),
          LoopNotificationCategory.values.toSet(),
        );
        expect(
          preferences.lockedFor(LoopNotificationCategory.securityEvent),
          isTrue,
        );
        expect(
          preferences.enabledFor(LoopNotificationCategory.securityEvent),
          isTrue,
        );
        // Delivery is unavailable in both compositions; a saved intent never
        // implies a channel exists.
        expect(preferences.push.reasonCode, 'PUSH_RUNTIME_DEFERRED');
      },
    );

    test('refuses a write that turns the security event off', () async {
      final gateway = MemoryNotificationsGateway();
      final preferences = await gateway.loadPreferences();
      final draft = <LoopNotificationCategory, bool>{
        for (final category in LoopNotificationCategory.values) category: true,
        LoopNotificationCategory.securityEvent: false,
      };

      await expectLater(
        gateway.replacePreferences(
          expectedVersion: preferences.version,
          categories: draft,
        ),
        throwsA(
          isA<LoopChainException>().having(
            (error) => error.kind,
            'kind',
            LoopChainFailureKind.validationFailed,
          ),
        ),
      );
      // The refusal changed nothing, exactly as a 422 leaves the resource.
      expect((await gateway.loadPreferences()).version, preferences.version);
    });

    test('refuses a partial write and accepts the full ten', () async {
      final gateway = MemoryNotificationsGateway();
      final preferences = await gateway.loadPreferences();

      await expectLater(
        gateway.replacePreferences(
          expectedVersion: preferences.version,
          categories: <LoopNotificationCategory, bool>{
            LoopNotificationCategory.securityEvent: true,
          },
        ),
        throwsA(isA<LoopChainException>()),
      );

      final saved = await gateway.replacePreferences(
        expectedVersion: preferences.version,
        categories: preferences.draftWith(
          LoopNotificationCategory.communityAll,
          true,
        ),
      );
      expect(saved.version, preferences.version + 1);
      expect(saved.enabledFor(LoopNotificationCategory.communityAll), isTrue);
      expect(saved.push.reasonCode, 'PUSH_RUNTIME_DEFERRED');
    });
  });

  group('the two Preview surfaces are visibly labelled', () {
    testWidgets('watchlist-edit says 演示数据 and lists the fixture', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: MemoryWatchlistGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('chain-preview-notice')),
        findsOneWidget,
      );
      expect(find.text('演示数据'), findsOneWidget);
      expect(find.text('4 个自选资产'), findsOneWidget);
      // A labelled Preview is never also an unavailable surface.
      expect(
        find.byKey(const ValueKey<String>('watchlist-capability-block')),
        findsNothing,
      );
    });

    testWidgets('notif-settings says 演示数据 and keeps push unavailable', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: MemoryNotificationsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('chain-preview-notice')),
        findsOneWidget,
      );
      expect(find.text('演示数据'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('notification-push-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-capability-block')),
        findsNothing,
      );
    });
  });
}
