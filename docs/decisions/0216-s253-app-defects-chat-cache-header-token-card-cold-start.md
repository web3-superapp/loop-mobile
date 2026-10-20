# 0216 · S253 App 缺陷批：聊天缓存不应用服务端删除、群聊顶栏缺群名、代币卡误报离线、冷启动闪登录页（S253-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` faaccbc7。依据：`LOOP/docs/integration/S245/report.md` 残留 1 与 `notes.md` 18:05 条、
`S240/report.md`「另记」与 `notes.md` 17:16 条、`S237/notes.md` 01c 与 §148 第 1 条、S250 观察 1。
只改 App：不新增依赖、路由、字体、颜色 token，`pubspec.lock` 不变；新增的网络读只有 Stream 官方 `queryChannel`（`watch: false`），不改 loop-api。

## Context

1. 服务端 `DELETE /messages/{id}?hard=true` 删掉 DeFi 早读会 20 条消息后，晚风这台模拟器（Android 用户 12）仍显示；强停、断网重连都不消失，清数据才消失。
2. 普通群（好友建的群）顶栏写死「群聊」，不显示群名；社区官方群顶栏只有「N 在线」，没有成员数。
3. 聊天里由合约地址识别出的代币卡偶发「设备离线，没有读这个合约」，网络正常，点重试像没反应。
4. 已登录用户冷启动在「正在恢复登录状态」与「正在准备你的账号」之间闪一帧登录页（「欢迎来到 LOOP / 使用 Google 继续」）。
5. 签名单与交易详情「网络：BNB Smart Chain」在测试网 staging 也这么显示。

## Decision

### 1. 本地聊天副本与服务端核对删除（`LoopStreamDeletedMessageReconciler`）

**现场（2026-10-20 17:40，emulator-5554 用户 12，build 32 cb499860）**：拉 `/data/user/12/com.cywd.loop/app_flutter/db_loop_c6c04173….sqlite`：
`connection_events.last_sync_at = 2026-10-19T09:59:20.007Z`，恰是 20 条删除事件里最后一条的时间——Stream 的 `client.sync` 确实回放过这批事件；
但 20 条里 7 条（较新的、当时在内存窗口里的）已删，13 条（09-28～09-30 的旧消息，不在内存窗口）仍在 `messages` 表里，另有 1 条 `created_at = 0001-01-01`、正文为空的残行（删除事件里的消息壳被 upsert 进来）。

**根因**：`stream_chat 10.3.0` 的删除处理（`channel.dart` `_listenMessageDeleted` → `deleteMessage`）只在事件带 `hard_delete: true` 时按 id 删本地库；
否则走 `_updateMessages(upsert: false)`，**只改内存窗口里已有的消息**，窗口外的落库消息原样保留。`sync` 回放后把同步标记推到最后一条事件，
同一批事件不会再回放；之后每次进频道，`queryChannels` 的结果与本地状态是**合并**（`mergeSorted`），不会删本地多出来的消息。于是这些行永久留在本地。

**修法**：客户端拿服务端的最新一页对账，按 id 删本地多出来的消息。

- 读：`client.queryChannel(type, id, messages.limit = 100, watch: false)`，只读不合并。只在 websocket 已连上时发。
- 判：本地副本 = 内存 `channel.state.messages` ∪ 本地库 `getMessagesByCid`（读服务端之前取，读的过程中到达的新消息不参与判断）。
  只判断服务端已接收的消息（排除 sending / failed、`ephemeral` / `error`、只在线程里的回复）；
  服务端这一页不满 100 条 = 整个频道都在页里，本地多出来的全删；满 100 条只判断这一页覆盖的时间窗（严格晚于页内最早一条）。
- 删：内存里的走 `channel.state.removeMessage`（SDK 自己同时删库），只在库里的走 `deleteMessageByIds` + `deletePinnedMessageByIds`。读失败什么都不删。
- 时机：进频道（成员查询答复后）、频道页打开时连接恢复（`connection.recovered`）、会话列表下拉刷新（前 8 个会话依次对账）。同一频道并发请求共用一次读。

不改的：不 flush 整个本地库（会丢离线首屏，决策 0132）；不改 Stream 的 `sync` 节奏。

### 2. 会话顶栏：群名 + 成员数

- 普通群：顶栏标题读本客户端持有的 Stream 频道名（同会话列表的显示闸 `loopStoredConversationName`），副标题「N 位成员」（频道 `member_count`）；
  频道没到或没有合规名字时仍是「群聊」；标题单行省略。频道到达或改名时随 `channelStateStream` 刷新。
- 社区官方群：副标题从「N 在线」改为「128 成员 · 1 在线」（社区记录的成员数，格式同社区主页）；有副标题时标题按 `LoopTopbar` 规则单行省略。
- 私聊：不改。顶栏已是对方昵称（会话列表把 LOOP 私聊索引里的对方资料作为 `DirectMessageTarget` 带进页面，决策 0112 / R14-3）；
  名字只来自随导航传入的资料，这是 `check_harness.py` R14-3 守卫的规则，本批不放宽。没有随导航带资料的入口（推送、转发）仍显示「私聊」。

