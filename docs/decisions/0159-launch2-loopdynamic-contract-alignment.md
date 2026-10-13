# 0159 · LoopDynamic 外盘 UI 数据层对齐 loop-api 定稿契约（S168b-mobile）

## Status

Accepted 2026-10-13。主代理下单（S168b-mobile），基线 `integration/v2` 7e41e2a，分支 `fix/S168b-dynamic-contract`。
修正决策 0157（S168 按 S166 草案自拟的字段与行为）。唯一依据：loop-api `docs/frontend-v2-launch2-api.md` §3.12
（含 §3.12.6 错误码与中文文案表）与 `openapi/loop-api.v2.json` 的 `/v2/launch2/instances/{id}/dynamic-pool*` 四条及
`pool/quote` 的 `quote.dynamic`。不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数（112）不变、视觉 token 不变；
新增请求只有 `…/rewards` 的 `walletId` 查询参数（契约必填）。

## Context

S168 开工时 S166 未发布契约，0157 按草案与未提交迁移自拟了字段名、类型、状态和错误码，并列出 11 条待核对项。
后端已定稿：`dynamic-pool` 对任何实例都回答 `hookKind`；金额是 18 位小数串而不是 wad 整数串；轮次用 `status`
四态；领取准备 / 上报有自己的响应形状；错误码统一 `LAUNCH2_DYNAMIC_*` 前缀并附中文表；卖出报价把动态税放进
`quote.dynamic`。App 侧照契约改，后端不动。

## Decision

### 1. 种类判断（`GET …/dynamic-pool`）

- 200 必须是 `{dynamicPool, contractVersion: "2.0"}`，`dynamicPool.instanceId` 必须等于所读实例。
- `hookKind: officialTax` 只能配 `status: not_applicable` → `Launch2OfficialTaxPool`，画 S146 原页面（不变）。
- `hookKind: loopDynamic` + `not_graduated` → `Launch2LoopDynamicNotGraduated`；+ `active` → `Launch2LoopDynamicPool(state)`。
  其余组合无效。
- `not_applicable` / `not_graduated` 时除 `instanceId`、`hookKind`、`status`、`candleSeconds` 外每个键都必须是 `null`；
  `active` 时只有 `currentRoundId`（未激活）与 `viewer`（无钱包）可为 `null`。`candleSeconds` 恒为 300。
- 404（任何 body）仍按 OfficialTax：只会来自没有这条路由的旧 API。
- 503 且 `detailsSafe.reasonCode` 是 LoopDynamic 专属（`LAUNCH2_DYNAMIC_ROUTER_NOT_CONFIGURED` /
  `_ROUTER_CODE_MISMATCH` / `_ROUTER_MANAGER_MISMATCH` / `_HOOK_NOT_INDEXED` / `_HOOK_MISMATCH` / `_HOOK_NOT_INITIALIZED`）
  → `Launch2LoopDynamicUnavailable(reasonCode)`；其余 503 照常抛出。
- 控制器：从未读到种类时，`unavailable` / `notFound` 仍按 OfficialTax（与 0157 相同）；**一旦读到过 LoopDynamic**，
  之后的 `unavailable` 变成 `Launch2LoopDynamicUnavailable`，其它失败保留上一次答案——永不退回 OfficialTax 面板（§3.12）。
- 毕业页遇 `LoopDynamicUnavailable` 或 `LoopDynamicNotGraduated`（详情已毕业、Hook 未读到）：在官方池读数下画
  「外盘暂不可用」结构化提示（原因按 §3.12.6 文案，未同步写「外盘池子正在同步，请稍后再试」）+「重试」按钮（44 dp），
  不画交易面板、不画钱包兑换链接。外盘奖励页同样。

### 2. 数值类型（全部按 openapi）

