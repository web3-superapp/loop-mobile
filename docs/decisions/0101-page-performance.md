# 0101 · 页面性能：连接复用、请求并行、按主体保留、图标与 folio 去离屏层、logo 限时

## Status

Proposed 2026-09-28。S94，客户端单侧。基线 `integration/v2` 3086bf4。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）、不改 API 形状与严格解码、fail-closed 不变。未触碰
`lib/features/launch/*`、LOOP/ops、launchd 与 3100 端口。

## Context

TestFlight 用户（中国网络）反馈「每个界面都很卡」。用户到服务器的单次往返 0.5–2.3 s，所以客户端
这一半只看两件事：**首屏可交互之前要付几次往返**（含 TCP/TLS 建连），以及**滚动时每帧的栅格化成本**。

测量方法：模拟器 emulator-5554（Android，Impeller OpenGLES），`flutter run --profile` 连本机 dev
API（`config/debug.json` → `https://api-dev.quant-dinger.cc`，经 Cloudflare 隧道；模拟器流量还经过宿主
代理）。临时在 `LoopDioFactory` 里加计时拦截器打每个请求的起止（`t` 为进程内毫秒），在 `main` 里挂
`addTimingsCallback` 打帧的 build/raster 分位数，并通过 VM service `getVMTimeline`（Embedder 流）
统计每帧的 `Canvas::saveLayer`、render pass 数与 `SurfaceFrame::Encode` 时间。滚动用 `adb input swipe`
上下各 4 次，改前改后同一手势。临时打点均未提交。

**模拟器的绝对帧时间不可当真**：每帧 25–55 ms 花在 `SurfaceFrame::Submit` /
`SurfaceGLES::WrapOnScreenFBO`（宿主 GL 转译的交换），与应用无关。应用能控制的是离屏层 / render pass
数与 Encode 时间，下文以这两个为准；真机帧时间需要在 iPhone 上抓一次 trace（见待确认）。

## 改前瀑布（3086bf4 实测）

「波」= 一次往返；同一波内的请求同时发出。括号内为实测耗时。

| 页面 | 请求序列 | 串行关系 | 首屏可交互往返数 |
| --- | --- | --- | --- |
| 冷启动 → 社区 | W1 `meta/client-policy` ‖ `meta/capabilities`（1.3 s，公共客户端新建连接）→ Privy token → W2 `account/me`（1.58 s，后端客户端**另建**一条 TLS）→ W3 `profile` ‖ `community/home` ‖ `chat/token` | 真依赖（0098） | 会话后 2；meta 与 account/me 各付一次建连 |
| 社区 tab 回访 | ≥10 s 时后台 `community/home`（保留，不闪） | — | 0 |
| 社区详情 | W1 `communities/{id}`（1.0 s）→ W2 `mining/communities/{id}` ‖ `market/assets/{bound}` ‖ `mining/assets`（1.8 s）→ 5 s 后 `voice-rooms/current` 轮询 | W2 等 W1 取 `boundAssetKey` | 2（绑定币卡）；**每次进入都重读**，先画骨架 |
| 挖矿 tab | `mining/summary` ‖ `mining/rank` ‖ `mining/assets`（2.0–2.3 s） | 已并行 | 1 |
| 行情 tab | `market/overview` ‖ `mining/rules`（+ 60 s 过期的 meta 一对）（1.6–2.9 s） | 已并行，保留 + 快照 | 1 |
| 代币页 | W1 `market/assets/{id}` ‖ `watchlist`（2.9 s）→ W2 `…/candles`（1.9 s） | **写成了顺序**：K 线只要路由里的 assetId | 2 |
| Launch tab | `launch/overview`（1.8 s） | — | 1 |
| 钱包 tab | `wallets` ‖ `wallets/{id}/balances` ‖ `mining/summary` ‖ `mining/assets`（balances 4.9–5.2 s，服务端链读） | 目录 → 余额为真依赖；0098 预读 + 快照已压到 0–1 | 1 |
| 聊天列表 | Stream `queryChannels`（本地持久化先出，<1 s）‖ `chat/direct-channels`（1.4 s） | 并行；**每次进入重建列表控制器、重读目录**，直聊行先显示中性名再换名 | 1 |
| 个人 | `profile` ‖ `profile/privacy` ‖ `wallets` ‖ `notifications/feed` ‖ `mining/summary` ‖ `mining/rank` ‖ `connections` | 已并行 | 1，但只有 1 个请求复用了连接（0.39 s），其余 6 个各建一条 TLS（1.75 s） |
| 设置 | `settings`（+ meta 一对） | — | 1 |

