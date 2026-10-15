# 0174 · MEME 代币页改为设计稿「代币页 B」（S187-2-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e49203（含 0166 ~ 0172）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15.md` 与 `body.html`「代币页 B」手机框（HTML 结构即规格），
用户 2026-10-15 裁决「代币页 = B」。只改 `meme-token` 页的版式与快买入口：路由、状态合同、请求路径、
controller、轮询、签名出口（仍只有 `_trade` → `showMemeSignSheet`）不变；路由数不变；不新增依赖与字体。
行情 Tab 的 `market/token_screen.dart` 本批不动；`meme_widgets.dart` 的 `MemeTokenCard` / `MemeProgressPill`（S187-1 在改）未碰。

## Context

旧代币页顶部是松散几块：单独的身份行、价格 + 1h + 「市值 …」一行、内盘进度大段文字（已募 / 目标 / 说明句），
走势图在进度之后、区间 chips 在图上方，要滑一屏才看到图；底部是等宽的「卖出 / 买入」。设计稿 B 照 fomo：
大价格与满版走势直接铺在页面上，两格统计 + 进度条，持有者 / 动态 / 关于，底部满 lime 买入 + ⚡ 快买。

## Decision

### 1. 顶栏（`.topbar`）
- `LoopDashboardPage` 新增可选 `titleField`（透传 `LoopTopbar.titleField`；缺省 `null`，其它页像素不变），
  `title` 仍是 `$SYMBOL`，作为栏的无障碍名称。
- 标题列 `_TokenTitle`：`MemeLogo` 36、圆角 `LoopRadius.innerValue`；ticker（`LoopType.title` 15，key `meme-token-ticker`）
  + `LoopBadge(mute)` 状态（key `meme-token-status-badge`：草稿 / 创建中 / 内盘 / 已打满 / 暂停 / 已毕业）；
  副标题「名称 · 0x8a3f…c21e」+ copy 字形（key `meme-token-identity`）。文字列整体是一个 ≥44 高的 InkWell
  （key `meme-token-copy-address`，语义「复制合约地址」），点按复制合约地址。右侧分享不变。
- 删除单独的 `_IdentityLine`。

### 2. 价格头（`.pricehead`）
- 左：`LoopType.figureXl`（28，最接近设计 30 的 figure 档，不新增字号）价格；下一行
  「▲ $0.0₅4797 (14.38%) · 1h」（key `meme-token-change`，figureSm 600，0117 rise / fall）。绝对变化
  `memeChange1hAmount` = 现价 × pct / (100 + pct)（即现价 − 1h 前价，Decimal）；无价格时只画「▲ 14.38% · 1h」；
  未报告仍是「1h 涨跌未报告」；已毕业仍写「外盘价格」。
- 右：「$9,891 / 市值」：`LoopType.figureMd`（17；figure 档没有 15，取最接近的上一档）+ captionSm。
- 价格缺失沿用 `memeQuoteUnavailableText`（key `meme-token-price-unavailable`）。
- 价格来源行 `meme-token-price-provenance` 从价格头里移到统计条之后（保持「图紧接价格头」，规则 25 的来源仍在页内）。

### 3. 满版走势（`.bigchart`）
- 紧接价格头，高度 `memeTokenChartHeight` = 屏高 × 0.3 夹在 180–260（700 pt 屏 = 210），横向 0 边距、无卡壳、无成交量条。
- `LoopMarketChart` 新增两个可选参数（缺省时像素不变）：`lineColor`（缺省按窗口涨跌着色）与
  `lastPriceTag`（缺省 false）。代币页传 `lineColor: lime, lastPriceTag: true`：虚线现价线与现价圆点用 lime，
  圆点加 18% lime 光晕；价签改为图上方的 widget（key `loop-market-chart-last-price-tag`，lime 底、
  `LoopRadius.badge` 7、ink figureXs 700），不再画轴上 16 px 方块。
- 少于两根蜡烛的占位（0121，`meme-chart-empty`）与读取态不变。

### 4. 区间胶囊（`.segs` quiet）
- 图下方一排 `LoopSeg(quiet)`：LIVE / 1H / 4H / 1D 分别对应现有 `1m / 1h / 4h / 1d` 桶；**ALL 没有对应桶，不画**；
  5 分 / 15 分不再提供。默认 LIVE（1m）：新币几分钟内就能画出走势，默认 1H 会让刚上线的币落在「还没有成交」。
  key `meme-interval-{wireName}` 与 `meme-interval-strip` 不变。
- 行尾「K」（key `meme-chart-style`，quiet，K 线时为选中）切换 K 线 / 折线（现有能力）。
- 0131 的「区间在图上方」被本条取代：底栏高度由页面测量预留，chips 在图下也不会被底栏遮住。

### 5. 两格统计 + 进度条
- `LoopStatGrid`（key `meme-token-stats`）：「打满进度」`33.27% · 还差 $X`（`LoopStatTone.up` = lime 字；
  还差 = `fillTargetUsd1 − realUsd1`；已毕业「100% · 已毕业」）/「24h 交易量」`memeCapLabel(row.volume24hUsd1)`。
  cell key `meme-token-stat-progress` / `meme-token-stat-volume`。
- 下接 `LoopProgressBar`（key `meme-token-progress-bar`，6 px，semantics 不变）。删除旧 `_ProgressBlock`
  的「内盘进度 N%」标题、「已募 … / ≈…」与说明句。
