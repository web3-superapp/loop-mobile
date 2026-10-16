# 0145 · MEME v2 毕业态外盘页内买卖：官方池报价、准备与两步签名（S146-mobile）

## Status

Accepted 2026-10-11。主代理下单（S146-mobile），基线 `integration/v2` 04cf716，分支 `feat/S146-mobile`。
依据：loop-api S146-api（`feat/S146-pool-trade` a858bb6，loop-api 决策 0124）提交的 `openapi/loop-api.v2.json`——
`GET /v2/launch2/instances/{instanceId}/pool/quote`、`POST …/pool/trade/prepare`、实例详情 `instance.pool`；
本仓决策 0139（曲线面板与签名出口）、0142；验收记录 `docs/acceptance/2026-10-10-s136-emulator.md` 观察项 5
（需求方 10-10 裁决：「去外盘交易」改为页内直接买卖）。不新增依赖，`pubspec.lock`、路由清单、视觉 token 不变。

## Context

毕业态项目页的唯一动作是底栏「去外盘交易」，外跳到钱包兑换并预填代币。需求方要求和内盘一样在项目页里买卖。
loop-api 0124 给出了官方池（Uniswap v4 + OfficialTaxHook）的报价与准备两条路由，形状镜像曲线侧，交易发往
服务端校验过代码哈希的 OfficialPoolRouter；准备结果仍是 `launch2Intent`（`kind: pool_buy | pool_sell`），
外加构造它所用的 `quote`。Development 还没有这两条路由，本批 fixture 全部按合同手写（`_handwritten` 注明来源）。

## Decision

### 1. 页面（`launch2_instance_screen.dart`，只动毕业分支）

- `graduated` 的内容区：官方池卡（原样）→ **官方池读数**（`Launch2PoolStats`：外盘最新价、成交笔数「N 笔 · 买 a / 卖 b」、
  24 小时成交额、最近成交时间；`pool` 缺省时一行「官方池成交还在同步」）→ **外盘交易面板**（`Launch2PoolTradePanel`）→
  一行次要链接「也可以在钱包兑换里交易」（Key 仍是 `launch2-go-swap`，预填与原来相同）→ 回购卡（原样）。
- 底栏「去外盘交易」删除（`_bottomBar` 的 `graduated` 返回 `null`）。其他阶段的分支结构不动。
- 毕业态也预读当前钱包（与 NFT 发售、内盘同一处），签名出口要拿它对比交易的 `from`。

### 2. 外盘交易面板（`launch2_pool_trade_panel.dart` + `launch2_pool_view_model.dart`）

- 布局与曲线面板一致：标题「外盘交易」+「官方池」徽标 + 右侧「外盘税 2%」；买入 / 卖出分段；**金额口径**两个小分段
  （买：按支付 / 按买入数量；卖：按卖出数量 / 按到手），对应 `mode = exactIn | exactOut`，默认 exactIn；
  单个金额输入框（标签与单位随口径变：支付（含税）USD1、想买入 $T、卖出 $T、想到手 USD1）；报价区；滑点上限
  0.5% / 1% / 3% / 自定义（0.01–50%，两位小数，默认 1%）；确认键贴在键盘上方。
- 报价：输入、口径、方向、滑点任一变化即丢弃旧报价，350 ms 防抖后请求 `pool/quote`（`walletId` 必带、`slippageBps` 必带）；
  `expiresAt` 到期静默重报。报价行：exactIn「预计获得 / 最少获得」（卖：预计到手 / 最少到手），exactOut「预计支付 / 最多支付」
  （卖：预计卖出 / 最多卖出）；「外盘税 2%」按 `taxToken` 显示——**买入的税是 MEME（从到手里扣），卖出的税是 USD1**（**0197 修订**：LoopDynamic S209 Hook 的买入税改从付出的 USD1 扣，`taxToken = usd1`，以报价 `dynamic.baseTaxToken` 为准；OfficialTax 不变）；成交均价；
  滑点上限；来源行「官方池路由 · 按区块 N 计算，已扣 2% 外盘税」。
