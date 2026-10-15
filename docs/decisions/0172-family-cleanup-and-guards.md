# 0172 · 收尾：低项余量、死代码、圆角 token 与三条家族守卫（S186-7-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 6dd506d（已含 S186-1 ~ S186-6，决策 0166 ~ 0171）。七批走查修复的最后一批。
路由、状态合同、请求路径、controller、签名出口与文案语义不变；不新增依赖与字体；路由数不变（113）。
来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §2 低项余量（L1、L2、L12、L19 ~ L21、L24、L26 ~ L29、L31、L34）、
§3 统计（`LoopRadius.tile = 15`、`loop_components.dart` 的未命名精确值）与 §4 S186-7 行（三条守卫）。
用户裁决：M1 快打满卡（`MemeHeroCard` / `MemeProgressRing`）不动；L16 收支 rise / fall 保留；`features/perp/` 是无路由死代码，可整目录删除。

## Context

前六批把高 / 中项和大部分低项收回了原型家族，各自留下「没做」：0169 的 `meme_token_screen.dart` 两处 `LoopEmpty`；
0171 的 `token_screen.dart` 四处 `LoopEmpty` / `LoopUnavailableCard`、`market_secondary_screens` 无效资产整页 `LoopEmpty`、
钱包其余页的 `LoopEmpty` / `LoopUnavailableCard`、`security_screens.dart` 的 `Theme.of(context).textTheme`；
0170 的 `voice_room_page.dart` `LoopRadius.medium`。docs/33 §4 要求本批再加三条 harness 守卫，免得修过的东西回潮。

## Decision

### 1. 低项余量（docs/33 §2）
| # | 文件 | 改法 |
|---|---|---|
| L1 | `social/qr/loop_qr_card.dart` | 海报卡仍是 Ink 底、`LoopRadius.shell`、Line2 边，加 `.ledger-quiet` 点阵（`LoopLedgerTexturePainter(LoopLedgerTexture.quiet)`，key `qr-card-poster-texture`）；满 lime 全圆「LOOP」胶囊 → `LoopBadge('LOOP', kind: launch)`（key `qr-card-poster-badge`）。没有用 `LoopChalkCard`：海报是另存图片，整张换浅底会把头像、名字与代码全部反色。 |
| L2 | `square/square_community_list.dart` | `_MembershipCapsule` 只剩一层 `LoopPillAction`：「加入」走新增的 `soft` 形态（limeSoft 底 lime 字，无描边），已加入 / 我的 / 审核中是描边 quiet pill；加入中文字「加入中」、不可点。key 不变。`LoopPillAction` 新增 `soft` 参数（`loop_person_row.dart`），其它调用方不变。 |
| L12 | `intel/intel_rank_board.dart` | 「权重 n」描边 pill → `LoopBadge(mute)`；领奖台卡 `Radius.circular(16)` → `LoopRadius.control`（同为 16）。 |
| L19 | `account/account_screens.dart` | 删 `_SecurityCard` / `_SecurityRow`。应用锁 = `LoopRecordGroup`；交易验证两行（读自身状态的大额验证行 + MFA 行）是一个 `Column`（key `security-verification-group`），两行自带 first / last，等同 group。页面在 `LoopFlat` 内，所以两组按 OKX 平铺行画，不再是自造 r16 card。 |
| L20 | 同上 | `IdentityOptionIcon` = `LoopRowIcon(choice: true, chosen: …)`。`LoopRowIcon` 新增 `.row-choice` 形态：在 `LoopFlat` 里仍是 44 方块（选中态靠字形 lime 表达，`.row-choice.is-chosen .row-ico{color:lime}`），像素不变。 |
| L21 | `account/privy_login_screen.dart` | 三处 Material `LinearProgressIndicator` → `LoopBrandLoader`（等待网络那条保留 key `privy-awaiting-network-progress`；退出中宽 160）。 |
| L24 | `profile/presentation/avatar_editor.dart` | 上传失败的 danger 粉红字 → `LoopInlineUnavailable`（warn 字形 + 辅助灰，最多 3 行，key 不变）。 |
| L26 | `chat/member_buy/loop_member_buy_card.dart` | 买入动态卡 → `LoopRecordCard`（r20、line 边，内边距不变，外距变为上 6 / 下 14）；数据不完整 → `LoopNotice(info)`；复制哈希的墨水圆角 → `LoopRadius.inner`。 |
| L27 | `square/square_screen.dart` | 语音房分段的 `LoopProvenanceFooter('读取于 …')` → `LoopProvenanceLine(sources: ['LOOP'], observedAt)`（0117，可点开来源说明）。 |
| L28 | `chat/v2/chat_search_screen.dart` | 高亮 `TextStyle(color: lime)` → `LoopType.caption.copyWith(color: lime)`（就是该行第二行的 bodySmall 档）；输入框 r12 → `LoopRadius.inner`。 |
| L29 | `community/community_ai_screen.dart` | 回复 / 等待 / 失败与回答三处复制的「头像 + Community AI + 气泡」抽成 `_CommunityAiTurn`（气泡 + `after` 子部件）；引用 `[sN]` 的 r6 自造块 → `LoopBadge(launch)`，墨水圆角 `LoopRadius.badge`。 |
| L31 | `launch/launch_widgets.dart` | 轮次编号与 ticker 方块 → `LoopMonoTile`（r15、figure 11）。 |
| L30 | — | S186-5 已做完。 |

