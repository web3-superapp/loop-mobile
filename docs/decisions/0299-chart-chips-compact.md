# 0299 · 图表时间胶囊与 K线 / MA / VOL 切换胶囊改小（S375-mobile）

## Status

Accepted · 2026-11-05（S375-mobile）。改写 0171 / 0273 里图表周期胶囊与工具条开关「44 高整块胶囊（左右 15 内边距）」的画法；0171 的「安静 `.seg`、选中实底」、0273 的两行布局（图上工具条、图下周期行 + 尾部控件）不变。

## Context

需求方 11-05 17:35 反馈：资产详情页（情报 · 行情 → 代币页 `token`）K 线下面的时间切换胶囊（15分 / 1时 / 4时 / 1日 / 1周）太大，要改小：胶囊内边距上下 2、左右 4，字号不变；图上方的「K线 / MA / VOL」切换胶囊同样处理。选中态底色、圆角 r8、间距规则不变；触控区仍 44。

此前周期与开关都是 `LoopSeg(quiet: true)`：胶囊本身最小 44 × 44、左右 15 内边距，选中时整块 44 高的底色；MEME 两页的填充周期（`LoopChartPeriod`）选中时是占满整份宽度、44 高的整块底色。

## Decision

- `LoopSeg` 新增 `compact` 选项（`LoopSeg.compactPadding` = 左右 4、上下 2）。打开时画新的公共件 `LoopCompactChip`：胶囊紧贴文字（13 pt chip 字阶不变），底色仍是 `chipActive` / `chipIdle`，圆角仍是 `LoopRadius.pill`（r8）；胶囊居中放在透明热区里，热区至少 44 × 44，点热区任意位置等同点胶囊，按下态画在胶囊上（无波纹溢出）。
- `LoopChartToggle`（K线 / MA / VOL）与 `LoopChartIntervalRow` 的滚动周期行改用 `compact: true`；周期之间 4 的间距（热区之间）不变。
- `LoopChartPeriod`（MEME 两页的填充周期行）改为 `LoopCompactChip(expand: true)`：热区占满所分宽度、44 高，胶囊紧贴文字居中；选中底色 `purpleSelected`、选中字重 / 字色不变；大字号时文字仍 `FittedBox` 缩小不溢出。
- 周期行顶部 2 的额外内边距去掉，行高 = 44 热区本身。工具条行本就是 44（热区），视觉上胶囊从 44 高降到约 21 高。右侧全屏按钮（44 `LoopIconButton`）与胶囊同一中线，下方「单位 …」来源行紧跟周期行，无需单独调整。

## Consequences

- 复用同一工具条的四处一起生效：行情代币页 `token`、全屏 K 线 `chart-full`（同一 `TokenCandleSection`）、MEME v2 项目页 K 线（`launch2_candle_chart.dart`，含其全屏）、MEME 曲线代币页（`meme_token_screen.dart`）。
- 行高不再收得比 44 更紧：触控区 44 是硬规则，热区不越出行外以免和图表手势（十字线）抢点。视觉上的收紧来自胶囊本身变矮、行顶 2 去掉。
- 未选中的窄胶囊热区宽 44，视觉上相邻胶囊之间的空隙会大于 4（4 是热区之间的间距）。
- 测试：新增 `test/s375_chart_chips_compact_test.dart`（文字到胶囊边 上下 2 / 左右 4、热区 ≥ 44 且胶囊居中、选中底色与 r8 不变、点热区透明处也能选中、360 宽五个周期 + 全屏一行不滚动、MEME 填充行同样紧贴）。旧断言无需改写（`LoopSeg` 类型、`quiet`、`LoopChartPeriod.selected`、热区 ≥ 44 均保持）。
- 已知与本批无关：360 宽测试字体下代币页「持有者」数行（`token_screen.dart` 441 行 Row）溢出 16，S375 前即存在。
