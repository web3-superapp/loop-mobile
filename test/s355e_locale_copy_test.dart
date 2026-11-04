import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/text/loop_error_text.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

/// S355e (decision 0281): copy in `lib/core`, account, profile and system
/// follows the App language, and the formatters there branch on
/// [LoopL10n.currentLocale].
void main() {
  tearDown(LoopL10n.debugReset);

  group('joined line', () {
    final activatedAt = DateTime(2026, 10, 12, 9);

    test('English names the month', () {
      expect(ProfileIdentityCard.joinedLine(activatedAt), 'Joined Oct 2026');
    });

    test('Chinese keeps the numeric month', () {
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(ProfileIdentityCard.joinedLine(activatedAt), '2026 年 10 月加入');
    });
  });

  group('route titles follow the App language', () {
    LoopRouteEntry entry(String slug) =>
        LoopRouteManifest.entries.firstWhere((e) => e.slug == slug);

    test('English by default, Chinese after a switch', () {
      expect(entry('devices').title, 'Device management');
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(entry('devices').title, '设备管理');
    });

    test('every manifest entry has an English title without CJK', () {
      final cjk = RegExp(r'[㐀-鿿]');
      for (final e in LoopRouteManifest.entries) {
        expect(e.title, isNotEmpty, reason: e.slug);
        expect(cjk.hasMatch(e.title), isFalse, reason: e.slug);
      }
    });
  });

  group('error catalog copy', () {
    test('resolves per code in the current language', () {
      final copy = LoopErrorText.forCode('INSUFFICIENT_BALANCE');
      expect(copy.title, 'Insufficient balance');
      LoopL10n.use(LoopL10n.simplifiedChinese);
      expect(copy.title, '余额不足');
    });

    test('unknown keeps its identity and its own copy', () {
      expect(LoopErrorText.forCode('FUTURE_CODE'), same(LoopErrorText.unknown));
      expect(LoopErrorText.unknown.title, "Can't finish right now");
    });
  });

  test('onboarding join button counts in English plurals', () {
    final l10n = LoopL10n.current;
    expect(
      l10n.account_onboardingCommunitiesS(1),
      'Join 1 community and enter',
    );
    expect(
      l10n.account_onboardingCommunitiesS(5),
      'Join 5 communities and enter',
    );
    LoopL10n.use(const Locale('zh', 'CN'));
    expect(LoopL10n.current.account_onboardingCommunitiesS(5), '加入 5 个社区并进入');
  });
}
