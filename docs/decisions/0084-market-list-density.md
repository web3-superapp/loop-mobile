# 0084 · 行情是一张价目表，按交易所的密度读

## Status

Accepted 2026-09-23。S78b，客户端单侧。不新增路由，93 条路由清单不变。

改动范围：`lib/features/market/**`、`lib/widgets/loop_assets.dart`，以及主代理
本单特批的 logo codec 文件（`lib/integrations/backend/v2/loop_v2_chain_codec.dart`
与 market / wallet / watchlist / mining / search 五个 API，加
`lib/integrations/market/memory_watchlist_gateway.dart` 的 Preview fixture）。
`scripts/check_harness.py` 只改了一行常量，见 §11。

契约：只消费已冻结的 `loop-api/docs/frontend-v2-market-api.md` §2a（决策 0072，
已合并 loop-api `integration/v2`，Dev 栈待部署）。

## Context

需求方 2026-09-23 先给了一句「行情页面的 UI 有点差」，随后要求「近似交易所的
感觉」并**批准了设计稿**（`Main.dc.html` / `Token.dc.html`，390×844 画板）。
走查报告 `LOOP/docs/acceptance/2026-09-23-full-walkthrough.md` 与截图
`docs/evidence/2026-09-23-full-walkthrough/`（d01–d08、e01–e05）把「差」拆成了
可以逐条修的东西：

| 现象 | 证据 |
| --- | --- |
| 自选行副标题是「PancakeSwap Token · 权重 1× · 开发基线」，内部标签用主色印在每一行，且换行成两三行，行高参差 | d01–d03 |
| 同一列表里只有三行有小折线，其余没有，页面不解释 | d02 走查「趋势区」 |
| hero 说「1 项涨跌读不到」，指的是 USDT ——稳定币没有涨跌可报，对用户是噪音 | d01 |
| 「MARKET SIGNALS」「4 WATCHED」「NEW PAIRS」「HIGH RISK」「HOLDER LEDGER」「ACTIVITY TAPE」裸英文 | d01、d05 等 |
| 新币行把 provider slug `four-meme` / `pancakeswap_v2` / `uniswap-v4-bsc` 原样印出，再叠两个否定，每行三行字 | d06 |
| 头像把整串标签当字母画进去：「OH /」「YAMA」「SWBR」 | d06 |
| 代币页「Mining Weight 1× · 开发基线」在首屏出现两次 | e01 |
| 代币页「行情事实」卡与 hero 三格印同一组数字 | e01、e02 |

根因不是八个，是四个：**行是按「记录行」排的而不是按价目表排的**；**内部口径
当成了用户信息**；**同一个数字被印了两遍**；**这一页没有交易所列表该有的骨架**
（搜索、分段、统计条、可排序列头）。

## Decision

### 1 · 行情列表按设计稿重建

- 顶栏：标题 + 价格提醒。
- 搜索框：**是控件不是输入框**。LOOP 的搜索是跨五个域、带自己的筛选与出处的
  独立页；在这里打字会是第二个更弱的搜索。按下去打开那一页。
- 四个 Tab（自选 / 热门 / 涨幅榜 / 新币，Lime 下划线）。**热门与涨幅榜是同一次
  trending 读取的两种排序**，不发第二个请求，也都不是 LOOP 发布的榜单；新币是
  new-pairs 读取，第一次点开这个 Tab 才发请求（`market.newPairs.resolves == 0`
  在 self 选 Tab 上是被测的）。切 Tab 只换列出的块，不重建页面、不重发已持有的读取。
- 一行统计条：`自选 N · 涨 X · 跌 Y · 持平 Z | N 秒前更新`。
- 可排序列头：`名称 / 成交额 · 最新价 · 24h 涨跌`，箭头指示方向；再按一次同一列
  反向。**涨幅榜固定按 24h 涨跌**，列头跟着它，不给一个会自相矛盾的控件。
