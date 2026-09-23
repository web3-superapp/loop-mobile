# 0079 · 一次拒绝、一个读数与一只时钟

## Status

Accepted 2026-09-23。S77c，客户端单侧。不新增路由，93 条路由清单不变。
依赖已上线的 `POST /v2/message-requests`、`GET /v2/search`（后端决策 0071 起
`assets` 域可用）、`GET /v2/mining/communities/{id}`、`GET /v2/mining/assets`、
`GET /v2/mining/summary`、`GET /v2/mining/rank?scope=users`、`GET /v2/wallets`、
`GET /v2/privacy`、`GET /v2/connections`。安全中心与 Privy 能力投影不在本决策内
（走查 2026-09-23 待裁决第 4 条）。

## Context

2026-09-23 主代理 93 页真机走查（`LOOP/docs/acceptance/2026-09-23-full-walkthrough.md`，
截图 `docs/evidence/2026-09-23-full-walkthrough/`）在社区 / 社交 / 搜索 / 我的
四个域里记下八类问题。它们不是八个独立的 bug，是三条同样的毛病：

1. **写操作失败没有留下痕迹。** 「发送消息请求」在服务端 404（对方没有开放
   「显示 LOOP ID」）后，页面既不改按钮也不留说明，只有一条已经消失的 toast
   （i06/i07）。用户会一直点。
2. **读得到的数字被写成了说明文字。** 「我的」页算力行写「这一页不读算力」，
   社区详情的挖矿卡三格永远是「—」并注明「这张卡片不替它们估算」，而挖矿模块
   两个接口里就有这些数（h01、a48）。搜索框承诺五个域，其中三个对任何词都回
   「域暂不可用」（a55–a65）。
3. **同一个时刻有两只时钟。** 聊天页印本地时间 20:06，两屏之外的转发页、成员页、
   快照、设备页把同一个时刻印成 `2026-09-17 13:38 UTC`。聊天页的日期胶囊本身也
   不稳：同一条 2026-09-21 的消息三次进入分别显示「周一」「周四」「今天」
   （a10/a11/a33）。

## Decision

### 1 · 被拒绝的消息请求是页面状态，不是一条播报

`DirectChannelState` 增加 `requestFailure`。失败时页面留下
`dm-message-request-failed` 说明卡（notFound → 「对方没有开放被找到，或者这个
账号不存在，消息请求没有送出。」），按钮改成「重新发送消息请求」并保持可按。
可达性仍然不可枚举（决策 0070）：关掉的开关、不存在的账号、没有好友关系都回
同一句话。资料卡「关注」失败早已有 `public-profile-failure` 内联说明，本次只
补了回归测试。

### 2 · 搜索只承诺答得上来的域，并落在有结果的那个

- `searchDomainIsDeferred` 现在只剩 `launch` 与 `dapps`；输入框标签由
  `searchableDomains` 拼出，因此永远等于实际可搜的域（今天是「搜索资产、社区、
  用户」）。一个域拿到后端的同一次提交里就会出现在标签上。
- 提交查询时，若所选域可用且零结果，按 chip 顺序依次问其余可搜域，落在第一个
  有结果的域上；**用手点 chip 选定的域不会被改写**——那是一条指令，空答案就是
  答案。补问失败的域只影响它自己，不会把已经拿到的空结果变成错误页。
- 三个不可用码按后端决策 0071 更名并分开说：`LAUNCH_PROJECT_DIRECTORY_PENDING`
  是「LOOP 还没有 Launch 项目目录」，`DAPP_DIRECTORY_NOT_INTEGRATED` 是「DApp
  目录还没有接入」，`ASSET_REGISTRY_NOT_COMPOSED` 只在注册表这次没组合出来时出现。
- 资产域接上：`SearchDestination` 改成 sealed 类型，`assetDetail` 是唯一带参数
  （`assetId`）的目的地，行点击用它打开代币页；`stableId` 对资产是 CAIP-19 id，
  严格解码按 `resultType` 分别校验 UUID 与 `MarketAssetRoute.isCanonical`。
- 社区搜索面板里那句「全局资产与社区搜索从社区 Tab 顶部进入。这是唯一的全局
  搜索入口。」删掉——它在向已经打开它的人解释它在哪。01 文档 §3/§12.2 规定的
  这句话属于 `chat-search`（那里原来写的是「从社区首页进入」），已按文档原文订正。

### 3 · 社区详情的挖矿卡读它能读到的三格

卡片新增 `CommunityMiningAccountReading`：

| 格 | 来源 |
| --- | --- |
| 我的持仓 | `GET /v2/mining/assets` 里绑定资产那一行的 `holding`（带 symbol） |
| 我的算力 | `GET /v2/mining/communities/{id}.myContribution` |
| 预估/日 | 无来源 · 服务端只按账号总算力结算 `estimatedToday`，卡片不做除法 |

