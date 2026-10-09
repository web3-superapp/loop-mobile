# 0133 · IA 清理：一处一个入口、退出先确认、只读值、全屏扫码、说明收进 ⓘ（S123g）

## Status

Accepted 2026-10-09。主代理下单（S123g），基线 `integration/v2` e6749fd。
来源：`docs/integration/review-2026-10-09/s123-interaction-audit.md` 的 M14、m8、m9、m10、m11、m13、m14、m15、m16 与 §五 规则 15、18；
截图 `docs/evidence/2026-10-09-s123/` 02、20–25、61b、62b、64–68、88–93。主代理追加：兑换页两张说明卡收进 ⓘ、顶部横幅压成一行；
iOS 只留竖屏；通知点开用 push。不新增依赖、`pubspec.lock` 不变；路由清单 slug 与 path 都不变（`networth` 的 path 改为重定向，见下）。
并行：S123f（会话缓存、冷启动、接收页与交易历史骨架）——本单没有碰骨架、首帧和接收页。

## Context

真机走查把「我 / 设置 / 钱包」读成网站导航：同一页面三处入口、入口名字和页面标题不一致（「好友」打开「关注与粉丝」、
「好友请求」打开「陌生人请求」、「交易记录」打开「交易历史」）、只为转一次手的中间抽屉（授权与网络）、与钱包首页重复的
「净值明细」；退出登录一点即退且两处两种样式；设置里「语言 / 货币 / 主题」看起来可点、点了没反应；扫码是一张卡片；
交易历史一条长带没有日期；钱包与兑换页用整段说明卡占据首屏；「发起」悬浮键压住列表行尾的时间。

## Decision

### 退出登录（M14、m15，规则 15）

- 新共用件 `lib/features/profile/sign_out_button.dart`：`LoopSignOutButton`（整宽次按钮 `LoopButton(block: true)`）+ `confirmLoopSignOut`。
  点按先弹共用确认抽屉（`confirmCommunityAction`，根 navigator 底部抽屉，不是居中对话框）：标题「退出登录？」，正文只说退出真正做的事
  （这台设备不再收到该账号通知、本机首屏数据清除、账号内容不受影响），按钮「退出登录 / 取消」。确认后按钮变「正在退出…」并禁用，
  不会触发第二次退出。
- 「我」与「设置」两处都只用这一个控件（原来一处是居中灰字、一处是整宽按钮）。`app.dart` 的 `_signOut` 不变。

### 设置的只读值（m8）

- `LoopRecordRow` 新增 `readOnly`：无 `onTap` 时不画 chevron、没有按下态（本来就没有），值用最弱的 text3，读屏读「语言，简体中文，不可更改」
  （`Semantics.readOnly`）。语言 / 货币单位 / 主题三行用它；组下一行 12px 说明「语言、货币单位与主题在当前版本固定，不能更改」。
  没有做成可选：服务端只发布一个语言与一个货币，主题只有深色，做一个只有一个选项的选择器是另一种假按钮。

### 一处一个入口、名字跟着页面走（m9）

- 「我」：去掉圆键「好友」（它打开的就是下方「关注与粉丝」行）；圆键剩 分享名片 / 扫一扫 / 挖矿 三个。「好友请求」行改名「陌生人请求」，
  与它打开的页面和聊天页顶部的入口同名。
- 「设置」：删掉「账户」组（隐私中心 / 安全中心 / 通知 / 网络与 RPC）——前三个是「我」的「设置」组里的行，网络是钱包的行；设置只剩
  通用、关于与退出登录。
- 「钱包」：底部入口组把「授权与网络」抽屉平铺成三行（代币授权 / 网络 / DApp 网址核对），`showWalletConnectionsSheet` 删除；
  「安全中心」行删除（账号页面，只在「我」）。于是 安全中心 从三处入口变一处（我），网络从两处变一处（钱包）。设置行副标题改「语言、显示与应用锁」。
- 「净值明细」并入钱包首页：它的页头就是钱包的总资产头、列表就是钱包的资产行，唯一多出的是一张空的「还没有净值走势」。
  总资产旁的 chevron 删除，`NetWorthScreen` 删除；manifest 的 `networth` 保留 slug 与 path，`/wallet/networth` 在 `app.dart` 重定向到 `/wallet`
  （与 `/home`、`/launchpad` 同一种兼容重定向）。「不是可用余额」等说明本来就在总资产的 ⓘ 里。
- 标题统一：钱包顶栏时钟键的名字「交易记录」→「交易历史」；资产页底部「这个钱包的收发记录」→「交易历史」。

### 「发起」悬浮键（m10）

- 保留 S121 §1.1.1 第 7 条的 Lime 56 FAB（「聊天列表右下『发起』可用」），不改回顶栏「＋」。列表向后滚时它淡出并下移让开行尾，
  向回滚或回到顶部时回来（`UserScrollNotification`；隐藏时不接收点按、不进读屏；减弱动态效果时无动画）。
- 静止时首屏第 6 行的时间仍可能在它下面——这是 FAB 这一形式本身的代价，主代理若要彻底让开需改回顶栏「＋」（偏离 0122/S121 §1.1.1）。

### 扫码全屏（m11）

- 相机画面铺满整页（`Material` + `Stack`，不再是 `LoopFocusPage` 里的方形卡片）；顶部浮着返回与「扫一扫」；中间一个取景窗（宽 68%，
  四角 Lime，窗外 55% Ink 蒙层）；底部是提示与两个 56 圆形工具「相册 / 手电筒」（手电开启时 Lime 实心）。识别不了的码在底部实心面板上显示，
  复制 / 继续扫描不变。状态栏浅色图标。相机不可用（没有适配器）时仍是原来的整页空态。
