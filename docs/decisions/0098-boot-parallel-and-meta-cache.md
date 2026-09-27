# 0098 · 启动请求并行化与 D0 元数据 60 秒缓存

## Status

Proposed 2026-09-27。S88c，客户端单侧。基线 `integration/v2` 5785f0c。不改任何 API 形状、
不改严格 wire decoder、不新增依赖（`pubspec.lock` 未变）、不改路由清单（93 条）、不碰
签名路径与 `lib/features/launch/*`、`lib/widgets/loop_accordion_strip.dart`。

## Context

用户反映钱包页慢。主代理实测：服务端单请求平均 364 ms，手机经隧道单次往返 0.5–2.3 s。
总时延约等于**关键路径上串行往返的次数 × 单次往返**，所以本单只数往返，不调服务端。

### 改前：冷启动到钱包页可交互的实际请求（已登录、会话日志可复用、无冷启动快照）

逐个从 `lib/main.dart` → `LoopApp.initState` → 各 coordinator / controller 读出来的，
标注「真依赖」= 后一个需要前一个的结果；「写成了顺序」= 没有数据依赖，只是代码顺序 await。

| # | 时机 | 请求 | 等谁 | 判定 |
|---|------|------|------|------|
| 0 | `main()` 首帧前 | （本地）显示偏好 → 快照文件打开（≤3×400 ms）→ Firebase 初始化 | 依次 await | 写成了顺序（三者互不相关） |
| 1 | `initState` t0 | `GET /v2/meta/client-policy` ‖ `GET /v2/meta/capabilities` | 无 | 已并行（`Future.wait`，D0 起就是） |
| 2 | Privy 恢复会话后 | Privy `getAccessToken`（Privy 网络，非 LOOP） | 会话 | 真依赖 |
| 3 | 同上 | `GET /v2/account/me` | 2 的 token | 真依赖（核对本地会话日志与服务端账号一致才可复用） |
| 3b | 首次登录才有 | `POST /v2/session/bootstrap` | 3 的答复 | 真依赖 |
| 4 | bootstrap authorized | `GET /v2/profile` | 3（`LoopAuthenticatedSession` 先 `_requireBootstrap`） | 真依赖（会话前置条件，保持串行） |
| 4' | 同上 | `/v1/chat/token`（Stream presence，unawaited）、推送注册（条件满足才发） | 3 | 已与 4 并行 |
| 5 | profile 答复 `active` → 落 Community 后页面挂载 | `GET /v2/community/home` | 4（F1：启动页等 profile，Community 页之后才挂载才发读） | **写成了顺序**：home 读不需要 profile 的任何字段 |
| 6 | 用户点「钱包」 | 钱包页门禁 `walletRead`+`bscRead` | 1（早已返回） | 真依赖（fail-closed 门禁） |
| 7 | 同上 | `GET /v2/wallets` ‖ `GET /v2/mining/assets` | 6 | 已并行 |
| 8 | 7 返回 | `GET /v2/wallets/{walletId}/balances` | 7 的 `activeWalletId` | 真依赖 |
| 9 | 下拉刷新 / 失败条「重试」 | `GET /v2/wallets` **然后** `…/balances` | 前者 await 完才发后者 | **写成了顺序**：刷新的是屏上已有 walletId 的余额 |

另外核对了主代理的假设「页面切换重复打 capabilities」：**在 5785f0c 上不成立**。
`loopV2MetaSnapshotProvider` 被 `LoopApp` 常驻监听，成功一次后整个进程不再重读（只有失败会按
0064 的阶梯重试）。代价是另一面：服务端改了 capability，客户端要到下次冷启动才知道。

关键路径（会话就绪之后）：`account/me → profile → community/home` 才有 Community 内容（3 次
往返）；点钱包后 `wallets → balances` 才有资产行（2 次往返）。合计 5 次串行往返，其中 2 次
（5、9）没有数据依赖。

## Decision

### 1 首帧前三步同时开始（`lib/main.dart`）

快照文件打开、Firebase 初始化先启动为 Future，再 `await` 显示偏好，然后依次取回另外两个。
三者都自带上限并在失败时回退，不会抛出；harness 要求的字面量
`await bootstrapSharedPreferencesDisplayPreferences()` 与 Firebase 门控不变。

### 2 首屏预读（`lib/app/session/loop_boot_warmup.dart`，`LoopApp` 常驻监听）

- **Community**：账号已签入（principal 非空）、`community` 门禁开、适配器为 production、且
  profile 尚未答复「仍在开户流程」时，立刻 `communityHomeController.load()`。请求在
  `LoopAuthenticatedSession` 里照常等 bootstrap，然后与 `GET /v2/profile` **同时**发出。
- **钱包**：profile 答复 `active`、钱包适配器为 production、`walletRead` 与 `bscRead` 都
  可用时，`walletDirectoryController.load()`，拿到 `activeWalletId` 后
  `walletBalancesController(walletId).load()`。与 Community 的读并行，不等用户点 Tab。
- 预读走页面自己的 controller：页面打开时要么已有答复，要么加入进行中的同一个读（single
  flight），不会重复请求；持有 controller 只到读完为止，之后由 0095 的 5 分钟保留决定去留。
- 预读失败且没有值时 `invalidate` 该 controller，页面打开时从自己的新读开始，不会先闪一个
  它自己没发过的失败。
- 每个账号每进程一次（provider watch principal，换账号换实例）。门禁关闭、未观测、
  Preview 适配器、开户流程中的账号一律不预读——**不发页面自己不会发的请求**。

### 3 下拉刷新同时发两个读（`wallet_read_screens.dart::_refreshWallet`）

