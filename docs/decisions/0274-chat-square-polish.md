# 0274 · 聊天与广场（动态 / 社区）视觉打磨

## Status

Accepted · 2026-11-04（S350a-mobile）。来源：需求方 11-04 发来 8 张旧版截图，用户裁决对这 8 页做一轮整体视觉打磨（层级、字号、间距、分区、对比）；docs/56 §四的 10 条结果全部保留。本批不做功能、不改路由、不加文案。

## Context

改前 390 宽截图（S350a 截图测试 `test/s350a_shots_test.dart`）上看到的问题：

聊天（`chat`）
1. 群 / 社区会话第二行的「成员: 」发送者前缀是 Stream 默认粗体，和上方 17 / 600 的会话名同重，第二行跟第一行抢主次（`StreamMessagePreviewText` → `LoopStreamTokenCardMessagePreviewFormatter.formatMessage`）。
2. 置顶会话在混排列表里只有会话名后面一个 20 号图钉（`StreamChannelListTile` 默认 `attributePosition: inlineTitle`），名字一长图钉就贴着省略号，置顶的两三行在列表里认不出是一组。
3. 静音 / 置顶图标挤在第一行，第一行同时有名字、图标、时间、未读角标四样东西。
4. 搜索框的放大镜是 Text2，广场搜索框是 Text3，两个 Tab 的同一个控件不同色。
5. 空态「还没有会话，加入社区或添加好友后会出现在这里」是解释句（决策 0248）。

广场 · 动态（`square` 的「动态」段）
1. 帖子之间是一条通栏 1px 线（`SquareFeedPostRow` 的 `Border(bottom: LoopColors.line)`），上 12 下 4，帖子直接铺在墙面上；同一个广场里「社区」段是卡片，两段是两套语言。
2. 正文、代币卡、点赞都缩进到头像列之后（`indent = 40`），代币卡在 390 宽里只剩约 250，「市值 $666.7K」被截成「市值 …」。
3. 官方帖的回顾块是 `LoopRecordCard`（Card 底），放进卡片后看不出边界，文字凭空缩进 14。
4. 「全球 / 已关注」下有一条通栏线，「发帖」是 48 高的页面级按钮，比两个分段词重。
5. 空态有一句「有人发帖、买入、领奖或代币毕业时会出现在这里」解释句。

广场 · 社区（`square` 的「社区」段）
1. 卡片前有四层控件：「发现社区 / 规则与入驻」、52 高搜索框、整行「全部 / 我加入的」分段、「成员最多」排序；390 × 844 上第一张卡从 288 开始。
2. 搜索框和分段在 20 页边距，卡片在 16（S335 需求方定稿），盒子左右边缘差 4。
3. 卡片第三行事实（成员数、算力）用 Text3 `#AEACB6`，简介用 Text2 `#B8B4C0`，两者只差一个色阶，三行读成两级。
4. 空态「这个排序下没有社区。」「加入后，社区群聊会出现在聊天里」是解释句。

## Decision

### 聊天

- 发送者前缀去粗：`loopQuietSenderPrefix` 只改 Stream 生成的首个「…: 」粗体片段为 400，正文里 @ 提及的粗体保留；`LoopStreamTokenCardMessagePreviewFormatter.formatMessage` 两条出口都过一遍。
- 置顶 / 静音图标移到第二行末尾（`channelListItemTheme.attributePosition: trailingBottom`）；第一行只剩名字、时间、未读。
- 置顶行底色抬一级：`ChatInboxSwipeRow(pinned:)`，置顶行用 `loopChatBoardPinnedFill`（Chalk 5% 叠在 `loopChatBoardFill` 上），随 `channel.isPinnedStream` 实时变化；不加「置顶」小节标题。
- 搜索框放大镜改 Text3，与广场一致。空态只留「还没有会话」+「找朋友」。

### 广场 · 动态

- 每条帖子一张卡：Card 底、20 圆角、离屏边 16、卡间 12、卡内 16（与「社区」段卡片同一网格，常量 `squareFeedCardInset / Gap / Padding`）；去掉通栏线。
- 正文、代币卡、点赞不再缩进到头像后，和头像左缘对齐（`SquareFeedPostRow.indent = 0`）；名字到正文 10、正文到代币卡 10。
- 代币卡的市值要么整段画出、要么不画（`_squareQuoteWidth` 量宽），不再出现「市值 …」；颜色降到 Text3，价格仍是主数字。
- 官方回顾块改为 Card2 底、12 圆角的内嵌块（与代币卡同一层级）。
- 「全球 / 已关注」下去掉通栏线，下方留 16；「发帖」改 `LoopButtonSize.compact`（32 高面、44 触控）。
- 空态只留「还没有动态」。
- 标签胶囊（置顶 / 观点 / 毕业 / 买入 / 领奖）沿用 `LoopBadge`，本来就是同一高度与字号，未改。

### 广场 · 社区

- 搜索框与「全部 / 我加入的」并到同一行并一起吸顶：搜索框占剩余宽度，分段是与搜索框同高 52 的紧凑轨道（Input 底，每个词按自身宽度，不截「我加入的」）；整行与卡片同用 16 边距。卡片前从四层变三层，第一张卡在 390 × 844 上从 288 上移到 232。
- 「发现社区 / 规则与入驻 ›」（UX-013）和右对齐的「成员最多 ∨」（S335）保留原位。
- 卡片事实行（成员数、算力、人形图标）改 Muted `#8E8A98`（对 Card 底 ≥ 5:1），名字 Chalk → 简介 Text2 → 事实 Muted 三级。卡片其余尺寸（S335 需求方定稿）不变。
- 空态只留「没有符合条件的社区」/「还没有加入社区」与原有按钮。

## Consequences

- 不改路由、view model、gateway、codec；不加文案（只删了 4 句解释句）。
- 共享组件只动了 `lib/integrations/communication/stream_chat_appearance.dart` 的 `channelListItemTheme`（只影响会话列表行）；`lib/widgets/*` 未改。`community_record_row.dart`（我的 / 他人主页的「社区」节在用）本批未改，避免和 S350c 同一页的截图对不上。
- 测试：新增 `test/s350a_polish_test.dart`（前缀去粗、图标位置、置顶底色、帖子卡片网格、市值整段或不画、搜索与分段同行且 360 宽不截字）；`test/s350a_shots_test.dart`（`LOOP_SHOTS=true` 才跑，390 / 360 有数据 + 390 空态）；`s335` 事实行颜色断言改为 Muted；`s268` 年龄右缘改为卡片内容右缘。
- 截图在主代理 scratchpad `S350a/before` 与 `S350a/after`。
