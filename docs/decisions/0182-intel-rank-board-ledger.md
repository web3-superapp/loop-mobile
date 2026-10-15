# 0182 · 情报 · 算力榜改为设计稿「算力榜 · 定稿」（S190-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3486ea4（0181 之上）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15.md` 末尾追加与 `body3.html`「算力榜 · 定稿」两个手机框（社区榜 / 用户榜，
HTML 结构即规格；标「存档」的 A / B 不做）。用户裁决：整体用 A（lime 账本卡做「我的名次」主视觉），列表行用 B。
只改 `lib/features/intel/intel_rank_board.dart` 的版式：路由、状态合同、请求路径、`IntelRankBoardController`、
分页与换榜规则不变；不新增依赖与字体；独立路由 `mining-rank` 不动。修订 0118 §2、0122 P2、0123 的算力榜部分。

## Context

0122 / 0123 的算力榜是「三枚筹码 + 我的名次胶囊 + 三张并排领奖台卡 + 无卡行」：「我的名次」只是一枚 36 高的描边胶囊，
页面没有 docs/33 §1 第 1 条要求的主视觉；行只有名次 / 头像 36 / 名字 / 权重 pill / 数字，看不出离第一名多远，
自己不在已读页里时整页看不到自己。

## Decision

### 1. 主视觉：lime 账本卡（`IntelRankLedger`，key `intel-rank-me`）
放进 `LoopDashboardPage.primary`：`LoopFolioPrimary(variant: lime, archetype: record, ring: false)`。
- kicker（`intelRankLedgerKicker`）：社区 / 用户榜「POWER BOARD · 快照 MM-dd HH:mm」，时间是 `MiningSnapshotComputed.computedAt`
  （本机时区，`intelRankMonthDayClock`）；快照不可用时只写「POWER BOARD」；推广榜读的是实时邀请关系，写「POWER BOARD · 实时」。
- heading（`intelRankLedgerHeading`）：「我的名次\n第 N 名」，没有 `me` 时「我的名次\n还没有名次」。
- caption（`intelRankLedgerCaption`，最多 3 行，` · ` 连接）：
  - 「算力 1,240」（推广榜「直接邀请 N 人」），数字取 `me.value`；
  - 「距第 N−1 名还差 X」（推广榜「… 人」）：只在已读页里有名次 = N−1 且有数字的行、且差值 > 0 时写（`intelRankGapToNext`，Decimal 相减）；
    读不到上一名（不在已读页、算力仅本人可见、并列）就省略；第一名没有这一段；
  - 社区榜：「社区 X 权重 W」——`me.communityId` 对应的行已读到时写名称与权重；只在 `communityFacesProvider` 里有名称时写「社区 X」；都没有就省略；
  - 用户榜的「持有 N 枚共识勋章」：rank 契约里没有勋章数，**不画**；
  - 没有名次：推广榜「邀请到第一位好友后上榜」，其余「有算力后，下一次算力快照上榜」。
- stamp（`intelRankTopShare`）：「TOP x%」= `me.rank × 100 ÷ ranking.participants` 向上取整、夹在 1–100；没有 `me`、榜单不可用或
  `participants` 为 0 时不画。
- 第一页读取中且还没有榜时画同一张卡的 `headingLoading` 骨架（key `intel-rank-me-loading`）；读失败时不画卡（下面的状态块说明原因）。
- 旧 `IntelRankMePill` 删除（信息并入账本卡）。同屏满 lime 只有这张卡：推广榜空态的「去邀请」由 primary 改为普通按钮；
  筹码选中态本就是 0122 的深灰胶囊。

### 2. 筹码
`LoopSegBar` 社区 / 用户 / 推广（顺序、图标、key `intel-rank-scope`、左右滑动换榜不变），位于账本卡下方 sections 的第一项。

### 3. 领奖台
`LoopLabel('前三名')`（key `intel-rank-podium-label`）+ `IntelRankPodium`。卡片容器从自造的 card / card2 面 + `LoopRadius.control`
改为 `LoopRecordCard(margin: zero)`（r20、line 描边、record 渐变；点按走它自带的 InkWell，不再是裸 `GestureDetector`），
第一名上内边距 16、二三名 12。奖牌改为卡片左上 10 / 10 的 20 方标，`LoopRadius.badge`，颜色仍按 0122（lime / brass / copper）。
皇冠、头像 56 / 48、三卡同高（0123）、名字两行、数字同一基线、权重 / 「我」徽标保留。

### 4. 列表行（B，`IntelRankRow`）
- 表头 `IntelRankListHead`（key `intel-rank-list-head`）：`LoopMono.label`（`.label` 同款）大写一行，左「名次 · 社区 · 权重」/「名次 · 用户」，
  右「算力 · 占第一名比例」（推广榜「直接邀请 · 占第一名比例」）。只在有第 4 名以后的行或补行时出现。
- 行：名次（最小宽 22，右对齐，`LoopType.figure` 700，text3；自己 lime）· 头像 40 圆（社区 Logo 圆角 = 半径）· 名字（`LoopType.body` 600）
  + `LoopBadge(mute)`「权重 x」（只有社区榜）· 副标题 `LoopType.captionSm` text2 · 右侧数字（`LoopType.figure` 700）+ 64 px `LoopProgressBar`。
  行内边距 12 / 16、最小高 64、底部 line 描边。
