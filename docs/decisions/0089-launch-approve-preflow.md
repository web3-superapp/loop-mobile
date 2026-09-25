# 0089 · launch-trade 先授权 USD1，Intent 可选字段与广播上报

## Status

Accepted 2026-09-25。S83c2，客户端单侧。对应 loop-api 决策 0077（S83b，
`integration/v2` = `8d99260`，`openapi/loop-api.v2.json` 与
`docs/frontend-v2-launch-api.md` §S83b）。扩展决策 0088；推翻 0088 §1 里
「`balances.launchChain.usd1` 从 Intent `201` 根上宽松读取」这一条，以及 0088 §3
「Launch intent 没有上报接口」「签名单完成态显示共享组件的『已完成』」两句。
93 条路由清单不变，没有新增路由。

## Context

S83c 把 `launch-trade` 接上了签名出口，但 USD1 授权不足时只是在签名单里拒绝，
没有引导用户先授权；第一笔购买必然撞上。S83b 已合并部署：

- `POST /v2/wallet-intents/approve` 放行 **Launch 槽位上的 USD1 → Launch 合约** 这一对
  （`assetId = eip155:97:<LAUNCH_USD1_ADDRESS>`，spender = Launch 合约），其余资产 /
  spender / 链仍是 `422 CHAIN_MISMATCH`；钱包 Intent 的 `unsignedTransaction.chainId`
  放宽为 `56 | 97`。
- `GET /v2/wallets/{id}/balances` 的 `launchChain` 块新增可选
  `usd1: {balance, allowance}`，只在两者同块读到时出现，缺席时整个键不存在（不会是
  `null`）。它**不在** Intent `201` 里。
- `launchIntent` 新增可选键 `projectAssetId / saleId / walletRoundCapUsd1 /
  walletProjectCapUsd1 / transactionHash / simulation / policy / signing`，
  `unsignedTransaction` 新增可选 `from / gas / nonce / type / maxFeePerGas /
  maxPriorityFeePerGas / gasPrice`。
- 新增 `POST /v2/launch/{launchId}/intents/{launchIntentId}/broadcast-report`，形状同
  0035，`200` 返回同形 `{launchIntent, contractVersion}`（`submitted`）。
- 主代理对 0077 的第 7 条裁决：`holderCount` 是去重买家数，不是持币人数。

## Decision

### 1 授权额度只从 balances 读，严格解码

- `launchChain` 改用「必需键 + 可选 `usd1`」的严格映射；`usd1` 在场时必须恰好是
  `{balance, allowance}` 两个十进制整数串。`null`、只有一半、数字、多余键 → 整份响应
  作废（fail closed）。旧响应（无 `usd1`）解码结果与改前逐字段相同。
- Intent `201` 根上只接受 `{launchIntent, contractVersion}`；0088 为 `balances`
  开的宽松口子关闭，`balances` 键现在与其它未知键一样使 `201` 作废。
- 页面用 `walletBalancesControllerProvider(walletId)` 读支付钱包的 balances；
  `launchChain.chainId` 必须等于该 launch 的 `chainId`，否则视为「未读取」。

### 2 approve 前置流程

判断只用读到的事实，不猜：

| 读到的事实 | 主按钮 | 说明 |
| --- | --- | --- |
| balances 在读 | 「买入」禁用 | 「正在读取授权状态」 |
| 读失败 / 离线 / 无权限 / 无 `launchChain` / 链不符 / 无 `usd1` | 「买入」禁用 | 「授权状态未读取」+ 具体原因 +「重新读取」 |
| `allowance < 本次金额` | 「先授权 USD1」 | 当前授权、本次需要、「只按本次金额，不是无限额度」 |
| `allowance ≥ 本次金额` | 「买入」 | 进入 0088 的 prepare → 复核 → 签名 |