改前测到的三个与页面无关的问题：

1. **连接活不过一次停留**。`dart:io` 的 `HttpClient.idleTimeout` 默认 15 s，服务端 `keepAliveTimeout`
   是 72 s。读者在一页停 15 s 以上，下一页的第一批请求全部重新 TCP + TLS（多 2 个往返）。
2. **两个连接池**。D0 的公共客户端（`DioLoopV2MetaRepository`）与后端客户端是两个 `Dio`、两个
   `HttpClient`，同一 origin 的热连接互相用不上：冷启动 `account/me` 1.58 s（新建） vs 同一时刻复用连接的
   `community/home` 0.39 s；签名前的 capability 刷新（0099）每次都新建连接。
3. **冷启动快照从未生效**。`FileLoopSnapshotStore.openPersistent` 的可写性探针用
   `writeAsString('', flush: true)`，模拟器上 fsync ≈ 400 ms，正好撞上每步 400 ms 上限，日志
   `snapshot directory unavailable, keeping snapshots in memory only (TimeoutException after 0:00:00.400000)`，
   store 退化为仅内存。所以 0095 的社区首页 / 行情首页 / 钱包冷启动快照（S88b 已接好）实际一直没有生效。

## Decision

### 1 网络层：每个 origin 一个 keep-alive 池，空闲 60 s（`lib/core/network/loop_dio_factory.dart`）

- `LoopDioFactory._create` 给每个 client 装一个 `_LoopOriginConnectionPool` 租约：同一
  `scheme://host:port` 共用一个 `IOHttpClientAdapter`，其 `HttpClient.idleTimeout =
  LoopDioFactory.idleConnectionTimeout = 60 s`（低于服务端 72 s，客户端先放手，避免写到服务端已关的
  socket 上）。最后一个租约 `close` 时才关池。
- 信任边界不变：`_LoopTrustBoundaryInterceptor` 仍按 client 在派发前执行；`dart:io` 不存 cookie，
  Authorization 仍是请求级。共享的只是 socket。
- DNS/TLS：同一 origin 的并发请求在 HTTP/1.1 下仍各占一条连接，池里保有上一波留下的连接，下一波在
  60 s 内复用。首个请求前的 DNS/TLS 只在池空时发生。
- harness：`check_network_dio_policy_contract` 的 factory import 白名单由 `[dio]` 扩为
  `[dart:io, dart:typed_data, dio, dio/io]`（其余约束——唯一 `Dio(`、唯一 `BaseOptions(`、拦截器只在
  factory 内——不变）。
- **HTTP/2 未做**：`dart:io` 只有 HTTP/1.1；多路复用需要 `dio_http2_adapter` 或平台栈
  （`cupertino_http` / `cronet_http` + `native_dio_adapter`），均不在锁文件里，属依赖决策。
- **ETag 未做**：`openapi/loop-api.v2.json` 没有任何 `ETag` / `If-None-Match`，实测响应头是
  `cache-control: no-store`、无 ETag。按任务单「先查 openapi」，没有就不加。

### 2 冷启动快照恢复生效（`lib/core/cache/loop_snapshot_store.dart`）