- 连续表行，无卡片包裹：`logo 32 + symbol + 成交额副行 + 小折线 48×24 + 右对齐
  价格 + 涨跌实心块 70×30 圆角 6`，行高 58，分隔线 `LoopColors.line`。
  去掉 chevron —— 整块列表本身就是「可以点开」的意思。

行高 `marketRowHeight` 固定，两行文字都是 `maxLines: 1`：放不下的东西移出这一行，
不在行内换行。折线槽 `marketRowSparklineSize` **无论有没有折线都占位**，否则价值列
会逐行左右移动（走查里一半行有形状一半没有）。

设计稿的列宽 `1fr 96px 88px` + 8pt gap 在 390pt 上只给名称格留 60pt，
「成交额 $1.28B」被截成「成交额 $…」（本单第一版实测）。固定列按各自内容在梯子
步长下实际需要的宽度收窄（价格 84、涨跌 70、间距 6），差额给名称。

### 2 · 涨是 Lime，跌是 danger，持平是 muted

设计稿用 `#FF6B82`（= `LoopColors.danger`），需求方已批准。这是 LOOP 第一次让
「跌」用第二个色相：一屏八行价目表里，全 Lime / Chalk 的涨跌读不出方向。三个底色
都是不透明浅色，块内文字一律 Ink。

`loopFormatPercent` 给每个数字带符号，于是没有动的行读作「+0%」——涨了个零。
持平单独印 `0.00%`。读不到的行印「读不到」，绝不是 `0.00%`。

### 3 · 副标题说这一行为什么排在这里

`marketAssetSubtitle()`：

- 价格读到了 → 「成交额 $1.28B」（列头就是它的标签）；自选块不下发成交额，
  退回资产名，再退回截断身份。
- 只有当已批准规则**不是**开发基线时才追加「权重 1.5×」。开发基线下的 `1×` 与
  `开发基线` 字样一概不印：那是发布属性，属于「关于」。
- 价格没读到 → 整行让给服务端的完整原因句，此时价值列不印任何替代文字。

### 4 · 价格低于 1 美元时保三位有效数字

`loopFormatUsd` 取两位小数，把每个亚分资产印成 `$0`。在一个承诺「读不到会说明
原因、不会显示 0」的页面上，把**读到了**的数印成 0 更糟。`marketRowPrice()`
在 `< $1` 时走 `loopFormatCompactFigure(preciseBelowOne: true)`。

### 5 · 统计条只数读到的

没读到 24H 变化的行**不计入任何一边，也不被统计条宣布**。计数不是数值；被跳过的
那一行自己带着「读不到」块，读者想知道是哪一行时就在那一行。

设计稿的第四项写的是「稳定币 N」。这里印的是**持平 N**：LOOP 不下发任何锚定标记，
说某一行「是稳定币」是这一页自己的判断；「持平」是同一行按读到的数该说的话，
对 USDT（0.00%）给出的结果与设计稿一致。**如果后端愿意下发锚定标记，这是一个词的
改动。**

### 6 · 眉标用读者的语言

`market_widgets.dart` 集中持有：`行情概览` / `新币` / `高风险` / `持有人` /
`成交记录` / `聪明钱` / `价格提醒` / `自选管理`，以及 `未保存` / `编辑`。原型的
拉丁腔是设计稿的声音，不是产品的。

### 7 · 新币行：场馆有名字，只读只说一次

- `marketDexLabel()`：`four-meme → four.meme`、`pancakeswap_v2 → PancakeSwap V2`、
  `uniswap-v4-bsc → Uniswap V4`。表是开集，认不出的 slug 仍然印出来，按分隔符
  首字母大写（`my_new_dex → My New Dex`），不隐藏读者看不到的场馆。
