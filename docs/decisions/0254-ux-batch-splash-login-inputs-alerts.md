# 0254 · S324 UX 批次：开屏、登录与验证码、输入框焦点、提示样式

## Status

Accepted · 2026-10-31 · S324-mobile

## Context
日期：2026-10-31 · 批次 S324-mobile · 来源：需求方 UX 设计师问题表（`LOOP/docs/evidence/ux-2026-10-31/`）UX-001 / UX-002 / UX-008 / UX-010；主代理处置文档 `LOOP/docs/51-UX问题跟踪处置-2026-10-31.md`。

需求方 UX 设计师交来 18 条问题，本批处理其中四条：开屏加载闪三次（P0）、登录与验证码页排版及忙碌态 bug（P1）、输入框选中态与圆角不统一（P1）、提示样式不统一且顶部提示画进状态栏关不掉（P0）。需求方不要解释性文案（见 0248）。

## Decision

### UX-001 开屏闪三次（P0）

根因：已登录用户冷启动时，原生启动图之后依次画了三张不同的「加载页」，并且中间夹着一次页面推入动画：

1. `/auth` 的 `PrivySessionRestoreScreen`：88 高字标 + 「正在恢复登录状态」+ 说明句 + 加载条，整组居中，字标偏上；
2. 会话恢复成功后同一路由先画一两帧 `PrivySessionHandoverFrame`：只有 88 高字标，居中（字标位置跳一次，加载条消失）；
3. 路由重定向到 `/splash`：`SplashScreen` 是 96 高字标 + 上下 Spacer 布局（字标再跳一次），而且 `/splash` 是普通 `GoRoute`，在 iOS 上以 Cupertino 推入动画从右侧滑入。

另外原生 LaunchImage（160×103 pt，全屏居中）与 Flutter 第一帧字标大小、位置都不同，等于又多一次跳动。

处理：

- 新增 `LoopLaunchFrame`（`lib/features/account/account_screens.dart`）：字标按原生启动图 103 pt 高、全屏正中摆放；字标下方固定位置是加载条和一行状态文字。恢复登录、交接帧、`/splash`（准备账号 / 失败 / 入口）、等待网络、安全退出、恢复失败（重试）、App 锁幕布全部用这一个框架，切换时只换那一行字。
- 等待久时只改文字：恢复登录 3 秒后由「正在恢复登录状态」改为「网络较慢，仍在恢复登录状态…」；删掉原来的说明句「正在确认这台设备上的登录状态。」和长句慢速提示，恢复失败页删掉「还没有收到「未登录」的答复…」解释句。
- 交接帧直接显示 `/splash` 的那行「正在准备你的账号…」，加载条在这一两帧里静止（路由会立刻替换它，不让一个永远在动的条把测试里的 settle 卡住）。
- `/auth` 与 `/splash` 改为 `NoTransitionPage`：两页之间替换不再有推入动画。
- 所有加载条读同一个进程级时钟定相位，换页后条带接着上一页的位置走，不从左端重新开始。
- App 锁：删掉解释句「这台设备的锁屏验证通过后才会显示内容。」，保留标题「LOOP 已锁定」和「验证身份」按钮；幕布字标与开屏同位。

### UX-002 登录页与验证码页（P1）

设计给了三种排版，主代理拍板用**方案一**（图 `02_UX-002.jpg`）：

- 登录页：Logo、「欢迎来到 LOOP」、副标题「选择一种方式登录或创建账户」；三个同形按钮「使用 Apple 登录」（黄色主按钮 + Apple 图标，仍仅 iOS 且受开关控制）/「使用 Google 登录」/「使用邮箱登录」（深灰次按钮 + 图标）；下方文字链「已有钱包？连接钱包」（行为不变 = 外部钱包登录）；页面最底部「继续即表示同意 用户协议 和 隐私政策」。删掉「外部钱包只是登录凭证，不是 LOOP 交易钱包，不能授权任何交易」和「或」分隔线。
- 「使用邮箱登录」进入独立步骤页 `/auth/email`（新路由 slug `auth-email`，清单 114 → 115，prototypeOrder 128）：输入框 + 「获取验证码」，成功后推入 `/auth/otp`。
- 验证码页（图 `06_UX-002.jpg`）：等分段进度条放在最顶部，返回键下方右侧 `1/5`；标题「验证邮箱」；「验证码已发送至 1026••••85@qq.com」右侧文字链「更换邮箱」；六个码格；格子下方倒计时「N 秒后可重新发送」，结束后**同一位置**变成文字按钮「重新发送」；去掉「还可尝试 3 次」、「查看垃圾邮件」和「换个邮箱 / 重新发送」两个大按钮；底部主按钮「继续」，六位未填满时禁用。尝试次数用完时仍显示事实行「尝试次数已用完，请重新发送验证码。」，错误仍走原危险提示卡。
- Bug（图 `07_UX-002.jpg`）：原来发送按钮文案读的是 `authState.isBusy`，任何登录方式进行中它都显示「发送中…」。现在每个入口只看自己的 `activeOperation`：点 Apple 只有 Apple 按钮出转圈和「…」，其它入口只是暂时不可点；「获取验证码」只在 `sendEmailCode` 时显示「发送中…」。
- 共享步骤页骨架 `IdentityStepScaffold` / `IdentityStepBar`（`lib/features/account/identity_step_scaffold.dart`），供后续统一步骤条（UX-006）复用。开户第 02–05 步仍是原来的点式步骤条，未改。