探针改为 `writeAsString('')`（不 fsync）：它只问目录能不能写文件。改后探针步骤 4–5 ms。快照本身的写入
仍是 `.tmp` + `flush` + rename，不在首帧路径上。实测冷启动日志不再出现 memory-only，钱包余额在目录
答复之前就用快照里的 walletId 发出（下表冷启动行）。社区首页与行情首页的快照资源 0095 已有，本单让它
真正落盘，没有新增资源类型。

### 3 无依赖请求同时发出

- **代币页**（`token_screen.dart`）：页面 build 时对当前周期的 `marketCandlesControllerProvider`
  `ref.listen`（持有、不触发整页重建）并 `load()`，K 线与报价、自选同一波发出。单飞保证 K 线区块挂载时
  不再发第二次。
- **社区详情**（`community_profile_screen.dart`）：若社区 tab 的聚合已在内存且列出了这个社区
  （`ref.exists` 判断，不创建聚合），用它的 `boundAssetKey` 把绑定币报价、`mining/communities/{id}`、
  `mining/assets` 与 `communities/{id}` 同一波发出。提示只启动页面本来就会发的读；画什么仍由记录本身
  的答复决定。从深链进入（没有列表提示）时行为与改前相同。

### 4 按主体保留上次答复（0095 的延伸）

- `lib/core/cache/loop_recent_answers.dart`：`LoopRecentAnswers<K, V>`，最近 16 个、5 分钟
  （`LoopSnapshotPolicy.memoryRetention`）、LRU、仅内存。
- **社区详情**：`communityDetailMemoryProvider`（watch 账号作用域与 community gateway，换账号 / 换网关
  即清空）。`open(id)` 命中时立即画 ready，距上次 <10 s 不重读，≥10 s 后台重读（`refreshing`，页面
  「更新中」）；打开另一个社区时先清掉当前值，绝不在别的社区的路由下画这一个的记录。加入 / 退出 /
  编辑 / 重新提交的服务端答复同样记入；`notFound` / `permissionDenied` 时删去。控制器补上了
  `ref.watch(loopAccountScopeProvider)`。
- **发现社区**（`CommunityDiscoverController`）：接 `loopRetainRead`，回访 ≥10 s 用 `refresh()`
  （保留行、标更新中）重读第一页；保留的筛选与本次入口不一致（全部 / 仅已加入）时按本次入口重读，
  新增 `openAll()`。
- **聊天列表**：`loopStreamChannelListControllerProvider`（key = Stream client + userId，
  `loopRetainRead` 保留 5 分钟）。回访时列表立刻有行且一直订阅着 Stream 事件；`StreamChannelListView`
  的 initial load 在旧行之后重新查询，不清空。`directChannelDirectoryProvider` 同样保留，≥10 s 才
  `invalidateSelf`，期间保留旧值，直聊行不会先变回中性名再换回来。
- 社区首页、行情各 tab（overview / new-pairs / smart-money）、代币页的 asset / candles / trades /
  holders 在基线已经是 `LoopChainReadController` / 0095 保留，未改。

### 5 图片与图标

- **`LoopTokenLogo`**：3 s 预算（`LoopTokenLogo.fetchBudget`）内没有出第一帧、或 `errorBuilder`
  报错，就把该 URL 记入进程级失败集，本进程内所有行 / 页 / 重建直接画首字母，不再发起请求
  （`raw.githubusercontent.com` 在中国网络可挂一分钟）。等待期间槽位始终是同尺寸首字母，列表布局不等图片。
  解码尺寸改为 `cacheWidth/cacheHeight = size × dpr`（不再按 256 px 原图解码）。
- **头像**：`LoopIdentityAvatar` 用的是包内 WebP 图集，无网络请求；`ImageCache` 按资产键共享一次解码。
  未改（它的三层裁剪在 Impeller 下是 stencil，不是离屏层，timeline 里没有看到它的成本）。
