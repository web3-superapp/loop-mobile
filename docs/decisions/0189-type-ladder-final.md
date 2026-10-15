# 0189 · 字体阶梯定稿、共享部件落档与两条字体守卫（S197-1-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 449ad64。来源：主仓库 `docs/37-全App字体一致性走查-2026-10-15.md` §1（角色规范表）、§2.4（W1–W11）、§4 批 1 与 §4.1（G1、G2、G7）。
用户裁决（2026-10-16）：**S1** `LoopQuoteRow` 按方案 A 回到阶梯内；**S2** 平铺行（0126）与账本行合并为一套行尺寸，`LoopFlat` 不再改行字号。
本批只改 `lib/core/theme/`、`lib/widgets/`、`scripts/check_harness.py`、`tests/`、`test/` 与本决策 / 0119 / 0122 / 0126 的修订记录；`lib/features/**` 一行未动（S198 / S199 并行改 features，第 2–4 批逐页落档）。
不新增依赖、路由、字体；`pubspec.lock` 不变。

## Context

docs/37 的结论：根因不是「没走 token」，是 token 能带任意数字——features 579 处字体调用里 325 处是 `LoopTypography.xxx(数字)`，100 处离档；共享部件自己还有 21 处离档
（`LoopQuoteRow` 18 / 18 / 16）。同类列表行三套尺寸（账本行 15/12/13、平铺行 16/13/14、行情行 18/14/18），弹层标题六种，签名弹层标题比普通弹层小两档。
harness 只拦 `fontSize:`，拦不住 builder 带数字。

## Decision

### 1. 阶梯定稿（`LoopType`，每档带用途注释）

| # | 角色 | 档 | 字号 / 字重 / 行高 |
|---|---|---|---|
| R1 | 页面标题 · 一级 Tab / 账本二级页 | `headingLg` | 22 / 600 / 1.25 |
| R1b | 页面标题 · 平铺二级页 | **`flatTitle`（新）** | 20 / 700 / 1.25 |
| R1c | 页面标题 · 步骤页 | **`stepTitle`（新）** | 24 / 700 / 1.25 |
| R1d | 聊天会话顶栏 | `headingSm` | 17 / 600 / 1.3 |
| R2 | 弹层标题（只经 `LoopSheetHeading` / `LoopSheet` / `LoopSignSheet`） | `heading` | 20 / 600 / 1.25 |
| R3 / R3c | 段标题 / 卡内小标题 | `eyebrow` | 12 / 500 / 1.25 text3 |
| R3b | 段标题 · 平铺页 | `headingSm` | 17 / 600 / 1.3 |
| R4 | 行标题（账本行、平铺行、人物行同一档，S2） | `title` | 15 / 600 / 1.3 |
| R5 | 行副标题（同上，S2） | `caption` text2 | 12 / 400 / 1.35 |
| R6 | 行右侧数值 | `figure` | 13 / **600**（原 500）/ 1.3 |
| R7 | 行右侧副值 / 涨跌 | `figureXs` | 11 / 400，涨跌 600 / 1.35 |
| R8 / R11 / R13 | 账本卡 kicker、stamp，统计格标签 | **`kicker`（新）** | 11 / 500 / 1.25 |
| R9 | 账本卡 heading | `displayXl`（intro / record / state）· `display`（action）· `displaySm`（index / compact） | 28 / 26 / 24 · 600 / 1.2 |
| R10 | 账本卡 caption | `caption` | 12 / 400 / 1.35 |
| R12 | 统计格数值 | `figure` | 13 / 600 |
| R14 | 徽标 | `label` @700 | 12 / 700 / 1.25 |
| R15 | 按钮；平铺宽按钮 | `label` @700；`titleLg` | 12 / 700；16 / 600 |
| R16 | 分段胶囊；quiet | `label`；`action` | 12 / 600（选中 700）；14 / 600（选中 700） |
| R17 | 行内文字动作 | `label` @600 | 12 / 600 |
| R18 | 正文 | `body` | 14 / 400 / 1.4 |
| R19 | 弹层说明 | `bodySm` | 13 / 400 / 1.4 text2 |
| R20 | 页内辅助说明 / 提示 | `caption` | 12 / 400 / 1.35 |
| R21 | 来源 / 版本 / 脚注 | `captionSm` | 11 / 400 / 1.35 |
| R22 | 主视觉大数字 | `figureXl` | 28 / 600（不加粗）/ 1.2 |
| R22b / R24 | 大数字小数 / 金额输入 | `figureLg` | 20 / 600 / 1.25 |
| R23 | 副大数字 | `figureMd` | 17 / 600 / 1.3 |
| R25 | 文本输入（正文 + 占位） | `bodyLg` | 15 / 400 / 1.4 |
| R26 | 搜索框占位 | `body` | 14 / 400 |
| R27 | 个人 / 社区主页名字 | `displaySm` | 24 / 600 |
| R29 | 键值行 | 键 `captionSm` text2 / 值 `figureXs` @500 | 11 |
| R30 | 地址 / 哈希 | `code` / `codeSm` | 13 / 11 · 500 |
| R31 | 居中状态页标题 | `titleLg`（compact `title`） | 16 / 15 · 600 |