- 两个否定合成一枚中性胶囊 `仅浏览`，只在既不能加自选也不能打开时出现。
- 行从三行压到两行。行本身 `marketNewPairRow()` 由 Tab 与同名页共用；星标只由
  拥有这次写入的那个页面传进来。

### 8 · 代币页按设计稿重建首屏

- 顶栏：`WBNB / USD` + 副行 `Wrapped BNB · 0xbb4c…095c`（计价币是读数的一部分）。
- 大字价（`figureXl`）+ 涨跌块 + `≈ +2.01 · 24h`。最后一项由同一行上的两个数字
  推出，任一没读到就整项省略。
- 四格：24H 成交额 / 流动性 / 市值 / 持有人（`figure` + `caption`）。
- 买入 / 卖出在首屏，由**同一个** `capability.swappable` 关着；理由只在页脚那张卡
  说一次。
- 「行情事实」卡只留四格**没有格子**的一项（完全稀释估值）；四格的出处与时间由卡下
  一行落款统一交代。页面上没有任何数字被印两遍。
- 「挖矿权重」只在「挖矿数据」区出现一次（那一处同时是进入 `/mining` 的入口），
  不带 `开发基线` 字样，`Mining Weight` 改中文。
- Token Card（`LoopTokenCard`）不再出现在这一页。它仍然服务于社区详情与聊天里的
  代币卡片，那两处不动。

### 9 · logo：契约、白名单、每行每屏一次

`LoopTokenLogo` 的解析顺序是 **注册表远端图 → 内置的七个原型 token 图 →
monogram**，任一级失败落到下一级。

- `loopRemoteLogoUri()` 只接受带 host 的绝对 `https` 地址。
- **每行每屏只试一次**：组件改成 `StatefulWidget`，失败由这个 element 记住，
  滚动、下拉刷新与重建都不会再问 CDN 要同一个 404。地址变了才重新试一次。
- 成功的图由 Flutter 自己的 `ImageCache` 按地址去重，所以同一个 symbol 在自选和
  热门各出现一次只解一次码。**没有磁盘缓存** —— 那需要新依赖。
- monogram 永远过一遍 `loopMonogram()`：此前调用方把整串 `pair.name` /
  `row.displayName` 塞进圆里，于是出现「OH /」与四字母溢出。

### 10 · 全部 codec 接住必填 `logo`

`LoopV2ChainCodec.logoUrl()` 是唯一的解码口：校验 `status` 两个变体的字段互斥、
`source` 只在 `dexscreener` / `trustwallet` 两者之内、URL ≤512 字符、scheme 必须
`https`、无凭据、无端口、主机严格等于契约白名单三者之一。**客户端不放宽**：其它
主机一律当作无效载荷，而不是"加载看看"。`unavailable` 返回 `null`，直接画 monogram。

已接住必填键的位置：`market/overview` 的 `watchlist.items[]` 与 `trending.items[]`、
`market/assets/{id}` 顶层、`market/new-pairs` items[]、`wallets/{id}/balances` 的
`balances[]` 与 `launchChain.nativeBalance`、`watchlist` 的 `groups[].items[]`、
`mining/assets` 的 `included[]`/`excluded[]`、`search` 的 `displaySnapshot.logo`。

其中 **market 与 watchlist 同时投影到模型并画出来**（`MarketAssetRow.logoUrl`、
`MarketAssetDetail.logoUrl`、`MarketNewPair.logoUrl`、`WatchlistItem.logoUrl`）。
wallet / mining / search 三处**只校验后丢弃**：它们的模型在本单不属于我的可写范围，
给一个没有页面会画的字段是让模型撒谎。这三处的 UI 接线是后续一单。

### 11 · 改了 `check_harness.py` 一行

`S5_SWAP_CARD_GATE` 原本锁的是 Token Card 的 `tradable: detail?.capability.swappable ?? false,`。
Token Card 不在这一页了，买入/卖出改由 `MarketTradeActions` 承载，同名同旗标。
**不变式没有变** —— 这一对按钮在且只在一处被关，入口按钮在且只在另一处被关，两处
都直接读 `capability.swappable` —— 只是接住它的组件换了。常量相应改成
`tradable: detail.capability.swappable,`，并在旁边写了为什么。

