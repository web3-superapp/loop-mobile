# 0273 · MEME 去「战绩」、K 线对齐行情 token 详情

## Status

Accepted · 2026-11-03（S345-mobile）。来源：需求方脑图 `Loop.xmind`，主代理落地方案 `LOOP/docs/56-页面精简-需求方脑图-2026-11-03.md` §二「MEME」。

## Context

脑图：「MEME：战绩不要；MEME token 详情页 K 线相关信息要和行情页一样；其余不动。」

## Decision

### 去「战绩」

- v2 发射台首页（`Launch2ListSegment` 全部范围）的「战绩」整块删除：标题、(i) 来源、四格（本周毕业 / 累计回购 / 勋章已铸 / 进行中）及每格第二行。`launch2DeskStats`、`launch2DeskStatNotes`、`_StatsHeading` 删除。
- 页尾改为始终画一行 `LoopProvenanceLine`（`launch2-list-all-provenance`，与原先「没读到战绩」时相同）。
- `Launch2Stats` 模型与 codec 不动（`launch2DeskCounts` 仍用它给三段 tab 计数）；`MemeStatFigures` 仍被 NFT 铸造、项目页、挖矿奖励等使用，保留。

### K 线对齐

- 新增 `features/market/loop_chart_toolbar.dart`：`LoopChartToolbar`（MA 读数 · K线/折线 · MA · VOL）、`LoopChartToggle`、`LoopChartIntervalRow`（周期 + 末尾控件）、`loopChartAveragesText`。行情 `TokenCandleSection` 改用这三件，key、文案、间距、默认值不变（纯抽取）。
- `launch2-instance` 的 `Launch2CandleCard`、`meme-token` 的走势区（`MemeChartSection`）与行情 token 详情同构：图上方工具栏（MA 读数在左，K线/折线、MA、VOL 在右），图下周期行，周期行末尾全屏图标；默认折线、MA 关、VOL 开；最新价用行情同款轴上标签（`lastPriceTag` 关）。
- launch2 去掉 `LoopRecordCard` 外框和 `LoopSegBar`，改为与行情同样的全宽布局；周期保留 MEME 自己的 6 档（1分 / 5分 / 15分 / 1时 / 4时 / 1天）；「毕业」竖线与向左拉取更早数据保留；价格格式仍用 `launch2PriceLabel`（零折叠），价格轴宽仍 66。
- meme-token 周期由 LIVE / 1H / 4H / 1D 改为同样 6 档（默认仍 1 分）；覆盖 0174 的 Lime 折线 + Lime 价签 + 无成交量，改为行情默认配色、带成交量。
- 成交量：两个接口本来就带——launch2 candles 的 `v`（MEME 数量，图里用它）与 `q`；meme candles 的 `volumeUsd1`。不需要后端改动。

### 全屏

- 不新增 slug：复用 `chart-full`（`/market/chart`），用查询参数区分：`?assetId=`（行情，原样）、`?launch2=<instanceId>`（`Launch2FullChartScreen`）、`?meme=<memeTokenId>`（`MemeFullChartScreen`）。分派在 `app.dart` 的 `loopChartFullPage`。
- 两个全屏页与 `FullChartScreen` 同构：允许横屏、离开时锁回竖屏、图高 = 屏高 − 210（最低 160）、标题为代币、没有全屏图标；复用各自的图表块（工具栏、周期、毕业标记、向左加载都在）。不带「这张图能做什么」说明。
- 五态：加载 / 错误 / 离线来自项目（代币）读取的 `LoopChainStateBlock`；空态是图表块自己的「还没有成交」；能力关闭时整页 `LoopPageBlock`。非法 id 失败关闭，不回退到其他资产。

## Consequences

- 路由清单 slug 数不变；`docs/product/routes-manifest.json` 无需改动。
- 测试：`test/s345_meme_chart_parity_test.dart`（战绩消失、两页工具栏四件、MA / VOL 开关、全屏进出、毕业标记、全屏五态），`test/s345_shots_test.dart`（`LOOP_SHOTS=true` 才跑）；`s117` / `s182` 相应用例按新结构更新。

## Amendment · 2026-11-03（主代理验收截图后）

- MEME 两页的周期行改为等分（`LoopChartIntervalRow(fill: true)` + `LoopChartPeriod`）：6 档各占一份、不滚动，全屏图标固定在最右；外观同 quiet `LoopSeg`（未选为纯文字，选中为紫色实心胶囊 + 白色粗体 + splat），每档触控 ≥ 44×44，文字在大字号下缩放而不溢出。360 / 390 宽下 6 档文字都完整可见（测试用 App 自带字体量）。行情 5 档仍是原来的可滚动 `LoopSeg` 行，不变。
- MEME 两页的 MA 读数改为工具栏下方单独一行（`averagesOnOwnLine`，`LoopType.meta`，可换行不截断）；MA 关时不占行。行情仍是读数与开关同一行。
