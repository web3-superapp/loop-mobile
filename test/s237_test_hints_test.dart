// S237 · client decision 0204: 需求方 2026-10-19「页面不要有测试相关提示」.
// Every user-visible test hint goes through one switch,
// `LoopFeatureSwitches.testHintsVisible`, off by default. These cases pin the
// default (off) on the surfaces the requester checks, and three of the
// original behaviours with the switch on.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/loop_backend_identity.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_screen.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s8_harness.dart';
import 'support/testnet_faucet_fakes.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _stagingUrl = 'https://api-staging.quant-dinger.cc';

AppConfig _config(String baseUrl) => AppConfig(
  privyAppId: '',
  privyAppClientId: '',
  streamApiKey: '',
  backendBaseUrl: baseUrl,
  firebaseConfigured: false,
  declaredBuildModeName: 'debug',
);

List<Override> _staging() => <Override>[
  appConfigProvider.overrideWithValue(_config(_stagingUrl)),
  loopReleaseBinaryProvider.overrideWithValue(false),
];

Map<String, Object?> _launchChainWire() =>
    (jsonDecode(
          File('test/fixtures/s236/wallet_balances_launch_chain.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['launchChain']!
        as Map<String, Object?>;

LoopWalletBalances _balances() => DioLoopV2WalletApi.decodeBalances(
  s5BalancesBody()..['launchChain'] = _launchChainWire(),
  walletId: s5WalletId,
);

/// Every test-only word the requester listed, none of which may be drawn
/// with the switch off.
const List<String> _hintWords = <String>[
  '测试',
  '水龙头',
  'TESTNET',
  'STAGING',
  'tBNB',
  'tUSD1',
];

void _expectNoHintText() {
  for (final word in _hintWords) {
    expect(find.textContaining(word), findsNothing, reason: word);
  }
}

Future<void> _pumpWallet(WidgetTester tester) => pumpS5Page(
  tester,
  const WalletScreen(),
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: _balances()),
  ),
  meta: s5MetaSnapshot(testnetFaucet: LoopV2CapabilityAvailability.available),
  overrides: <Override>[
    ..._staging(),
    testnetFaucetGatewayProvider.overrideWithValue(
      FakeTestnetFaucetGateway(status: faucetStatus(walletId: s5WalletId)),
    ),
  ],
);

void main() {
  loopWatchGround();

  test('the switch is off by default', () {
    expect(LoopFeatureSwitches.testHintsVisible, isFalse);
    expect(loopTestHintsVisible, isFalse);
  });

  group('switch off (the default)', () {
    setUp(() => debugSetLoopTestHintsVisible(null));

    testWidgets('钱包首页: no faucet card, no 测试网, no STAGING, plain symbols', (
      tester,
    ) async {
      await _pumpWallet(tester);
      expect(_key('wallet-screen'), findsOneWidget);
      expect(_key('wallet-faucet-entry'), findsNothing);
      expect(find.textContaining('领取测试币'), findsNothing);
      expect(find.textContaining('获取资金'), findsNothing);
      // The DEV / STAGING tag beside 总资产.
      expect(find.text('STAGING'), findsNothing);
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(find.text('Launch 链'), findsOneWidget);
      expect(_key('loop-testnet-badge'), findsNothing);
      expect(_key('wallet-launch-chain-info'), findsNothing);
      expect(_key('wallet-launch-chain-total-note'), findsNothing);
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-row'),
          matching: find.text('BNB'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text('USD1'),
        ),
        findsOneWidget,
      );
      _expectNoHintText();
    });

    testWidgets('签名单: 网络 is BNB Smart Chain and no badge is drawn', (
      tester,
    ) async {
      expect(loopChainName(loopLaunchTestnetChainId), 'BNB Smart Chain');
      expect(loopTestnetBadgeFor(loopLaunchTestnetChainId), isNull);
      expect(loopTestnetBadgeFor(loopPrimaryChainId), isNull);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                LoopTestnetBadge(),
                LoopTestnetNotice(visible: true),
              ],
            ),
          ),
        ),
      );
      expect(_key('loop-testnet-badge'), findsNothing);
      expect(_key('loop-testnet-notice'), findsNothing);
    });

    test('余额不足: BNB 手续费不足, never tBNB', () {
      expect(memeReasonText('MEME_GAS_INSUFFICIENT'), 'BNB 手续费不足');
      expect(launch2ReasonText('LAUNCH2_GAS_INSUFFICIENT'), 'BNB 手续费不足，充值后再试');
      expect(launch2GasShortText, startsWith('BNB 手续费不足'));
      expect(launch2GasShortText, isNot(contains('tBNB')));
      expect(loopDisplaySymbol('tBNB'), 'BNB');
      expect(loopDisplaySymbol('tUSD1'), 'USD1');
      expect(loopDisplaySymbol('PEPE'), 'PEPE');
    });

    test('launch2 kicker: no TESTNET', () {
      expect(launch2DeskKicker(loopLaunchTestnetChainId), 'LAUNCH DESK · BSC');
      expect(launch2DeskKicker(loopPrimaryChainId), 'LAUNCH DESK · BSC');
    });

    test('环境标签: no DEV / STAGING tag', () {
      expect(loopEnvironmentTag(_stagingUrl, release: false), isNull);
    });

    testWidgets('关于: no 服务端 host, no tier, no 构建模式', (tester) async {
      await pumpS8Page(
        tester,
        const AboutScreen(),
        about: FakeAboutGateway(),
        overrides: _staging(),
      );
      expect(_key('about-screen'), findsOneWidget);
      expect(_key('about-network-diagnostics'), findsOneWidget);
      expect(_key('about-backend-host'), findsNothing);
      expect(_key('about-build-mode'), findsNothing);
      expect(find.textContaining('api-staging'), findsNothing);
      expect(find.text('构建模式'), findsNothing);
      _expectNoHintText();
    });

    testWidgets('网络诊断: the build rows stay hidden too', (tester) async {
      await pumpS8Page(
        tester,
        const NetworkDiagnosticsScreen(),
        overrides: _staging(),
      );
      expect(_key('network-diagnostics-screen'), findsOneWidget);
      expect(_key('about-backend-host'), findsNothing);
      expect(_key('about-build-mode'), findsNothing);
      expect(find.textContaining('api-staging'), findsNothing);
      _expectNoHintText();
    });

    test('specimen routes are closed outside a Development Preview', () {
      for (final location in loopSpecimenLocations) {
        expect(
          loopSpecimenLocationClosed(location, previewSession: false),
          isTrue,
          reason: location,
        );
        expect(
          loopSpecimenLocationClosed(location, previewSession: true),
          isFalse,
          reason: location,
        );
      }
      expect(
        loopSpecimenLocationClosed('/system/update', previewSession: false),
        isFalse,
      );
      expect(
        loopSpecimenLocationClosed('/system/region', previewSession: false),
        isFalse,
      );
    });
  });

  group('switch on (走查包)', () {
    setUp(() => debugSetLoopTestHintsVisible(true));
    tearDown(() => debugSetLoopTestHintsVisible(null));

    test('the chain, the kicker and the environment tag say testnet', () {
      expect(loopChainName(loopLaunchTestnetChainId), 'BSC 测试网');
      expect(loopTestnetBadgeFor(loopLaunchTestnetChainId), 'BSC 测试网');
      expect(
        launch2DeskKicker(loopLaunchTestnetChainId),
        'LAUNCH DESK · BSC TESTNET',
      );
      expect(loopEnvironmentTag(_stagingUrl, release: false), 'STAGING');
      expect(loopDisplaySymbol('tBNB'), 'tBNB');
      expect(memeReasonText('MEME_GAS_INSUFFICIENT'), 'tBNB 手续费不足');
    });

    testWidgets('钱包首页: the badge, the note and the STAGING tag are back', (
      tester,
    ) async {
      await _pumpWallet(tester);
      expect(find.text('STAGING'), findsOneWidget);
      await scrollToS5Section(tester, _key('wallet-launch-chain-total-note'));
      expect(_key('loop-testnet-badge'), findsWidgets);
      expect(_key('wallet-launch-chain-info'), findsOneWidget);
    });

    test('specimen routes open again', () {
      expect(
        loopSpecimenLocationClosed('/system/offline', previewSession: false),
        isFalse,
      );
    });
  });
}
