# 0125 · App 空闲 CPU：Privy Android 忙等 + 被遮挡页面的语音房轮询（S122）

## Status

Accepted 2026-10-09。S122 实施。基线 `integration/v2` eb53251，分支 `fix/S122-idle-cpu`。
`pubspec.yaml` / `pubspec.lock` 不变；Android Gradle 新增一条可配置的依赖解析覆盖（见 Decision 1）。
产品语义、路由清单不变。证据：`LOOP/docs/evidence/2026-10-09-s122/`。

## Context

S121c 在模拟器上观察到：App 前台空闲时 Kotlin `DefaultDispatcher` 线程合计约 120–150% CPU，系统反复弹
「Application Not Responding: com.cywd.loop」，旧包同样如此；真机表现为耗电和发热。另外 api.log 里
`GET /v2/communities/:id/voice-rooms/current` 每分钟 6–13 次。

## 测量（emulator-5554，Android 14 arm64，profile 包，账号 cy，停在「聊天」Tab 不操作）

### 修前（eb53251，pid 10512，启动后 20 分钟）
- `top -H`：18 个 `DefaultDispatcher-worker-*` 全部 R 态，各 3–19%；进程合计 140% / 40% / 131%（三次取样，`top-process-before.txt`）。
- `dumpsys cpuinfo` 5 分钟平均：**146%**（133% user + 13% kernel，`cpuinfo-before.txt`）。
- `debuggerd -j` 6 次线程栈（`stacks-before-*.txt`）：worker 要么在调度器 `WorkQueue.poll/trySteal/park`
  之间空转，要么正在执行同一个协程：
  ```
  kotlinx.coroutines.YieldKt.yield(Yield.kt:151)
  io.privy.sdk.webview.WebViewState.awaitReady(WebViewState.kt:28)
  io.privy.sdk.webview.WebViewState$awaitReady$1.invokeSuspend
  kotlinx.coroutines.internal.LimitedDispatcher$Worker.run   (Dispatchers.IO)
  ```
- 空闲期 api.log 中模拟器的请求只有每 3–5 分钟一组 `/v2/meta/client-policy` + `/v2/meta/capabilities`
  （此时不在社区页），网络请求不是 CPU 来源。

### 根因 1（CPU / ANR）：privy-core 0.12.1 的忙等
`privy_flutter 0.10.1`（当前锁定）在 `android/build.gradle` 固定 `io.privy:privy-core:0.12.1`。反编译
`WebViewState.awaitReady()`：`while (!isReady) { yield() }`，运行在 `Dispatchers.IO`；由
`RealWebViewHandler` 构造函数里的 `subscribeToWebViewReady()` 启动，即 Privy SDK 初始化即开始。
`isReady` 只有在隐藏的钱包 WebView 加载并 ping 成功后才变 true，而只浏览不签名时没有任何东西加载这个
WebView，于是这个协程永远 `yield` 自旋，把 IO 调度器的 worker 全部唤醒在任务队列间来回偷任务——即 18 个
worker 同时 R 态的 140% CPU，主线程被饿到时触发 ANR。与我们的 Dart 代码无关，所以旧包同样复现。

复现：任意装 privy_flutter 0.10.1 的 Android 包，登录后停在任一不涉及签名的页面，`adb shell top -H -p <pid>`。

上游已修：privy-core **0.14.0** 起 `WebViewState` 改为 `MutableStateFlow<Boolean>` + `first { it }`
（0.13.0–0.13.2 仍是 `yield` 循环，逐版反编译确认）。`privy_flutter 0.10.2` 随附 privy-core 0.15.0；
0.10.1 → 0.10.2 的 Kotlin 桥接只改了错误码常量名，privy-core 0.12.1 与 0.15.0 的第三方依赖
（androidx browser / core-ktx / activity-ktx / credentials 1.5.0、kotlin-stdlib 2.1.0）完全相同，新增
`kmp-breadcrumbs`。

### 根因 2（请求频率）：被遮挡的社区页仍在 5 秒轮询
`CommunityProfileScreen` 的 `_voicePoll`（`LoopForegroundPoll`，5 s）只在 dispose 与 App 进后台时停。
从社区页进入聊天、语音房或其它页面时，社区页仍挂在导航栈下，继续每 5 秒读一次
`voice-rooms/current`——叠加语音房页自己的 15 s 轮询，就是 api.log 里的每分钟 6–13 次。widget 测试在去掉
修复后测得遮挡 60 秒内 12 次读取。

### 其它排查项（无需改动）
- Dart 侧全部定时器（`grep Timer.periodic|Stream.periodic|Timer(`）：两个 `Timer.periodic`（OTP 倒计时、
  资金页倒计时）都只活在各自页面；其余是一次性 `Timer`（防抖、截止、状态驱动的单次重读），没有 busy loop。
