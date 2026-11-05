# 0288 · 广场 · 社区：去「我加入的」、排序上移 +「加入优先」、标签永远可见、入驻放标题行（S364-mobile）

## Status

Accepted · 2026-11-05（S364-mobile）。需求方验收九条（docs/62）第 2 / 7 / 8 条。改写 0274（搜索框与「全部 / 我加入的」同一钉住行）、0257（「发现社区 / 规则与入驻 ›」标题行、排序单独一行）、0264 里「标签最后、最先让位」的那一条；0264 的闪电规则（标签 =「算力社区」且有代币 → 并入代币 chip）不变。

## Context

- 第 2 条：「我加入的」按钮去掉，排序放到「我加入的」的位置，排序里加「加入优先」。
- 第 7 条：dad 的「新锐社区」标签没显示。原因是卡片元信息行里代币 chip（`$猫猫啦咯啦咯啦咯啦咯`）把标签挤没了：S335 的规则让标签最后排、窄行时先被去掉。
- 第 8 条：「发现社区 / 规则与入驻」这一行去掉，入驻放到右上角。
- api 没有「加入优先」这个排序。

## Decision

- **钉住行**：搜索框（Expanded）+ 排序下拉（「成员最多 ˅」样式不变，12 / 500 textSecondary + 下箭头，44 触控）。「全部 / 我加入的」两个筛选 chip、排序原来单独的一行、「发现社区 / 规则与入驻 ›」标题行全部删掉。行右内边距 = 页边距 − 8（排序自带 8 的触控内边距，箭头落在页边线上）。
- **加入优先**（`CommunityDiscoverSegment.joinedFirst`，ARB `community_discoverJoinedFirst` zh「加入优先」/ en「Joined first」）：排序列表顺序 = 加入优先 / 成员最多 / 算力最高 / 讨论最多 / 最新。默认仍是成员最多。客户端合并：
  - `CommunityDiscoverState.joinedFirst` 标记，`sort` 仍是 `members`；`selectJoinedFirst()` / `openJoinedFirst()` 进入，`selectSort()` 离开。
  - 先翻原「我加入的」查询（`membership=joined`、`verification=all`、按成员）直到末页，再从第一页翻已认证目录（`membership=all`、`verification=verified`、按成员）。两个服务端游标包在 `joined:` / `all:` 前缀里放进 `nextCursor`，翻页哨兵照旧可用。
  - 已加入查询的末页同一次读取里顺带读目录第一页，没加入任何社区的人首屏也是满的、不会判空。
  - 去重：同页内按已加入集合去掉目录里的重复行，后续页由 `_fetch` 原有的 seen 集合去重；一个社区只占一行。
- **我的 →「全部已加入的社区」**：目的地 `community-joined` → `/community/discover?membership=joined` 不变（旧参数兼容）。`CommunityDiscoverScreen(joinedOnly: true)` 改为进入时**一次性**切到「加入优先」的全目录（`openJoinedFirst()`），之后读者可改别的排序；页标题统一用「发现社区」，不再是「已加入的社区」。该页的排序 chip 行同样多出「加入优先」。没有改成跳 广场 Tab：从「我的」推一页保留返回路径。
- **标签永远可见**：元信息行按优先级分宽度（`squareCommunityMetaLayout`）——成员数 > 标签 > 排名事实（算力 / 讨论排序时）> 代币 chip。标签 chip 最多占行宽 45%（`squareCommunityLabelMaxShare`），超长省略；代币符号先省略，最短保留 logo + `$` + 2 字 + 省略号，仍放不下就整个去掉代币 chip。视觉顺序不变（成员、排名、代币、标签在末尾）。算力社区的闪电仍在代币 chip 里；若代币 chip 放不下，标签以普通 chip 回来，标记不丢。
- **入驻**：`SquareCommunityApplyEntry`（key `square-community-apply-entry`）经 `LoopSegmentedTabPage.actionsBuilder` 放在 广场 标题行（「动态 社区 语音房」那一行）右端，只在社区页签出现；文字「入驻」（en「Apply」）12 / 500 textSecondary + 右箭头，44 触控，读屏名沿用「规则与入驻」。点开原「规则与入驻」那张表（排序规则 + 申请入驻，`showSquareCommunityRules`），申请流程不变。
- 删除不再使用的文案键：`square_communityListJoined`、`square_communityListBuild`、`square_communityListSquareCommunityJoinedEmptyAllLabel`、`square_communityListSquareCommunityJoinedEmptyTitle`。

## Consequences

- 「我加入的」空态（`square-community-joined-empty`）随筛选一起删除；加入优先下没加入任何社区就是普通目录。
- 控制器的 `membership` 筛选与 `openJoined()` / `selectMembership()` 保留（无 UI 入口，测试仍用），不影响 api 契约。
- 测试：新增 `test/s364_square_community_list_test.dart`（钉住行无筛选 chip、排序在搜索框右侧同一行、排序表顺序、加入优先两段读取 + 去重 + 翻页 + 验证筛选、无已加入时不判空、`membership=joined` 落到加入优先且只应用一次、390 / 360 / 320 下长代币符号时标签仍完整且 ≤45%、闪电规则、入驻只在社区页签并打开原表）。测试桩 `FakeCommunityGateway` 加 `directoryPageFor` 钩子（按 membership / verification / cursor 应答）。改写 s111 / s335 / s350a / s327 / s197_3 / community_pages_test 的旧断言。
