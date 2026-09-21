import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
import 'package:loop_mobile/integrations/personalization/memory_privacy_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';
import 'support/s8_harness.dart';

/// The Profile module's block order and its row vocabulary, pinned against
/// the frozen prototype (`docs/prototype/screens/{profile,…,support}.html`).
///
/// The visual audit of 2026-09-21 (§J, §D+ #11–#14) found three habits here:
/// a hero added to pages the prototype opens without one, a row's second line
/// describing the destination instead of stating its current value, and a
/// Material `Switch` where the prototype has a status pill. Each of those is
/// an ordering or a vocabulary fact, so each is asserted as one.
List<String> _labels(WidgetTester tester) => <String>[
  for (final label in tester.widgetList<LoopLabel>(find.byType(LoopLabel)))
    label.text,
];

/// A viewport tall enough that every section is built, so the order read off
/// the tree is the whole page's and not the first screen's.
const _tall = Size(390, 6000);

/// The real device's width and height, for the questions that are about what
/// fits on one screen.
const _phone = Size(390, 844);

void main() {
  // The privacy group mounts its page through its own `pumpWidget`, so this
  // file arms the ground probe itself.
  loopWatchGround();

  group('privacy · the last row is not held under the action bar', () {
    testWidgets('屏蔽名单 is fully visible and hittable at phone size', (
      tester,
    ) async {
      await _pumpPrivacy(tester, size: _phone);

      final row = find.byKey(const ValueKey<String>('privacy-open-blocklist'));
      final save = find.byKey(const ValueKey<String>('privacy-save'));
      expect(row, findsOneWidget);

      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final rowRect = tester.getRect(row);
      final saveRect = tester.getRect(save);
      final screen = Offset.zero & tester.view.physicalSize;

      // Whole row on screen, not two pixels of it.
      expect(rowRect.height, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(rowRect.top, greaterThanOrEqualTo(screen.top));
      expect(rowRect.bottom, lessThanOrEqualTo(screen.bottom));
      // And nothing of the action sits over it: the action flows with the
      // body now, so it comes after the row instead of on top of it.
      expect(rowRect.bottom, lessThanOrEqualTo(saveRect.top));

      // The point a finger lands on belongs to the row, not to the button.
      final hit = tester.hitTestOnBinding(rowRect.center);
      expect(
        hit.path.any(
          (entry) => identical(entry.target, tester.renderObject(row)),
        ),
        isTrue,
        reason: 'the blocklist row owns its own centre point',
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_navigated, contains('blocklist'));
    });

    testWidgets('a preference states itself as a pill, never as a value', (
      tester,
    ) async {
      await _pumpPrivacy(tester, size: _tall);

      final row = find.byKey(const ValueKey<String>('privacy-anonymous-mode'));
      expect(
        find.descendant(of: row, matching: find.byType(LoopBadge)),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
    });
  });

  group('settings · no hero, and a value on every row that has one', () {
    testWidgets('the page opens on 通用 and keeps the prototype groups', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(),
        size: _tall,
      );

      // §D+ #13: the prototype has no `[data-page-primary]` here.
      expect(
        find.byKey(const ValueKey<String>('loop-page-primary')),
        findsNothing,
      );
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(_labels(tester), <String>['通用', '账户', '关于']);

      // §D+ #11: 语言 reads its value, not a sentence about why it is fixed.
      final language = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('settings-language')),
      );
      expect(language.subtitle, isNull);
      expect(language.trailing, isNotNull);
      final privacy = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('settings-open-privacy')),
      );
      expect(privacy.subtitle, isNull);
    });
  });

  group('notif-settings · pills, not sliders', () {
    testWidgets('每一行只有一个状态控件，页面没有 hero', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        size: _tall,
      );

      expect(find.byType(Switch), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-page-primary')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('notification-preferences-summary')),
        findsOneWidget,
      );
      expect(_labels(tester), <String>['挖矿', 'Launch', '交易', '社区', '安全']);

      for (final category in LoopNotificationCategory.values) {
        final row = find.byKey(
          ValueKey<String>('notification-category-${category.wireName}'),
        );
        expect(
          find.descendant(of: row, matching: find.byType(LoopBadge)),
          findsOneWidget,
          reason: category.wireName,
        );
      }
    });
  });

  group('support · the answers the hero used to promise', () {
    testWidgets('联系我们 then 常见问题 then the ticket form', (tester) async {
      await pumpS8Page(
        tester,
        SupportScreen(onNavigate: (_) {}),
        support: FakeSupportGateway(),
        size: _tall,
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-primary')),
        findsNothing,
      );
      expect(_labels(tester), <String>['联系我们', '常见问题', '提交工单', '我的工单']);
      // Five bundled answers and the one human entry point.
      expect(find.byType(LoopDisclosure), findsNWidgets(6));
      expect(
        find.byKey(const ValueKey<String>('support-open-community')),
        findsOneWidget,
      );
      // The warning closes the page in the prototype; the disclosure is last.
      expect(
        find.byKey(const ValueKey<String>('support-policy-disclosure')),
        findsOneWidget,
      );
    });
  });

  group('security · 验证 and 恢复 are two groups', () {
    testWidgets('the posture card is Chalk and the methods are split', (
      tester,
    ) async {
      await pumpS8Page(
        tester,
        SecurityCenterScreen(onNavigate: (_) {}),
        security: FakeSecurityGateway(),
        size: _tall,
      );

      final folio = tester.widget<LoopFolioPrimary>(
        find.byKey(const ValueKey<String>('security-folio')),
      );
      expect(folio.variant, LoopFolioVariant.chalk);
      expect(folio.ring, isFalse);
      expect(_labels(tester), <String>[
        '验证',
        '恢复',
        '设备',
        '授权盘点',
        '通知',
        '最近安全事件',
      ]);
    });

    testWidgets('devices opens on a Chalk card too', (tester) async {
      await pumpS8Page(
        tester,
        const DeviceManagementScreen(),
        security: FakeSecurityGateway(),
        size: _tall,
      );

      final folio = tester.widget<LoopFolioPrimary>(
        find.byKey(const ValueKey<String>('devices-folio')),
      );
      expect(folio.variant, LoopFolioVariant.chalk);
    });
  });
}

final List<String> _navigated = <String>[];

Future<void> _pumpPrivacy(WidgetTester tester, {required Size size}) async {
  _navigated.clear();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyGatewayProvider.overrideWithValue(
          MemoryPrivacyGateway(
            initialResource: PrivacyResource(
              version: 1,
              values: const PrivacyValues.defaults(),
              updatedAt: DateTime.utc(2026, 8, 25),
            ),
            clock: () => DateTime.utc(2026, 8, 25, 12),
          ),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: ProfileSurfaceScreen.fromId(
          'privacy',
          onNavigate: _navigated.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
