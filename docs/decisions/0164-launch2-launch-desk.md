# 0164 · 发射台改为冻结原型的「账本台 Launch Desk」（S182-mobile）

## Status

Accepted 2026-10-14。基线 `integration/v2` efa3907（0163 之上）。只换视觉层：数据层（`launch2_overview.dart`、overview
gateway、controllers、`launch2HeroRows` 选行排序、`launch2GroupRows` 分组、文案函数、测试 fixture）不变。
不新增依赖、不新增字体与颜色 token、路由数不变（113）、无新请求路径。

## Context

TF 17 的发射台（0163）用的是深灰卡 + 大号 lime 数字 + 计数胶囊 + 横向漂移电报 + 行下引线 + brass 环，
和聊天 / 广场 / 情报 / 钱包所用的冻结原型部件家族不一样。2026-10-14 给用户看了三套全部用原型 `style-v2.css`
原文件画的候选（A 账本台 / B 对开本 / C 签名卡流），用户选 **A**：它就是原型 `launch.html`（Launch 页）的结构——
满 lime 账本卡 + `.segs` 分段计数 + `.record-card` 进度 + `.label` 分组行 + `.notice`，与旧 IDO Launch 页
（`lib/features/launch/launch_screen.dart`）同一套 Flutter 部件，改动最小、和其它 Tab 同家族。

同日用户追加：顶部账本卡做成左右可滑的分页（样式不变，每件事一页，≥ 2 页才画分页点，不自动轮播），
并为后台「运营活动卡」预留页模型（本批不接数据）。

## Decision

### 1. 「v2 发射」（scope=all）自上而下

| 块 | 部件 | 说明 |
| --- | --- | --- |
| 账本卡（分页） | `Launch2DeskPager` → `PageView` 每页一张 `LoopFolioPrimary(variant: lime, archetype: listing, ring: false)` | 同屏唯一满 lime。kicker `LAUNCH DESK · BSC TESTNET`（主网 `· BSC`，取首行 `chainId`）；heading `{ticker}\n{状态句}`（共识勋章铸造中 / 白名单提前购 / 内盘冲刺 {bps} / 开售倒计时）；caption 一句数据；stamp `剩 {倒计时}` / `距开售 {倒计时}`（`Launch2CountdownBuilder` 每秒重建、到点 `reload()`；冲刺无倒计时不画 stamp）。页 = `launch2DeskPages(launch2HeroRows(...))`，每件事（含预告）一页，最多 5；高度固定 220 × textScale，页宽 = 屏宽 − 2×16；分页点在 kicker 行右端（`kickerTrailing`，ink 实心 / ink 30%），≥ 2 页才画；无行时一页「暂无进行中的发射 / NFT 预售开始后会出现在这里」、无 stamp、不可点。点击：upcoming / nft_sale → 铸造页，其它 → 项目页。 |
| 分段计数 | `LoopSegBar`（新增可选 `dimmed`） | 铸造中 / 内盘（提前购 + 公开内盘）/ 预告 / 已毕业；有 overview 统计时取统计，否则按已读行计；0 仍显示但 text3 灰；选中态 = 主事件所在段；点击滚到该段第一个分组标题（无标题则滚到该段的 record-card），「已毕业」切到 MEME 的已毕业分段（`Launch2ListSegment.onOpenGraduated`，MEME 传 `select(2)`）。 |
| 进度卡 | `Launch2DeskRecordCard` = `LoopRecordCard` | 行内：铸造中用 `LoopMonoTile(accent: true)`（lime 底 ink 字 row-ico，ticker 前两字），其它 `MemeLogo` 44 / r15；ticker + 「{name} · NFT 发售 7 天 · 截止 MM-dd HH:mm」；右侧 mono 16 lime 倒计时（冲刺为已售 %）+ 「铸造剩余 / 提前购剩余 / 距开售 / 内盘进度」；下方 `LoopProgressBar`（6 px lime：铸造中 = 发售时间已过比例，提前购 / 内盘 = 已售 ÷ 8 亿，预告不画）；底句「发售已过 57% · 已铸 2 枚 · 100 USD1 / 枚」。主事件之外若第二件也在进行（铸造 / 提前购 / 冲刺）再画一张，最多两张。 |
| 实时 | `LoopLabel('实时')` + `Launch2DeskTape` | 原型 `.tape`：card 底、line 边、行间 line，mono 11，左侧 lime 时间（刚刚 / N 分钟前 / HH:mm），金额 chalk 加粗；静态最新 3 条，超过 3 条右上「全部」展开到 10 条、「收起」收回；不再漂移；点行进项目页。 |
| 分组行 | `LoopLabel(group.title)` + `Launch2InstanceTile`（`LoopQuoteRow`） | 顺序沿用 `launch2GroupRows`；已在 record-card 里的行不重复；空组不画标签；行去掉 fuse 与 brass 环。 |
| 战绩 | `LoopLabel('战绩')` + `LoopStatGrid` 2×2 | 本周毕业（「本周毕业 · 累计 N」）/ 累计回购 X USD1 / 勋章已铸 N 枚 / 进行中 N；统计缺失整块（含标签）不画。 |
| 说明 | `LoopNotice(icon: target)` | 「精品发射，不是每天几万个」+ 方案 A 原句，放在来源行之前。 |

已毕业分段（scope=graduated）：不画账本卡、计数、进度卡、实时、战绩、说明，只有行列表（同前）。

