# 0190 · 钱包 / MEME / 情报 / 代币 / 发射台的列表与交易面板落到字体阶梯（S197-2-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` e0f24ff（0189 之上，已含 S197-3 / 0191 与 S197-4 / 0192）。来源：主仓库 `docs/37-全App字体一致性走查-2026-10-15.md` §1 角色表、§2 偏离清单、
`docs/decisions/0189-type-ladder-final.md`（阶梯定稿与 G1 / G2 守卫）。
范围：`lib/features/{wallet,meme,market,intel,chain,launch2}/**`（不含 `launch2/creator/**` 与 `launch2_signing.dart`），以及随之更新的测试与
`scripts/check_harness.py` 两张白名单。不新增依赖、路由、字体、资产；`pubspec.lock` 不变；`lib/widgets/**` 与 `test/type_roles_test.dart` 未动。

## Context

0189 定稿阶梯并把共享部件落档后，本批六个 feature 目录仍有 58 处数字 builder、19 处弃用别名与 1 处低于 11px 的字号；docs/37 列出的 H3–H7、M13–M31、L10–L24 里，
MEME 列表与行情列表、钱包 C 行与失败行、四种交易记录行、发射台两种行各用一套尺寸。本批把这些页面逐条落到 0189 的唯一档位。

## Decision

逐条（行号为本次提交后的位置；「前 → 后」写字号 / 字重）。

### 高

| ID | 文件:行 | 前 | 后 |
|---|---|---|---|
| H3 | `meme/meme_home_top.dart:294` 总资产 | `figureXl`@700 整数 + `figureLg` 20 text3 小数 | `figureXl` 28/600 整串，不拆小数（与钱包 Tab、我的同） |
| H4 | `meme/meme_widgets.dart:377` / `:409` / `:432` / `:445` / `:561` 代币行 | 15/600 · 12 text2 · 13/700 · 11/700（h1） · 11/600 | QuoteRow 同一套：`titleLg` 16 · `bodySm` 13 · `figureMd` 17/600 · 涨跌 `figureSm`@600 · 进度 `figureSm`@600（后两者 `height: 1`，保住 44 tile 定行高） |
| H5 | `wallet/wallet_home_widgets.dart:857`（`WalletAssetLine.recordRow`） | 失败行 ticker 一律 `title` 15 | 失败行跟随所在列表：QuoteRow 列表（我的页）`titleLg` 16，钱包 C 列表（`WalletBalanceRow` 传 `recordRow: true`）`title` 15 |
| H5 / H7 | `wallet/wallet_home_widgets.dart:1350` 起 `WalletBalanceRow`（钱包 C） | ticker 14/700 · 副 11 · 数额 14/700 · 估值 11/600 · 24h 11/600 | R4 `title` 15 · R5 `caption` 12 · R6 `figure` 13/600 · R7 `figureXs` 11（24h `figureXs`@600） |
| H7 | `wallet/wallet_read_widgets.dart` `walletActivityRow`（tx-history） | 已是 `LoopRecordRow` 默认（0189 S2） | 不变；骨架屏 `WalletActivitySkeleton` 由 16/13/16/11 改为 15/12/13/11 与行同档 |
| H7 | `market/token_screen.dart:891` / `:904` 代币成交行 | 时间 `captionSm` 11 text3 · 右侧数量 `figureSm` 12 | R5 `caption` 12 text2 · R6 `figure` 13/600 text2（方向词 `title` 15、左侧成交额 `figure` 13/600 不变） |
| H7 | `meme/meme_token_screen.dart:1657` MEME 成交行 | 名字 `body` 14 · 时间 `captionSm` 11 · 金额 `figureSm` 12 · 数量 `captionSm` 11 | R4 `title` 15 · R5 `caption` 12 text2 · R6 `figure` 13/600 · R7 `figureXs` 11 text3 |

H7 的目标（交易记录行）= R4 `title` 15/600 · R5 `caption` 12 text2 · R6 `figure` 13/600 · R7 `figureXs` 11，即 `LoopRecordRow` 默认值。
`social/public_profile/user_profile_screen.dart:875`（他人主页交易，现为 `LoopQuoteRow` 16/13/17/12）属于 S197-3，**本批未改**，S197-3 应对齐到上述四档（宜直接换 `LoopRecordRow`）。

