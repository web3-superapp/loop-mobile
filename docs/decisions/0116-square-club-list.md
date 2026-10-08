# 0116 · 广场社区段按 DeBox 俱乐部页重排：紧凑头部 + 搜索入口 + 两组 chips + 俱乐部式卡片内联加入 +「我加入的」（S111）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S111-square-club-list.md` §2），S111-mobile 实施。
基线 `integration/v2` 6864e0c。对接后端 S111-api（决策 0099，并行实现中）：`GET /v2/communities` 目录行新增
可选键 `viewerMembership { role, status, pending }` 与 `boundAsset { assetId, symbol, logoUrl } | null`；
`membership=joined` 与 `sort` 组合。不新增依赖、`pubspec.lock` 不变、路由清单不变（无新路由）、`app.dart` 不变。

## Context

1. 需求方 v3（`LOOP/docs/09` §1 位置 2、§6.2 第 2/3/4/6 节）：广场 = 社区列表 + 语音房浏览，参照 DeBox 俱乐部页；
   删不必要提示、减少卡片包裹、常用操作入口浅、滚动加载。
2. S111 之前：广场社区段直接嵌入 `CommunityDiscoverScreen`——「DISCOVERY DESK · 已载入 N 个社区」大卡、
   四种排序 chips（吸顶）、record row（logo 44 + 名称 + 「N 名成员 · 已验证」）、底部「社区怎么入驻」notice +
   「申请入驻」按钮；加入只能进社区页、经确认弹层。行上没有本人会员关系与代币符号。

## Decision

### 1. 社区段（`SquareCommunityList`，`lib/features/square/square_community_list.dart`）

archetype `index`，布局 `stream`。`SquareScreen` 的社区段由它替换；独立路由 `community-discover`
（`CommunityDiscoverScreen`）原样保留，两者共用 `communityDiscoverControllerProvider`。

- **紧凑头部**：一行灰字 12px「按成员数 / 算力 / 讨论量 / 新建排序，热门不等于推荐」+ 右侧「规则」文字按钮
  （44 触控）。「规则」弹层（`square-community-rules-sheet`，root navigator，盖在 Tab 栏上）：原 folio 的排序说明、
  `RULE · {ruleVersion}`（目录给了 recommendation 时）、「社区怎么入驻」说明与「申请入驻」（沿用
  `startCommunityApplication`）。
- **搜索入口**：只读框「搜索社区」→ `context.push('/search')`（`SquareScreen.onOpenSearch` 可注入）。
- **chips**：一行横向滚动，`全部 · 我加入的`（互斥，默认全部）| 分隔线 | `成员最多 · 算力最高 · 讨论最多 · 新社区`
  （互斥）。「我加入的」= `membership=joined`（控制器既有：同时 `verification=all`，含本人未验证社区），保持所选排序。
  新增 `CommunityDiscoverController.selectMembership`。头部与搜索框随列表滚走，chips 用 pinned
  `SliverPersistentHeader` 吸顶（S106 验收项不退化）。
- **卡片**（`SquareCommunityRow`，行高 76，无卡片包裹）：logo 48 圆角 12；名称 + 验证小标（已验证 Lime，其余灰）；
  副行 `{memberCount} 成员 · ${SYMBOL}`（无代币只有成员数）；排序为算力 / 讨论时第二段换为
  `communityDirectoryRowFigure` 的「{caption} {value}」（缺读数为「—」，沿用 S106 / 0061 规则）。
  右侧胶囊由 `squareMembershipAction(viewerMembership)` 决定：
  - 行未带 `viewerMembership`（旧后端）→ 不显示；`status == banned` → 不显示；
  - `role == owner` →「我的」；`admin` / `member` →「已加入」（灰，点进社区）；
  - `role == null` 且 `pending == false` →「加入」（Lime）；`role == null` 且 `pending == true` →「审核中」（灰，点进社区）。
  整行点进 `community-profile`。
- **内联加入**：点「加入」直接 `POST /v2/communities/{id}/join`（既有 `CommunityGateway.join`，幂等键照旧），
  不弹确认；进行中胶囊显示小圈、不可再点；成功 toast「已加入」，按回包 `viewer.membership` 与
  `community.memberCount` 原地改该行（`CommunityDiscoverController.joinFromRow`，不打断也不等待目录读取）；
  失败 toast `communityFailureReason(kind)`，行不变。翻页合并以当前屏上行为准，翻页回包不会把刚加入的行改回去。
