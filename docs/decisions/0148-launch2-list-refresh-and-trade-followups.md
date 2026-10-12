# 0148 · MEME v2 列表刷新、两步签名过期保护、毕业后持仓与成交确认、Meme 轨退出原因（S150-mobile）

## Status

Accepted 2026-10-11。主代理下单（S150-mobile），基线 `integration/v2` 91ab8b0（含 0144–0147），分支 `feat/S150-mobile`。
依据：主代理验收记录 `LOOP/docs/acceptance/2026-10-11-s142-emulator.md` §3cd40d5 观察项 1–3 与「观察项（续）」4；
本仓 0139（列表与签名出口）、0145（外盘交易面板）、0146（keeper 一行）；loop-api S150-api（决策 0126）在
`feat/S150-*` 提交 fada8be 的 `openapi/loop-api.v2.json`（见「与 OpenAPI 对齐」）。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变。

## Context

验收真实走了一次页内外盘买卖：买入签名抽屉的有效期离报价只有 60 s，Privy 两次弹窗偏紧；广播后用全池 `tradeCount`
判断「你的外盘买入应已确认」，任何人的一笔都会触发；报价前看不到钱包余额；v2 列表只在进入 / 下拉时读，停留期间
NFT 已售与阶段胶囊不变、从项目页返回也不重读；卖出摘要「先授权 2,000 $XXX 给官方池路由」折成两行右对齐；回购卡
「下一笔」（链上读数）与 keeper 行可能同时说暂缓（0146 未决 3）；挖矿奖励页 Meme 轨退出原因仍带「价格」。

## Decision

### 1. v2 列表刷新（调整 0139）

- `Launch2ListSegment` 改为有状态：**可见** = 所在路由在顶（`ModalRoute.isCurrentOf`）且所在 Tab 在台前
  （`TickerMode.valuesOf(context).enabled`，go_router 的 indexedStack 给非当前分支关 TickerMode）。可见期间每
  `Launch2Polling.listInterval`（60 s）重读一次第一页；不可见（被项目页盖住、切到别的 Tab、App 不在前台）不读；
  从不可见回到可见**立即**重读一次，然后重新起 60 s 节拍。下拉刷新照旧（`reload`，从第一页重来）。
- 轮询与返回重读走新的 `Launch2ListController.refresh()`：只读第一页，用 `Launch2InstancePage.refreshHead` 盖在已滚到的
  行上（第一页的行按新顺序在前，更深的行保留、游标保留；新第一页没有游标时整页替换），用户滚到第二页后不会被拉回。
  游标失效仍由 `loadMore` 的 400 → `reload` 兜底。已有读在途、或还没有第一次结果时，这一拍不发。
- 「观察于」随每次读更新（`valueObservedAt`）；来源行说明加一句「列表在屏幕上时每分钟刷新一次」。

### 2. 两步签名的过期保护（只接官方池，见「未做」）

- `Launch2IntentSigner.sign` 新增 `clock` / `refresh` / `onRefreshed`。授权广播之后、交易签名之前，若
  `intent.expiresAt − clock() < 20 s`（`launch2RefreshMargin`，含已过期），且调用方给了 `refresh`，就进入
  `Launch2SignStep.refreshing`：外盘面板提供的 `refresh` = 同参数**重报价**（`pool/quote`）+ **重新 prepare**
  （`pool/trade/prepare`，同 `requestedAmount / mode / slippageBps`；幂等键在上一次成功后已释放，是新的一笔 intent）。
- 新 intent 只有满足 `refreshRefusal` 全部条件才替换：同 kind / venue / 实例 / 钱包 / 链 / 路由；`approval == null`；
  `refusalBeforeWallet` 通过（未过期、摘要一致、`from` 是当前钱包）；**不比抽屉上确认的差**——`amountIn ≤` 原
  `amountIn`（最多支付 / 卖出）且 `minOut ≥` 原 `minOut`（最少获得 / 到手）。
