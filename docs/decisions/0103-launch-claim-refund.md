# 0103 · Launch 领取与退款：详情页「我的份额」、三种 kind 的 Intent、settlements 记录

## Status

Proposed 2026-09-28。S92b，客户端单侧。基线 `integration/v2` e10a529。对应 loop-api 决策 0087
（S92a，dev 部署 `006f461`，`docs/frontend-v2-launch-api.md` §S92a）。93 条路由清单不变，没有新增路由、
没有新增依赖，`pubspec.lock` 不变。

## Context

认购线（0088 / 0089 / 0090 / 0099）已经能把 USD1 买进合约，但钱回不来：成功发售的代币要 `claim(saleId)`，
失败或取消的 USD1 要 `claimRefund(saleId)`。S92a 让 `POST /v2/launch/{id}/intents` 接受
`{kind: "claim" | "claimRefund", walletId}`，响应同一个 `launchIntent` 信封（多 `kind`、`claimableTokens` /
`refundableUsd1`，`roundId` / `roundIndex` 为 `null`），并在 history 上加可选 `settlements`。
原型（冻结版 93 页）里没有领取 / 退款界面。

## Decision

### 1 入口：`launch-detail` 的「我的份额」块，不新增路由

放在「我的资格」与「发射轨道」之间（原型无此块，属于新增，不改原型已有块的顺序）。按钮只由两份读数决定：
详情的四轴，与 `GET /v2/launch/{id}/holders` 的 `myPosition`（详情响应没有持仓）。判定表
（`launchSettlementView`，最终以 prepare 的回答为准）：

| 四轴 | 持仓 | 显示 |
| --- | --- | --- |
| 四轴不可读 / SCHEDULED / LIVE | 任意 | 不画（认购页负责） |
| ENDED | 任意（含读不到） | 「等待最终化」说明 |
| 其余 | 读取中 | 「正在读取我的份额」，无按钮 |
| 其余 | `unavailable` / 读失败 | 「我的份额暂时读不到」+ 服务端原因，无按钮 |
| 其余 | 七个数字全为 0（没参与） | 不画 |
| VESTING / COMPLETED | `claimableTokens > 0` | 主按钮「领取 X 代币」 |
| VESTING | 可领 0、已领 0 | 「暂无可领取」行（份额 X，成熟后可领） |
| VESTING | 可领 0、已领 > 0 | 「已领取 X 代币」行，徽标「已领取」 |
| COMPLETED | 可领 0、已领 > 0 | 「已全部领取」行，徽标「已完成」 |
| SUCCEEDED + NONE / FROZEN | 参与过 | 「等待 TGE」说明 |
| FAILED / CANCELLED + REFUNDING | `refundableUsd1 > 0` | 主按钮「申请退款 X USD1」 |
| FAILED / CANCELLED + REFUNDING / REFUNDED | 可退 0、已退 > 0 | 「已全部退款」行，徽标「已完成」 |
| FAILED / CANCELLED + REFUNDED | `refundableUsd1 > 0` | 「退款窗口已关闭」说明，无按钮 |
| FAILED / CANCELLED + 其他权益态 | 参与过 | 「退款准备中」说明 |
| 以上有按钮的行 + `PAUSED` | — | 按钮保留但禁用，说明「合约已暂停」 |
| 以上有按钮的行 + capability 关门或 evidence 未 confirmed | — | 按钮禁用，写服务端原因 |

COMPLETED 仍可领取（06 §4.1：释放全部到期后仍可领取未领完的部分）。退款同时看 `saleState ∈ {FAILED,
CANCELLED}` 与 `entitlementState == REFUNDING`（S92a.1；只看 saleState 会在窗口关闭后引导用户做一笔必然被拒的
请求）。

「发射轨道」END 条：权益轴 VESTING / COMPLETED / REFUNDING 时徽标分别为「领取中 / 已完成 / 退款中」，说明句换成
对应的一句（`launchTrackEndBadge` / `launchTrackEndDetail`），其余沿用毕业投影或「待触发」。纵向回退列表同样。

### 2 意向线：与认购同一套出口

