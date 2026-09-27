import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0091 · the `launch-trade` keyboard, the 内盘持有人 row on
/// `launch-detail` and the staking entry on `launch-tier`.
///
/// Every value is 测试专用. The device facts behind it: an iPhone 14 Pro Max
/// (430 × 932 logical) whose decimal pad is about 336 logical pixels tall.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const Size _device = Size(430, 932);
const double _keyboard = 336;

bool _amountFocused(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: _key('launch-trade-amount'),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

Future<void> _pumpTrade(WidgetTester tester) => pumpS7Page(
  tester,
  LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow),
  size: _device,
  launch: FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(
      value: s83cDetail(chainId: loopLaunchTestnetChainId),
    ),
  ),
  // `usd1` absent: the allowance card reads 授权状态未读取, the case that
  // was under the keyboard on the device.
  wallet: FakeWalletDirectory(
    activeWalletId: s7WalletId,
    wallets: [s83cWallet()],
    balances: [s83cBalances(chainId: loopLaunchTestnetChainId, usd1: false)],
  ),
  meta: s7MetaSnapshot(launchEvidencePending: false),
);

/// Picks the round, types an amount and raises the keyboard.
Future<void> _typeWithKeyboard(WidgetTester tester) async {
  await scrollToS7Section(tester, _key('launch-round-1'));
  await tester.tap(_key('launch-round-1'));
  await tester.pumpAndSettle();
  await scrollToS7Section(tester, _key('launch-trade-amount'));
  await tester.enterText(_key('launch-trade-amount'), '500');
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester,
  S7Answer<LaunchHolders> holders,
) => pumpS7Page(
  tester,
  const LaunchDetailScreen(launchId: s7LaunchId),
  launch: FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(value: s83cDetail()),
    holders: holders,
  ),
);

String? _holdersSubtitle(WidgetTester tester) =>
    tester.widget<LoopRecordRow>(_key('launch-detail-open-holders')).subtitle;

LaunchHolders _holdersUnavailable(String reasonCode) => LaunchHolders(
  launchId: s7LaunchId,
  holders: LaunchReadingUnavailable<LaunchHolderCount>(
    LaunchUnavailable(reasonCode),
  ),
  myPosition: LaunchReadingUnavailable<LaunchPosition>(
    LaunchUnavailable(reasonCode),
  ),
  walletCap: LaunchReadingUnavailable<LaunchWalletCap>(
    LaunchUnavailable(reasonCode),
  ),
);

