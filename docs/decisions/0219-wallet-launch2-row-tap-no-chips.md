# 0219 · 钱包 launch2 持仓行去 chip、整行进项目页（S263-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 54790037。需求方 10-21 走查截图。不新增路由、不新增依赖、`pubspec.lock` 不变。

## Context

钱包 →「代币」tab 的 Launch 链内盘持仓行（副标「Launch 链 · 内盘持仓」）在决策 0188（钱包 C）下多画一排「卖出 / 买入」安静 chip，
两者都只是进项目页。需求方原话：「这列表不要按钮 交易进到页面」。

## Decision

1. `launch2_wallet_rows.dart`：内盘持仓行不再画「卖出 / 买入」（key `launch2-wallet-sell-*` / `launch2-wallet-buy-*` 删除），
   行与 USD1 / BNB 行一样只有一行高度。已毕业 / 钱包余额行本来就没有 chip，保持不变。
2. 整行点击 → `Launch2Route.instance(instanceId)`（原 chip 同一路由，无 side 参数），`LoopQuoteRow` 的 InkWell 按下反馈不变。
3. `LoopQuoteRow` 的 `Semantics(excludeSemantics: true)` 会吞掉 InkWell 的 tap 动作；补 `onTap`，读屏可激活整行。
4. 原生代币与 ERC20 行的「发送 / 兑换」（`WalletRowActions`）不动。0188 中「内盘持仓带买入 / 卖出」一条由本决策取代。

## Tests

`test/s136_launch2_user_test.dart`：内盘持仓行无 chip、无「买入 / 卖出」文字，语义为 button 且带 tap，点击整行打开项目页一次。