「先授权 USD1」：`POST /v2/wallet-intents/approve`，`walletId` = 支付钱包，
`assetId = <launch.chainId>:<getSaleConfig().usd1>`，`spenderAddress =
launch.contractAddress`，`allowance = {mode: exact, amount: 本次金额}` → 既有的
`showMoneySignSheet` + `MoneyActionSigner`（先查服务端可签、再查 payload 与复核一致、
再查链、最后交给钱包，广播后调钱包 Intent 的 `broadcast-report`）。

**授权额度 = 本次金额，不是无限额度。** 理由是红线里的最小暴露：无限授权让 Launch
合约在之后任何时候都能拉走钱包里全部 USD1，而本次购买只需要本次金额；多付出一次
授权签名的代价远小于长期敞口。`approve` 是覆盖写（不是累加），所以金额变大时再授权
一次即可。

授权后的状态（`LaunchApprovalController`）：

- 钱包 / 出口拒绝 → 「授权没有签名，没有提交任何交易」，可重新发起；
- 服务端拒绝准备 → 权限 / 策略类按 `moneyPolicyRefusalText` 说明规则，其余按类别文案；
- 已广播（`submitted` / `locked` / `reportRefused`）→ 轮询：立即读一次 balances（同时
  读一次该授权 Intent，`reverted` / `failed` 则显示「授权没有生效」并允许重新授权），
  之后每 3 秒一次、最多 40 次；`allowance ≥ 本次金额` 即结束，主按钮回到「买入」；
  窗口到期显示「授权额度还没有更新」+「重新读取」，**不**再提供第二次授权；
  轮询期间金额输入框与两个主按钮都禁用。

服务端三个 `409 INSUFFICIENT_BALANCE`（`detailsSafe.reasonCode`）各有独立文案并回到
对应引导：

- `LAUNCH_USD1_ALLOWANCE_INSUFFICIENT`：重读 balances，且服务端的回答优先——即使
  读数显示足够，主按钮仍是「先授权 USD1」，直到一次授权轮询完成（完成时清掉这条拒绝）；
- `LAUNCH_USD1_BALANCE_INSUFFICIENT`：「先补充 USD1」+ 读到的 USD1 余额 +「重新读取余额」；
- `LAUNCH_GAS_INSUFFICIENT`：「先补充网络费」+ 读到的 Launch 链原生币余额 +「重新读取余额」。

传输层修正：`POST …/intents` 与 `…/broadcast-report` 原来复用通用 `writeErrors`，
其中没有 `409 INSUFFICIENT_BALANCE`，真实的三个拒绝会被当成无法解析的回答
（`outcomeUnknown`，并重放幂等键）。现在这两条路由用 OpenAPI 为它们列出的错误目录
`launchIntentWriteErrors`，`INSUFFICIENT_BALANCE` 映射为新的
`LaunchFailureKind.insufficientBalance`（已知拒绝，释放幂等键）。

### 3 签名出口放行 Launch 槽位上的授权，且只放行它

- 钱包 Intent 解码：`send` / `swap` 仍钉主链；`approve` / `revoke` 可以是主链或
  `loopLaunchTestnetChainId`，此时 `unsignedTransaction.chainId` 必须等于该链编号，
  `review.asset.assetId` 必须以该链为前缀。
- `IntentKind` 新增 `launchApproval`；`MoneyActionSigner.toSigningIntent` 把非主链的
  approve / revoke 映射到它；`SigningIntent.chainIsPermitted` 只对 `launchPurchase` 与
  `launchApproval` 放行 Launch 槽位，`approval` 仍锁主链。
- 已知限制不变（0062 / 0088）：`privy_device_signer.dart` 在非主链
  `privy_chain_switch_unsupported` 失败关闭，所以真机上授权与购买都会停在钱包边界，
  页面如实显示「没有提交任何交易」。

### 4 `launchIntent` 可选字段

- 八个可选键按 OpenAPI 严格解码（`strictMapWithOptional`，在场即校验 pattern / 枚举 /
  子对象键集，任何其它键仍作废）。