- 金额（`potUsd1`、`carryUsd1`、`roundExtraFeesUsd1`、`roundTotalBuyWeightUsd1`、`reservedRewardsUsd1`、`priceUsd1`、
  `viewer.currentRoundWeightUsd1`、`summary.*Usd1` / `buyFeesMeme`、轮次与领取的全部 `*Usd1`）：18 位小数串 → `Decimal`。
- `currentDropWad`：小数比例串（`"0.3"` = 30%），> 1 无效；卡片展示用 `currentDropBps`（整数 bps → `30%`）。
- id（`currentRoundId`、`candleId`、`roundId`、`startCandle`、`endCandle`、`blockNumber`）：十进制整数串 → `BigInt`。
- 计数与 bps（`roundCount`、`closedRoundCount`、`candleSeconds`、`buyTaxBps`、`baseSellTaxBps`、`currentDropBps`、
  报价 `baseTaxBps` / `dynamicTaxBps`）：JSON 整数，字符串无效。
- S168 字段 `hookAddress` / `pot` / `totalBuyWeight` / `myBuyWeight` / `baseSellFeePpm` / wad 整数 `currentDropWad` 全部删除。
- 新读入并保留：`router`、`routerRegistry`、`routingPolicy`（`loopRouterOnly` / `open` 枚举）、`priceTiming`、
  `excludeBuybackFromRewards`、`candleEndsAt`、`rollPending`、`summary`、`basis.blockNumber`。

### 3. 本轮状态卡

- 激活时：当前跌幅（`currentDropBps`；`rollPending` 时写「K 线已结束，待结算」）、奖金池 `potUsd1`、
  本轮我的权重（`viewer.currentRoundWeightUsd1`，有总权重时附「占 X%」= 它 / `roundTotalBuyWeightUsd1`；无 viewer 写「暂无」）、
  本根 K 线结束（`candleEndsAt`，本地 HH:mm）、结束条件。未激活：一行触发条件 + 奖金池。

### 4. 外盘奖励（`GET …/dynamic-pool/rewards?walletId=`）

- `walletId` 必填：取钱包目录的活跃钱包，否则详情 `viewer.walletId`；都没有时显示「还没有可用的钱包」，不发请求。
  控制器 family 键改为 `(instanceId, walletId)`。不传 `limit`（服务端默认 50）。
- 根对象 `{instanceId, walletId, hookKind, claimableUsd1, claimedUsd1, rounds, contractVersion}`，两个 id 必须回显；
  `officialTax` 必须 `rounds: []`；`rounds` ≤ 100，`roundId` 不重复。
- 轮次：`status` ∈ `open` / `claimable` / `claimed` / `no_reward`；`open` ⇔ `endCandle == null`，且 `open` 时
  `allocationUsd1` 必须为 `null`；`endCandle ≥ startCandle`；`weightUsd1 ≤ totalBuyWeightUsd1`；
  `claimedUsd1`（本钱包本轮已领金额）只在 `claimed` 时非空。按钮只在 `claimable` 且 `claimableUsd1 > 0` 时可按；
  `no_reward` 写「本轮无可领金额」。S168 的 `closed` / `claimed`（布尔或金额）/ `myWeight` / `totalWeight` / `allocation` / `claimable` 删除。

### 5. 领取准备（`POST …/claim/prepare`）

- 入参 `{walletId, roundId}`（roundId ≥ 1），期望 201，出参 `{launch2Intent, claim: {roundId, hook, claimableUsd1}, contractVersion}`。
- 端口返回 `Launch2DynamicClaimPrepared(intent, claim)`。codec 要求：kind `dynamic_claim`、无授权、实例与钱包一致、
  `claim.roundId` 等于所请求轮次、`intent.contractAddress == claim.hook`；页面再要求两者都等于 `dynamic-pool` 读到的 `hook`，
  否则在钱包前拒绝（`REVIEW_PAYLOAD_MISMATCH` 文案）。签名表单不变（「确认领取外盘奖励」、领取 = `expectedOut`）。

### 6. 领取上报（`POST …/claim/report`）

