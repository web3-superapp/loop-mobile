# 0171 · 行情与钱包细节回到同一部件家族（S186-6-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 7bf8d81（已含 S186-1 / 2 / 3）。只换视觉语汇：路由（数量不变）、状态合同、请求路径、
controller、签名出口、发送 / 兑换闸门与自选 CAS 写入不变。不新增依赖、不新增字体与颜色 token。
来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §2 条目 M11、M15、L3–L7、L13–L15、L17、L18。
用户裁决：M15 钱包四键只留「兑换」满 lime；L16 收支方向的 rise / fall 保留不改。

## Context

docs/33 §1 家族特征五条要求：分组只用 `LoopLabel` + 行容器、胶囊只有 `LoopSegBar` / `LoopSeg(quiet)` / `LoopBadge` / `LoopProgressBar`
三种、颜色只走 ink / lime / chalk 档（`warning / danger / chat / market / elevated` 是 v1 遗留）、字号走 `LoopType`、圆角走 `LoopRadius`、
同屏一个满 lime。行情与钱包模块里还剩：自选编辑页手写的 record-card 外壳、把手方块、撤销 toast 与 fall 红左滑底；钱包四个满 lime 圆键；
代币页 tab 的 lime 下划线、K 线周期与图表开关的自造小胶囊、warning 黄风险点与均线；`MarketStatGrid`（`LoopStatGrid` 的单行复制）与
二级页残留的 `LoopUnavailableCard` / `LoopEmpty`；一组无引用的旧行情行；提醒页手写 limeSoft 方块；「产生算力」r999 描边胶囊；
收款页手写的二维码底板与地址胶囊；水龙头与发送页的 warning 黄；若干页直接读 `Theme.of(context).textTheme`。

## Decision

### 1. 自选编辑（M11，`watchlist_editor_screen.dart`）
- 列表外壳 = `LoopRecordCard(padding: zero)`（key `watchlist-record-card`），里面 `ClipRRect(LoopRadius.card)` 让左滑底色不越出圆角；
  行间分隔线 `LoopColors.line`。`LoopRecordCard` 新增可选 `padding`（缺省 15，像素不变）。
- 拖动把手 = `LoopRowIcon(icon: 'drag', size: 36)`（key `watchlist-drag-{assetId}`），仍包在 `ReorderableDragStartListener` 里。
- 撤销 = `LoopToast.show(action: LoopToastAction('撤销'), duration: 4 s, toastKey: watchlist-undo-toast)`；按钮 key 仍为 `watchlist-undo`。
  删掉自造的 `_WatchlistUndoToast` 与页面上的 `Stack`。暂存的移除仍由页面持有（4 s 计时器），撤销只在窗口内、页面仍挂载时生效。
- 左滑底色 card2 + chalk「删除」（key `watchlist-swipe-background`），不再用 fall 红：暂存移除不是行情涨跌（0117）。
- 「移除」InkWell 圆角 9 → `LoopRadius.inner`。

### 2. 共享 toast 的操作（`lib/widgets/loop_toast.dart`，可选扩展）
`LoopToast.show` 新增 `action`（`LoopToastAction{label, onPressed, key}`）与 `toastKey`。无 action 时外观、语义、`IgnorePointer` 与之前逐像素相同；
有 action 时只有这张 toast 接受触摸，右端是一个 ≥ 44 × 48 的 ink 文字按钮，点按 = 执行动作并收起（host 走淡出、overlay 直接移除），
文案部分仍是 live region。

### 3. 钱包（M15 / L14 / L15 / L17 / L18）
- 四键：`WalletQuickAction` 新增 `primary`（缺省 false）。只有「兑换」`primary: true` = 满 lime 圆盘 + ink 图标；接收 / 发送 / 扫码 =
  card2 圆盘 + chalk 图标；关闭的键仍是 `LoopGround.fillOf` 底 + 辅助灰（不论是否 primary）。圆盘加 key `wallet-quick-disc-{label}`。
  四键不是 `LoopRoundKey`（扫码用的是 Material 图标、高度 74），所以加的是这里的 `primary`，`LoopRoundKey` 不动。
- 「产生算力」：`LoopBadge('产生算力')`（mute）+ 13 号 info 图标，44 dp 点按区与 key `wallet-power-tag` 不变。
- 收款：一张 `LoopChalkCard`（key `receive-chalk-card`）里是二维码（208，居中）和整条地址（`LoopMono.address`，`inkText2`，可选择，居中）+
  ink 复制图标；行 key 仍为 `receive-address-capsule`。二维码编码失败时卡内是 `LoopInlineUnavailable`（随卡片底色取 ink 档），不再是块状 strip。
- 水龙头 `_line` 与发送页收款地址校验失败 = `LoopNotice(tone: warn, icon: warn)`；水龙头那几行外面保留 live region；key 不变（落在 notice 上）。
  发送页校验通过（lime）与校验中（text2）仍是原来那一行字。
- `Theme.of(context).textTheme.*` 全部换成主题本身映射的同一档：labelMedium → `LoopType.label`、bodySmall → `caption`、
  bodyMedium → `bodySm`、titleLarge → `titleLg`、titleMedium → `title`（像素不变）。涉及 approval / tx_result / send / swap /
  money_actions_widgets / wallet_read_screens / wallet_read_widgets，以及 docs/33 L18 点名的 `profile/security/security_screens.dart:529, 534` 两行。
- L16：`wallet_read_widgets.dart` 收支方向的 rise / fall 按用户裁决保留。