### 2. 前六批残留（B）
- 新增 `LoopUnavailableLine`（`features/chain/chain_widgets.dart`）：与旧 `LoopUnavailableCard` 同构造（`label` / `reasonCode` / `margin` / `action` / `.fact`），
  画一条 `LoopInlineUnavailable`（标签 2 行 + 服务端理由 3 行），内层仍带 `unavailable-<code>` key。旧 `LoopUnavailableCard` 已无调用方，**类删除**；
  全仓 30 处调用（行情、钱包、关于 / 通知 / 设置 / 帮助 / 安全中心、二维码卡）改名即换。`LoopInlineUnavailable` 新增 `detailMaxLines`（缺省 1，行为不变）。
- meme / market / wallet 三个目录内全部 `LoopEmpty` 改掉：
  无效路由整页与列表空态 → `LoopEmptyState(compact)`（插图：MEME launchpad、代币 chartEmpty、行情 / DApp / 选资产 search、提醒 history、自选 watchlist、钱包 history / profile）；
  页内 warn 型「读不到」（授权清单、跨链进度、资产不在清单、无可接收网络）→ `LoopInlineUnavailable(message, detail)`。key 全部保留。
  完成后 `lib/features/{market,meme,wallet}/` 内没有 `LoopEmpty(`、`LoopUnavailableCard`、`LoopStateCard`。
- `profile/security/security_screens.dart` 撤销会话弹层标题 `Theme.of(context).textTheme.titleLarge` → `LoopType.titleLg`（主题里就是同一个对象）。
- `chat/voice_room_page.dart` 的 `LoopRadius.medium` 是 `control` 的别名、是 token，不算偏离，不改（该文件是 preview-only）。
- `chat/v2/voice_room_screens.dart` (i) 键未确认时的 `LoopColors.warning` → lime（原型 `--amber` = lime）。

### 3. 死代码（L34）
每个删除前在 `lib/` 与 `test/` grep 过引用。
- `chat/friends/friend_screens.dart`：删 `FriendListPage`、`AddFriendPage` 及其专属 `_FriendPreviewBanner` / `_FriendIdentityRow` / `_FriendSearchResultRow` / `_FriendLoadingCard`；建群页（0168）与它用的私有部件保留。controller 与 gateway 不动。
- `chat/friends/friend_request_screen.dart` 整文件删除（`chat.dart` 的 export 一并删）；`friend_request_controller.dart` 保留（仍有控制器测试）。
- `wallet/wallet_management_screens.dart`（`DappListScreen` / `ProtectionScreen`）整文件删除，`wallet_screens.dart` 的 export 一并删。
- `profile/profile_screens.dart`：`ProfileSurfaceScreen` 只认路由真正会传的十一个 id；删掉无路由的 `copytrade-perms` / `connections` / `blocklist` / `mining` / `referral`
  分支与 `_CopyTradePermissions` / `_ConnectionsScreen` / `_BlocklistScreen` / `_ComingLaterScreen` / `_PrivacyFootnote`。兜底 `_UnknownProfileScreen` 从 `LoopPage` + `LoopStateCard`
  改为 `LoopFocusPage(state)` + `LoopEmptyState(profile)`：「设置不可用 / 没有做任何更改」（key `unknown-profile-surface` 不变）。
- 整个 `lib/features/perp/`（用户裁决），以及只为它存在的 `lib/integrations/backend/loop_perp_{providers,repository,session}.dart`（它们 import perp 的模型，没有别的调用方）和七个 perp 测试文件。
  路由清单里 12 条退役 Perp 路径（`route_manifest.dart`）与 app.dart 的「不得挂载 Perp」守卫保留——路径是历史，代码不是。
- 测试：`friend_feature_test` 删除只针对两页的三例、两例瘦身（「gateway rotation clears the visible group text」改名）；`friend_request_feature_test` 删三个 widget 例与只为它们存在的帮助函数；
  `social_ui_safety_edges_test` 删末尾对好友列表的渲染断言；`privacy_presentation_screen_test` 的跟单权限段改为断言该 id 落到未知设置页；`security_capability_truthfulness_test` 改中文文案。