### 2. 页模型（为运营活动卡预留）
`sealed class Launch2DeskPage`：`Launch2DeskEventPage(row)` 与 `Launch2DeskCampaignPage(Launch2DeskCampaign)`；
`Launch2DeskCampaign` 有 `campaignId / title / subtitle / coverUrl / startAt / endAt / link`。`launch2DeskPages(hero,
campaigns:, now:)` 先事件后在期内的活动；本批调用方不传 campaigns，活动页只有渲染桩 `Launch2DeskCampaignCard`
（同一张 lime 账本卡：kicker `LAUNCH DESK · 活动`、标题、副标题，点击开 `link`），封面与起止展示等接数据时再定。

### 3. 共识勋章铸造页（`launch2_nft_screen.dart`）
- 顶部 `LoopFolioPrimary`（quiet，archetype record，`ring: false`）：kicker `CONSENSUS MEDAL`，heading ticker，
  caption「状态句 · 已铸 N 枚」（`Launch2NftView.status` + `statusDetail`），stamp `剩 / 距开售 {倒计时}`；
  可交易 / 可铸造阶段 heading lime，否则 `headingTone: neutral`。原自造状态行（`_StatusLines`）删除。
- 勋章 `Launch2NftMedal` 原样居中放在账本卡下（brass 环只在这里）。
- 「这枚勋章能做什么」「规则」改为 `LoopLabel` + `LoopRecordGroup`（`LoopRowIcon` + 标题 + 说明，无 chevron）；
  「我的持有」「已铸」放在 `LoopLabel('我的勋章')` 下的 `LoopKeyValue`；主按钮不变。

### 4. 公共部件的两处改动
- `LoopSeg.dimmed` / `LoopSegBar.dimmed`：计数为 0 的段用 text3（已有 token）。
- `LoopProgressBar` 修复：填充段 `FractionallySizedBox` 加 `heightFactor: 1`。原来轨道给子节点的是松高度，无子节点的
  `ColoredBox` 取最小值 0，lime 填充从未画出（所有用它的页面都受影响，本批截图自验时发现）。

## Consequences

- 发射台与 IDO Launch 页、聊天 / 广场 / 情报 / 钱包回到同一部件家族；同屏满 lime 只有账本卡，brass 只在铸造页。
- 发射台不再有任何自驱动动画（无漂移、无引线画入）；只有倒计时文字每秒重绘，页面只在用户滑动时换页。
- 运营活动卡接数据时只需给 `launch2DeskPages` 传 `campaigns` 并补全 `Launch2DeskCampaignCard`，不动列表与页模型。
- `LoopProgressBar` 的填充从此真正画出：用它的其它页面（项目页内盘进度等）会出现原本就该有的 lime 填充。

## 与 TF 17（0163）相比删掉的
- `Launch2HeroPager` / `Launch2HeroCard`（深灰卡、64 logo + brass 环、figureXl 大数字）与 `Launch2HeroFuse`（2 px 引线及 600 ms 画入）。
- `Launch2ActivityTape`（40 dp/s 横向漂移电报、触摸暂停、减少动画三条）与 `launch2ActivityMark`（brass / lime 竖标）。
- `Launch2StageCountBar` / `_CountPill`（计数胶囊）与 `Launch2GroupHeading`（标题 + 灰计数）。
- `Launch2StatsStrip`（一行三格），改为原型 2×2 `stat-grid`。
- `Launch2InstanceTile` 的 `fuse` / `ringed`、`Launch2RowFuse`、`launch2RowFuse`、`launch2StageCounts`、`launch2HeroHeight`。
- 铸造页 `_MedalHeader` / `_StatusLines` / `_Bullets`。
- harness `MEDAL_COLOUR_ALLOWLIST` 去掉 `launch2_hero.dart`、`launch2_widgets.dart`、`launch2_launchpad.dart`（发射台不再用 brass）。

## 与方案 A 参考图的差异
- 顶部账本卡是分页（用户追加），单页时外观与参考一致；分页点在 kicker 行右端。
- 提前购 caption 用「已铸 N 枚 · 内盘已售 … · 价格」：列表行没有快照名单人数，不写「名单内 N 人」。
- 倒计时文本沿用 `launch2CountdownText`（`3天 20:10:20`；不足一小时 `MM:SS`），stamp 为 `剩 3天 20:10:20` 而非 `3D`。
- 分组标签沿用现有分组（铸造中 / 提前购 / 内盘 / 名单生成中 / 预告 / 已毕业 / 已暂停 / 无人铸造），参考图只画了其中两组。
- 内盘 / 已毕业行沿用现有 OKX 报价行（logo + ticker/名称 + 数字 + 阶段块），未改成原型 `.row` 的 `row-ico` 方块。

## 测试
`test/s182_launch2_desk_nft_test.dart`（由 `s180_launch2_hero_nft_test.dart` 改名重写）：账本卡四种状态句 / caption / stamp
与倒计时到点重读、空态、分页（单页无点、三页三点、滑动换点、各页去向、不自动走）、页模型与活动桩、分段计数（行计 / 统计、0 灰、
选中、已毕业切段、点击滚动）、record-card 进度比例与底句、第二张卡、实时 3 条 + 展开 / 收起、分组不重复主事件、战绩 2×2 与缺失不画、
铸造页账本卡、360 dp 无溢出。
