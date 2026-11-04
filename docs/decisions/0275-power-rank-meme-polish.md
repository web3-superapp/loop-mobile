# 0275 · 视觉打磨：情报·算力 / 算力榜 / MEME 首页

## Status

Accepted · 2026-11-04（S350b-mobile）。依据主代理任务单 S350（需求方 11-04 发来 8 张旧版截图，用户裁决「对这 8 页做一轮整体视觉打磨」）。docs/56 §四 的 10 条结果全部保留；不改路由、不改 view model / gateway / codec、不加文案。

## Context

TF 63 的情报·算力是两张同重的大卡堆叠（全网总算力卡 + 我的总算力卡，两条黄色 kicker、两个 Anton/Arimo 28 数字、一个黄按钮），名次只是卡角一行小字，进算力榜的皇冠在另一张卡上；没数据的格子画成「—」占一整行；tab 顺序 NFT / 代币 / 邀请而默认选中的是中间的代币；邀请 tab 内「邀请列表 / 邀请加成」与顶层 tab 用同一种紫色胶囊 + 喷点，两层读起来一样重；「分享邀请链接」在 360 宽折成两行。

算力榜：领奖台的名字 16 比下方列表行的名字 17 还小，表头紧贴领奖台底。

MEME：横幅空态是「暂无进行中···」（标题在 186 宽的文字栏里被省略）加一句说明；文字栏宽度写死 186，在 360 宽下活动副标跑到镀铬手底下；列表行的「已售 %」是 Chalk 700，和名字、价格一样亮；360 宽下名字被截成「Frog Lau…」而代码还在；几处空态句带「…会出现在这里」「第一个发射的就是你」这类说明尾巴，「还没有排队中的项目，第一个发射的就是你」在 390 宽折出单字「你」。

## Decision

### 情报·算力（`mining_screen.dart`、`mining_widgets.dart`、`intel_power_route.dart`、`referral_screen.dart`）

- 一张 hero：`MiningSummaryHero` 新增 `network` / `onOpenRank`。自上而下：「我的总算力」（caption 600 Text2）+ 右上 `MiningRankEntry`（黄皇冠 + 「第 N 名」+ chevron 的小胶囊，44 触控，key 仍为 `mining-network-rank-action`，→ 算力榜）；我的算力 Anton 40 黄（`plateFigure`，FittedBox 缩放不截断）+ 灰「H」；快照一行 caption Text3（不再加粗）；有值的格子（`_MiningHeroStrip` 改为上方一条细线、无竖线网格，数字 17 Chalk 在上、标签 14 Text3 在下）；细线下「全网总算力（· 上一小时）」左 / 总数 17 Chalk 右，NFT / 代币拆分一行灰色小字右对齐（`MiningNetworkPowerCard(inline: true)`）；最后是黄按钮。右侧淡皇冠水印（`crownFlat` 灰阶 8%）。
- 还没读到我的算力（加载 / 失败 / 离线）时，全网总算力仍按原样独立成卡，皇冠图标在卡右上；能力关闭时照旧不画。
- 值为 `—` 的格子不画（上线前的「有效邀请」没读到、上线后的「累计已挖 / 待领取」恒为 `—`），一个都没有时整条不画。
- tab 顺序改为 `代币 / NFT / 邀请`（`IntelPowerTab` 枚举顺序，默认仍是代币，深链 `sub=` 不变）。
- 构成小计（`MiningCompositionGroupHeading`）降为 caption Text3 + 14 / 600 Text2，比行内数字低一级。
- 邀请 tab 内的「邀请列表 / 邀请加成」改为 `ReferralSubTabs`：全 App 统一的下层筛选档（主代理 11-04 定，与 S350c 的 `WalletAssetTabs.filterHeight` 同形）——32 高带底色描边的 `LoopSeg`、14 号字、选中紫色实心 + 喷点、间距 8、距上方 16；不再与顶层 36 紫胶囊同款。顶层「代币 / NFT / 邀请」保持 36 紫胶囊（主代理允许）。(i) 仍在右侧，key `referral-tabs` 不变。合并时可与 S350c 的实现收拢成一个共享件。
- 「分享邀请链接 / 生成海报」改为 4 : 3 分栏，分享键去掉图标，360 宽下一行放下。

### 算力榜（`intel_rank_board.dart`）

- 领奖台名字 16 → body1 17 / 600，与列表行名字同级；数字仍是 22（领奖台 > 列表 17）。
- 表头上方 16（`segmentGap`），两列字 Text3；名次列 16 / 700 → 14 / 600，退到名字与数字之后。

### MEME 首页（`launch2_launchpad.dart`、`launch2_hero.dart`、`launch2_list.dart`、`launch2_atmosphere.dart`）

- 横幅空态只留「发射台 · BSC」与「暂无进行中的发射」，说明句删除；横幅标题（`Launch2BannerTitle`）在栏宽不够时整体缩小，不再省略。
- 横幅文字栏宽 = `Launch2BannerBackdrop.textWidthFor(卡宽)`（卡宽 − 20 − 160，夹在 140–186），390 宽仍是 170、360 宽 140，文字折行而不跑到镀铬手下。
- 列表行：「已售 %」改 14 / 600 Text2（进度条与它是一组次要读数，价格 17 Chalk 仍是行主数字，阶段胶囊不变；价格的下标 0 写法不变）；名字一行放不下名字 + 代码时代码整体让出，名字不被截（`_BoardRowName`）。
- 内盘置顶卡副标「公开内盘 · 人人可买，卖满即毕业」→「公开内盘」（卡底行已有「卖满自动毕业」）。
- 空态只留事实句：「现在没有铸造或内盘中的项目」「还没有毕业的 v2 项目」「还没有排队中的项目」（预告空态仍带「我要发射」按钮）；整页无项目的空态去掉 message。

## Consequences

- 截图（`test/s350b_shots_test.dart`，`LOOP_SHOTS=true` 才跑）：改前 / 改后 390 宽各一组，另有改后 360 宽。
- 受影响的测试按新结构更新：tab 顺序（s344）、`—` 格子不再出现（s59 / s138 / s322）、空态句（s182 / s264 / s279）、邀请子 tab 的类型（s348）。
- 未改：`LoopSegBar`、`LoopRecordRow`、`LoopChromePlate` 等共享组件；`launch2_candle_chart.dart`。
- 待定（交主代理）：算力榜「我的名次」牌的小字「算力榜，快照 …」与页标题重复（docs/46 §7 早有建议只留「快照 …」）；邀请列表行副标「加入于 … UTC」在 360 宽仍被省略号截尾（时间格式是共享的 `launchTimestampLabel`）。
