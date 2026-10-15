# 0183 · 旧 `LoopEmpty` 内联条全部退役，家族守卫白名单只剩 preview 聊天（S192-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 1af417b。接 0172 §5 守卫 3 的白名单（49 → 8）。
路由（113）、状态合同、请求路径、controller、文案、key 与重试回调不变；不新增依赖、插图与字体。
来源：主仓库 `docs/33-全App对照原型一致性走查-2026-10-15.md` §1 第 5 条（空态用 `LoopEmptyState`，内联不可用用 `LoopInlineUnavailable`，
不用旧 `LoopEmpty` / `LoopStateCard` / `LoopUnavailableCard`）；0172「仍保留的例外」里的 40 个 `_LEGACY_EMPTY` 文件与 `chain/chain_widgets.dart`。

## Context

0172 只把 market / meme / wallet 三个目录收回了家族，其余 37 个 feature 文件的 107 处 `LoopEmpty(` 被 `FEATURE_LEGACY_WIDGET_ALLOWLIST`
以 `_LEGACY_EMPTY` 理由锁着，另有 `chain_widgets.dart`（共享链上状态块，59 个调用方）与两处 0127 `LoopWideButton`（社区加入条、申请表单）。
`LoopEmpty` 是 17px 字形 + 两行 11px 灰字的左上角内联条，和 0122 的插图空态、0117 的 44px 不可用线是两种语汇。

## Decision

### 1. 换法（每处保留原 key、文案与动作）
- **内容为空**（「还没有 / 没有 … / 为空」，以及无效路由整段）→ `LoopEmptyState(compact: true)`：`message` → `title`、`reason` → `message`、`action` 原样。
  插图按语义取现有 12 张：chat（会话 / 转发 / 社区 AI）、search（聊天搜索）、friends（私聊需好友）、members（群 / 社区 / 语音房名单与举手队列）、
  voiceRoom（房间已结束）、launchpad（旧 IDO 轮次 / 配置 / 已毕业、launch2 无效标识）、history（账本 / 安全事件 / 规则草案 / 链上默认空态）、
  holders（算力计入资产）、rank（算力榜）、profile（账户 / 资料 / 隐私 / 设备 / Passkey / 用户资料）。全部用 compact：这些块都在页面段内或 `block:` 槽里，
  非 compact 版本要 64% 视口最小高度，会把段后内容推出屏幕。
- **读不到 / 不可用 / 未开放 / 缺标识**（原 `icon: warn / offline / clock / shield / lock / camera …`）→ `LoopInlineUnavailable(message, detail)`，
  `maxLines: 2`、`detailMaxLines: 4`（服务端理由不截断），原字形保留（原 `info` 或缺省改为 `warn`，代币卡「未收录」除外），`margin` → `padding`。
  - 原动作是「重试」按钮的两处（`chat-token-card-offline-*`、系统页「无法连接到服务器」）→ `onRetry`，即该线右侧的「重试」文字动作。
  - 原动作是别的按钮、且带 key 的四处（`voiceroom-media-backstage` ×2「刷新」、`community-discover-ordering-unavailable` / `square-community-ordering-unavailable`
    「按成员最多排序」）→ 外层 `Column`（承接原 key）= `LoopInlineUnavailable` + 原 `LoopButton`（key 与 busy 文案不变）。
  - `CommunityUnavailableCard` 同此写法（有 `action` 时线下接按钮，key `community-unavailable-<code>` 在外层）。
- 共享块：`LoopChainStateBlock`（chain）、`CommunityStateBlock`、`LaunchStateBlock` 的默认空态 → `LoopEmptyState(compact)`，不可用 → `LoopInlineUnavailable`；
  `LoopCapabilityBlockCard` 的不可达 → `LoopInlineUnavailable(icon: offline)`；`LaunchUnavailableCard` → `LoopInlineUnavailable`。
  `LoopChainStateBlock` 新增 `emptyIllustration`（缺省 `LoopIllustration.history`），59 个调用方不改；传了 `empty:` 的照旧。
- 没有用 `LoopNotice`：逐处看下来没有纯说明类的 `LoopEmpty`；而且平铺页里 info 型 `LoopNotice` 会把标题与正文拼成一行，`find.text(message)` 的现有断言会失效。

