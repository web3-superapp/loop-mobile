# 0188 · 钱包首页改为设计稿「钱包 C」：币安式总览 + 可展开净值图（S199-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 449ad64（含 0166 ~ 0187）。来源：主仓库
`docs/35-代币列表与代币页设计稿-2026-10-15/body4.html` 的「钱包 C · 收起」「钱包 C · 展开」两个手机框（HTML 结构即规格）。
后端契约由 S199-api 并行实现：`GET /v2/wallets/{walletId}/networth/history?range=1d|7d|30d|180d|360d`。
没有新能力位（沿用 `walletRead` 的整页闸门）；路由数不变；不新增依赖、字体与字形；`lib/features/square/` 未碰。

## Context

0119 / 0171 的钱包页顶部是「总资产 + 眼睛 + 24h 一行」，资产是 OKX 式无包裹行（Logo 36 · 数量 18 · 96×44 涨跌胶囊）。
设计稿 C 照币安资产页：总资产大数字带 `USD`、≈¥ 与地址一行、今日盈亏、右侧 7 天小折线；点开原地变成 200 高面积图；
四圆键之下是持仓分布条，余额行为「数量 / 估值 / 24 小时 / 两个小按钮」。小折线、大图与今日盈亏都要净值历史，
后端此前只有 `balances` 当前快照（0175 记过这个缺口）。

## Decision

### 1. 净值历史：端口、编解码与读取块
- 新端口 `WalletNetWorthHistoryGateway`（`wallet_read_gateway.dart`），默认 `UnavailableWalletNetWorthHistoryGateway`；
  `walletNetWorthHistoryGatewayProvider` 直接默认到它，只由 `lib/main.dart` 覆盖为 `loopV2WalletNetWorthHistoryGatewayProvider`
  （同一个已认证的 `DioLoopV2WalletReadGateway`，它同时实现两个端口；任一输入缺失仍是 Unavailable）。
  没有给 `WalletReadGateway` 加第六个方法：历史只是展示，服务端没部署时不应牵动任何余额读取，也不改动现有五个测试替身。
- `LoopV2WalletApi.getNetWorthHistory` → `…/networth/history`，`range` 走 query；`validateSuccess`（200 + `no-store`）
  与 `chainReadErrors` 照旧。`decodeNetWorthHistory` **宽松**：未知键忽略；坏点（时间或金额不可解析、负数）跳过，
  其余按时间升序；`current` / `change24h` / `high` / `low` / `fiat` 任一畸形即视为缺失；金额接受十进制字符串或 JSON 数字
  （数字只经其文本形式进 `Decimal`）。只有缺 `points` 或缺 `change24h` 键、`range` 与请求不符、正文不是对象时整份拒绝。
  404 / 503 / 缺键 → 读取块失败 → 不画小折线、大图与今日盈亏，页面其余部分不受影响。
- 模型 `LoopNetWorthRange`（1d / 7d / 30d / 180d / 360d，标签「1 天 … 360 天」）、`LoopNetWorthPoint`、`LoopNetWorthFiat`、
  `LoopNetWorthHistory`（`drawable` = 点数 ≥ 2）；`change24h` 复用 `LoopNetWorthChangeAvailable`。
- `WalletNetWorthHistoryController`（`LoopChainReadController`，无快照），family 键 `(walletId, range)`：
  切换区间各自读一次，回到读过的区间不重读；下拉刷新只重读已经被问过的区间。

### 2. 顶部块（`WalletTotalHeader`，改为 ConsumerStatefulWidget）
- 「总资产」+ 眼睛 + (i) + 环境标签不变；**眼睛改用 0175 的 `loopBalanceVisibilityProvider`**（与「我」同一个本机偏好），
  删除 0119 的进程内 `walletAmountsHiddenProvider`。隐藏时总额、¥、今日盈亏金额、图的高低点、每行数量 / 估值 / 24h 金额都画 `****`，
  百分比保留（0119 的口径）。AGENTS 23 与 implementation-constraints 各补一句「以及钱包页」。
- 大数字 `LoopType.figureXl`（28，最接近设计 34 的 figure 档）+ 小字 `USD`（figure 14，key `wallet-total-unit`）。
- 下一行（key `wallet-total-subline`）「≈ ¥913.27 · 0x1d27…86ed」+ copy 字形，整行点按经 `LoopCopy` 复制完整地址
  （key `wallet-address-copy`）。¥ 只在 `fiat.currency == CNY` 时画，`fiat` 缺失只剩地址。
