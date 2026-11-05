# 0295 · 钱包 / 情报 / 挖矿 / 设置二级页按 docs/58 §9 通用规则扫一遍

## Status

Accepted · 2026-11-05（S370c-mobile）。来源：用户 11-05 裁决「二级页按稿规则扫一遍、不等需求方出稿，放 TF 69」。规范 `docs/58` §9（主代理裁决）为准，§1–§5 作细节参考；度量语言沿用底座 0277 与九页对齐 0278 / 0279 / 0280。只改视觉度量：不重排、不增删功能、不改文案 / ARB、不改路由与 key、不改 `lib/widgets/` 与 `lib/app/` 共享件。

## Context

需求方稿只画了九页，本批负责的二级页（接收 / 发送 / 兑换 / 授权 / 结果、交易历史与资产读页、测试币、资产详情、价格提醒、自选管理、算力二级页、邀请中心、挖矿奖励、开户与登录、安全 / 设置 / 支持 / 资料编辑 / 隐私、通知中心、扫码、DApp、内测反馈、链状态块、壳层占位页）没有稿，按 §9 通用规则套。

先盘点：这些页面绝大部分已由共享件拼成（`LoopRecordGroup` / `LoopRecordRow` 扁平行 56、`LoopLabel` 20 页边、`LoopSurfaceCard` / `LoopRecordCard` 20 页边 + 16 卡内、`LoopEmptyState` 皇冠 + 17 / 700、`LoopButton` 48 r8），0277 已让它们吃到稿的字体 / 色 / 圆角。页面层残留的偏差集中在四类：

1. **页边距 16**：约 90 处本地 `EdgeInsets.fromLTRB(16, …, 16, …)` / `symmetric(horizontal: 16)` 包在卡片、按钮、说明行、表单外，而同页的 `LoopLabel`、`LoopRecordGroup`、`LoopSheetHeading` 都在 20——同一页左边线差 4px。
2. **自画行**：通知行 68 高无分割线；资产详情成交行 52；自选管理编辑行 44 起、内边距 11、币标 32；「我的」持仓列表里的 Launch 链 tBNB / USD1 两行仍是 `LoopQuoteRow` 默认 80 高（S353c 把同列表的 `WalletBalanceRow` 改成了 51，这两行漏了）。
3. **圆角**：兑换「选择资产 ›」键 r12（`control`）；意见反馈图片格与添加格、我的反馈缩略图 r10（`tile`）。
4. **按钮 / 字**：登录页方式按钮 52 高、16 / 700；挖矿奖励邀请表头 `kicker.copyWith(fontSize: 12)` 字面量。

## 页面对照表

