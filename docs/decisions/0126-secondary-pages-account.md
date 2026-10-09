# 0126 · 二级页视觉统一：我的 / 账户 / 设置 / 钱包二级页（S121e）

## Status

Accepted 2026-10-09。主代理下单（S121e），本单设计兼实现。基线 `integration/v2` 5c08c8c，交付前合并 944e410（含 S121f / 0127）。
不新增依赖、`pubspec.lock` 不变、路由清单不变（`_profilePath` 增加 `scan` 去向，指向已有的 `scan` 路由）。

## Context

一级页已按 OKX 改过（0122 / 0123），账户与设置类二级页仍是旧样子：「PUBLIC PROFILE / PRIVACY STATUS / SECURITY POSTURE /
NOTIFICATION SUMMARY / WALLET APPROVALS / PRODUCT RECORD」等英文 eyebrow 的 folio 大卡，每组入口是描边圆角卡片里的 44 方块图标行，
偏好用「已开启」胶囊，说明卡一张接一张，五步开户的进度是 `04 / 05` 计数 + 进度条。对照：S121 §1.1.1 十条、§1.2 纪律；
OKX 资产页 4908（头部、四个圆键、section 标题、无卡行）；已落地截图 `2026-10-09-s121/`、`2026-10-09-s121c/`；并行单 0127 的共用件。

## Decision

### 机制：`LoopFlat`（一处开关，旧组件自己换声音）

`lib/widgets/loop_flat.dart` 的 `LoopFlat` 是一个 InheritedWidget。二级页把自己包进 `LoopFlat(child: LoopFocusPage/LoopDashboardPage(...))`，
页面里已有的组件按扁平声音画，键值、语义、五态块都不变，所以测试与 harness 合约大多原样成立：

- `LoopTopbar`：返回 + 标题 20 粗、一行；`LoopFlat(step: true)` 的开户步骤页为 24 粗。
- `LoopLabel`：0127 `LoopSectionTitle` 的 17 档（`LoopType.headingSm`）、上 24、最小高 44、页面自己的中文；`tight` 为 15，用于块内（折叠区、子组）。
- `LoopRecordRow`：最小高 56、无底无阴影无分隔线，度量对齐 0127 `LoopPersonRow`（左 16、图标距 12、标题 16、副行 13 灰、右值 14 灰、› 16）；
  选中行用 Lime 勾（有右侧控件时不画）。新增 `trailingColor` / `trailingStrong`（金额 16 + rise/fall）。
- `LoopRowIcon`：0127 的 `LoopEntryIcon`（40 圆 card2 + 20 图标）；`circle: true` 为 36 记录标记（交易记录 / 钱包 / 授权行），不分页面。
- `LoopTogglePreferenceRow` 与设置 / 通知行：Lime `Switch`（`LoopFlatSwitch`），取代「已开启」胶囊（0105 / audit §D+ #12 的胶囊结论被本决定在扁平页取代）。
- `LoopNotice`：普通色调、无尾部按钮时变成一行 11px ⓘ 灰字（标题与正文以「。」相接）；warn / danger 仍是卡片（需要动作，S121 §1 提示分级 ③）。
- `LoopButton(block: true)`：0127 `LoopWideButton` 的样子（52 高、整圆角、平涂 Lime、16 字）。
- 新件：`LoopStepDots`（5 点 + 步名）、`LoopFlatHeading`、`LoopFlatSwitch`、`LoopFlatField`（13 灰标签在上 + 0127 `loopFormFieldDecoration` 的 52 填充框；
  `boxed` 给只读值画同一张卡）、`LoopFlatFootnote`（11 灰居中，版本号）。
- 复用 0127：我页四键用 `LoopRoundKey` / `LoopRoundKeyRow`；输入框用 `loopFormFieldDecoration`。顺带修了 `LoopRoundKey` 与钱包 `_QuickActionTile`
  的无障碍：外层 Semantics 排除了子树却没有挂 `onTap`，读屏无法按键。
- 修正 `LoopRecordGroup` 一处旧缺陷：重建行时丢了 `chevron`（`chevron: false` 的分组行仍画 ›）。

插图新增 `profile`（ID 卡 + 人形）、`history`（时钟 + 列表线），96 框 1.7 线宽，登记 `LoopIllustration` 与 harness `ILLUSTRATION_NAMES`。

### 逐页六行计划（色 / 字 / 布局 / 记忆点 / 删掉什么 / 对照）

**我 `profile`**（4908）
- 色：Ink 底；四键实心 Lime + Ink 图标；行图标 card2 圆；值 text2。
- 字：名 18 粗 / LOOP ID 13 灰 tabular；段标题 17；行 16 / 13；版本 11 灰。
- 布局：头像 56 + 名 + ID（复制）+ 右侧编辑笔；四键 分享名片 / 扫一扫 / 好友 / 挖矿；「账号」我的钱包 · 关注与粉丝 · 好友请求 · 邀请好友（码 + 复制）· 我加入的（+ 我创建的子组 15）；
  「资产与挖矿」总算力 · 挖矿资产 · 挖矿奖励 · 挖矿规则；「设置」隐私中心 · 安全中心 · 通知设置 · 通用设置；退出登录一行居中灰字；版本号。