- 新 intent 仍带授权（授权交易还没进块，服务端读到的额度不够）：间隔 3 s 再要，最多 4 次。
- 成功：抽屉事实行换成新 intent 的数字，步骤条下加一行 `launch2-sign-refreshed`「已刷新报价：原报价即将到期，已按最新区块
  重新报价，金额在你确认的范围内」，第 2 步签的是新 intent（`revision = 新 intentId`）。交给钱包的 `now` 改用当下时钟
  （原来用的是打开抽屉时的时间）。
- 失败一律**停在步骤 2**（授权「已广播」、交易「未完成」），不开第二次钱包，抽屉与页面同一句中文：
  「授权已广播。原报价即将到期，刷新时<原因>，买入没有签名，没有提交买入交易。稍后重新发起，授权足够时只需签一次。」
  原因：授权还在链上确认 / 最新报价超出了你确认的范围 / 没有取到新报价（<外盘目录中文>）/ 新的交易内容没有通过核对。
  客户端内部码 `LAUNCH2_REFRESH_APPROVAL_PENDING` / `_OUT_OF_RANGE` / `_FAILED`，不上屏。没有广播，不锁下一次。
- 与后端同时生效：S150-api 把 prepare 的 deadline / intent `expiresAt` 放到 prepare 时间 + 180 s，正常情况下授权后仍有
  余量、不触发刷新；本条是 60 s 旧后端与慢弹窗的兜底。

### 3. 毕业后的钱包余额（S150-api `memeBalance` / `usd1Balance`）

- 新模型 `Launch2WalletHolding`（`Launch2BalanceStatus` available / notGraduated / unavailable、`memeBalance`、
  `usd1Balance`、`reasonCode`、`blockNumber`、`poolTradeCount`、`lastPoolTradeAt`），挂在 `Launch2Viewer.holding` 与
  `Launch2Position.holding`；`null` = 旧后端没发这一组。
- 外盘面板「持有 X · 可卖 X」：**优先服务端余额**（`viewer.memeBalance`，报价前就显示，MAX 也用它），报价返回的
  `balance.meme` 作兜底；服务端读失败（`unavailable`）且还没报价时一行「钱包余额暂时读不到 · 报价后显示」；旧后端仍是
  「内盘净买入 X · 钱包余额报价后显示」。
- 钱包资产 v2 行（`Launch2WalletRows`）：`memeBalance` 读到时，代币行 = 钱包余额（副标题「钱包余额」，0 不画）；
  读不到或未毕业仍是 `curve.net` 的「v2 内盘持仓」行。`usd1Balance` 解析入模型，本批不单独上屏。

### 4. 成交确认信号（S150-api `viewer.poolTradeCount` / `lastPoolTradeAt`）

- `_viewerSignature`：viewer 有 holding 组时，外盘部分用 `own:<poolTradeCount>:<lastPoolTradeAt>`，**不再看全池
  `tradeCount`**（别人的成交、回购都不会触发）；旧后端退回 0145 的全池计数。
- 文案：自己的计数动了 →「你的外盘买入 / 卖出已在链上确认。」（确定语气）；旧后端的弱信号保留原句。
- 「我的外盘成交」（`GET …/pool/trades?walletId=&limit=5`）：viewer 的 `poolTradeCount > 0` 才读、才画，provider key
  含计数，计数一变自动重读；最近 5 笔一行一笔「买入 · 时间 | 7,333.18 $T · 付 5 USD1」/「卖出 · 时间 | 2,000 $T · 得
  1.3032 USD1」（路由口径，已扣 2% 税），标题右侧「共 N 笔」，来源行「LOOP 链上索引 · 只含经官方池路由成交的记录」；读失败
  一行 + 重试；列表空（索引未追上）一行「成交还在同步，稍后刷新」。位置：外盘交易面板之后、「也可以在钱包兑换里交易」之前。

### 5. Meme 轨退出原因（S150-api 决策 0126）