### 中

| ID | 文件:行 | 前 | 后 |
|---|---|---|---|
| M13 | `meme/meme_token_screen.dart:1719` 分享弹层 | 已有 `LoopSheetHeading('分享代币')`，其下代币名 `titleLg` 16 | 代币名降为 R19 `bodySm` 13 text2（弹层只剩一个 R2 标题） |
| M14 | `wallet/wallet_home_widgets.dart:483` / `:801` 「关于总资产」「持仓产生算力」 | `headingSm` 17 | `LoopSheetHeading`（R2 20/600） |
| M21 | `wallet_home_widgets.dart:971`、`launch2/launch2_wallet_rows.dart:188` QuoteRow 副值 | 调用方传 `figure(14)` / `body(14)` | 不传 style，由 `LoopQuoteRow` 的 `figureSm` 12 定 |
| M22 | `launch2/launch2_widgets.dart:330` 起 `Launch2InstanceTile` | 倒计时 / 价格 / 状态 `body(14)`，开售前大数 `figure(18,700)` | 数字 `figureSm` 12、文字 R5 `caption` 12 text2、开售前大数 `figureMd` 17/600；`Launch2Countdown` 默认 `figure(14)` → `LoopType.figure`；阶段胶囊 `title(14)` → `titleSm`@600 |
| M23 | `launch2/launch2_launchpad.dart:626` 起台账卡 | ticker `title(14)` · 数 `figure(16,700)` · 副 / 脚 `caption(11)` | R4 `title` 15 · R6 `figure` 13/600 lime · R5 `caption` 12 text2；数下小字 `captionSm` 11 text3 |
| M24 | `market/market_widgets.dart:332` `MarketTabBar` | `title` 15 | R16 quiet 档 `action` 14，选中 700 / 未选 600 text3（下划线样式不动） |
| M25 | `market/market_widgets.dart:713` `MarketQuoteCells` | 标签 `captionSm` · 值 `figure` | `LoopStatGrid` 的档：标签 R13 `kicker` 11/500、值 R12 `figure` 13/600（未换部件，见保留项） |
| M26 | `market/token_screen.dart:793` | 24h 涨跌 `figureSm`/400 | `figureSm`@600，与 `meme_token_screen.dart` 同 |
| M27 | `meme/meme_widgets.dart:395` 行龄 | `figure(10)` | `figureXs`@600 11（G2 白名单清零）；进度环内数字 `figure(11/10,700)` → `figureXs`@700 |
| M28 | `wallet/wallet_read_widgets.dart` 资产明细行 | 已是 `LoopRecordRow` 默认（0189 S2） | 不变（钱包 Tab 行见 H5） |
| M29 | `wallet/wallet_read_widgets.dart:297` 日期分组头 | 手写 `caption(13)` text2 | `LoopLabel(followsLabel: true)`（交易记录是平铺页，按部件画 R3b） |
| M30 | `wallet/wallet_read_screens.dart:1418` / `:1528`、`wallet_read_widgets.dart:388` / `:430` 来源行 | `LoopType.label` 12/500 | R21 `captionSm` 11 text3 |
| M31 | `chain/chain_widgets.dart:725` / `:760` | `labelMedium` 12/500 | R21 `captionSm` 11 text3；同文件 `LoopProvenanceFooter` `LoopMono.stamp` → `captionSm` text3 |

### 低