- 入参 `{intentId, transactionHash, walletId, roundId}`（后两个是契约里的可选回显，不一致服务端 404），期望 200。
- 出参 `{dynamicClaimReport: {intentId, instanceId, walletId, roundId, transactionHash, status, amountUsd1, claimedAt, blockNumber, reportedAt}, contractVersion}`；
  五个回显都要与本次上报一致；`status` 只收 `submitted` / `confirmed`（S168 的 `failed` 删除）；`confirmed` 必须带 `amountUsd1`。
- 页面：`submitted` → 提示「领取已提交（哈希），正在等待链上确认。不要重复领取。」，该轮按钮「领取确认中…」并按交易轮询间隔
  重读奖励直到该轮 `claimed`；`confirmed` → 立即「外盘奖励已领取，已在链上确认。」、按钮「已领取」、不再轮询。上报失败仍只追加一句不重复领取。
- 写入目录在池子准备的基础上加 `409 RESOURCE_CONFLICT`（`LAUNCH2_DYNAMIC_ALREADY_CLAIMED`、`_CLAIM_TRANSACTION_CONFLICT`）。

### 7. 错误码与文案

- `launch2DynamicReasonMessagesZh` 与 §3.12.6 表逐字一致（17 条），`launch2PoolReasonText` 先查它。
- 删除 S168 自造的前缀剥离与 `UNAUTHORIZED_ROUTER` / `UNSUPPORTED_SWAP` / `BUSY` / `ROUND_NOT_CLOSED` / `ALREADY_CLAIMED` 及 Solidity 原名匹配。
- `LAUNCH2_EXACT_OUT_UNSUPPORTED` 文案由「这个项目只支持按支付金额买入」改为契约的「该池子只支持按支付金额交易」。

### 8. 报价（`quote.dynamic`）

- 报价根对象只多一个可选键 `dynamic`（严格 10 键）；S168 的顶层 `dynamicTaxBps` / `rewardWeight` 作为未知键无效。
- `dynamic` 要求：`hookKind == loopDynamic`、`hook == poolKey.hooks`、`baseTaxBps == taxBps`、模式 exactIn；买入
  `dynamicTaxBps == 0` 且 `dynamicTaxAmount == 0`，卖出 `rewardWeight == 0`。
- 报价行按 `quote.dynamic` 是否存在切换（不再依赖页面的种类答案）。买入：「外盘税 2%（扣 MEME）」= `taxAmount`；激活时
  「本笔计入奖励权重」= `rewardWeight` USD1，未激活「奖励权重：当前未激活，不计奖励」。卖出：「基础税 2% + 当前动态税 X%（扣 USD1）」
  = `taxAmount`（基础 + 动态），X = `dynamic.dynamicTaxBps / 100`；下一行「其中动态税」= `dynamicTaxAmount`；预计到手即 `expectedOut`
  （已扣两种税）。来源行写「已扣基础税与动态税（按成交后 / 前跌幅模拟）」（按 `priceTiming`）。S168 的「成交后按跌幅计」占位删除。
- 卖出意图带 `dynamicTaxBps`（新可选字段），签名表单税行写「基础税 2% + 动态税 X%」，金额仍是意图的 `taxUsd1`。

### 9. 保留不变（已一致）

- exactOut 拒绝 422 `VALIDATION_FAILED / LAUNCH2_EXACT_OUT_UNSUPPORTED`；`contractVersion` 恒为 `2.0`；意图 kind `dynamic_claim`。

### 10. 测试样例

- 新目录 `test/fixtures/s168b-launch2-dynamic/` 15 个文件，按 §3.12 示例手写（省略号换成合法 id / 地址），每个文件
  `_handwritten` 注明「来源：frontend-v2-launch2-api.md §3.12 … 待真实抓包替换」；已用 openapi 响应 schema 逐个校验通过。
  `test/s168_launch2_dynamic_pool_test.dart` 全部改用这些样例。