- `volume24hUsd1`：本仓库 codec 早已把它作为行与详情的**必填**字段解析（`MemeTokenRow.volume24hUsd1` 为非空
  `Decimal`），缺这个键整份响应即被拒，所以「暂无」分支不存在、没有写。

### 6. 持有者 / 动态 / 关于
- `MarketTabBar`（chalk 下划线）不变；持有者标题带人数「持有者 12」（取 `row.holderCount`），
  tab key 因此是 `meme-token-tab-持有者 12`；动态 / 关于 key 不变。
- 持有者行改 `LoopRecordGroup`（key `{prefix}-rows`）内的 `LoopRecordRow`（`memeHolderRow`）：头像 36、名称、
  「第 N · 数量 $SYM」；右侧持有价值（`balance × 现价`，mono；无价格时写数量）；索引没有成本价，右下写持有占比；
  创建者 / 我 徽标放在 `trailingBadge`。行 key `{prefix}-{wallet}` 不变；独立持有者页同用。
- 设计稿的「只看已关注」开关没有数据源，不画。

### 7. 流动性提示
- 交易中且 `realUsd1 × 20 < fillTargetUsd1`（内盘储备 < 毕业目标 5%）时，统计条下画
  `LoopNotice(tone: warn)`「流动性低 · 内盘储备 $X，大额买入滑点高」（key `meme-token-liquidity-low`）。
  放在统计条下而非设计稿的列表末尾：长列表时末尾几乎看不到。

### 8. 底栏（`.bottombar`）
- 交易中：满 lime「买入」（`LoopButton primary`，key `meme-token-buy`，同屏唯一满 lime）+ 右侧 ⚡ 快买方键
  （key `meme-token-quick-buy`，52 宽、`LoopTouch.primaryButton` 高、card2 底、chalk `bolt` 字形、`LoopRadius.control`）。
  持有 > 0 时左侧多一个次级「卖出」（key `meme-token-sell`，买入占 2 份宽）；未持有时不显示（面板内仍可切卖出）。
- 快买：打开现有买入面板，金额预填「本次运行上次确认过的买入金额」，没有就 `10` USD1，随后照常报价；
  仍须在面板点「确认买入」，再走 `_trade` → 签名面板（含 0152 大额二次验证）。不新增签名出口。
  记忆在 `memeQuickBuyAmountProvider`（内存 Notifier，不落盘：金额是资金事实，不进 SharedPreferences / 安全存储）。
  `showMemeTradePanel` / `MemeTradePanel` 新增可选 `initialAmount`。
  （docs/35 末尾曾写「快买默认金额沿用大额验证阈值」；本批按任务清单用「上次金额 / 10 USD1」。）
- 新增字形 `assets/icons/i-bolt.svg`（24 box、fill none、currentColor 1.7，与 sprite 同笔）并登记进 `LoopIconNames`
  （70 → 71）：LOOP 不打印系统 Emoji（0117），⚡ 不能用文字。
- 其它状态（打满 / 暂停 / 创建中 / 草稿 / 已毕业 / 测试网兑换）的底栏不变。

### 9. 其它顺序
提交状态 notice、毕业横幅、隐藏提示移到价格头之上（出现时才占位）；持仓行、持仓读不到、合约核对中、价格来源在统计条之后。

## Consequences

- 首屏即是价格 + 满版走势；内盘进度从一段文字变成两格统计与一条进度条。
- `LoopMarketChart` 的两个新参数默认关闭，行情代币页与全屏图像素不变。
- 可见变化（均待主代理真机验收）：顶栏变 logo + ticker + 徽标 + 地址行；区间 chips 从图上移到图下且只剩四档；
  图变 lime 线、无成交量条、lime 价签；进度说明文字消失；持有者行变 record 组；底栏变「(卖出) 买入 ⚡」。

### 未按清单做的点
- ALL 区间：服务端没有对应桶，不画（清单允许）。
- 「24h 交易量 缺则暂无」：字段已是必填，无缺失路径。
- 价格字号 30 / 市值 15：取 `figureXl` 28 与 `figureMd` 17，未新增字号。
- 持有者涨跌：索引没有成本价，右下写持有占比（清单允许）。
- 设计稿的自选 ☆ 与「只看已关注」：清单未要求，且后者无数据源，未画。

## Verification

- `bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  meme / 行情图相关 `bin/flutter test`（结果见提交说明）。
- `test/s117_meme_launchpad_test.dart` 新增 / 改写：顶栏（logo 36 r12、ticker、mute 徽标、地址行）、价格头（figureXl、
  金额 + 百分比涨跌、rise 色、市值在右）、满版图（高度 = `memeTokenChartHeight`、左 0 满宽、lime、无成交量、紧接价格头、
  lime r7 ink 价签）、LIVE/1H/4H/1D/K 无 ALL、两格统计与 6 px 条、tab 标题带人数、流动性提示、无价只画百分比、
  底栏只有一个满 lime 且快买 card2 / 52 / bolt、未持有无卖出、快买预填 10 USD1 并记住确认过的金额、快买预填上次金额；
  区间条改为在图下。`test/loop_assets_test.dart` 字形数 70 → 71。
- 未起模拟器、未做真机验收。
