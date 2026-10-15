# 0168 · 聊天五处 v1 旧壳换成原型部件（S186-3）

## Status

Accepted 2026-10-15。基线 `integration/v2` 25a7e4c。对应 S186-audit（LOOP `docs/33-全App对照原型一致性走查-2026-10-15.md`）
§2 的 H3 / H4 / M12 / M13 / M16。只换语汇：功能、状态合同、路由表、Stream 接入、控制器与网关都不变；不新增依赖、
颜色 token、字体或路由（仍 113）。

## Context

S186-audit 列出聊天域里仍是 v1 `LoopPage` 壳的五处：群内昵称页（12 处 `LoopStateCard` + 3 处 `LoopCard` + Material
图标与按钮）、建群页（`LoopStateCard` / `LoopSectionLabel` / `LoopStatusPill` / `LoopWideButton` / 裸 `TextField`）、
收件箱的出错 / 未连接态与频道不可用页（英文 `LoopPage(eyebrow:'Discuss', title:'Chat')`，Stream 不在时最常见）、
群聊里的代币卡附件（自造 `LoopTokenCardView`，chat / warning / danger 三色和 Material 图标），以及 404 页。
它们违背 §1 家族特征五条：主视觉不是 folio、分组不是 `LoopLabel` + 行容器、自造胶囊、v1 遗留色、Material 按钮与图标。

## Decision

### 1. H3 群内昵称（`group_alias/group_alias_screen.dart`）
- 正常页 = `LoopDashboardPage(archetype: record)` + 顶部 `LoopFolioPrimary(quiet, record)`（kicker `GROUP ALIAS`，
  caption 是原来的副标题，stamp 按网关模式「开发预览 / 仅本群 / 未连接」）。预览构建的「开发预览」放在 topbar kicker。
- 边界说明 = 一条 `LoopNotice`（不可用时 warn）；分组 = `LoopLabel('我的群昵称')` / `LoopLabel('查找群成员昵称')`。
- 已保留 = `LoopRecordGroup` 一行（首字母头像、昵称、`LoopBadge` 已永久保留 / 同步中）+ `LoopNotice`；同步中再给
  「重试同步」`LoopButton(block)`。结果待确认 / 失败 / 无法设置 = `LoopNotice`（warn / danger）+ 需要时一个 `LoopButton`。
- 输入 = `LoopFlatField` + `TextField(loopFormFieldDecoration)`；提交 = `LoopButton(primary, block)`。
  查找 = 同款字段，trailing 一个「查找」`LoopButton`；结果 = `LoopRecordGroup`；空 = `LoopEmptyState(search, compact)`；
  截断 = warn `LoopNotice`；失败 = `LoopInlineUnavailable`；加载 = `LoopSkeleton`。
- 整页态（群组引用无效、群聊引用无效、功能暂未开放、解析中 / 不可用）= `LoopDashboardPage(block: LoopEmptyState(members))`，
  解析失败可重试时 action 是「重试确认」`LoopButton(primary)`。
- 返回键沿用旧壳的规则：有上一页才画（`Navigator.canPop`）。

### 2. H4 建群（`friends/friend_screens.dart` 的 `CreateFriendGroupPage`）
- 原型 flow = `LoopFocusPage(archetype: action)` + `LoopFolioPrimary(quiet, action)`（kicker「好友建群」，不用英文
  eyebrow，0127）+ 群名 `LoopFlatField` + `LoopLabel('选择好友 · n/上限')` + `LoopRecordGroup`（行 = 首字母头像 36、
  昵称、`LOOP #code`，value 列是共享的 `LoopSelectionCheck`）+ 固定在底部的 `LoopButton(primary, block)`「创建群组」
  与一行「至少选择 N 位好友」。
- 好友列表加载 = `LoopSkeleton`；失败 / 没有好友 = `LoopEmptyState(friends, compact)` + 一个次级 `LoopButton`；
  创建失败 = danger `LoopNotice` + 「查询结果」/「修改草稿」`LoopButton(block)`；未开放 = 整页 `LoopEmptyState`。
- 结果态 = `LoopLabel('结果')` + `LoopNotice` + 预览「再建一个」/ 正式「设置群昵称」+「进入群聊」（`LoopButtonPair`）。
- 只动建群页；同文件的好友列表与加好友页不在本批，`_FriendPreviewBanner` / `_FriendLoadingCard` 留给它们用。

### 3. M12 收件箱与频道不可用（`stream_chat_inbox_page.dart`）
- 收件箱「会话列表读不到」「会话还没有连接」= `LoopEmptyState(chat)` + 「重试」`LoopButton`。重试是次级按钮：
  收件箱的「发起」圆键已是这一屏唯一的满 lime。