点击 → `loopRefreshCapabilitiesBeforeSigning`（0099，按钮显示「正在核对可用性」）→ 关门则停 → `POST …/intents`
`{kind, walletId}`（`walletId` 取 `myPosition.walletId`，即服务端读持仓用的活跃钱包）→ 直接打开 Launch 签名单
（`showLaunchSignSheet`，与认购同一个组件与 `LaunchPurchaseSigner`：先查服务端可签、再查 payload 与复核一致、
再查链、最后交给钱包）→ 钱包返回 hash 即 `POST …/broadcast-report`（幂等键 `launch:report:<id>:<hash>`，
与认购相同）→ `submitted` 后每 5 秒 `GET …/intents/{id}`（S83b3.1），最多 72 次（6 分钟）；到
`confirmed / reverted / failed / expired` 停止，超时给「重新查询」。

- prepare 的幂等键签名 `launch:intent:<kind>:<launchId>:<walletId>`；服务端回答后释放，所以每次新动作都是新键；
  只有结果未决（离线 / 超时 / 解析失败）才重放同一个键。
- `IntentKind`：三种 kind 都用既有的 `IntentKind.launchPurchase`（「Launch 合约调用」这一类）。同一合约、同一
  链槽位，0090 的放行矩阵保持一条规则；没有新增 kind，签名器与 `chainIsPermitted` 不变。签名单标题按 kind
  （确认认购 / 确认领取 / 确认退款）。
- `payloadMatchesReview` 对领取 / 退款多一条：calldata 必须恰好是 `selector ‖ uint256 saleId`（`0x379607f5` /
  `0x5b7baf64`，74 个字符），`saleId` 在场时参数必须等于它；否则不交给钱包。
- `confirmed`、`expired`、`reverted` 后自动重读详情、holders 与 history（expired 可能晚到已成功，S92a.6）。
- 页面状态：`confirmed` →「已领取 / 已退款」；`reverted` →「交易失败（仅消耗 gas）」；`expired` →「未上链，
  可重新发起」；`failed` →「回报的交易不匹配」；其余 →「已广播，等待链上确认」。只有 `confirmed` 是结果。
  settled 之后按钮按新读数重新开放。

### 3 六个 409 的文案与按钮态

| reasonCode | 标题 | 下一步 |
| --- | --- | --- |
| `LAUNCH_CLAIM_NOT_OPEN` | 尚未开放领取 | 自动重读详情与持仓；开放后出现按钮 |
| `LAUNCH_REFUND_NOT_OPEN` | 当前不可退款 | 自动重读 |
| `LAUNCH_SALE_PAUSED` | 合约已暂停 | 自动重读；暂停读到后按钮带「合约已暂停」 |
| `LAUNCH_NOT_PARTICIPANT` | 这个钱包没有参与 | 隐藏按钮；提示切换钱包 |
| `LAUNCH_NOTHING_TO_CLAIM` | 暂无可领取 | 自动重读；下一次释放后再来 |
| `LAUNCH_NOTHING_TO_REFUND` | 已退款 | 自动重读 |

规则：拒绝记下当时读数的区块（详情快照块 / 持仓快照块）。只要页面还是这两个区块，服务端的回答优先，按钮禁用
（NOT_PARTICIPANT 隐藏）；重读拿到更新的区块后按新读数重新开放。`LAUNCH_CONFIG_VERSION_MISMATCH` 同样触发重读。
其他拒绝（503、403 对手方白名单、`LAUNCH_GAS_INSUFFICIENT`、422 非嵌入式钱包、幂等冲突）沿用
`launchPurchaseRefusalText`，把「认购」换成「领取 / 退款」、「支付钱包」换成「当前钱包」。

### 4 严格解码

- `launchIntent` 可选键加 `kind`、`claimableTokens`、`refundableUsd1`。缺 `kind` = buy（老响应逐字段不变）；
  `kind` 必须是 `buy | claim | claimRefund`（OpenAPI 枚举含 buy）。
