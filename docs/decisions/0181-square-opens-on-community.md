# 0181 · 广场默认停在「社区」段

## Status

Accepted 2026-10-15。基线 `integration/v2` 8b191b1。用户装 TF 21 后反馈「广场默认进了动态，应默认进社区」。

## Context

0177 把「动态」放在广场第一段，`LoopSegmentedTabPage` 在读者没选过段时取索引 0，于是广场打开就是动态。

## Decision

- `LoopSegmentedTabPage` 新增 `initialIndex`（默认 0）：读者没在该 Tab 选过段时用它；选过仍按记忆。
- 广场传 `initialIndex: communityIndex(feed: feed)`：有动态段时默认第 2 段「社区」，没有时仍是第 1 段。段的顺序不变。

## Consequences

- 读者第一次打开广场看到社区；左滑或点「动态」后，本次运行内记住选择。
- 其它分段页（MEME、情报）不变。

## Verification

- `test/s187_4_square_feed_test.dart`：段序 动态 / 社区 / 语音房，初始显示社区列表，点第 1 段后显示动态。
- 广场、导航相关 7 个测试文件通过；`bin/flutter analyze` 0；harness 通过。
