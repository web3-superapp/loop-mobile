# 0146 · 2026-10-11 模拟器验收跟进：MEME v2 项目方入口、老挖矿页按数量加权、回购 keeper 一行、已毕业行让出代码列（S148-mobile）

## Status

Accepted 2026-10-11。主代理下单（S148-mobile），基线 `integration/v2` 67f5ae2（已含 0144），分支 `feat/S148-mobile`。
依据：主代理验收记录 `LOOP/docs/acceptance/2026-10-11-s142-emulator.md`（证据 `docs/evidence/2026-10-11-s142-emulator/`）；
本仓 0138 §6 / §8、0139、0142、0143、0144；loop-api 决策 0121、0122、0123，`docs/frontend-v2-launch2-api.md` §3.2 / §5，
`openapi/loop-api.v2.json`（loop-api `integration/v2` 1b2b426）。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变（只改 `mining-rules` 的清单标题）、视觉 token 不变。

## Context

验收发现五件事：MEME Tab 的 v2 面没有「发起 / 我的项目」入口（0138 §6 的选择抽屉从未落地，`Launch2CreatorEntry` 只在测试里出现）；
老挖矿页 POWER COMPOSITION 行仍写「0 × $2.25 × 0.9×」（数量 × 价格 × 权重），与 0123 / 0143 的按数量加权矛盾，规则页大标题仍是
「权重与价格保护」；0144 读进来的 `buyback.keeper` 没有展示（0144 未决项 2）；「v2 发射」已毕业行的代码列被中列「已毕业 / 毕业价 …」
挤成「S1377…」（证据 02）。

## Decision

### 1. MEME v2 面的项目方入口（0138 §6）

- 新组件 `Launch2CreatorActions`（`features/launch2/creator/launch2_creator_entry.dart`）：两个顶栏图标按钮，
  「我的项目」（`user`，→ `/launch2/projects/mine`）与「发起」（`plus`，→ 选择抽屉）。只在 `launch2CreatorEntryVisible`
  （构建开关开且 `launch2 == available`）时画，否则 `SizedBox.shrink()`。经典发射的创建路径由调用方传入（`MemeRoute.createPath`），
  launch2 模块不反向依赖 MEME 模块。
- 选择抽屉（`showLoopSheet`，根导航器）两行：「v2 发射」NFT 预售 + 提前购 + 公开内盘，毕业进官方外盘 → `/launch2/create`；
  「经典发射」联合曲线发币，打满自动上 PancakeSwap → `/meme/create`。
- 位置：MEME Tab v2 面的顶栏右侧（`LoopSegmentedTabPage.actionsBuilder`），只在「v2 发射」「已毕业」两个分段出现；「经典」分段保留
  原有「创建代币」工具行，不加顶栏按钮；IDO 分段（开关开时）仍是它自己的两个工具。顶栏按钮是图标 + 无障碍名（0087：顶栏文字一律
  改图标），与聊天 Tab 的「＋」同一语法。
- `Launch2CreatorEntry` / `Launch2MyProjectsEntry` 保留（整宽按钮形态，供以后的空态或页内使用）。

### 2. 老挖矿页按数量加权（0123 / 0143）

- OpenAPI 核对：`/v2/mining/assets`、`/v2/mining/summary`、`/v2/mining/rules` 三条都**没有** `assetPowerBasis` 或同义字段；
  `assetPowerBasis` 只存在于 loop-api 的小时结算参数文档（admin），客户端读不到。`/v2/mining/assets` 的 `included[]` 仍下发
  `holding / referencePriceUsd / referencePriceQuality / referencePriceProxyAssetId / referencePricePairAddress / weight / power`，
  键集不变，codec 不改（参考价仍解析，只是不展示）。
- 资产行（「我的挖矿」POWER COMPOSITION 与「算力明细」共用 `miningCompositionRow`）：算式改为 `持有量 × 权重×`
  （`miningCompositionExpression`），去掉 `$参考价`、「代理价，来自 …」「推导价，来源池 …」副注与读屏里的参考价；资产 id 行保留。
- 「算力明细」页：头部算式 `miningPowerFormulaHeading` 改为「持有量 × 权重」；「参考价」分区（批次 + 详情里的参考价版本）与
  「参考价不是瞬时成交价」提示删除。排除原因里的 `MINING_PRICE_*` 文案（服务端仍可能下发）不变。
- 「当前算力公式」抽屉（`miningBaselineDetail`）首句加「算力 = 持有数量 × 挖矿权重，按数量加权，不乘价格。」；挖矿页空态原因、
  帮助中心「算力是怎么算的」同步去掉参考价。
- 规则页大标题与 `route_manifest.dart` 的 `mining-rules` 标题：「权重与价格保护」→「权重与算力规则」（slug、path 不变；
  `docs/product/routes-manifest.json` 与 `LOOP/docs/routes-manifest.json` 无标题字段，不用改）。规则页里服务端下发的
  `priceGuardRules` 条目与 `mining.rules.formula.holdingTimesReferencePriceTimesWeight` 的文案照服务端 key 原样翻译，未改。

### 3. 回购 keeper 一行（0144 未决项 2，主代理裁决）

视图模型 `launch2KeeperLine(Launch2BuybackSummary)`（`launch2_format.dart`），回购卡在「下一笔」之后、「回购已暂停」之前画一行
`launch2-buyback-keeper`：

| keeper | 显示 |
| --- | --- |
| `null`（keeper 未跑过，合同 §5） | 不画 |
| `summary.paused = true` | 不画（卡上已有「回购已暂停」） |
| `confirmed` / `pending` / `broadcast`，或 `rejected` + `LAUNCH2_BUYBACK_TOO_SOON` | 「自动回购运行中 · 上次 <账本 lastExecutedAt>」；在途加「一笔正在上链」 |
| `rejected` 其他原因 | 「回购暂缓：<原因> · <nextEligibleAt HH:mm> 后再试」 |
| `failed` | 「回购暂缓：<失败原因>」 |

