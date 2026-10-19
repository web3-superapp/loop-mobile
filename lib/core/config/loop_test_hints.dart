/// S237 · 决策 0204：测试相关提示的唯一开关与唯一文案来源。
///
/// 需求方 2026-10-19：「页面不要有测试相关提示」。凡是只在测试网 / 走查时
/// 才该被看到的字（测试网名、测试币符号、环境标签、测试网说明）都只在这个
/// 文件里出现，调用方只经下面的函数取值；开关关时它们返回中性写法或 `null`。
/// `test/s237_source_guard_test.dart` 扫描 `lib/` 的全部字符串字面量，只放
/// 过这个文件，以免以后再混进来。
library;

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';

bool? _debugOverride;

/// Whether test-only hints are drawn in this build.
///
/// Reads [LoopFeatureSwitches.testHintsVisible] (a `--dart-define`), unless a
/// test has set [debugSetLoopTestHintsVisible].
bool get loopTestHintsVisible =>
    _debugOverride ?? LoopFeatureSwitches.testHintsVisible;

/// Lets a test render both values of the switch. Pass `null` to return to
/// the build's value.
@visibleForTesting
void debugSetLoopTestHintsVisible(bool? value) => _debugOverride = value;

/// The Launch slot's network name while it is the BSC testnet, switch on.
const String loopTestnetChainLabel = 'BSC 测试网';

/// The badge text for the Launch testnet slot, switch on.
const String loopTestnetBadgeText = loopTestnetChainLabel;

/// The upper-case stamp on an asset hero, switch on.
const String loopTestnetStampText = 'BSC TESTNET';

/// The testnet explanation's title, switch on.
const String loopTestnetNoticeTitleText = 'Launch 当前运行在 BSC 测试网';

/// The testnet explanation's body, switch on. [chainId] is the Launch
/// slot's CAIP id.
String loopTestnetNoticeBodyText(String chainId) =>
    'Launch 目录、详情与签名单当前指向 BSC 测试网（$chainId），'
    '测试网上的代币没有真实价值。钱包余额、行情、兑换与授权仍然只走 BNB Smart Chain 主网，'
    '不受影响。这条说明可以关闭，不会阻断任何操作。';

/// The wallet's Launch-chain block note (decision 0203), switch on.
const String loopTestnetWalletTotalNoteText =
    'Launch 链是 BSC 测试网余额，不计入总资产；总资产只统计 BNB Smart Chain 主网。';

/// The label of the wallet (i) that opens the testnet explanation.
const String loopTestnetInfoButtonText = '关于 Launch 测试网';

/// The dismiss label of the testnet notice.
const String loopTestnetNoticeDismissText = '关闭测试网说明';

/// The network-settings row for the Launch testnet, switch on.
const String loopTestnetNetworkRowTitle = '测试网';

/// The network-settings row when no testnet is published, switch on.
const String loopTestnetNetworkRowAbsent = '没有已发布的测试网';

/// The Launch slot's native symbol as the server names it on the testnet.
const String loopTestnetNativeSymbol = 'tBNB';

/// The Launch slot's USD1 symbol on the testnet, as the faucet names it.
const String loopTestnetUsd1Symbol = 'tUSD1';

/// A token symbol as it is drawn: with the switch off the testnet prefix is
/// dropped (`tBNB` → `BNB`, `tUSD1` → `USD1`); with it on the symbol is
/// drawn as the server or the contract named it.
///
/// Display only: models, signing payloads and amounts keep the original.
String loopDisplaySymbol(String symbol) {
  if (loopTestHintsVisible) return symbol;
  return switch (symbol) {
    loopTestnetNativeSymbol => 'BNB',
    loopTestnetUsd1Symbol => 'USD1',
    _ => symbol,
  };
}

/// The Launch slot's native symbol for a sentence (fees, faucet, gas).
String get loopLaunchNativeSymbolText =>
    loopDisplaySymbol(loopTestnetNativeSymbol);

/// The Launch slot's USD1 symbol for a sentence.
String get loopLaunchUsd1SymbolText => loopDisplaySymbol(loopTestnetUsd1Symbol);
