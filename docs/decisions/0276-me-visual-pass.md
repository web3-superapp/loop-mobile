# 0276 · 「我的」与他人主页视觉打磨（两层导航分级）

## Status

Accepted · 2026-11-04（S350c-mobile）。来源：需求方 11-04 发来旧版钱包截图，用户裁决对八页做一轮整体视觉打磨（主代理任务单 S350 §S350c）。docs/56 §四 的 10 条结果全部保留；不加功能、不改路由、不加文案。

## Context

TF 63（89c135fb）的「我的」= 身份卡 → 总资产牌（地址旁「管理」）→ 五快捷键 → 「持仓 / 交易 / 社区」→ 持仓内「代币 / NFT」+「产生算力」。截图诊断：

1. `LoopProfileSectionsBar`（`lib/widgets/loop_profile_sections.dart`）与 `WalletAssetTabs`（`wallet_home_widgets.dart`）同为 36 高紫色实心胶囊 + 黄色喷点，「交易」下的五个筛选（`_ActivitySegments`）也是同一款：三层控件长得一样，读起来像两套导航；两层之间还空了约 60（`sectionTop − 12` + 胶囊留白）。
2. 「持仓 / 交易 / 社区」首个胶囊从 16 起（`LoopSegBar` 默认内边距），不在页边距 20 上；他人主页同样。
3. `WalletQuickActions` 左右只留 8、五列等分：两端方键落在 14 左右，和上面 20 边距的资产牌不齐；390 宽键距 19、360 宽键距 13，节奏随宽度变化。
4. 身份卡：「＋ 添加个人简介」在 44 高的点击区里垂直居中，离 LOOP ID 空出约 13；关注 / 粉丝行左内边距 8 + 计数自带 8 = 16，不在页边距上；行底一条通栏 `line` 分割线后 4 就是资产牌描边，两条线挤在一起（docs/46 §3.3 只在少数地方画线）。
5. 资产牌「管理」胶囊字是 `meta` 13 / 400，地址是 `caption` 14：同一行两种字号。
6. 「社区」分区内「我加入的 / 我创建的」用 `LoopLabel(tight)` = 18 / 700 Chalk，与上层分区标签同级。
7. 他人主页的空态（持仓、交易、社区、未公开、无钱包）各带一句解释（「对方的钱包里暂时没有可显示的资产。」等），违反决策 0248；「我的 · 交易」空读的 `LoopChainStateBlock` 也带「索引器已经读到这个区间……」。

## Decision

- **上层 = 页签**：`LoopProfileSectionsBar` 改为 `headline` 18 / 700 文字页签——选中 Chalk、未选 auxiliary ink，选中词下 3px × 24 黄短线（docs/42 附C §4「顶部页签」，与 `LoopSegmentedTabPage` 同形态，字号低一档）；无胶囊、无紫色、无喷点；首字落在页边距 20；上方 24；每个页签 ≥ 44 × 44；短线动画在 reduced motion 下为 0；切换给选择触感。「我的」与他人主页共用，两页同构不变。
- **下层 = 筛选**：`WalletAssetTabs`（代币 / NFT）与「我的 · 交易」的五个筛选改为带底色的筛选胶囊（非 quiet `LoopSeg`，`label` 14 字，胶囊高 32 = `WalletAssetTabs.filterHeight`），选中仍紫实心 + 喷点（决策 0221 / 0222 不变）；页签短线到胶囊 16（`segmentGap`）；筛选从页边距 20 起，胶囊间 8。`tx-history` 页自己的筛选条不变（`activityTapeSections(underTabs:)` 只对「我的」开）。
- **快捷键**：左右 20、两端对齐页边距，`spaceBetween` 均分；方键边长 = min(56, (可用宽 − 12 × 4) / 5)：390 宽 56、360 宽 54（键距 12）。底色、图标、字号、key 不变。
- **身份卡**：「＋ 添加个人简介」贴在 LOOP ID 下 6（点击区仍 44）；关注 / 粉丝首个数字落在页边距；去掉通栏分割线，资产牌上方改 16。名字仍 `displaySm`（docs/46 title1，「个人主页名字」，测试钉住）。
- **资产牌**：「管理」字改 `caption` 14 / 600，与地址同字号、比地址亮一档。
- **社区分组标签**：「我加入的 / 我创建的」降为 14 / 700 灰（`LoopKicker` + auxiliary ink），上 16 下 4；只有一组时列表在短线下 8 开始。他人主页分区同样在短线下 8 开始。
- **空态**：他人主页五处空态去掉说明句，只留标题事实（「还没有持仓」「还没有交易」「还没有加入社区」「对方未公开持仓」「对方暂无钱包」）；「我的 · 交易」空读不带 `emptyReason`。

## Consequences

- 改动只在 widget 层：`lib/widgets/loop_profile_sections.dart`、`lib/features/wallet/wallet_home_widgets.dart`（`WalletQuickActions`、`WalletAssetTabs`、`WalletManagePill`）、`lib/features/wallet/wallet_read_screens.dart`（「我的」资产牌边距、`activityTapeSections` / `_ActivitySegments` 的 `underTabs` 分支）、`lib/features/profile/profile_v2_screens.dart`（`ProfileIdentityCard`、`MeCommunitiesSection`）、`lib/features/social/public_profile/user_profile_screen.dart`（空态与分区间距）。View model / gateway / codec / 路由表未动；未新增字体与依赖。
- 共享组件：`LoopSeg` / `LoopSegBar` 本身未改；`WalletAssetTabs` 只有「我的」在用；`activityTapeSections` 与 `tx-history` 共用，`tx-history` 外观不变。
- 测试：`test/s349_me_profile_structure_test.dart` 的「分区条是 `LoopSegBar`」改为「是 `LoopProfileSectionsBar`、其下无 `LoopSegBar`」；夹具挪到 `test/support/me_page_fixtures.dart`（新增他人主页夹具）；`test/s350c_shots_test.dart` 只在 `LOOP_SHOTS=true` 时出图（改前 / 改后各 390，改后另 360）。
- 未做：持仓行下「发送 / 兑换」小按钮（决策 0188，docs/46 §7 建议删，待主代理定）；他人主页导航栏标题与头部名字重复（改标题属页面元信息，未动）；交易日期组头上方留白（`WalletActivityDayHeader` 与 `tx-history` 共用）。