void main() {
  loopWatchGround();

  group('launch-trade · keyboard', () {
    testWidgets('a tap outside the amount puts the keyboard away', (
      tester,
    ) async {
      await _pumpTrade(tester);
      await _typeWithKeyboard(tester);
      expect(_amountFocused(tester), isTrue);

      // The caption under the amount is not interactive: the tap belongs to
      // the page, and the page puts the keyboard away.
      await tester.tap(_key('launch-trade-balance'));
      await tester.pumpAndSettle();
      expect(_amountFocused(tester), isFalse);
    });

    testWidgets('a tap on a row keeps the row, not the dismiss', (
      tester,
    ) async {
      var opened = 0;
      await pumpS7Page(
        tester,
        LaunchTradeScreen(
          launchId: s7LaunchId,
          clock: s83cNow,
          onOpenHolders: () => opened += 1,
        ),
        size: _device,
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(chainId: loopLaunchTestnetChainId),
          ),
        ),
        meta: s7MetaSnapshot(launchEvidencePending: false),
      );
      await tester.tap(_key('launch-trade-holders-action'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets(
      'with the keyboard up, 买入 sits on the 完成 bar and the reading stays in view',
      (tester) async {
        await _pumpTrade(tester);
        await _typeWithKeyboard(tester);
        final keyboardTop = _device.height - _keyboard;

        // The iOS accessory sits directly on the keyboard.
        final bar = tester.getRect(_key('loop-keyboard-done-bar'));
        expect(bar.bottom, moreOrLessEquals(keyboardTop));
        expect(bar.height, LoopKeyboardDoneBar.height);

        // The primary action is pinned right above it, never under it.
        final submit = tester.getRect(_key('launch-trade-submit'));
        expect(submit.bottom, lessThanOrEqualTo(bar.top));
        expect(submit.top, greaterThan(0));
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: _key('launch-trade-submit'),
          ),
          findsNothing,
        );

        // The folio folds away; the balance line and the 授权状态未读取 card
        // are inside the part of the body the keyboard left.
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        expect(viewport.bottom, lessThanOrEqualTo(submit.top));
        final balance = tester.getRect(_key('launch-trade-balance'));
        expect(balance.top, greaterThanOrEqualTo(viewport.top));
        expect(balance.bottom, lessThanOrEqualTo(viewport.bottom));
        final notice = tester.getRect(_key('launch-trade-allowance-notice'));
        expect(notice.top, greaterThanOrEqualTo(viewport.top));
        expect(notice.top, lessThan(viewport.bottom));
        expect(
          tester
              .widget<LoopNotice>(_key('launch-trade-allowance-notice'))
              .title,
          '授权状态未读取',
        );

        // 完成 puts the keyboard away.
        await tester.tap(_key('loop-keyboard-done'));
        await tester.pumpAndSettle();
        expect(_amountFocused(tester), isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'Android has its own done key: no accessory bar, action still pinned',
      (tester) async {
        await _pumpTrade(tester);
        await _typeWithKeyboard(tester);
        expect(_key('loop-keyboard-done-bar'), findsNothing);
        final field = tester.widget<TextField>(_key('launch-trade-amount'));
        expect(field.textInputAction, TextInputAction.done);
        final submit = tester.getRect(_key('launch-trade-submit'));
        expect(submit.bottom, lessThanOrEqualTo(_device.height - _keyboard));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('LoopFocusPage · keyboardAccessory', () {
    Future<void> pumpPage(WidgetTester tester, {required bool accessory}) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _device;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopFocusPage(
            archetype: LoopPageArchetype.action,
            title: '测试专用',
            keyboardAccessory: accessory,
            body: <Widget>[
              const TextField(key: ValueKey<String>('field')),
              const SizedBox(key: ValueKey<String>('blank'), height: 200),
            ],
            primaryAction: LoopButton(
              key: const ValueKey<String>('action'),
              label: '下一步',
              primary: true,
              block: true,
              onPressed: () {},
            ),
          ),
        ),
      );
    }

    bool focused(WidgetTester tester) => tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .hasFocus;

    testWidgets('only an opted-in page dismisses on a blank tap', (
      tester,
    ) async {
      await pumpPage(tester, accessory: false);
      await tester.tap(_key('field'));
      await tester.pump();
      await tester.tap(_key('blank'));
      await tester.pump();
      expect(focused(tester), isTrue);
      expect(_key('loop-page-keyboard-dismiss'), findsNothing);

      await pumpPage(tester, accessory: true);
      await tester.tap(_key('field'));
      await tester.pump();
      expect(focused(tester), isTrue);
      await tester.tap(_key('blank'));
      await tester.pump();
      expect(focused(tester), isFalse);
    });

    testWidgets('the 完成 bar appears only while the keyboard is up', (
      tester,
    ) async {
      await pumpPage(tester, accessory: true);
      expect(_key('loop-keyboard-done-bar'), findsNothing);
      await tester.tap(_key('field'));
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      expect(_key('loop-keyboard-done-bar'), findsOneWidget);
      expect(
        tester.getRect(_key('action')).bottom,
        lessThanOrEqualTo(tester.getRect(_key('loop-keyboard-done-bar')).top),
      );
      // 44 logical pixels: the touch target floor.
      expect(
        tester.getSize(_key('loop-keyboard-done')).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(_key('loop-keyboard-done'));
      await tester.pump();
      expect(focused(tester), isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('launch-detail · 内盘持有人 follows the holders branch', () {
    testWidgets('available · N 位参与者', (tester) async {
      await _pumpDetail(tester, S7Answer<LaunchHolders>(value: s83cHolders()));
      expect(_holdersSubtitle(tester), '1,842 位参与者');
      expect(find.textContaining('合约还没有上线'), findsNothing);
    });

    testWidgets('baseline pending · the only case that says 合约还没有上线', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        S7Answer<LaunchHolders>(
          value: _holdersUnavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
        ),
      );
      expect(_holdersSubtitle(tester), 'Launch 合约还没有上线，参与人数暂时不可用。');
    });

    for (final code in <String>[
      'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
      'LAUNCH_ONCHAIN_STATE_NOT_PROJECTED',
    ]) {
      testWidgets('$code · 链上记录索引中', (tester) async {
        await _pumpDetail(
          tester,
          S7Answer<LaunchHolders>(value: _holdersUnavailable(code)),
        );
        expect(_holdersSubtitle(tester), '链上记录索引中，参与人数稍后可见。');
      });
    }

    testWidgets('any other reason · 暂时读不到', (tester) async {
      await _pumpDetail(
        tester,
        S7Answer<LaunchHolders>(
          value: _holdersUnavailable('LAUNCH_CHAIN_RPC_UNREACHABLE'),
        ),
      );
      expect(_holdersSubtitle(tester), '参与人数暂时读不到');
    });

    testWidgets('a failed read · 暂时读不到, never 合约还没有上线', (tester) async {
      await _pumpDetail(
        tester,
        S7Answer<LaunchHolders>(failure: LaunchFailureKind.offline),
      );
      expect(_holdersSubtitle(tester), '参与人数暂时读不到');
    });

    testWidgets('a read in flight · 正在读取', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
          holders: S7Answer<LaunchHolders>(pending: true),
        ),
        settle: false,
      );
      await tester.pump();
      expect(_holdersSubtitle(tester), '正在读取参与人数');
    });
  });

  group('launch-tier · the staking entry', () {
    Future<void> pumpTier(WidgetTester tester, {required bool staking}) =>
        pumpS7Page(
          tester,
          const LaunchTierScreen(launchId: s7LaunchId),
          launch: FakeLaunchGateway(
            eligibility: S7Answer<LaunchEligibility>(
              value: s7Eligibility(
                mode: LaunchEligibilityMode.whitelist,
                dependsOnStaking: staking,
              ),
            ),
          ),
        );

    testWidgets('dependsOnStaking false · no 查看 LOOP 质押, one sentence', (
      tester,
    ) async {
      await pumpTier(tester, staking: false);
      expect(_key('launch-tier-open-stake'), findsNothing);
      expect(find.text('查看 LOOP 质押'), findsNothing);
      expect(_key('launch-tier-staking-independent'), findsOneWidget);
      expect(find.text('本次发射的资格不依赖 LOOP 质押'), findsOneWidget);
    });

    testWidgets('dependsOnStaking true · the primary entry stays', (
      tester,
    ) async {
      await pumpTier(tester, staking: true);
      expect(
        tester.widget<LoopButton>(_key('launch-tier-open-stake')).primary,
        isTrue,
      );
      expect(_key('launch-tier-staking-independent'), findsNothing);
    });
  });
}