- 原弱化说明行（未计入项数、过期、不可用理由）保留，地址移到上一行。
- 今日盈亏（key `wallet-pnl` / `wallet-pnl-value`）：读的是 **7 天历史**的 `change24h`，`+$12.08 (+10.4%)`，色只经
  `LoopPriceMove`（0117 rise / fall）；`change24h` 为 null 写「今日盈亏 暂无」；历史读不到整行不画。末尾 chevron，点按展开大图。
  旧的 `balances.netWorth.change24h` 那一行（`wallet-change24h*`）删除：按清单「404 / 503 → 不画盈亏」，不退回另一个来源。
- 右侧 88×44 小折线（`WalletNetWorthSpark`，`LoopSparkline` lime）：7 天历史点数 ≥ 2 才画，展开时隐藏（**0193 修订**：读到但点数 < 2 时画同尺寸占位「净值走势 · 记录中」+ 虚线，读取中画骨架，读失败仍不画）。

### 3. 原地展开（`WalletNetWorthPanel`）
- 下方 ⌄（`wallet-networth-expand`）或小折线、今日盈亏都可展开；⌃（`wallet-networth-collapse`）收起
  （**0193 修订**：⌄ / ⌃ 前加文字「净值走势」/「收起」，captionSm text2；占位同样可展开）。
  展开态 `walletNetWorthExpandedProvider`、区间 `walletNetWorthRangeProvider` 都是本次运行内记忆（非 autoDispose，不落盘）。
  历史端口 Unavailable（preview 组装、缺 session）时 ⌄ 也不画。
- 面积图 `WalletNetWorthChart`：200 高、lime 2 px 线 + `lime` 28% → 0 的纵向渐变（token 色的透明档），
  高低点标注 figure 11 / text2（key `wallet-networth-high` / `-low`，取自 points 本身，与线条位置一致）。
  Decimal → double 只发生在归一化到像素空间时。图下来源一行 `LoopProvenanceLine`「净值快照 · 来源 · 观察于」，
  `source` 不是已知 `LoopFactSource` 时写「LOOP 净值快照」而不是打印服务端标识符。
- 五个 `LoopSeg(quiet)` 区间胶囊（`wallet-networth-range-{wire}`），一行放不下时整行 scaleDown。
- 读取中 200 高骨架；读不到 `LoopInlineUnavailable`「净值走势暂时读不到」+ 重试（一行，不占满 200）；
  区间内点数 < 2 写「这个区间还没有净值记录」（**0193 修订**为「这个区间还没有净值记录 · 每小时记一次，有资产后开始画线」）。

### 4. 四个圆键、领取测试币卡
不变（0119 / 0171：只有兑换满 lime；`wallet-pay-entry` 等 key 不变）。

### 5. 持仓分布（`WalletHoldingsDistribution`，`LoopRecordCard`）
- `walletHoldingShares`：按每行自身 `valuation.valueUsd` 占比，降序；最多 3 段具名，第 4 个起合成「其它」。
  颜色依次 lime / chalk / card2 / line。一条 6 px 分段条（段间 2 px、`LoopRadius.pill`）+ 图例「BNB 84%」。
- 估值不全就不画整张卡：净值 partial / unavailable、任一余额读不到、任一非零持仓没有估值。零持仓不占段。

### 6. 余额（`WalletBalanceRow`）
- 标题 `LoopLabel('余额')`；现有页面没有列表排序，**不画排序图标**。「产生算力」标签（0171）保留在标题行右侧。
- 行：Logo 40 圆、名称 14/700 + 副标题（代币全名；原生行写「手续费保留 0.005」，来自 `gasReservePolicy`）+ 原有弱化标注
  （`wallet-balance-mark-*`）；右侧数量 figure 14/700、估值 `≈$x` figure 11 text2（无估值「暂无估值」）。
- 第二行「24 小时 +$249.13 (+5%)」（key `wallet-balance-change-*`）：只在 `change24hPct` 非 null 时画；金额 =
  估值 × pct / (100 + pct)（Decimal，即同等持仓下的现值 − 24h 前值）。