- **`LoopIcon` / SVG**：确认 0100 的预热与 `svg.cache` 让列表项复用编译结果，**没有**反复解码。
  但 timeline 显示真正的成本在绘制：`flutter_svg` 的 picture 策略遇到 `colorFilter` 会对**每个图标**
  `saveLayer`（`vector_graphics` `RenderPictureVectorGraphic.paint`），社区页每帧 ≈ 19 个离屏 pass。
  新增 `LoopIconRasters`：同名同像素尺寸的图标从同一份编译好的 picture 栅格化一次（`toImageSync`，
  `BoxFit.contain` 居中），之后用 `RawImage(color, BlendMode.srcIn)` 绘制——着色在图像绘制本身，
  没有图层。第一次在某尺寸出现时仍画矢量（与改前一致，不会出现空白），栅格好后下一帧切换。所有 sprite
  都是 `stroke: currentColor` / `fill: none`，srcIn 结果与矢量路径相同（截图核对一致）。进程内常驻，
  上限 512 份，超过的新尺寸继续走矢量。`RenderingStrategy.raster` 未直接使用：`flutter_svg` 不导出它，
  直接依赖 `vector_graphics` 需改锁文件。

### 6 掉帧：修掉的三处

1. `LoopIcon` 每图标一个 `saveLayer`（上节）。
2. `LoopFolioPrimary` 的 kicker / caption / stamp 用 `Opacity` 包文字，每个 dashboard 页面每帧 2–3 个
   离屏层。改为把透明度乘进墨色的 alpha（`_faded`）：文字与细边框自身不重叠，像素相同。
3. 代币 logo 以原图尺寸解码（上节 `cacheWidth`）。

UI 线程（build / layout / paint）三页都 <1 ms/帧 p50，没有 >16 ms 的 build 热点，无需改 widget 树。

## 改后瀑布（本分支实测）

| 页面 | 请求序列 | 首屏可交互往返数 | 对比 |
| --- | --- | --- | --- |
| 冷启动 → 社区 | W1 meta 一对 → W2 `account/me`（**0.22–0.27 s**，复用 W1 的连接）→ W3 `profile`（0.36 s）‖ `community/home`（0.40 s）‖ `chat/token`；快照命中时 `balances` 与 `wallets` 同波发出 | 会话后 2，但 W2/W3 不再建连 | account/me 1.58 s → 0.22 s；profile 1.13 s → 0.36 s |
| 社区详情（首次，从 tab 进入） | `communities/{id}` ‖ `market/assets/{bound}` ‖ `mining/communities/{id}` ‖ `mining/assets` 同一波 | 2 → **1** | 绑定币卡 0.93 s 内全部到齐（改前 1.0 + 1.8 s） |
| 社区详情（回访 <10 s） | 只有未保留的 `mining/communities/{id}` | 1 → **0**（记录立即画出） | |
| 社区详情（回访 ≥10 s） | 记录立即画出 + 后台 `communities/{id}` | 1 → **0** | |
| 代币页 | `market/assets/{id}` ‖ `…/candles` ‖ `watchlist` 同一波 | 2 → **1** | |
| 聊天列表（回访） | 列表与名字立即画出；<10 s 不发 `direct-channels` | 1 → **0** | |
| 发现社区（回访） | 第一页立即画出；≥10 s 后台刷新 | 1 → **0** | |
| 个人 | 7 个请求同一波；4 个复用池里的连接（0.39–0.52 s），3 个新建（1.0 s） | 1 | 改前 1 个复用、6 个新建（1.75 s） |
| 设置 | `settings` 0.22 s（复用） | 1 | 改前 6.6 s（那次含一次代理抖动） |
| 挖矿 / Launch / 行情 / 钱包 | 结构不变（已并行 / 已保留），60 s 内的 tab 切换复用连接：Launch overview 1.79 s → 0.34 s，meta 一对 1.1–1.8 s → 0.35–0.44 s | 1 | |

