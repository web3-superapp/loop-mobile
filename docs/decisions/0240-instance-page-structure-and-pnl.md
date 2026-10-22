# 0240 · MEME v2 项目页重排 + 持仓成本与盈亏（S285-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 8d997bfd（S277–S283 合入后）。主代理下单 S285-mobile。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api（消费 loop-api 决策 0174 / S280 的公开成交接口与 S284 的成本键）。

## Context

需求方 2026-10-22 验收反馈：

- 第 04 条：代币详情页信息杂乱、没有成交记录；买卖区域要固定；挂钩（LoopDynamic）状态放到图表区；其他信息用 tab 切换（参考 DeBot 截图）。
  现状（决策 0166 / 0227）：一个长页从上到下叠 folio 卡、内盘/官方池块、K 线、本轮状态卡、费用累计卡、池统计、内联交易面板、我的外盘成交（最多 5 笔）、回购、名单公示；毕业后没有全体成交列表，交易面板在页面中段，滚动后就找不到。
- 第 03 条（客户端部分）：K 线页显示买入成本价与盈亏。

后端：loop-api 78c5f72 起有公开接口 `GET /v2/launch2/instances/{id}/pool/recent-trades?limit=`（不需 Bearer、要 V2 读头、`Cache-Control: public, max-age=10`、可能 429）；S284（f8a9605）在 positions 行与详情 `instance.viewer` 上加可选键 `avgCostUsd1 / costBasisUsd1 / realizedPnlUsd1 / unrealizedPnlUsd1 / costCoverage`。

## Decision

### 一、页面结构（`launch2_instance_screen.dart` + 新文件 `launch2_instance_parts.dart`）

自上而下：

1. **头部一行半**（`Launch2InstanceHead`，取代 0166 的 folio 卡）：logo 44、代码（交易中黄色 / 等待与暂停 Chalk）+ 名称、合约地址与复制键（44 触控）、阶段胶囊（有倒计时时第二行是倒计时，只有胶囊每秒重绘）。
2. **状态提示**：交易挂起横幅、合约核对、本次操作的挂起 / 失败通知、「无人铸造直接公开」——都在价格区上方，不收进 tab。
3. **价格区**（曲线阶段与毕业后）：「当前价（USD1）」+ 大字价格；右侧一行：毕业后「24h 成交 x USD1」（`pool.volume24hUsd1`），内盘「内盘已售 x%」。下面是 K 线卡（0227 的 `Launch2CandleCard`，不变）。
4. **我的持仓条**（`Launch2HoldingStrip`，K 线正下方，有持仓才画）：持仓数量（毕业后 `viewer.holding.memeBalance`，内盘 `viewer.curve.net`）、估值（`me/positions` 行的 `valueUsd1`，只在该行已读到时画，绝不本地相乘）、成本价（`avgCostUsd1`）、盈亏（服务端 `unrealizedPnlUsd1` + 百分比 `(当前价 − 均价) / 均价`；均价为 null 或 0 时不画百分比；涨跌色 rise / fall）。`costCoverage == partial` 或有 `realizedPnlUsd1` 时盈亏旁加 ⓘ：说明「部分持仓为链上转入，无成本记录」与已实现盈亏。没有成本键时只显示数量（与现状一致）。成本键先取 `viewer`，没有再取 positions 行。
5. **挂钩状态条**（`Launch2DynamicStatusStrip`，仅 LoopDynamic 池）：「本轮状态 + 已激活 / 未激活 + 跌幅 · 奖金池」一条胶囊，点开是原完整 `Launch2DynamicRoundCard`（底部弹层，「我的奖励」照常进入外盘奖励页）。外盘暂不可用块（0159）也在这里。
6. **曲线阶段**另有「内盘进度」卡（原 `_CurveBlock` 的进度卡）。
7. **Tab**（`Launch2InstanceTabs`，S279 胶囊条样式去掉编号与计数）：
   - 毕业后：「成交 / 信息 / 回购」。成交 = 公开外盘成交（每行：买/卖色、脱敏钱包或「匿名」、`MM-DD HH:mm:ss`、价格、USD1、MEME 数量；来源 ⓘ）；顶部「只看我的」切换为现有 `/pool/trades`（上限由 5 提到 20，标题显示「我的外盘成交 · 共 N 笔」）。信息 = 官方池（ⓘ）/ 毕业时间 / 毕业价 / 外盘税、费用累计（LoopDynamic）、池统计、名单公示、去外盘交易链接（OfficialTax）。回购 = 原回购面板。
   - 铸造中 / 提前购 / 公开内盘：「成交 / 信息」。成交 = 内盘最新成交（`detail.recentTrades`）；信息 = 名单公示 + 发射规则。
   - 预告、名单生成中、无人铸造、已暂停：无 tab，内容不变。
   - 每个 v2 毕业实例都有回购托管，故「没有回购的实例」= 未毕业，不画回购 tab。