- 「figure 系列字重统一 600」落为：`figureXl / figureLg / figureMd / figure` 均 600（`figure` 由 500 改 600，W3）；`figureSm` / `figureXs` 按 §1 R7 保持中性 400、涨跌经 `withWeight` 到 600。
- 别名层：`LoopType.monoDisplay / monoQuote / monoValue / monoBody` 删除（无调用方）；`LoopType.monoTitle / monoStamp` 与 `LoopMono.*`、`context.dataStyle` 标为弃用别名（注释，不加 `@Deprecated`，免得 analyze 出 deprecated_member_use），
  `lib/widgets` 内调用全部改掉；features 内 31 处与 integrations（Stream 主题、图片附件）内调用留给后批，features 的计入 G1 白名单。
- 主题：`textTheme.bodyLarge`（裸 `TextField` 默认字）→ `bodyLg` 15；`inputDecorationTheme.hintStyle / labelStyle` → `bodyLg` text3（原 13）；snackbar 正文显式 `body`；新增 `listTileTheme` 标题 `body` / 副标 `bodySm`，使 `bodyLarge` 改档不波及 ListTile。

### 2. 共享部件前后对照（`lib/widgets/**` 内已无 `LoopTypography.<band>(数字)` 与 `copyWith(fontSize:`）

