# 0294 · 社区 + 聊天 + 社交二级页按 docs/58 §9 扫一遍（S370b）

## Status

Accepted · 2026-11-05（S370b-mobile）。来源：用户 11-05 裁决「二级页按稿规则扫一遍、不等需求方出稿」，放 TF 69。规格 `docs/58-Figma设计规范-需求方稿-2026-11-04.md` §9（§3.2 / §3.3 / §4 作细节）；底座 0277，样板 0278–0280。基线 integration/v2 6fbcb2e1（TF 68）。

## Context

需求方只画了九页，二级页没有稿。0277 换了 token 与共享组件后，二级页大多已经吃到字体 / 色 / 圆角 / 空态 / 胶囊；剩下的偏差集中在**页面本地写死的度量**：行头像 36 / 40 / 44、行高 56 / 60 / 64 / 72、社区 logo 默认 44 r10、功能行 64 高 + 40 圆底、搜索框 card2 无描边、页 / 底单边距 16、token 卡里的 `fontSize: 12/13` 字面量。本批只改这些，结构、文案、路由、key、共享件都不动。

二级页没有对应稿行，按最近似的已画行**类推**，并把借来的数集中在 `lib/features/social/secondary_row_metrics.dart`（`SecondaryRowMetrics`），页面写「借哪一行」而不是重复数字：

| 类推 | 行高 | 头像 | 线 | 依据 |
|---|---|---|---|---|
| 人物行（成员、好友、关注、私信请求、搜索里的用户） | 67 | 48 圆 | 共享件无参数，未画（见「共享件」） | 会话行 §3.2 |
| 社区行（社区卡片行、成员页 / 管理中心抬头、搜索里的社区、社区首页已加入、发现页） | 86 | 56 方 r12 | 画（`CommunityRecordRow`）；发现页在 `LoopRecordGroup` 里由组画 | 社区行 §3.2 |
| 功能行（管理中心九行、社区 AI 入口、退出社区） | 56 | 图标底 34 | 未画（同上） | 钱包功能行 §3.2 |
| 代币行（绑定代币、搜索里的代币 / 最近代币） | 71 | 44 圆 | — | 代币行 §3.2 |
| 会话目标（转发面板、转发页、聊天搜索命中） | 67 | 48，群 / 社区 r12 | — | 会话行 §3.2（`chatListAvatarSize` / `chatListAvatarRadius`） |

## 页面对照表（现状 → 稿值）

### 社区

| 页面 / 位置 | 现状 | 改为 | 备注 |
|---|---|---|---|
| `community_record_row.dart`（我的 / 他人主页「社区」段落共用） | logo 40 r12、行 72、无线 | logo 56 r12、行 86（logo 自带上下 6.5 补足 flat 行 8+8）、1px 白 5 % 线 | 稿值 |
| 成员 · 抬头社区行 | `LoopPersonRow` 64、logo 40 r10 | 86、56 r12 | 社区行 |
| 成员 · 成员行 | 60、头像 36 | 67、48 | **类推**会话行 |
| 管理中心 · 抬头 | 72、logo 48 r10 | 86、56 r12 | 社区行 |
| 管理中心 · 九个功能行 | 64、40 圆底 | 56、34 底 | **类推**钱包功能行；圆底 → r9 方底要改共享件 |
| 管理中心 · 「未注册池」说明缩进 | 左 68 / 右 16 | 左 20+34+12=66 / 右 20 | 对齐行文字 |
| 社区主页 · 社区 AI 入口、退出社区（两态） | 64、40 圆底 | 56、34 底 | **类推**功能行 |
| 社区主页 · 绑定代币 `LoopQuoteRow` | 80、logo 36 | 71、44 | 代币行 |
| 社区主页 · 抬头（logo 72、名 `displaySm`、计数 `figureSm`、简介 `body` 次字） | — | 不动 | 与 S353c 已对齐的他人主页抬头同一套，保持一致 |
| 社区首页 · 已加入社区行 | logo 44 r10 | 56 r12 | 社区行；行高由 `LoopRecordRow` 定（见共享件） |
| 发现社区 · 目录行（`communityDirectoryRow`） | logo 44 r10 | 56 r12 | 只改度量，S364 的控件行与 `LoopRecordGroup` 结构未动 |
| 搜索 · 搜索框 | card2 底、无描边、占位 `body` 16 三级字、高随前缀键 48 | `searchBg` 底、1px `cardEdge`、r12、占位 `searchHint` 15 / 500、高 44 | §9.4 搜索框 |
| 搜索 · 分段左缩进 | 16 | 20 | 页边距 |
| 搜索 · 代币结果 / 最近代币 | 64、44 r10 方 | 71、44 圆 | 代币行 |
| 搜索 · 社区结果 | 64、44 r10 | 86、56 r12（最近卡片里的社区 logo 同 r12） | 社区行 |
| 搜索 · 用户结果 | 64、44 | 67、48 | **类推**会话行 |
| 社区 AI、社区首页聚合块、创建 / 申请表 | — | 核过，已全走 token，未改 | — |

### 聊天

