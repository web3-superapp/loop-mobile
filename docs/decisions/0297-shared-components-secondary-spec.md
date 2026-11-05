# 0297 · 共享组件收口：二级页扫描报出的共享件偏差 + 空态动作按钮

## Status

Accepted · 2026-11-05（S371-mobile，基于 integration/v2 d6197ebe，已含 S370a / b / c）。来源：S370a / b / c 三份扫描（决策 0293 / 0294 / 0295）「需要改共享件」各节，主代理派单；外加需求方 11-05 16:52 反馈（MEME 首页「预告 / Upcoming」空态下的黄色大 CTA「Launch a tok…」太大且被省略号截断）。规范 `docs/58` §9 为准。本批允许改 `lib/widgets/` 与主题 token，每条都核过调用方。

## Context

0277 把字体 / 色 / 圆角经 token 下发后，三份二级页扫描发现剩余偏差集中在共享件的**默认值**与**缺参数**：默认边距 16、`LoopRecordRow` 行高写死 72 / 80 + 上下 13 + 标题写死、`LoopRecordGroup` 不透传 `divider`、`LoopPersonRow` 无分割线参数、`LoopEntryIcon` 只有圆底、表单搜索框各写一份、抽屉标题 22 / 700（稿无此档）。页面批次（S370a / b / c）按规定不能动这些，留到本批。

## Decision

### 1 · 默认边距 16 → `LoopSpacing.page`（20）

| 组件 | 现状 | 稿值 | 影响范围 |
| --- | --- | --- | --- |
| `LoopNotice`（两个构造） | margin (16, 0, 16, 14) | (20, 0, 20, 14) | 约 125 处默认调用（警示 / 危险卡等）随之左移 4 |
| `LoopSegBar.padding` | (16, 0, 16, 8) | (20, 0, 20, 8) | 用默认值的分段条 |
| `LoopErrorState.margin` | symmetric(16) | symmetric(20) | 全部错误态 |
| `LoopOfflineState.margin` | (16, 0, 16, 14) | (20, 0, 20, 14) | 全部离线态 |
| `LoopPermissionState.margin` + 内部按钮行 ×2 | 16 | 20 | 全部权限态 |
| `LoopPowerHint` | 外边距 16 | 20 | 算力提示条 |
| `LoopLoadMoreFooter.padding` | (16, 12, 16, 0) | (20, 12, 20, 0) | 分页尾 |
| `LoopProvenanceLine` 的来源抽屉（`showLoopProvenanceSheet`） | 抽屉内容 16 | 20（与 `LoopSheetHeading` 同线） | 所有来源 (i) 抽屉 |
| `LoopInfoSheet`（说明段、页脚） | 16 | 20 | 所有 (i) 说明抽屉 |
| `loop_provenance_scope.dart` 四处（页脚、说明段、小节标题、两个键值行） | 16 | 20 | 来源说明抽屉 |
| `loop_sign_steps.dart` 步骤条 | (16, 4, 16, 8) | (20, 4, 20, 8) | 签名步骤条 |
| `LoopComposer` 底栏（任务书写作「`LoopButtonPair` 抽屉底栏 (16, 10, 16)」——共享件里唯一的 (16, 10, 16) 就是它） | (16, 10, 16, safe) | (20, 10, 20, safe) | 社区 AI 页（唯一调用方） |
| `Launch2BarShell`（MEME 详情 / 交易底栏，同为 (16, 10, 16, 10)） | 16 | 20 | MEME v2 详情 / 交易底部操作栏 |
| 调用方显式 16：`group_screens.dart` 群范围脚注 | (16, 0, 12, 0) | (20, 0, 12, 0) | 群聊头部脚注 |
| `loop_atmosphere.dart` 两处（`LoopAtmoEmpty` 内边距、`LoopChromePlate.padding`） | 16 | **保持 16，改写成 `LoopSpacing.card`** | 无视觉变化，见「取舍」 |

`LoopButtonPair` 本身早已是 `LoopSpacing.page`，未动。

