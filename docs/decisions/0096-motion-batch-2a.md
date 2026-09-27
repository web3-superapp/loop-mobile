# 0096 · 动效第二批（前半）：横向手风琴、Dock 放大、token 托盘收紧

## Status

Accepted 2026-09-27。S89a，客户端单侧。需求方六条动效中的第 3 条（横向手风琴）与第 5 条
（Dock 放大），加上批次一（0092）模拟器走查发现的 token 托盘问题。用户裁决动效由主代理
自决。不新增依赖、不改路由清单（93 条不变）、不改任何接口契约、不改冻结原型文案。

## Context

需求方的六条动效里，第 3 条要一个横向手风琴（点一条变宽、其余收窄），第 5 条要底部 Tab 的
Dock 放大（按住横滑时图标按距离放大、松手选中）。批次一模拟器走查另发现 token 页托盘展开后
是 16 行、每行重复「—— 来源 GoPlus，观察于 N 秒前」，且四格指标没有底，托盘像一枚独立药丸。
约束沿用 0092：动效不携带信息、减弱动效瞬时、颜色只取 token、渲染探针逐帧受检。

## Decision

### 1 参数（`lib/core/theme/loop_motion.dart`）

| 组件 | 常量 | 值 |
| --- | --- | --- |
| LoopAccordionStrip | `accordionExpand` / `accordionCurve` | 280 ms / `Curves.easeOutCubic` |
| | `accordionFadeStart` | 0.4（展开条明细在同一控制器 40%–100% 淡入；收窄条明细在 0–40% 淡出） |
| | `accordionOpenWeight` | 3（展开条权重 3，其余各 1） |
| LoopDockBar | `dockPeakScale` | 1.45（手指所在格） |
| | `dockNeighbourScale` | 1.15（相邻一格） |
| | `dockReach` | 2（≥ 2 格为 1.0） |
| | 衰减 | 高斯：`1 + 0.45 · 3^(−d²)`，d 以格为单位；d=1 恰为 1.15，d=2 处尾部 < 1%，截断不可见 |
| | `dockEngage` / `dockRelease` / `dockCurve` | 120 ms / 180 ms / `Curves.easeOutCubic` |

减弱动效（`MediaQuery.disableAnimations`，含 App 自己的「减弱动态效果」）时两者全部瞬时。

### 2 `LoopAccordionStrip`（`lib/widgets/loop_accordion_strip.dart`）

- 一排等宽窄条（间距 6），每条圆角 `LoopRadius.control`，底色 `LoopGround.tintOf` →
  展开时插值到 `LoopGround.fillOf`，边线 hairline → edge；
- 收窄条只画缩写标题（`R1` / `END`，Plex Mono eyebrow）与一个 6px 状态点：
  进行中 Lime、未开始 `secondaryOf`、已结束/无状态 `auxiliaryOf`；
- 点某条：权重在 280 ms 内从当前值插值到 3 : 1 : …；再点当前条收回等宽；动画中途再点
  从当前宽度继续，不跳；
- 明细按**最终展开宽度**一次排版，由条本身裁切（`OverflowBox` + `ClipRect`），动画中
  文字不重排；未展开条不构建明细（读屏/查找只读到屏幕上的内容）；明细用
  `FadeTransition`（与 0092 托盘同法）；
- 行高固定（调用方给出，随 `textScaler` 放大），明细数值用 `FittedBox.scaleDown`，
  数字不截断；
- **回退**：`textScaler ≥ 1.3`、屏宽 < 360、或展开条宽度 < 132（条数过多）时整块改为
  调用方给的纵向列表。第三条是任务单之外补的：390 宽屏上 5 条（4 轮 + END）可放，
  6 条及以上展开条不足 132，数字会被缩得不可读。

### 3 落地：`launch-detail` 发射轨道

- 仅链上轮次（`detail.chainRounds` 非空）时使用手风琴：R1…RN + END；
- 展开明细：`Round N · 名单轮/公开轮`，开始/结束（UTC，去年份 `MM-dd HH:mm`），单价、
  轮次上限、钱包上限、已募集（与纵向行同一格式化），进度条 = 已募集 / 轮次上限；
  LOOP 无该轮记录（`roundId == null`）时加一行「LOOP 没有这一轮的记录，不能在这里认购」；
- END 展开：「毕业与迁移」、投影徽标、说明句、「查看毕业流程」按钮（→ `launch-graduation`，
  原纵向行的点击去向）；
- 默认展开 `isOpenAt(now)` 的第一轮；没有进行中的轮次时全部等宽；`LaunchDetailScreen`
  新增可选 `clock`（测试注入）；
- 只有配置轮次（`detail.rounds`，链上读不到）时保留原纵向列表：这些轮次没有单价/上限/
  已募集可展示，手风琴只会展开一排「待确认」；
- 回退列表即原 `LoopRecordGroup`（key `launch-track`，行 key `launch-track-<n>` 与
  `launch-track-graduation` 不变）；手风琴行也用 key `launch-track`，两者只会构建其一；
- `launch-trade` 的「本轮参数」、`launch-rounds` 不变。

### 4 `LoopDockBar`（`lib/widgets/loop_dock_bar.dart`）与底部五 Tab

- 通用组件：一排等宽格 + 手势；`LoopDockBar.scaleAt(d)` 与 `LoopDockBar.layout(...)`
  为纯函数；