- 记忆点：头部下一排四个 Lime 圆键。
- 删掉：PUBLIC PROFILE 大卡、Chalk 身份卡、「编辑资料」黑按钮、挖矿总览行（= 挖矿键）、「邀请」单独段；自评再删：退出登录前的 × 图标行（改为居中灰字）。
- 对照：4908 头部 + 圆键 + 「资产组合」标题。

**资料编辑 `profile-edit`**
- 色：输入框 card 面圆角 12、聚焦 Lime 边；保存 Lime。字：标签 13 灰、值 16 / 15。
- 布局：头像编辑器 → 用户名（+ 换一个）→ 简介 → LOOP ID（只读框 + 复制）→ 隐私中心入口行 → 底部 52 整宽保存。
- 记忆点：三个等高框。删掉：每个框上方的 section 标签、「公开范围」标题。对照：0127 表单。

**隐私中心 `privacy`（含社交隐私三闸）**
- 色：开关 Lime 轨道 Ink 拇指；其余 Chalk / text2。字：段 17、行 16 / 13（两行副标保留，规则句不能截断）。
- 布局：身份 / 社交 / 可见性三段 + 屏蔽名单行 + 一行 ⓘ + 52 保存。
- 记忆点：一列开关。删掉：PRIVACY STATUS 大卡、「可见性不是授权」说明卡、「隐私状态说明」折叠条（两句并成一行 ⓘ）。对照：OKX 设置列表。

**通知设置 `notif-settings`**
- 布局：一行 ⓘ「N 项开启并生效。目前只有价格提醒…」→ 推送 / 设备 ⓘ 行 → 挖矿 / Launch / 交易 / 社区 / 安全五段开关；安全事件开关锁定。
- 删掉：NOTIFICATION SUMMARY Chalk 卡、底部「开关只是意图」卡；自评再删：「推送还没有在真机上确认过」由横幅降为 ⓘ（不需要动作）。

**安全中心 `security`**
- 布局：验证 / 恢复（状态胶囊「还没有开放」+ 原因）→ 设备 → 授权盘点 → 通知 → 最近安全事件 → 一行 ⓘ。
- 删掉：SECURITY POSTURE 卡（设备数已在设备行）；自评再删：安全事件通知副标「保存的是意图…」改为「始终开启，无法关闭」。

**设置 `settings` / 关于 `about` / 帮助 `support`**
- 设置：通用（语言 / 货币 / 主题 值在右；减少动效、应用锁为开关）/ 账户 / 关于；删「没有"数据用量"」说明卡与常规的本机保存句（只在存储不可用时出现）。
- 关于：删 PRODUCT RECORD 卡（版本号已在「本机构建」行）；开源组件说明降为 ⓘ；风险提示保持 warn 卡。
- 帮助：官方社区行（删「成员数读不到」副标）→ 常见问题 → 分类胶囊 + 52 问题框（计数与问题提示在框下一行 11）→ 52 提交 → 我的工单（空态 `history` 插图）→ 回复时效进脚注 → 防骗 warn 卡；
  删 LOOP SUPPORT 折叠卡。

**开户五步：登录 `auth` / OTP `auth-otp` / 创建钱包 `wallet-create` / 恢复方式 `wallet-recovery` / 安全设置 `security-setup` / LOOP ID `loop-id-setup`**
- 进度：`IdentityProgress` 改画 5 点（当前 18×6 Lime 胶囊、已过 Lime、未到 line2）+ 步名 13 灰；读屏仍是「流程第 N 步，共 5 步：步名」。
- 字：步骤页标题 24 粗（`LoopFlat(step: true)`）、叙述 14 灰（`IdentityStepCopy` 原样）；登录页「欢迎来到 LOOP」24 粗、副标 14 灰（原 11）。
- 登录：邮箱为 52 标签框；删 OTP 页「验证失败时会看到什么」折叠条（错误发生时页面本来就会显示）。
- 等网 / 恢复未决页：品牌字标居中 + 离线图标 + 标题 16 + 一句 14 灰，不再是告警卡；按钮不变。
- 0092 的进度条推进动画随之退役（点阵无需动画）。

**开户后加入社区 `onboarding-communities`**
- 行：Logo 36 圆 + 名称 / 「N 成员」（删简介拼接）+ 右侧 Lime 勾选圆（选中实心 Lime + Ink 勾；未选 line2 圈）；列表到底不画「没有更多社区」。

**钱包二级页**
- 交易记录 `tx-history`：删「钱包记录 / N 笔」folio；分段为 0122 深灰胶囊（quiet）；行 = 36 圆标记 + 「收到 USDT」/「来自 0x…」+ 右「+2.99」16 rise（发出 fall）+ 时间 11；
  区块 / 确认 / 哈希进详情 sheet；空段 `LoopEmptyState(history)`；到底不画「没有更早的记录」。
