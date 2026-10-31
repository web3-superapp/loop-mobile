# 0255 · UX 问题表全局组件：按钮三级、空态统一、口径入口一页一个

## Status

Accepted · 2026-10-31（S325-mobile）。

## Context

需求方 UX 设计师 2026-10-28 交来「UX问题跟踪」18 条（存档 `LOOP/docs/evidence/ux-2026-10-31/`，主代理处置 `LOOP/docs/51-UX问题跟踪处置-2026-10-31.md`）。本批负责其中落在共享组件上的五条：UX-007 按钮、UX-003 空态、UX-009 ⓘ 小圆点、UX-011 卡片、UX-018 排行进度条。页面级重排归 S326 / S327，输入框与 toast 归 S324。

## Decision

### 一、按钮（UX-007）

- **统一圆角 token**：所有按钮用 `LoopRadius.button`（12）。不再有纯胶囊 / 全圆的按钮：MEME 首页「发射」（`Launch2LaunchCapsule`）由 `LoopRadius.pill` 改为 `LoopRadius.button`。
- **三级**（`LoopButtonRank`，由 `LoopButton.primary` / `assist` 决定）：
  - 主按钮：黄底（`LoopColors.yellow`）黑字（`LoopColors.ink`）；
  - 次按钮：深灰底（`LoopColors.card2`）白字（`LoopColors.chalk`）；
  - 辅助按钮（新增 `assist: true`）：更弱的灰底（`LoopColors.assistFill` = Chalk 8 %）灰字（`LoopColors.text2`）。
  - 「生成海报」原为黄字暗黄底，与标签重复；`LoopPillAction(soft: true)` 整体改为辅助按钮样式（同时影响广场「加入」等同类行内按钮）。
- **尺寸档**（`LoopButtonSize`）：`regular` 48 高、两侧 23；`compact` 可见面 32 高（`LoopTouch.compactButton`）、两侧 12，外围仍是 44 触控区。`LoopNotice` 的 trailing 与 `LoopRecordRow` 的 trailingBadge 内的 `LoopButton` 自动取 compact（`LoopCompactButtons`），所以推送「开启」等行内小按钮不再沿用大按钮边距；搜索页「粘贴」由胶囊 `LoopSeg` 改为 compact 次按钮。`LoopPillAction` 也取 32 高、两侧 12。
- **不发光**：按钮一律无发光阴影。`LoopYellowButton`（聊天空态「找朋友」等）与「发射」去掉黄光。
- **图标按钮**：标题栏里的每个控件统一为「图标 + 深色方底」（群组页的样式）：`LoopTopbar` 的返回键恒为 framed，`actions` 与 `LoopTabSegments` 的 actions 外包 `LoopTopbarScope`，其中的 `LoopIconButton` 一律 framed。聊天铃铛、发起发射页的人形、验证邮箱返回键随之统一，无需改各页。字形尺寸维持 19。`LoopTopbar.framedTools` 保留参数但不再改变外观。
- **开关**：`LoopFlatSwitch` 给 thumbIcon 一个空图标，Material 3 关闭态圆点不再缩小，开 / 关圆点同大。

### 二、空态（UX-003）

- 默认空态图统一为现有涂鸦皇冠（`atmo-crown-flat.png`）灰度 45 %（`LoopEmptyArt`）；原线性黄白小图标不再绘制。`LoopEmptyState.illustration` 改为可选、仅表示「这是什么集合」；需要别的图时用新增的 `art` 槽替换。
- 结构统一为「主标题（`loop-empty-title`）+ 一句描述（`loop-empty-message`）」，至多一个动作。`LoopAtmoEmpty` 新增可选 `title`；只给一句时这句按主标题样式绘制。描述只写事实一句，不写教程。
- 皇冠裁切：素材本身在底边（两条滴漆处）被截断。`LoopEmptyArt` 按素材自身宽高比（115:109）给足盒子，并把底部 22 % 渐隐，滴漆自然收尾，不再出现硬切边。

### 三、口径入口「一页一个」（UX-009）