目录与屏上钱包的余额用 `Future.wait` 同时 reload。若新目录换了 active 钱包，页面按新 id
重建，由该钱包自己的块去读余额。

### 4 D0 元数据 60 秒缓存 + stale-while-revalidate（`loop_v2_meta_providers.dart`）

- `LoopV2MetaCache`（每个 backend origin 一个，内存）：只存**成功**的观测与收到时刻；
  `LoopV2MetaCachePolicy.freshFor = 60 s`；single-flight；两份文档仍在
  `Future.wait<Object>` 里同时请求。失败不入缓存，0064 的重试阶梯照旧负责。
- `loopV2MetaSnapshotProvider` 改为从缓存取：60 秒内无论 provider 被重建多少次都不发请求。
- `LoopV2MetaObserver.observe`（导航、回前台、网络恢复三个既有触发点）：上次失败 → 照旧重试；
  上次成功但已过 60 秒 → 后台重读。Riverpod 在重读期间保留旧值（`AsyncLoading` 带
  previous），`loopCapabilityProvider` 继续给出旧 projection；新值落地即替换——包括把
  `available` 变成 `unavailable`，页面随即按现有 block 规则关门。触发发生在 router
  redirect 里，所以失效动作放在 microtask，不在当前同步流程里改 provider。
- 重读失败：保留上一份答复（与改前「永远用第一份」相比不更松），`unreachable` 置真，进入
  0064 阶梯重试；失败不会把旧答复重新标记为新鲜。
- 强制刷新入口：`LoopV2MetaObserver.refreshNow()`，features 通过
  `lib/core/policy/loop_capability_refresh.dart` 的 `loopCapabilityRefreshProvider` 调用：
  `await ref.read(loopCapabilityRefreshProvider)();` 然后照常读 `loopCapabilityProvider`。
  已在进行中的读会被加入，不重复。
- 与 0095 快照：D0 文档不进 `loop_snapshot_store`，快照格式、key、清理时机均未改。

### 改后：同一条路径分几波

| 波 | 内容 | 依赖 |
|----|------|------|
| 首帧前 | 显示偏好 ‖ 快照文件 ‖ Firebase | 无 |
| W1 t0 | meta 两份 | 无 |
| W2 | `account/me`（首次登录再加 `bootstrap`） | Privy token |
| W3 | `profile` ‖ `community/home` ‖ Stream token | W2 authorized |
| W4 | `wallets` | W3 的 profile = active |
| W5 | `balances` | W4 的 `activeWalletId` |
| 点钱包 | `mining/assets`（未改）；目录与余额已在内存 | — |

- 会话就绪 → Community 内容：3 次往返 → **2 次**。
- 点钱包 → 资产行：2 次往返 → **0 次**（W4/W5 已完成时）；用户点得比 W5 快时只剩未完成
  的那一段。
- 下拉刷新：2 次往返 → **1 次**。
- 页面切换：60 秒内 0 次 meta 请求（改前也是 0 次）；超过 60 秒的下一次导航/回前台后台
  重读一对（改前永不重读）。

## Consequences

- 一个 active 账号每次冷启动多发 `GET /v2/wallets` 与 `…/balances` 各一次，即使这次没打开
  钱包。余额读会落到 BSC RPC。
- 开户流程中的账号在 profile 答复前可能被预读一次 `community/home`（只发生在 profile 未答复
  期间；失败即丢弃）。
- 服务端关闭一个 capability 后，最迟在下一次「超过 60 秒后的导航/回前台/网络恢复」生效，
  而不是下次冷启动。
- 预读与 D0 缓存都只在生产组合里有请求；Preview 与测试默认适配器不发。

## Evidence

`test/s88c_boot_parallel_meta_cache_test.dart`（12 例）：

- a) 并行：policy 与 capabilities 在任一返回前都已发出、且后发的先回也不阻塞；Community 首读
  在 landing 未知（profile 未答复）时已发出；钱包目录在 landing 后、未打开 Tab 就发出，余额
  随目录后发出，页面随后 `load()` 不再发请求；下拉刷新时目录与余额都在途且都未返回。
- 不预读：钱包门禁关闭 / 开户流程账号 / Preview 适配器 / community 门禁关闭；预读失败不留失败态。
- b) 60 s：30 s、59 s 的触发与 provider 重建都不发请求；61 s 的触发发一对，期间旧值可读、
  重复触发不加倍；新答复开启新窗口；强制刷新在窗口内立即发、两个并发调用只发一对；重读失败保留
  旧值、进入重试阶梯。
- c) `walletRead` 由 available 改为 unavailable：窗口内不变；61 s 后触发刷新，
  `walletCapabilityBlocks` 为真；挂载的钱包页出现 `wallet-capability-block`。

## 主代理裁决（2026-09-27）

状态：Accepted，随 `integration/v2` 合并。

1. 预读保留目录 + 余额两步：钱包页慢是用户当前最直接的抱怨，每次冷启动多一次点读可接受；余额点读走免费端点，不占付费额度。
2. 开户中账号多一次 `community/home` 读，失败即丢弃：接受。
3. 不放宽 `LoopAuthenticatedSession` 的前置语义（profile/home 仍等 bootstrap）。
4. 重读失败沿用旧值，不新增「N 分钟拿不到新文档就关门」规则。
5. meta 不进冷启动快照：用旧文档开门不算 fail-closed。
6. 待办 S88c2（S89a-fix 合并后开单）：强制刷新接进 send / swap / Launch 的 Sign sheet 打开前；`MiningReadController` 接 0095 保留机制。
