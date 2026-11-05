# 0296 · 算力榜领奖台头像画在名次卡之上（S372-mobile）

## Status

Accepted · 2026-11-05（S372-mobile）。修正 0279（S353b，docs/58 §5.15 领奖台）的绘制顺序；0279 的尺寸、颜色、皇冠、紫光、文字与位置不变。

## Context

用户 11-05 16:44 在 iOS 真机（TF 68）截图：算力榜二级页（`/mining/rank`）领奖台三个头像的下沿都被下面的名次卡（02 / 01 / 03）盖掉一截——01 的猫图下半被卡顶切掉，02 / 03 的紫环下半也被切。需求方稿 docs/58 §5.15（Editable 结构：第一名 62 头像 y 354–416，中台顶 y 400）里头像压在卡片上方、完整可见，只与卡顶重叠约 16。

根因：`_PodiumPlace` 与 `_PodiumEmpty` 都是一个 `Column`：皇冠 → 头像 → `Transform.translate` 上移的卡片（头像 1/4，约 15.5 / 13.5；空位 13）。`Column` 按子序绘制，卡片在头像之后画，于是上移进头像区的那一截卡片把头像盖住。不存在 `ClipRect` / `clipBehavior` 裁切；领奖台外层 `Stack` 已是 `Clip.none`，高度也不固定。

## Decision

- 新增 `_FaceOverBlock`：一个 `Clip.none` 的 `Stack`，底层 `Column` 照旧排皇冠（第一名 27 + 4）、头像占位（`intelPodiumRingExtent`：头像 + 2 间隙 + 2 环，第一名 70 / 二三名 62；空位 52）、上移的卡片；头像用 `Positioned` 放在占位处、作为 `Stack` 的最后一个子节点，画在卡片之上。布局与此前逐像素相同，只换绘制（与命中）顺序。
- 重叠量按稿保留：`intelPodiumFaceOverlap(place)` = 头像 1/4（15.5 / 13.5），`intelPodiumEmptyOverlap` = 13，均不超过稿量 16。
- 三个尺寸 62 / 54 / 52、2 宽描边环、皇冠、紫光、名次 / 名字 / 数值位置都不动。二三名的环 Container 也带 key `intel-rank-ring-$place`；卡片包 `intel-rank-block-$place` / `intel-rank-empty-block-$place`，空位环 `intel-rank-empty-ring-$place`，供测试定位。

## Consequences

- 第一名头像外环比卡内「01」行框顶低 1.5（卡上内边距 14 < 重叠 15.5），落在 17 / 1.2 行框的上行距里，不压字形；如需完全让开可把第一名卡上内边距改 16，属位置变化，本批不做。
- 二三名与第一名卡片底边仍差 2（重叠 13.5 vs 15.5 带来的布局尾差，0279 起即如此），本批不改。
- 测试：新增 `test/s372_podium_avatar_not_clipped_test.dart`（390 / 360 宽，三名 + 空位 + 长名字：头像 Rect 完整位于领奖台与屏幕内、与卡片重叠 0 < x ≤ 16、交叠处命中测试先中头像环）。

## 追加 · MEME 首页「发射 / Launch」按钮（需求方 11-05 16:52）

### Context

MEME 首页右上黄色「发射 / Launch」按钮（`Launch2LaunchCapsule`，lib/features/launch2/creator/launch2_creator_entry.dart）两处问题：① 图标是 `LoopIcon('launch')` 的实心小火箭（再叠 5 层 `Launch2BoldIcon` 加粗，看起来像钥匙），不是底栏 MEME 页签那套线性火箭；② 图标 + 文字看起来偏下 / 偏左：文字用 `LoopType.button` 默认的按比例分配行距（上行距少、下行距多，字形落在行框偏下），且 Row 只靠容器内边距撑开，没有显式居中。

### Decision