## 帧（同一手势，VM timeline，模拟器）

| 列表 | 指标 | 改前 | 改后 |
| --- | --- | --- | --- |
| 社区 | `saveLayer` / 帧 | 18.9 | **0** |
| | render pass / 帧 | 18.8 | **1.0** |
| | `SurfaceFrame::Encode` / 帧 | 15.2 ms | **5.1 ms** |
| | raster p50（含模拟器交换） | 74 ms | 45 ms |
| | 同一手势内交付的帧 | 38 | 56 |
| 行情（热门） | `saveLayer` / 帧 | 7.9 | **0** |
| | render pass / 帧 | 8.9 | **1.0** |
| | Encode / 帧 | 7.1 ms | 5.4 ms |
| | raster p50 | 46 ms | 34 ms |
| 钱包 | `saveLayer` / 帧 | 22.5 | **1.6** |
| | render pass / 帧 | 21.7 | **1.8** |
| | Encode / 帧 | 13.4 ms | 4.8 ms |
| | raster p50 | 59 ms | 49 ms |

模拟器上帧时间的其余部分（25–35 ms/帧）是宿主 GL 的 `SurfaceFrame::Submit`，与应用无关；真机上
没有这一项，离屏 pass 的减少在 Metal / Vulkan 上的收益需真机确认。

## Consequences

- 同一 origin 的所有 LOOP 请求共用一个连接池，空闲连接多留 45 s（最多与上一波并发数相同的几条 socket）。
- 页面回访更少请求；社区详情 / 发现 / 聊天目录与列表在 5 分钟内保留在内存，换账号即清空。
- 首次在某尺寸出现的图标仍画一次矢量，下一帧起换成栅格；图标栅格常驻进程（约 64 × 常用尺寸，
  每份 ≤ 20 KB）。
- 失败或超时的 logo 在本进程内不再重试；网络恢复后需重启 App 才会重新尝试该 URL。
- 冷启动快照现在真正落盘（0095 设计的行为首次生效）：冷启动 10 分钟内重开会先画旧值并标注「数据来自
  N 秒前，正在更新」。
- 发现：社区详情里绑定币卡的 1H 走势（`_BoundAssetSection` watch 了 candles 但从不 `load()`）一直停在
  「1H K 线读取中」，改前改后相同，未在本单修（会多一个请求，需主代理决定）。

## Evidence

- `test/s94_page_performance_test.dart`（16 例）：空闲超时 60 s < 72 s；同 origin 两个 client 共用
  socket、关一个另一个照常复用（真实 loopback server；将池键改成每 client 一个后此例失败）；池不削弱
  信任边界；代币页报价未答复时 K 线已请求；`LoopRecentAnswers` LRU 与 5 分钟；社区详情回访 <10 s
  不读、≥10 s 先画后读、换社区不串、换账号清空、从 tab 进入时绑定币报价与记录同波；发现社区回访保留与
  10 s 下限、筛选不串；直聊目录 10 s 下限且刷新期间保留旧值；Stream 列表控制器跨访问同一实例、换用户
  不同；logo 3 s 无帧后进程内放弃、后续行不再请求、占位尺寸不变；400 同样记住；folio 无 `Opacity`
  且墨色 alpha 为 0.66 / 0.68。
- 改断言不删：`test/s78b_market_density_test.dart`（远程 logo 的 provider 现为
  `ResizeImage(NetworkImage)`）、`test/s16e_ground_test.dart`（quiet folio 的 kicker 由「Chalk +
  Opacity 0.78」改为「Chalk 的 alpha 0.78」）、`test/loop_assets_test.dart`（LoopIcon 先矢量、栅格就绪后
  `RawImage` + srcIn）。

## 主代理裁决（2026-09-28）

状态：Accepted，随 `integration/v2` 合并。

