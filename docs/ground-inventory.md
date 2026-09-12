# 底色清单与深色专用色 token

适用范围：`lib/` 里任何绘制颜色的代码 —— 填充、描边、文字、图标、CustomPainter。

问题的形状：`LoopColors` 里所有柔和 token（`bg2` / `panel` / `card` / `card2` /
`line` / `line2` / `text2` / `text3`）都是同一个米白（Chalk `#F3F5EF`）把 alpha
调低。它们是为 Ink 深色页设计的。画在米白卡或柠檬绿卡上就是米白画米白：控件照样
布局、照样占 200px，只是什么都没有。**代码里看不出来，只渲染深色页的测试也看不
出来，只有真机上表现为「东西不见了」。**

守卫有三条：

1. `scripts/check_harness.py` 的 `check_light_ground_contract`（用例在
   `tests/test_check_harness.py`）—— 静态，看浅色容器的参数里字面写了什么。
2. `test/s16e_ground_test.dart` —— 十一个共用组件 × 三种底的目录式渲染。
3. **武装探针**（S16f）。`test/support/loop_ground_probe.dart` 里的
   `loopArmGroundProbe` 由六个页面 harness 在 `pumpWidget` 之前调用，
   `loopWatchGround()` 由自己挂载页面的测试文件在 `main` 里调用。它挂一个
   persistent frame callback，**逐帧**走整棵已挂载的树，把每一笔颜色和它落下去的
   那个底配成一对判一次；判错的在 tear-down 里一次报出来。
   `check_harness.py` 的 `check_ground_probe_armed` 强制第 3 条：`test/support/`
   下任何名字形如 `pump*` 且函数体里出现 `tester.pumpWidget(` 的函数，必须在同一个
   函数体里调用 `loopArmGroundProbe(`，否则守卫失败。新写的页面测试走 harness，
   于是不用记得 opt-in 就已经被看着。

本文件记录三条守卫合起来仍然覆盖不到的部分。

## 1. 底色清单

| 底 | 颜色 | 谁画的 | 是否声明自己的底 |
| --- | --- | --- | --- |
| Ink 页面 | `#050604` | `LoopTheme.dark` 的 `scaffoldBackgroundColor` | 是（`ThemeData`） |
| Chalk 卡 | `#F3F5EF` | `LoopChalkCard` | 是 |
| Lime 卡 | `#B8FF20` | `LoopLedgerCard`（非 quiet） | 是 |
| Quiet 卡 | Lime 7.5% 叠在 Ink 上，实为深色 | `LoopLedgerCard(quiet: true)` | 是 |
| Lime folio | `#B8FF20` | `LoopFolioPrimary(variant: lime)` | 是（S16e 起） |
| Chalk folio | `#F3F5EF` | `LoopFolioPrimary(variant: chalk)` | 是（S16e 起） |
| Quiet folio | Lime 7.5% 叠在 Ink 上，实为深色 | `LoopFolioPrimary(variant: quiet)` | 是（S16e 起） |
| Chalk Token Card | `#F3F5EF` | `LoopTokenCard(chalk: true)` | 是（S16e 起） |
| 底部 Tab 栏 | `#F3F5EF`，选中格是 `#C6FF45 → #B8FF20` 渐变 | `LoopTabBar` / `LoopTabItem` | 否，但自己画完每一格，不接收外来 widget |
| Toast | `#F3F5EF` | `LoopToastView` | 否，同上 |
| 主按钮 | `#C6FF45 → #B8FF20` 渐变 | `LoopButton(primary: true)` | 否，同上 |
| 选中的 seg | `#B8FF20` | `LoopSeg(selected: true)` | 否，同上 |
| 下拉刷新指示器 | `#F3F5EF` 底 + Ink 弧 | `loopRefreshable` | 否，同上 |
| 收款二维码 | `#F3F5EF` 底 + Ink 模块 | `_QrPainter` | 否，同上 |
| Sheet | Ink + Lime 微光，深色 | `LoopSheet` | —— |

「声明自己的底」= 用 `DefaultTextStyle` + `IconTheme` 把该底的 ink 交给子树。
`LoopGround.*` 全部从这两者推导，所以**一个画浅色底却不声明的容器，会让每一个
`LoopGround` 派生出来的颜色都悄悄算错**。`check_light_ground_contract` 拦这件事：
注册在 `LIGHT_GROUND_CONTAINERS` 里的容器必须声明；任何画不透明 Chalk/Lime 填充
又持有 `Widget` 槽位的类必须注册。

## 2. 浅色底上的危险 token

