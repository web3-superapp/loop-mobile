# 0271 · 页面精简：聊天去分段、钱包 Tab 改「我的」、设置删减

## Status

Accepted · 2026-11-03（S343-mobile）。依据 `LOOP/docs/56-页面精简-需求方脑图-2026-11-03.md` §二「聊天」「我的」。情报·算力（S344）与 MEME（S345）并行，不在本批。

## Context

需求方脑图（Loop.xmind）要求减少二级页面：聊天去掉「全部 / 社区 / 好友」分段，添加放右上角、通知与陌生人请求放到「我的」；钱包改成「我的」并与「我」融合，底部跨链 / 代币授权 / 网络去掉，分享名片放主页，扫一扫与挖矿去掉，账号相关放到一级页面，其余留在设置。主代理在 docs/56 §二给出落地方案。

## Decision

### 聊天

- 删 `ChatInboxFilter` 与 `LoopSegBar`、`ChatInboxFilterEmptyGate`、`chatInboxFilterLeftNothing`。同一个 Stream 列表按 `ChatInboxSection`（`社区` / `好友`）分两节：节标题画在每节第一行上方，节内保持 Stream 顺序（置顶在前、再按最新消息）；CID 认不出的会话归「好友」。行仍是 `ChannelListView` 的分页与未读，不重查询（`chatInboxSectioned` 只重排，同一列表对象只算一次）。墙面卡板按节各成一块。
- 左上头像入口、铃铛、底部浮动「发起」与其滚动隐藏逻辑删除；右上角只放「＋」（原「发起」面板原样：搜索 / 添加用户、创建社区、创建群聊、扫一扫）。列表底部留白 = 浮动 tab 栏保留区（`chatInboxListBottomPadding`，原 88 发起键间距去掉）。
- 陌生人请求行移到「我的」（`MeMessageRequestsEntry`，key 不变）。

### 我的（原钱包 Tab，slug / 路径 `/wallet` 不变）

- Tab 文案「我的」、图标 `user`（现有 sprite），选中动效：轻点头放大。未读通知 > 0 或有待处理陌生人请求时 Tab 右上 8 dp 红点（`LoopShell.attention`；读数由 `LoopMeAttentionReader` 在壳层发起：未读数首次与回前台时读，最多一分钟一次；预览构建不读陌生人请求）。
- 页面自上而下：标题「我的」，右上 交易历史 / 通知（铃铛带角标，key `me-notification-bell`）/ 设置；身份卡（头像、昵称、LOOP ID 复制、分享名片图标、已关注 / 粉丝、奖励；资料加载中显示本机存的头像与昵称）；陌生人请求行（仅有待处理时）；总资产卡 + 接收 / 发送 / 兑换 / 扫码；代币 / NFT 持仓（「产生算力」标签直接进 `/intel?tab=power`，不再弹说明）；账号行：我的钱包、我加入的社区、我创建的社区（仅创建过时，含审核通知）、邀请好友（码 + 复制，行进 `/intel?tab=power&sub=invite`）、DApp 浏览器。
- 删除：右上「钱包管理」（与「我的钱包」同页）、底部跨链 / 代币授权 / 网络 / 设置行、profile 版净值面板与持仓（`ProfileHomeScreen` 整页删除）、底部「充值」。钱包模块整体关闭时只把资产部分换成能力块，身份卡与账号行仍在。
- 测试网「获取资金」挪进「接收」页：`testnetFaucet` 能力可用且当前钱包为内置钱包时，复制 / 分享下方一个按钮打开原领币弹层；主网不画。

### 我的 · 截图验收后再精简（主代理 2026-11-03）

- 右上角只留 交易历史 / 通知 / 设置：`LoopDashboardPage.pageInfo: false`（`LoopTopbar.pageInfo`），不再自动加页面 (i)。
- 身份卡去掉「奖励」按钮（挖矿奖励在情报·算力）；分享名片图标在昵称同一行右侧；昵称单行省略，LOOP ID 单行（`LoopIdCopyLine` 不折行），390 / 360 宽都不折行。
- 删「持仓分布」整块；总资产卡标题旁 (i) 删除；资产行副行不再写「手续费保留 …」，只显示资产名（手续费保留仍在资产详情页）。

### 设置

- 只剩 隐私与安全（隐私中心 / 安全中心 / 通知设置，`ProfileSettingsEntries`）、通用、关于、退出登录。删去三个圆键（分享名片 / 扫一扫 / 挖矿）、账号组、资产与挖矿组、通知中心行。

### 路由

