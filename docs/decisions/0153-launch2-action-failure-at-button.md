# 0153 · MEME v2 项目页动作失败跟着按钮走、余额不足带数字与「去充值」（S155-mobile）

## Status

Accepted 2026-10-12。主代理下单（S155-mobile），基线 `integration/v2` be97915，分支 `feat/S155-action-failure-visibility`。
依据：需求方 2026-10-12 TestFlight 真机反馈（NFT 发售中点「购买 NFT」→ 确认抽屉 → `POST …/nft/prepare` 回
`409 INSUFFICIENT_BALANCE` / `LAUNCH2_USD1_BALANCE_INSUFFICIENT`，`detailsSafe.requiredUsd1 = "100"`，「不成功也没任何提示」）；
loop-api `src/features/launch2/launch2-service.ts` 的三处余额拒绝与 `detailsSafe` 形状（只读核对）。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变、签名出口与安全页不动。

## Context

`_buyNft` 失败时把 `_actionFailure` 设成「USD1 余额不足」，但它只渲染在正文 `_Identity` / `_StageBar` 之后（key
`launch2-action-failed`），按钮在固定底部栏。用户滚到下方按按钮时提示在视口上方，抽屉关掉、按钮恢复「购买 NFT」，看起来什么都没发生。
曲线与官方池两个交易面板的失败行虽在面板内按钮上方，但只是一行无语义的小字，不带数字，不给出路。
`LoopFailureDetails` 只白名单了 reasonCode / ceiling / daily / scope，launch2 的余额数字在边界处被丢掉。

## Decision

### 1. 失败提示在触发它的按钮紧上方

- 新共享件 `Launch2ActionFailureLine`（`launch2_widgets.dart`）：warn 图标 + 警示色 caption 正文，**不限行数**（不用单行省略的
  `LoopInlineUnavailable`，避免数字被截），外层 `Semantics(liveRegion: true)`；余额类拒绝下一行次要链接「去充值」+ chevron，44 dp 触控。
- NFT：`_BarShell` 加可选 `failure`，按钮上方 8 dp 一条（key `launch2-bar-failure`，链接 `launch2-bar-topup`）；正文那条
  `launch2-action-failed` 保留（单行）。已持有 / 正在准备时不显示；再次购买开始即清除（`_preparingNft` 期间「正在准备…」不变）。
- 曲线面板：原 `launch2-trade-prepare-failed` 小字改为该件（key 不变，链接 `launch2-trade-topup`），仍在「确认买入 / 卖出」上方。
- 官方池面板：原 `launch2-pool-prepare-failed` 小字改为该件（key 不变，链接 `launch2-pool-topup`）。
- `_actionFailure` 由 `String?` 改为 `Launch2ActionFailure?`（文字 + 是否给「去充值」）。

### 2. 文案带数字（`launch2ActionFailure`，`launch2_format.dart`）

- `LAUNCH2_USD1_BALANCE_INSUFFICIENT`：「USD1 余额不足：需要 X USD1，当前 Y USD1」。
  - 需要：服务端 `requiredUsd1`（NFT）或 `requiredAmountIn`（官方池），否则本次请求的金额（曲线：报价的 `amountIn`）。
  - 当前：官方池的 `maxAmountIn`（服务端即 `inputBalance`）；否则页面已在某块读到的余额（`viewer.holding.usd1Balance` 且
    `balancesRead`，仅毕业后有）。曲线的 `maxAmountIn` 是按余额限制的最大可付，写「最多可付 Y USD1」而非「当前」——
    尘额时服务端给 0，不把它说成余额。
  - 什么数字都没有：回落原句（曲线「USD1 余额不足」/ 官方池「USD1 余额不足，没有发起任何交易」）。
  - NFT 发售期服务端只给 `requiredUsd1`、页面没有余额读数，所以真机上是「USD1 余额不足：需要 100 USD1」（不编当前余额）。
- `LAUNCH2_MEME_BALANCE_INSUFFICIENT`：「卖出数量超过持有：需要 X $T，当前持有 Y $T」（官方池）/「最多可卖 Y $T」（曲线），不给「去充值」。
- `LAUNCH2_GAS_INSUFFICIENT`（服务端不带数字）：「tBNB 手续费不足：钱包里的 tBNB 不够付这笔的网络手续费，充值后再试」+「去充值」。
- 无 reasonCode 的 `insufficientBalance` 也给「去充值」；其余拒绝沿用各自目录原句，不给链接。

### 3. details 透传

- `LoopFailureDetails` 白名单加 `requiredUsd1` / `requiredAmountIn` / `maxAmountIn`（同一十进制正则，非字符串 / 负数 / 超长即丢该键，
  **不让整条响应判无效**，reasonCode 照留）；`LoopChainException` 加同名三字段；`loopChainExceptionForV2` 透传。

### 4. 「去充值」

- 复用 `receive`（`/wallet/receive`，`WalletRoute.receive(walletId)`）：当前激活钱包 id 规范时带 `walletId`，否则只开路径。不新建页面。

## Fixtures / 测试

- `test/s136_launch2_user_test.dart` 新组「0153 · a failed action is said at its button」：360 × 640 滚到底后 NFT 拒绝
  （`requiredUsd1: '100'`）→ 底部栏内文字「USD1 余额不足：需要 100 USD1」、在按钮上方 < 20 dp、在视口内、live region、
  「去充值」打开 `/wallet/receive?walletId=…`、再次购买成功后两条都清除；tBNB 文案与链接；非余额拒绝无链接；曲线买入
  （`maxAmountIn: '30'`）「需要 50 USD1，最多可付 30 USD1」+ 链接 + 成功后清除；文案单测；`detailsSafe` 透传与坏值丢弃单测。
  原「gas short」用例改为正文与栏内各一条（`findsNWidgets(2)`）。
- `test/s146_launch2_pool_trade_test.dart`：官方池 `requiredAmountIn: '100.5'` / `maxAmountIn: '20'` →「需要 100.5 USD1，当前 20 USD1」、
  live region、链接、在确认按钮上方；随后 tBNB 文案。

## Consequences

- 屏幕阅读器在提示出现时播报（liveRegion）；视觉用户无论滚到哪都在按钮上方看到原因。
- NFT 页正文与栏内同时可见时会出现两条同义提示（任务单允许保留正文那条）。

## 未决项

1. NFT 发售期没有 USD1 余额来源：要显示「当前 0 USD1」需 loop-api 在 `nft/prepare` 的拒绝 `detailsSafe` 里加 `balanceUsd1`
   （或 viewer 在发售期给余额）。客户端不推算。
2. tBNB 不足没有数字：若要「需要约 X tBNB」需后端在 `LAUNCH2_GAS_INSUFFICIENT` 带所需 / 现有 wei。
3. 曲线 `maxAmountIn` 语义是「余额限制下最大可付」，若后端确认等同余额可改写「当前」。