| 页面 / 位置 | 现状 | 改为 | 备注 |
|---|---|---|---|
| 转发面板 `forward_target_sheet.dart` 行 | 最小 56、名 `title` 14 / 500、副 `caption` 12 | 67、名 `rowTitleLg` 16 / 500、副 `captionMd` 14 / 300、名副间 2 | 会话行 |
| 转发面板外边距 | 16 | 20 | 页边距 |
| 转发页 `chat_forward_screens.dart` 目标行 | 44 r15 | 48 r12 | 会话行头像 |
| 聊天搜索命中 | 44 r15 | 48 r12（单聊圆） | 会话行头像 |
| 建群选好友 `friend_screens.dart` | 头像 36 | 48 | **类推**会话行 |
| 语音房（`voice_room_screens.dart` 四处、`voice_room_stage.dart` 三处）、通话面板（`stream_voice_room_page.dart` 三处、`stream_foreground_call_view.dart` 一处） | 左右 16 | 20 | 页边距；舞台网格按 `LayoutBuilder` 自算格宽，无连带 |
| 预览语音房 `voice_room_page.dart` 面板 | 左右 16 | 20 | 页边距 |
| 预览会话 / 群信息 / 消息请求 / 消息搜索（`conversation_pages.dart`、`chat_secondary_pages.dart`） | 左右 16、成员头像 40 | **不改** | 这两份是开发预览夹具，`scripts/check_harness.py` 按审过的源码指纹冻结（「Preview conversation pages / group information / Chat Message Requests」），改一个数字就破指纹；改了又撤回 |
| 代币卡 `chat_token_card_view.dart` | 6 处 `fontSize: 12/13` 字面量 | 去掉冗余 `fontSize: 12`（`caption` 本身 12）；风险事实 13 / 600 → `figureXs` | 走字阶 |
| 单聊 / 社区聊天 / 群内页、频道抬头、群信息、member_buy、token_card 容器、widgets/、attachments/ | — | 核过，Stream 自管或已走 token，未改 | — |

### 社交

| 页面 / 位置 | 现状 | 改为 | 备注 |
|---|---|---|---|
| 关注与粉丝行 | 56、40 | 67、48 | **类推**会话行 |
| 私信请求行 | 64、40 | 67、48 | **类推**会话行 |
| 黑名单行、扫码名片、公开资料面板 | — | 核过，未改 | 黑名单用共享 `LoopRecordRow` + `LoopRowIcon` |
| 他人主页 `user_profile_screen.dart` | — | 未改（S353c 已对齐） | 「社区」段落经 `CommunityRecordRow` 随社区行变为 86 / 56 + 线 |

### 广场

发帖页（`SquareFeedComposer`）在 `square_feed_view.dart` 里，该文件按任务书不动；广场没有独立的帖子详情页。本批广场无改动。

## Decision

- 新增 `SecondaryRowMetrics`（纯常量，取 `LoopRowHeight` / `LoopRadius` token），二级页借行时引用它。
- 按上表改页面本地度量；ARB、路由、key、view model、gateway、共享件（`lib/widgets/`、`lib/app/`、`loop_theme.dart`）均未改。

## 需要改共享件才能到稿值的条目（留给主代理派）

1. `LoopPersonRow` 无 `divider` 参数，上下内边距写死 8：人物行 / 功能行的 1px 白 5 % 线画不上；功能行头像底要 r9 方（`LoopEntryIcon` 写死圆、底色 card2）。
2. `LoopRecordRow` 上下内边距写死 13、最小高 72 / 80、标题写死 `LoopType.title`：社区首页已加入、发现页、聊天搜索命中、转发页目标、黑名单、建群选好友这些行到不了 86 / 67，会话类行的名也到不了 `rowTitleLg` 16 / 500。
3. `LoopRecordGroup`（发现页、转发页、聊天搜索等）仍是一块 r12 卡底 + 组内线，稿的列表行直接落在页面上；改成无底属于结构 / 共享件变化，本批未动。
4. 成员搜索框、群改名、好友搜索等表单输入框走主题 `InputDecorationTheme`，稿的搜索框（`searchBg` + `cardEdge` + 44）要在主题或 `LoopSearchEntry` 统一，本批只改了全局搜索页本地的那一个。

## Consequences

- `CommunityRecordRow` 是我的 / 他人主页「社区」段落共用件，两页的社区行随之变为 86 / 56 + 线（稿的社区行规格）。
- 测试：新增 `test/s370b_secondary_spec_test.dart`（13 条：常量、社区卡片行、成员、管理中心、搜索、关注、私信请求的实测度量；需 Stream 会话才能挂载的聊天面按源码钉住）。旧断言按本批有意改动更新两处：`s187_6_search_layout_test` 代币 logo 圆角 `tileValue` → 圆（`cornerRadius` null）；`s82_logos_discover_and_token_test` 发现页行高 80 → 82、文字左缘 20+16+44+12 → 20+16+56+12。无删除、无 skip。
- `scripts/check_harness.py` 与基线比：无新增失败；代币卡的 `fontSize:` 手写项消失、字阶外计数 7 → 1（剩一处 `LoopTypography.figure(20)`，字阶里没有 20 档，未动）。基线本身就有的 20 余条（预览页指纹、intel / meme 手写字号等）不属于本批。