- 第三行两个 `LoopSeg(quiet)`：发送 → `/wallet/send`（`sendApprovals` 闸门）、兑换 → `/wallet/swap?from={assetId}`
  （`privySwap` 闸门，沿用 `_swapPrefill`）；闸门关闭时保持形状、点按 toast 服务端理由，与四圆键一致。
- 读不到的行仍是 `WalletAssetLine` 的一行弱化 + 重试，没有动作按钮；`WalletAssetLine` 本身不变（「我」的持仓仍用它）。
- MEME v2 内盘持仓（`Launch2WalletRows`，阶段 priority / public 的曲线持仓行）加「卖出 / 买入」两个 quiet seg，
  都进现有项目页 `Launch2Route.instance`（该页内切买卖）；已毕业的余额行与 NFT 行不加。
- 零余额折叠行、NFT 段、Launch 链段、来源行照旧。

## Consequences

- 首屏多出 ⌄ 与（有历史时）小折线和今日盈亏；后端没上线前这三样都不出现，页面其余与改前相同。
- 24h 信息的来源从 `balances.netWorth.change24h` 换成净值历史的 `change24h`，二者不再同时出现。
- 钱包与「我」共享一个隐藏余额开关，且这个开关在本机保存（0175 适配器）。
- 可见变化（均待主代理真机验收）：顶部版式、⌄ / 展开图、持仓分布卡、余额行变高（24 小时一行 + 两个小按钮）、
  资产标题从「资产」变「余额」、MEME 内盘行多两个按钮。

### 未按清单做的点
- 副标题「内盘 x%」：钱包里的 MEME 行来自 `me/positions`，该资源没有内盘进度字段，未画（仍写「v2 内盘持仓」/「钱包余额」）。
- 余额排序图标：现有页面没有排序，按清单不画。
- 大数字 34 / USD 14：取 `figureXl` 28 与 figure 14，未新增字号。
- 设计稿持仓分布卡右上的 ⌄：没有说明它折叠什么，未画。
- 估值保留了「≈」前缀（设计稿无）：它是按价格估出来的，与 0119 的写法一致。
- 买入 / 卖出不能直接预选方向：现有项目页路由只有 `id` 参数，两个按钮都打开项目页。

## Verification

- `bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  `python3 -m unittest discover -s tests -p 'test_*.py'`、钱包相关 35 个测试文件的 `bin/flutter test`（结果见提交说明）。
- 新增 `test/s199_wallet_home_c_test.dart`（22 例）：宽松解码（全量、缺键 / 区间不符拒绝、坏点跳过 / 坏块缺失 / 数字金额、
  null 盈亏与 fiat、请求路径与 query、503 失败）；顶部 USD / ¥ / 今日盈亏涨跌色 / 暂无 / 无 fiat；小折线 ≥ 2 点才画；
  展开 200 高 lime 图 + 高低点 + 五个 quiet 区间 + 收起 + 跨页面记忆；区间切换各读一次；隐藏余额打码；
  历史 503 不画线与盈亏、展开只一行、余额列表照常；无端口无 ⌄；持仓分布占比 / 记录卡 / 段宽比例 / 估值不全不画；
  行内发送 / 兑换路由（兑换带 `from`）、闸门关闭只 toast；无 24h 字段不画 24 小时行；读不到的行无按钮。
- `test/s136_launch2_user_test.dart` 新增内盘持仓的买入 / 卖出路由与已毕业不画；`s114` / `s5_wallet_pages` / `s121c` /
  `s26` / `s58` / `s156` 跟随版式更新（四圆键文字限定在键行内、24h 胶囊改为 24 小时行、「资产」→「余额」）。
- 未起模拟器、未做真机验收。

## 0190 修订

`WalletBalanceRow` 的字号回到账本行四档：ticker 14/700 → `title` 15/600，副行 11 → `caption` 12，数额 14/700 → `figure` 13/600，估值 11/600 → `figureXs` 11/400，24h 变动 `figureXs`@600；
读不到余额的行 ticker 与之同为 15。两个说明弹层标题改用 `LoopSheetHeading`（20/600）。

## 0193 修订

§2 右侧小折线位：点数 < 2 画占位 `WalletNetWorthSparkPlaceholder`（虚线 + 「净值走势 · 记录中」，可展开），读取中画同尺寸骨架，读失败仍不画；
§3 ⌄ / ⌃ 加「净值走势」/「收起」标签，空区间文案加「· 每小时记一次，有资产后开始画线」。详见 0193。