### 11. 顺带：项目页「授权已广播」行（决策 0158 口径）

- `launch2_instance_screen.dart` 待处理行改用新函数 `launch2ApprovalOnlyText`：授权已发出后二次验证取消 / 失败写
  `loopStepUpAfterApprovalText`（「授权已发出，交易未发起。」），与 MEME / MEME v2 三处签名面板一致；其它停止原句不变。

## 0157「待 S166 确认」逐条结论

1. 意图 kind：定稿 `dynamic_claim`。**一致，保留。**
2. `startCandle` / `endCandle`：K 线 id，十进制整数串；`endCandle` 进行中为 `null`。**一致，保留**（仍不换算时间）。
3. `allocation`：定稿名 `allocationUsd1`，开轮时 `null`。**改名。**
4. `claimed`：定稿是 `claimedUsd1`（本钱包本轮已领金额，未领 `null`）+ `status`；不是布尔、不是整轮合计。**改为按 `status` 判定已领。**
5. 整数字段：id 是整数串（一致），但 `currentDropWad` 是小数比例串、计数 / bps 是 JSON 整数。**`currentDropWad` 改为 Decimal，展示改用 `currentDropBps`。**
6. `contractVersion`：四条路由根对象都**必带** `2.0`。**由可选改为必需。**
7. `routingPolicy`：枚举 `loopRouterOnly` / `open`，不是任意串。**改为枚举；仍不据此改 UI。**
8. `dynamic-pool` 的 `walletId`：可选（默认活跃钱包）；`rewards` 的 `walletId` **必填**。**`dynamic-pool` 仍不带，`rewards` 改为必带。**
9. exactOut：`422 VALIDATION_FAILED` + `detailsSafe.reasonCode = LAUNCH2_EXACT_OUT_UNSUPPORTED`。**一致；文案改为契约表。**
10. 领取准备 / 上报：准备 201 多一个 `claim` 对象；上报 body 必需只有 `intentId` / `transactionHash`（`walletId` / `roundId` 为可选回显），
    响应包在 `dynamicClaimReport` 里，`status` 无 `failed`。**按 §5、§6 重写。**
11. 卖出 `taxAmount` / `expectedOut`：`expectedOut` 已扣基础税与动态税，`taxAmount` = 两者之和，拆分在 `quote.dynamic`。**按 §8 重写行与来源。**
12. 0157 未决项 1（定稿后替换手写样例）：**已按契约重写手写样例；真实抓包仍待 staging 打开 LoopDynamic 开关后替换。**
    未决项 2（挖矿奖励页入口）与 3（钱包兑换 / 聚合器）：契约未提供账户级汇总，`routingPolicy` 已可读但本批不改钱包兑换，**维持未决。**

## Consequences

- 旧后端（无路由）仍 404 → OfficialTax；新后端对 OfficialTax 实例回答 `not_applicable`，页面同样不变。
- 能力隐藏测试（无适配器、OfficialTax）同步改用 `not_applicable` 样例；新增「外盘暂不可用」、`not_graduated`、控制器不回退三类测试。
- harness、路由清单、依赖不变。

## 未决项

1. 契约 503 的依赖类 reasonCode（`LAUNCH2_CHAIN_READ_FAILED` 等）不带 `hookKind`：首次读就失败时 App 无法区分实例种类，只能画 S146 面板
   （此时服务端 `pool/quote` 仍按实例真实种类报价，`quote.dynamic` 出现时报价行会按 LoopDynamic 显示，但「输入方式」仍可选 exactOut，
   会被 422 拒绝）。建议后端在该 503 的 `detailsSafe` 里带 `hookKind`，或在详情里给只读 `hookKind`。
2. `rewards` 无分页游标，超过 50 轮的旧轮次本页不显示。
3. 领取签名表单的金额取意图 `expectedOut`；契约未声明它与 `claim.claimableUsd1` 必须相等，codec 未强制。