| token | 实际颜色 | 落到浅色底上的后果 |
| --- | --- | --- |
| `LoopColors.chalk` | `#F3F5EF` | 米白底上完全消失 |
| `LoopColors.card2` | Chalk 10% | 填充消失（头像兜底、骨架块、索引方块） |
| `LoopColors.card` | Chalk 6% | 同上，更轻 |
| `LoopColors.panel` / `bg2` | Chalk 5.5% / 2.5% | 同上 |
| `LoopColors.line` / `line2` | Chalk 13% / 22% | 分隔线、网格线、控件描边消失 |
| `LoopColors.text2` / `text3` | Chalk 68% / 58% | 副文案与辅助文案不可读 |
| `LoopColors.textSecondary` / `textTertiary` | 同上（别名） | 同上 |
| `LoopDepth.liftPrimaryEdge` / `liftCardEdge` / `innerEdge` | Chalk 10% / 5.5% / 4% | 顶部高光边消失 |
| `LoopTypography.*` 的默认 `color` | `chalk` 或 `text3` | **不写 `color:` 就是危险默认值** |
| `LoopType.*` / `LoopMono.*` / `theme.textTheme.*` | 全部内嵌 Chalk 系颜色 | 同上；`DefaultTextStyle` 救不了显式颜色 |

对应的派生写法在 `LoopGround`：`inkOf` / `fillOf`(card2) / `tintOf`(card) /
`hairlineOf`(line) / `edgeOf`(line2) / `secondaryOf`(text2) /
`auxiliaryOf`(text3)。每个权重都从它替代的 token 上读 alpha，所以 **Ink 页上逐字
节不变**。

## 3. 探针现在覆盖到哪里（S16f 扩面结论）

摸底数字，`test/` 顶层 175 个测试文件里：

| | 数量 | 说明 |
| --- | --- | --- |
| 挂载了页面级 widget 的文件 | 76 | 其余只挂卡片/按钮/图表等组件 |
| 经共用 harness 挂载（自动武装） | 42 | 六个 harness 的 7 个 `pump*` 函数全部调 `loopArmGroundProbe` |
| 自己 `pumpWidget` 挂载页面 | 37 | 其中 15 个已加 `loopWatchGround()` |
| **仍未被看着的自挂载页面文件** | **22** | 见下方盲区 |

93 条路由的落地 widget 类，**93 个都至少被一个测试渲染过**（按类计，不按路由计：
`voiceroom` / `voiceroom-full` 共用 `VoiceRoomScreen`，Preview/线上分支的
`GroupChatPage` vs `GroupChatScreen` 只覆盖了一侧）。武装探针跑在其中经 harness
挂载的那 42 个文件上，加上 15 个自挂载文件，所以「渲染过的页面」与「被探针看着的
页面」之间的差就是下面这 22 个文件。

已加 `loopWatchGround()` 的 15 个文件：`account_auth_catalog_truthfulness_test`、
`friend_feature_test`、`identity_pages_test`、`loop_id_setup_screen_test`、
`perp_account_screen_test`、`perp_positions_screen_test`、
`privacy_presentation_screen_test`、`privy_login_screen_test`、
`privy_otp_screen_test`、`profile_presentation_screen_test`、
`profile_v2_pages_test`、`s11_cold_start_resilience_test`、`s16c_recovery_test`、
`social_privacy_presentation_screen_test`、`v2_ui_foundation_test`。

## 4. 三条守卫覆盖不到的部分（人工检查项）

静态守卫只看「浅色容器的参数里**字面**写了危险 token」；探针只看「测试真的渲染过的
那一帧」。以下几类必须评审时人看：

- [x] ~~**间接传入的 widget**~~。武装探针从根上解决了这一类：它不看代码怎么传，
      只看渲染出来的那一帧里这笔颜色落在哪个底上。仍然受限于「测试渲染过」——
      一个从没被渲染过的分支照样看不见。
- [x] ~~**`LoopTypography.*` 不写 `color:`**~~。同上，凡是渲染过的都会被按
      落地底判一次对比度。
- [ ] **`CustomPainter`**。`_QrPainter`、`LoopLedgerTexturePainter`、图表画笔
      都在 `paint()` 里取色，不经过 widget 树，探针看不到。**仍然是盲区。**
- [x] ~~**Lime 强调色落在 Lime 或 Chalk 底上**~~。原来的理由（「探针的下限会把
      Ink 页上合法的 Lime 强调一起判错」）经实测不成立：Lime 在 Ink 上的对比度约
      16，离 2.5 的下限远得很；只有落在 Lime 或 Chalk 底上才会掉到下限以下，而那
      正是要拦的。扩面之后整轮跑下来**没有报出一处**，说明现有调用点是干净的。
- [ ] **`lib/integrations/communication/stream_chat_appearance.dart`**。Stream 的
      主题对象由 SDK 消费，不是 LOOP 的 widget 树，三条守卫都不覆盖。它目前只服务
      深色聊天页。**仍然是盲区。**
- [ ] **动态底色**。任何由运行时值决定 `variant` / `chalk` 的调用点，守卫按「可能
      是浅色」处理；探针只覆盖它实际渲染过的分支。**仍然是盲区，但比原来小**：
      扩面后被渲染过的分支多了一个数量级。
