# S276 · 全 App 输入框收键盘审计（决策 0234）

基线 `integration/v2` 5f7ec3dc。范围：`lib/features/**` 与 `lib/widgets/**` 里的每个 `TextField`（无 `TextFormField` / 自建 `EditableText` / `CupertinoTextField`），加上 Stream 的 `StreamMessageComposer`（SDK 内部的 TextField，经 `loop_chat_image_composer.dart` 的组件构建器挂进来）。

收起路径：

- **点外面**：`LoopKeyboardScope`（`app.dart` 的 `MaterialApp.builder`，在根 Navigator 之上）覆盖 `EditableTextTapOutsideIntent`，任何焦点输入框在它的 tap region 外按下即失焦。对全部字段生效，包括底部弹层与对话框里的字段。字段自身、装饰里的前后缀（MAX）、文本选择菜单、`LoopKeepsKeyboard` 包住的控件不算「外面」。
- **拖动**：`LoopScrollBehavior.getKeyboardDismissBehavior` = `onDrag`，所有没自己指定的 `ScrollView` / `SingleChildScrollView`（含 `LoopFocusPage` / `LoopDashboardPage` / `LoopStreamPage` / `LoopSegmentedTabPage` 的滚动区、`NestedScrollView` 内外层、弹层里的滚动）拖动即收起；拖动的是哪个滚动区都会清掉当前焦点。Stream 消息列表显式传 `manual`，保持 Stream 自己的行为。
- **完成条**：iOS 上数字 / 小数 / 电话键盘（没有回车键）弹起时，`LoopKeyboardScope` 在键盘上沿画 `LoopKeyboardDoneBar`。0091 的 `LoopFocusPage(keyboardAccessory: true)` 页自己画完成条（对所有键盘类型），全局条在这些页让位，不会出现两条。
- **键盘键**：单行文本框的回车键（done / search / next / send，单行默认即 done）；多行框回车是换行，不收起；Android 数字键盘自带完成键（数字框均设 `textInputAction: done`）。

