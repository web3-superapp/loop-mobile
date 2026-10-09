# 0130 · 触感、按下态与系统集成（S123c + S123d）

## Status

Accepted 2026-10-09。主代理下单（S123c + S123d），基线 `integration/v2` bd52fd1。
来源：`docs/integration/review-2026-10-09/s123-interaction-audit.md` 的 M6、M4、M15、m1、m2、m3、m4、m5、m12、m17、m20 与 §五 规则 9、10、11、12、14。
不新增依赖、`pubspec.yaml` / `pubspec.lock` 不变、路由清单不变。并行：S123a（路由壳、`showLoopSheet` 的 `useRootNavigator`）、S123b（列表手势）、S123e（资金表单）。

## Context

审查结论是「像网页」：全仓只有扫码页一处触感；约 20 处 `GestureDetector(onTap:)` 按下无反馈；主题是 `InkSparkle`（iOS 上也是 Material 水波纹）；
复制 LOOP ID 32、隐藏金额 36 的热区；抽屉无把手；系统控件英文（Paste / Select all）；登录进社区即弹系统推送框；
Android 13+ 复制时系统提示与 LOOP toast 叠两层；SnackBar 与 LoopToast 两套；收款分享不带二维码；外接键盘后整窗焦点描边。

## Decision

### 触感（M6）

- `lib/core/haptics/loop_haptics.dart`：`LoopHaptics.selection / light / medium / success / error`，按「发生了什么」命名而不是按强度；
  映射 `HapticFeedback.selectionClick / lightImpact / mediumImpact / successNotification / errorNotification`。不读减弱动态效果（触感不是动画）。
  测试用 `LoopHaptics.debugRecord()` 记录、`debugPlayer = null` 复原。全仓只有这个文件可以调 `HapticFeedback`。
- 接入：Tab 点击与滑动选中（`LoopDockBar`：点击由 Listener 判定「未滑动 + 换了 Tab」，滑动在结束处，二者各一次；壳 `loop_shell.dart` 未改）、
  页面分段（`LoopSegmentedTabPage`）、`LoopSeg`（筛选 / 滑点 / 周期，选中已选的不响）、图表十字线出现（medium）、
  下拉刷新越过阈值（light，`LoopRefreshArmHaptic` 复刻 RefreshIndicator 的 1/6 视口阈值，因为 spinner 版没有 armed 回调）、
  签名出口从「签名中」变为已广播（success）/ 失败（error）——开场就是失败的不响、复制（light，`LoopCopy`）、`LoopPressable.onLongPress`（medium）、扫码命中（selection）。
- 未接（不在本单文件范围）：聊天列表长按菜单、自选拖动排序拿起——交给 S123b 合并时用 `LoopHaptics.medium()`。

### 按下态（m2 / m20）

- `lib/widgets/loop_pressable.dart`：`LoopPressable`，按住变暗到 0.6、缩到 0.98（`LoopMotion.press*`），抬起恢复；减弱动态时保留变暗、去掉缩放；两端都没有水波纹。
  只有长按的区域用长按回调显示按下态，不会暴露空的点击语义。
- `lib/widgets/**` 与钱包圆键 / 净值 / (i) / 隐藏金额 / 算力小标 / 零余额开关里的 `GestureDetector(onTap:)` 全部换成 `LoopPressable`。
- 主题 `splashFactory: NoSplash.splashFactory`，`highlightColor: LoopColors.pressHighlight`（Muted 16%，深浅底都可见），InkWell 只剩按下高亮。

### 热区（m3）

复制 LOOP ID 32 → 44；钱包 (i) / 隐藏金额 36×44 → 44×44。`test/s123c_haptics_press_test.dart` 对共用件跑
`iOSTapTargetGuideline`、`labeledTapTargetGuideline` 与 `loopAndroidTapTargetGuideline`。
**偏离**：Flutter 的 `androidTapTargetGuideline` 是 48dp，LOOP 的触控 token 是两端 44（`LoopTouch.minimum`）；改 48 会动全部布局，
所以 Android 检查用 `MinimumTapTargetGuideline(size: 44×44)`。若要 48 需单独决策。自选删除（高 39）在 S123b 文件里，未改。

### 抽屉把手（m1）

