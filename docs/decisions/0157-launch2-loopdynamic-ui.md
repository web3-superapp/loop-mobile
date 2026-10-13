# 0157 · MEME v2 外盘 Hook 种类 LoopDynamic：能力判断后的面板、本轮状态卡与外盘奖励页（S168-mobile）

## Status

Accepted 2026-10-13。主代理下单（S168-mobile），基线 `integration/v2` 95030ef，分支 `feat/S168-loopdynamic-ui`。
依据：`LOOP/docs/26-需求方loop_hook_v1评审-2026-10-13.md` §五 App 改动清单；loop-contracts S164 决策 0009（LoopHook 作为可选
外盘 Hook 种类）；主代理下发的 loop-api S166 接口草案（开工与收尾时 S166 均未发布 `frontend-v2-launch2-api.md` 新节，
其 worktree 里未提交的 `migrations/000076_launch2_loop_dynamic.ts` 作为字段形状的旁证，见「与草案的差异」）；主代理补充裁决
（S165 合约定稿：LoopDynamic 买入同样收 2%，从到手 MEME 扣）。本仓决策 0145（外盘面板）、0148（两步签名刷新）、0153（失败跟按钮）。
不新增依赖，`pubspec.lock` 不变，视觉 token 不变；路由清单 111 → 112。

## Context

需求方要把外盘 Hook 从 OfficialTaxHook（买卖各 2%）换成可选的 LoopHook：卖出加动态税、5 分钟跌超 10% 开一轮、
本轮内的买入按 USD1 记权、本轮结束后按权分奖金池。合约把它做成每个项目可选的种类，默认仍是 OfficialTax。
App 必须在不知道种类时保持现状：现有毕业页在 OfficialTax 下一像素不变，旧包不会调到任何新路由。

## Decision

### 1. 种类来自一条独立读（端口 `Launch2DynamicPoolGateway`）

- 新端口 `launch2_dynamic_pool_gateway.dart`：`loadPoolKind` / `loadRewards` / `prepareClaim` / `reportClaim`；生产默认
  `UnavailableLaunch2DynamicPoolGateway`，`lib/main.dart` 挂 `loopV2Launch2DynamicPoolGatewayProvider`（缺 Dio / 元数据 / 会话仍不可用）。
- 传输 `GET /v2/launch2/instances/{id}/dynamic-pool`：200 → `Launch2LoopDynamicPool(state)`；**404（不论 body）**与
  **503 `CAPABILITY_UNAVAILABLE`** → `Launch2OfficialTaxPool`；其余失败照常抛。控制器 `Launch2PoolKindController` 再把
  `unavailable` / `notFound` 也读成 OfficialTax。只有 `graduated` 才读；其它阶段不发请求。
- 页面规则：只有读到 LoopDynamic 才渲染任何新元素。没有适配器、OfficialTax、还没读到、读失败，一律画 S146 原面板
  （读失败时随页面刷新重读；OfficialTax 答案不再重读）。
- 模型（`launch2_dynamic_pool_models.dart`）：`currentDropWad` 为 `BigInt`（10^18 = 100%，`dropPercent` 精确 Decimal），
  金额 Decimal，轮次 / K 线 id 为 `BigInt`；`baseSellFeePpm` 整数。

### 2. 面板（`Launch2PoolTradePanel(dynamicPool:)`，`launch2PoolTradeView(dynamicPool:)`）

- `dynamicPool == null` 时代码路径与 0145 / 0153 完全相同（报价行、标题右侧「外盘税 2%」、输入方式、钱包兑换链接）。
- LoopDynamic：去掉「输入方式」与「按买入数量 / 按到手金额」（只 exactIn；若用户在答案到来前选了 exactOut，清空并回到 exactIn）；
  标题下一行「在 LOOP 里买入才保证记入奖励」；标题右侧「外盘税 2% + 卖出动态税」；
  买入报价行「外盘税 2%（扣 MEME）」+「本笔计入本轮奖励权重 Y USD1」（Y = 报价 `rewardWeight`；无值时激活中写「以成交为准」、未激活写「本轮未开启」）；
  卖出报价行「基础税 2% + 当前动态税 X%（扣 USD1）」（X = 报价 `dynamicTaxBps`；无值时标签「基础税 2% + 当前动态税（扣 USD1）」、值「成交后按跌幅计」）；
  来源行相应说明。两步签名、滑点、失败行跟按钮（0148 / 0153）全部复用。
