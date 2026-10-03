import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_backend_identity.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_environment_tag.dart';

import 'support/s5_page_harness.dart';
import 'support/s8_harness.dart';

/// Decision 0100 · which backend this build talks to. Read from the
/// build-time `LOOP_BACKEND_BASE_URL`; no request is made for it.
AppConfig _config(String baseUrl, {String mode = 'debug'}) => AppConfig(
  privyAppId: '',
  privyAppClientId: '',
  streamApiKey: '',
  backendBaseUrl: baseUrl,
  firebaseConfigured: false,
  declaredBuildModeName: mode,
);

List<Override> _overrides(String baseUrl, {required bool release}) =>
    <Override>[
      appConfigProvider.overrideWithValue(_config(baseUrl)),
      loopReleaseBinaryProvider.overrideWithValue(release),
    ];

void main() {
  group('host → tier', () {
    test('the configured hosts', () {
      final cases = <String, (String?, String?)>{
        'https://api-dev.quant-dinger.cc': ('api-dev.quant-dinger.cc', 'DEV'),
        'https://api-staging.quant-dinger.cc': (
          'api-staging.quant-dinger.cc',
          'STAGING',
        ),
        'https://api.quant-dinger.cc/': ('api.quant-dinger.cc', 'PROD'),
        'http://10.0.2.2:3100': ('10.0.2.2', 'LOCAL'),
        'http://localhost:3100': ('localhost', 'LOCAL'),
        'https://API-DEV.Example.com': ('api-dev.example.com', 'DEV'),
        'https://preview-7.example.com': ('preview-7.example.com', 'PREVIEW-7'),
        '': (null, null),
        '   ': (null, null),
        'not a url': (null, null),
      };
      cases.forEach((url, expected) {
        final host = loopBackendHost(url);
        expect(host, expected.$1, reason: url);
        expect(host == null ? null : loopBackendTier(host), expected.$2);
      });
    });

    test('a release binary never draws a tag', () {
      expect(
        loopEnvironmentTag('https://api-dev.quant-dinger.cc', release: false),
        'DEV',
      );
      expect(
        loopEnvironmentTag('https://api-dev.quant-dinger.cc', release: true),
        isNull,
      );
      expect(loopEnvironmentTag('', release: false), isNull);
    });

    test('runtime mode names', () {
      expect(loopRuntimeBuildMode(release: true, profile: false), 'release');
      expect(loopRuntimeBuildMode(release: false, profile: true), 'profile');
      expect(loopRuntimeBuildMode(release: false, profile: false), 'debug');
    });
  });

  group('wallet hero tag', () {
    testWidgets('a non-release build shows STAGING beside the kicker', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        overrides: _overrides(
          'https://api-staging.quant-dinger.cc',
          release: false,
        ),
      );
      final tag = find.byKey(const ValueKey<String>('wallet-environment-tag'));
      expect(tag, findsOneWidget);
      expect(
        find.descendant(of: tag, matching: find.text('STAGING')),
        findsOneWidget,
      );
      expect(tester.getSize(tag).height, LoopEnvironmentTag.height);
      // Same line as the kicker, at its right end.
      final kicker = find.text('资产净值（USD）');
      expect(
        (tester.getCenter(tag).dy - tester.getCenter(kicker).dy).abs(),
        lessThan(2),
      );
      expect(
        tester.getTopLeft(tag).dx,
        greaterThan(tester.getTopRight(kicker).dx),
      );
    });

    testWidgets('a release build shows nothing', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
        overrides: _overrides('https://api-dev.quant-dinger.cc', release: true),
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-environment-tag')),
        findsNothing,
      );
      expect(find.byType(LoopEnvironmentTag), findsNothing);
      expect(find.text('资产净值（USD）'), findsOneWidget);
    });
  });

  group('about · 服务端', () {
    testWidgets('the host and the declared build mode', (tester) async {
      await pumpS8Page(
        tester,
        const AboutScreen(),
        about: FakeAboutGateway(),
        overrides: _overrides(
          'https://api-dev.quant-dinger.cc',
          release: false,
        ),
      );
      final row = find.byKey(const ValueKey<String>('about-backend-host'));
      await scrollToS8Section(tester, row);
      expect(
        find.descendant(
          of: row,
          matching: find.text('api-dev.quant-dinger.cc'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('DEV')),
        findsWidgets,
      );
      final mode = find.byKey(const ValueKey<String>('about-build-mode'));
      expect(
        find.descendant(of: mode, matching: find.textContaining('声明 debug')),
        findsOneWidget,
      );
    });

    testWidgets('no backend configured says so', (tester) async {
      await pumpS8Page(
        tester,
        const AboutScreen(),
        about: FakeAboutGateway(),
        overrides: _overrides('', release: false),
      );
      final row = find.byKey(const ValueKey<String>('about-backend-host'));
      await scrollToS8Section(tester, row);
      expect(
        find.descendant(of: row, matching: find.text('构建配置里没有服务端地址')),
        findsOneWidget,
      );
    });
  });
}