- 持仓：合同里只有报价带钱包余额（`balance.usd1 / meme`），详情和 `me/positions` 都没有毕业后的钱包余额。所以报价后显示
  「持有 X $T · 可卖 X $T」（取报价块上的 MEME 余额）；报价前若 `viewer.curve.net > 0` 只说「内盘净买入 X $T · 钱包余额报价后显示」，
  不把内盘净额当余额。卖出按卖出数量（exactIn）时出现 MAX，填入可卖。
- 拦截（面板灰度 + 一行原因，不发请求）：非毕业态、`graduation` 缺、`pool.router == null`（「外盘交易暂未开放（路由未配置）」）、
  无钱包；卖出数量超过可卖（不请求报价）；`exceedsBalance`（「USD1 余额不足：最多需要 …，钱包有 …」，确认键关闭）；
  自己的上一笔还在确认中（确认键「上一笔确认中…」）。
- 失败：报价失败留在面板一行「没有取到报价 · 原因」，准备失败一行原因；不进错误页、不弹 toast。中文原因：
  `POOL_QUOTE_UNAVAILABLE` 官方池试算没有通过，换个金额再试；`POOL_NOT_GRADUATED` 项目还没有毕业，官方池尚未开放；
  `POOL_INSUFFICIENT_LIQUIDITY` 官方池流动性不足；`POOL_QUOTE_ZERO` 这个金额太小，换算后为 0；`POOL_ROUTER_*` / `POOL_KEY_MISMATCH`
  外盘交易暂时关闭，平台正在核对官方池；余额不足两条注明「没有发起任何交易」；其余落到曲线目录（0139）。
- 准备：`POST …/pool/trade/prepare` 带报价的 `requestedAmount`、`mode`、`slippageBps`（服务端在同一块重报后构造）；
  签名出口显示的是 **intent 自己的数字**，不是面板上的报价。

### 3. 签名出口（`launch2_signing.dart`）

- 仍是同一个 `showLaunch2SignSheet` / `Launch2IntentSigner`：`approval` 非空先签授权（nonce N）再签交易（N+1），两笔都以
  `SigningIntent.backendCanonical` 交钱包、带服务端 `payloadDigest`。
- `Launch2Intent` 加 `venue`（`curve | officialPool`）、`taxBps`、`taxMeme`：标题「确认外盘买入 / 卖出」，操作「在官方池买入 $T」，
  税行「外盘税 2%」（买入显示 MEME 数量），授权行「… 给官方池路由」，合约行改名「路由」；买入「最多支付」不再写「含税」。
  曲线 intent 默认 `venue = curve`，字段与 0139 逐字相同。
- **两步进度**：intent 带授权时，抽屉上方加一条「1 授权 → 2 买入 / 卖出」步骤条（待签名 / 请在钱包确认 / 已广播 / 未完成 /
  结果未知），`sign()` 新增 `onStep` 回调驱动。曲线与 NFT 带授权时同样显示（行为不变，只是多了进度）。
- 广播后页内一行「已广播…广播不代表已成交」，锁住下一次签名，详情按交易轮询间隔重读。

### 4. 模型与 codec

- 新文件 `launch2_pool_models.dart`：`Launch2PoolMode`、`Launch2PoolTaxToken`、`Launch2PoolSummary`、`Launch2PoolQuote`、
  `Launch2PoolPrepared`。`Launch2InstanceDetail.pool`（可空）。
- `loop_v2_launch2_pool_codec.dart`：报价严格 29 键（`poolKey` 五键、`balance` 两键、`basis` 两键）；必须与所问的
  instance / wallet / side / mode 一致，`venue = official_pool`、`stage = graduated`，`taxToken` 必须是输出侧（买 meme、卖 usd1），
  `maxIn ≥ amountIn`、`minOut ≤ expectedOut`，否则 invalid。准备严格三键（`launch2Intent / quote / contractVersion`），intent 的
  `kind` 只认 `pool_buy / pool_sell`（并映射为 buy / sell + `officialPool`），`contractAddress` 必须等于报价的 `router`；授权的
  spender 必须是同一地址（沿用 0139 的 `payloadMatchesReview`）。曲线路由收到 `pool_*` 即 invalid。
