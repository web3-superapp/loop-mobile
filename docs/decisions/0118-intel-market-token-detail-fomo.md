# 0118 · 情报页（算力榜三榜 + 行情三分类 + 活动位）与代币详情 Fomo 式重排（S113）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S112-S114-intel-wallet-visual.md` §3），S113-mobile 实施。
基线 `integration/v2` 9e46f42（已含 S111 广场、S112 设计 Token）。后端契约 loop-api `integration/v2` 148b1e0
（决策 0100，dev 已部署）。客户端单侧：不新增依赖、`pubspec.lock` 不变、路由清单与 `lib/app.dart` 不变。
新增一个产品开关 `LoopFeatureSwitches.outboundMarketListsVisible = false`。修订 0084 / 0085 / 0086 / 0092 /
0096 的行情行与代币页布局。

## Context

1. 需求方 v3（`LOOP/docs/09` §1 位置 4、§2.1 C18 / D1 / D2 / D3）：情报 = 算力榜（社区 / 用户 / 推广）+ 行情；
   行情按 Fomo 参考（`LOOP/docs/evidence/2026-10-08-reference-fomo/`）重排：无卡片、64 高行、市值、涨跌色；
   代币详情折线默认、可切 K 线、可拖可缩可长按、时间轴可读；所有列表滚动加载到底说「没有更多」。
2. 后端 0100 新增 `GET /v2/market/assets?category=`、`GET /v2/intel/promotions`，`/v2/mining/rank` 加
   `scope=referrals`、`me`、`nextCursor` 与 alias 行的 `avatarRef`。旧客户端的严格解码对 `me` / `nextCursor`
   / `avatarRef` 会判无效载荷，本单同时完成解码。
3. 「管理自选」在空自选态误跳价格提醒页（2026-10-08 发现）。

## Decision

### 1. 数据层

- `market_read_models.dart`：`MarketCategory`（major / meme / community，标签 主流 / MEME / 社区代币）、
  `MarketCategorySort`、`MarketCategoryQuote`（`Decimal` + `observedAt` + `source` + `quality`
  fresh / stale / proxied）、`MarketCategoryRow`（`quote == null` 时必带 `quoteUnavailableReason`）、
  `MarketCategoryRules`、`MarketCategoryPage`（`append` 去重）；`IntelPromotion(s)`。
- `DioLoopV2MarketApi.getCategory`：首屏带 `category` + `sort`；翻页带 `category` + `sort` + `cursor`，**不带
  `limit`**（同时传入在客户端即拒）；`decodeCategory` 校验回声的 category / sort、行内 assetId 不重复、
  `community` 键只在 community 分类出现且必出现、`quoteUnavailable` 恰在 `quote: null` 时出现、ordering 三选一；
  分类行的 sparkline 拒因放宽为任意合法 reasonCode（测试网行同样带 `MARKET_CHAIN_NOT_PRICED`）。
- `getPromotions` / `decodePromotions`：无 query；`deeplink` 只认 `/intel`、`/square`、`/meme`、
  `/community/profile?id=<uuid>`，图片只认 https，按 `order` 排序。
- `DioLoopV2MiningApi.getRank(scope, cursor?)`：顶层必含 `me`、`nextCursor`；`referrals` 榜
  `{position, invitedCount, display, isSelf}` + `ruleKey`，名次不倒退、自己最多一行、同一 profile 不重复；
  `me` 在社区榜可带 `communityId`；alias 行必含 `avatarRef`（`avatar:` 形状或 null）。
- 端口：`MarketReadGateway` 加 `loadCategory` / `loadPromotions`，`MiningGateway.loadRank` 加 `cursor`，
  Unavailable 默认与 V2 适配器同步。
- 控制器：`MarketCategoryController`（family，按分类；`loadMore` 追加，cursor 400 → 回第一页）、
  `IntelPromotionsController`、`MarketTradesController.loadMore`、`AlertsController.loadMore`、
  `IntelRankBoardController`（`lib/features/intel/`，换榜丢弃旧榜、晚到的旧榜答案作废，`loadMore` 追加）。
  `MarketCandleRequest` 加 `limit`，代币图表读 `limit=300`（钱包与群卡片的小线不受影响）。

### 2. 情报 · 算力榜（`IntelRankBoard`）

- chips 社区 / 用户 / 推广；「我的名次」卡（有 `me` →「第 N 名」+ 算力或「N 人」，无 →「还没有名次」+ 一句如何上榜）；
  行 = 名次（前三 Lime）/ 头像（用户与推广：`LoopProfileAvatar(avatarRef)`；社区：`CommunityLogo`）/ 名字 / 数值；
  匿名成员仍按服务端标签显示「匿名成员」（B7）；社区行点开社区资料。滚动到末尾读 `nextCursor`，读完显示「没有更多」，
  失败为一行可重试。