1. HTTP/2 适配器需要新依赖，本单不加；等真机（中国网络）复核连接复用效果后再定。
2. 服务端没有 ETag，`If-None-Match` 不做。
3. 社区详情绑定代币卡的「1H K 线读取中」是既有缺陷，开 S94b 补那一次请求。
4. 快照打开步骤预算 400 ms 保留，目录创建步骤单独放宽到 1000 ms（S94b 一并做）。
5. `check_harness.py` 给 `loop_dio_factory.dart` 放开 `dart:io` / `dart:typed_data` / `package:dio/io.dart`：接受。
6. 图标 URL 失败后本进程不再重试：接受；S92 服务端代取图标后此规则自然失效。

## S94b（2026-09-28）

基线 `integration/v2` c2df3ee，分支 `fix/S94b-followups`。客户端单侧；不新增依赖、`pubspec.lock` 不变、
路由清单不变（93 条）、不改 API 形状与严格解码。

### 1 代币图标：慢不等于失败（取代上文 §5 与裁决 6 的「超时即放弃」）

主代理模拟器复现：冷启动行情页多张 logo 并行下载，3 s 内没出帧的被记为失败，本进程不再请求，
好网络上 Cake / WBNB / BNB 也只剩首字母。改为（`lib/widgets/loop_assets.dart`）：

- `LoopTokenLogo.fetchBudget` 3 s → **5 s**，且只管「首次绘制」：槽位从第一帧起就是同尺寸的内置图或首字母，
  超过预算**不卸载** `Image`、不记失败，下载继续，第一帧到达即替换成真图（布局不动）。超预算只打一行
  debug 日志（每个 URL 一次）。已发起的下载由 `ImageCache` 的 pending 项持有，行滚出屏幕也会下完，
  同一 URL 的其他行共用这一次下载。
- 只有**明确失败**记入进程级失败表（`loopLogoFailureIsDefinite`）：HTTP 4xx/5xx
  （`NetworkImageLoadException`）、DNS 失败（`Failed host lookup` 等）、连接被拒（`Connection refused`，
  errno 61 / 111）。超时、连接重置、TLS 与解码错误不记；这些情况下只有出错的那个 tile 在挂载期间不再重试。
- 失败表带时间：`LoopTokenLogo.failureRetryAfter` = 10 分钟内不再请求；10 分钟后允许**再请求一次**，
  这次仍明确失败则本进程不再请求。
- 测试接缝：`debugLoopTokenLogoClock`、`debugLoopTokenLogoImageProvider`（均 `@visibleForTesting`，
  `debugResetLoopTokenLogoFailures` 一并复位）。生产路径仍是 `ResizeImage(NetworkImage)`。

### 2 社区详情绑定代币卡的 1H 走势（裁决 3）

`_BoundAssetSection` 以前只 watch `marketCandlesControllerProvider`，而会发起读取的
`TokenCardSparkline` 只在序列就绪后才挂载，于是永远停在「1H K 线读取中」。现在：

- 卡片自己在 loading 时 `load()` 该币的 1H 序列（与代币页同一个 provider、同一份保留；单飞，
  sparkline 挂载后不再发第二次）。
- 从社区 tab 进入（有列表提示）时，`_prefetchBoundAsset` 在报价之外同时持有并发起 1H K 线，
  与 `communities/{id}`、报价、挖矿读同一波。深链进入时随记录答复后发起（与报价相同）。
- 读不到时显示既有的「暂无走势：<原因>」文案，不再无限「读取中」。

### 3 快照打开预算（裁决 4）

`FileLoopSnapshotStore.openPersistent` 新增 `createTimeout`（默认 1000 ms）只约束「创建目录」一步；
定位目录、探针写 / 删、读旧文件仍是 400 ms。超时行为不变（回退仅内存 + 一行日志）。新增
`createDirectory` 参数供测试注入。

### Evidence