| 文件（`lib/features/`） | → `LoopEmptyState`（插图） | → `LoopInlineUnavailable` |
|---|---|---|
| `account/account_screens.dart` | `unknown-account-surface`(profile) | `external-wallet-list-unavailable` |
| `account/loop_id_setup_screen.dart` | `loop-id-empty`(profile，「载入」按钮保留) | — |
| `account/privy_otp_screen.dart` | `privy-otp-no-destination`(profile) | — |
| `chain/chain_widgets.dart` | `<prefix>-state-empty`(`emptyIllustration`) | `<prefix>-state-unavailable`、`capability-unreachable` |
| `chat/token_card/chat_token_card.dart` | — | `chat-token-card-unlisted-*`、`chat-token-card-offline-*`（onRetry） |
| `chat/v2/chat_forward_screens.dart` | `chat-forward-no-messages` / `-no-targets` / `chat-merge-empty`(chat) | `chat-forward-missing-source` |
| `chat/v2/chat_search_screen.dart` | `chat-search-idle` / `chat-search-empty`(search) | `chat-search-not-connected` |
| `chat/v2/community_chat_screen.dart` | — | `_ChatBlock`（`community-chat-missing-id` / `-capability-unavailable` / `-unavailable`） |
| `chat/v2/direct_message_screen.dart` | `dm-friendship-required`(friends) | `dm-operator-required`、私有 `_Block`（`dm-missing-target`、`dm-capability-unavailable`） |
| `chat/v2/forward_target_sheet.dart` | `forward-target-sheet-empty`(chat) | — |
| `chat/v2/group_screens.dart` | `group-info-state-empty`(members) | `group-info-capability-unavailable` / `-missing-cid` / `-state-unavailable`、私有 `_Block`（`group-missing-cid` 等） |
| `chat/v2/loop_stream_channel_surface.dart` | — | 无重试的「会话不可用」 |
| `chat/v2/voice_room_screens.dart` | roster 空、`voiceroom-queue-self-only` / `-queue-empty` / `-invite-empty`(members)、`voiceroom-ended`(voiceRoom，「返回社区」保留) | `-evidence-pending`、`-capability-unavailable`、`-missing-id`、`-not-joinable`×2、`-host-no-leave`×2、`-media-unavailable`、roster 不可用、`-step-down-unavailable`、`-media-backstage`×2（+「刷新」） |
| `chat/v2/voice_room_stage.dart` | — | `voiceroom-speakers-unavailable`、`voiceroom-listeners-unavailable` |
| `community/community_ai_screen.dart` | `community-ai-state-empty` / `-capabilities-empty`(chat) | `community-ai-state-unavailable` |
| `community/community_discover_screen.dart` | — | `community-discover-ordering-unavailable`（+ 原按钮） |
| `community/community_manage_screen.dart` | — | `community-manage-missing-id`、`community-manage-permission` |
| `community/community_members_screen.dart` | — | `community-members-missing-id` |
| `community/community_profile_screen.dart` | — | `community-profile-missing-id` |
| `community/community_screen.dart` | `community-joined-empty`(members) | — |
| `community/community_widgets.dart` | `community-state-empty`(members) | `community-state-unavailable`、`CommunityUnavailableCard` |
| `launch/launch_action_screens.dart` | — | `loop-economy-onchain-unavailable`、`loop-economy-reason-*`、`launch-apply-providers-pending`、`launch-apply-kyb` |
| `launch/launch_detail_screens.dart` | `launch-detail-no-config`、`launch-track-empty`、`launch-rounds-empty` / `-no-subject` / `-no-config`(launchpad)、`launch-history-indexed-empty`(history) | — |
| `launch/launch_screen.dart` | `launch-graduated-empty`(launchpad) | — |
| `launch/launch_trade_screen.dart` | `launch-trade-no-round`(launchpad) | — |
| `launch/launch_widgets.dart` | `<prefix>-state-empty`(launchpad) | `<prefix>-state-unavailable`、`LaunchUnavailableCard` |
| `launch2/launch2_instance_screen.dart`、`launch2_nft_screen.dart` | `launch2-invalid-identity`、`launch2-nft-invalid-identity`(launchpad) | — |
| `mining/mining_screen.dart` | `mining-composition-empty`(holders) | `mining-snapshot-unavailable` |
| `mining/mining_secondary_screens.dart` | `mining-assets-included-empty` / `-excluded-empty`(holders)、`mining-rank-none-ranked` / `-rank-empty`(rank)、`mining-rules-no-pending`(history) | `mining-assets-source-unavailable`、`mining-community-weight-pending` / `-not-applicable`、`mining-community-snapshot-unavailable` |
| `mining/referral_screen.dart` | — | `referral-claim-unavailable`、`referral-claim-closed` |
| `profile/profile_v2_screens.dart` | `profile-empty`、`privacy-empty`(profile) | — |
| `profile/security/security_screens.dart` | `security-events-empty`(history)、`devices-state-empty`(profile) | `social-recovery-no-guardians` |
| `scan/scan_screen.dart` | — | `scan-unavailable`、`scan-state-permission`、`scan-state-unsupported` |
| `security/mfa/passkey_sheet.dart` | `passkey-sheet-empty`(profile) | — |
| `social/blocklist_screen.dart` | — | `blocklist-kind-unavailable-*`、`blocklist-deferred-kinds` |
| `social/public_profile/user_profile_screen.dart` | `user-profile-invalid-target`、`user-profile-not-found`(profile) | `user-profile-unavailable`、`user-profile-*-unavailable`、`user-profile-communities-unavailable` |
| `social/public_profile_sheet.dart` | — | `public-profile-not-targetable` |
| `square/square_community_list.dart` | — | `square-community-ordering-unavailable`（+ 原按钮） |
| `system/system_surfaces.dart` | — | 全离线「无法连接到服务器」（onRetry） |

