import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_scroll_behavior.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_keyboard.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/launch2_fixtures.dart';
import 'support/launch2_trade_sheet.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

// ---------------------------------------------------------------------------
// S276 · every input's keyboard can be put away (client decision 0234)
//
// Requester bug, TestFlight 40 on an iPhone: the MEME trade page's amount
// field opens the iOS decimal pad, which has no return key, and neither a tap
// elsewhere nor a scroll put it away. Every value here is 测试专用.
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const Size _device = Size(390, 844);
const double _keyboard = 336;

/// The curve panel's gateway: one detail, scripted quotes, nothing else.
final class _Launch2 implements Launch2Gateway {
  _Launch2({required this.detail});

  final Launch2InstanceDetail detail;

  /// `null` answers every quote with a fresh [l2Quote].
  Object? quoteAnswer;
  final List<(Launch2Side, Decimal)> quoteCalls = <(Launch2Side, Decimal)>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) => _unavailable();

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      Future<Launch2InstanceDetail>.value(detail);

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) {
    quoteCalls.add((side, amount));
    final answer = quoteAnswer;
    if (answer is LoopChainException) return Future<Launch2Quote>.error(answer);
    return Future<Launch2Quote>.value(
      answer is Launch2Quote ? answer : l2Quote(),
    );
  }

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) => _unavailable();

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) => _unavailable();

  @override
  Future<Launch2Positions> loadPositions() => _unavailable();

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) => _unavailable();

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _unavailable();
}

Launch2InstanceDetail _public({Map<String, Object?>? holding}) => l2Detail(
  stage: 'public',
  viewer: l2ViewerJson(member: true, eligibleNow: true, holding: holding),
);

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: l2WalletId,
  address: l2WalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

Future<void> _pumpTrade(WidgetTester tester) async {
  await pumpS7Page(
    tester,
    const Launch2InstanceScreen(instanceId: l2InstanceA),
    size: _device,
    appKeyboard: true,
    meta: _meta(),
    wallet: FakeWalletDirectory(
      activeWalletId: l2WalletId,
      wallets: <LoopWalletAccount>[_wallet()],
    ),
    overrides: <Override>[
      launch2GatewayProvider.overrideWithValue(_Launch2(detail: _public())),
      launch2ClockProvider.overrideWithValue(() => l2Now),
      launch2PollingProvider.overrideWithValue(
        const Launch2Polling(
          detailInterval: Duration(hours: 1),
          tradingInterval: Duration(hours: 1),
        ),
      ),
      loopFeatureSwitchesProvider.overrideWithValue(
        const LoopFeatureSwitchValues(
          launch2Visible: true,
          classicMemeLaunchVisible: true,
        ),
      ),
    ],
  );
  // Decision 0240: the panel is the sheet behind the page's 买入 key.
  await l2OpenTradeSheet(tester);
  await tester.ensureVisible(_key('launch2-trade-amount'));
  await tester.pumpAndSettle();
}

/// Puts the amount field near the middle of the screen and focuses it.
Future<void> _focusAmount(WidgetTester tester) async {
  await tester.tap(_key('launch2-trade-amount'));
  await tester.pump();
  expect(_focused(tester, 'launch2-trade-amount'), isTrue);
}

/// A tap on the page just under the amount field: not a control, not the
/// field.
Future<void> _tapBesideField(WidgetTester tester) => tester.tapAt(
  tester.getRect(_key('launch2-trade-amount')).bottomLeft + const Offset(4, 30),
);

bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: _key(key), matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

Future<void> _drain(WidgetTester tester) async {
  tester.view.resetViewInsets();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

/// A bare App with the same keyboard rules as `app.dart`.
Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _device;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      scrollBehavior: const LoopScrollBehavior(),
      builder: (context, child) => LoopKeyboardScope(child: child!),
      home: home,
    ),
  );
}