| 页面 / 部件 | 文件 | 现状 | 稿值 / 规则 | 改后 | 依据 |
| --- | --- | --- | --- | --- | --- |
| 发送 · NFT 复核、确认页事实卡、到账卡 | `send_screens.dart` | 外边距 16 | 页边距 20 | `LoopSpacing.page` | §9.4 |
| 兑换 · 价格影响勾选、报价卡、路线金额 / 费用卡 | `swap_screens.dart` | 外边距 16 | 20 | `LoopSpacing.page` | §9.4 |
| 兑换 · 「选择资产 ›」键 | `swap_screens.dart` `SwapAssetPickButton` | r12 `control`，48 高 | 按钮 r8 | `LoopRadius.button`（8），高度不变 | §9.4 按钮 |
| 授权 · 请求卡、风险卡、解码调用卡、两个底部抽屉内容 | `approval_screens.dart` | 外边距 16 | 20（抽屉标题 `LoopSheetHeading` 已是 20） | `LoopSpacing.page` | §9.4 |
| 交易结果 · 回执卡 | `tx_result_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 资产选择抽屉 · 搜索框外边距 | `money_asset_picker.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 资金动作复核卡 | `money_actions_widgets.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 接收 · 地址行、按钮对、测试币按钮；钱包来源脚注；交易历史筛选条（非筛选态） | `wallet_read_screens.dart` | 16 | 20；接收白卡内边距 16 保持（卡内） | `LoopSpacing.page`；白卡内边距改写成 `LoopSpacing.card` | §9.4 |
| 净值紧凑条、加载骨架 | `wallet_read_widgets.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 我的 · Launch 链 tBNB / USD1 持仓行 | `wallet_read_widgets.dart` `walletLaunchNativeRow` / `walletLaunchUsd1Row` | `LoopQuoteRow` 80 高、值 `figure` 16、币标 36 字面量 | 持仓行 51、值 `figureSm`、副值 `caption` 次字、头像 36 | `height: LoopRowHeight.holdings`、`valueStyle: LoopType.figureSm`、副值 `walletHoldingCaption`、币标 `LoopRowHeight.holdingsAvatar`（与 0280 他人主页同参） | §5.13 / 0280 |
| 测试币抽屉 | `testnet_faucet_sheet.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 跨链（不可用页）按钮 | `deferred_screens.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 资产详情 · 成交行 | `market/token_screen.dart` `TokenTradeRow` | 52 高、底线白 5% | 类推持仓行 51；成交是逐行读的流水，线保留 | `TokenTradeRow.height = LoopRowHeight.holdings`（51） | **类推** |
| 价格提醒 · 「显示全部资产」按钮 | `alerts_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 自选管理 · 分组条 | `watchlist_editor_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 自选管理 · 编辑行 | 同上 | 最小 44、内边距 12 / 11、币标 32 | 类推持仓行：51、上下 6、头像 36；卡内 16 | `minHeight: LoopRowHeight.holdings`、`fromLTRB(card, 6, card, 6)`、币标 `holdingsAvatar` | **类推** |
| 算力二级页 · 社区算力脚注 | `mining_secondary_screens.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 邀请中心 · 绑定说明抽屉 | `referral_screen.dart` | 16 | 20 | `LoopSpacing.page`；邀请码卡（0279 已对齐）不动 | §9.4 |
| 挖矿奖励 · 领取 gas 抽屉、追踪占位行 | `mining_rewards_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 挖矿奖励 · 邀请表头 | 同上 | `kicker.copyWith(fontSize: 12)`（12 / 500 次字） | `meta` 12 / 500 | `LoopType.meta` 次字（视觉不变，去掉字面量） | §9.2 |
| 开户 · 钱包恢复骨架、生物识别回退说明；Loop ID 设置五处；推荐社区四处；登录页头部 | `account_screens.dart` `loop_id_setup_screen.dart` `onboarding_communities.dart` `privy_login_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 登录 · 方式按钮 | `privy_login_screen.dart` `AuthMethodButton` | 52 高、`bodyLg` 16 / 700 | 全宽 CTA 48 r8 16 / 600 | `LoopTouch.primaryButton`（48）、`LoopType.button` | §9.4 按钮 |
| Passkey / MFA 抽屉、应用锁提示、大额验证门槛抽屉 | `security/**` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 系统面 · 网络横幅、反馈块、错误重试、样张页 | `system_surfaces.dart` | 16 | 20 | `LoopSpacing.page`（网络横幅左 20，右 8 留给关闭键） | §9.4，横幅**类推** |
| 设置 · 固定值说明；设备「全部下线」；退出登录按钮默认边距 | `settings_screen.dart` `security_screens.dart` `sign_out_button.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 支持 · 提交按钮、工单详情三处 | `support_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 资料编辑 · 头像编辑器两处、资料 / 隐私加载骨架、可见性脚注、头像选择器 | `avatar_editor.dart` `profile_v2_screens.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 通知中心 · 通知行 | `notification_inbox_screen.dart` `_NotificationRow` | 最小 68、无分割线 | 类推会话行 67 + 1px 白 5% 线（跨内容宽 20…宽−20） | `notificationRowHeight = LoopRowHeight.chat`（66 + 1 线）、`notificationRowDividerKey` | **类推** §9.4 |
| 扫码 · 未识别内容卡 | `scan_screen.dart` | 16 | 20 | `LoopSpacing.page` | §9.4 |
| 链状态块默认边距 | `chain/chain_widgets.dart` `LoopUnavailableLine`（两个构造）、`LoopProvenanceFooter`、`LoopFootnote`、`LoopTestnetNotice` | 默认 16 | 20 | 默认改 `LoopSpacing.page`（来源脚注右 12 留给 ⓘ 不变） | §9.4 |
| 意见反馈 · 图片格、添加格；我的反馈缩略图 | `beta_feedback_screen.dart` `beta_feedback_mine_screen.dart` | r10 `tile` | 卡 r12 | `LoopRadius.card` | **类推**（图片格按卡） |
| 壳层占位页 · 说明卡 | `shell/loop_pending_surface.dart` | 内边距 18 | 卡内 16 | `LoopSpacing.card` | **类推** |

保持不动（核对过、已符合或不属本条规则）：`LoopDisclosure` 内的 14 内边距（与共享件摘要行同值）；接收页网络胶囊（r8 已合规）；行情图表内部圆角（K 线 / 轴标签 / 气泡，图形不是控件）；邀请海报（导出图片）；扫码相机层控件；底部抽屉标题 `LoopType.heading` 22（与共享 `LoopSheetHeading` 同值，要改得一起改共享件）；价格提醒 / 邀请列表 36 头像（已是持仓 / 榜单头像）。

## Decision

- 上表全部落地。页边距统一 `LoopSpacing.page`（20），卡内统一 `LoopSpacing.card`（16）；行高 / 头像只用 `LoopRowHeight` token；按钮高度 `LoopTouch.primaryButton`；无新字面量。
- 类推规则：通知行 → 会话行（67 + 线）；成交行、自选编辑行 → 持仓行（51 / 36）；反馈图片格、占位说明卡 → 卡（r12 / 16）；网络横幅 → 页边距。
- `chain/chain_widgets.dart` 在本批目录内，几个状态块默认边距改 20 后，其他页（含 S370a / b 范围）里用默认值的地方同样左移到 20，方向与 §9.4 一致。

### 需要改共享件（留给主代理派单，本批未动）

1. `LoopNotice` 默认 `margin` 是 `fromLTRB(16, 0, 16, 14)`（`loop_components.dart` 两个构造），本批范围内约 125 处调用用默认值。扁平页里的普通提示已走 `LoopSpacing.page`，**警示 / 危险卡仍在 16**，与本批改到 20 的卡片差 4px。建议默认改 `LoopSpacing.page`。
2. 同类默认 16 的共享件：`LoopSegBar.padding`、`LoopErrorState` / `LoopOfflineState` / `LoopPermissionState` 的 `margin`、`LoopPowerHint`、`LoopLoadMoreFooter.padding`、`LoopProvenanceLine`、`LoopInfoSheet` 内容、`loop_provenance_scope.dart` 四处、`loop_sign_steps.dart`、`loop_atmosphere.dart` 两处、`LoopButtonPair` 抽屉底栏（16, 10, 16）。
3. `LoopRecordGroup._rowsColumn` 重建行时没有复制 `divider`，组内功能行画不出 §9.4 的「功能行每行 1px 白 5%」。本批范围约 85 处 `LoopRecordGroup`（设置、安全、关于、支持、接收、资产页等）都是功能行；建议共享件补上 `divider` 透传，并决定组内是否默认开。
4. 底部抽屉标题 `LoopSheetHeading` 用 `LoopType.heading`（22 / 700，稿无此档），本批抽屉内的自画标题（Passkey、MFA、DApp 连接 / 签名 / 风险）跟它一致没改；若要按区块标题 19 / 700，应先改共享件再统一。
5. `features/launch2/launch2_wallet_rows.dart`（不在本批目录）里 MEME v2 持仓行仍是 `LoopQuoteRow` 默认 80 高，与「我的」持仓列表其余 51 行不齐，同 0280 处理（`height: LoopRowHeight.holdings`、`valueStyle: figureSm`）即可。

## Consequences

- 改动只在 `lib/features/**` 本批目录；`lib/widgets/`、`lib/app/`、`loop_theme.dart` 未动；view model / gateway / codec / 路由 / key / ARB 未动；lockfile 未变。
- 新增两个公开常量：`notificationRowHeight`、`notificationRowDividerKey`（`notification_inbox_screen.dart`）、`TokenTradeRow.height`、`walletHoldingCaption`（`wallet_read_widgets.dart`）。
- 依赖共享件默认值的地方（上节 1、2）在共享件改之前仍是 16。

## Tests

- 新增 `test/s370c_secondary_spec_test.dart`：本批 34 个文件不再出现 16 页边（源码守卫）；链状态块与退出登录按钮默认 20；意见反馈不再用 `tile`；兑换资产键 r8；登录方式按钮 48 高 16 / 600；通知行 67 + 1px 线落在 20…370；成交行 51；Launch USD1 持仓行 51 + 头像 36；自选编辑行 ≥51 + 币标 36。
- `dart format` 0 改动、`flutter analyze` 0、`merge.py --check` 0；全量 `flutter test` 结果见提交说明。