- 「也可以在钱包兑换里交易」在 LoopDynamic 下不显示（钱包兑换可能走 Hook 不记权或不接受的路由）。
- 报价 codec：`dynamicTaxBps`（bps，可 null）与 `rewardWeight`（金额，可 null）作为**可选键**加入，其它未知键仍判无效。

### 3. 本轮状态卡（`Launch2DynamicRoundCard`，在官方池读数上方）

- 标题「本轮状态」+ 徽标「已激活 / 未激活」+ 右侧「我的奖励 ›」（44 dp，开 `/launch2/dynamic-rewards?id=`）。
- 激活：当前跌幅、奖金池 USD1、本轮我的权重（无账户权重写「暂无」）、结束条件「出现一根收绿的 5 分钟 K 线即结束」。
- 未激活：一行「价格 5 分钟内跌超 10% 将开启动态税与买入奖励」+ 奖金池。来源行「LoopHook · 时间」。

### 4. 外盘奖励页（新路由 `launch2-dynamic-rewards`）

- 路径 `/launch2/dynamic-rewards?id=<instanceId>`（manifest 不许路径参数，同 `launch2-instance` 用 `id` 查询参数）；
  archetype `index`、布局 `dashboard`；`launch2ReadsBlocked` 关闭时整页 block。
- 种类不是 LoopDynamic（含无适配器）→ 只一行「这个项目没有外盘奖励」，不读奖励。
- 五态：加载 / 空（「还没有外盘奖励」+ 说明）/ 错误 / 离线（`LoopChainStateBlock`）/ 权限；无效 id 不发请求。
- 每轮：「第 N 轮」+ 进行中 / 已结束；起止（`K 线 #a – #b`，不在设备上换算成时间）；我的权重 / 总权重；本轮奖金（未结束「本轮结束后结算」）；
  可领；已领；按钮「领取」只在已结束、未领、可领 > 0 时可按。
- 领取：`POST …/dynamic-pool/claim/prepare` → intent 必须是 `dynamic_claim`、无授权、`contractAddress` 等于状态的 `hookAddress`
  （否则在钱包前拒绝）→ 同一个 `showLaunch2SignSheet`（标题「确认领取外盘奖励」，字段「领取 X USD1」，大额验证按 `expectedOut`）→
  广播后 `POST …/claim/report` 上报 hash（失败只追加一句「上报没有成功…不要重复领取」）→ 该轮锁定「领取确认中…」，
  按交易轮询间隔重读奖励，读到已领后「外盘奖励已领取，已在链上确认。」；36 次未见则「还没有读到确认…不要重复领取」。
- 签名模型：`Launch2IntentKind.rewardClaim`（wire `dynamic_claim`）、`Launch2Venue.loopDynamicRewards`；曲线 / 官方池路由收到
  `dynamic_claim` 一律判无效。

### 5. 文案（`launch2DynamicReasonText`，并入 `launch2PoolReasonText` 之前）

`LAUNCH2_EXACT_OUT_UNSUPPORTED` 这个项目只支持按支付金额买入；`UNAUTHORIZED_ROUTER` 这个交易入口不被该项目接受；
`UNSUPPORTED_SWAP` 这个项目不支持这种交易方式；`BUSY` 池子正忙，几秒后再试；`ROUND_NOT_CLOSED` 本轮还没结束，结束后可领；
`ALREADY_CLAIMED` 这一轮已经领过。reasonCode 规则只收大写下划线，所以按大写形式匹配，允许 `LAUNCH2_` / `POOL_` / `HOOK_` /
`LOOP_HOOK_` / `LOOP_ROUTER_` 前缀，Solidity 原名也列上（不会过 codec，仅作兜底）。