| 部件 | 文字 | 前 | 后 |
|---|---|---|---|
| `LoopQuoteRow`（S1） | 标题 / 副题 / 副题尾注 / 数值 / 副值 | 18·600 / 14 / 11 / 18·700 / 14 | `titleLg` 16 / `bodySm` 13 / `captionSm` 11 / `figureMd` 17·600 / `figureSm` 12 |
| `LoopChangePill`（S1） | 涨跌 | 16·700 | `figure` 13·700 |
| `LoopRecordRow` 账本（S2） | 标题 / 副题 / 值 / 副值 | 15 / 12 text3 / 13·600 / 11·600 | `title` 15 / `caption` 12 text2 / `figure` 13·600 / `figureXs` 11·400（涨跌 600） |
| `LoopRecordRow` 平铺（S2） | 标题 / 副题 / 值（强值） / 副值 | 16 / 13 / 14·500（16·600） / 11·600 | 同账本行：15 / 12 / 13·600（灰或 Chalk / trailingColor） / 11 |
| `LoopPersonRow`（S2） | 名字 / 副行 | 16 / 13 | `title` 15 / `caption` 12 text2 |
| `LoopTag` / `LoopPillAction` / `LoopSeeAll` | — | label(11·600) / label(13·600) / body(13) | `kicker`@600 / `titleSm`@600 / `bodySm`（像素不变） |
| `LoopSheetHeading` / `LoopSheet` | 标题 | headlineMedium 20·600 | `LoopType.heading`（同值，显式） |
| `LoopSignSheet` | 标题 / 理由 / 签名中标题 | 16·600 / 11 / 13·700 | `heading` 20·600 / `caption` 12 / `title` 15 |
| 输入框主题 | 占位 / 浮动标签 / 裸 TextField 正文 | 13 / 13 / 14 | `bodyLg` 15 |
| `loopFormFieldDecoration` / `LoopComposer` / URL 字段 | 占位 / 输入 / 输入+占位 | 15 / 11 / 13+11 | `bodyLg` 15 / `bodyLg` 15 / `body` 14 + 14 |
| `LoopFolioPrimary` | kicker / heading / caption / stamp | eyebrow(11) / 30·25·29·27·29（compact 24） / 12 / eyebrow(11) | `kicker` / 28·24·28·26·28（compact 24） / `caption` / `kicker` |
| `LoopStatGrid` | 值 / 标签 | 13·600 / eyebrow(11) | `figure` / `kicker`（像素不变） |
| `LoopBadge` | — | 12·700 | `label`@700（不变） |
| `LoopSeg` | 普通 / quiet | 12 / 14，600·700 | `label` / `action`，600·700（不变） |
| `LoopButton` | 普通 / 平铺宽 | 12·700 / 16·600 | `label`@700 / `titleLg`（不变） |
| `LoopLabel` | 账本 / 平铺 / tight | LoopMono.label 12 / 17 / 15 | `eyebrow` / `headingSm` / `title`（不变） |
| `LoopNotice` | 平铺单行 / 卡片正文 | 11 / 11 | `caption` 12 / `caption` 12（W9） |
| `LoopInlineUnavailable` | 文案 / 「重试」 | 11 / 12·500 | `captionSm` 11 / `label` 12·600（R17） |
| `LoopEmptyState` | 标题 / 说明 | 16（compact 15）/ 13 | 不变（已是 `titleLg` / `title` / `bodySm`） |
| `LoopTopbar` | 平铺 / 步骤 / kicker / 副题 | 20·700 / heading(24,700) / LoopMono.label / 11 | `flatTitle` / `stepTitle` / `eyebrow` / `captionSm` |
| `LoopFlatHeading` | 标题 / 副题 | display(24) 600 / 14 | `stepTitle` 24·700（W8）/ `body` |
| `LoopKeyValue` | 键 / 值 | 11 / 11·500 | `captionSm` / `figureXs`@500（不变） |
| 其它（W10） | `LoopUnreadBadge` 10 → `figureXs` 11·600；`LoopFigureBox` 21 → `figureLg` 20；主宫格 16·800 → `titleLg`@700；小宫格 12·800 → `label`@700；`LoopCompositeDetailRow`（旧 IDO）26 / 18 / 15·800 → 最近 figure 档 28 / 17 / 17·600；`LoopSignSteps` 步名 14 → `title` 15；toast 动作 13·700 → `label`@700；「完成」15·600 → `action` 14；代币卡代码 14·700 → `title`、价格 17 h1.15 → `figureMd`、指标标签 → `kicker`；折叠条标题 12·700 → `label`@600（R17）；图表面板头 11·600 → `figureXs`（方向 600）。 | | |

- 删除死代码 `LoopHeroFigure`（W11，无挂载、`title(32,800)`）。`CommunityIdentityBlock` 在 features，留后批。
- 按头像尺寸缩放的字母（`loop_assets` 的 `size * 0.34`、`loop_avatar_stack` 的 `+N`）保留比例 builder：它们不是字号阶梯里的角色，G1 只拦数字字面量。

### 3. 守卫（`check_type_ladder_contract`，排在 S186-7 之后）

- **G1**：`lib/features/**` 与 `lib/widgets/**` 禁 `LoopTypography.<display|heading|title|body|caption|label|eyebrow|figure|code|sans|mono>(数字…`（含多行与 `size:` 命名参数）、`copyWith(… fontSize:`、
  以及弃用别名 `LoopMono.*` / `LoopType.mono*` / `.dataStyle`。`lib/widgets` 为 0、白名单不得收 widgets 条目；features 现有违规以 `TYPE_LADDER_FEATURE_ALLOWLIST` 按文件登记精确条数
  `(数字 builder, 别名)`——多了报 grew，少了报 shrank 要求改小，清零要求删条目（只能缩）。
- **G2**：`lib/**` 全仓解析出的字面字号（builder 首参与 `fontSize:`）不得低于 11。图表画布 `market/loop_candle_chart.dart`、`market/loop_market_chart.dart`（轴标 7 / 9）两项豁免 G1 与 G2；
  features 里 9 处非图表低于 11 的调用以 `TYPE_FLOOR_FEATURE_ALLOWLIST` 按文件计数，同样只能缩。
