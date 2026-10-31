# 0258 · 群头像九宫格拼图，私聊保持圆形

## Status

Accepted · 2026-10-31（S328-mobile）。

## Context

需求方反馈聊天列表里群聊和私聊分不清：私聊行是圆形首字母，群行是方形首字母，两者都只有一个字，扫一眼看不出区别。要求参考微信：没有自定义群头像时用群成员头像拼成九宫格组合头像。

## Decision

### 外形

- 私聊：圆形单人头像（对方上传的头像，读不到时为首字母），不变。
- 群聊、社区官方群、语音房（按群处理）：圆角方形，深色底（`LoopColors.plateRaised`），圆角默认 `LoopRadius.innerValue`，不超过边长的 1/4。
- 有社区 logo 的社区群：在同一个圆角方形里画社区 logo（`CommunityLogo`，预设图或上传图）；没有 logo（本账号还没读到这个社区的 `logoRef`）时画成员拼图。
- 组件：`lib/features/chat/widgets/group_mosaic_avatar.dart` 的 `GroupMosaicAvatar(members, size, label, logo, logoUrl, radius)`；入口统一经 `loopGroupChannelFace(...)`（`group_alias_stream_message_identity.dart`）。

### 排布规则（微信）

格子边长只由列数决定：`(边长 − 2×2 − 2×(列数 − 1)) / 列数`，格子之间、格子与边缘都留 2 px。

| 人数 | 列数 | 每行个数（上→下） |
| --- | --- | --- |
| 1 | 1 | 1（满格，留 2 px 边） |
| 2 | 2 | 2 |
| 3 | 2 | 1 + 2 |
| 4 | 2 | 2 + 2 |
| 5 | 3 | 2 + 3 |
| 6 | 3 | 3 + 3 |
| 7 | 3 | 1 + 3 + 3 |
| 8 | 3 | 2 + 3 + 3 |
| 9 | 3 | 3 + 3 + 3 |

除第一行外每行排满，余数放第一行；每行水平居中，整体垂直居中。超过 9 人只取前 9 个。一个成员都没有时，画一格群名首字母。

### 单元格

- 有头像地址：远程图（`LoopRemoteAvatar`，方形小圆角），图到之前与失败时显示首字母格。
- 没有头像：首字母格。底色取 `LoopMonogramPalette.grounds`，按成员 id 的 FNV-1a 哈希选，同一个人在所有群里同一个颜色；字取 `loopMonogram(name)` 的第一个字符。

### 取人规则

- 来源：Stream 频道的 `state.members`（会话列表查询带 `memberLimit: 30`，所以列表最多从 30 个已加载成员里挑；转发目标用 `queryChannelsOnline` 返回的成员；搜索结果用本机 `client.state.channels[cid]` 已持有的频道成员，没持有就退回群名首字母）。
- 顺序：按加入时间 `Member.createdAt` 升序（最先加入在前），同时间按 userId；去重；排除 `loop_feed_bot` 及带 `loop_bot: true` 的用户；取前 9 个。
- 身份边界与房间内一致（决策 0112）：实名房间（社区群按 `communityChatRealIdentity`，普通群按 `!groupAliasVisible`）用账号自己的 `name` 与 `image`（`loopStreamRealIdentityOf`）；化名房间只用群内化名或「成员」，**不画头像图**，拼图不会比消息泄露更多身份。
- 预览模式（非 Stream 的 `ConversationSummary`）没有成员数据，群行画群名首字母的圆角方形。

### 缓存

- 内存 LRU（256 项），不落盘。
- key：`人数 : FNV-1a(按顺序拼接的成员 id) @ 边长/圆角`。
- 命中且成员记录（id、名字、头像地址）完全相同，直接返回同一个 widget 实例，行重建时不重新布局；有人进出 → id 列表变 → key 变 → 重拼；同一批人换了名字或头像 → 记录不等 → 重拼。

### 替换入口

- Stream 会话列表群行（`_LoopStreamGroupChannelListItem`）。
- 非 Stream 会话列表（`ConversationRow`），群 / 语音房 / 会议为方形，私聊仍为 `ChatAvatar` 圆形。
- 会话页顶栏：`LoopStreamGroupChannelHeader` 右侧群图标；预览会话页 AppBar；预览群页大头像。
- 转发目标：`forward_target_sheet.dart`、`chat_forward_screens.dart`（统一走 `chatForwardTargetFace`，私聊目标改为圆形并带对方头像）。
- 搜索结果：`chat_search_screen.dart`（群 / 社区命中为会话方形，私聊命中为圆形）、`chat_secondary_pages.dart` 预览搜索结果。

## Consequences

- 正式群聊 / 社区群会话页（`GroupChatScreen`、`CommunityChatScreen`）的 `LoopTopbar` 原本没有头像位，且 `leading` 在有返回键时不画；本批不改 `lib/widgets/`，所以这两页顶栏仍无群头像。
- 搜索结果原来画发送者首字母，现在画会话头像（发送者在标题里仍写明）。