- `/profile` 改为重定向 `/wallet`（manifest `profile` 条目与路径不变，仍 implemented，同 `/wallet/networth` 做法）；`/profile/*` 子路由原样。自己的头像链接（`loopOwnProfileLocation`）改为 `/wallet` 且用 `go`；公开主页「是自己」改 `go('/wallet')`。
- profile 目的地解析从 `app.dart` 私有函数移到 `lib/features/profile/profile_destinations.dart`（`profileDestinationPath`），新增 `invite`、`dapp`。
- bridge、bridge-status、networks、approvals、pay 路由保留但无入口（安全中心「授权盘点」仍可进 approvals）。清单数量不变。

## Consequences

- IDO「参与记录 / 我的资格」两个入口随资产与挖矿组删除；IDO 现在关闭，重开时再定入口位置。

- `scripts/check_harness.py` 的「首帧画本机头像」规则从聊天页移到 `profile_v2_screens.dart`（`ref.watch(ownerFaceProvider)` 现在在 `ProfileIdentitySection`）。
- 依赖 `/intel?tab=power` 与 `&sub=invite` 的落点由 S344 实现；合并前这两个深链落在情报默认段。
- 聊天分节的整列表渲染没有 widget 测试（需要真实 Stream 会话），分节规则由 `chatInboxSectioned` 单测覆盖。

## Amendment · 2026-11-03（S347 · docs/57 N2 / N3 / N5）

- 聊天分节改为两个 Stream 查询（`LoopSectionedChannelListController` 组合两个 `LoopInboxSectionController`）：「社区」按服务端写在频道上的自定义字段 `loop_channel_kind = community` 查询，30 条一页连续读到底后一次画出（重读期间保留上一份完整列表，不出现半截社区节）；「好友」按 `loop_channel_kind ∈ {direct, group}` 查询，20 条一页（首读 30）随滚动分页，下一页、加载更多失败与重试都属于好友节。列表先社区后好友，翻页只在末尾追加，已画的行不移动。
- 每节自带排序（置顶在前，再按最新消息）；实时事件按 CID 前缀只进所属节（`_SectionEvents`：另一节的 `message.new` / `channel.visible` / `notification.*` 不处理），并在 `value` setter 里再按 CID 过滤一次，任何读取或事件都不会把另一节的行带进来。
- 一节为空时保留节标题 + 一行「暂无社区会话」/「暂无好友会话」；两节都空时仍是原整页空态。
- 本机副本（0132）按两节各自的查询从 Stream 本地库读取（社区最多 300 条，好友 30 条），交给在线列表时按节拆分。
- 我的 · 邀请好友等 Tab 目的地：`_profileScreen` 按 `Uri.parse(path).path` 判断是否 Tab，带 query 的 Tab 地址（`/intel?tab=power&sub=invite`）走 `go`，不再被 `push` 到壳上。
- `LoopDashboardPage.pageInfo` 的文档注释移出 `backdrop` 注释中间。
- 测试：`test/s347_regressions_test.dart`（>20 条会话时社区节首屏完整、好友翻页不跳动、重读不出现半截社区、实时事件只进所属节、种子按节拆分、节空态一行）。

## Amendment · 2026-11-03（S348 · docs/56 §四「聊天」）

- 需求方 11-03 晚确认：社区与好友**混排、不分节**。撤回 S343 的分节与 S347 的双查询：聊天回到单一 Stream 查询（`loopStreamInboxFilter`：`type = messaging` 且本人是成员），排序仍为置顶在前、再按最新消息（`loopStreamInboxSort`），20 条一页（首读 30），单列表直接按 Stream 顺序画出；无 seg bar、无节标题、无节空态。右上「＋」与 S343 其余结构不变；整列表空态仍是原整页空态。
- 删除：`ChatInboxSection`、`chatInboxSectioned`、`LoopSectionedInbox`、`LoopSectionedChannelListController`、`LoopInboxSectionController`、`_SectionEvents`、`loopStreamInboxSectionFilter`、`loopStreamChannelKindField`、`ChatInboxSectionHeader`、`ChatInboxSectionEmpty` 及社区分页 / 本机社区读取两个常量。本机副本（0132）回到单查询读 30 条。卡板（0221）的首末圆角改为整张列表的首行与末行。
- S347 的其他修复（Tab 带 query 走 `go`、`pageInfo` 注释）保留。
- 测试：删去 s343 / s106 / s106b / s347 / stream_chat_inbox_page_test 里的分节用例；新增 `test/s348_chat_power_slimming_test.dart`（单查询、一次读取、社区与好友按 Stream 顺序混排、种子不重排）。
