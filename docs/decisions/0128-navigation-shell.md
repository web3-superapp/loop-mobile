# 0128 · 导航骨架原生化（S123a）

## Status

Accepted 2026-10-09。主代理下单（S123a），基线 `integration/v2` bd52fd1。来源：交互审查
`docs/integration/review-2026-10-09/s123-interaction-audit.md` 的 B1、B2、B3、M1、M5、M13、m21。
不新增依赖、`pubspec.lock` 不变、路由清单与 manifest（105）不变。

## Context

五个 Tab 挂在普通 `ShellRoute` 下，`context.go` 每次切换都重建整页：广场滚到中段切去钱包再回来，回到顶部，
页面状态全丢；重复点当前 Tab 也不回顶。非首个 Tab 按 Android 返回直接退出 App，下次冷启动 5–8 秒。
`showLoopSheet` 默认推在 Tab 自己的 navigator 上，悬浮 Tab 栏盖在抽屉和遮罩上面，「授权与网络」第三行点不到。
创建代币第 2 步按系统返回退出整个流程并清空；会话 → 社区 → 进群聊 又 push 一份同一个会话；App 横屏时 Tab 栏占屏幕三分之一。

## Decision

1. **Tab = `StatefulShellRoute.indexedStack` 的五个分支**（`lib/app.dart`）。离开的 Tab 留在 IndexedStack 里（Offstage + TickerMode 关），
   页面、滚动偏移、状态原样保留。二级页仍是根路由，push 在根 navigator 上、盖住整个壳（决策 0085 / 0110 不变，
   Tab 栏仍只出现在五个 Tab 根页）。深链 `/community/...`、`/launch/...`、`/meme/token` 等路径不变，照旧可达。
2. **切 Tab 用 `goBranch(i, initialLocation: i == currentIndex)`**（`LoopShell`）。同级淡入保留：`LoopTabSwitchFade`
   在分支序号变化时让容器 180ms 淡入；reduce motion 下直接显示。原 `LoopTabPage` 页面转场删除（分支不再重建，没有转场可淡）。
3. **重复点当前 Tab 回顶（m21）**：`LoopShell.scrollToTop` 把当前分支里所有纵向、在屏的滚动位置 `animateTo(min)`（320ms easeOutCubic），
   reduce motion 下 `jumpTo`。不只问 `PrimaryScrollController`：folio 页的列表在 `NestedScrollView` 内层，内层位置不是路由的 primary controller。
   Offstage 的分段不动。
4. **返回（B2）**：壳外层 `PopScope(canPop: currentIndex == 0)`，非首 Tab 的系统返回 `goBranch(0)` 回「聊天」；只有聊天再按返回才退出。
   `PopScope` 是 Android predictive back 读取的接口，非首 Tab 上系统不再预览「离开 App」。
5. **抽屉（B3）**：`showLoopSheet` 默认 `useRootNavigator: true`，抽屉与遮罩画在 Tab 栏上面；harness 禁止显式传 `false`。
   原有三处显式 `true` 保留（与默认一致，属于别的并行单的文件）。
6. **创建代币（M1）**：页面包 `PopScope`。第 2 / 3 步系统返回 = 页内返回 = 回上一步，不清空；第 1 步有内容时先弹
   「放弃创建？」底部确认抽屉（复用 `confirmCommunityAction`，「放弃」/「继续编辑」）；第 1 步空白直接离开；提交进行中返回无效。
   iOS 边缘右滑在第 2 / 3 步以及第 1 步有内容时不再直接离开整页（`canPop` 为 false），与系统返回一致，用页内返回键回上一步。
7. **进群聊（M5）**：社区页「进群聊」（含公告板的打开）先看下一层页面：就是这个社区的 `/community/chat?id=` 时 `pop` 回去，否则 push。
8. **竖屏（M13）**：`lib/features/shell/loop_orientation.dart` 定义 `loopAppOrientations = [portraitUp]`；`main.dart` 首帧前 `loopLockPortrait()`。
   全屏图表进入时切 `loopChartOrientations`（左右横屏），离开时 `loopLockPortrait()`，不再恢复成「任意方向」。

## 偏离

- **`ios/Runner/Info.plist` 的 iPhone 方向未删横屏**。iOS 规定 VC 请求的方向必须与 App 声明的方向有交集，否则抛
  `UIApplicationInvalidInterfaceOrientation` 崩溃；全屏图表要横屏，Info.plist 只留竖屏会让它一进就崩。锁定由 Dart 侧
  `setPreferredOrientations` 从首帧前开始负责，Info.plist 首项仍是竖屏（启动方向）。若要 Info.plist 只留竖屏，需在 AppDelegate
  实现 `supportedInterfaceOrientationsFor`，属另一单。
- `main_preview.dart` 未加竖屏锁（不在本单文件范围；只影响开发预览入口）。
- 通知点开仍走 `router.go(location)`：落到二级页时壳会被替换，返回经 `_popOrHome` 回聊天，此时五个分支会重新构建。属通知路由，未在本单改。

## Consequences

- 五个 Tab 访问过后一直挂在内存里（Offstage、Ticker 关），内存占用比重建式略高；离开的 Tab 不再在回来时重新拉数据，
  数据新鲜度由各页自己的前台轮询 / 下拉刷新负责（行为与切回「用缓存」的现状一致）。
- 新 Tab 页不需要也不能自己装页面转场；同级淡入归 `LoopTabSwitchFade`。
- 任何新的多步页面（有 `_step =` 字段）必须用 `PopScope` 接住系统返回，harness 会拦。
- 抽屉一律在根 navigator：抽屉内 `Navigator.of(sheetContext)` 是根 navigator，用打开它的页面 context 去 pop 会弹错层。

## Harness

`check_navigation_shell_contract`（审查 §五 2、3、4、5、13）：app.dart 必须 `StatefulShellRoute.indexedStack` 且无普通 `ShellRoute`；
`LoopShell` 必须 `goBranch` 切换、`canPop: selectedIndex == 0` + `goBranch(0)`、调用 `scrollToTop`；`showLoopSheet` 默认根 navigator，
`lib/**` 禁止 `useRootNavigator: false`；有 `_step =` 的页面必须有 `PopScope`；`main.dart` 必须 `loopLockPortrait()`、
`loopAppOrientations` 恰为 portraitUp、全屏图表 dispose 恢复竖屏、`lib/**` 禁止 `setPreferredOrientations(const <DeviceOrientation>[])`；
`test/s123a_navigation_shell_test.dart` 必须保留滚动保持、`handlePopRoute` 回 `/chat`、创建代币第 2 步回第 1 步、竖屏断言。
`check_v2_primary_navigation_contract` 与 C3 图表检查改为按 `StatefulShellRoute.indexedStack` 定位壳。

## Evidence

`docs/evidence/2026-10-09-s123a/`：01 聊天；02 广场滚到中段 → 03 钱包 → 04 回广场偏移不变；05 重复点广场回顶；
06 广场按返回回聊天；07 授权与网络抽屉盖住 Tab 栏、三行完整 → 08 第三行可点（DApp 核对）；09–12 创建代币填写 → 第 2 步 →
系统返回回第 1 步（内容保留）→ 再返回弹「放弃创建？」；13 放弃后回 MEME；14 系统转横屏（user_rotation=1）仍竖屏；15 MEME 按返回回聊天。