### 2 · `LoopRecordRow` 行高与字阶可配

| 项 | 现状 | 稿值 / 本批 | 影响范围 |
| --- | --- | --- | --- |
| 行高 | 写死 72 / 80（有副行），扁平页 56；上下 13 / 8 | 新增 `kind: LoopRecordRowKind`（`token` 71 / `person` 67 / `community` 86 / `function` 56 / `holdings` 51，上下 6，高度含自身分割线）；`null` = 原样 | 只影响传了 `kind` 的行 |
| 标题字阶 | 写死 `LoopType.title` | 新增 `titleStyle`（`null` = `LoopType.title`） | 只影响传了的行 |
| `trailingBadge` | 不可收缩，长英文徽章会把行撑出宽度 | 槽位上限 = 行宽 − 头像 56 − 间距 − 箭头 − 标题保底 48（`badgeTitleReserve`；行宽按屏宽减页边、组内再减卡内 16），超出才压缩（`LoopBadge` 自带省略）；更窄的徽章原样 | 全部 76 处徽章调用；只有原本超宽的会变 |

接上的行：

| 页面 / 行 | 改前 | 改后 | 依据 |
| --- | --- | --- | --- |
| 社区首页「已加入」 | 72 / 80 | `kind: community` 86 | §9.4 社区行 |
| 发现社区目录行（`communityDirectoryRow` 两个分支） | 82 | 86 | §9.4 社区行 |
| 聊天搜索命中 | 80，名 14 / 500 | 67，名 `rowTitleLg` 16 / 500 | §9.4 会话行 |
| 转发页目标 | 80，名 14 / 500 | 67，名 `rowTitleLg` | §9.4 会话行 |
| 黑名单 | 80，字母头像 44 | 67，字母头像 48 | 类推会话行 |
| 建群选好友 | 80 | 67（头像 48 已由 0294 改） | 类推会话行 |
| 我的项目列表（两种行） | 头像 36，80 | 头像 44 圆，`kind: token` 71；英文状态徽章在 360 / 390 都不再溢出 | §9.4 代币行（推翻 0293 的 36 暂定） |
| MEME v2 钱包持仓行（`launch2_wallet_rows.dart`） | `LoopQuoteRow` 默认 80、币标 `memeCardLogoSize`、值 `figure` 16 | `height: LoopRowHeight.holdings` 51、币标 36、`valueStyle: figureSm`、副值 `caption` 次字（同 0280 / 0295 参数） | §5.13 |

### 3 · `LoopRecordGroup` 分割线

| 项 | 现状 | 本批 | 影响范围 |
| --- | --- | --- | --- |
| `_rowsColumn` 重建行 | 丢 `divider`（以及新参数） | 透传 `kind`、`titleStyle`、`divider` | 全部 `LoopRecordGroup(rows:)` |
| 组内分割线 | 无 | 新增 `divided`（默认 `true`）：行与行之间画 1px 白 5%，**最后一行下不画**（卡底边已收口，避免重线）；线算在行高里（扁平功能行仍 56） | 约 85 处功能行组（设置、安全中心、关于、支持、接收、资产页、MEME 旧页、行情入口等） |
| 持仓 / 榜单组 | — | 传 `divided: false`：资产选择抽屉两组、算力构成两组 | §9.4 持仓不画线 |
| `LoopRecordGroup.children` | 原样画 | 不变（子件自带位置与状态） | — |

### 4 · `LoopPersonRow` 与 `LoopEntryIcon`

| 项 | 现状 | 本批 | 影响范围 |
| --- | --- | --- | --- |
| `LoopPersonRow.divider` | 无 | 新增，默认 `false`；线算在 `height` 里，跨内容宽（左右 = `padding`） | 只影响传了的行 |
| `LoopPersonRow.padding` | 写死 (20, 8) | 新增，默认 (20, 8) | 只影响传了的行 |
| `LoopEntryIcon.shape` | 只有圆、card2 底 | 新增 `LoopEntryIconShape.square`（r9，`LoopRadius.glyphGround` 新 token），默认圆 | 只影响传了的 |
| `LoopRowIcon` 在扁平页的字形底（非 `circle`） | 40 圆 | 40 **r9 方**（功能行）；`circle: true` 的记录标记仍圆；字母头像不变 | 扁平页功能行组（设置 / 安全 / 关于 / 支持等） |