两个读都是挖矿面板自己的读，且每个社区只发起一次，所以从卡片点进面板不会再发
第二次请求；读不到时每格印「—」并在卡片下写出服务端给的原因。社区总算力走
`loopGroupedFigure`（531381.12 → 531,381.12）。第三格保留「—」是有意的：
设备上不编造服务端没有结算过的数。

### 4 · 「我的」页印数字与状态，不印实现说明

- 算力行读 `GET /v2/mining/summary.power` 与
  `GET /v2/mining/rank?scope=users.myPosition`，印「4.48 / 我的名次 第 47 名」。
  用户榜是一个固定 scope 的第二个读者（`miningUserRankControllerProvider`），
  因为 `miningRankControllerProvider` 的 scope 是排行榜页的页面状态。
- 账户四行补副标题：钱包数、匿名模式、关注/粉丝。**读不到就不写第二行**，不写
  「读不到」。安全中心暂不写：服务端投影把六种方法全报 unavailable，而设备上
  Privy MFA 已经在用，两边对齐之前这一行不下结论。
- 头像 monogram 在浅色地面上按原型画成 ink 底 + chalk 字（`#scr-profile` 就是
  `background:var(--ink); color:var(--chalk)`），不再是 Chalk 卡上几乎看不见的
  `card2` 灰盘。

### 5 · 标签是 chip 流，hero 跟着页面滚

`LoopSeg` 把标签放在设了 `alignment` 的 `Container` 里，而 `Wrap` 给子节点的是
松约束——居中容器会吃满可用宽度，于是五个标签各占一行整宽。兴趣标签外面套
`IntrinsicWidth` 量出自己的宽度即可。**根因在共享组件上**：任何把 `LoopSeg` 放进
`Wrap` 的地方都会这样（swap 页三个滑点档竖排是同一个原因，那页归 S77a），是否
改 `LoopSeg` 本身留给主代理裁决。
`profile-edit` 的 hero 从 `LoopFocusPage.folio`（固定）移进 `body` 第一行，跟着
内容滚——`#scr-profile-edit` 本来就把它放在滚动容器里。

### 6 · 私聊页：一行说明，没有压在输入框上的卡片

固定 hero（四分之一屏、重复顶栏已有的名字）换成一行
`LoopChatHeaderStrip`：「不声明端到端加密 · 私聊由 Stream Chat 承载」。列表底部
那张常驻说明卡去掉。Chalk hero 留在**没有会话**的状态（还不能直接私聊 / 缺少会话
标识），那里页面本来就只有它。

### 7 · 日期胶囊回到消息流里，时钟只有一只

- 关掉浮动日期胶囊（`StreamMessageListViewConfiguration.showFloatingDateDivider`
  = false，在 `loopStreamChatConfiguration` 里一次设定）。它画在会话之上（`dm` 里
  压住第一条气泡的一半），而且它印的是视口锚点那一项的日期，还要减去列表自己的
  两行特殊项（`floating_date_divider.dart:71`）。行内分隔符留下：它由**单条消息
  自己的** `createdAt.toLocal()` 生成，夹在它分隔的两天中间，跟着列表滚。
- `LoopServerClock.observeAtLeast` 的下限改成「当前 offset」，包括初始的零。原来
  第一条无括号观测无论说什么都被采信，于是 socket 回放的一条两天前的消息把「现在」
  推到两天前，周一的消息头上就写了「今天」。
- 服务端时刻统一按读者本地墙钟显示：新增 `lib/core/time/loop_time_format.dart`，
  `communityObservedAtLabel` / `communitySettlementLabel` /
  `loopSessionCreatedAtLabel` 都走它，不再印 `UTC` 后缀。测试里的期望值用同一个
  函数生成，避免把某一个时区写死。语音房（S77d）、钱包与行情（S77a）的标签不在
  本次改动内。

## Consequences

- 搜索在「所选域空结果」时最多多发 2 次请求（可搜域只有三个）。`assets` 不消耗
  公共配额，`users`/`communities` 共用配额桶 30/分钟，输入框有 300ms 防抖。
- 社区详情多两个挖矿读（每个社区一次），「我的」页多四个读（钱包、隐私、关注、
  挖矿摘要与用户榜）。每一个都是对应入口自己的读，进那一页时不会重复请求。
- 私聊页不再有 Chalk hero；`s58c` B.3「dm opens on the Chalk hero」现在成立于
  无会话态。
- 时间显示改动影响社区成员/快照/转发/搜索/设备页；`UTC` 字样在这些页面消失。

## Not done here

- 私聊 composer 的「贴合约地址识别代币」**保留**。走查建议在私聊里去掉，但
  `_withTokenCards` 对任何频道的任何气泡都会画代币卡，私聊里也会画，所以这句话
  在私聊里是真的；决策 0075 与 `check_harness.py` 也锁定三个会话共用同一个
  placeholder。要改需要先改识别范围，留给主代理裁决。
- 安全中心与 Privy 已接能力的对齐（走查待裁决第 4 条）。
- `LoopSeg` 在 `Wrap` 里吃满宽度的根因修复（见 5）。
