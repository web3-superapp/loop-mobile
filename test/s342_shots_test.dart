// S342 · decision 0270: self-review renders of the in-app DApp browser.
//
// Not a check: it writes 390-wide renders to build/s342-shots (or
// `LOOP_SHOTS_DIR`). It runs only with `--dart-define=LOOP_SHOTS=true`; a
// plain `flutter test` skips every case and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/dapp/dapp_browser_screens.dart';
import 'package:loop_mobile/features/dapp/dapp_gateway.dart';
import 'package:loop_mobile/features/dapp/dapp_signing.dart';
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/features/dapp/dapp_webview.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s342_dapp_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'build/s342-shots',
);

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loopV2MetaSnapshotProvider.overrideWith(
          (ref) async => s5MetaSnapshot(
            dappBrowser: LoopV2CapabilityAvailability.available,
          ),
        ),
        dappWebViewFactoryProvider.overrideWithValue(FakeDappWebViewFactory()),
        dappBrowserStoreProvider.overrideWithValue(
          MemoryDappBrowserStore(
            DappBrowserLocalState(
              recents: const <DappPageEntry>[
                DappPageEntry(
                  url: 'https://pancakeswap.finance/swap',
                  title: 'PancakeSwap',
                ),
                DappPageEntry(
                  url: 'https://app.uniswap.org/',
                  title: 'Uniswap',
                ),
                DappPageEntry(url: 'https://venus.io/', title: ''),
              ],
              bookmarks: const <DappPageEntry>[
                DappPageEntry(
                  url: 'https://pancakeswap.finance/',
                  title: 'PancakeSwap',
                ),
              ],
            ),
          ),
        ),
        dappIntentsGatewayProvider.overrideWithValue(FakeDappIntentsGateway()),
        walletReadGatewayProvider.overrideWithValue(FakeWalletReadGateway()),
        walletSigningGatewayProvider.overrideWithValue(
          RecordingSigningGateway(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  testWidgets('浏览器首页', skip: !_shots, (tester) async {
    await _pump(tester, const DappEntryScreen());
    await loopShot(tester, 's342-dapp-home', dir: _dir, slice: 844);
  });

  testWidgets('打开网页外壳', skip: !_shots, (tester) async {
    await _pump(
      tester,
      DappBrowserPage(
        request: DappOpenRequest(url: Uri.parse('$s342Origin/swap')),
      ),
    );
    await loopShot(tester, 's342-dapp-web', dir: _dir, slice: 844);
  });

  testWidgets('连接确认', skip: !_shots, (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: LoopColors.ink,
          body: Center(
            child: TextButton(
              onPressed: () => showDappConnectSheet(
                context,
                origin: s342Origin,
                address: s342Address,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await loopShot(tester, 's342-dapp-connect', dir: _dir, slice: 844);
  });

  testWidgets('dapp-tx 确认（无限授权）', skip: !_shots, (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: LoopColors.ink,
          body: Center(
            child: TextButton(
              onPressed: () => showDappIntentSheet(
                context,
                intent: s342TxIntent(),
                signer: DappSigner(
                  wallet: RecordingSigningGateway(),
                  intents: FakeDappIntentsGateway(),
                ),
                fromAddress: s342Address,
                tx: s342TxRequest,
                clock: () => DateTime.utc(2026, 11, 3),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await loopShot(tester, 's342-dapp-tx-confirm', dir: _dir, slice: 844);
  });
}