- 「排名不是静态权益」「排行条目如何显示身份」两张卡删除，改为底部一行 `LoopProvenanceLine`：
  「按当前生效的算力公式 · 来源 LOOP 算力快照 · 观察于 HH:mm」（推广榜：「按直接邀请人数 · 来源 LOOP 邀请关系」），
  点开是原两张卡的文字。快照过期 / 含演示持仓的两条提示保留。
- 独立路由 `mining-rank` 保留社区 / 用户两榜，去掉「推广榜还没有开放」占位。

### 3. 情报 · 行情（`MarketScreen`）

- 活动位横滑卡（只在情报内嵌时出现；读不到或 `items: []` 整块不画）；`/intel` 切到算力榜段，`/square`、`/meme`
  用 `GoRouter.go` 切 Tab，社区资料 push。
- chips 自选 / 主流 / MEME / 社区代币（`LoopSegBar`）；「新币」chip 与「聪明钱追踪」行只在
  `outboundMarketListsVisible` 为 true 时出现（页面与路由保留）。
- 行 `MarketFomoRow`：Logo 36 + 「SYMBOL / 市值 $x」（自选块不带市值，第二行为资产名）+ 右「价格 / ▲▼x%」，
  价格与涨跌文字按 `LoopPriceMove` 取 rise / fall；行高 64、无卡片、底部分隔线；报价读不到时右侧为
  `LoopInlineUnavailable`（短句：测试网代币不报价 / 行情限流中 / …），不显示 0；stale 加「延迟」、proxied 加
  「以 WBNB 计价」。
- 分类列表滚动加载（每行是独立 section，`LoopLoadMoreSentinel` 只在接近末尾时构建），读完「没有更多」；自选列表
  一次读完同样显示「没有更多」。
- 自选空态「还没有自选」+「去主流看看」（就地切到主流）；有自选时末尾「管理自选」→ `/market/watchlist`
  （修正误跳提醒页）。
- 删除 `market-truth-notice`、统计行 `MarketStatsLine`、排序表头与排序脚注、热门 / 涨幅榜两个 Tab；来源合成一行
  `LoopProvenanceLine`（分类：DexScreener + 最早观察时间，点开写排序规则）。harness 白名单里
  `market_widgets.dart` 的过渡项随统计行一并删除。

### 4. 代币详情（`TokenDetailScreen`）

- 顶栏：返回 + SYMBOL + 提醒 / 自选 / 分享（系统分享：符号、名称、合约地址，不带价格）；其下一行
  Logo + 「名称 · 0x12…34」+ 复制地址。
- 价格区：`figureXl` 价格 +「▲ $x (x%) · 24h」（rise / fall；$ 值由价格与 24h 百分比推得）+ 右侧「市值」。
- 图表 `LoopMarketChart`（新文件 `loop_market_chart.dart`）：无卡片，高度约屏高 40%；默认收盘价折线（按窗口首尾
  涨跌取色 + 渐隐填充），工具条右侧切 K 线、MA（默认关，MA7 / MA25 读数标「本机计算」）、VOL（默认开）；周期 chips
  15分 / 1时 / 4时 / 1日 / 1周；一次读 300 根，默认显示最近 60 根；单指横向拖动平移、双指缩放 20–300 根、
  长按十字线（价格气泡在右轴、时间气泡在下轴，松手消失）；时间轴 4–6 个刻度（每约 80pt 一个）、右侧 4 个价格刻度
  与最新价标签；左缘 24pt 不放手势区（给系统边缘返回）；无任何动画（reduced motion 下一样）。`Decimal` 只在按全序列
  区间归一化后转为 `double`，轴上与气泡里的数字都取自 `Decimal`。
- 图表下一行 `LoopProvenanceLine`：「{按成交价折算 / 以 WBNB 计价 / 数据可能过期 · 未登记池 · 最后一根进行中 ·}
  单位 X · 来源 Y · 观察于 HH:mm」，点开为池与来源全文（AGENTS 第 25 条的 stale / derived / proxied 标记仍在页面上）。
- Tab 持有者 / 动态 / 关于：持有者 = 持有人数 + 「持有人分布暂不可用」一行 + 来源行；动态 = 已登记池成交，
  买 rise / 卖 fall，按 cursor 滚动加载到「没有更多」，来源行带索引高度；关于 = 24h 高 / 低、成交额、流动性、FDV、
  市值格子、合约地址、社区卡、挖矿权重（有才显示）、池与合约事实（原 tray 内容，全部事实、风险项在前、一行来源）、
  通知、兑换门（`capability.swappable`，关时为一行不可用）。
