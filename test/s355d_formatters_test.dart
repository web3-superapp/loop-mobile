// S355d · decision 0281 · glossary §一 7–8: the wallet / chain date and time
// formatters answer in the app's language — English by default, the original
// Chinese once the reader picks 简体中文.
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_sheet.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

void main() {
  final now = DateTime(2026, 11, 4, 14, 5);

  group('English (default)', () {
    test('relative time is compact', () {
      expect(
        loopRelativeTime(now.subtract(const Duration(seconds: 30)), now: now),
        '30s ago',
      );
      expect(
        loopRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        loopRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        loopRelativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
      expect(
        loopRelativeTime(now.add(const Duration(minutes: 1)), now: now),
        'Just now',
      );
    });

    test('months are three-letter abbreviations', () {
      expect(loopMonthLabel(1), 'Jan');
      expect(loopMonthLabel(11), 'Nov');
      expect(loopMonthLabel(12), 'Dec');
    });

    test('activity day headers read MMM d / MMM d, yyyy', () {
      expect(walletActivityDayLabel(now, now: now), 'Today');
      expect(
        walletActivityDayLabel(DateTime(2026, 11, 3, 9), now: now),
        'Yesterday',
      );
      expect(
        walletActivityDayLabel(DateTime(2026, 9, 16, 9), now: now),
        'Sep 16',
      );
      expect(
        walletActivityDayLabel(DateTime(2025, 9, 16, 9), now: now),
        'Sep 16, 2025',
      );
    });

    test('the faucet next-claim label reads MMM d, HH:mm', () {
      expect(
        testnetFaucetNextLabel(DateTime(2026, 11, 4, 18, 30), now: now),
        '18:30',
      );
      expect(
        testnetFaucetNextLabel(DateTime(2026, 11, 5, 9, 7), now: now),
        'Tomorrow 09:07',
      );
      expect(
        testnetFaucetNextLabel(DateTime(2026, 11, 7, 9, 7), now: now),
        'Nov 7, 09:07',
      );
    });

    test('cooldown periods are pluralised', () {
      expect(testnetFaucetCooldownText(86400), '24 hours');
      expect(testnetFaucetCooldownText(3 * 86400), '3 days');
      expect(testnetFaucetCooldownText(3600), '1 hour');
      expect(testnetFaucetCooldownText(60), '1 minute');
      expect(testnetFaucetCooldownText(45), '45 seconds');
    });
  });

  group('简体中文', () {
    setUp(() => LoopL10n.use(LoopL10n.simplifiedChinese));
    tearDown(LoopL10n.debugReset);

    test('the Chinese wording is unchanged', () {
      expect(
        loopRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 分钟前',
      );
      expect(loopMonthLabel(11), '11');
      expect(
        walletActivityDayLabel(DateTime(2026, 9, 16, 9), now: now),
        '9月16日',
      );
      expect(
        walletActivityDayLabel(DateTime(2025, 9, 16, 9), now: now),
        '2025年9月16日',
      );
      expect(
        testnetFaucetNextLabel(DateTime(2026, 11, 7, 9, 7), now: now),
        '11月7日 09:07',
      );
      expect(testnetFaucetCooldownText(3 * 86400), '3 天');
    });
  });
}