void main() {
  loopShowTestHints();
  loopWatchGround();

  test('every scroll view without its own choice dismisses on drag', () {
    expect(
      const LoopScrollBehavior().getKeyboardDismissBehavior(_FakeContext()),
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  test('the pads with no return key are the number and phone pads', () {
    expect(loopKeyboardLacksReturnKey(TextInputType.number), isTrue);
    expect(
      loopKeyboardLacksReturnKey(
        const TextInputType.numberWithOptions(decimal: true),
      ),
      isTrue,
    );
    expect(loopKeyboardLacksReturnKey(TextInputType.phone), isTrue);
    expect(loopKeyboardLacksReturnKey(TextInputType.text), isFalse);
    expect(loopKeyboardLacksReturnKey(TextInputType.url), isFalse);
  });

  group('MEME trade panel', () {
    testWidgets('a tap elsewhere on the page puts the keyboard away', (
      tester,
    ) async {
      await _pumpTrade(tester);
      await _focusAmount(tester);
      await _tapBesideField(tester);
      await tester.pump();
      expect(_focused(tester, 'launch2-trade-amount'), isFalse);
      await _drain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('MAX and the 买入 / 卖出 switch keep the keyboard up', (
      tester,
    ) async {
      await _pumpTrade(tester);
      await _focusAmount(tester);
      await tester.tap(_key('launch2-trade-max'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'launch2-trade-amount'), isTrue);
      // A programmatic scroll (no drag) brings the switch into view.
      await tester.ensureVisible(_key('launch2-trade-side'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'launch2-trade-amount'), isTrue);
      await tester.tap(
        find.descendant(
          of: _key('launch2-trade-side'),
          matching: find.text('卖出'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_focused(tester, 'launch2-trade-amount'), isTrue);
      // Typing into the field itself never loses it either.
      await tester.tap(_key('launch2-trade-amount'));
      await tester.pump();
      expect(_focused(tester, 'launch2-trade-amount'), isTrue);
      await _drain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('dragging the page puts the keyboard away', (tester) async {
      await _pumpTrade(tester);
      await _focusAmount(tester);
      // The drag starts on the field itself, so no tap-outside is involved:
      // only the scroll view's own onDrag rule can clear the focus.
      await tester.drag(
        _key('launch2-trade-amount'),
        const Offset(0, 160),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(_focused(tester, 'launch2-trade-amount'), isFalse);
      await _drain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the decimal pad gets a 完成 bar on the keyboard that puts it '
        'away', (tester) async {
      await _pumpTrade(tester);
      await _focusAmount(tester);
      // Focus alone does not raise the bar: it waits for the keyboard.
      expect(_key('loop-keyboard-done-bar'), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      final bar = tester.getRect(_key('loop-keyboard-done-bar'));
      expect(bar.bottom, moreOrLessEquals(_device.height - _keyboard));
      expect(bar.height, LoopKeyboardDoneBar.height);
      expect(find.text('完成'), findsOneWidget);
      // The field was scrolled clear of the bar, not hidden under it.
      expect(
        tester.getRect(_key('launch2-trade-amount')).bottom,
        lessThanOrEqualTo(bar.top),
      );
      await tester.tap(_key('loop-keyboard-done'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'launch2-trade-amount'), isFalse);
      expect(_key('loop-keyboard-done-bar'), findsNothing);
      await _drain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('Android has its own done key: no 完成 bar', (tester) async {
      await _pumpTrade(tester);
      await _focusAmount(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      expect(_key('loop-keyboard-done-bar'), findsNothing);
      expect(
        tester.widget<TextField>(_key('launch2-trade-amount')).textInputAction,
        TextInputAction.done,
      );
      // The tap-outside rule holds on Android too.
      await _tapBesideField(tester);
      await tester.pump();
      expect(_focused(tester, 'launch2-trade-amount'), isFalse);
      await _drain(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('bottom sheets and composers', () {
    Widget sheetOpener() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey<String>('open'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      key: ValueKey<String>('sheet-blank'),
                      height: 120,
                      width: double.infinity,
                      child: Text('测试专用'),
                    ),
                    TextField(
                      key: ValueKey<String>('sheet-field'),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    TextField(key: ValueKey<String>('sheet-text')),
                  ],
                ),
              ),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    testWidgets('a field in a sheet loses focus on a tap outside it', (
      tester,
    ) async {
      await _pumpApp(tester, sheetOpener());
      await tester.tap(_key('open'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sheet-field'));
      await tester.pump();
      expect(_focused(tester, 'sheet-field'), isTrue);
      await tester.tap(_key('sheet-blank'));
      await tester.pump();
      expect(_focused(tester, 'sheet-field'), isFalse);
      // The sheet itself stays open: the tap only took the focus.
      expect(_key('sheet-field'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the sheet rises above the 完成 bar; a text field gets none', (
      tester,
    ) async {
      await _pumpApp(tester, sheetOpener());
      await tester.tap(_key('open'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sheet-field'));
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final bar = tester.getRect(_key('loop-keyboard-done-bar'));
      expect(
        tester.getRect(_key('sheet-text')).bottom,
        lessThanOrEqualTo(bar.top),
      );
      await tester.tap(_key('sheet-text'));
      await tester.pumpAndSettle();
      expect(_focused(tester, 'sheet-text'), isTrue);
      expect(_key('loop-keyboard-done-bar'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a composer\'s send key keeps the keyboard up', (tester) async {
      var sent = 0;
      await _pumpApp(
        tester,
        Scaffold(
          body: Column(
            children: <Widget>[
              const Expanded(
                child: SizedBox(
                  key: ValueKey<String>('blank'),
                  width: double.infinity,
                ),
              ),
              LoopComposer(onSend: (_) => sent += 1),
            ],
          ),
        ),
      );
      await tester.tap(_key('loop-composer-input'));
      await tester.pump();
      await tester.enterText(_key('loop-composer-input'), '测试专用');
      await tester.tap(_key('loop-composer-send'));
      await tester.pump();
      expect(sent, 1);
      expect(_focused(tester, 'loop-composer-input'), isTrue);
      await tester.tapAt(const Offset(20, 40));
      await tester.pump();
      expect(_focused(tester, 'loop-composer-input'), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a page that draws its own 完成 bar (0091) gets only one', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        const LoopFocusPage(
          archetype: LoopPageArchetype.action,
          title: '测试专用',
          keyboardAccessory: true,
          body: <Widget>[
            TextField(
              key: ValueKey<String>('field'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      );
      await tester.tap(_key('field'));
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(_key('loop-keyboard-done-bar'), findsOneWidget);
      expect(_key('loop-keyboard-scope-bar'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

class _FakeContext extends Fake implements BuildContext {}