- [ ] **22 个自己挂载页面、尚未调 `loopWatchGround()` 的测试文件**。守卫只强制
      `test/support/` 下的 harness，管不到自挂载的文件。其中 13 个直接挂
      `const LoopApp()`（`app_navigation_test`、`app_auth_gate_test`、
      `route_manifest_test`、`v2_primary_navigation_test`、
      `post_auth_login_bootstrap_test`、`development_preview_experience_test`、
      `local_settings_and_help_test`、`loop_v2_meta_providers_test`、
      `app_notification_coordinator_test`、`chat_preview_conversation_identity_test`、
      `chat_preview_route_guard_test`、`stream_chat_providers_test`、
      `security_capability_truthfulness_test`），9 个直接挂页面
      （`chat_preview_message_requests_test`、`chat_spot_snapshot_test`、
      `friend_request_feature_test`、`group_alias_resolver_test`、
      `s8_chat_profile_state_pages_test`、`s8_community_system_state_pages_test`、
      `social_ui_safety_edges_test`、`stream_chat_inbox_page_test`、
      `stream_voice_room_page_test`）。

## 5. 生成出来的底也要为它自己的字负责

扩面报出来的**真错配**只有一处，但它是一整类：`ChatAvatar` 的字母头像。
圆盘由八个固定色种子生成（`_avatarColors`），字永远是米白；八个里有三个
（Lime `#B8FF20`、浅绿 `#B3D66E`、琥珀 `#F2B562`）比米白还亮，于是米白字母落在
上面是 1.60 / 2.13 / 2.33 的对比度——名字在那儿，读不出来。

这不是假数据造出来的：种子是会话自己的 `colorSeed`，任何一个落到这三个下标的真实
账号都是这个样子。修法不是把那三个颜色改掉，而是**给生成加一条下限**：
`_avatarSeed` 把种子朝 Ink 方向搬，直到圆盘最亮的那一笔（第一个渐变停止点，
即种子 82% 叠在它落地的底上）对米白达到 3:1（WCAG 1.4.3 的大字号阈值，
比探针 2.5 的下限留有余量）。已经达标的种子**逐字节原样返回**，所以 Ink 页上五个
深色种子的圆盘一个像素都没动。落地的底按 `LoopGround` 的老办法推导：一个把浅色
ink 交给子树的底是深底，反之是浅底。

一句话：**调色板可以是生成的，但明度范围不可以是自由的。** 新增第九个种子时不用
记得任何事——下限是种子的一个性质，不是三条修补。

## 6. 探针只判「页面声明过的状态」，不判两个状态之间的那一帧

扩面之后报出来的问题里有两类是探针自己看错的，修法都是同一句话：**把控件自己画、
或者自己声明的东西读出来，而不是猜。**

- **`Badge`**。药丸画在 `Badge` 自己的 render object 里，走查看不到盒子，于是它的
  数字被判成画在药丸背后的页面底上。探针改为读 `Badge` 声明的
  `backgroundColor`（缺省时按 widget 自己的顺序回落到 `badgeTheme` 和
  `colorScheme.error`）。
- **隐式动画中途的那一帧**。`Material` 的 `color` 是一个普通字段，而它交给子树的
  文字颜色走 `AnimatedDefaultTextStyle`。一个按钮从 disabled 变 enabled 时，探针
  读到的是「正在离开的文字颜色」配「已经到达的底」——两个状态各一半，而那个组合
  页面从来不在。探针改为：文字自己写了 `color:` 就永远以它为准；否则优先取上方
  `AnimatedDefaultTextStyle` **声明的**目标颜色，让文字和底从同一端读。
  已停稳的那一帧逐字节不变。

两处都在 `test/s16f_probe_test.dart` 里钉住了：既钉「不该报的不报」，也钉「真的看不见
的照样报」。

## 7. 豁免清单

`loopGroundProbeExemptions` 目前 3 条，扩面**没有新增**：
`ModalBarrier · ColoredBox`、`CommunityScreen · ColoredBox`、
`LoopActionDock · DecoratedBox`，三条都是「用页面自己的 Ink 重画了一遍页面」。
一条豁免是在主张「这笔颜色本来就该看不见」，不是在主张「下限太严」——
调下限会把下一个真问题一起放过，写一条豁免只放过那一个位置。

## 8. 新增一个浅色底时

1. 在容器里加 `DefaultTextStyle.merge` + `IconTheme.merge`，颜色是该底的 ink。
2. 把类名加进 `scripts/check_harness.py` 的 `LIGHT_GROUND_CONTAINERS`，并列出它
   对外开放的 widget 槽位名。
3. 在 `test/s16e_ground_test.dart` 的 `_grounds` 里加一行，整份 `_catalogue` 会
   自动在新底上跑一遍。
