# 0300 · 聊天列表静音图标移到行最右侧（S376-mobile）

## Status

Accepted · 2026-11-05（S376-mobile）。改写 0274（S350a）里「置顶 / 静音标记接在预览行末尾」的那一条；0274 其余内容（置顶行抬一级底色、名字行只放名字 / 时间 / 未读数）不变。

## Context

需求方 11-05 17:5x 反馈：底栏「聊天」页签里，被静音的会话的静音小图标紧跟在最后一条消息预览文字后面，预览短时图标落在行中间。

来源：图标是 Stream 频道的服务端 mute 状态（`channel.isMuted` / `isMutedStream`，读当前用户的 `channelMutes`；行操作「静音 / 取消静音」调用 `channel.mute()` / `unmute()`），不是本地设置。图标由 Stream 官方 `StreamChannelListTile` 画：主题设了 `AttributePosition.trailingBottom`，SDK 的 `_SubtitleRow` 用 `Flexible(预览) + 图标`，所以图标贴在文字后面，而非行右端。

需求方稿 docs/58 §5.6：右列 61 宽，时间在上（高 20），下面是 16 高的 Meta Space，「放免打扰等图标」。

## Decision

- 两种行（直聊 `_LoopStreamDirectChannelListItem`、群 / 社区 `_LoopStreamGroupChannelListItem`）给 `StreamChannelListTile` 传 `isMuted: false` / `isPinned: false`，SDK 不再画标记。
- 新增 `loopStreamChannelListSubtitle(preview, muted:, pinned:)`：有标记时预览行是 `Row[Expanded(预览), 8, 标记组]`，预览占满剩余宽度、单行省略号（沿用主题的 `DefaultTextStyle` maxLines 1 / ellipsis）；标记组在右列、时间下方，右缘与时间（有未读时为未读徽章）右缘对齐。无标记时原样返回预览。
- 标记尺寸 16（`loopChannelMetaIconSize`，§5.6 Meta Space），颜色 `LoopColors.text3`，保留 Stream 的无障碍标签（`channelMutedLabel` / `channelPinnedLabel`）。
- 置顶标记同属这一槽位、有同样的「贴字尾」问题，一并移过去；同时存在时静音在左、置顶在右。
- 有未读 + 静音：名字行右端仍是「时间 + 未读徽章」（0105 · 6），静音图标在其下方、右缘对齐徽章右缘。
- 主题 `attributePosition: trailingBottom` 保留，作为其他官方 tile 的兜底。

## Consequences

- 无文案改动。
- 测试：新增 `test/s376_chat_mute_icon_right_test.dart`（360 宽：静音行图标 16、右缘贴时间右缘、在时间下方、不在预览的 Expanded 内；长预览单行省略且在图标左侧；非静音行无标记；未读 + 静音；静音 + 置顶）。`test/s350a_polish_test.dart` 的主题断言改名为兜底说明，断言值不变。
