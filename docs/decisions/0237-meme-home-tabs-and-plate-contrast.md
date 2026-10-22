# 0237 · MEME 首页改 Tab 切换 + 全局分块底色两级（S279-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 1274db1c（S276 合入后）。主代理下单 S279-mobile。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api。

## Context

需求方 2026-10-22 验收反馈：

- 第 15 条：「不要一个页面展示全部的代币列表 做成tab栏切换 右上角icon加粗加大 发射按钮可以做到右上角icon位置」。
  现状：MEME 首页（`Launch2ListSegment(scope: all, tabTitle: 'MEME')`）在主事件 pager 与成交 ticker 下面放一排阶段 chip（铸造中 / 内盘 / 预告 / 已毕业，点了滚动到下方对应段），然后把「01 内盘 / 02 预告 / 03 已毕业 / …」按组叠在一个滚动页里（`Launch2SectionHeading` + `Launch2Board`）；右上角是两个 19 号细线 icon（user「我的项目」、plus「发起」），「我要发射」只在预告空态里。
- 第 16 条：「全局有模块划分的 背景颜色调整 目前有的深有的浅色 深色看不出模块 浅色又太突兀」。
  盘点（`lib/core/theme/loop_theme.dart`）：块底只有一种 `#111114`（`graphite` = `card` = `panel` = `input`，`recordCardGlow/Tint` 同值），与页面 Ink `#09090B` 只差 8 级，放在氛围层墙面上基本看不出块；次级 `card2 #1C1B22`。偏浅的来源：聊天列表的磨砂板 `loopChatBoardFill`（Chalk 10% 叠 Ink 35%，合成 `#414143` @ 41.5%，在墙上是一块浅灰）、镀铬牌（钱包「总资产」、情报「我的名次」）的近白色 chrome1 `#F0F0F3` 斜边。另外决策 0126 / 0229 让 `LoopRecordGroup` 行「无底、无线」，安全中心、设置、钱包工具列表等分组在页面上只靠标题分段，块根本没有底色。
  写死颜色：`LoopDripBar` 轨道 `#24232A`（已改 Token）；`#0E0D12` 三处是横幅图片下的垫底，不是块底，保留。

## Decision

### 一、MEME 首页三个 Tab

1. 顶部保留主事件 pager 与成交 ticker；原阶段 chip 换成 `Launch2DeskTabs`：「01 内盘 / 02 预告 / 03 已毕业」三等分胶囊条（底为块底色，选中紫底白字、编号黄色 + 黄色喷点；标签 `LoopType.button` 16，编号新增字阶 `LoopType.tabIndex` = Anton 18），每个 Tab 只显示自己的一个列表。原来每段的大号编号标题 `Launch2SectionHeading` 删除，编号挪进 Tab 标签做氛围元素，页面不再出现重复标题。
2. Tab 归属：`Launch2DeskTab`（`launch2_launchpad.dart`）。**内盘** = 铸造中 + 提前购 + 内盘 + 名单生成中 + 已暂停 / 无人铸造（每行自带阶段胶囊，组内顺序沿用 `launch2GroupRows`，关闭行沉底）；**预告** = upcoming；**已毕业** = `stage=graduated` 独立分页列表（`Launch2ListScope.graduated`，首次切到该 Tab 才读，Tab 内加载 / 空 / 错误三态，行点进项目详情，不再跳单独页）。计数：内盘 = 铸造中 + 内盘（overview 有数用 overview，否则数已读行），其余同原 chip。
3. 主事件的记录卡放在它所属 Tab 的顶部，其行不重复画。各 Tab 空态：预告保留原文案与「我要发射」；已毕业用原文案「还没有毕业的 v2 项目，内盘卖满后自动建官方池，会出现在这里」；内盘新增一句「现在没有铸造或内盘中的项目，开售后会出现在这里」。只要还有下一页没读，就不显示空态而由加载哨兵继续读。
4. 记住位置：所选 Tab 存在 `loopTabSegmentMemoryProvider` 的 `meme-desk` 键（与 Tab 页分段同一份记忆，进详情返回、切别的主 Tab 再回来都保留）；每个 Tab 离开时记下滚动位置，回来恢复；没看过的 Tab 若读者已滚过 Tab 条，则把 Tab 条停在顶部。下拉刷新仍读首页 + overview + 活动卡，在已毕业 Tab 时同时重读已毕业列表；60 秒轮询同理。
5. 默认 Tab：主事件所在 Tab；无主事件时第一个有项目的 Tab；都为 0 时内盘。
6. IDO 开关开启时外层仍是 `LoopSegmentedTabPage`（发射台 / IDO，可横滑），内层 Tab 只响应点按、不加横滑，记忆键也不同（`meme` vs `meme-desk`），两层互不干扰。
7. 右上角：「我的项目」改成 24 号加粗 glyph（`Launch2BoldIcon`：同一 1.7 笔画的 sprite 以 ±0.45 px 叠画五次，不新增图标资产），44 触控；「发起」plus 改为主色胶囊「发射」（`Launch2LaunchCapsule`：黄底、火箭 + Ink 字、36 高胶囊、44 触控），放最右；行为不变（classic 关闭时直接进创建页，开启时弹 v2 / 经典选择）。空态的「我要发射」保留。