- 删除：报价下的 tray 与 `TokenQuotePanel` / `TokenFactsTrayDetail`、`token-facts-notice` 说明卡、OHLC 读数行。
  底部买入 / 卖出栏不变。
- `chart-full` 复用 `TokenCandleSection`，进入时锁横屏、离开时交还应用默认方向。

### 5. 其它列表

- 价格提醒：提醒列表与触发历史都改为滚动加载（触发历史整块构建，使用按可见位置触发的 `MarketVisibleSentinel`，
  避免一次读完所有页）；空态文案改为「设一个目标价，价格到了会在通知里告诉你。」
- 成交页 `token-trades`：滚动加载到「没有更多」。
- 自选编辑：Watchlist 是整份文档（无分页）；「添加资产」在新币隐藏时改去情报 · 行情。

## 偏离表（相对设计 §3）

| 设计 §3 | 实现 | 原因 |
| --- | --- | --- |
| 算力榜来源行写「公式版本 + 快照时间」 | 「按当前生效的算力公式 · 观察于 HH:mm」，版本号不上屏 | harness `check_user_visible_copy` 禁止把 configVersion 插进用户文案（只能放 LoopDisclosure） |
| 顶栏 = Logo + SYMBOL（名称 · 复制地址） | 顶栏只放 SYMBOL 与三个工具；Logo、名称、短地址、复制在顶栏下一行 | `LoopDashboardPage` 顶栏只收字符串标题，`lib/widgets/` 不在本单边界 |
| 价格区「▲ $x (x%) · 周期」 | 「· 24h」，取服务端 24h 涨跌 | 按图表窗口自算涨跌是本机推导的数字，AGENTS 第 25 条要求数字有来源 |
| 行情行（未提 sparkline） | 行内不画走势线 | Fomo 参考无走势线；行高 64 内放不下第三列；列表仍不逐行请求 K 线 |
| 自选行「市值 $x」 | 第二行为资产名 | overview 的自选块不带市值 |
| 市值格式 | 沿用 `loopFormatCompactFigure`（$1.6B，一位小数） | 与全应用摘要格式一致 |
| 情报算力榜在 `mining_secondary_screens.dart` | 新组件放 `lib/features/intel/`（`IntelRankBoard` + 控制器），独立路由的 `MiningRankScreen` 只做最小改动 | 情报页的榜单行为（三榜、滚动、我的名次）与独立路由不同，分开避免改坏 `mining-rank` |
| 文件边界 | 另动了 `mining_models.dart`、`mining_gateway.dart`、`loop_v2_s5_gateways.dart`、`loop_v2_s7_gateways.dart`（端口与适配器各加一个方法 / 参数）、`watchlist_editor_screen.dart`、`alerts/*`（滚动加载与空态）、`tests/test_check_harness.py` 一个夹具 | 新契约必须穿过端口；C3 夹具依赖的 `labels: const <String>['MA', 'VOL']` 随 MA/VOL 进入共享工具条而消失，夹具改为在图表段旁注入 |
| 自选编辑分页改滚动 | 无改动（文档无分页） | Watchlist 是整份资源（AGENTS 第 15 条） |
| 行情 / 情报以外的 `MarketAssetTile` 等 | 保留源码（测试仍覆盖），产品不再挂载 | 清理留给后续单，避免本单删测试过多 |

## 未验证

- 真机手势：iOS 边缘返回与图表左缘 24pt 的分界、双指缩放手感、长按与纵向滚动的竞争（widget 测试已覆盖逻辑）。
- `chart-full` 锁横屏在 iOS / Android 真机上的旋转与返回后恢复。
- dev 真实响应：未在本机请求 `api-dev`，三分类、活动位、推广榜的真实载荷只经契约测试样例验证。
- 300 根数据下拖动 / 缩放的帧率（每帧只做 `double` 运算，`Decimal` 归一化在换数据时做一次）。
- Android Debug 构建未在本单运行（门禁清单不含；机器负载高）。

## Consequences

- 行情三分类与活动位是新的读请求；分类翻页 cursor 10 分钟过期时列表静默回到第一页。
- `outboundMarketListsVisible` 改 true 即恢复「新币」chip 与「聪明钱追踪」入口。
- 0084 / 0085 的 58pt 行、走势线槽、色块，0092 / 0096 的报价 tray 在产品里退场。