- `tests/test_check_harness.py` 新增 `TypeLadderContractTests`（10 例）：现仓库通过；G1 八种反例 × 两棵树均报错；阶梯档 / withWeight / copyWith(color) / 注释 / 比例 builder / theme 文件通过；
  白名单计数增减、过期条目、widgets 条目均报错；G2 三处（features / widgets / integrations）反例、11 与画布正例；画布清单与 9 处总数固定。
- `test/type_roles_test.dart`（G7，11 例）：逐个 pump 上表共享部件，按实际绘制样式断言 fontSize / fontWeight / height / family 等于阶梯常量；账本行与平铺行同一套断言跑两遍（S2）。

### 4. features 白名单剩余（81 个文件，374 处数字 builder + 31 处别名；另 G2 9 处）

| 文件 | 数字 builder | 别名 |
|---|---|---|
| `account/account_screens.dart` | 8 | 0 |
| `account/loop_id_setup_screen.dart` | 5 | 0 |
| `account/onboarding_communities.dart` | 4 | 0 |
| `account/privy_login_screen.dart` | 11 | 0 |
| `account/privy_otp_screen.dart` | 3 | 0 |
| `chain/chain_widgets.dart` | 0 | 5 |
| `chat/calls/voice_media_state_card.dart` | 2 | 0 |
| `chat/chat_inbox_row_actions.dart` | 2 | 0 |
| `chat/chat_preview_pages.dart` | 0 | 1 |
| `chat/friends/friend_screens.dart` | 2 | 0 |
| `chat/group_alias/group_alias_screen.dart` | 2 | 0 |
| `chat/member_buy/loop_member_buy_card.dart` | 7 | 0 |
| `chat/stream_chat_inbox_page.dart` | 2 | 0 |
| `chat/token_card/chat_token_card.dart` | 1 | 0 |
| `chat/v2/chat_forward_screens.dart` | 9 | 0 |
| `chat/v2/chat_search_screen.dart` | 1 | 0 |
| `chat/v2/forward_target_sheet.dart` | 4 | 0 |
| `chat/v2/group_screens.dart` | 1 | 0 |
| `chat/v2/loop_stream_channel_surface.dart` | 3 | 0 |
| `chat/v2/voice_room_screens.dart` | 6 | 0 |
| `chat/v2/voice_room_stage.dart` | 11 | 0 |
| `chat/widgets/chat_components.dart` | 0 | 1 |
| `community/community_ai_screen.dart` | 13 | 0 |
| `community/community_home_widgets.dart` | 4 | 0 |
| `community/community_manage_screen.dart` | 2 | 0 |
| `community/community_member_faces.dart` | 1 | 0 |
| `community/community_profile_screen.dart` | 6 | 0 |
| `community/community_screen.dart` | 1 | 1 |
| `community/community_widgets.dart` | 19 | 0 |
| `community/search_screen.dart` | 2 | 0 |
| `intel/intel_rank_board.dart` | 0 | 2 |
| `launch/launch_action_screens.dart` | 13 | 0 |
| `launch/launch_detail_screens.dart` | 11 | 1 |
| `launch/launch_trade_screen.dart` | 15 | 0 |
| `launch/launch_widgets.dart` | 17 | 0 |
| `launch2/launch2_instance_screen.dart` | 6 | 0 |
| `launch2/launch2_launchpad.dart` | 9 | 1 |
| `launch2/launch2_nft_screen.dart` | 2 | 0 |
| `launch2/launch2_pool_trade_panel.dart` | 1 | 0 |
| `launch2/launch2_signing.dart` | 2 | 0 |
| `launch2/launch2_trade_panel.dart` | 2 | 0 |
| `launch2/launch2_wallet_rows.dart` | 1 | 0 |
| `launch2/launch2_widgets.dart` | 11 | 0 |
| `market/token_card_chart.dart` | 1 | 0 |
| `market/token_screen.dart` | 2 | 0 |
| `market/watchlist/watchlist_editor_screen.dart` | 1 | 1 |
| `meme/meme_home_top.dart` | 2 | 0 |
| `meme/meme_widgets.dart` | 4 | 0 |
| `mining/mining_screen.dart` | 2 | 1 |
| `mining/mining_secondary_screens.dart` | 11 | 1 |
| `mining/mining_widgets.dart` | 16 | 0 |
| `mining/referral_screen.dart` | 9 | 0 |
| `mining_rewards/mining_rewards_screen.dart` | 3 | 1 |
| `profile/presentation/avatar_editor.dart` | 3 | 0 |
| `profile/profile_v2_screens.dart` | 11 | 0 |
| `profile/security/security_screens.dart` | 2 | 0 |
| `profile/settings/settings_screen.dart` | 1 | 0 |
| `profile/support/support_screen.dart` | 1 | 2 |
| `scan/scan_screen.dart` | 5 | 0 |
| `security/app_lock/app_lock_gate.dart` | 2 | 0 |
| `security/app_lock/app_lock_prompt.dart` | 2 | 0 |
| `security/mfa/mfa_sheet.dart` | 5 | 0 |
| `security/mfa/passkey_sheet.dart` | 1 | 0 |
| `security/step_up/step_up_widgets.dart` | 2 | 0 |
| `shell/loop_pending_surface.dart` | 0 | 3 |
| `shell/loop_shell.dart` | 1 | 0 |
| `social/connections_screen.dart` | 1 | 0 |
| `social/public_profile/user_profile_screen.dart` | 10 | 0 |
| `social/public_profile_sheet.dart` | 3 | 0 |
| `social/qr/loop_qr_card.dart` | 7 | 0 |
| `square/square_community_list.dart` | 10 | 0 |
| `square/square_feed_view.dart` | 16 | 0 |
| `square/square_screen.dart` | 4 | 0 |
| `system/system_surfaces.dart` | 3 | 0 |
| `wallet/approval_screens.dart` | 0 | 1 |
| `wallet/money_actions_widgets.dart` | 0 | 2 |
| `wallet/send_screens.dart` | 2 | 0 |
| `wallet/swap_screens.dart` | 0 | 3 |
| `wallet/wallet_home_widgets.dart` | 3 | 0 |
| `wallet/wallet_read_screens.dart` | 0 | 2 |
| `wallet/wallet_read_widgets.dart` | 6 | 2 |