接上的行：管理中心 8 个功能行（线 + 方底）、社区主页社区 AI 入口 / 退出社区两态（线 + 方底）、成员行、关注与粉丝行、私信请求行、搜索里的代币 / 社区 / 用户结果与最近代币（线 + 上下 6，借 `SecondaryRowMetrics.rowPadding`）。管理中心 / 成员页的**抬头社区行**是单行页头，不画线。

### 5 · 搜索输入框统一

新增 `loopSearchFieldDecoration()`（`lib/widgets/loop_search_entry.dart`，与 `LoopSearchEntry` 同一张脸）：44 高（无错误文字时上下限都 44）、r12、`searchBg` 底、1px `cardEdge`、占位 `searchHint` 15 / 500、20 放大镜（可关、可换成提交键）、聚焦紫边（0254）。主题 `InputDecorationTheme` **不动**——它管所有表单字段，改它会把表单也变成搜索框。

| 调用方 | 改前 | 改后 |
| --- | --- | --- |
| 成员搜索 `community_members_screen.dart` | 主题字段 + 浮动 label + 说明 hint | 共享搜索框；label 文案作占位，说明 hint 不再显示（docs/46 / 0248 不加说明句） |
| 群改名 `group_screens.dart` | 主题字段 + 浮动 label | 共享搜索框（无放大镜），label 文案作占位，错误文字保留 |
| 聊天搜索 `chat_search_screen.dart` | 本地 card 底 + line 边 + 16 放大镜 | 共享搜索框 |
| 群别名搜索 `group_alias_screen.dart` | `loopFormFieldDecoration` 52 高 | 共享搜索框（旁边已有搜索键，无放大镜） |
| 资产选择抽屉 `money_asset_picker.dart` | 主题字段 | 共享搜索框 |
| 全局搜索 `search_screen.dart` | 0294 本地写的一份 | 共享搜索框，放大镜仍是提交键（key `search-submit` 不变） |

「好友搜索」：工作树里没有独立的好友搜索输入框（加好友走全局搜索 / 扫码），`friend-group-name-input` 是分组名表单字段，未改。

### 6 · 抽屉标题

| 项 | 现状 | 本批 | 影响范围 |
| --- | --- | --- | --- |
| `LoopSheetHeading` | `heading` 22 / 700 | `headline` 19 / 700（§9.2） | 全部共享抽屉标题 |
| `LoopSheet.title`、`LoopSignSheet` 标题 | 22 / 700 | 19 / 700 | 全部签名出口与带标题抽屉 |
| 抽屉内自画标题：DApp 风险提示抽屉、DApp 地址抽屉、DApp 连接抽屉、MFA、Passkey | 22 / 700 | 19 / 700 | 这 5 个抽屉 |
| 页面里的 `heading`（DApp 风险整页、部署进度状态、开户钱包创建标题） | 22 / 700 | 不动（不是抽屉） | — |

`LoopLabel` 分区标题本批不动。

### 7 · 空态动作按钮（需求方 11-05 16:52）

新增 `LoopEmptyActionButton`（`lib/widgets/loop_atmosphere.dart`）：§9.4 次按钮——面 36 高（单行）、r8、白 8% 底、字 `body1` 14 / 500 主字、左右 16、宽随文字、不超过内容区；**不省略**（不设 `maxLines`，过长换行、面随之变高）；触控区仍 ≥ 44；居中，与标题间距 16。

