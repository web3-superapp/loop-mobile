# 0088 · Launch 解码器与页面按 `available` 分支渲染，launch-trade 接签名出口

## Status

Accepted 2026-09-25。S83c，客户端单侧。对应 loop-api 决策 0076（S83a，
`integration/v2` = `101ca4a`）与冻结的 S83b 形状。扩展决策 0058 与 0062，
不推翻其中任何一条；推翻的只有 0058 里「`launch-trade` 永不打开签名」这一句，
理由见下。93 条路由清单不变，没有新增路由。

## Context

S7 时合约不存在，`loop_v2_launch_api.dart` 把所有链上位置钉死：
`contractAddress` / `stateTupleDigest` / `snapshotBlock*` / 资格 `tier` /
`snapshotBlock` 为 `requireNull`，四轴只接受 `unavailable`，`reasonCode` 只接受
`LAUNCH_CONTRACT_BASELINE_PENDING`，`purchaseRecords/entitlements/refunds` 为
`requireEmptyList`，`POST …/intents` 没有成功响应。

S83a 把这些位置改成判别联合：旧对象原样作为 `unavailable` 分支（**字节不变**，
由 `test/fixtures/s83a-baseline/` 的 12 份文件锁定），旁边加 `available` 分支。
合约本身仍未部署，所以真机上所有 Launch 响应仍是 `unavailable` 分支。

## Decision

### 1 解码：先按判别字段选分支，再严格解码

| 槽位 | 判别 | `unavailable` 分支（与 S7 相同的键与严格性） | `available` 分支 |
| --- | --- | --- | --- |
| `launch.onChainState` | `source` | 四轴 `unavailable`、三个 `null`、`reasonCode` 非空 | `source: chain`，四轴取 06 §2 枚举，`stateTupleDigest` / `snapshotBlockHash` / `configVersion` 为 `0x`+64 hex，`snapshotBlockNumber` 十进制串，`reasonCode: null` |
| `launch.contractAddress` | 类型 | `null` | `0x`+40 位小写 hex |
| 详情 `config` | `status` | `pending_confirmation` / `confirmed`（LOOP 槽） | `available`（`getSaleConfig`） |
| 详情 `rounds[]` | `status` | LOOP 轮次槽 | `available`（`getRounds`） |
| 资格 `result` | 有无 `status` 键 | `{tier:null, reasonCode, snapshotBlock:null}` | `{status:available, tier|null, reasonCode|null, snapshotBlock, roundIndex, allowlistRoot, eligibilityProof[]}` |
| 持有人 `holders/myPosition/walletCap` | `status` | `unavailable` | `available`（06 `Position` 等） |
| 历史 `source` | `status` | `unavailable`，三个数组**仍必须为空** | `available`，数组按 OpenAPI 逐项严格解码 |
| `POST …/intents` | HTTP 状态 | `503`（七字段错误体） | `201 {launchIntent, contractVersion}` |

- 两个分支都拒绝未知键；分支内的每个字段仍按 OpenAPI 的 pattern / 范围校验。
- `reasonCode` 按主代理对 0076 的第 4 条裁决改为「任意 `^[A-Z][A-Z0-9_]{0,63}$`
  字符串」，不再钉字面量。这是 `unavailable` 分支唯一一处放宽，且只放宽到
  OpenAPI 已经写明的集合之外的同形字符串；未知码在页面上走通用文案。
- `roundIndex`（链上 `uint16` 序号）与 `roundId`（LOOP 的 opaque ID）分开保存；
  `available` 轮次的 `roundId` 可以为 `null`，这样的轮次在 `launch-trade` 不可选，
  因为 Intent 请求只收 opaque `roundId`。
- 金额一律保存为十进制整数字符串（18 位最小单位，06 §3「USD1 与项目代币都按
  18 位小数」），只在展示层用 `Decimal` 移位后交给 `loopFormatDecimal`。
  `bps / seconds / poolFeeTier / roundIndex` 是整数。
- 跨字段一致性，失败即整份响应作废（fail closed）：
  - `onChainState.source == chain` ⇔ `config.status == available` 且全部轮次为
    `available`，且 `contractAddress` 非空，且 `onChainState.configVersion ==
    config.configVersion`；
  - 轮次不得混用两种分支；`roundIndex` 不得重复；
  - Intent `201` 的 `launchId / walletId / roundId` 必须等于请求里的值，
    `unsignedTransaction.chainId` 必须等于 `launchIntent.chainId` 的 EIP-155
    编号，`to` 必须等于 `contractAddress`，`value` 恒为 `0x0`。
- `GET /v2/launch/economy` 在 OpenAPI 里**没有** `available` 分支（S83a 未给出链上
  计数），所以 `loop-economy` 本单不改；等后端给出形状后再加。
- `balances.launchChain.usd1`（S83b 可选字段）形状未冻结：`201` 根上出现
  `balances` 键时按「`usd1` 为 `{balance?, allowance?}` 十进制整数串」宽松读取，
  读不懂就当「未读取」，**不会**让整份 Intent 作废。这是本决策唯一一处宽松解码，
  理由是它只影响展示，不进签名 payload。

### 2 页面：四轴各自成行，组合投影只从四轴推导

- `launch-detail`：四轴各一行（标题是轴名、尾部是 06 §2 的线上值、副标题是该值的
  含义），下面一行快照区块与 `stateTupleDigest` 缩写。组合投影（例如「销售成功，
  流动性准备中」「已毕业，LP 已锁定」「已暂停 · 销售进行中」）由
  `launchStateProjection` 从四轴算出，不引入第五个状态；`operationalState=PAUSED`
  总是单独前缀。`unavailable` 时每行仍是 em dash 加服务端 `reasonCode` 的解释，
  底部 notice 改为读 `onChainState.reasonCode`（真机上仍是
  `LAUNCH_CONTRACT_BASELINE_PENDING`，文案与改前逐字相同）。