- harness：`REQUIRED_FILES` / 测试夹具去掉被删文件；friend 前端合同去掉被删页的片段与测试标记；删 `check_perp_positions_application_contract` 及其常量、单测；
  `S5_HYPERLIQUID_UNMOUNTED_EXEMPT_ROOT`（perp 豁免）删除——以后谁在 `features/perp/` 重建文件就是普通 feature 文件，不得 import Hyperliquid（单测改为正向断言）；
  `test/loop_theme_test.dart` 的旧 accent 名单缩到实际仍用的 6 个文件。`harness.json`、`AGENTS.md`、`README.md` 的 Perp 句子同步改成「已删除」。

### 4. Token（D）
- `LoopRadius` 新增：`tile = 15`（`.row-ico` / `.tcard-logo` / `.notice` / `.power-hint` / `.composer input`）、`button = 14`（`.btn` / `.seg` / `.composer button`）、
  `tool = 13`（`.back` / `.tool-btn`）、`badge = 7`（`.badge`）、`wideButton = 26`（52 高平铺宽按钮的半高），各带 `…Value`。
- `LoopColors` 新增原型合成值的名字（像素不变）：`quietFolioGlow / quietFolioTint`、`recordCardGlow / recordCardTint`、`primaryGlow`、`contactShadow`。
- `widgets/loop_components.dart`：r13 / r14 / r15 / r7 / r26 与上面六个颜色全部换成具名常量，选中行 3 px 轨道圆角收为私有 `_selectedRowRailEnd`；**不改像素**。
- `features/**` 与 `widgets/**` 的 r15 → `LoopRadius.tile`（`loop_blocks` 两处、`loop_toast`、`chat_forward_screens` 序号块、`community_widgets` 申请进度）。
  r14 只有一处语义与 15 相同：转发合并预览的「n/m 可见」小块，并到 `tile`（**+1 px**）。原型里 14 是按钮 / seg 的角，`loop_components` 里的 14 因此命名为 `button` 而不是并到 15。
- 其余 features 字面量：`voice_room_stage` 两处 InkWell r12 → `inner`；`loop_id_copy` InkWell r8 → `inner`（只影响按压水波形状）；`scan_screen` r20 / r16 → `cardValue` / `controlValue`（同值）；
  `chat_components`（preview-only）气泡 r15 → `tileValue`、尾角 r4 → `bubbleTail`（5，**+1 px**）；`community_home_widgets` 的 `.community-discover-hero` r19 收为私有常量 `_communityDiscoverHeroRadius`。

### 5. harness 三条守卫（E）
`scripts/check_harness.py` 新增 `check_family_guard_contract`（`validate()` 中排在 S186-5 的 `check_flat_family_contract` 之后，后者保留），只扫 `lib/features/**`、先去注释：
1. **圆角**：禁 `Radius.circular(数字)` / `BorderRadius.circular(数字)`。白名单 `FEATURE_RADIUS_LITERAL_ALLOWLIST` 是「文件 + 字面量所在的顶层类 / 常量名」：
   `loop_market_chart.dart · _ChartCorner`、`loop_candle_chart.dart · _candleCorner`、`meme_widgets.dart · MemeHeroCard`、`community_home_widgets.dart · _communityDiscoverHeroRadius`。
2. **v1 色**：禁 `LoopColors.market / chat / danger / warning / elevated`，白名单只有六个 preview-only 文件。这些颜色在 `core/theme` 之外仍有生产引用
   （`widgets/loop_ui.dart`、`loop_loading`、`loop_sign_steps`、`loop_person_row`、`loop_unread_badge`、`loop_flat`、`integrations/communication/stream_chat_appearance` 等），
   所以本批**没有**标 `@Deprecated`（会让 analyze 出一串 deprecated_member_use）；守卫只管 features。
3. **v1 部件**：禁 `LoopStateCard`、`LoopPage(`、`LoopEmpty(`、`LoopUnavailableCard`、`LoopCard(`、`LoopSectionLabel`、`LoopStatusPill`、`LoopWideButton`、`LoopSubChip`。
   剩下的用 `FEATURE_LEGACY_WIDGET_ALLOWLIST` 按文件锁死，每条写理由。

三张白名单都**只能缩**：某条目对应的文件已经不再需要它，守卫本身报错要求删掉该条。`tests/test_check_harness.py` 新增 `FamilyGuardContractTests`（13 例）：
现仓库通过；三条各有反例（字面量 / 五种 v1 色 / 九种 v1 部件均报错）与正例（token、注释、`widgets/` 目录、家族部件、白名单内的命名常量与 preview 文件通过）；
白名单外同文件另一个类里的字面量仍报错；三类过期条目报错；圆角与颜色白名单内容固定；部件白名单每条有理由且不含 market / meme / wallet。