- 副标题：社区「N 人有算力」（`participants`）；用户榜只在自己匿名时写「其他人看到的是匿名成员」，「N 枚勋章」无来源**不画**；推广「直接邀请」。
- 用户榜的「所在社区名」徽标：`MiningRankUserRow` 没有社区字段，**不画**。
- 进度条值 `intelRankShare` = 该行数字 ÷ 第一名（服务端名次为 1 的条目）数字，纯前端、Decimal 相除后才转 `double`，夹在 0–1；
  第一名缺失、为 0 或仅本人可见，以及本行数字仅本人可见时不画条。

### 5. 我的那一行
- 已读页里有自己（用户 / 推广 `isSelf`；社区榜 = `me.communityId` 对应的行）：该行 limeSoft 底，名次与数字 lime。
- 已读页里没有自己而 `me` 存在：在所有行之后、加载更多哨兵之前补一行 `IntelRankSelfRow`（key `intel-rank-self-row`）：
  名次与数字来自 `me`，头像与名字来自 `ownerFaceProvider`（社区榜为 `me.communityId` 的社区 Logo 与名称，名称读不到写「我的社区」），
  同样 limeSoft 高亮、带占第一名比例。翻页读到自己那一行后补行自动消失。

### 6. 沿用
来源行与 ⓘ 详情、快照过期提示、空态插图、不可用行、加载更多 / 失败重试、榜底 12 空白（0122 不画「没有更多」）、换榜丢弃旧榜全部不变；
换榜时账本卡随新榜重建（读取中先骨架）。

## 偏离表

| 设计稿 / 清单 | 实现 | 原因 |
| --- | --- | --- |
| 行数字 mono 14 粗、名字 14、领奖台名字 / 数字 13、奖牌 10 | 数字 `LoopType.figure`（13）700、名字 `LoopType.body`（14）600、领奖台 `titleSm` / `figure`（13）、奖牌 `figureXs`（11）800 | 字号只用 `LoopType`，没有 14 的 figure 档，取最接近的一档；字重经 `LoopTypography.withWeight`（harness 禁手写 `fontWeight:`） |
| 表头 mono 10 | `LoopMono.label`（= `LoopType.eyebrow` 12） | 与 `LoopLabel` 同一样式 |
| 奖牌 `border-radius:50%` | `LoopRadius.badge`（7） | 任务清单指定 |
| 设计稿领奖台无皇冠 | 皇冠保留 | 清单：领奖台沿用，只改容器与奖牌 |
| 自己那一行头像是 lime 圆「我」 | 用真实头像 / 社区 Logo | 同屏只许一个满 lime |
| 用户榜行徽标 = 所在社区、副标题「N 枚勋章」；账本卡「持有 N 枚共识勋章」 | 不画 | rank 契约没有这两个字段 |

## Consequences

- 情报 · 算力榜顶部有了唯一的 lime 主视觉；行能看出与第一名的差距，自己始终在列表里。
- `IntelRankMePill` 与常量 `intelRankRowHeight` 删除；`IntelRankRow` 新增 `share`，`IntelRankEntry` 新增 `amount`。
- `PRESS_FEEDBACK_DEBT` 中本文件的 1 条余额不再使用（领奖台改走 `LoopRecordCard` 的 InkWell），条目保留未删（只许减，不要求清零）。
- 可见变化（待主代理真机验收）：账本卡、领奖台变 record-card 且奖牌移到左上、行变高（≥ 64）并带进度条、自己那一行 limeSoft、末尾补行、推广空态按钮不再满 lime。

## Verification

- `test/s190_intel_rank_ledger_test.dart`（新增 13 例）：kicker（快照时间 / 实时 / 无快照）、heading（有 / 无名次）、caption（有 / 无上一名、
  第一名无差距、社区名与权重、推广人数、无名次）、stamp（有 / 无总人数、无名次、榜不可用）、占比函数；页面：账本卡为 lime record folio、
  筹码在卡下、同屏 ≥44² 的满 lime 面只有 1 个、「前三名」标签、奖牌 `LoopRadius.badge`、领奖台是 `LoopRecordCard`；B 行表头、权重徽标、
  「N 人有算力」、进度条值 = 4870 / 12960 且宽 64、头像 40；末尾补行（位置在最后一行之后、来源行之前，limeSoft、名次与数字 lime）；
  自己在已读页时该行高亮且不补行；三块榜切换时 caption / stamp / kicker / 表头随之变化、用户行无徽标、推广行无权重；无名次无 stamp、
  推广空态按钮非 primary。
- 改写：`test/s113_intel_market_token_test.dart`（heading / caption 文案；滚到榜底改用页面自身的 Scrollable）、
  `test/s121b_visual_second_pass_test.dart`（领奖台 record-card 与奖牌圆角、行的副标题与 64 px 进度条）。
- 命令：`bin/dart format`（本批文件）、`bin/flutter analyze`、`python3 scripts/check_harness.py`、intel / mining rank 相关 `bin/flutter test`（结果见提交说明）。
  未起模拟器、未做真机验收。

## 0190 修订

列表行（§4）的档位按 0189 阶梯对齐：名字 `body`@600 14 → R4 `title` 15/600，副行 `captionSm` 11 → R5 `caption` 12 text2，右侧数 `figure`@700 → R6 `figure` 13/600；榜头 `LoopMono.label` → `eyebrow`。布局（名次列、头像、权重标、占比条）不变。
