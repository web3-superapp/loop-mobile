# 0301 · Figma 副本 11-05 改稿：代币 / 社区 / 持仓行主标题 14 → 16

## Status

Accepted · 2026-11-05（S377-mobile，基于 integration/v2 7383ea0d）。来源：需求方 11-05 傍晚在 Figma 副本（UsUft4rXagLP8qkKmPvKYw，Section 2001:20 九张手机稿）上改字号；主代理逐帧读取并与 `docs/58` §5 / §9.2 旧值比对，只有下表三处变了。规范记录在 `docs/58` §5.4 / §5.8 / §5.13 / §9.2 与新增 §9.6。

## Context

0277 把「行主标题」统一定为 `body1` 14 / 500 / 22（代币、社区、榜单、持仓），持仓数量 `figureSm` 14 / 600。11-05 改稿只抬了代币行、社区行、持仓行，榜单行（算力榜 / 社区榜 / 邀请榜 §5.16）仍是 14 / 500、数值 13 / 600。其余字阶（页标题 28、段名 24、区块标题 19 / 16、会话行 16 / 14 / 12、帖子 18 / 16 / 14、胶囊 13、tab 16、底栏 12、meta 12 / 10、按钮 16 / 12 / 13、总资产 40、算力值 30、邀请码 23、空态 17、分节 13）未动。

## Decision

### 对照表

| 组件（稿节点） | 旧（docs/58 §5） | 新（11-05 稿） | 实现 |
| --- | --- | --- | --- |
| MEME 代币行名（Token Row 2001:103，§5.4） | Inter 14 / 500 / 22 | Inter 16 / 500 / 22（6 行里 5 行已改，「S234 Walk」视为漏改） | `LoopType.rowTitle` |
| 社区行名（Community Row 2001:1077，§5.8） | Inter 14 / 500 | Inter 16 / 500 | `LoopType.rowTitle` |
| 钱包持仓行名 / 数量（2001:1761，§5.13） | 14 / 500；14 / 600 | 16 / 500；16 / 600（副行 12 / 300 不变） | 名 `rowTitle`、数量 `figure` |

### 字阶

- 新增 `LoopType.rowTitle` = Inter 16 / 500 / 22（`rowTitleLg` 是 16 / 500 / **23**，行高不同，另立一档；loop_theme.dart 注明「0301：代币 / 社区 / 持仓行主标题」）。
- `body1` 14 / 500 / 22 保留，含义改为「榜单行主标题」及其余仍是 14 的标题。
- 持仓数量从 `figureSm` 14 / 600 改 `figure` 16 / 600；`figureSm` 只剩引用卡名等。

### 共享件

- `LoopRecordRow`：`titleStyle` 为 `null` 时按 `kind` 取默认——`token` / `community` / `holdings` → `rowTitle`；`person` 由调用处传 `rowTitleLg`（不变）；`function` 与无 `kind` → `LoopType.title`（= `body1` 14 / 500，不变）。
- `LoopQuoteRow`：新增可选 `titleStyle`（默认仍 `titleLg`）。
- `LoopPersonRow`：新增可选 `titleStyle`（默认仍 `title`）。

### 影响范围

| 行类型 | 位置 | 改法 |
| --- | --- | --- |
| 代币行 | MEME 首页榜单行名 `_BoardRowName`（`launch2_atmosphere.dart`，名 + 符号同行的宽度判定一并用 16） | `rowTitle` |
| 代币行 | MEME 已毕业 / 其他 scope 列表 `Launch2InstanceTile`（`launch2_widgets.dart`） | `LoopQuoteRow.titleStyle` |
| 代币行 | 曲线 MEME 经典列表 `MemeTokenCard`（`meme_widgets.dart`） | `rowTitle` |
| 代币行 | 我的项目列表（`launch2_projects_screen.dart`，`kind: token`） | 共享默认 |
| 代币行 | 社区资料页绑定代币行（`community_profile_screen.dart`，71 高） | `LoopQuoteRow.titleStyle` |
| 代币行 / 社区行 | 社区搜索结果（`search_screen.dart` 资产、社区两类） | `LoopPersonRow.titleStyle`；用户结果不变 |
| 社区行 | 广场社区卡（`square_community_list.dart`） | `rowTitle` |
| 社区行 | 社区首页「已加入」（`community_screen.dart`）、发现页目录行（`community_widgets.dart`） | 共享默认（`kind: community`） |
| 社区行 | 他人主页 / 我的「社区」节 `CommunityRecordRow`（`community_record_row.dart`） | `titleStyle: rowTitle` |
| 持仓行 | 我的持仓 `WalletBalanceRow`（`wallet_home_widgets.dart`）：名 16 / 500、数量 16 / 600，两者行高 19（`walletHoldingLineHeight`），两行 + 4 仍在 51 − 12 = 39 内；读取失败行同步 `rowTitle` | 本地 |
| 持仓行 | Launch 链原生 / USD1 行（`wallet_read_widgets.dart`）、MEME v2 持仓行（`launch2_wallet_rows.dart`）、他人主页持仓两种（`user_profile_screen.dart`） | `titleStyle: rowTitle` + `valueStyle: figure` |
| 持仓行 | 资产选择抽屉（`money_asset_picker.dart`） | `titleStyle: rowTitle`（数量本来是 `figure`） |

不改：榜单行（算力榜 / 社区榜 / 邀请榜）、0293 / 0295 按「持仓 / 榜单行」类推的成交行（MEME 详情成交、曲线 MEME 成交、行情代币页成交）、情报行情行（不是稿里的代币行）、聊天列表（S376 并行批次）、NFT 格标题。

行高不变（代币 71 / 社区 86 / 持仓 51）。360 宽长名省略、不溢出由 `test/s377_row_title_16_test.dart` 覆盖。

## Consequences

- 代币 / 社区 / 持仓三类行的名字比旧稿大一档；行高不变，360 宽长名仍单行省略。「我的」持仓行名 / 数量用 19 行高才放得进 51，与 `rowTitle` 的 22 不同，常量 `walletHoldingLineHeight` 集中写明。
- `LoopRecordRow` 的 `kind` 现在同时决定行高与默认标题档；新调用处给 `kind: token / community / holdings` 即得 16，不必再传 `titleStyle`。
- 改写的旧断言：`test/s197_2_type_test.dart`（MEME 经典行 ticker、我的持仓名与数量）、`test/s121c_visual_followups_test.dart`（持仓名与数量）、`test/s269_type_scale_test.dart`（MEME 榜单行名、广场社区名）、`test/s335_square_community_cards_test.dart`（社区卡名）、`test/s353c_figma_me_test.dart`（持仓数量）、`test/s371_shared_components_spec_test.dart`（MEME v2 持仓行源码断言）。新增 `test/s377_row_title_16_test.dart`。
- 需求方若再改榜单行字号，按同法在 `body1` / `figureXs` 上动，不影响本决策三类行。