### 4. 行情（L3–L7 / L13）
- `MarketTabBar` 选中下划线 lime → chalk（0122）；`meme_token_screen` 同用此部件，一并变化。
- K 线周期 = `LoopSeg(quiet)`（key `token-interval-{wire}` 不变），一排放进横向滚动区，尾部控件位置不变，窄屏不溢出；
  K线 / MA / VOL 开关 = `LoopSeg(quiet, selected: on)`，外层保留 `toggled` 语义与中文读法（均线 / 成交量 / 切换到 K 线）。
- 风险点 warning → lime（原型 `--amber` = lime）；第一条均线 warning → lime 85 %，第二条仍 chalk 55 %。
- `MarketStatGrid` 删除，持有人页改 `LoopStatGrid`（`MarketStatCell.toStat()`）；持有人数卡 `LoopSurfaceCard` → `LoopRecordCard`。
- `market_secondary_screens.dart` 的 `LoopUnavailableCard` 全部 → 私有 `_MarketUnavailableLine` = `LoopInlineUnavailable('{label} · {服务端理由}', maxLines: 3)`；
  成交空、新池空、聪明钱动向 → `LoopEmptyState(compact)`（插图 history / search / rank）。`MarketNewPairsList`（情报 · 新币 tab）同样两处一并换。key 全部不变。
- 删除无引用的旧行情行：`MarketChangeBlock`、`MarketAssetTile`、`MarketAssetTileGroup`、`MarketRowSparkline`、`MarketRankAvatar` 与只为它们存在的
  `marketRowHeight / SparklineSize / PriceWidth / PriceMaxWidth / Change* / LogoSize / PriceStyle`、`marketAssetLogoUrl`、`marketAssetSubtitle`。
  `marketRowPrice`、`MarketMove`、`MarketStatCell` 仍有引用，保留。
- 提醒页触发记录图标 = `LoopRowIcon(icon: check, tone: accent, size: 36)`。
- 图表画布里的 1 / 1.25 / 3 / 4 px 圆角是绘图几何、不是表面圆角（`LoopRadius` 从 12 起，套上会把 2 px 蜡烛变成药丸），
  收为具名常量 `_ChartCorner.candle / axisTag / bubble` 与 `_candleCorner`，各写一次。

### 5. 范围说明
完成后 `lib/features/market/` 与 `lib/features/wallet/` 内没有 `LoopColors.warning / danger / chat / market / elevated`、
没有 `Theme.of(…).textTheme`、除上面四个具名图表圆角外没有 `Radius.circular(字面量)`（新测试逐行扫描守住）。
未在本批改动：`token_screen.dart` 的 `LoopEmpty` / `LoopUnavailableCard`（129、310、1046、1522）、`market_secondary_screens` 的无效资产整页 `LoopEmpty`、
钱包其余页面的 `LoopEmpty` / `LoopUnavailableCard` / `LoopStateCard`（docs/33 未列入本批）；`security_screens.dart:951` 的 textTheme（不在 L18 点名行，且 profile 不属本批目录）；
`MarketDirectionAvatar` 的 `size / 3` 圆角（非字面量）。

## Consequences

- 行情与钱包的细节页回到同一部件家族：行容器是 record-card、筛选是 quiet seg、状态是 badge / inline unavailable / empty state、警示是 `.notice-warn`。
- 钱包一级页同屏满 lime 只剩「兑换」；其余三键变成深灰圆盘，扫码与收发仍可点，闸门与理由 toast 不变。
- `LoopToast` 第一次带操作；以后其它「已暂存、可撤销」的场景用同一参数，不再自造 toast。
- 删掉约 700 行死代码及其测试；行情列表的唯一行部件是 `LoopQuoteRow`。

## Verification

- 新增 `test/s186_6_market_wallet_detail_test.dart`（8 例）：自选列表在 `LoopRecordCard` 内、把手是 neutral `LoopRowIcon`；左滑底 card2 + chalk 字、不是 fall；
  撤销是带一个「撤销」操作的共享 toast，点后恢复计数并消失；代币页选中 tab 下划线 chalk；周期与三个图表开关都是 quiet `LoopSeg`；
  持有人页 `LoopStatGrid` + 分布行 `LoopInlineUnavailable`；提醒触发记录是 accent `LoopRowIcon`；market / wallet 源码逐行扫描无 v1 色、无 textTheme、无裸圆角。
- `test/s114_wallet_okx_layout_test.dart`：新增「only 兑换 wears the Lime disc」（兑换 lime、其余 card2、图标 chalk）与「产生算力 is a mute badge with an info glyph」。
- `test/s16f_probe_test.dart`：钱包页浅色底前提改为打开兑换闸门后的那一个 lime 键；收款页改为断言二维码在 `LoopChalkCard` 内、探针采到 chalk 底。
- `test/s89a_token_tray_test.dart`：风险点 lime、中性点 text3。
- `test/s156_testnet_faucet_test.dart`：行文本改从 notice 内读取；冷却行断言 warn tone、无 warning 色。
- `test/s78b_market_density_test.dart` / `test/s81_edge_swipe_and_market_rows_test.dart`：删除针对已删旧行情行的密度 / 列宽 / 折线槽用例。
- 命令：`bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  `python3 -m unittest discover -s tests -p 'test_*.py'`，以及引用 market / wallet / security / toast / record card / meme 代币页的 95 个测试文件 + 新文件。
  未跑全量、未起模拟器、未做真机验收。
