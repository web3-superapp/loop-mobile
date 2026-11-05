# 0302 · 算力页移除快照时间标注 + 总算力卡排名入口上移（S378-mobile）

## Status

Accepted · 2026-11-05（S378-mobile）。需求方 11-05 18:13 截图（算力榜二级页「我的名次」牌顶「算力榜，快照 11-05 18:00」）：「这种快照统一移除」。同日主代理追加两条（§二）。改写 0182 / 0279 里「算力榜，快照 MM-DD HH:mm」与 0279 §5.14「快照右上 10 / 400 白 30%」两条，以及 0275 / 0279 里排名入口在总算力数值下一行的位置；其余不变。不改路由、view model、gateway、codec；挖矿结算 / 后台数据字段不动。

## Context

快照时间（`MiningSnapshotComputed.computedAt` / `LoopMiningPowerSettled.computedAt`）在算力相关页面上以多种形式出现：算力榜牌 kicker、情报 · 算力 hero 右上小字、社区算力行副标题、过期提示句、(i) 说明里的区块行、来源 sheet 的「观察于」。需求方的意思是快照时间不要，牌和行本身保留。

## Decision

### 一、快照时间标注（位置 → 处理）

| 位置 | 原文 | 处理 |
|---|---|---|
| 算力榜 · 我的名次牌 kicker（`intel_rank_board.dart` `intelRankLedgerKicker`） | 算力榜，快照 11-05 18:00 | 只留「算力榜」（kicker 保留，牌布局不变）；推广榜「算力榜，实时」不变（不是时间戳）。删 `intelRankMonthDayClock` 与 ARB `intel_rankBoardMiningSnapshotComputed`；kicker 加 key `intel-rank-me-kicker` |
| 算力榜来源 sheet（`_provenance` 的 `observedAt`） | 观察于 18:00 | 不再传快照时间（推广榜原本就不传） |
| 情报 · 算力 hero 右上（`mining_screen.dart` `_heroCaption`） | 快照 · 2026-11-05 18:00 UTC（· 未更新） | 时间去掉；快照未过期时整块不画（不留空位）；过期时只显示「未更新」（AGENTS 25 的可见标记）。删 ARB `mining_screenMiningSnapshotComputed2` |
| 算力页面来源 sheet（`MiningSnapshotProvenanceLine`，hero 下 / 组成页 / 社区挖矿页） | 观察于 18:00 | 不再传快照时间；「未更新」标记与 sheet 说明保留 |
| 过期提示句（`miningStaleLine`：`MiningStaleNotice` 横幅、来源 sheet、社区算力行） | 显示的是 {时间} 的算力快照 · 最近一次快照未完成（原因） | 改为「显示的是上一次完整的算力快照 · …」（`mining_copyHead` 去掉占位符），`computedAtLabel` 参数删除 |
| 社区主页算力行副标题（`community_widgets.dart` `CommunityMiningPowerCard`） | 最近一次算力快照 · {时间} | 删副标题（只剩「最近一次算力快照」是空话）；过期时副标题为上面的不带时间的过期句。删 `communitySettlementLabel` 与 ARB `community_widgetsCommunityMiningPowerRowSubtitle` |
| 社区挖矿卡过期行（`CommunityMiningSummaryCard` KV「算力快照」） | {时间} · 未更新 | 值改为「未更新」（`mining_widgetsMarker`）。删 ARB `community_widgetsValue` |
| 挖矿 (i) 说明「最近一次算力快照」 + 社区挖矿页快照行（`mining_screenMiningSnapshotComputed`） | 区块 N · {时间} · 这是算出算力的时间 | 只留「区块 N」（占位符 `launchTimestampLabel` 删除） |

不动（不是快照时间戳，或不属算力页）：「有算力后，下一次算力快照上榜」「榜单实时更新」「名次来自最近一次算力快照…」等说明句；邀请规则 (i) 的「按 {time} 的结算小时」（有效成员截至时间，不是快照标注）；钱包净值卡「快照观察于」（钱包余额读数，AGENTS 25 要求来源 + 观察时间）；聊天代币卡「引用快照 {label}」；Launch 旧页「快照区块 N」（区块号，非时间）。

### 二、总算力卡（`MiningSummaryHero`）追加两条

1. 排名入口（key `mining-network-rank-action`，`MiningRankEntry`）从数值下一行移到数值行右端（空出的右上位置），与数值行同一 `Row`、`CrossAxisAlignment.center` 竖向居中、右边与卡内容边齐。加文字：有名次「我的排名 第 N 名」+ 皇冠 + ›（名次着色沿用 0279：1 黄 / 3 铜 / 其余主字）；无名次「暂无排名」+ 皇冠 + ›。文字 `LoopType.meta` 12 / 500 次字（`text2`），皇冠 61 × 37 的 60%，整块可点、最小 44 × 44，仍进 `/mining/rank`。原数值下一行入口删除。新 ARB `mining_widgetsMyRank`（我的排名 / My rank）、`mining_widgetsNoRank`（暂无排名 / No rank yet），删 `mining_widgetsCurrentRank`。
2. 「有效邀请 N 人」格删除（`_powerMetrics` 只剩「上一小时算力」，无值时按 0275 不画）；邀请数据在下方「邀请」tab。hero 收紧：数值行之下直接是（上一小时算力格，若有）→「全网总算力」细线块（0279 间距不变）。

## Consequences

- 新增 `test/s378_no_snapshot_time_test.dart`：算力榜牌 kicker 为「Power Ranking」且页面无「快照/snapshot + 时钟」文本；hero 无右上 caption、无快照时间；排名入口在数值右侧、中线差 ≤ 2、右边与全网块齐、≥ 44、点开算力榜；两态文案「My rank #12」/「No rank yet」+ 皇冠；无「Active invites」；社区算力行（新鲜 / 过期）无快照时间，过期句为不带时间版本。
- 改写旧断言：s190（kicker 三态、页面 kicker 文本，删 `intelRankMonthDayClock` 用例）、s7_mining_pages（`miningStaleLine` 不带时间；hero 过期 caption = 「Not updated」）、s353b（「My rank」；无右上 caption）、s344（hero 无 caption）、s325（挖矿 (i) sheet 无「Observed at」）、s293（(i) 快照行无「when power was calculated」，仍有「Block」）、community_pages（过期 KV = 「Not updated」）、community_social_pages（算力行无时间；过期句不带时间）、s138（hero 无 active-invites）。
- 不再使用的 ARB 键已从 fragments 删除并重新合并：`intel_rankBoardMiningSnapshotComputed`、`mining_screenMiningSnapshotComputed2`、`community_widgetsCommunityMiningPowerRowSubtitle`、`community_widgetsValue`、`mining_widgetsCurrentRank`；改文案：`mining_copyHead`、`mining_screenMiningSnapshotComputed`；新增 `mining_widgetsMyRank`、`mining_widgetsNoRank`。