### 6. 「我 → 挖矿奖励」底部入口：本批不做

条件「任一 loopDynamic 实例存在」没有数据源（没有跨实例的 LoopDynamic 列表或账户级奖励汇总），只放项目详情入口。

## 与 S166 草案的差异 / 待 S166 定稿核对

1. 意图 kind：草案未写；按 S166 未提交迁移 `launch2_intents.kind` 取 `dynamic_claim`。
2. `startCandle` / `endCandle`：按迁移是 K 线 id（numeric），客户端读十进制整数串，不当时间戳。
3. `allocation`：未结束时为 `null`（迁移 `allocation_usd1` 仅关闭后有值）。
4. `claimed`：草案未说是布尔还是金额；codec 两种都收（金额 > 0 视为已领），其它类型无效。迁移里的 `claimed_usd1` 是整轮合计，
   若接口把它原样当 `claimed` 下发则含义不对，需 S166 确认是「本账户」。
5. 整数字段（`currentRoundId`、`currentDropWad`、`roundId`、K 线 id）按仓库惯例读十进制字符串，不收 JSON number。
6. `contractVersion`：草案根对象没有；可选，出现时必须 `2.0`。
7. `routingPolicy`：只当不透明字符串（`^[A-Za-z][A-Za-z0-9_]{0,63}$`），不据此改 UI。
8. `dynamic-pool` 读不带 `walletId`（`myBuyWeight` 按发起账户）。
9. exactOut 拒绝：假定为 `422 VALIDATION_FAILED` + `detailsSafe.reasonCode = LAUNCH2_EXACT_OUT_UNSUPPORTED`；若改成顶层 code，需加入错误目录。
10. 领取准备 / 上报：准备 201、`{launch2Intent, contractVersion}`，body `{walletId, roundId}`；上报 200、body
    `{walletId, roundId, intentId, transactionHash}`、响应 `{roundId, status: submitted|confirmed|failed}`——均为客户端自拟，需对齐。
11. 卖出报价 `taxAmount` 是否已含动态税、`expectedOut` 是否已扣动态税：来源行在 X 已知时写「动态税按当前跌幅计入」，需 S166 确认。

## Consequences

- 旧包不调 `dynamic-pool`，LoopDynamic 项目在旧包里显示的是 0145 面板（「外盘税 2%」、可选 exactOut）；exactOut 会被服务端 422 拒绝。
- 新包读旧后端：404 → OfficialTax，页面不变。
- harness：`launch2_dynamic_rewards_screen.dart` 进 `LAUNCH2_GATED_SURFACES`；`LAUNCH2_DYNAMIC_PORT` 校验默认 unavailable 与
  `main.dart` 挂载；路由清单 112。
- 测试：`test/s168_launch2_dynamic_pool_test.dart`（codec 严格性、传输 404 / 503 / 200 / 500、准备路径与幂等键、文案、视图模型、
  页面：无适配器 / OfficialTax 无新元素、未激活、激活跌 20%、激活回到开盘 0%、动态面板买卖报价、exactOut 拒绝、奖励页五态 / 列表 /
  领取签名与上报 / 拒绝与合约不符）；S146 / S136 页面测试不改。

## 未决项

1. S166 定稿后按上节逐条核对并替换手写样例。
2. 挖矿奖励页的「外盘奖励」入口需要账户级 LoopDynamic 汇总或实例列表的 `poolHookKind`。
3. 外部钱包 / 聚合器入口：本批只在 LoopDynamic 项目页隐藏「钱包兑换」链接；钱包 Swap 页本身不知道种类，若 `routingPolicy` 定为只认自家路由，需另行处理。