- 净值明细 `networth`：总额头不变；「按资产」为 17 段标题；30D 空图表面板换为 `LoopEmptyState(chartEmpty)`；空资产为 `watchlist` 空态。
- 钱包管理 `wallets`：删 folio 与「一个 LOOP ID，多个钱包」卡；嵌入式 / 外部两段；行 = 36 圆（wallet / link）+ 地址 + 「嵌入式钱包 · 可用」+ 使用中胶囊；
  外部为空用 `profile` 空态；挖矿与身份两句并成一行 ⓘ。
- 授权与网络：入口仍是钱包页的底部弹层（未新开路由）；授权盘点删 WALLET APPROVALS 卡，两格计数领头；网络与 RPC 删 folio，「x / y 正常」成为链行的值
  （过半 Lime，否则 Chalk），链头区块移入折叠区的参数行，链行的「正常」胶囊在有计数时不再重复。
- 收款 `receive`：网络胶囊居中 → 二维码居中（Chalk 底板 208）→ 地址胶囊（完整地址 + 复制图标）→ 复制地址（Lime）/ 分享（系统分享面板，`loopTextShareProvider`）→ 只收本网 warn 卡；
  删 folio、付款链接文字行与「复制付款链接」（EIP-681 串就是二维码本身）。

**挖矿二级页（从我进入）**：`mining-assets` / `mining-rewards` / `mining-rules` 套 `LoopFlat`；英文 eyebrow 与段名改中文（算力公式 / 可领取 / 算力规则 / 计入的资产 / 未计入的资产 / 参考价 / 领取记录）。
公式 hero 卡保留（它是这一页的记忆点），见偏离。

### 截图（`LOOP/docs/evidence/2026-10-09-s121e/`，模拟器 loop_pixel7_api34，dev 数据，账号 cy，profile 包）

`01-me-top.png` / `01b-me-bottom.png`、`02-profile-edit.png`、`03-privacy.png` / `03b-privacy-end.png`、`04-settings.png`、`05-notif-settings.png`、
`06-security.png` / `06b-security-end.png`、`07-tx-history.png`、`08-networth.png`、`09-wallets.png`、`10-receive.png`、`11-mining-assets.png`、
`12-mining-rewards.png`、`13-mining-rules.png`、`14-networks.png`、`15-about.png`、`16-support.png`、`17a-connections-sheet.png`、`17-approvals.png`；改前 `before/`。
登录 / OTP / 开户步骤 / 加入社区 / 等网页需要签出或新账号，未在设备上截图，以 widget 测试为准。

### 偏离

1. 段标题按主代理追加指示与 0127 对齐为 17（任务单原写 22）。
2. 表单标签在框**上方**（0127 的框把标签当提示文字，值填入后标签消失；资料编辑需要常驻标签），框本身用 `loopFormFieldDecoration`。
3. 入口行图标为 0127 的 40 圆底 20 图标（任务单原写「图标 20」裸图标），两单统一。
4. 挖矿资产 / 奖励 / 规则保留公式与可领取的 hero 卡（只去英文）；它们是记录页的唯一大数字。
5. 「授权与网络（合并页）」未新增路由：合并入口仍是钱包页的弹层，授权 / 网络两页各自扁平化（新增路由需改清单，超出本单）。
6. 扫一扫图标用 `camera`（图标集无扫码图形）。

## Consequences

- 测试：新增 `test/s121e_secondary_pages_test.dart`（扁平行 56 / 无底 / 40 圆、段标题 17、ⓘ 行与 warn 卡、步骤点与标签框、我页头部 + 四键顺序与 Lime 圆 + 三段 + 版本号 + 扫一扫去向、
  我页加载 / 离线 / 不可用 / 无权限 / 错误五态、资料编辑 52 框与 52 保存、隐私三段开关、设置开关、交易记录行 + 空段插图、收款居中与两键、钱包管理、净值空态、网络链行值、授权页；
  每页无 Emoji 与禁词）；`privy_login_screen_test` / `privy_otp_screen_test` 各加一条（24 / 14、52 邮箱框、点阵、无折叠条）。
  更新：identity_pages、local_settings_and_help、profile_v2_pages、s109a、s114、s16f、s26 ×2、s5_wallet_pages、s5_watchlist_alerts_notifications、s58、s59 ×2、s6、s8_settings_about_support、
  s97、s99、security_capability_truthfulness（folio / 胶囊 / 英文段名 / 说明卡被取代处）。
- harness：`ILLUSTRATION_NAMES` 增 `profile`、`history`；H12 「唯一显示开关」要求 `setReduceMotion(` 只出现一次，行与开关共用一个本地函数。
- 未做：设备页 `devices`、导出私钥、社交恢复三页仍是旧 folio（不在本单列表）；挖矿排行 / 社区面板与推荐页的英文 eyebrow（`NETWORK POSITION`、`COMMUNITY POWER`、`MINING POWER`、`FINAL BOOST`）未动；
  帮助页常见问题仍是描边折叠卡；登录等未登录页无设备截图。