- 签名前复核（页面与签名单共用 `launchPurchaseFields`）：保留「钱包已累计」
  （`walletCumulativeUsd1`），新增「本轮钱包上限」（`walletRoundCapUsd1`，缺席时写
  「未提供」）、「项目钱包上限」（在场时）、「模拟结果」（在场时）。
- `signing.allowed = false` 使 `canSignAt` 为假，拒绝文案优先用 `signing.reasonCode`
  （`LAUNCH_SIMULATION_REVERTED` / `LAUNCH_SIMULATION_UNAVAILABLE` 有独立文案）。
- `unsignedTransaction` 的七个可选键原样保存（在场 / 缺席、`null` / 值都保持），
  `toWire()` 按合约顺序输出，钱包拿到的就是服务端对象。`from` 在场且不等于支付钱包
  地址时，签名前拒绝（`LAUNCH_WALLET_ADDRESS_MISMATCH`）。

### 5 广播上报

- 钱包返回 hash 后立即 `POST …/broadcast-report`（幂等键签名
  `launch:report:<intentId>:<hash>`）。成功：状态为 `submitted`，页面显示
  「已广播 · 已提交，等待链上索引」与「广播不代表已成交」，从不写成功。
- 四个拒绝码各有文案，均说明「钱包已经广播、交易可能已上链、不要重复签名」：
  `LAUNCH_INTENT_ALREADY_REPORTED`、`LAUNCH_INTENT_NOT_SIGNABLE`、
  `LAUNCH_INTENT_EXPIRED`、`LAUNCH_TX_PAYLOAD_MISMATCH`。这四个是服务端对该 Intent
  的最终回答，不提供重报；其它失败（离线、503 等）提供「重新上报」，用同一个 hash。
- `LaunchIntentState` 九个值（含 OpenAPI 已有的 `reverted` / `expired`）都有中文标签，
  按服务端原样显示；只有 `confirmed` 表示索引已看到购买。`launch-history` 的记录仍按
  `purchaseRecords[].confirmationState`（`pending` / `confirmed` / `reorged`）显示。

### 6 文案

- `launch-holders`：「N 位持有人」→「N 位参与者」，说明「参与人数是在内盘买过的不同
  地址数，不是当前持币人数」。
- 共享 `LoopSignSheet` 的 `complete` 徽标「已完成」→「已广播」。它是共享组件，send /
  swap / approve 的完成态一并改为「已广播」；各自的副文案不变（Launch 仍是「广播不代表
  已成交」）。既有测试按新文案更新，没有删除。

### 7 守卫

`check_s7_truth_contract` 的门槛片段新增：`launch_trade_screen.dart` 必须以
`allowance.status == LaunchAllowanceStatus.sufficient` 放开购买；
`launch_approval.dart` 必须用 `LoopExactAllowanceRequest(amount)` 并从
`walletBalancesControllerProvider(walletId)` 读回额度。新文件列入必需文件清单。

## Consequences

- 合约未配置时一切照旧：没有 `usd1`，页面显示「授权状态未读取」，购买本来就因四轴
  不可用而关闭。
- `launchChain` 只在 Launch 槽位不同于主链时出现，所以 Launch 部署在主链时 `usd1`
  永远缺席、购买永远关闭——这是契约的结果，需要后端决定（见下）。
- 待后端 / 主代理：
  1. Launch 槽位等于主链时，USD1 余额与授权从哪里读（当前没有 `launchChain` 块）；
  2. 授权的轮询窗口（3 秒 × 40 次）是客户端常量，后端若有推荐的确认数 / 超时请给出；
  3. Launch Intent 没有 `GET`，`submitted → confirmed / expired` 只能靠
     `launch-history` 的索引看到，页面上的 Intent 状态停在上报时的回答；
  4. 真机签名仍受 0062 的链切换限制，需要单独的设备证据与决策。