- `LoopAtmoEmpty`：原 `LoopYellowButton`（44 高、最宽 160、单行省略，所以「Launch a token」被截成「Launch a tok…」）换成它。
- `LoopEmptyState`：`action` 外包 `LoopEmptyActionScope`，其中的 `LoopButton`（不论调用方给的 primary / block）都画成同一张脸；key、点击、语义不变。标题 → 动作间距由 20 / 14 统一为 16。
- 受影响的空态页面：MEME 首页「预告」空态（`launch2-upcoming-empty-launch`）、聊天列表空态「找朋友」（`stream-chat-empty-find-friends`）、MEME v2 列表空态（`launch2-*-empty-action`）、MEME 旧版发射台 / 创建页空态、算力榜邀请空态（`intel_rank_board.dart`，本批未改该文件，靠共享件生效）、聊天列表失败重试、语音房返回、群别名重试、建群好友失败 / 空、广场语音房空态、钱包无钱包 / 无激活钱包、兑换无主网余额、行情自选空、价格提醒空、自选管理分组空 / 无分组、Loop ID 空、未知路由页。

### 8 · 未做（记录）

- `LoopRecordGroup` 列表行去卡底（稿的行直接落在页面上）：结构变化，等需求方稿。
- `LoopFolioPrimary`（NFT 页、曲线代币页状态卡）：稿无对应件。
- `LoopTypography.figure(20)` 一处：未动。
- `LoopRowIcon` 扁平页功能字形底的尺寸：形状已改 r9 方，尺寸仍 40（稿 34），尺寸变化会影响约 40 个调用的行宽，留给下一次页面批次逐页核。
- 预览夹具（`conversation_pages.dart` / `chat_secondary_pages.dart`）按 0294 仍不动（harness 指纹）。

## 取舍

- **atmosphere 两处没改成 20**：`LoopAtmoEmpty` 板和 `LoopChromePlate` 自身已在 20 页边上（`LoopAtmoBoard` / plate 的 margin），那两个 16 是**卡内**边距（§9.4 卡内 16），改 20 会让内容缩进到 40。按卡内 token 改写为 `LoopSpacing.card`，视觉不变。
- **组内分割线不画最后一行**：组是一块 r12 卡，最后一行下再画线会和卡底边形成双线（「核几页截图确认不重线」）。§9.4「每行都画」解读为行间都画。
- **线算进行高**：`kind` 行与组内行画线时最小高减 1，保证 56 / 67 / 86 是含线总高（与 `LoopRowHeight` 文档一致）；不在组内、没传 `kind` 的老行传 `divider: true` 时仍是旧行为（行高 + 1）。
- **徽章上限按行内剩余宽算，而不是固定比例**：先试了与右侧数值列同样的 0.42 屏宽，安全中心「(i) + 状态徽章」组合（约 187 宽）被压到溢出；再试 0.6 屏宽，我的项目行（组内行宽只有 318）仍溢出 3px。最后按「行宽 − 头像 − 间距 − 箭头 − 标题保底 48」算，两处都不溢出。没用 `LayoutBuilder`，因为选中行外层是 `IntrinsicHeight`，`LayoutBuilder` 不支持固有尺寸。
- **空态按钮通过作用域让 `LoopButton` 变脸**，而不是逐个改 20 个调用方：保留调用方 key 与测试句柄，新增空态自动跟随（与已有 `LoopCompactButtons` 同一做法）。
- **搜索框不改主题**：主题字段同时服务表单，统一放在 `loopSearchFieldDecoration()`。

## Consequences

- 新增公开 API：`LoopRecordRowKind`、`LoopRecordRow.kind / titleStyle / badgeTitleReserve`、`LoopRecordGroup.divided`、`LoopPersonRow.divider / padding / dividerKey`、`LoopEntryIconShape` + `LoopEntryIcon.shape`、`LoopRadius.glyphGround(Value)`、`loopSearchFieldDecoration()`、`LoopEmptyActionButton`、`LoopEmptyActionScope`、`SecondaryRowMetrics.rowPadding`。
- ARB、路由、key、view model、gateway、codec 未动；lockfile 未变；`intel_rank_board.dart`（S372）未动。
- 测试：新增 `test/s371_shared_components_spec_test.dart`；旧断言按有意改动更新见提交说明。