G2：`account/privy_login_screen.dart` 1、`meme/meme_widgets.dart` 1、`mining/mining_secondary_screens.dart` 3、`mining/mining_widgets.dart` 3、`mining/referral_screen.dart` 1。

后续：S197-2（钱包 / MEME / 情报 / 代币）、S197-3（个人 / 社区 / 社交 / 广场 / 聊天弹层）、S197-4（挖矿 / 账户 / 系统 / 发射创建）按 docs/37 §4 逐页落档并同步下调两张白名单；preview-only 聊天文件与旧 IDO `launch/` 随其退役清零。

## Consequences

- 全 App 可见变化（待主代理真机验收）：钱包 Tab / 行情 / 发射台 / 他人主页交易等 `LoopQuoteRow` 明显变小（18 → 16 / 17，胶囊 16 → 13）；设置 / 安全 / 社区成员等平铺行与 `LoopPersonRow` 字小一号（16/13/14 → 15/12/13），
  平铺页交易记录金额 16 → 13；账本行副标题由 text3 变 text2；签名弹层标题 16 → 20；所有默认输入框占位 13 → 15、裸 TextField 正文 14 → 15、聊天式 composer 11 → 15；账本卡标题 30 / 25 / 29 / 27 → 28 / 24 / 28 / 26；
  平铺提示 11 → 12；步骤页大标题（`LoopFlatHeading`）600 → 700；页面里直接用 `LoopType.figure` 的数字由 500 变 600；未读角标 10 → 11。
- 0119 / 0122 的 OKX「18 粗」行与 0126 的平铺行 16 / 13 / 14 被本决策修订（各文末已记「0189 修订」）。
- 以后在 features / widgets 写 builder 数字、`copyWith(fontSize:)`、弃用别名或低于 11 的字号，`python3 scripts/check_harness.py` 直接失败。
- 未按清单做的点：别名层未删（features / integrations 仍有调用，本批不能动 features）；`figureSm` / `figureXs` 未改 600（按 §1 R7 保持中性 400）；`CommunityIdentityBlock` 死代码在 features，未删；
  integrations 的 `LoopMono.stamp`（Stream 主题、图片附件）未改（不在本批目录内，G1 不覆盖 integrations）。
- 验证：`dart format --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、`python3 -m unittest discover -s tests -p 'test_*.py'`、全量 `bin/flutter test`（数字见提交说明）。未起模拟器。
