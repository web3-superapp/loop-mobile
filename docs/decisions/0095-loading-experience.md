# 0095 · 加载体验：保留上次答复、冷启动快照、同高骨架、分块到达

## Status

Accepted 2026-09-27。S88，客户端单侧。用户 2026-09-27 反馈钱包页「总是很慢」，方案由
主代理定、不再征询。实测服务端 `balances` 平均 364 ms，但手机经本机隧道单次往返
0.5–2.3 s；钱包页每次进入都重新发起四五个请求，并在全部返回前只画空白或骨架。不新增
依赖、`pubspec.lock` 不变、不改路由清单（93 条不变）、不改任何线格式解码逻辑、不碰
签名路径。Launch 只改目录页 `launch_screen.dart` 与 `LaunchOverviewController`；
`launch_detail_screens.dart`、`launch_trade_screen.dart`、`launch_action_screens.dart`
未触碰。

## Context

读控制器全部是 `autoDispose`，而标签壳一次只挂一个页面：从钱包切到行情就销毁余额，
回来再全部重读、重新走骨架。慢的不是服务端，而是每次进入都要付一次隧道往返，而且页面
等所有块都回来才画。

## Decision

### 1 读控制器跨页面保留上次成功值（`lib/core/cache/loop_read_retention.dart`）

`LoopChainReadController`、`CommunityHomeController`、`LaunchOverviewController` 在
`build` 里调用 `loopRetainRead`：

- `ref.keepAlive()` 持有状态；最后一个监听者离开（或被遮挡的路由暂停）时启动
  `LoopSnapshotPolicy.memoryRetention` = 5 分钟计时器，到时 `link.close()`，交还给
  `autoDispose`；监听者回来即取消计时器。
- 回来时（`onResume`，放在 microtask 里，避免在 widget build 期间写状态）若上次答复距今
  ≥ `revisitFloor` = 10 s 就后台 `reload()`；`LoopChainResourceState.loading()` 在已有值
  时给出 `phase: ready, refreshing: true`，页面保持内容、只显示「更新中」。10 s 下限防止在
  两个 Tab 之间来回点时反复打隧道。没有值的块（失败、从未读过）回来总会重读。
- 控制器同时 `ref.watch(loopAccountScopeProvider)`：账号变化即重建，一个账号永远看不到
  另一个账号保留的答复。生产里它是 `loopBootstrapPrincipalKeyProvider`。
- 状态契约形状未改：仍然只有 `phase/value/failureKind/busy/refreshing`。页面需要的
  「这份值何时收到」「是否来自快照」由控制器的 getter `valueObservedAt` /
  `restoredObservedAt` 提供。
- `ApprovalsController` 以 `retainsAnswer => false` 退出：授权盘点页承诺「当场重读的
  allowance()」，不能带着上一次的清单回来。

### 2 冷启动快照（`lib/core/cache/loop_snapshot_store.dart`）

**存储选择：一个 JSON 文件（`dart:io`），不是 hive_ce，也不是 shared_preferences。**

- `hive_ce` 在锁文件里只是传递依赖；直接 import 需要把它提升为 `direct main`，
  `pub get --enforce-lockfile` 会拒绝，这是需主代理批准的依赖变更。它还需要一个目录，
  而 `path_provider` 同样只是传递依赖。
- `shared_preferences` 被 `check_harness.py` 限定为两个审阅过的适配器（显示偏好、开户
  进度）可 import，且显示偏好适配器明文规定「不得用于账户资源」。
- 快照就是缓存：放在 `Directory.systemTemp`（iOS 为应用私有 `tmp/`，Android 为 Flutter
  设置的应用私有缓存目录）下的 `loop_read_snapshots_v1.json`，系统清掉就当没有。
  打开有 400 ms 上限；读不出、解析失败都视为空；写失败只影响下次冷启动。写入走
  `.tmp` + rename。`LoopSnapshotStore` 是接口，以后换 hive 只换一个适配器。

**只存四类只读答复**（`LoopSnapshotResource`）：`wallet.directory`、
`wallet.balances.<walletId>`、`community.home`、`market.overview`、`launch.overview`。
钱包余额需要目录才能知道 walletId，所以目录一并存。

**存的是线上原文，不是模型。** 四个 Dio 传输在严格解码成功之后把 `response.data` 交给
`LoopV2SnapshotTap`；解码逻辑原样抽成 `decodeBalances/decodeDirectory/decodeOverview/
decodeHome` 静态函数（仅移动代码，未改一行校验），冷启动时用同一个解码器重新解码。
今天的解码器不接受的旧快照（契约升级、文件损坏）直接不画。

**Key 设计**：一条记录 = `{account, resource, observedAt, body}`。

- `account` 是 principal（Privy user id）的 FNV-1a 64 位指纹，文件里不出现账号原文。
- `resource` 为上面五个之一，同一 resource 只保留最新一条，总数上限 16。
- `observedAt` 是本机收到这份答复的时刻（UTC）；答复体里服务端自己的
  `snapshot.observedAt` / `observedAt` 仍由各页页脚照常显示。

**绘制规则**（`LoopV2SnapshotSession.restore`）：

- 只在本次运行里某 resource 第一次打开且尚无实时答复时恢复一次；恢复过一次、或本次已收到
  实时答复后就不再恢复——之后控制器自己的内存保留才是兜底。这样被主动 `invalidate` 的
  读（改自选、创建钱包）不会重新打开在比刚替换掉的更旧的答复上。