合计 107 处：`LoopEmptyState` 45、`LoopInlineUnavailable` 62（其中 onRetry 2、线 + 原按钮 5）。

**语义不明、按「内容为空」处理的**：`privy-otp-no-destination`（没有待验证的邮箱）、`chat-search-idle`（还没输入关键词）、
`voiceroom-queue-self-only`（你还没有举手）、`launch-detail-no-config` / `launch-rounds-no-config`（还没有配置版本，原 warn 字形）、
`launch-track-empty` / `launch-rounds-empty` / `launch-trade-no-round`（还没有轮次，原 warn 字形）、`launch-rounds-no-subject`、
`launch2-invalid-identity` / `launch2-nft-invalid-identity` / `user-profile-invalid-target`（无效路由，照 0172 meme 无效路由的写法）。
**反过来按「不可用」处理的**：`mining-community-weight-pending`（权重审核中）、`mining-community-weight-not-applicable`、`referral-claim-closed`（窗口已关闭）、
`dm-operator-required`（需要人工处理）、`chat-token-card-unlisted-*`（未收录，放在消息卡里，插图太大；保留 info 字形，它是答复不是失败）、`social-recovery-no-guardians`（守护人未开放）。

### 2. `LoopWideButton` 并入 `LoopButton`
- 社区档案 `_JoinBar`（在 `LoopFlat` 内）→ `LoopButton(primary, block)`：平铺页里就是 0127 的 52 高全圆角 lime 按钮；忙时 `onPressed: null`、文案「正在加入…」不变。
- 申请表单（`showLoopSheet`，不在平铺页）→ `LoopFlat(child: LoopButton(primary, block))`：只给这一个按钮套平铺作用域，得到同一外观。
- `LoopWideButton` 已无调用方，**类删除**（`widgets/loop_person_row.dart`）。

### 3. 删除的旧类
- `LoopEmpty`（`widgets/loop_components.dart`）与只测它的两例（`s16_component_polish_test` 的「one line of copy」「grows only with what it says」）；
  其余用到它的测试改用 `LoopInlineUnavailable`（`loop_components_test`、`s16b_refresh_and_page_block_test`、`s16d_tail_test`、`s16e_ground_test`、`system_connectivity_truthfulness_test`）。