| # | 文件:行 | 页面 / 位置 | key | 键盘 | 点外面 | 拖动 | 完成条（iOS） | 键盘键 |
|---|---|---|---|---|---|---|---|---|
| 1 | account/privy_login_screen.dart:176 | 登录 · 邮箱 | privy-email-field | emailAddress | 是 | 是 | — | done |
| 2 | account/privy_otp_screen.dart:288 | 登录 · 邮箱验证码（透明全幅框） | privy-otp-field | number | 是 | 是 | 全局条 | done（Android） |
| 3 | account/loop_id_setup_screen.dart:166 | 设置 LOOP ID · 别名 | loop-id-alias-field | text | 是 | 是 | — | done |
| 4 | account/loop_id_setup_screen.dart:199 | 设置 LOOP ID · 简介（3 行） | loop-id-bio-field | multiline | 是 | 是 | — | 换行 |
| 5 | chat/chat_secondary_pages.dart:573 | 消息搜索（预览面） | — | text | 是 | 是 | — | search |
| 6 | chat/friends/friend_screens.dart:139 | 建群 · 群名（0091 页） | friend-group-name-input | text | 是 | 是 | 页面条 | next |
| 7 | chat/group_alias/group_alias_screen.dart:389 | 群别名 · 输入 | group-alias-input | text | 是 | 是 | — | done |
| 8 | chat/group_alias/group_alias_screen.dart:491 | 群别名 · 搜索成员 | group-alias-search-input | text | 是 | 是 | — | search |
| 9 | chat/v2/chat_search_screen.dart:379 | 聊天搜索（顶栏） | chat-search-input | text | 是 | 是（拖结果列表） | — | search |
| 10 | chat/v2/group_screens.dart:559 | 群设置 · 改群名 | group-rename-field | text | 是 | 是 | — | done |
| 11 | chat/v2/voice_room_stage.dart:1128 | 语音房 · 开房标题 | voiceroom-start-title | text | 是 | 是 | — | done |
| 12 | chat/widgets/chat_components.dart:1015 | 预览会话 composer（发送键保焦点） | — | multiline | 是 | 是（会话列表 onDrag） | — | 换行 |
| 13 | community/community_members_screen.dart:194 | 社区成员 · 搜索 | community-members-search-field | text | 是 | 是 | — | search |
| 14 | community/community_widgets.dart:1441 | 编辑社区 · 名称 | community-edit-name | text | 是 | 是 | — | done |
| 15 | community/community_widgets.dart:1447 | 编辑社区 · 简介（3 行） | community-edit-description | multiline | 是 | 是 | — | 换行 |
| 16 | community/community_widgets.dart:1455 | 编辑社区 · 绑定资产 | community-edit-bound-asset | text | 是 | 是 | — | done |
| 17 | community/community_widgets.dart:1677 | 申请社区 · 名称 | community-apply-name | text | 是 | 是 | — | done |
| 18 | community/community_widgets.dart:1687 | 申请社区 · slug | community-apply-slug | text | 是 | 是 | — | done |
| 19 | community/community_widgets.dart:1696 | 申请社区 · 简介（2 行） | community-apply-description | multiline | 是 | 是 | — | 换行 |
| 20 | community/community_widgets.dart:1707 | 申请社区 · 资产键 | community-apply-asset-key | text | 是 | 是 | — | done |
| 21 | community/search_screen.dart:609 | 全局搜索 | search-field | text | 是 | 是（结果列表 onDrag） | — | search |
| 22–28 | launch/launch_action_screens.dart:1191–1249 | Launch 申请 · 名称 / 代码 / 叙事（4 行）/ 官网 / X / Telegram / Discord | launch-apply-* | text（叙事 multiline） | 是 | 是 | — | done（叙事换行） |
| 29 | launch/launch_trade_screen.dart:822 | launch-trade · 金额（0091 页） | launch-trade-amount | decimal | 是 | 是 | 页面条 | done |
| 30 | launch2/creator/launch2_create_screen.dart:674 | 创建项目 · 各字段（`_field`，0091 页） | launch2-create-* | text / url | 是 | 是 | 页面条 | done / 换行 |
| 31 | launch2/launch2_pool_trade_panel.dart:470 | MEME 代币页 · 官方池金额 | launch2-pool-amount | decimal | 是 | 是 | 全局条 | done |
| 32 | launch2/launch2_pool_trade_panel.dart:597 | MEME 代币页 · 官方池自定义滑点 | launch2-pool-slippage-custom-input | decimal | 是 | 是 | 全局条 | done（本单新增） |
| 33 | launch2/launch2_trade_panel.dart:456 | MEME 代币页 · 内盘金额（需求方 bug） | launch2-trade-amount | decimal | 是 | 是 | 全局条 | done |
| 34 | market/alerts/alerts_screen.dart:697 | 价格提醒弹层 · 阈值 | alert-threshold-field | decimal | 是 | 是 | 全局条 | done（本单新增） |
| 35 | market/watchlist/watchlist_editor_screen.dart:477 | 自选分组 · 名称 | watchlist-group-name-field | text | 是 | 是 | — | done |
| 36–38 | meme/meme_create_screen.dart:620/631/644 | 经典 MEME 创建 · 名称 / 代码 / 简介（0091 页） | meme-create-* | text（简介 multiline） | 是 | 是 | 页面条 | done / 换行 |
| 39–41 | meme/meme_create_screen.dart:723/734/745 | 经典 MEME 创建 · X / Telegram / 官网 | meme-create-* | url | 是 | 是 | 页面条 | done |
| 42 | meme/meme_create_screen.dart:890 | 经典 MEME 创建 · 首购 | meme-create-first-buy | decimal | 是 | 是 | 页面条 | done |
| 43 | meme/meme_trade_panel.dart:344 | 经典 MEME 交易弹层 · 金额 | meme-trade-amount | decimal | 是 | 是 | 全局条 | done |
| 44 | meme/meme_trade_panel.dart:451 | 经典 MEME 交易弹层 · 自定义滑点 | meme-trade-slippage-custom-input | decimal | 是 | 是 | 全局条 | done（本单新增） |
| 45 | mining/referral_screen.dart:1328 | 邀请 · 填写邀请码 | referral-claim-input | text | 是 | 是 | — | done |
| 46 | profile/profile_v2_screens.dart:2076 | 编辑资料 · 别名 | profile-edit-alias-field | text | 是 | 是 | — | done |
| 47 | profile/profile_v2_screens.dart:2095 | 编辑资料 · 简介（4 行） | profile-edit-bio-field | multiline | 是 | 是 | — | 换行 |
| 48 | profile/support/support_screen.dart:192 | 帮助与反馈 · 内容 | support-body-field | text | 是 | 是 | — | done |
| 49 | security/mfa/mfa_sheet.dart:187 | 二次验证弹层 · 6 位码 | mfa-sheet-code | number | 是 | 是 | 全局条 | done（本单新增） |
| 50 | security/step_up/step_up_widgets.dart:417 | 大额验证金额弹层（预设胶囊保焦点） | step-up-threshold-field | number | 是 | 是 | 全局条 | done（本单新增） |
| 51 | square/square_feed_view.dart:1242 | 发帖弹层 · 搜索代币 | square-composer-token-search-field | text | 是 | 是 | — | search |
| 52 | square/square_feed_view.dart:1283 | 发帖弹层 · 内容（4–8 行） | square-composer-field | multiline | 是 | 是 | — | 换行 |
| 53 | wallet/approval_screens.dart:208 | approval-guard · 限额（0091 页） | approval-guard-amount | decimal | 是 | 是 | 页面条 | done |
| 54 | wallet/money_asset_picker.dart:139 | 选资产弹层 · 搜索 | *-search | text | 是 | 是 | — | search |
| 55 | wallet/send_screens.dart:564 | 转账 · 收款地址 | send-recipient-field | visiblePassword | 是 | 是 | — | done |
| 56 | wallet/send_screens.dart:818 | 转账 · 金额（0091 页） | send-amount-field | decimal | 是 | 是 | 页面条 | done |
| 57 | wallet/swap_screens.dart:627 | 兑换 · 金额（0091 页） | *-amount | decimal | 是 | 是 | 页面条 | done |
| 58 | widgets/loop_blocks.dart:814 | 共享搜索块（`LoopSearchBlock`） | 调用方给 | url | 是 | 是 | — | done |
| 59 | widgets/loop_components.dart:2977 | 共享 `LoopComposer`（发送键保焦点） | loop-composer-input | multiline | 是 | 是（所在页可拖时） | — | send |
| S | integrations/communication/loop_chat_image_composer.dart | Stream 会话 / 群 / 线程 composer（整条保焦点） | loop-stream-message-composer | multiline | 是 | 否（Stream 列表保持 manual） | — | 换行 |

