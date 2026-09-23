// The clock LOOP reads when a timestamp has to agree with the servers.
//
// C-31: a member can set the device clock to anything. Every answer from a
// server names an instant on the servers' own clock, so the app can know how
// far off the device is without asking for anything extra, and stamp what it
// sends with a time the servers will recognise.
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/time/loop_server_clock.dart';

void main() {
  group('LoopServerClock', () {
    test('is the device clock until a server has named an instant', () {
      final device = DateTime.utc(2026, 9, 17, 12);
      final clock = LoopServerClock(deviceNow: () => device);

      expect(clock.hasServerObservation, isFalse);
      expect(clock.offset, Duration.zero);
      expect(clock.nowUtc(), device);
    });

    test('corrects a device that is a day behind', () {
      final server = DateTime.utc(2026, 9, 17, 12);
      final device = server.subtract(const Duration(days: 1));
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observe(serverTime: server, sentAt: device, receivedAt: device);

      expect(clock.offset, const Duration(days: 1));
      expect(clock.nowUtc(), server);
      expect(
        clock.deviceNow(),
        device,
        reason: 'the device clock itself is left alone',
      );
    });

    test('pairs the server instant with the middle of the round trip', () {
      final server = DateTime.utc(2026, 9, 17, 12);
      final device = DateTime.utc(2026, 9, 17, 10);
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observe(
        serverTime: server,
        sentAt: device,
        receivedAt: device.add(const Duration(milliseconds: 200)),
      );

      expect(
        clock.offset,
        const Duration(hours: 2) - const Duration(milliseconds: 100),
      );
    });

    test('drops an observation too slow to say anything', () {
      final server = DateTime.utc(2026, 9, 17, 12);
      final device = DateTime.utc(2026, 9, 17, 10);
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observe(
        serverTime: server,
        sentAt: device,
        receivedAt: device.add(const Duration(minutes: 5)),
      );

      expect(clock.hasServerObservation, isFalse);
      expect(clock.offset, Duration.zero);
    });

    test('drops an answer that claims to precede its own request', () {
      final device = DateTime.utc(2026, 9, 17, 10);
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observe(
        serverTime: DateTime.utc(2026, 9, 17, 12),
        sentAt: device,
        receivedAt: device.subtract(const Duration(seconds: 1)),
      );

      expect(clock.hasServerObservation, isFalse);
    });

    test(
      'the newest reading wins, because the member can change the clock',
      () {
        var device = DateTime.utc(2026, 9, 17, 12);
        final clock = LoopServerClock(deviceNow: () => device);

        clock.observe(
          serverTime: DateTime.utc(2026, 9, 17, 12),
          sentAt: device,
          receivedAt: device,
        );
        expect(clock.offset, Duration.zero);

        device = DateTime.utc(2026, 9, 16, 12);
        clock.observe(
          serverTime: DateTime.utc(2026, 9, 17, 12, 0, 30),
          sentAt: device,
          receivedAt: device,
        );

        expect(clock.offset, const Duration(days: 1, seconds: 30));
      },
    );

    test('an undated delivery may raise the offset but never lower it', () {
      final device = DateTime.utc(2026, 9, 17, 11);
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observeAtLeast(
        serverTime: DateTime.utc(2026, 9, 17, 12),
        at: device,
      );
      expect(clock.offset, const Duration(hours: 1));

      // A message replayed after a reconnect carries an older instant; it
      // says nothing about the drift and must not undo what is known.
      clock.observeAtLeast(
        serverTime: DateTime.utc(2026, 9, 17, 11, 30),
        at: device,
      );
      expect(clock.offset, const Duration(hours: 1));

      // The measured round trip is allowed to correct it downwards.
      clock.observe(
        serverTime: DateTime.utc(2026, 9, 17, 11, 30),
        sentAt: device,
        receivedAt: device,
      );
      expect(clock.offset, const Duration(minutes: 30));
    });

    test('the first undated delivery cannot set the clock backwards', () {
      // Device walkthrough 2026-09-23 · a10/a11/a33: the first message the
      // socket replayed into a watched channel was two days old, and it was
      // taken as the drift. 「今天」 then labelled Monday's messages.
      final device = DateTime.utc(2026, 9, 23, 3);
      final clock = LoopServerClock(deviceNow: () => device);

      clock.observeAtLeast(
        serverTime: DateTime.utc(2026, 9, 21, 12),
        at: device,
      );

      expect(clock.offset, Duration.zero);
      expect(clock.hasServerObservation, isFalse);
      expect(clock.nowUtc(), device);
    });
  });
}