- 触发：水平拖动越过 touch slop，或长按（系统长按时长）后滑动；单击仍由各格自己的
  `InkWell` 处理——不放大，行为与之前完全一致；
- 放大时每格可视宽度 = 行宽 × 该格缩放 / 缩放之和，据此算出每格中心的横向偏移
  （`LoopDockCell.shift`），相邻格向外让位，行两端不动；
- 缩放和偏移只作用于格内绘制（`Transform`，以底边中心为原点，图标向上长出栏外），
  各格的布局与点击热区始终是等宽的 1/5；
- 松手选中手指所在格（按等宽热区计算），与当前相同则不再触发；然后 180 ms 回落；
- Lime 选中胶囊仍是一个指示器（0071），随其所在格的 `shift` 横移，不缩放；
- `RawGestureDetector.excludeFromSemantics`：读屏不把导航栏读成可滚动区域；
- 减弱动效：不放大、不让位，滑动松手仍然选中。

### 5 token 页托盘收紧

- 四格指标放到 `TokenQuotePanel` 上：与托盘同宽（页边 16），圆角 `LoopRadius.card`，
  底色 = `LoopGround.tintOf` 叠在 Ink 上的**不透明**色（托盘先画、伸到面板下沿之下，
  半透明面板会透出托盘），hairline 边线。托盘 `trayInset = 16`，`overlap` 回到默认 20
  （0092 时因四格无底色取 8）。主卡位置不动的规则不变；
- 明细：主交易对一行（单行省略）；合约事实改为两列紧凑格（6px 点 + 短标签，
  读屏读完整句子）；风险类在前、警示色点（`LoopColors.warning`），其余中性点
  （`LoopColors.text3`）；最多 8 格，多出的收成一个 44 高的「更多 N 项 › 简介」，
  点击切到「简介」页签（该页签仍列全部事实与各自来源、时间）；
- 风险类按语义判定，不按文字开头：`proxy`、`mintable`、`ownershipTakeBack`、
  `ownerChangeBalance`、`hiddenOwner`、`selfDestruct`、`externalCall`、`honeypot`、
  `transferPausable`、`blacklist`、`whitelist`、`antiWhale`、`tradingCooldown`、
  `cannotSellAll` 取值 `true`，以及 `openSource` 取值 `false`。「可以全部卖出」以「可」开头
  但不是风险，按文字开头会误判；非 true/false 的取值一律中性；
- 短标签保留原句的判断强度：「未检测到」仍写「未检测到」，不写成「无」或「安全」；
- 底部一行「来源 GoPlus · 观察于 N 前」：来源为全部事实来源去重，时间取**最旧**的
  观察时间（格子整体只和最旧的一格一样新）；
- 合约事实不可用 / 为空时，文案与之前相同，不画格子与来源行。

## Tests

- `test/s89a_dock_bar_test.dart`：衰减三个锚点与单调、让位对称且行宽守恒、单击不放大、
  拖动放大（1.45 / ≈1.15）与让位、热区矩形前后完全相同、松手选中、滑回原格不选、
  长按后滑动、减弱动效只选中不放大；
- `test/s89a_launch_track_accordion_test.dart`：默认展开进行中轮且 3:1、40% 前明细未出现、
  逐帧 pump 到终态、再点收回等宽、无进行中轮等宽、无记录轮提示、END 展开与跳转、
  减弱动效一帧到位、字号 1.3 / 屏宽 340 / 7 轮回退为纵向列表（原行 key 仍在）；
  走 `pumpS7Page`，渲染探针逐帧检查；
- `test/s89a_token_tray_test.dart`：风险判定与短标签、两列、风险在前与警示点、最多 8 格、
  「更多 4 项」≥ 44 且在来源行之上、「来源」全托盘只出现一次、点「更多」切到简介且托盘
  不收、≤ 8 项无「更多」、面板与托盘同宽同左且不透明；
- 既有 `s5_market_pages_test`「token 托盘」用例更新：原断言每条事实带「—— 来源」改为断言
  短标签、无逐条来源、底部来源行。

## Consequences

以下为真机要看的点（本单未在模拟器或真机上验证）：

1. Dock：底栏按住横滑时图标长出栏外的高度（1.45 × 21px 图标 + 标签，以底边为原点）在
   有 Home Indicator 的机型上是否被安全区或页面内容遮挡；与 iOS 系统边缘返回手势、
   底部 Home 条上滑手势是否互抢；长按 500 ms 触发是否太慢；
2. 手风琴：Launch 详情「发射轨道」在 375 / 390 / 430 宽机型上 R1…END 各条的缩写和状态点
   是否清楚；展开条数字是否被 scaleDown 缩得过小；系统字号调到 1.3 以上是否回到纵向列表；
3. token：四格面板与托盘是否读成「一张卡 + 下面的托盘」；面板底色与 Ink 页的区分在
   OLED 上是否可见；「更多 N 项 › 简介」切页签后简介内容在折叠区下方，用户是否需要滚动
   才能看到（本单未自动滚动）。

## Main-agent rulings (2026-09-27)

1. The extra fallback rule (open strip narrower than 132 → vertical list) stays.
2. `proxy = true` and `openSource = false` count as risk facts in the tray.