| ID | 文件:行 | 前 | 后 |
|---|---|---|---|
| L10 | `wallet/swap_screens.dart:700` | 「报价中…」走 `LoopMono.headline` | 有报价 `figureLg` 20、无报价 R20 `caption` 12 text3；另两处 `LoopMono.label` → `eyebrow` |
| L20 | `intel/intel_rank_board.dart:994` 算力榜行 | 名字 `body`@600 14 · 副 `captionSm` 11 · 数 `figure`@700 | R4 `title` 15 · R5 `caption` 12 text2 · R6 `figure` 13/600（0182 布局不动）；榜头两处 `LoopMono.label` → `eyebrow` |
| L21 | `launch2/launch2_pool_trade_panel.dart:709`、`launch2/launch2_trade_panel.dart:616`（MAX）、`market/watchlist/watchlist_editor_screen.dart:689`（删除） | `label(13,700)` | R17 `label`@600 12 |
| L22 | `launch2/launch2_launchpad.dart:808` 「收起 / 全部」 | `LoopMono.label` | R17 `label`@600 |
| L23 | `meme/meme_launchpad.dart:324`、`launch2/launch2_instance_screen.dart:1136`、`launch2/launch2_dynamic_pool_widgets.dart:116`、`launch2/launch2_widgets.dart:592`、`launch2/launch2_pool_trade_panel.dart:819` | `caption` 12/400 | R17 `label`@600 12 |
| L24 | `launch2/launch2_pool_trade_panel.dart:483`、`meme/meme_trade_panel.dart:367` 持有 / 可用 | 12 text2 / 11 text3 | 两处 R20 `caption` 12 text3 |

### 顺带落档（本批文件里其余的数字 builder / 别名）

- `meme_home_top.dart` 最佳交易卡：名字 `label(12,700)` → `label`@700；收益 `figure(15,700,h1)` → `figureMd` 17/600 lime（`FittedBox` 内）。
- `wallet_home_widgets.dart`：总额旁 `USD` `figure(14)` → `figure` 13；四键文字 `title(13)` → `titleSm`@600；「显示 N 项零余额」`body(14)` → `body`。
- `wallet_read_widgets.dart`：托盘 `caption(12)` → `caption`；净值卡 `LoopMono.label / display` → `eyebrow` / `figureXl`。
- `wallet_read_screens.dart`：收款地址 `LoopMono.address` → `code`；交易哈希 `LoopMono.body` → `code` text2；浏览器链接 `label` → `codeSm` text2。
- `approval_screens.dart`、`money_actions_widgets.dart`：`LoopMono.label` → `eyebrow`，`LoopMono.display` → `figureXl`。
- `send_screens.dart`：收款地址下两行注释 `label(11)` → R20 `caption` 12。
- `market/token_screen.dart` 安全格 `caption(12)` ×2 → `caption`；`market/token_card_chart.dart` `caption(11)` → `captionSm`；`watchlist_editor_screen.dart` `LoopMono.label` → `eyebrow`。
- `chain_widgets.dart` 事实块：`LoopMono.label / headline / value` → `eyebrow` / `figureLg` / `figure`。
- `launch2_launchpad.dart`：活动卡 CTA `eyebrow(11)` → R17 `label`@600 lime；实时动态 `figure(11)` ×3 → `figureXs`（时间 / 金额 @600）。
- `launch2_instance_screen.dart`：进度卡标签 `caption(11)` → `captionSm`；数 `figure(13)` → `figure`；条下说明 `caption(11)` → R20 `caption` 12。
- `launch2_nft_screen.dart`：简介 `caption(12)` → `caption`；勋章环字 `figure(11,600)` → `figureXs`@600。`launch2_trade_panel.dart` 额度 `figure(13)` → `figure`。

### 保留项

- **M25 未换 `LoopStatGrid` 部件**：代币页报价下是 4 格一行的条（两条共 8 格），`LoopStatGrid` 是两列带框格子，换部件会把条改成 4 行卡片，属于布局改动；本批只把字号 / 字重对齐到 `LoopStatGrid` 的 R12 / R13。若要换部件，需主代理在真机看过后另定。
- **H4 未直接换 `LoopQuoteRow`**：MEME 行带 0173「列表 A」的 44 r15 tile、行龄 / 已毕业标、右侧进度条与分隔线，且十余个测试按其 key 定位；`LoopQuoteRow` 没有这些槽位（共享部件不在本批可改范围）。改为同一套档位：16 / 13 / 17 / 12。
- `meme/meme_widgets.dart:94` Logo 字母 `figure(size / 3.2)` 按头像尺寸缩放，0189 已定不属于阶梯角色，保留（G1 不计）。
- `launch2_signing.dart` 与 `launch2/creator/**` 不属本批（其白名单条目已由 S197-4 / 0192 清掉）。
- 共享部件缺口：无。

