# 0260 · 聊天列表社区会话用成员拼图，列表头像放大到 48

## Status

Accepted · 2026-10-31（S330-mobile）。部分覆盖 0258「有社区 logo 的社区群画 logo」一条：在会话列表类场景不再画 logo。

## Context

用户 2026-10-31 看了 TF 56 后裁决：聊天列表里社区会话也按群组头像来，让用户一眼分出「群 vs 私聊」；列表头像偏小，从 40 放大到 48。

## Decision

### 列表场景一律画成员拼图

- `loopGroupChannelFace(...)` 新增 `listRow` 参数（默认 `false`）。`listRow: true` 时，即使是有 `logoRef` 的社区群（含社区官方群），也画成员九宫格拼图（key `loop-group-channel-mosaic`），不画 `CommunityLogo`。
- 传 `listRow: true` 的地方（会话列表类）：
  - Stream 会话列表群行（`_LoopStreamGroupChannelListItem`，`stream_chat_inbox_page.dart` 的行）。
  - 转发目标：`chatForwardTargetFace`（`forward_target_sheet.dart` 弹层、`chat_forward_screens.dart` 页面）。
  - 聊天搜索结果：`chat_search_screen.dart`。
- 非 Stream 的 `ConversationRow` 与预览搜索结果本来就没有 logo（预览数据没有社区 logo），不变。
- 仍走 logo 分支（`listRow: false`）的只剩会话页顶栏 `LoopStreamGroupChannelHeader` 的群图标：它读 `CommunityFacesScope`，有 `logoRef` 才画 logo。社区页、社区资料、语音房返回条、挖矿榜等直接用 `CommunityLogo` 的地方不经过本入口，不受影响。
- 会话列表仍读社区首页聚合（`communityFacesProvider`），用于社区行无消息时的简介首句和打开会话时的标题。

### 列表头像 48

- 常量 `chatListAvatarSize = 48`、`chatListAvatarRadius = 12`（`group_mosaic_avatar.dart`）。
- 圆角 12 = 边长 1/4，与原来 40 / 10 的比例相同，不超过 1/4。
- 48 下拼图格子：1 人 44；2–4 人 21；5–9 人约 13.3；格间与边缘仍 2 px；格内圆角 `格宽 × 0.12`（夹在 1–4）；首字母字号为格宽的一半。
- 改为 48 的列表：Stream 会话列表私聊行（`LoopInitialsAvatar` / `LoopRemoteAvatar` 圆形）与群行、会话列表加载骨架、非 Stream `ConversationRow`（私聊 `ChatAvatar` 圆形、群方形，原 44）、预览搜索结果（原 40）、转发目标弹层（原 40 / 圆角 13）。
- 行高随头像变高；Stream 行的头像与标题、预览两行在同一中线上（`Row` 默认垂直居中），不另调间距。
- 不变：会话页顶栏（32）、消息气泡旁小头像、聊天页顶栏「我」头像（40）、转发页面与聊天搜索里的 `LoopRecordRow` 行首（44 / 圆角 15，这两处不是 40，沿用记录行规格）。

### 身份边界

不变（决策 0112 / 0258）：实名房间用账号 `name` / `image`；化名房间只用化名或「成员」首字母，不画头像图。

## Consequences

- 生产中会话页顶栏的路由不在会话列表的 `CommunityFacesScope` 之下，读不到 `logoRef`，所以实际上顶栏也是拼图；聊天域里目前没有显示社区 logo 的群头像位置。
- 社区 logo 只在社区相关页面（社区主页、社区资料、发现社区、语音房返回条等直接使用 `CommunityLogo` 的地方）出现。