8. **固定底栏**：曲线阶段与毕业后为「买入（主色）/ 卖出（次色）」两键；点开为底部弹层，内容就是原 `Launch2TradePanel` / `Launch2PoolTradePanel`（交易逻辑、签名出口不变，只加 `initialSide`）。弹层自读项目，随轮询刷新；阶段变化自动关闭；钱包广播成功后关闭弹层，页面显示挂起通知。禁用规则：交易挂起（`tradingHold`）→ 两键禁用、上方显示挂起原因；上一笔广播未确认 → 两键禁用「上一笔还在链上确认」；LoopDynamic 读不到 → 两键禁用并给原因；提前购阶段卖出禁用「提前购阶段只能买入」。铸造中仍是「铸造勋章」底栏。
   - 键盘：弹层在根导航之上，0234 的点外部收起与 iOS 完成条全局生效；弹层另加 `Launch2DragUnfocus`（读原始指针移动，不参与手势竞技），在弹层内纵向拖动即收键盘（弹层内容不够滚动时滚动视图不接拖动）。

### 二、数据

- 新端口 `Launch2RecentPoolTradesGateway`（`launch2_recent_trades.dart`，默认 unavailable）+ 适配器 `loop_v2_launch2_recent_trades_api.dart`，`main.dart` 挂载。随项目页同一会话发请求（服务端忽略 Bearer）。`LoopV2Contract.validateCacheableSuccess` 新增：成功响应接受 `public, max-age=N`（或 no-store）；错误仍要求 no-store。
- 公开成交 codec 单独声明：根必须可读（对象、契约 2.0、同 instanceId、`items` 是数组），否则整体失败；单条有任何字段读不懂则丢掉该条；未知键忽略；`wallet` 只接受服务端脱敏格式 `0x????…????` 或 null（完整地址视为坏条目）。
- 成本键：positions 行与 `viewer` 的可选键；`avgCostUsd1 / costBasisUsd1` 无符号，`realizedPnlUsd1 / unrealizedPnlUsd1` 有符号（`^-?…`），`costCoverage` 只认 full / partial；缺键、null、垃圾值一律当「无」，不拒绝整行。
- 刷新：下拉刷新重读详情、回购、Hook、公开成交（已读过时）与持仓；轮询读到 `pool.tradeCount` 变化时重读公开成交；我方交易确认时重读持仓。429 显示「请求太频繁，稍后再试」。

## Consequences

- 截图：`docs/integration/S285/shots/`（毕业后成交 tab、信息 tab、公开内盘、买入弹层），由 `test/s285_shots_test.dart` 生成（`--dart-define=LOOP_SHOTS=true`）。
- 测试：新增 `test/s285_instance_page_test.dart`（公开成交 codec 有/空/坏条目/坏根、接口路径与缓存头与 51 拒绝、429；成本五键有/无/null/垃圾/负号、viewer 同键、百分比与符号；毕业后三 tab、公开成交行、只看我的切换与无交易 / 无钱包、成交 tab 加载 / 空 / 限流 / 离线重试 / 无适配器；固定底栏不随滚动、买入 / 卖出打开对应方向弹层；曲线阶段两 tab、提前购卖出禁用；铸造中底栏不变；预告无 tab；持仓条有成本、partial ⓘ、无成本键、无持仓、内盘持仓）。更新：`s136`、`s146`、`s168`、`s177`、`s182`、`s266`、`s267`、`s276`（面板改在弹层、信息/回购进 tab、本轮状态点开、头部替代 folio、挂起时底栏禁用）。`tests/test_check_harness.py` 的 `test_rejects_ungated_meme_tab` 锚点改为 `final v2 = launch2SurfaceVisible(ref);`（基线遗留）。
- 删除：`_InstanceFolio`、`_CurveBlock`、`_GraduatedBlock`（拆为 `_CurveProgress` / `_GraduatedInfo`）、`_MyPoolTrades`（并入成交 tab）。`launch2InstanceFolioCaption` 保留（纯函数，测试仍用）。
- 行为变化（需求方确认）：交易挂起时原来面板仍可输入报价、只禁确认；现在底栏两键直接禁用并显示原因（按本批要求「暂停/不可用时按钮禁用并显示原因」）。
- 未还原：「24h 涨跌」服务端没有字段（详情只有 `volume24hUsd1` 与 `lastPriceUsd1`），本批显示 24h 成交额；要涨跌需后端在 pool 摘要加 24h 前价格或涨跌字段。
- 真机需确认：弹层内金额框弹键盘后确认键可见；弹层内拖动收键盘；固定底栏在 Android 手势条上方。