- 文案里的「从相册选图」改为指向底部的「相册」；读屏名仍是「从相册选图」。

### 交易历史按日期分组（m13）

- `_activityList` 把同一本地日的连续行放在一个 13px 小标题下：今天 / 昨天 / 9月16日 / 2025年9月16日（`walletActivityDayLabel`，按日历日
  计算，夏令时不错日）。不重排：列表本来就是新到旧，若分页带来乱序则同一天出现两个标题，而不是把行挪走。行本身、骨架、加载更多都没动。

### 横幅收进 ⓘ（m14 + 主代理追加的兑换页）

- 新共用件 `lib/widgets/loop_info_sheet.dart`：`showLoopInfoSheet(title, notes)`，共用 `showLoopSheet` 外观，只读、无按钮。
- 钱包「Launch 链」：五行的测试网说明卡（`LoopTestnetNotice`）从资产区移除，「Launch 链」小标题右侧一个 ⓘ 打开同样的标题与原文
  （`showLoopTestnetInfoSheet`）。行上的「BSC 测试网」徽章不变。Launch 自己的页面仍用原来可关闭的说明（不在本单范围）。
- 兑换：「路由由供应商选择」「算力影响不可用」两张卡移出页面，顶栏一个 ⓘ（`swap-info-action`）打开「关于兑换」，原文照搬；页面只剩表单。
  「兑换还在验证中，可以查看报价，但不能执行」是真实限制，保留，改成一行 11px 的 `LoopInlineUnavailable`（与钱包里余额读不到同一样式）。

### 消息搜索（m16）

- 已由 S123b（防抖 300 ms 即时搜索，回车立即搜）与 S123e（去掉含「从社区 Tab 顶部进入」的 folio）完成，本单不改代码。
  规则 18 落进 harness：`lib/features/**` 不得出现「社区 Tab」「Tab 顶部」「从首页」「回到首页」。

### 系统项

- **iOS 只竖屏**：`Info.plist` 的 `UISupportedInterfaceOrientations` 与 `~ipad` 都只留 `Portrait`，并加 `UIRequiresFullScreen = true`
  （只竖屏的 iPad 构建不能声明分屏多任务，否则上传校验 ITMS-90474）。全屏图表仍要横屏：`AppDelegate` 实现
  `application(_:supportedInterfaceOrientationsFor:)` 返回 竖屏 + 左右横屏——UIKit 要求页面请求的方向与 App 允许的方向有交集，
  否则抛 `UIApplicationInvalidInterfaceOrientation`（0128「偏离」一节记的就是这个）。实际方向仍由 Dart 的 `setPreferredOrientations`
  决定：首帧前锁竖屏，只有 `chart-full` 打开期间横屏。
- **通知点开用 push**：`lib/app/notifications/loop_notification_navigation.dart` 的 `loopOpenNotificationLocation`：目标是 Tab，
  或当前还停在账户闸门（splash / auth / 安全与 LOOP ID 设置 / 强制更新 / 地区限制）或冷启动空栈时 `go`；其它情况 `push` 到当前页面之上，
  返回回到读者原来的页面，五个 Tab 分支不再被替换重建。

## Consequences

- 「我」的圆键是三个而不是四个；钱包底部入口组从 4 行变 5 行，但少了一层抽屉。
- 从钱包进入「设置」不再能一步到「通知」「安全中心」——它们在「我」；从「我」进「设置」不再能一步到「网络」——它在钱包。
- 测试改动：删掉只测 `NetWorthScreen` 本身的用例（五态、走势空态、版式）；其中关于「不是可用余额」「部分计价」「不可用原因」的断言
  改到钱包首页的总资产头上（`s5_wallet_pages_test` 的 `wallet total (net worth)` 组）。退出、设置、钱包入口、兑换横幅相关测试按新行为改写。
- 未在模拟器 / 真机验证：全屏扫码在真机相机上的取景比例、iOS 横屏图表在 AppDelegate 放开后的旋转、iPad 全屏、通知 push 的返回路径、
  FAB 让开的手感，需要主代理在设备上核对。iOS 本单未编译（只改了 Swift 一个方法与 plist），下一次 `ops/ios-testflight.sh` 前请先本地 build。

## Harness

`check_ia_cleanup_contract`：`sign_out_button.dart` 必须走 `confirmCommunityAction`；「我」「设置」有 `onSignOut` 时必须用 `LoopSignOutButton`
且不得直接调用 `onSignOut()`；设置三行 `readOnly: true` 且无 `onTap`；设置不得再有 `settings-open-privacy / security / notifications / networks`；
`wallet_read_screens.dart` 不得出现 `showWalletConnectionsSheet`、`wallet-security-entry`、`'/wallet/networth'`、`NetWorthScreen`，必须用
`walletActivityDays(`；`app.dart` 的 `/wallet/networth` 不得有 builder；「我」不得有 `profile-open-friends`；钱包 Launch 链块不得构造
`LoopTestnetNotice`；兑换页不得用 `LoopNotice` 画两张说明卡与验证中横幅；扫码运行态不得有 `AspectRatio` / `ClipRRect` 卡片；
`lib/features/**` 不得出现指向不存在 IA 的文案；`Info.plist` 两组方向只有 Portrait、`UIRequiresFullScreen` 为真、`AppDelegate` 有
`supportedInterfaceOrientationsFor`；`test/s123g_ia_cleanup_test.dart` 必须保留确认抽屉、只读语义、日期分组、兑换 ⓘ、FAB 让开、通知 push 的断言。
`check_notification_contract` 的「唯一一次类型化根导航」改为匹配 `loopOpenNotificationLocation(router, intent.location)`；
`check_friend_frontend_contract` 锁定的「我」页文案由 `title: '好友请求'` 改为 `title: '陌生人请求'`。