`showLoopSheet(showDragHandle: true)` 默认画 36×4 把手（Line2），只在可下滑关闭时画；画在原有 20px 上边距里（8 + 4 + 8），高度不变。
没用 Material 的 `showDragHandle`：它把把手放在透明 Material 上、内容外，会悬在遮罩上。

### 系统本地化（M4）

`MaterialApp.router` 固定 `locale: Locale('zh', 'CN')`，`supportedLocales` 只有它，挂 Stream 中文 + `GlobalMaterialLocalizations / GlobalCupertinoLocalizations / GlobalWidgetsLocalizations`
（`lib/app.dart` 的 `loopAppLocale` / `loopLocalizationsDelegates`）。
**依赖说明**：`flutter_localizations` 是 SDK 包，已经以 transitive 身份在 `pubspec.lock`（经 Stream Video）。在 pubspec 直接声明时 `pub get --enforce-lockfile` 通过，
但任何普通 `pub get`（`flutter analyze` / `flutter test` 会隐式跑）都会把 lock 里这一项的 `dependency: transitive` 改成 `"direct main"`。
按「不改 lockfile」的要求，本单不声明，`lib/app.dart` 以 `// ignore: depend_on_referenced_packages` 引入。正式做法是声明 + 接受 lock 一行元数据变化，待主代理决定。

### 推送权限前置说明（M15）

`LoopPushRegistrationCoordinator` 在请求前先 `currentPermission()`（不弹框）：已允许就静默登记；否则记新门 `awaitingOptIn` 并停下。
通知设置页在 `awaitingOptIn` 显示「开启推送通知」说明卡 +『开启』，按下调 `requestPermissionFromOwner()`，之后才 `requestPermission()`（每账号一次，规则不变）。
0076 的「进社区之后」仍是前提；进社区本身不再弹。「首次有消息提醒时」的入口未做（需要通知中心 / 聊天页文件），只做了通知设置页。

### 复制、Toast、分享、焦点（m4 / m5 / m12 / m17）

- `LoopCopy.text(context, text, message:)` 是唯一写剪贴板的地方：写入、light 触感、toast；Android API ≥ 33 时不出 LOOP toast（系统已有提示）。
  API 级别经 `MainActivity` 新通道 `com.cywd.loop/platform`（`sdkInt`）读一次，`LoopToastHost` 挂载时预取，复制时同步判断（`lib/core/platform/loop_android_sdk.dart`）。13 处调用已迁移。
- SnackBar 12 处（聊天 Preview 页、好友申请、组件、旧 profile、未挂载的 perp 历史）全部改 `LoopToast`；`LoopToast.show` 在没有 Host 的子树里退到最近的 Overlay（自带计时，随树释放）。
  聊天 Preview 页的审过指纹因此更新（同文案、同 exact-ID 规则）。
- 收款「分享」：本机把同一张码画成 1024px PNG（Ink 模块 + Chalk 底 + 4 模块静区），与地址文字一起交给系统分享（`loopImageShareProvider`）；画不出时退回纯文字。
- `MainActivity.onPostResume` 关闭 FlutterView 的 `defaultFocusHighlightEnabled`（API 26+，minSdk 28）。真机未验证（审查标「待真机」）。

### Harness（§五 9 / 10 / 11 / 12 / 14）

`check_press_haptics_contract`：触感只在 `loop_haptics.dart` 调平台、各接入点不得丢失触感；`GestureDetector(onTap:)` 必须有按下态
（`LoopPressable` / InkWell，或参数里写 `loop-press-exempt` 说明），现存 15 处列为按文件计数的债，只能减；`showLoopSheet` 默认把手；主题无水波纹；
`lib/app.dart` 中文三件套与固定 locale；禁止 `showSnackBar / ScaffoldMessenger / SnackBar(`；`Clipboard.setData` 只在 `loop_copy.dart`；
测试文件必须有三条 tap target guideline 与行为测试证据。`tests/test_check_harness.py` 增 `PressHapticsContractTests`。

## Consequences

- S123b / S123e 合并时：新的可点区域用 `LoopPressable`；长按菜单、拖动排序拿起用 `LoopHaptics.medium()`；复制用 `LoopCopy.text`。
- `PRESS_FEEDBACK_DEBT` 里的 15 处（社区、聊天、MEME 面板、Stream 外观等）留给后续批次。
- 真机待验：触感强度、Android 13 复制提示、焦点描边、分享图片在微信 / Telegram 的表现。