`miningExcludedReasonText`：新码 `MINING_ASSET_GRADUATED_BALANCE_PENDING`「已毕业，外盘持有数量还在同步」（数量口径
小时）；`MINING_ASSET_GRADUATED_UNREADABLE` 只留给重放的旧估值小时，「已毕业，外盘持有数量暂读不到」；
`MINING_ASSET_WEIGHT_NOT_CONFIGURED`「还没有配置挖矿权重」；未知码「暂不计入」（原来直接把码画上屏）。全部不含「价格」。

### 6. 小修

- 签名事实「先授权」只写金额（`2,000 $XXX` / `100 USD1`），不再「… 给官方池路由」；带授权时地址行的标签改为
  「授权给官方池路由 / 授权给曲线合约 / 授权给 NFT 合约」（无授权仍是「路由 / 合约」），谁被授权仍在抽屉上。曲线与 NFT 同步。
- 回购卡：链上读数的「下一笔」被拦（`nextOrderBlockedReason != null`）且 keeper 也是暂缓时，两行合成一行
  `launch2-buyback-held`（`launch2BuybackHeldLine`）：同一原因「下一笔暂缓：<原因>（链上读数、自动回购） · HH:mm 后再试」；
  不同原因「下一笔暂缓：<链上原因>（链上读数）；<keeper 原因>（自动回购） · HH:mm 后再试」。同类判断：去掉 `LAUNCH2_` 前缀
  比码，三个旧版价格保护码归为 `BUYBACK_LEGACY_PRICE_PROTECTION`。任一方不暂缓时各画各的（0146 不变）。

## 与 OpenAPI 对齐（S150-api fada8be `openapi/loop-api.v2.json`，2026-10-11）

| 位置 | 字段 | OpenAPI | 客户端 |
| --- | --- | --- | --- |
| 详情 `instance.viewer` | `memeBalance` / `usd1Balance` | 必填，decimal 或 null | 组可缺省（旧后端），出现则七键全在；`available` ⇔ 两个余额非空且有块高，否则两者为 null |
| 同上 | `balanceStatus` | 必填，`available / not_graduated / unavailable` | 枚举严格 |
| 同上 | `balanceReasonCode` | 必填，reasonCode 或 null | `available` 时必须 null |
| 同上 | `balanceBlockNumber` | 必填，uint 串或 null | `available` 时必须非空 |
| 同上 | `poolTradeCount` | 必填，uint 串 | 必填（组内） |
| 同上 | `lastPoolTradeAt` | 必填，date-time 或 null | 同 |
| `me/positions` 每行 | 同上七键 | 必填 | 同上（组可缺省） |
| `GET …/pool/trades` | query `walletId`（必填）、`limit`（`^[1-9][0-9]?$`，≤ 50，默认 20） | — | 固定 `limit=5`，客户端拒绝 1–50 以外 |
| 同上 200 | `instanceId, walletId, poolTradeCount, lastPoolTradeAt, trades[≤50], contractVersion` | 严格 | 严格，instance / wallet 必须是所问的 |
| 同上 trades[] | 16 键（`poolTradeId` … `blockNumber`） | 严格 | 严格；买 = usd1→meme 且税 meme，卖反之，否则 invalid；`recipientAddress` / `logIndex` 只校验不入模型 |
| 同上错误 | 400 / 401 / 404 / 409(`ACCOUNT_BOOTSTRAP_REQUIRED, DATA_STALE, VERSION_CONFLICT`) / 422 / 500 / 503 | — | 与 pool quote 同一目录 |
| `pool/quote` / `pool/trade/prepare` | `deadline` / `expiresAt` 说明改为 quote 60 s、prepare 180 s | 键集未变 | codec 不改 |

部署顺序：本包读旧后端（无七键、无 `pool/trades`）正常；**旧包读新后端会因 viewer / positions 多出七键判 invalid**
（0145 起的严格键集），与 0145 的 `pool` 键同一问题，需要后端在旧包淘汰前不下发或本包先上线。