### UX-008 输入框（P1）

焦点色以 UX-008 文字规则为准：**全局选中统一紫色描边**（验证码示意图里的黄色焦点格不采用），圆角统一 12（`LoopRadius.control`）。

- 主题 `InputDecorationTheme` 补 `focusedErrorBorder`、`disabledBorder`，所有状态都是 12 圆角。
- 新增 `lib/widgets/loop_inputs.dart`：`LoopFocusRing`（自绘输入框外套一层，子树有焦点时画 1px 紫边，跟随盒子圆角）与 `loopCodeCellDecoration`（码格：12 圆角，等待输入的那格在有焦点时紫边）。
- 补焦点态 / 圆角的自绘输入框：聊天 composer（Stream `messageComposerInput` 组件构造器套 `LoopFocusRing`，保留胶囊圆角）、验证码码格、社区搜索框（6 → 12 圆角 + 紫色焦点）、聊天消息搜索（10 → 12 圆角 + 紫色焦点）、`loop_blocks` 的搜索输入块、完善资料页用户名 / 简介两张卡（去掉内层主题框，焦点画在卡上）。
- 未改：`features/meme`、`launch2`、`wallet` 等其它批次范围内的金额输入；旧 Launch 交易页金额输入是平铺数字样式，保持原样。

### UX-010 提示框（P0）

- 页面内告警统一为带背景卡片：新增 `LoopAlertCard`（`lib/widgets/loop_alert_card.dart`，琥珀描边 + 深琥珀底 + 左侧警告图标 + 粗体标题 + 正文，与「关于」页风险提示同一外观），另有紧凑版。`LoopUnavailableLine` 与 `LoopChainBlock` 的 unavailable 态由裸两行灰字改为紧凑卡片，原 key（`unavailable-<code>`、`<prefix>-state-unavailable`）保留。
- 顶部提示位置规则：页面顶部的提示一律放进 `LoopTopNoticeLayer`（`lib/widgets/loop_toast.dart`）—— **落在安全区（状态栏）以下**；有提示时由提示区承担状态栏留白、页面整体排在提示下方（不遮挡页面标题栏与按钮，页面在树中的位置不变、不重建）；每条有自己的关闭按钮、可上滑关掉、无人操作 6 秒后自动消失，并垫不透明底色。壳层的「资料状态暂不可读」（图 `36_UX-010.jpg`）与「有新版本可用」两条原来是壳层 Column 的头两行、位于页面自身 SafeArea 之上，所以画进了状态栏；现在改由该图层承载。资料提示被滑走 / 超时等同点「关闭」（本次运行内收起）。
- 底部 toast（`LoopToast`）原本已在安全区与 Tab 栏之上并自动消失，未改。
- 未改：直接调用 `LoopInlineUnavailable`（`loop_inline_states.dart`，属 S325）的其它页面仍是旧的两行式，待 S325 合入后统一。

## Consequences

### 改动页面

登录页 `auth`、新增邮箱步骤页 `auth-email`、验证码页 `auth-otp`、启动页 `splash` 及恢复登录 / 等待网络 / 安全退出 / 恢复失败各帧、App 锁幕布、完善资料 `loop-id-setup`（输入框焦点）、社区搜索 `search`、聊天消息搜索、所有聊天会话的输入框、所有使用 `LoopUnavailableLine` / `LoopChainBlock` 不可用态的页面（如交易历史、关于）、壳层五个 Tab 顶部提示。

### 路由

`auth-email` → `/auth/email`；`docs/product/routes-manifest.json`（count 115、sha256 `72a0a09f…a240`）、`lib/core/navigation/route_manifest.dart`、`scripts/check_harness.py`、`test/route_manifest_test.dart` 已同步；`app.dart` 的 liftable / waiting / signedOut / credential 四个集合都加入 `/auth/email`。上游镜像 `LOOP/docs/routes-manifest.json` 需主代理同步。

- 测试：新增 `test/s324_login_otp_test.dart`、`test/s324_alerts_inputs_test.dart`；更新登录 / 验证码 / 冷启动 / 路由清单相关旧测试以匹配新版面。
- 守护脚本：`scripts/check_harness.py` 的路由数（115）与两个认证路由集合加入 `/auth/email`。
