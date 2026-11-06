# 0303 · 「我的」钱包卡 + 触摸动效、K 线周期胶囊 12 号不加粗、MEME 详情页头部（S379-mobile）

## Status

Accepted · 2026-11-06（S379-mobile，基于 integration/v2 f04f12dd = TF 69）。改写 0280（S353c）里「总资产去掉 chrome 牌，直接落在页面上」那一条；改写 0299（S375）里「周期胶囊字号不变（13 / 600）」那一条；改写 0240 / 0293 的 MEME 详情页头部排法。文件名沿用派单时的 slug（当时第 1 条方向是「去底」，之后改为「加卡」，见下）。

## Context

需求方 11-06 在 TF 69 上反馈：

1. 「我的」页钱包块要一张卡底。派单时最初理解成「TF 69 多出了一张底、要去掉」，随后主代理两次更正，最终方向是：**加一张卡**。排查结论供记录：6fbcb2e1..f04f12dd（S370a/b/c、S371、S372、S374、S375、S376、S377、S378）没有任何一批给钱包块加过底色；在 6fbcb2e1（TF 68）和 f04f12dd（TF 69）分别渲染「我的」页（含净值走势），两者都没有底。需求方截图里那张卡（卡内文字在 30 处，代码只有 20）不是任何已提交代码能画出来的，判断是需求方想要的样子（效果图），不是回归。
2. 资产详情页 K 线下方的时间周期胶囊（1m / 5m / 15m / 1h / 4h / 1D）字要小一点、不加粗；上面的 Candles / MA / VOL 不动。
3. MEME 详情页头部结构：顶栏只有返回和 ⓘ；代币名完整展示（可换行、不省略）；名字下一行「符号 | 合约地址 + 复制」靠左、阶段胶囊靠右；价格下是 24h 成交量；再下是 Candles / MA / VOL。
4. 用户追加：钱包卡要有触摸动效（跟手倾斜、流光、松手弹簧回正）。

## Decision

### 1 · 钱包卡

- `_totalPlate` 现在是一张卡：`walletTotalCardDecoration` = 底白 3%（`LoopColors.white3`）、圆角 `LoopRadius.card`（12）、1px `LoopColors.cardEdge` 描边（docs/58 §9 卡片规格）；内边距 16（`walletTotalCardInset`）；卡左右贴页边距 20。
- 卡内从「总资产 + 眼睛」到「接收 / 发送 / 兑换 / 扫码 / DApp」：`WalletTotalHeader` 去掉自己的 20 / 2 边距（新参数 `padding`，默认不变），快捷键行只保留上方 18（`WalletQuickActions.padding`，默认不变）。净值大图展开时也在卡内。
- 快捷键从 `sections` 搬进 `primary`，和总资产同一张卡；新鲜度条（`wallet-freshness`）移到卡上方。
- 间距：卡顶距「关注 / 粉丝」行 16；卡底到「持仓 / 交易 / 社区」页签 16（`LoopProfileSectionsBar.topGap`，默认仍 24，他人主页不变）。
- key 不变：`wallet-total-plate`（卡外层）、`wallet-folio`、`wallet-quick-actions` 及各键；新增 `wallet-total-card`、`wallet-total-card-inset` 作测试句柄。

### 钱包卡触摸动效

- 新公共件 `LoopTiltCard`（`lib/widgets/loop_tilt_card.dart`），本批只包钱包卡，卡内布局和 key 不变。
- 跟手 3D 倾斜：按下后按触点相对卡中心的偏移（各轴 −1…1），绕 X / Y 轴最多 ±6°，`Matrix4.identity()..setEntry(3, 2, 0.0012)` 透视，以卡中心为轴；按下的一侧下沉。手指移动实时跟随。
- 只用 `Listener`，不进手势竞技场：卡内眼睛 / 复制 / 管理 / 快捷键 / 展开都照常点击，外层列表照常滚动；纵向位移超过 `kTouchSlop` 即停止跟随并回正。
- 径向流光：以触点为中心一层 `RadialGradient`（白 12% → 0，半径 0.7 卡宽），`CustomPaint` 画、按卡圆角裁切、`IgnorePointer` 包住；无触摸且回正后不画。
- 松手：`AnimationController.unbounded().animateWith(SpringSimulation(SpringDescription(mass: 1, stiffness: 180, damping: 14), 1, 0, 0))`，倾斜和流光一起回 0；阻尼比约 0.52，反向过冲约 0.15 × 6° ≈ 0.9°（< 1°），流光强度夹在 0…1 不会反向。结束后精确置 0（单位阵）。
- `loopAmbientMotionProvider` 关或系统「减弱动态效果」开：直接画子树，不倾斜、不流光。
- 性能：`AnimatedBuilder` 只重建 `Transform` 和流光层，卡内容作为 `child` 不重建。