- `test/s94b_followups_test.dart`（11 例）：预算 5 s / 重试间隔 10 min；超预算后完成 → 显示真图、尺寸不变、
  只请求一次；404 → 首字母，9 分 59 秒内新行不请求，10 分钟时再请求一次，再次 404 后一小时仍不请求；
  超时（SocketException timed out）不记、下一行重试；明确失败分类表；从 tab 进入时 1H K 线与记录同波；
  深链进入读一次 1H 并画出走势线（`community-bound-asset-chart-line`）；K 线读失败时显示原因而非「读取中」；
  目录创建 600 ms 仍落盘；创建超过 `createTimeout` 回退内存；定位 600 ms 仍按 400 ms 回退。
  社区三例在去掉本次修复后失败（已核对）。
- 改断言不删：`test/s94_page_performance_test.dart` 的「3 s 无帧后进程内放弃」改为「超预算仍挂载下载、
  不记失败」；「400 被记住」保留。

### 待主代理确认

- 解码失败（服务端返回非图片 / 空文件）按任务单不记入失败表，因而每个新挂载的 tile 会各自重下一次。
  若要把它也算明确失败，改 `loopLogoFailureIsDefinite` 一处即可。
- 预算现在不改变任何可见行为（槽位本来就先画首字母），只用于日志；保留它是为了与任务单一致。

### S94b 主代理裁决（2026-09-28）
1. 解码失败不记失败表：接受（服务端代取图标后此路径消失）。
2. 5 s 预算保留，只作日志。
3. 0101 裁决 6 由「只记明确失败、10 分钟后再试一次」取代：确认。

## S96b（2026-09-28）· 图标主机：接受本构建的后端图片代理

基线 `integration/v2` 035fc75，分支 `fix/S96b-logo-host`。客户端单侧；不新增依赖、`pubspec.lock` 不变、
路由清单不变（93 条）、不改 API 形状。未触碰 `lib/features/profile`、`lib/features/chat/friends`、LOOP/ops。

### 背景

后端 S96（loop-api 决策 0089）起，所有 `logo.url` 都是
`<PUBLIC_BASE_URL>/v2/market/logos/eip155:56/<小写地址|native>.png`，服务端代取并缓存上游图片（中国网络连不上
GitHub）。客户端 `LoopV2ChainCodec.logoUrl` 只认三个外部主机；而且不在白名单里的 URL 不是「无图」，是
`invalidPayload`——**S96 部署后行情 / 代币页 / 钱包余额 / 自选 / 挖矿资产 / 资产搜索的整个响应都会解码失败**，
不只是图标变首字母。本单与后端 S96 必须同批上线。

### 规则（`lib/integrations/backend/v2/loop_v2_chain_codec.dart` `isAcceptedLogoUrl`）

- 三个外部主机照旧：`cdn.dexscreener.com`、`dd.dexscreener.com`、`raw.githubusercontent.com`，https、无凭据、
  无端口。保留原因：代理对 >256 KiB 的图回 `302` 指向它们，旧栈也仍下发它们。
- **本构建的后端 origin**：取 `AppConfig.fromEnvironment().backendBaseUrlForCurrentBuild` 经
  `LoopBackendEndpoint.tryParse`——与 `loopBackendEndpointProvider` / `LoopDioFactory.createLoopBackend`
  同一个输入、同一个解析函数。dev / staging / hk 各自的域名自然覆盖；别的栈的 URL 在本构建里被拒。
  要求 scheme、host、port 与 origin 完全一致；无凭据、无 query、无 fragment；路径必须完整匹配 OpenAPI
  锚定的 `^/v2/market/logos/eip155:56/(0x[0-9a-f]{40}|native)\.png$`（同源的其它路径、其它链、大写地址、
  `.svg` 一律拒）。https 恒可；http 只在 origin 本身是 loopback（`localhost` / `127.0.0.1` / `::1`）且
  非 release 构建时允许——与网络层的信任边界相同。
