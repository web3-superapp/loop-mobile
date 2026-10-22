// S287 · decision 0241: the self-review shots of the notification centre and
// the 聊天 bell (需求方 2026-10-22 第 10 条).
//
// Not a check: it writes 390-wide renders to docs/integration/S287/shots/
// (or `LOOP_SHOTS_DIR`). It runs only with `--dart-define=LOOP_SHOTS=true`;
// a plain `flutter test` skips every case and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s287_notifications.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S287/shots',
);

const Size _phone = Size(390, 844);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 844, dir: _dir);

void main() {
  loopWatchGround();

  testWidgets('通知中心 · 有数据', skip: !_shots, (tester) async {
    await pumpS287Inbox(
      tester,
      S287NotificationsGateway(items: s287MixedRows()),
      size: _phone,
    );
    await _shot(tester, 'notification-centre');
  });

  testWidgets('通知中心 · 空态', skip: !_shots, (tester) async {
    await pumpS287Inbox(tester, S287NotificationsGateway(), size: _phone);
    await _shot(tester, 'notification-centre-empty');
  });

  testWidgets('聊天顶栏 · 角标', skip: !_shots, (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _phone;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final gateway = S287NotificationsGateway()
      ..unread = LoopNotificationUnreadCount(
        unread: 5,
        observedAt: DateTime.utc(2026, 10, 22, 7),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsGatewayProvider.overrideWithValue(gateway),
          streamChatAuthorizationProvider.overrideWith(
            (ref) async => StreamSessionAuthorization.unavailable,
          ),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: StreamChatInboxPage(onOpenNotifications: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await _shot(tester, 'chat-head-bell');
  });
}