- 形状按 kind 校验，任何一条不符整份作废：buy 不得带两个持仓数；claim / claimRefund 的 `roundId`、`roundIndex`
  必须为 `null`，`usd1Amount`、`minTokenAmount` 为 `"0"`，`eligibilityProof` 为空，不得带两个钱包上限；claim 必须带
  `claimableTokens` 且不带 `refundableUsd1`，`expectedTokenAmount` 等于 `claimableTokens`；claimRefund 反之，
  `expectedTokenAmount` 为 `"0"`。
- 回答必须对应请求：认购请求收到非 buy、领取请求收到退款，都作废。`GET` 读回必须是同一个 intent。
- 模型：`LaunchPurchaseIntent.roundId` / `roundIndex` 改为可空（只有认购带）；新增 `kind`、`claimableTokens`、
  `refundableUsd1`。类名保持不变以免牵动认购线。

### 5 记录：`settlements`

- history 根改为「必需键 + 可选 `settlements`」。`source` unavailable 时出现即作废（S92a.7：那时没有这个键）；
  `null` 作废；行按 OpenAPI 十二键严格解码，ID 与其他三组共用去重。缺席 = `null`（未知，不是「没有」）。
- 「我的参与记录」：有 settlements 时认购与结算合并成一组「认购与结算」，按区块号、log index、观察时间倒序；结算行
  标题「领取 X 代币 / 退回 X USD1」，徽标「已领取 / 已退款」（`reorged` 显示「已失效」），副行写累计、确认状态、区块与
  交易。缺席时页面与改前逐像素相同（「认购」组）。详情页「我的参与记录」行加「N 笔领取 / N 笔退款」计数（不计 reorged）。

### 6 守卫

`check_s7_truth_contract` 的门槛片段新增 `launch_settlement.dart`（VESTING / COMPLETED + 可领、REFUNDING + 可退）、
`launch_settlement_section.dart`（暂停、evidence、签前刷新、统一签名出口）与 `launch_chain_models.dart`
（calldata 选择器校验）；新文件列入必需文件清单。既有测试 `test_s7_trade_gate_must_read_the_four_axes` 自动覆盖
新片段。

## Tests

- `test/s92b_launch_claim_refund_decoder_test.dart`（42）：领取 / 退款 201 与请求体、kind 与请求不符、十三种畸形
  claim、三种畸形 refund、calldata 选择器 / saleId / 长度、旧 buy 响应（无 kind）与显式 buy、buy 带持仓数 / 空轮次、
  认购请求收到 claim、GET 读回与错 ID、六个 409 的 reasonCode 透传、settlements 缺席 / 在场 / 空数组 / unavailable
  带键 / 六种畸形。
- `test/s92b_launch_claim_refund_pages_test.dart`（40）：判定表 12 例（含 COMPLETED 可领、暂停、未参与、读不到）；
  领取全流程（准备 → 签名单文案 → 钱包拿到 `claim(7)` calldata → 回报 → 两次 GET → confirmed → 重读）；退款全流程与
  reverted；暂停、evidence 未 confirmed、已全部领取；六个 409 的标题、文案、自动重读与按钮态；更新区块后重新开放；
  ENDED 等待最终化、FROZEN 等待 TGE、LIVE 不画；持仓读取中 / 三种读失败 / unavailable；END 徽标与说明；settlements
  合并排序、徽标、缺席回归、详情行计数；签名文案按 kind。
- 改动的共享测试替身：`FakeLaunchGateway` 加 `prepareSettlementIntent`、`loadIntent`、`holdersSequence`。

## Consequences

1. 三种 kind 共用 `IntentKind.launchPurchase`。若希望签名审计里区分领取 / 退款，需要新增 kind 并同步 0090 的放行
   矩阵与 harness 的 S9 片段。
2. 认购线本身仍没有接 `GET …/intents/{id}` 轮询（0089 待办 3），本单只给领取 / 退款接了；是否给认购补上由主代理定。
3. 「我的份额」块是原型之外的新增块，位置与文案需要验收确认。
4. 按钮文案按任务单写「领取 X 代币」（不带 ticker）；签名单另有「代币」一行写 ticker。
5. 退款 / 领取的真机广播在 BSC 测试网上尚无证据（与 0090 相同的 go/no-go #6）。
