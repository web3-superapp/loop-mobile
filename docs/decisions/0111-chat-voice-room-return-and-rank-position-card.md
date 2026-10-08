# 0111 · 聊天 Tab 的「正在语音房」返回行；算力榜个人名次卡只在用户榜（S106b）

## Status

Accepted 2026-10-08。主代理裁决，S106b 实施。基线 `integration/v2` 94aa444（决策 0110）。
不新增依赖、`pubspec.lock` 不变、路由清单不变。

## Context

1. 决策 0110 退役了社区 Tab 的消息面板，面板里的 LIVE 行（「我当前所在的语音房」）随之消失，
   离开语音房页之后只剩壳上的浮条能回到房间。
2. 2026-10-08 模拟器验收（`LOOP/docs/acceptance/2026-10-08-s106-emulator.md` 缺陷 2）：情报 · 算力榜
   顶部 NETWORK POSITION 卡在社区榜下显示「暂无数值 · 社区榜不显示个人名次」，推广榜下也是这句。

## Decision

1. **聊天 Tab 返回行**：列表顶部、与「陌生人请求」同一槽位（在其上方），读
   `voiceRoomSessionProvider`；有会话时显示一行「正在语音房 · {社区名}」，尾部「返回」，点击进
   `/chat/voice?id={communityId}`；没有会话不画。Preview 也按同一会话显示（会话是本机真实状态，
   不是夹具）。
2. **广场 · 语音房段**：`voiceRoomId` 与本机会话相同的那一行，尾部徽标由「直播中」换成「已在房间」。
3. **算力榜个人名次卡**：在情报 Tab 的嵌入算力榜里，NETWORK POSITION 卡（含「我的名次」行）只在
   用户榜显示；社区榜与推广榜不画这张卡。独立路由 `mining-rank`（`/mining/rank`）保留原型的
   folio，不在本裁决范围。

## Consequences

- 原 `community_pages_test.dart`「the message panel states a room this account is in」的行为由
  `test/s106b_nav_followups_test.dart`（chat · the room this account is in）接替。
- 独立 `mining-rank` 页社区榜下仍显示「社区榜不显示个人名次」，如需一致需另行裁决。