### 2 · 周期胶囊字号

- 新增 `LoopType.periodChip`（12 / 500，选中）与 `LoopType.periodChipIdle`（12 / 400，未选），都不加粗。
- `LoopChartPeriod` 用这两档；新增 `fill` 参数：`true`（默认，MEME 页填满一行）沿用原选中底与字色，`false`（行情代币页可滚动的一行）用 `chipActive` / `chipIdle` 底——`LoopChartIntervalRow` 的滚动分支从 `LoopSeg(compact)` 改为 `LoopChartPeriod(fill: false)`，外观除字号字重外不变。
- 胶囊内边距 2 / 4、44 触控不变。`LoopChartToggle`（Candles / MA / VOL）仍是 `LoopSeg` 的 13 / 600 · 13 / 500。
- 影响：行情代币页、全屏 K 线、MEME v2 项目页 K 线、MEME 曲线代币页（都经 `LoopChartIntervalRow`）。

### 3 · MEME 详情页头部（`Launch2InstanceHead`）

- 顶栏不变（返回 + ⓘ；页面标题只在顶栏收起态用，未改）。
- 头像 44 在左；右侧第一行是代币全名 `Launch2HeadName`：`LoopType.headline`（19 / 700）最多 3 行，超过 3 行降一档到 `headlineSm`（16 / 700），不设行数上限、不省略——一个字都不截。
- 第二行一行到底、不换行：「符号」（`body2Sm`，可交易阶段黄、其余 Text2，最宽 120）+ 1×12 竖线 + 合约地址（中间省略，`codeSm`）+ 复制键（44 触控），阶段胶囊在行尾、右缘贴内容区右缘。挤不下时地址先缩，胶囊不被挤走。
- key：`launch2-head-name`、`launch2-head-ticker`、`launch2-copy-address`、`launch2-stage-capsule`、`launch2-identity` 保留；新增 `launch2-head-address`、`launch2-head-rule`。
- 价格 / 24h 成交量 / Candles·MA·VOL 的顺序原本就符合，未改。

## Consequences

- 新增 `test/s379_me_wallet_flat_chip_font_test.dart`（18 例）：卡底存在、圆角 12、白 3%、1px cardEdge、内边距 16、左右 20、快捷键与总资产在卡内、上下各 16、展开大图在卡内；倾斜符号正确、流光出现、松手回单位阵且流光消失、反向过冲 < 1°、减弱动效无变换、卡内「管理」仍可点、纵向拖动仍滚动页面且回正；周期胶囊 12 号 / 字重 400 · 500（填满与滚动两种行、行情代币页），Candles / MA / VOL 仍 13；MEME 头部 390 / 360 下长名 ≤ 3 行不截断、超长名降档仍完整、符号 / 地址 / 复制 / 阶段同一行且阶段右缘贴内容区右缘。
- 改写的旧断言：`s375_chart_chips_compact_test`（行情页周期改为 `LoopChartPeriod(fill: false)`、字号 13 → 12，VOL 仍 13）、`s186_6_market_wallet_detail_test`（周期由 `LoopSeg` 改为 `LoopChartPeriod`）、`s182_launch2_desk_nft_test`（未亮起阶段的符号 Chalk → Text2，全名为 Chalk 标题）。s353c / s349 / s329 / s343 / s370a / s370c / s371 / s372 的断言无需改动、已复跑通过。