- 详情 `pool` 是 OpenAPI 里的**可选键**（服务端说总会给）：用 `strictMapWithOptional` 读，缺省 = `null`，存在时严格 12 键。
  本包读未升级的后端（没有 `pool`）照常；反过来老包读新后端会判 invalid，见 Consequences。
- 传输（`loop_v2_launch2_api.dart`）：报价错误目录与准备错误目录照 OpenAPI 单列（两者 409 都含 `VERSION_CONFLICT`，曲线目录不动）；
  准备的幂等签名 = `launch2:pool:{instance}:{wallet}:{side}:{mode}:{amount}:{slippage}`。

## 与下单描述的偏离

- 下单写「`taxBps:200` 的外盘税」——合同里买入的税从 MEME 到手扣（`taxUsd1 = 0`），所以面板与签名抽屉按 `taxToken` 显示
  MEME 或 USD1，而不是一律 USD1。
- 「我的持仓（`me/positions`）在毕业态显示 MEME 余额与可卖」：S146-api 没有给 positions（也没有给详情 viewer）加钱包余额，
  `curve.net` 只是内盘买卖净额（毕业后的转账与外盘成交都不计）。本批只在面板里用报价块上的余额显示持有 / 可卖；钱包资产里的
  v2 行保持「v2 内盘持仓」原义，不改成余额。见未决 1。
- 「去外盘交易」降级为次要文字链接，没有删掉——钱包兑换能走别的路由与滑点，保留作为退路。

## Consequences

- **部署顺序**：老包读新后端的详情会因多出 `pool` 键判 invalid（老 codec 严格键集）；本包读老后端（无 `pool`）正常。
  所以本包必须先于（或同时于）loop-api 0124 上线，或后端在老包淘汰前不下发 `pool`——需主代理与后端对齐。
- 广播后的「已确认」判定：读模型没有按钱包的外盘数字，页面用「`viewer` 曲线数字或 `pool.tradeCount` 变化」作为信号，
  外盘交易时文案写「官方池已记录新成交，你的外盘买入应已确认；数量以钱包余额为准」。任何人的一笔外盘成交（包括回购）
  都会触发这句，是已知的弱信号；超时（36 次轮询）仍走 0139 的「还没有读到确认」。
- 新增 fixture `test/fixtures/s146-launch2-pool/`（七份：买 exactIn 报价、卖 exactOut 报价、买入带授权准备、卖出已授权准备、
  422 `POOL_QUOTE_UNAVAILABLE`、422 `POOL_NOT_GRADUATED`、503 `POOL_ROUTER_NOT_CONFIGURED`）；`test/support/launch2_fixtures.dart`
  加 `l2PoolSummaryJson` 与 `l2DetailJson(pool:)`。Development 升到 0124 后需实抓替换。
- 测试：`test/s146_launch2_pool_trade_test.dart`（codec 严格性、传输路径 / 查询 / body / 幂等键 / 错误原因、视图模型各态、
  签名字段、页面：读数、灰态、加载→报价→两步签名、确认信号、报价 / 准备失败、离线、卖出 exactOut + 自定义滑点、44pt 触控）；
  `s136` 的假网关补两个方法。

## 未决项（需后端 / 主代理决策）

1. 毕业后的「我的持仓」需要钱包 MEME 余额：建议 loop-api 在 `me/positions` 或详情 `viewer` 加 `memeBalance`（链上读，带区块），
   否则只能在报价后显示。
2. 广播后的成交确认：建议详情 `viewer` 加按钱包的外盘计数或最近一笔外盘成交哈希，替代 `pool.tradeCount` 弱信号。
3. 老包兼容：后端下发 `pool` 会让 0145 之前的包把毕业详情判 invalid（见 Consequences）。
4. 合同文档 `docs/frontend-v2-launch2-api.md` 尚无 §pool（OpenAPI 描述里引用了它）；本批以 OpenAPI 为准。
5. 授权额度：服务端给的是「只够这一笔」的精确授权（exactOut 为 `maxIn`）；是否允许用户选择无限授权以省 gas 是产品问题，本批不做。