- 频道 / 群聊不可用整页 = `LoopStreamPage(title: '聊天', block: LoopEmptyState(chat))`，恢复中的状态在 topbar 打
  「更新中」。11 处英文标题与说明改成中文（例：`Stream not connected` →「聊天服务还没有连接」）。

### 4. M13 代币卡附件（`attachments/stream_token_card_attachment_builder.dart`）
- 附件改渲染原型 `.tcard` 的 `LoopTokenCard`，两种生产态都是它的「数据缺失」形（`LoopTokenCardState.partial`，
  无操作）：
  - `LoopUnavailableTokenCard`：符号、`链 · 合约缩写`、价格位写「当前事实不可得」、脚注说明消息只存标识因此
    不显示价格 / 风险结论 / 买入 / 自选，以及引用快照的 UTC 时间。
  - `LoopMalformedTokenCard`：不读附件里任何字段，只说「这条附件不符合 LOOP token_card.v1，没有显示任何代币事实或操作」。
- 预览夹具 `TokenMessageCard`（只挂 preview 路由）改成 `LoopTokenCard(normal)`：「开发预览」徽标、价格与涨跌标
  「演示数据」、两条风险事实带来源与观察时间、三个操作全部不可点。
- 删除 `widgets/token_card_view.dart` 和 `chat.dart` 里的导出；它独有的 previewBlocked / previewStale 态没有生产用户，一并删除。
- harness 的同步渲染 import 白名单与锁定片段跟着改到新文件（`scripts/check_harness.py`，其单测 `tests/test_check_harness.py` 两例改指 builder），仍保证这条渲染路径不发请求。

### 5. M16 404（`app.dart` 的 `UnknownRouteScreen`）
- `LoopFocusPage(archetype: state, title: '页面不存在', subtitle: location, block: LoopEmptyState(chat))`，
  action =「回到聊天」`LoopButton(primary)`（`context.go(LoopRouteManifest.defaultPath)`）。只改这个类，路由表不动。

## Consequences

- 改过的五个页面里不再有 `LoopPage` / `LoopStateCard` / `LoopCard` / `LoopSectionLabel` / `LoopStatusPill` /
  `LoopWideButton` / `LoopEmpty` / Material `OutlinedButton` / `FilledButton` / `Icons.*`，也没有 `Radius.circular(字面量)`
  和 `LoopColors.warning/danger/chat/market/elevated`。
- 测试 key 全部保留（`group-alias-*`、`friend-group-*`、`friend-select-result-*`、`stream-chat-unavailable`、
  `stream-chat-channel-unavailable`、`token-card-unavailable` / `token-card-malformed`），新增 key：
  `group-alias-route-invalid`、`group-alias-boundary`、`stream-chat-list-error` / `-retry`、`stream-chat-unavailable-retry`、
  `token-card-preview`、`unknown-route-state` / `-home`。
- 频道不可用页的锁定文案由英文 `No existing Stream channel membership was confirmed` 改为中文
  「没有确认到你在这个频道里的成员身份」（harness 同步改）。
- 同文件的好友列表页、加好友页仍是旧壳，留给后续批次。

## 测试

- `test/stream_token_card_attachment_builder_test.dart`：有效引用渲染 `LoopTokenCard(partial)`、无操作、无 Material 按钮与
  `Icon`、中文说明与快照时间；畸形附件不显示任何附带字段；预览夹具是 `LoopTokenCard`、「开发预览」「演示数据」可见、
  三个操作 `onTap == null`；删掉只测旧 preview 态的一例。
- `test/social_ui_safety_edges_test.dart`：群内昵称页是 `LoopDashboardPage` + quiet folio + 两个 `LoopFlatField` + `LoopButton`，
  且没有任何旧壳 / Material 按钮 / `ListTile` / `Icon`；群组引用无效是 `LoopEmptyState`；搜索结果行是 `LoopRecordRow`。
- `test/group_alias_resolver_test.dart`：重试键是 `LoopButton`，整页态是 `LoopEmptyState`。
- `test/friend_feature_test.dart`：建群页是 `LoopFocusPage` + quiet folio + `LoopRecordGroup` + `LoopSelectionCheck` +
  `LoopFlatField` + `LoopButton(primary, block)`，没有旧壳与 Material 部件；`LoopWideButton` 断言改为 `LoopButton`。
- `test/stream_chat_inbox_page_test.dart`：未连接态是 `LoopEmptyState`、重试是 `LoopButton`；频道不可用页是 `LoopStreamPage`
  「聊天」+ 中文标题，无 `Chat` / `Discuss` 英文。
- `test/app_navigation_test.dart`：404 页是 `LoopFocusPage` + `LoopEmptyState`，「回到聊天」回到 `/chat`。
- `test/loop_theme_test.dart`：legacy 色消费者名单去掉 `token_card_view.dart`。