### 3. 代币卡：「请求失败」与「真离线」分开，失败自动重试一次

- 根因：后端读失败里的 `connection` 一律映射成 `LoopChainFailureKind.offline`，其中包括连接被对端关掉、Privy 取 token 网络抖动等「设备有网但这次没读到」的情况；卡片据此写「设备离线」。
  重试同样快速失败，看起来像没反应；退出重进是新的连接，所以正常。
- 修法：卡片读到 `offline` 时再问一次平台 `loopDeviceTransportProvider.hasTransport()`；只有平台明确说「没有任何网络」才显示「设备离线，没有读这个合约」，
  其余（有网、平台答不上来）记为 `readFailed`。`readFailed` / `timedOut` 显示「加载失败，点按重试」，整行可点、带重试键。
- 自动重试一次：连接恢复 / 回到前台（`loopNetworkRecoveryTickProvider`）或卡片再次出现（重新挂载）时，对暂时性失败（offline / timedOut / readFailed）自动 `resolve(force: true)` 一次；
  一次失败只换一次自动重试，读到答复后清零。「未收录」、能力关闭、限流不自动重试。

### 4. 冷启动不再闪登录页

- 根因：`/auth` 是初始路由。会话从 `restoring` 变成 `authenticated` 时，`PrivyLoginScreen` 在同一帧按新状态重建（不再是 restoring 分支），画出登录表单；
  路由器 `refresh()` 把人挪到 `/splash` 要晚一到两帧。那一两帧就是闪的登录页。
- 修法：`PrivyLoginScreen` 在 `session.canEnterProduct` 时画静态的品牌帧（`PrivySessionHandoverFrame`，与前后两帧同底同字标，无动画、无按钮），等路由器带走；
  恢复失败 / 明确登出仍然进登录表单（决策 0064 / 0124 不变）。

### 5. 「网络：BNB Smart Chain」——不改，确认来源

签名单与交易详情的「网络」值都来自链名映射 `loopChainName(chainId)`（`lib/core/chain/loop_chain_ids.dart`）：主链槽 → 「BNB Smart Chain」；
Launch 测试网槽在测试提示开关关闭时也显示「BNB Smart Chain」（S237 · 决策 0204 的去测试提示口径），开关打开时显示测试网名。
调用点：`meme_signing.dart`、`launch2_signing.dart`、`launch_signing.dart`、`mining_rewards_signing.dart`、`meme_token_screen.dart`、
钱包流水详情 `_assetChainName`、Launch2 创建签名 `launch2ChainLabel`。不是写死的字符串，本批不改。

## Consequences

- 每次打开一个会话多一次 Stream `queryChannel`（≤100 条，不 watch）；下拉刷新会话列表多至 8 次。
- 新测试：`test/s253_app_defects_test.dart`（对账纯函数 / 内存 + 本地库删除 / 并发单飞 / 读失败不删 / 未连接不读；群顶栏）、
  `test/s52_chat_token_card_test.dart` S253 组（有网失败不是离线、平台答不上来不是离线、超时、连接恢复自动重试一次、一次失败只自动重试一次、重新出现时重试、未收录不重试）、
  `test/privy_login_screen_test.dart`「a restored session never draws the credential form」（去掉修复时该测试失败）。
- 改动的既有断言：`communication_pages_test.dart` 社区群聊顶栏标题从两行改为一行（副标题出现后 `LoopTopbar` 让出第二行），并断言「128 成员」。

## Verification（2026-10-20 18:32–18:40，emulator-5554 Android 用户 12「晚风」，香港 staging，本分支 staging profile 包覆盖安装、保留数据）

- 1：装包前本地库 DeFi 早读会 40 行、20 个已删 id 里 13 个仍在；装包后进一次频道，本地库 27 行、已删 id 0 个；从顶到底滚动整段会话，
  hhh / S99-reply-test / 1 / 123 / 456 / 789 / 10–15 都不再出现（`LOOP/docs/integration/S253/logs/01-*`）。
- 2：普通群顶栏「BSC 早期盘互助 / 4 位成员」；社区群「DeFi 早读会 / 11 成员 · 1 在线」（`shots/01b`、`02b`，对照 `01a`、`02a`）。
- 4：三次冷启动逐帧截屏（约 0.3 s 一帧）：原生启动图 →「正在恢复登录状态」→「正在准备你的账号」→ 会话列表，未出现登录表单（`shots/04b`）。
  一两帧的闪烁截屏抓不稳，回归由 widget 测试保证（去掉修复时该测试失败）。
- 3：现场未复现到偶发失败；由 widget 测试覆盖。