### 二、分块底色两级

1. 新增 `LoopColors.plate #1A1920`（一级块底）与 `LoopColors.plateRaised #26252D`（二级：块内子块、输入框、icon 底、次按钮）。`card` / `panel` / `recordCardGlow/Tint` → `plate`；`card2` / `input` → `plateRaised`；`InputDecorationTheme.fillColor` 从 `card` 改为 `input`。对比：plate 比 Ink 高 17 级，plateRaised 再高 12 级；`muted #8E8A98` 在 plateRaised 上对比度 > 4.5。
2. `graphite #111114` 保留为「浮层面」：底部弹层、对话框、`ColorScheme.surface`、底部 Tab 栏（`loopTabBarGround` 不变）。弹层里的块因此也能看出来。
3. `LoopRecordGroup` 成为一块：页边距内 plate 底、16 圆角、裁切；组内行（普通与 Flat 两种语态）水平内距改为 `LoopSpacing.card` 16，按压高亮在块上用 `card2`。单独的 `LoopRecordRow`（不在组里）不变。这是共享组件里唯一的结构改动，`LoopNotice` / `LoopDisclosure` 实现未动。
4. 偏浅的两处收回：聊天磨砂板 `loopChatBoardFill` 改为 plate @ 92%（墙面只隐约透出，和其他块同一层级）；镀铬牌斜边起点由 chrome1 近白改为 chrome2 中灰（`LoopChromePlate.bevelColors`）。
5. 写死颜色：`LoopDripBar` 轨道 `#24232A` → `LoopColors.card2`。

## Consequences

- 视觉：全 App 所有 `card` / `card2` / `input` / `LoopRecordGroup` 一起变化（钱包持仓卡、工具列表、操作按钮底，安全中心 / 设置 / 我 等二级页分组，MEME 项目卡、launch2 详情各块、聊天列表、邀请页块——邀请页文件未改，仅随 Token 生效）。设计稿对照截图：`docs/integration/S279/shots/`（`before/` 为改前），由 `test/s279_shots_test.dart` 生成（`--dart-define=LOOP_SHOTS=true`）。
- 未覆盖：安全中心「交易验证 · 大额交易二次验证」是单独一行（不在 `LoopRecordGroup` 里），仍无块底；该文件在别的批次手里，本批不改，需要时把它包进 `LoopRecordGroup` 即可。
- 验证：`flutter analyze` 无问题；`dart format` 无改动；全量 `flutter test` 5665 通过、16 跳过（截图用例默认跳过）；`scripts/check_harness.py` 通过。
- 测试：新增 `test/s279_meme_tabs_and_plate_test.dart`（Tab 归属 / 计数 / 默认 Tab 纯函数；只显示当前 Tab；已毕业首次切换才读、行进详情；Tab 记忆跨重建；已毕业 Tab 加载 / 空 / 离线；内盘空态；IDO 嵌套不动外层分段；右上角 24 号 glyph 与黄色「发射」胶囊、classic 关闭直达创建页；launch2 关闭无入口；两级底色 Token 关系与对比度；`LoopRecordGroup` 块底与 16 内距）。更新：`s136`、`s182`、`s184`、`s264`、`s269`（MEME Tab 字号 16）、`s265`、`s265d`（磨砂板 92%）、`s265e`（Tab 栏仍为 graphite）。
- 删除：`Launch2SectionHeading`、`launch2DeskSections`、`launch2RevealGroup`、`Launch2ListSegment.onOpenGraduated`（只有测试在用）。`Launch2StageChips` 组件保留（未再用于首页）。
- 待主代理 / 需求方确认：内盘 Tab 合并了铸造中（NFT 预售）与名单生成中、已暂停——需求方原话是三个 Tab，若要「铸造中」单独成 Tab，加一个 `Launch2DeskTab` 值即可。