- `launch-rounds`：`available` 时从 `rounds[]` 渲染 `roundIndex`、时间窗（UTC）、
  单价、轮次上限、钱包上限、已募集、是否设名单（`allowlistRoot` 全 0 = 不设）；
  合约参数折叠区渲染 `getSaleConfig` 的 13 个值。
- `launch-graduation`：四步的状态**只**由 `liquidityState / entitlementState`
  推导（`launchGraduationStepProgress`）：退款分支（`REFUNDING/REFUNDED`）四步皆
  「不适用」；`PREPARING` 第 2 步进行中、`RETRY_SCHEDULED` 第 2 步重试已排期；
  `V3_LIVE` 第 3 步进行中；`LP_LOCKED/COMPLETED` 第 3 步完成，第 4 步在
  `entitlementState ∈ {VESTING, COMPLETED}` 时完成、否则进行中。线上 `steps[]`
  仍恒为 `pending`，解码不变。
- `launch-tier`：`available` 时标题是 tier（`null` = 不在名单），并显示快照区块、
  `roundIndex`、名单根是否为零、证明条数。
- `launch-holders` / `launch-history`：按各自 `available` 分支渲染；`available`
  且数组为空时才是真正的「没有记录」，并写明索引到的区块。
- `loop-stake` 不动，仍不可执行；`loop-economy` 见上。

### 3 launch-trade 接统一签名出口

- 主动作可用的条件：`launch` capability 可用且证据不在 pending，**并且**
  `onChainState` 为 `chain` 且 `saleState=LIVE`、`operationalState=ACTIVE`，
  并且选中了带 opaque `roundId` 的轮次、有支付钱包、金额合法。
- 提交走 `POST /v2/launch/{id}/intents`（一次逻辑操作一个幂等键，结果未知时重放）
  → `201 {launchIntent, contractVersion}` → 页面展示复核卡 → 「签名认购」打开
  `LaunchSignSheet`。复核卡与签名单的每一行都由同一个 `launchPurchaseFields`
  从 `launchIntent` 构造：支付 USD1、预计获得、最少获得、轮次、钱包已累计、
  有效期、`stateTupleDigest` 缩写、快照区块、合约地址、网络。
- 签名出口复用 `money_actions_signing.dart` 的类型与顺序（`MoneySignOutcome` /
  `MoneySignStatus` / `MoneySignLatch`，先查服务端可签、再查 payload 与复核一致、
  再查链、最后才交给 `WalletSigningGateway`），钱包收到的是
  `SigningIntent.backendCanonical(kind: IntentKind.launchPurchase, payloadDigest:
  launchIntent.payloadDigest, payload: DeviceTransactionPayload(transaction:
  unsignedTransaction 原样))`。`fromAddress` 取钱包目录里 `walletId` 对应的
  服务端地址，从不猜测。
- 钱包广播之后没有上报接口（S83a/S83b 未定义 launch intent 的 broadcast-report），
  所以结果一律是「已广播、结果未确认」并锁定：页面显示 hash，说明结果以链上索引为准、
  会出现在「我的参与记录」，不再允许第二次签名，从不显示成功。
- 4xx / 503 按 `detailsSafe.reasonCode` 分文案（`LaunchException` 新增可选
  `reasonCode`，由 adapter 从错误体的 `detailsSafe` 白名单读出）；没有文案的码
  （包括未知 `LAUNCH_*`）显示通用句子，**码本身放在句子下方的「错误代码」
  `LoopDisclosure` 里**——`check_user_visible_copy` 禁止把标识符插进中文句子，
  这是任务单「通用文案+码」在本仓库规则下的落法；没有码时按错误类别文案。
- 签名单复用共享的 `LoopSignSheet`，广播后进入它的 `complete` 态，标题区显示
  共享组件的「已完成」字样；正文明确写「广播不代表已成交」，页面锁定且从不写
  「成功」。若要换掉这两个字需要改共享组件，本单不动。
- 已知限制（不在本单修）：`privy_device_signer.dart` 在非主链上
  `privy_chain_switch_unsupported` 失败关闭（决策 0062），而 Launch 当前在
  `eip155:97`。所以即使后端返回 `201`，真机签名也会被钱包边界拒绝，页面如实显示
  「没有提交任何交易」。放开需要单独的设备证据与决策。

### 4 守卫

`scripts/check_harness.py::check_s7_truth_contract` 保留原型口径数字的禁令；
「Launch 面不得引用签名出口」改为「`lib/features/launch/` 下除
`launch_trade_screen.dart` 与 `launch_signing.dart` 之外的任何文件都不得引用
`showLoopSignSheet` / `LoopSignSheet` / `SigningIntent`」，并要求
`launch_trade_screen.dart` 的主动作读 `isPurchasable`。

## Consequences

- 合约未配置时，12 份 S83a 基线响应解码成功且与改前等价（`test/s83c_*`），
  所有页面的真机呈现不变。
- `available` 分支只在测试里出现，测试夹具标注「测试专用，按 OpenAPI 手写」；
  生产路径与 Preview 路径都没有 Launch 夹具（决策 0058 不变）。
- 待后端/主代理：Intent `201` 没有「本轮钱包上限」字段；`balances` 形状；
  launch intent 的广播上报接口；USD1 `approve` 的 Intent；Launch 测试网签名证据。