- **列表**：滚动加载、重试、「没有更多社区」、更新中条、排序不可用说明与 S106 相同；五态沿用
  `CommunityStateBlock`；「我加入的」为空 →「还没有加入社区」+「去看看全部」（切回全部）。
- 语音房段不改（S110）。

### 2. 契约与数据层

- `CommunitySummary` 新增可选 `assetBadge`（`CommunityAssetBadge {assetId, symbol, logoUrl}`）与
  `viewerMembership`（`CommunityDirectoryViewer {role?, status?, pending}`），`assetSymbol` 取 `assetBadge`
  再退 `boundAsset`，`withJoin` 只换会员关系与成员数。
- `LoopV2ProjectionCodec.communityRow`：`viewerMembership` 进行级可选键；`boundAsset` 在行上按三字段摘要读
  （`assetId` 过 `boundAssetKeyPattern`、`symbol` 必填文本、`logoUrl` 可空非空串），不再交给详情资源的五字段
  读法；行不产出 `boundAsset`（池子事实只来自详情）。`viewerMembership` 严格键集，role / status 为 null 或已知
  枚举，`pending` 必须布尔，否则整页 invalid。
- Preview（`MemoryCommunityGateway`，只在 `main_preview.dart` 组合）目录行按预览账号的关系带上
  `viewerMembership`。

## 与契约的偏离

| # | 项 | S111 §1 / §2 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | 缺 `viewerMembership` | 契约总带该键 | 缺键 → 字段 null → 不显示胶囊（不猜「加入」） | 后端并行上线前的旧部署；任务单要求不显示假状态 |
| 2 | role / status 组合 | 无关系 = `{null, null, false}` | 两字段各自校验，不强制「role 为 null ⇔ status 为 null」；先看 `banned` 再看 role | 组合写错会让整页 invalid，代价大于收益；按钮规则对任意组合都有确定结果 |
| 3 | `pending` 的展示 | §2 未定义 | `role == null && pending` →「审核中」灰胶囊（点进社区）；有 role 时忽略 pending（owner 的待审社区仍是「我的」） | 「加入」对已有待审申请的人是错误动作；当前后端无加入审批，`pending` 只在 owner 侧为 true |
| 4 | 行上 `boundAsset` | `{assetId, symbol, logoUrl}` | 三字段必读 `assetId`/`symbol`，`logoUrl` 可缺省；容忍额外的 `name`、`hasRegisteredPool` 但不使用 | 与详情资源同名不同形；容忍完整块以免服务端多给字段时整页失败 |
| 5 | 搜索 scope | 若支持则传 `scope=community` | 只 `push('/search')`，不带参数 | `GlobalSearchScreen` 只认 `q`；不改 `app.dart` |
| 6 | 「规则」内容 | 弹现有 RULE 说明 | 现有说明来自原 folio 的 caption 与 `RULE` stamp；弹层另收纳原列表底部的「社区怎么入驻」notice 与「申请入驻」 | 删除列表底部提示（§6.2 第 2 节）；创建入口另有聊天「＋ → 创建社区」 |
| 7 | 加入后聊天列表 | 聊天列表出现该社区 | 客户端不额外刷新聊天列表；依赖 Stream 频道成员事件与列表自身的回访刷新 | 与社区页加入路径一致；需模拟器验收 |
| 8 | 目录 controller 共用 | — | 广场与 `community-discover` 共用 `communityDiscoverControllerProvider`；在广场选的「我加入的」被独立发现页的 `openAll` / `openJoined` 覆盖后，回广场显示被覆盖后的筛选 | 不新增 provider；两页不同时可见 |

## Consequences

- 测试：新增 `test/s111_square_club_list_test.dart`（无 DISCOVERY DESK、规则弹层、搜索入口、chips 吸顶、两组互斥与组合
  请求参数、「我加入的」空态与回到全部、七种 viewerMembership 胶囊、副行代币 / 排序读数、内联加入成功原地变更与
  失败不变且无确认弹层、loading / empty / offline / unexpected / permission / unavailable、翻页到底、行编码器四例）；
  `test/support/community_test_harness.dart` 的 `FakeCommunityGateway` 加 `directoryPagesByMembership`；
  `s106_v3_navigation_test.dart` 社区段 key 改为 `square-community-list`。
- `CommunityDiscoverScreen`、`communityDirectoryRow` 与其它目录调用方不变。
- 未验证（需模拟器 + S111-api）：真实回包的 `viewerMembership` / `boundAsset`、加入后聊天列表出现该社区的时延、
  「我加入的」与 `sort=miningPower|activity` 组合的服务端行为、长名称 + 验证小标 + 胶囊在窄屏的截断。
