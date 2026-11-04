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
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
String get loopTestnetChainLabel =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetChainLabel;

/// The badge text for the Launch testnet slot, switch on.
String get loopTestnetBadgeText => loopTestnetChainLabel;

/// The upper-case stamp on an asset hero, switch on.
const String loopTestnetStampText = 'BSC TESTNET';

/// The testnet explanation's title, switch on.
String get loopTestnetNoticeTitleText =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetNoticeTitleText;

/// The testnet explanation's body, switch on. [chainId] is the Launch
/// slot's CAIP id.
String loopTestnetNoticeBodyText(String chainId) =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetNoticeBodyText(chainId);

/// The wallet's Launch-chain block note (decision 0203), switch on.
String get loopTestnetWalletTotalNoteText =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetWalletTotalNoteText;

/// The label of the wallet (i) that opens the testnet explanation.
String get loopTestnetInfoButtonText =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetInfoButtonText;

/// The dismiss label of the testnet notice.
String get loopTestnetNoticeDismissText =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetNoticeDismissText;

/// The network-settings row for the Launch testnet, switch on.
String get loopTestnetNetworkRowTitle =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetNetworkRowTitle;

/// The network-settings row when no testnet is published, switch on.
String get loopTestnetNetworkRowAbsent =>
    LoopL10n.current.coreConfig_testHintsLoopTestnetNetworkRowAbsent;

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