注：表中把同一函数产出的同型字段合并成一行（22–28、30、36–38、39–41），实际字段数 59 + Stream composer 1 = 60。

## 汇总

| 收起路径 | 字段数 |
|---|---|
| 点外面 | 60 / 60 |
| 拖动（所在页或弹层有可拖滚动区） | 59 / 60（Stream composer 除外，Stream 列表保持自身行为；点外面仍生效） |
| 完成条 · 全局（`LoopKeyboardScope`，iOS 数字 / 电话键盘） | 9：privy-otp、launch2-pool-amount、launch2-pool-slippage-custom、launch2-trade-amount、alert-threshold、meme-trade-amount、meme-trade-slippage-custom、mfa-sheet-code、step-up-threshold |
| 完成条 · 页面自带（0091 `LoopFocusPage.keyboardAccessory`，iOS 任意键盘） | 7 个页面：launch-trade、send-to、swap、approval-guard、建群、经典 MEME 创建、创建项目（全局条在这些页让位） |
| 键盘自带收起键（单行 done / search / next / send） | iOS 37（= 59 − 14 个数字框 − 8 个多行换行框）；Android 再加 14 个数字框（done）。多行框回车为换行，靠点外面 / 拖动 / 页面条收起 |

本单新增 `textInputAction: TextInputAction.done`：launch2-pool-slippage-custom-input、alert-threshold-field、meme-trade-slippage-custom-input、mfa-sheet-code、step-up-threshold-field（Android 数字键盘的完成键）。

本单新增 `LoopKeepsKeyboard`（点它不算「外面」）：Stream composer 整条、`LoopComposer` 整条、预览 `ChatComposer` 整行、内盘「买入 / 卖出」切换与报价行「填入上限」、官方池「付 / 得」模式切换、经典 MEME 交易「买入 / 卖出」切换、大额验证预设胶囊、完成条本身。MAX 在输入框装饰的后缀里，本来就在字段的 tap region 内。
