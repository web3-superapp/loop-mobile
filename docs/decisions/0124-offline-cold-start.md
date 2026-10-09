# 0124 · 断网冷启动不再出现登录页（S121d）

## Status

Accepted 2026-10-09。主代理裁定（S121c 决策 0123「需要主代理决策 1」），本单实现。基线 `integration/v2` eb53251。
不新增依赖（`connectivity_plus` 7.3.1 已是直接依赖）、`pubspec.lock` 不变、路由清单不变。修订决策 0064（原文不改，文末加「Revision 2026-10-09」）。

## Context

`docs/evidence/2026-10-09-s121c/06a`、`06b`：设备无网时冷启动，Privy 恢复会话直接发 `Unauthenticated`，0064 §5 的 4 秒宽限过后
页面落到登录表单；联网约 1 分钟后 Privy 发 `Authenticated`，App 自己跳回已登录。用户看到的是「被登出」又「被登回」。
无网时 Privy 不可能核实过凭据，这个 `Unauthenticated` 不是答复。

## Decision

### 1. 网络状态门控，不靠计时器

- 新增 `LoopDeviceTransport` / `loopDeviceTransportProvider`（`lib/core/network/loop_connectivity_signal.dart`）：
  `hasTransport()` 读一次 `connectivity_plus.checkConnectivity()`，返回 `true` / `false`（全部为 `none`）/ `null`（读不到、插件缺席、空结果）。
  不挂计时器；只用于**扣住**签出，不作为任何服务可达或离线的证据。
- `LoopSessionMode.awaitingNetwork`（第四个未决态，`isRestoring` 为真、`canEnterProduct` 为假，路由仍停在 `/auth`）。
- 读取时机：0064 §5 冷启动宽限开始扣住第一个签出答复时（宽限 4000 ms 就是电台作答的时间）、用户按「重试」时。
- 冷启动未决期间（`restoring` / `restoreUnavailable`）任何会落到 `signedOut` 的 Privy 答复——`Unauthenticated` 快照、
  分类为 authentication 的恢复失败、宽限到期——统一经 `_publishSignOut`：最近一次读数为 `false` → `awaitingNetwork`；
  `true` 或 `null` → 与之前完全相同的 `signedOut`。
- 有网冷启动、读不到电台、已登录后（`authenticated` / `authenticatedUnverified` / `preview` / `signingOut`）的签出：行为不变。

### 2. 等网态的退出

- `recheckAfterNetwork()`（0123）现在也处理 `awaitingNetwork`：先读电台，仍为 `false` 不问 Privy；有传输再 `restoreSession()` 一次：
  - `authenticated` / `authenticatedUnverified` → 进主界面（与冷启动映射一致）；
  - `unauthenticated`（或 authentication 类失败）→ **本次网络恢复内第一次**先扣住一个宽限时长（同 `loopSessionUnauthenticatedGraceProvider`，默认 4000 ms，
    与冷启动宽限是两个独立标志，不读也不花冷启动宽限），期间 Privy 流的 `Authenticated` 直接进主界面；到期再问一次，仍为 `unauthenticated` → 登录页；
  - 网络 / 未分类失败、`notReady` → 继续等。
- 触发：App 壳已有的 `_recoverAfterNetwork`（`connectivity_plus` 恢复事件 + App 回前台），无新增订阅。
- 等网期间 Privy 流上的 `Unauthenticated` 一律忽略（由复查决定）；冷启动迟到的失败也忽略；`notReady` 不把它拉回 `restoring`。
- 电台再次读到 `false` 时开启新的「网络回合」，下次恢复的第一个 `unauthenticated` 再扣一次。
- `restoreUnavailable` 仍不被自动重试（0123 撤回项与其测试不变）。

### 3. 页面

`PrivySessionAwaitingNetworkScreen`（`privy_login_screen.dart`）：品牌字标 88 + `LoopNotice`（offline 图标、warn 色）
标题「网络不可用，正在等待连接」/ 正文「联网后会自动确认这台设备上的登录状态，不需要重新登录。」+ 不定进度条 + 次按钮「换个账号登录」。
按钮调 `useAnotherAccount()`：只把会话置为 `signedOut` 显示登录表单，不调用 Privy 退出、不设本地签出屏障——若 Privy 随后确认了原会话，用户照常进入主界面。

## 与裁定的偏离

- **网络恢复后的第一个 `unauthenticated` 扣住一次再问**（裁定原文为「拿到 unauthenticated（有网时）才进登录页」）。理由：privy_flutter 0.10.1
  的 `getAuthState()` 读的是原生侧当前状态，网络刚恢复时那仍是离线时形成的答复（06b 中 Privy 自己约 1 分钟后才改发 `Authenticated`）；
  立即采信就会在联网瞬间闪出登录表单，正是本单要消除的现象。扣住时长可注入，到期一定再问并采信，不会无限等。
- 「换个账号登录」不做 Privy 退出（离线时远端退出无法确认），见上。

## Consequences

- 新增测试 `test/s121d_offline_cold_start_test.dart`：无网冷启动 `Unauthenticated` / authentication 失败 → 等网态不签出；
  仍无网的复查不问 Privy；恢复 → `authenticated` 进主界面；恢复 → `unauthenticated` 扣住一次后进登录页（期间再次 tick 不缩短窗口）；
  扣住期间 Privy 确认胜出且取消的窗口不再触发；恢复后网络失败继续等；「换个账号登录」；有网冷启动 / 读不到电台 → 登录页；
  已登录离线收到 `Unauthenticated` 仍立即签出；`restoreUnavailable` 仍不自动重试；等网页面五要素与 44px 按钮。S11 / S121c 既有测试不改并全部通过。
- 剩余风险：设备有传输但 Privy 后端不可达（强制门户、DNS 故障）时仍按「有网」处理，宽限后落到登录页（0064 Open risk 的剩余部分）。
  若宽限开始到宽限到期之间电台读数尚未返回（实际为毫秒级），按「读不到」处理，即旧行为。
- 真机待复核：Android / iOS 各一次「飞行模式冷启动 → 等网页 → 关飞行模式 → 不碰屏自动进入主界面」；以及「已退出登录的账号飞行模式冷启动 → 等网页 → 联网 → 登录页」。
