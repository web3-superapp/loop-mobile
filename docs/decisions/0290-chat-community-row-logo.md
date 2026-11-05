# 0290 · 聊天列表社区会话改用社区 logo（S366-mobile）

## Status

Accepted · 2026-11-05（S366-mobile，需求方验收九条第 4 条，docs/62）。改写 0260 里「列表行里社区也画成员拼图」的那一条；0260 的 48 头像、行高 80、私聊圆形、普通群拼图不变。0258 的群拼图本身不变。

## Context

需求方 11-05 在 TF 66 上看聊天列表：「聊天页面的社区不用这种头像拼，就用社区头像，形状可以是圆角方形」。0260 为了让列表里「群」与「私聊」一眼分开，让 `loopGroupChannelFace(listRow: true)` 对社区也画成员拼图，社区 logo 只留在会话标题栏；没有读到 logo 的社区在任何位置都画拼图。

## Decision

- `loopGroupChannelFace`：只要会话是社区官方群（cid 能解析出 communityId），一律画 `CommunityLogo`（logoRef 取 `communityFacesProvider` 里社区首页聚合 / 目录页记下的那份），包在同一个圆角方 `GroupMosaicAvatar(logo:)` 里；没有 logoRef 时 `CommunityLogo` 自己画名字首字 + 按 id 定的底色，同样圆角方。非社区群聊仍是成员拼图；私聊仍是圆形（不经过这个函数）。
- 去掉 `listRow` 参数：列表行与标题栏不再分叉。列表行 48 / 圆角 12（`chatListAvatarSize` / `chatListAvatarRadius`），尺寸与布局沿用 0260。
- 复用同一函数的位置一并跟随：会话标题栏头像（32 / 8）、转发目标（`chatForwardTargetFace`，含转发页与转发表）、聊天搜索结果（44 / 15）。
- 收件箱对 `communityFacesProvider` 的读取保留——现在它同时供 logo、无消息时的首句、打开会话的标题；provider 本身不动。

## Consequences

- 社区会话在列表里不再显示成员拼图；没读过社区首页聚合的账号（首次冷启动、聚合失败）看到的是首字方块，聚合回来后换成 logo。
- 标题栏：此前「社区但没 logo」画拼图，现在画首字方块，与列表一致。
- 测试：新增 `test/s366_chat_community_logo_test.dart`（社区行 CommunityLogo 48 圆角 12、无 logo 首字方块圆角 12、普通群拼图、私聊 48 圆）；改写 s328（列表里社区画 logo、无 logo 画首字非拼图）、s330（社区行 logo 48 且与两行文字同中线、行高 80；转发目标社区画 logo）、group_alias_stream_message_identity_test（两条社区行断言改为 logo）。