### 白名单变化（`scripts/check_harness.py`）

`TYPE_LADDER_FEATURE_ALLOWLIST`（数字 builder, 别名），本批 21 个文件全部清零并删除条目：

| 文件 | 前 | 后 |
|---|---|---|
| `chain/chain_widgets.dart` | (0, 5) | 删除 |
| `intel/intel_rank_board.dart` | (0, 2) | 删除 |
| `launch2/launch2_instance_screen.dart` | (6, 0) | 删除 |
| `launch2/launch2_launchpad.dart` | (9, 1) | 删除 |
| `launch2/launch2_nft_screen.dart` | (2, 0) | 删除 |
| `launch2/launch2_pool_trade_panel.dart` | (1, 0) | 删除 |
| `launch2/launch2_trade_panel.dart` | (2, 0) | 删除 |
| `launch2/launch2_wallet_rows.dart` | (1, 0) | 删除 |
| `launch2/launch2_widgets.dart` | (11, 0) | 删除 |
| `market/token_card_chart.dart` | (1, 0) | 删除 |
| `market/token_screen.dart` | (2, 0) | 删除 |
| `market/watchlist/watchlist_editor_screen.dart` | (1, 1) | 删除 |
| `meme/meme_home_top.dart` | (2, 0) | 删除 |
| `meme/meme_widgets.dart` | (4, 0) | 删除 |
| `wallet/approval_screens.dart` | (0, 1) | 删除 |
| `wallet/money_actions_widgets.dart` | (0, 2) | 删除 |
| `wallet/send_screens.dart` | (2, 0) | 删除 |
| `wallet/swap_screens.dart` | (0, 3) | 删除 |
| `wallet/wallet_home_widgets.dart` | (8, 0) | 删除 |
| `wallet/wallet_read_screens.dart` | (0, 2) | 删除 |
| `wallet/wallet_read_widgets.dart` | (6, 2) | 删除 |
| **合计** | **58 builder + 19 别名** | **0** |

`TYPE_FLOOR_FEATURE_ALLOWLIST`：`meme/meme_widgets.dart` 1 → 删除。rebase 到 e0f24ff 后这是最后一条：两张白名单现在都是空字典 `{}`，G2 固定总数（`tests/test_check_harness.py`）1 → 0。

## Consequences

- 可见变化（待主代理真机验收）：MEME Tab 代币行与情报·行情同一套（ticker 15 → 16、价格 / 市值 13 粗 → 17）；MEME 首页总资产不再加粗、小数不再变灰变小；钱包 C 资产行 14 粗 → 15 / 13 常规粗细，副行 11 → 12；
  钱包两个说明弹层标题 17 → 20；代币页与 MEME 代币页成交行同为 15 / 12 / 13 / 11；行情子 Tab 15 → 14；代币页统计条标签 11/400 → 11/500；发射台列表与台账卡数字变小（18 / 16 粗 → 17 / 13）；
  算力榜名字 14 → 15、数字 700 → 600；行内文字动作（MAX / 删除 / 全部 / 铸造页 / 我的奖励…）统一 12/600；交易记录日期头改为平铺段标题。
- 0182 / 0188 / 0173 各加「0190 修订」注脚。
- 测试改档：`test/s187_meme_home_top_test.dart`（总资产改断言 `Text.style` 28/600）、`test/s121b_visual_second_pass_test.dart`（MEME 行市值 17/600、进度 12）、`test/s121c_visual_followups_test.dart`（钱包 C 行 15/600 · 13/600）、
  `tests/test_check_harness.py`（G2 总数 1 → 0）。新增 `test/s197_2_type_test.dart`（8 例：H4 / M27、H5 / H7 / M21 两种列表、M24、M25、M29、M31）。
- 门禁：`bin/dart format --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、`python3 -m unittest discover -s tests -p 'test_*.py'`、全量 `bin/flutter test`（结果见提交说明）。未起模拟器、未做真机验收。