- `now - observedAt > 10 分钟` 不画，页面走骨架。
- 画快照时页面顶部 `LoopFreshnessStrip` 显示「数据来自 N 秒前，正在更新」（`LoopMotion
  .freshnessFade` 220 ms 淡入）；实时答复落地后淡出；实时读失败则改为「更新失败，显示的是
  N 前读到的数据」并给 44 px 的「重试」。
- 网关为 `unavailable` 时不恢复。Preview 与测试构建不接 store，永远走骨架。

**清空时机**：

- 登出：`_signOut` 在 `exit()` 前 `await store.clear()`（内存与文件都清，文件删除）。
- 换账号：新 principal 的 `LoopV2SnapshotSession` 构造时 `store.bind(accountKey)`，
  其他账号留下的记录全部删除；此后迟到的旧账号答复在 `write` 时因账号不符被丢弃。
- principal 变为 `null`（会话过期、冷启动尚未恢复会话）不清空——否则每次冷启动都会在会话
  恢复前把快照清掉；读取时仍按账号指纹比对，别人读不到。

**金额与签名**：余额快照只用于显示。签名出口一向自己重读要签的数字，本单未触碰签名路径；
`LoopWalletBalances` 控制器上的注释写明了这一点。

### 3 骨架与真实行等高

`LoopSkeleton` 新增两种类型，其余类型不动：

- `record`：按 `LoopRecordRow` 的结构画成一张分组卡；每行文字高度用
  `LoopSkeletonLine` 以真实行所用的主题字体和当前文字缩放量出来（`TextPainter`），
  前导块尺寸跟真实 logo 一致（钱包 36、社区/Launch 44），钱包行两行副标题。
- `priceRow`：行情列表的固定行高 `marketRowHeight`（58）× 6 行。

用在钱包资产列表、社区首页、行情列表、Launch 目录的 loading 相。内容到达时由
`LoopContentArrival` 在 `LoopMotion.contentFadeIn` = 180 ms 内淡入——只有本次挂载确实
画过骨架时才淡入，保留值、快照、刷新都不闪。`MediaQuery.disableAnimations` 下骨架不脉动、
内容不淡入、提示条不淡入淡出。

`LoopFolioPrimary.headingLoading`：数字未读到时，标题行画成同高骨架（语义标签仍是
「净值读取中」「正在读取」「目录读取中」），不写 0，也不写一句随后会被替换的话。

### 4 钱包页分块到达

目录一回来就画 Pay / 兑换 / 发送 / 接收 / 跨链和资产区标题，资产列表位置画 `record`
骨架，净值标题画骨架；余额回来后资产行淡入、净值替换骨架。价格、净值与 Launch 链块在当前
契约里随同一个 `balances` 答复到达，算力随挖矿模块自己的读到达（没到时照旧显示「—」），
两者互不等待。

### 5 下拉刷新不闪

刷新期间保持现有内容 + 顶栏「更新中」（已有）；失败时内容保留，`LoopFreshnessStrip`
给出失败条与重试。首读失败（没有任何内容）仍是原有的五态块。

### 6 时长与曲线

`lib/core/theme/loop_motion.dart` 新增：`contentFadeIn` 180 ms / `contentFadeCurve`
`easeOutCubic`；`freshnessFade` 220 ms / `freshnessCurve` `easeOutCubic`。保留与快照的
时长（5 分钟、10 分钟、10 秒）不是动效，放在 `LoopSnapshotPolicy`。

## Consequences

- 切 Tab 回来立刻有内容；冷启动 10 分钟内重开也立刻有内容，并明确标出它有多旧。
- 旧数据永远带时间：快照有提示条，失败的刷新有失败条，各页页脚仍显示服务端观察时间。
- 新增一个设备本地文件；它随登出删除、随换账号清空、系统可随时清理。
- 待真机确认：Android 上 `Directory.systemTemp` 确为应用私有可写目录（Flutter 将其设为
  应用缓存目录）；若不是，store 退化为仅内存，冷启动快照不生效但不影响其他功能。

## Evidence

- `test/s88_loading_experience_test.dart`：保留值 + 后台刷新 + 10 s 下限、5 分钟 TTL
  释放、换账号清空、授权盘点不保留、快照恢复后实时替换/失败保留、unavailable 不恢复、
  社区与 Launch 恢复；store 绑定/丢弃/重启存活/清空删文件/损坏文件、指纹；会话用真实解码器
  重解 JSON 往返后的目录/余额/行情、10 分钟过期、只恢复一次、解码拒绝、错钱包、换
  principal 清空、传输只在解码成功后调用 tap；四个页面冷启动有快照先画并标注、无快照画同高
  骨架、刷新不闪、失败条与重试、reduced motion 无动画；钱包分块到达（目录先到 → 动作 + 骨架，
  余额后到 → 行淡入）。
- 既有测试只改断言、不删：`community_pages_test.dart`（社区加载中标题「正在读取」改由
  `LoopFolioPrimary.heading` + `headingLoading` 断言）、`s8_launch_mining_state_pages_test
  .dart`（Launch 加载中标题接受同高骨架）。`s5_page_harness` / `community_test_harness`
  增加可选 `overrides` 参数。全量用例 3534 → 3575（+41，3 个既有 skip 不变）。