- S121c 的网络恢复 tick 由 `connectivity_plus` 事件与回前台事件驱动，不是定时器。
- Stream Video / Stream Chat：修复后空闲 CPU 已近零，未见它们的线程在转；未做懒初始化改动。

## Decision

1. **Android 强制 privy-core 0.15.0（可配置）**：`android/build.gradle.kts` 对所有子工程加
   `resolutionStrategy.eachDependency`，把 `io.privy:privy-core` 解析为 `loop.privyCoreVersion`（默认 `0.15.0`）。
   `-Ploop.privyCoreVersion=<版本>` 可换版本，`=plugin` 关闭覆盖、回到 privy_flutter 声明的版本。
   升级到 `privy_flutter >= 0.10.2` 后删除此覆盖（升级动 lockfile，需主代理批准，故本单不做）。
2. **`LoopForegroundPoll` 增加页面可见性**：`setVisible(bool)` + `LoopForegroundPoll.pageVisible(context)`
   （`ModalRoute.isCurrent && TickerMode.enabled`，在 build 里调用即随遮挡 / 切 Tab 重建）。不可见时撤掉间隔、
   `readNow` 也不读；重新可见时从此刻重新起算间隔，**不立即读**——页面自己打开的确认弹层关闭时也是「重新可见」，
   此时立即读会与弹层确认的命令结果赛跑（`community_pages_test` 的开启语音房三例即因此失败，已据此改为不立即读）。
3. **社区页语音行轮询**接入可见性：被其它页面、底部弹层或其它 Tab 遮住时停，回到页面后 5 秒读下一次（与被遮之前的节奏相同）。
   语音房页自己的 15 s 轮询**不改**——房间页上弹出的成员 / 举手弹层仍需要实时数据，遮挡即停会改变语义。

## Consequences

- Android 包里的 Privy 原生层与 privy_flutter 0.10.2 相同（privy-core 0.15.0），Dart 层仍是 0.10.1；两层的接口在这两个版本间没有变化，但这是一个跨版本组合，直到升级 privy_flutter 为止都要保留覆盖与本条说明。
- 任何用 `LoopForegroundPoll` 的页面都可以接可见性；不接的页面行为不变（默认可见）。
- 社区页从其它页面返回后，语音行最多晚 5 秒更新（与原轮询节奏一致）；被遮挡期间零请求。社区页打开弹层期间同样不轮询。

### 修后数据（同机同账号，profile 包含本单改动的 Gradle 覆盖，pid 11916）
- `top -H`：`DefaultDispatcher` 线程 0.0%，`debuggerd -j` 无 `awaitReady` 栈（`stacks-after-1.txt`）。
- `/proc/<pid>/stat` utime+stime 120 秒差值 169 ticks（HZ=100）≈ **1.4%** 平均（`cpu-avg-after.txt`）；
  三次 `top` 取样 8.1% / 48.3%（单次瞬时尖峰，未单独定位）/ 0.0%。
- `dumpsys cpuinfo` 窗口 16:28–16:30（含启动后 1 分钟内的首屏读取）18%（`cpuinfo-after.txt`）。
- 社区页被遮挡 60 s 的 `voice-rooms/current` 读取：修前 12 次 → 修后 0 次，回到页面 5 秒后恢复（widget 测试）。

## 测试
`test/s122_idle_poll_visibility_test.dart`：遮挡不读、`readNow` 也不读 / 回来不立即读、5 秒后恢复；遮挡时启动的轮询等页面；
页面被 push 覆盖停读；离屏 Tab（`TickerMode` false）停读；`CommunityProfileScreen` 被 push 覆盖 60 s 不读
`voice-rooms/current`、pop 后 5 秒恢复（去掉页面改动时该例 60 秒内读 12 次而失败）。原 `s72` 的前后台用例不变且通过。

## 遗留
- 修后冷启动第一次出现过一次「暂时无法确认登录状态」，点重试即进入；同时段 logcat 有
  `Failed host lookup: 'chat.stream-io-api.com'`，模拟器 DNS 抖动所致的可能性大，修前包未在同一网络条件下
  对照，需真机复核会话恢复（0123 的离线判定）在 privy-core 0.15.0 下行为一致。
- iOS 使用 Privy iOS SDK（不是 privy-core），本单未测；升级 privy_flutter 0.10.2 会把 iOS SDK 带到 2.16.2。
- 建议主代理批准把 `privy_flutter` 升到 0.10.2（或 0.11.0，新增 `privy.onNetworkRestored()` 可替代 0123 的
  部分自恢复逻辑），然后删 Gradle 覆盖。