## Consequences

- **代价：市值与流动性的精确值在代币页上没有了。** 它们此前只出现在与四格重复的
  那张卡里。判断用的是量级（`$9.9M`）；持有人的精确值仍在「持有人分布」页与入口行
  的副标题上。
- **代价：V4 池不再单独说「暂不支持详情」。** 该行没有 tap 也没有 chevron，读者从
  形状上已经知道它打不开；`仅浏览` 胶囊在它同时不能加自选时补上一句。
- **代价：代币页不再画小折线。** 一屏里两张同一段数据的图，小的那张只能说大的
  那张已经说过的话。K 线是这一页的图。
- **必须和 Dev 栈部署同步。** 契约加 `logo` 而客户端未接 → `strictMap` 会拒绝整个
  载荷。现在客户端已接住，所以顺序是：**先合这一单，再部署 Dev 栈**。反过来会让
  行情、钱包、自选、挖矿、搜索同时读不到。

### 设计稿里没有落地的部分（需主代理裁决）

1. **代币页底部固定的买入/卖出条。** `LoopDashboardPage` 没有 bottom-bar 槽位，
   加一个要改 `lib/widgets/loop_pages.dart`，不在本单范围。现在两个按钮在首屏
   四格下方，随页面滚动。
2. **代币页的 `24h 高 / 24h 低` 两格。** 契约不下发这两个事实。从 1H K 线里取
   最大/最小是这一页自己算的数，本单没有算；四格换成了 LOOP 确实持有的四项
   （24H 成交额 / 流动性 / 市值 / 持有人）。
3. **代币页的周期 Tab + MA 读数行、K 线 236 高含成交量、社区/持有人/成交/简介
   四个 Tab。** 现有 K 线区已有周期选择与 MA/VOL 开关（全屏页），把它重排成设计稿
   那一行、并把下半页改成 Tab，是一次独立的重排，本单没做。
4. **统计条第四项是「持平」不是「稳定币」。** 见 §5。
5. **`figure 15`。** 设计稿的价格是 15/600 等宽数字，band 7 的梯子里没有 15 这一步。
   现在用 band 3 的 `title` 打开 `tabularFigures` —— 同字面、同字号、同字重、列对齐，
   且没有手写任何 `fontSize`/`fontWeight`/`fontFamily`。梯子若补上 `figure 15`，
   `marketRowPriceStyle` 换成那个名字即可。
6. **磁盘图片缓存。** 需要新依赖，属依赖决策。

## Evidence

- 门禁：`dart format`、`flutter analyze`、`flutter test`、
  `python3 scripts/check_harness.py`、`python3 -m unittest`、
  `flutter build apk --debug`。
- `test/s78b_market_density_test.dart`：行高一致（有折线/无折线）、折线槽恒定、
  价格右缘对齐且不与涨跌块重叠、块定宽、亚分价格不印 `$0`、涨跌读不到不印
  `0.00%`、价格读不到只说一遍、monogram 两位、`https` 白名单与三级回落、
  统计条只数读到的、页面无 hero 与内部标签、空自选仍有入口、热门读不到整段说明、
  slug 映射、新币行只有一枚 `仅浏览`、列排序（含读不到的行沉底）与反向、
  logo codec 的可用/不可用/八种无效载荷。
- `test/s59_market_fidelity_test.dart`：列表页无 hero、四个 Tab 切换不重建页面、
  代币页无卡无 hero、买入卖出关着且理由只说一次、挖矿权重只出现一次。
- `test/s5_market_pages_test.dart`：新币 Tab 首次打开才发读取、热门 Tab 才印排序规则、
  四格摘要且全页不重复印数。