- 构建没有后端（`LOOP_BACKEND_BASE_URL` 为空，如 Preview）：只接受三个外部主机。
- 其它一切不加载：`logoUrl` 返回 `null`，该行画首字母，debug 日志记一行被拒的 `scheme://host`（裁决 1，见下）。
  `logo` 块自身的形状（`status` 两变体字段互斥、`source` 只在两者之内）仍严格，违反仍是 `invalidPayload`。
- `loopRemoteLogoUri`（图片组件自己的第二道门）同步放开 loopback http（仅非 release），否则本机 http
  开发栈的代理图会被组件再挡一次。
- 测试接缝：`LoopV2ChainCodec.debugSetLogoOrigin`（`@visibleForTesting`；`null` 复位为构建值）。

### 按字节解码

代理 URL 恒以 `.png` 结尾，内容可能是 JPEG / WebP / GIF。`LoopTokenLogo` 用
`ResizeImage(NetworkImage)`，引擎按字节签名选解码器，扩展名与 `Content-Type` 都不参与；客户端没有任何按扩展名
的判断。测试用真实 loopback 服务器回 `image/png` 头 + JPEG 字节、`image/png` 头 + WebP 字节，均解码成功。

### 失败记忆

S94b 的「明确失败记 10 分钟、再试一次」按 URL 记，对代理 URL 照常生效：代理 `404`（所有上游都没有图，服务端
记 24 h）与 `502`（上游不可达）都是 `NetworkImageLoadException`，记入失败表。`302` 到上游后在中国网络失败时
按原规则分类（DNS / 拒绝记，超时不记）。

### Evidence

`test/s96b_logo_host_test.dart`（11 例）：后端 https origin 的地址与 `native` 被接受（含显式 `:443`）；
staging 构建拒 dev 的 URL；同源 11 种非代理路径被拒（`/v2/market/overview`、`/v1/…`、`eip155:97`、`.svg`、
大写地址、`..`、query、fragment、前缀路径等）；scheme / 端口 / 凭据 / 子域不一致被拒；loopback http origin
被接受且另一端口被拒、非 loopback http 被组件拒；无后端构建只认外部主机；三个外部主机仍接受；随机主机、
仿冒后缀、http / 端口版 GitHub 被拒；真实 loopback 代理回 JPEG / WebP 字节的 `.png` 按字节解码；代理 404 为
`NetworkImageLoadException(404)` 且被判为明确失败。原有 `s78b` 的外部主机与非法载荷用例不改、仍通过。

### 待主代理确认

1. 不认的 logo 主机仍让**整个响应** `invalidPayload`（沿用 0084 的严格解码）。若后端某环境 `PUBLIC_BASE_URL`
   与客户端构建的 `LOOP_BACKEND_BASE_URL` 不一致（例如走另一个域名或 CDN），行情等整页会失败而不是只丢图标。
   dev 已核对一致（`https://api-dev.quant-dinger.cc`）；staging / hk 需部署时核对，或裁决改为「不认 → 首字母」。
2. 路径按 OpenAPI 完整 pattern 校验（比任务单的「前缀」更严）。服务端将来加链或改文件名规则时客户端需同步。

### S96b 主代理裁决（2026-09-28）

1. 不认的主机 = 无图（首字母），不再让整个响应 `invalidPayload`：0072 规定 logo 不是市场事实，域名或 CDN
   变化不该让行情 / 钱包整页不可用。接受规则（三个外部主机 + 本构建后端 origin + 完整代理路径）不变，只是拒绝时
   降级为 monogram，并在 debug 日志记一行被拒主机。`s78b` 原「非法主机 = 非法载荷」用例拆为「主机不认 → null」
   与「块形状越界 → 非法载荷」两例；`s96b` 用例的拒绝断言改为 `isNull`。
2. 路径按 OpenAPI 完整 pattern 校验：接受。
3. 误停 S97 测试进程：S97 已重跑门禁并合并，无需处理。