## Consequences

- 行情、MEME、钱包三个目录不再有 v1 状态部件；空态都是插图 `LoopEmptyState`，读不到都是 `LoopInlineUnavailable`。
- `LoopUnavailableCard` 不存在了；以后 `{label, reasonCode}` 块只有 `LoopUnavailableLine` 一种写法。
- 删掉约 1.1 万行无路由代码与测试（perp 十个文件、三个 perp adapter、两页好友旧壳、两个钱包旧页、五个我的旧页）及其测试；`ProfileSurfaceScreen.supportedIds` 从 16 个缩到 11 个。
- 以后 features 里写裸圆角、v1 色或 v1 部件会直接让 `python3 scripts/check_harness.py` 失败。
- 可见变化（均待主代理真机验收）：二维码海报多了 quiet 点阵、「LOOP」变 limeSoft 徽标；广场社区行「加入」不再满 lime；安全设置两组变平铺行；
  群友买入卡变 r20 record-card、下方多 8 px；登录等待线变品牌加载线；社区 AI 引用块变徽标；旧 IDO 编号块 r12 → r15；两处 +1 px（见 §4）。

### 仍保留的例外
- **圆角字面量**（守卫 1 白名单）：`market/loop_market_chart.dart · _ChartCorner`（1 / 3 / 4 px 图表几何）、`market/loop_candle_chart.dart · _candleCorner`（1.25 px）、
  `meme/meme_widgets.dart · MemeHeroCard`（r16，M1 用户裁决不动）、`community/community_home_widgets.dart · _communityDiscoverHeroRadius`（原型 19 px）。
- **v1 色**（守卫 2 白名单）：`chat/chat_inbox_page`、`chat/conversation_pages`、`chat/chat_secondary_pages`、`chat/voice_room_page`、`chat/chat_preview_pages`、`chat/widgets/chat_components`（均只挂 preview 路由）。
  features 之外：`widgets/loop_ui.dart` 等 v1 部件本体与 `integrations/communication/stream_chat_appearance.dart`（Stream 主题）仍用，故未加 `@Deprecated`。
- **v1 部件**（守卫 3 白名单，49 个文件）：
  - preview-only 聊天（8）：`chat_inbox_page`、`chat_preview_pages`、`chat_preview_route_guard`、`chat_secondary_pages`、`conversation_pages`、`preview_conversation_unavailable_page`、`voice_room_page`、`widgets/chat_components`。
  - 共享链上状态条（1）：`chain/chain_widgets.dart`（`LoopChainStateBlock` 等的 `LoopEmpty`，换掉会一次改动所有链上页）。
  - docs/33 未点名、需逐页验收的 `LoopEmpty` 内联条（40）：account（`account_screens`、`loop_id_setup_screen`、`privy_otp_screen`）；
    chat v2（`token_card/chat_token_card`、`chat_forward_screens`、`chat_search_screen`、`community_chat_screen`、`direct_message_screen`、`forward_target_sheet`、`group_screens`、`loop_stream_channel_surface`、`voice_room_screens`、`voice_room_stage`）；
    community（`community_ai_screen`、`community_discover_screen`、`community_manage_screen`、`community_members_screen`、`community_profile_screen`（另有 0127 申请入口 `LoopWideButton`）、`community_screen`、`community_widgets`（另有 0127 申请表单 `LoopWideButton`）、`search_screen`）；
    social / square（`blocklist_screen`、`public_profile/user_profile_screen`、`public_profile_sheet`、`square_community_list`）；
    launch 旧 IDO（`launch_action_screens`、`launch_detail_screens`、`launch_screen`、`launch_trade_screen`、`launch_widgets`）与 launch2（`launch2_instance_screen`、`launch2_nft_screen`）；
    mining（`mining_screen`、`mining_secondary_screens`、`referral_screen`）；profile（`profile_v2_screens`、`security/security_screens`）；`scan/scan_screen`、`security/mfa/passkey_sheet`、`system/system_surfaces`。
- 未按清单改的点：L1 没用 `LoopChalkCard`（理由见 §1）；`voice_room_page` 的 `LoopRadius.medium` 是 token 别名、未改；
  `community_widgets` 申请表单的「取消」`TextButton`（0170 提到）与 `chat/calls/*`、`security/*`、`chat_components` 等处剩余的 `Theme.of(context).textTheme` 不在本批清单内，未动。

## Verification

- 命令：`bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  `python3 -m unittest discover -s tests -p 'test_*.py'`、全量 `bin/flutter test`（结果见提交说明）。
- 未起模拟器、未做真机验收：§Consequences 列出的可见变化待主代理验收。