拒绝原因中文（合同 §3.2）：`PRINCIPAL_INSUFFICIENT` 官方池本金保护，本金不足 10,000 USD1 或单笔超过 1% / `NO_BUDGET` 托管余额不足一笔 /
`PAUSED` 合约回购已暂停 / `NOT_GRADUATED` 项目还没有毕业 / `NOT_KEEPER`、`KEEPER_NOT_AUTHORIZED`、`KEEPER_CHAIN_MISMATCH` 回购执行账户
未就绪，平台处理中 / `ESCROW_MISMATCH` 托管记录与链上不一致，平台核对中 / `NO_OUTPUT` 成交到账为 0，平台处理中 / 三个旧版价格保护码
旧版合约价格保护生效 / `GAS_PRICE_ABOVE_CAP` 链上手续费过高 / `CONTRACT_REVERTED` 合约拒绝执行，平台处理中 / 其他「暂不执行」。
失败原因：`PAUSED` 合约回购已暂停 / `KEEPER_INSUFFICIENT_FUNDS` 执行账户手续费不足，平台处理中 / `GAS_ABOVE_CAP` 链上手续费过高，稍后重试 /
其他「上一笔没有执行，稍后重试」。原因码不上屏。`TOO_SOON` 视为运行中：它是两笔之间的 10 秒节拍，不是阻塞。
改动只在 `_BuybackPanel` 的子项列表里插一项，不动毕业态分支（S146 正在改那里）。

### 4. 已毕业行让出代码列（证据 02）

- 已毕业行中列改为：数字位 = 毕业价（`launch2PriceLabel`，FittedBox 只缩不截），说明位 =「毕业价」；原来的「已毕业」数字位删除
  （右侧阶段胶囊已经写「已毕业」，重复）。
- `LoopQuoteRow` 加可选 `titleMinWidth`：给定时数字列上限 = min(140, 36 % 行宽, 行宽 − 头像 36 − 间距 − 代码最小宽 − 胶囊槽 96 − 间距)，
  下限 56；不给时与原来一致。v2 已毕业行传 `launch2TickerMinWidth = 92`（Sora 18 px 大写 / 数字约 0.62 em，8 个字符）。
  提前购 / 公开 / 其他阶段不传，原样。

## Fixtures / 测试

- `test/support/launch2_fixtures.dart`：`l2KeeperJson` 可变 `lastResult / reasonCode / nextEligibleAt`；`l2BuybacksJson` /
  `l2Buybacks` 加 `keeper`。均手写（dev 上 keeper 默认关，暂无实抓）。
- `test/s136_launch2_user_test.dart` 新增三组：MEME 入口（v2 发射 / 已毕业有、经典无、能力不可用无；我的项目、选择抽屉两项各自跳转）、
  keeper 一行（无 keeper / 暂停不画、拒绝带下次时间、全部原因码中文且不漏码、运行中三种、页面渲染）、已毕业行在 360 宽下代码列
  ≥ 92；原「各阶段两行」用例按新中列更新。
- 挖矿：`s7_mining_pages_test` 资产行断言 `12.5 × 0.8×` 且无 `$2.26`，代理价 / 推导价 / 参考价版本 / 参考价分区改为断言不出现，
  新增「我的挖矿」构成行 `0 × 0.8×` 与抽屉含「持有数量 × 挖矿权重」；`s59_mining_structure_test` 分区顺序去掉「参考价」、规则页标题；
  `s8` 算力明细的就绪标记改为 `mining-formula-row`；`s59_mining_recorded_page_test`（实抓回放，样本缺失时跳过）同步算式。

## Consequences

- 老挖矿页（S7 快照接口）展示口径与 0123 一致，但**数值来源仍是旧快照通道**：loop-api `mining-snapshot.ts` 的
  `power = holding × referencePriceUsd × weight` 未随 0123 改（0123 只改了小时结算）。在服务端改口径或下线该通道之前，
  非零持仓的行上「持有量 × 权重」与右侧算力数值对不上（dev 现网是 0 持仓 / 权重 1 的试运行，暂不显形）。见未决项 1。
- MEME v2 面的入口只在服务端 `launch2 = available` 时出现；main_preview 的预览网关模式能看到 v2 面但看不到入口（与 0138 §6 一致）。

## 未决项（需后端 / 主代理决策）

1. `/v2/mining/assets`（及 summary）的算力仍按价格算（旧快照通道），客户端没有 `assetPowerBasis` 可读。需要 loop-api 二选一：
   快照通道也改按数量（并在响应里下发 `assetPowerBasis`），或把老挖矿页的资产明细改读 `/v2/mining/rewards` 的 `hourly.tracks.asset`。
2. 规则页 `mining.rules.formula.holdingTimesReferencePriceTimesWeight` 与 `priceGuardRules` 是服务端下发的旧 key，客户端照译；
   需要服务端随 0123 换成数量口径的 key（客户端补一行中文即可）。
3. keeper 的 `nextEligibleAt` 只显示钟点（HH:mm），未做秒级倒计时；回购卡的「下一笔」（链上 live）与 keeper 行可能同时说暂缓，
   两者来源不同（链上视图 vs keeper 最近一次模拟），本批不合并。
4. 选择抽屉的「经典发射」走 S117 曲线创建页（`/meme/create`）；若需求方说的「经典 Launch」指已隐藏的 IDO 申请，需要另定。
