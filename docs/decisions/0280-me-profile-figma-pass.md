# 0280 · 「我的」与他人主页按需求方 Figma 钱包稿对齐

## Status

Accepted · 2026-11-04（S353c-mobile）。来源：用户 11-04 裁决「色、字体、字号、字重、行高、间距、圆角、组件形态一律按稿，结构不回退」；规格 `docs/58` §5.10–§5.13、§5.19、§5.20、§9.4；稿 `5-wallet-empty-2001-490`、`9-wallet-list-2001-1761`。底座 0277（S352），英文默认 0281。docs/56 §四 10 条与 §五 0276 结构保留：身份卡 → 总资产 → 五快捷键 → 持仓 / 交易 / 社区 → 代币 / NFT + 产生算力。

## Context

稿 vs 现状（TF 64 + S352 / S355 合入后，622e67ca）：

1. 总资产包在 `LoopChromePlate`（`wallet_read_screens.dart` `_totalPlate`）里，金额黄色 40 + 「USD」单位，牌面右侧「IN THE LOOP ALWAYS」字样；稿：无牌，金额白 40 / 700 / 46，无单位（§5.10）。
2. 「总资产」12 / 300 + 眼睛 16；¥ 行与地址 12 / 300 auxiliary，地址复制 12；今日盈亏单独一行（分割线 + 「净值走势 ⌄」字样）；稿：14 / 400 次字 + 眼睛 19、「≈ ¥ | 今日盈亏」一行、地址 14 / 400 + 复制 16、右侧 124 × 86 黄色走势线可点展开（§5.10）。
3. 五快捷键是 56 方块（card2 底、r8）+ 16 / 600 字，360 宽「Receive」截成「Rece…」；稿：无底色，图标 24 + 14 / 500，键间 1 × 28 `#24262c` 竖线（§5.11）。
4. 「产生算力」是 `LoopBadge` 灰底徽章；稿：12 / 500 次字 + ⓘ 16（§5.3）。
5. 持仓行 `WalletBalanceRow`：头像 40、上下 14、最小高 80、数量 16 / 600、估值 14 / 600；稿：51 高（上下 6）、头像 36、名 14 / 500、副行 12 / 300、数量 14 / 600、估值 12 / 300、无线（§5.13）。他人主页 `LoopQuoteRow` 80 高、价值 16 / 600。
6. 「管理」是描边胶囊（`line2` 边、14 / 600 次字）；稿 §5.20 深色次按钮：白 8 %、r8、黄字 13 / 600。
7. 空态皇冠在块内是 72；稿 §5.19 皇冠 106 × 64。
8. 英文溢出（S355 报）：他人主页计数行「1,284 Foll…」「2 Communi…」、四键「Direct mes…」；我的身份卡「Joined Oct 2…」；资产页标题「Wallet asset · WBNB」折两行；自选分组标题「… · Drag to sort · Swipe left to delete」截断；工单描述占位截断。

## Decision

- **总资产**（`WalletTotalHeader`）：去掉 chrome 牌，直接落在页面上（保留 `wallet-total-plate` key）；「总资产」`body2Sm` 次字 + 稿眼睛 19（距字 8，触控仍 44）；金额 `plateFigure` 白、无「USD」、长数字 `FittedBox` 缩放不截断；右侧 `WalletNetWorthTrend` 124 × 86 = 服务器存的一周净值（黄线 2.2 + 黄色 28 %→0 渐隐 + 末点），点它与点今日盈亏行同为展开 / 收起（0259 折叠不变）；**没有历史就不画**，不放装饰图。「≈ ¥ | 今日盈亏 值 ⌄」一行（`body2Sm` 次字，分隔改 1 × 12 `dividerSolid` 竖线——稿的 `#1a1b20`「|」字在底色上对比 1.17，地面探针判为不可见），放不下时 ¥ 金额单独一行、今日盈亏不截断；「净值走势 / 收起」只作读屏标签，不再画字。地址 `body2Sm` 次字 + 稿复制 16，「管理」紧随其后。
- **快捷键**（`WalletQuickActions`）：稿 SVG 图标 24（接收 / 发送 / 兑换 / 扫码 / 链接）+ `label` 14 / 500 主字，关闭的键三级字；等宽列，键间 1 × 28 `dividerSolid`；字放不下换第二行，不出省略号（顶对齐，换行的键图标不下移，竖线与图标平齐）。上方 18。
- **产生算力**（`WalletPowerTag`）：`meta` 12 / 500 次字 + 稿 ⓘ 16，无徽章底。**注**：0255（UX-009）曾去掉 ⓘ，本批按稿与任务书恢复，见「要拍板」。
- **持仓行**：`WalletBalanceRow` 顶部 51 高（上下 6）、头像 36、`body1` 名 + `caption` 次字副行、`figureSm` 主字数量 + `caption` 次字估值；无分割线。行下「发送 / 兑换」两键（0188）保留在 51 之下。他人主页 `LoopQuoteRow` 传 `height: 51`、`valueStyle: figureSm`、副值 `caption` 次字。
- **管理**（`WalletManagePill`）：白 8 % 底、r8、28 高、稿钱包图标 14 + `buttonSm` 13 / 600 黄。
- **空态**：钱包「代币 / NFT」三处与他人主页六处空态用 106 皇冠（`LoopEmptyArt(width: LoopEmptyState.illustrationSize)`），仍无说明句（0248）。
- **他人主页同构**：四键用 `LoopRoundKey(bare: true)` + `LoopRoundKeyRow(ruled: true)`，与「我的」快捷键同形（无底、24 + 14 / 500、竖线）；计数行改 `Wrap`，放不下换行不截断。
- **行高 token**：`LoopRowHeight`（`loop_theme.dart` 新增，纯追加）：token 71 / chat 67 / community 86 / management 56 / holdings 51 / rank 51 / holdingsAvatar 36；分隔线规则写在类注释（§9.4：代币、会话、社区、帖子、功能行画 1px 白 5 %；持仓、榜单不画）。本批只用 holdings；其余给 S353a / b。
- **英文溢出**：身份卡「关注 / 粉丝」与「Joined …」改 `Wrap`（放不下时 Joined 落到下一行）；资产页标题 en 改为 `{asset}`（卡片 kicker 已写 Wallet asset）；自选分组标题只留「{name} {items}」，「Drag to sort · Swipe left to delete」移到标题下一行 caption（新键 `marketWatchlist_editorWatchlistGroupHint`，zh「拖动排序 · 左滑删除」）；工单描述占位 `hintMaxLines: 2`。
- **兑换报价卡**（`swap_screens.dart` `_QuoteFacts`）：`platformFeeBps == null` 时不画「Platform fee」行；有平台费照常画 `N bps`（key `swap-quote-platform-fee`）。路线页 `swap-route-fees` 的「LOOP service fee · Not set」不在本批范围，未动。

## Consequences

- 共享件只加可选参数：`LoopRoundKey.bare`、`LoopRoundKeyRow.ruled`、`LoopQuoteRow.valueStyle`；`loop_theme.dart` 只追加 `LoopRowHeight`。新增 `lib/features/wallet/wallet_figma_glyph.dart`（`assets/figma/wallet-*.svg` 着色）。
- View model / gateway / codec / 路由 / 兑换流程未动；lockfile 未变。
- 测试：旧断言改到稿值（金额白、无单位、无牌、快捷键无底、产生算力无徽章、行高 51、报价卡无平台费行等），新增 `test/s353c_figma_me_test.dart` 与 `test/s353c_shots_test.dart`（`LOOP_SHOTS=true` 才出图）。