- 「来源」是数据口径披露入口（AGENTS 第 25 条），保留功能，只收拢位置：**每个页面只有一个 ⓘ，放在页面标题栏最右侧**。
- 实现：页面骨架（`LoopFocusPage`、`LoopDashboardPage` 非嵌入、`LoopStreamPage` 非嵌入、`LoopTabSegments`）外包 `LoopProvenanceScope`。在 scope 内，`LoopProvenanceLine`、`LoopProvenanceFooter`、`LoopFactLine` 的来源、`LoopInfoButton`（含 `LoopInfoLabel` 里的、安全中心每行的、大额二次验证行的）以及钱包占位页与行情持有人的「(i) 说明 / 来源」不再在页内绘制，而是登记一条 `LoopProvenanceEntry`；标题栏的 `LoopPageInfoAction` 有内容时才出现，点开一个 sheet，按登记顺序分段列出各处原来的来源 / 观察时间 / 说明。
- 已有标题栏 ⓘ 的页面（我的挖矿「挖矿说明」）改用 `LoopPageInfoAction` 并带上自己的说明与「查看挖矿规则」，页内的「ⓘ 来源」合并进同一个 sheet；标题栏不会出现第二个 ⓘ。
- 页面 ⓘ 的触控区 48（`LoopIconButton.target`），可见方底仍 44：它常是标题栏唯一控件，需单独满足 Android 48 dp 指南。
- 质量标记（如「未更新」）按 AGENTS 第 25 条仍留在数据旁，只去掉圆点。
- 行内 ⓘ：能用文字说清的直接用文字——钱包「产生算力」标签去掉后面的 ⓘ，标签本身可点；安全中心各行的状态 chip 已是文字，行内 ⓘ 并入页面入口。
- 不在页面骨架里的地方（底部 sheet、聊天消息里的代币卡、自绘页头的页面）没有标题栏可并，保留原来的单个「(i) 来源」，内容不丢。

### 四、卡片（UX-011）

- `LoopRecordRow` 右列（数值 + 单位）不再是第二个 Flexible：原来它分到半行并停在那半行的起点，「0 / 算力」落在卡片中间。改为最大宽 42 % 的右列，数值与单位右对齐到卡片右边缘。
- `LoopKeyValue` 的值列改为 Expanded，右对齐的值贴在卡片右边缘（社区「社区挖矿」卡左右两端对齐）。
- 可点卡片（`LoopRecordCard` / `LoopSurfaceCard`）去掉按住时的紫色描边，并关闭 hover / focus 高亮；按压只保留墨水高亮。

### 五、排行进度条（UX-018）

- `IntelRankRow` 去掉「占第一名」进度条与 `share` 参数，只留数字；用户榜、社区榜、推广榜同时生效。`intelRankShare` / `intelRankShareBarWidth` / `intelRankLeaderAmount` 删除。

## Consequences

- 改的是共享组件，全局受益；页面文件只改了 ⓘ / 来源调用行与按钮调用行，未重排页面。
- 跨批次目录被动过的文件：`features/launch2/creator/launch2_creator_entry.dart`（发射按钮圆角与发光）、`features/mining/mining_screen.dart`（标题栏 ⓘ 改 `LoopPageInfoAction`）、`features/wallet/wallet_home_widgets.dart`（产生算力去 ⓘ）、`features/wallet/deferred_screens.dart`（说明并入页面 ⓘ）、`features/profile/notification_preferences/notification_preferences_screen.dart`（开启按钮 compact）、`features/intel/intel_rank_board.dart`、`features/intel/intel_referral_board.dart`（进度条）。
- 既有测试中点按页内「(i) 来源」的断言改为 `openPageInfo`（`test/support/provenance_finders.dart`）点标题栏的页面 ⓘ；`findProvenanceContaining` 同时匹配已并入标题栏的条目（`LoopProvenanceHosted`）。空态测试仍可按 `loop-empty-illustration-<集合>` 识别是哪一种空态（键保留在皇冠外层）。
- 未做：钱包总资产旁的 ⓘ（打开自定义的总资产说明 sheet，不是 `LoopInfoNote` 结构；UX-015 钱包卡重排归 S327，届时一并收进页面入口）；聊天收件箱空态的文案拆成「标题 + 描述」需改聊天页文案，归 S326。

## Verification

2026-10-31，S325-mobile（基于 integration/v2 62c1129c），SDK 为仓库钉住的 Flutter 3.47.1：

- `pub get --enforce-lockfile`：通过，锁文件未变。
- `dart format --output=none --set-exit-if-changed lib test`：1029 个文件 0 处改动。
- `flutter analyze`：No issues found。
- `flutter test`：5972 项通过、33 项跳过（基线 5955 / 33）。
- `scripts/check_harness.py` 仍报的项（Reown、D0、共享偏好、0246 文档、`intel_rank_board.dart` 的 fontSize、s307 / s315 未挂 ground probe）均为基线已有，本批未新增。
- 未做真机验证。
