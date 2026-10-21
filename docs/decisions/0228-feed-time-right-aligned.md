# 0228 · 广场「动态」帖子时间贴右对齐（S268-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` b2e789ac。依据：用户 2026-10-21 iOS 真机截图（广场 → 动态），
三条帖子的「3d」横向位置各不相同，要求「时间统一对齐」。只改 loop-mobile；不改 theme、不改 lockfile、route manifest 不变。

## Context

- `SquareFeedPostRow`（0187）头部一行是 `Row[Flexible(头像+昵称), 标签, Spacer, 8, 时间]`。
  `Flexible`（loose）和 `Spacer` 各分到一半剩余空间，昵称用不完的那部分不会让给 `Spacer`，
  于是整行宽度随昵称与标签长度变化，时间跟着左右飘（测得短昵称时时间右边缘在 306，而不是 390 − 16 = 374）。
- 同类行核查：聊天收件箱（`StreamChannelListTile` 的 `timestamp` 槽、`ConversationRow` 的 `Expanded` 标题）时间本就贴右；
  钱包流水转账行时间在右列 `trailingCaption`；MEME v2 流水行时间在副标题行首（固定 x）；情报页没有相对时间。均无此问题，未改。
  MEME 列表行的 age 是紧跟 ticker 的内联标记（与「已毕业」二选一，右列是市值），属原型设计，不在本批范围。

## Decision

- 头部一行改为 `Row[Expanded(Row[Flexible(头像+昵称), 8, 标签胶囊]), 8, Align(centerRight, 时间)]`：
  昵称 + 标签吃掉时间之外的全部宽度，昵称先省略（`ellipsis`，单行），标签胶囊不被挤掉；时间永远贴行尾，
  右边缘 = 行宽 − 页边距 16。时间字号 / 颜色不变（`figureXs` / Text3），key `square-post-age` 不变。

## Consequences

- 新测试 `test/s268_feed_time_align_test.dart`：三条昵称 / 标签长度不同的帖子，时间右边缘相等且 = 行宽 − 16；
  超长昵称省略、标签仍在、时间仍在位。该测试在旧代码上失败（306 ≠ 374）。
- 旧测试 `test/s187_4_square_feed_test.dart` 无需修改，全部通过。