- `LoopWideButton`（见 §2）；`friend_feature_test` 删掉对它的 findsNothing，`s121f_secondary_pages_test` 改读 `LoopButton.label`。
- `LoopStateCard`、`LoopPage`、`LoopSectionLabel`、`LoopStatusPill` 仍被 preview-only 聊天文件使用，**保留**。`LoopUnavailableCard` 0172 已删。

### 4. 守卫
- `FEATURE_LEGACY_WIDGET_ALLOWLIST` 从 49 条缩到 8 条（只剩 `_PREVIEW_ONLY`）；`_LEGACY_EMPTY` 常量删除；守卫 pattern 不变（仍禁 `LoopEmpty(`、`LoopWideButton` 等九种）。
- `tests/test_check_harness.py` 新增 `test_widget_allowlist_is_only_the_preview_chat_surfaces`：白名单恰为这 8 个文件且理由都是 `_PREVIEW_ONLY`。

### 5. 测试
- 新文件 `test/s192_legacy_empty_retired_test.dart`（10 例）：chain / community / launch 三个共享状态块的空态是带插图的 `LoopEmptyState`、不可用是 `LoopInlineUnavailable`；
  `emptyIllustration` 可换；能力不可达是 offline 线；`CommunityUnavailableCard` 线 + 按钮可点；`LaunchUnavailableCard`；语音房发言 / 听众两格不可用；聊天通道无重试块。
- 现有页面测试在已有 `findsOneWidget` 之后补类型断言（`find.descendant(..., matchRoot: true)` 或 `isA<>`），覆盖 account、privy OTP、转发、聊天搜索、私聊、群、
  社区聊天、语音房、社区发现 / 管理 / 档案 / 首页 / 成员（新增一例：无 id）、旧 IDO（轮次 / 已毕业 / 交易 / 主体审核 / 链上账本）、launch2 两页、挖矿（快照 / 权重 / 新增「零计入」一例）、
  邀请、安全设备、扫码、Passkey、屏蔽名单、用户资料、资料卡、广场社区列表（新增一例：排序不可用）、代币卡、转发目标弹层（新增一例：无目标）。

## Consequences

- `lib/features/` 不再有 `LoopEmpty(` 与 `LoopWideButton`；空态都是插图 `LoopEmptyState`，读不到都是 44px `LoopInlineUnavailable`。
- 可见变化（待主代理真机验收）：上述 45 处空态从左上角两行灰字变为居中 64px 插图 + 标题（上 32 下 24，段内高度约 +120px）；62 处不可用从 17px 字形条变为 15px warn 字形的 44px 线、
  字号 11 → captionSm；`LoopChainStateBlock` 未传 `empty:` 的调用方（行情、钱包、launch2、设置等）空态统一出现 history 插图；
  两处 0127 宽按钮忙态从 card2 底 text3 字变为 card2 底 40% 透明。布局与数据流不变。

### 仍保留的例外
- **v1 部件**（守卫 3 白名单，8 个文件，全部只挂 Preview 路由，docs/33 范围外）：`chat/chat_inbox_page`、`chat/chat_preview_pages`、`chat/chat_preview_route_guard`、
  `chat/chat_secondary_pages`、`chat/conversation_pages`、`chat/preview_conversation_unavailable_page`、`chat/voice_room_page`、`chat/widgets/chat_components`。
  它们用的是 `LoopPage` / `LoopStateCard` / `LoopSectionLabel` / `LoopStatusPill`（没有 `LoopEmpty`），换掉等于重画整套 preview 聊天，不在本批。
- `chain/chain_widgets.dart` **已移出**白名单（三处 `LoopEmpty` 已换，见 §1）。
- 未加类型断言的两页：`loop_id_setup_screen` 的 `loop-id-empty` 与 `profile_v2_screens` 的 `profile-empty` / `privacy-empty`——
  这几个空态只在「读之前、也没失败」时出现，现有 gateway 夹具 `load()` 总返回资源或抛错，测试里够不到（与 s8 测试矩阵说明的 `<prefix>-state-empty 不可达` 同理）。

## Verification

- `bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
  `python3 -m unittest discover -s tests -p 'test_*.py'`、全量 `bin/flutter test`（结果见提交说明）。
- 未起模拟器、未做真机验收。