- 图标改为底栏同款 SVG：`LoopFigmaAssets.nav('meme', active: false)`（docs/58 §8，`assets/figma/nav-meme.svg` 线性描边），`ColorFilter.mode(onYellow, srcIn)` 着色，18 × 18（`Launch2LaunchCapsule.glyphSize`，配 16 / 600 字），key `launch2-create-capsule-glyph`。
- 图标与文字间距 6（`glyphGap`），原为 4。
- 居中：容器 `alignment: Alignment.center`、Row `mainAxisAlignment.center`；文字 `height 1.2` + `TextLeadingDistribution.even`（样式与 `TextHeightBehavior` 都设），行框中心即字形 em 框中心；文字 key `launch2-create-capsule-word`。
- 按钮尺寸、颜色、r6 不变（§9.4：发射 30 r6，左右内边距 8）；中英文同一布局。

### Consequences

- 测试：`test/s372_podium_avatar_not_clipped_test.dart` 加中 / 英两例：图标资产 = 底栏 MEME 线性 SVG 且着 onYellow、按钮高 30 / r6、图标 18、间距 6、图标与文字各自及整体中心线与按钮中心重合（误差 ≤ 1）。

## 追加 · 「我的」总资产：净值大图展开时不画小走势线（需求方 11-05 16:56）

### Context

「我的」页总资产区点「今日盈亏 ˄」展开净值大图（1D / 7D / 30D / 180D / 360D，0259 / 0280）后，总资产右侧 124 × 86 的周走势线（`WalletNetWorthTrend`）与下方大图重复，需求方判为多余。

### Decision

- `wallet_home_widgets.dart`：大图展开（`expanded`）时，走势线位置换成同尺寸的空 `SizedBox`（key `wallet-networth-trend-gap`，`WalletNetWorthTrend.size` + 原 left 8 / top 8 内边距），不画走势线；收起时恢复 `WalletNetWorthTrend`（key `wallet-networth-trend`）。留白而不是让金额行占满：金额是 `FittedBox` 缩放的，占满会让长金额放大、整块跳动。
- 展开 / 收起沿用 0259 的做法：即时切换，无额外动画。`WalletNetWorthTrend` 本身（lib/features/wallet/wallet_networth_widgets.dart）不改。

### Consequences

- 测试：新增 `test/s372_networth_trend_hidden_when_open_test.dart`（390 / 360）：展开后找不到走势线、留白 Rect 等于原走势线 Rect、金额与「今日盈亏」行位置不变；收起后走势线回到原位。
- 读屏：展开时原本只有小走势线读「Collapse / 收起」，现在由「今日盈亏」行读「Collapse net value trend」（`expanded: true`）；`test/s329_wallet_networth_fold_test.dart` 相应改为断言单独的「Collapse」不存在、行标签含「Collapse net value trend」。

## 追加 · 广场「社区」页签入驻入口改图标按钮（需求方 11-05 16:58）

### Context

S364（0288）在广场标题行右端加了文字入口「入驻 ›」/「Apply ›」（`SquareCommunityApplyEntry`，key `square-community-apply-entry`，只在社区页签出现）。需求方要它改成与「我的」页铃铛 / 齿轮、MEME 页 ⓘ 同款的图标按钮。

### Decision

- `square_community_list.dart`：`SquareCommunityApplyEntry` 改为 `LoopIconButton(framed: true)`，44 见方、19 图标、`LoopRadius.tool` 底色，与其他带框顶栏键同一组件。
- 图标：docs/58 §8 线性图标集里没有「申请 / 入驻」类图标，用集内的加号（2001:196，项目精灵图 `plus`，`SquareCommunityApplyEntry.icon`）。
- `label`（读屏 + 长按提示）用现有「规则与入驻」/「Rules and listing」（`square_communityListSquareCommunityRulesLabel`）；key 不变；仍只在社区页签出现，点开原来的规则与入驻表。`square_communityListApplyEntry`（「入驻」/「Apply」）文案不再使用，ARB 键暂留。

### Consequences

- 测试：`test/s364_square_community_list_test.dart` 不再找文字「Apply」（改为断言找不到），改断言 key 是 `LoopIconButton`、`framed`、图标 `plus`、label「Rules and listing」；s111 / s197 按 key 点开，不用改。