## Fixtures / 测试

- 手写：`test/fixtures/s150-launch2/pool_prepare_buy_ready.json`（授权已进块：`approval: null`、nonce N、
  expiresAt = prepare + 180 s）、`pool_prepare_buy_moved.json`（价格变差，minOut 低于原 intent）、`pool_trades.json`
  （按 10-11 模拟器那一买一卖的数字）；`test/support/launch2_fixtures.dart` 加 `l2HoldingJson`，`l2ViewerJson` /
  `l2PositionsJson` / `l2Positions` 可带 holding 组与阶段。均注明来源（S150-api 决策 0126 的 OpenAPI），Development 部署后实抓替换。
- `test/s150_launch2_followups_test.dart`（21）：holding 组 codec（三态、旧后端、半组 / 状态矛盾 / 未知键拒绝、positions）、
  pool/trades codec 与传输（路径、query、503 原因、limit 越界）、`refreshHead` 与控制器 refresh / reload、面板持仓优先级与
  报价前文案、`refreshRefusal`、签名器四条路径（余量足不刷新、<20 s 刷新并签新 intent、授权未进块重试后成功 / 停住、刷新读失败）、
  事实行、回购合并三种、Meme 轨原因全部不含「价格」。
- `s146`（+7）：服务端余额报价前显示与 MAX、读不到时的一行、慢授权触发刷新（两次报价两次 prepare、签新 intent、「已刷新报价」）、
  刷新变差停在第 2 步、授权一直未进块停在第 2 步、自己的计数而不是全池计数结算并显示「我的外盘成交」、成交读失败一行。
  原「先授权…给官方池路由」断言改为金额 + 「授权给官方池路由」行。
- `s136`（+6）：列表 60 s 轮询 / 切走不读 / 回来立即读、项目页盖住不读 / 返回立即读、回购不同原因合并、就绪时不合并、钱包
  余额行 / 读不到退回内盘行、余额 0 不画。原 keeper 用例改为断言合并行。

## Consequences

- （S153-mobile 补记，原文缺此节导致 `scripts/check_harness.py` 不过；内容只汇总上文已写的决定，不新增决定。）
- v2 列表在屏幕上时每 60 s 多一次第一页读取，被盖住或切走时不读；滚到的深页不会被刷新拉回。
- 外盘两步签名在 intent 将过期时多一次重报价与 prepare；新数字超出已确认界限时停在第 2 步给原因，不会静默签更差的单。
- 客户端依赖 S150-api 新增的 viewer / positions 键，旧包与新服务端的兼容见「未决项」2。

## 未做 / 与下单的偏离

- 过期保护只接**官方池**：曲线 prepare 由客户端带报价的 `minOut / deadline`，刷新要先重报价再拿新数字 prepare，且曲线
  价格每笔都动，「不比确认的差」会频繁拦下；验收观察的是外盘。曲线 / NFT 仍是原行为（广播授权后若过期，钱包边界拒签，
  页面「授权已广播，买入没有签名」）。
- 「静默」的边界：刷新不再弹确认，但新数字必须在用户已确认的界限内，否则停下；钱包（Privy）自己的弹窗仍是最后一次确认。
- `usd1Balance` 只入模型，买入侧没有单独显示 USD1 余额（报价后的 `exceedsBalance` 行照旧）。

## 未决项（需后端 / 主代理决策）

1. 本批对齐的是 S150-api fada8be（其提交说明写「tests still being updated」）；之后若契约再变，需要再对一次（codec 键集、`limit`、错误目录）。
2. 旧包兼容：viewer / positions 新增七键对 0148 之前的包是破坏性的（同 0145 未决 3）。
3. 服务端余额缓存 ≤ 15 s：自己的计数先动、余额后动时，「已在链上确认」之后的一个轮询周期内「持有」可能还是旧值。
4. 曲线 / NFT 是否也要授权后刷新（见「未做」）。
