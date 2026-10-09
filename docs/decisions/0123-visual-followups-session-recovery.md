# 0123 · 视觉收尾 + 断网会话自恢复（S121c）

## Status

Accepted 2026-10-09。主代理下单（S121c），本单设计兼实现。基线 `integration/v2` 2c4708b（含 S121a / S121b）。
不新增依赖、`pubspec.lock` 不变、路由清单不变。

## Context

- S121b（0122）「未做」三项：钱包资产行未改 OKX 行、代币页「关于」链接行无图标、聊天行之间仍有 Stream 分隔线；
  另有主代理追加：发射台交易中胶囊、领奖台名字两行与等高、列表到底不画「没有更多」的核对。
- 模拟器验收（`docs/acceptance/2026-10-08-s113-s114-emulator.md`）记录「会话失效不自恢复」：网络抖动后各页「当前不可用」，
  网络恢复回不来，只有重启 App。

## Decision

### 1. 断网会话自恢复

**复现与根因**（模拟器 loop_pixel7_api34，带临时日志的 profile 包，日志已删）：

1. **进程在断网时被重启**（Android 杀后台、模拟器负载高时常见；对测试者看起来是「同一个会话」）→ Privy 原生 SDK 在
   `handleNetworkOfflineAtInit` / `restorePriorSessionIfNeeded` 里发布 `AuthenticatedUnverified`（反编译 privy-core 0.12.1
   `RealInternalAuthManager` 可见：只有这两条恢复路径会发这个状态，运行中的 token 刷新失败不会）。
2. LOOP 的 `LoopSessionController` 把它映射为 `authenticatedUnverified` → `canUseProviderBackedFeatures == false` →
   `loopBootstrapPrincipalKeyProvider` 为 null → `loopAuthenticatedSessionProvider` 为 null → 39 个 v2 网关全部换成
   `Unavailable*Gateway` → 链读控制器初始态为 `unavailable`，页面写「该内容当前不可用 / 暂时读不到链上数据」。
   这是把「离线」说成了「不可用」。
3. 恢复完全依赖 Privy 自己的网络监视器在网络回来后重新确认并发布 `Authenticated`；privy_flutter 0.10.1 没有暴露
   `onNetworkRestored()`。实测本机这次约 60–90 秒后才回来（模拟器 load average 12–15、系统反复 ANR），验收那次在观察窗口内没回来。
4. 另一条路径（进程存活时断网）：会话一直是 `authenticated`，但 `LoopBootstrapSession._authorize` 把任何失败
   （包括超时 / 断连）都折成 `unavailable`，`LoopAuthenticatedSession` 再抛 `LoopBackendFailure(unavailable)`，页面同样写
   「不可用」；网络恢复后没有任何东西重读已经失败的块（只有 meta 与 Stream 在 `connectivity` 事件上重试）。

**修法**（原则：网络失败只能标「离线」，不能降级成「不可用」；网络恢复 / App 回前台后自动重试）：

- `LoopBootstrapSession.lastTransportFailure`：bootstrap 因 `connection` / `timeout` 失败时记下，下一次尝试清掉；
  `LoopAuthenticatedSession._requireBootstrap` 抛出这个传输失败（→ 页面「离线 / 读取超时」+ 重试），只有 LOOP 或 Privy 明确拒绝时才是 `unavailable`。
- Privy 刷新 token 时连不上（`Failure` 文案按 `PrivyFailureClassifier` 判为 network）→ `PrivyGatewayException(kind: network)`
  → access-token 源转成 `LoopBackendFailure(connection)`，同样是离线而不是登录失效。
- `loopNetworkRecoveryTickProvider`（`lib/core/network/loop_connectivity_signal.dart`）：`connectivity_plus` 恢复事件与
  App resume 各 bump 一次。`LoopChainReadController`（钱包 / 行情 / MEME / 通知 / 设置 / 安全 / 关于）、`MiningReadController`
  （情报算力榜）、`CommunityHomeController` 与 `CommunityDiscoverController`（广场）监听它：失败种类是
  offline / timedOut / unavailable / readFailed / unexpected 且不在请求中时自动 `reload()`；已有答案或服务端拒绝（权限、冲突等）不重读。
- `loopSessionAwaitingNetworkProvider`：App 壳按 `session.mode == authenticatedUnverified` 置位；上述控制器在网关缺席且该标志为真时
  初始态为 `offline`（而非 `unavailable`），重试仍失败也报 `offline`；钱包总额占位由「暂不可用」改为「离线」。默认 false，
  不经过 App 壳的测试与页面行为不变。
- `LoopSessionController.recheckAfterNetwork()`：恢复事件时若仍是 `authenticatedUnverified`，读一次 Privy 当前状态，
  **只接受 `authenticated`**，从不签出。安全约束不变：未确认的会话仍不能用 provider-backed 能力（`canUseProviderBackedFeatures`
  仍只认 `authenticated`）。
- `_recoverAfterNetwork`（`lib/app.dart`）：恢复事件 → 会话复查 + 已登录但 bootstrap 未完成时 `authorize()` + bump tick。

**曾做后撤回**：第一版在恢复事件上对 `restoreUnavailable` 自动调用 `retryRestore()`。它会花掉冷启动的 4 秒宽限（决策 0064 §5），
Privy 冷启动时的「过早 Unauthenticated」就会直接落到登录表单——模拟器上复现了一次误签出（凭据完好，强停重开即恢复）。已删除，
未决态仍只由用户按「重试」，并有测试锁住。

**实测**（`docs/evidence/2026-10-09-s121c/06*`）：

- 进程存活断网：钱包保留数字 +「更新失败，显示的是 37 秒前读到的数据 · 重试」（06c）；关飞行模式后不碰屏幕，约 45 秒内自动刷新、条消失、观察时间更新（06d）。
- 断网冷启动：本次 Privy 发的是 `Unauthenticated`（不是 `AuthenticatedUnverified`），页面落到登录表单（06a）；
  联网后约 1 分钟内 Privy 发 `Authenticated`，自动回到聊天列表、未做任何操作（06b）。另一次（临时日志包）同样场景 Privy 发的是
  `AuthenticatedUnverified`，网络恢复后约 90 秒回到 `authenticated`，bootstrap 与各页随之恢复。

### 2. 视觉收尾（每页六行计划：色 / 字 / 布局 / 记忆点 / 删掉什么 / 自检）

**钱包资产行（OKX 4908）**
- 色：涨跌只在 96×44 胶囊（riseSoft/fallSoft 底 + rise/fall 字）；数量 Chalk；≈$ 与副行 text2；derived 标记 text3。
- 字：符号 18 粗 / 名称 14 灰；数量 18 粗 / ≈$ 14 灰；derived 标记 11。
- 布局：`LoopQuoteRow`（Logo 36 圆）+ 最右涨跌胶囊；「以 WBNB 计价 / 待确认 / 数据源尚未对齐」进副行尾部小字（`subtitleMark`）；
  名称与符号相同（BNB / BNB）时只留标记；零余额开关改为居中一行文字「显示 N 项零余额资产 ⌄ / 隐藏零余额资产 ⌃」；
  Launch 链行同结构（tBNB + 测试网徽章 / 手续费保留 · 余额 / 可动用），无胶囊（测试网无价无涨跌）。
- 记忆点：右侧一列对齐的涨跌胶囊。
- 删掉什么：勾选框、「N 项」计数、副行里的「· ▲x%」、Launch 行灰卡片；自评再删一个：Launch 行副行与测试网徽章重复的「BSC 测试网」。
- 自检：对照 4908 结构一致；首轮截图发现胶囊不齐（`LoopQuoteRow` 右列 `Flexible` 与左列平分剩余宽度，窄数字留空），
  改为右列按内容宽、上限 `min(140, 行宽×0.36)`，所有行胶囊贴同一右缘（行情 / 发射台同受益）。

**发射台交易中胶囊**
- 色：card2 底；百分比 Lime；4px 条 Lime，轨道 line 色。
- 字：百分比 16 粗 tabular。
- 布局：百分比在上、4px 条在下（起步不足 4% 时最少画 4%，不会读成 0）。
- 记忆点：一列胶囊里可横向比较的进度条。
- 删掉什么：胶囊背后的 limeSoft 填充（与条重复）。
- 自检：两种都做了并在同一包里截图比较——「环 + 百分比」（02a）在 0.1% 时环几乎不可见、数字偏右；条（02）可读、与已毕业胶囊居中对齐。选条，环的代码已删。已毕业不变。

**领奖台**：卡片等高（`IntrinsicHeight` + stretch）；名字最多 2 行省略；第一名脸 56、其余 48；第二、三名多余高度放在脸上方（站得比冠军低），
数值在三张卡同一基线。删掉：第一名靠「高一截」区分（改为皇冠 + 大脸 + 亮面）。

**聊天列表**：去 Stream 默认分隔线；行间不再额外加 12（Stream 行自带上下内边距，头像间距已约 38；加 12 后行距 92 显得松，见 04 与上一轮对比）；
列表底部 padding = 底栏预留 90 + 「发起」56 + 32 = 178（只给 88 时末行仍在按钮下，截图 04a；178 时末行距按钮 ≈ 50，04b）。

**代币页「关于」**：MEME 代币页 X / Telegram 用 `link`、官网 `globe`、外盘行情 `chart`、区块浏览器 `link`；代币详情「进入 LOOP 社区」用 `community`。未新增图标。

**「没有更多」**：发射台 / 行情 / 算力榜 S121b 已移除（核对无误）；本单再移除广场社区列表、广场语音房、社区目录三处，末尾只留 12 空白（key 保留）。
保留：提醒列表、触发记录、成员列表、他人主页交易、语音房名单、开户选社区——这些是二级记录列表，原决策要求明确的结束标记，不在 S121 §1.1.1 第 10 条的主列表范围。

## Consequences

- 新增测试：`test/s121c_session_recovery_test.dart`（bootstrap 超时 → 会话仍在、请求报 timeout → 恢复后同一会话成功；拒绝仍是不可用；
  离线失败的块在 tick 上重读、已有答案不重读；未确认会话的缺席网关读作 offline；复查只接受 authenticated；未决态不被自动重试；钱包页离线态）、
  `test/s121c_visual_followups_test.dart`（1–5、7）。更新：s5 / s114 钱包测试（胶囊取代副行涨跌、文字开关）、s121b 领奖台等高、s111 广场列表末尾。
- `LoopQuoteRow` 新增 `subtitleMark` / `subtitleMarkKey`；右列宽度规则改变（见上）。
- 未做 / 需要决策：
  1. 断网冷启动时 Privy 可能直接给 `Unauthenticated`，用户离线期间会看到登录表单（联网后自动恢复，无需操作）。要避免需要在
     「设备无传输」时把冷启动的 Unauthenticated 当成未决态——这改动 0064 的签出语义，需主代理裁决。
  2. 主动触发 Privy 重新确认需要 `Privy.onNetworkRestored()`；privy_flutter 0.10.1 未暴露，Android 侧只能反射调用 privy-core
     （R8 风险）或给 app 模块加 `compileOnly io.privy:privy-core`（依赖决策）。本单未做。
  3. 模拟器上本 App 的 Kotlin `DefaultDispatcher` 线程空闲时占 ~120% CPU（线程转储里是大量短协程任务，疑似 Privy / Stream 原生侧），
     伴随系统反复 ANR；非本单引入（旧包同样），建议单独排查。
  4. 聊天列表的「无分隔线 / 末行避让」只有源码与常量级测试（渲染 Stream 列表需要 Stream 客户端假体），以截图 04 / 04b 为准。

### 截图（`LOOP/docs/evidence/2026-10-09-s121c/`，模拟器 loop_pixel7_api34，dev 数据，账号 cy）

- `01-wallet-okx-asset-rows.png` 资产行 + 胶囊 + 文字开关；`01a-…before-trim` / `01b-wallet-launch-chain-row.png` Launch 行删重复链名前后。
- `02a-launchpad-pill-ring-candidate.png` 环候选；`02-launchpad-pill-bar-chosen.png` 选定的条。
- `03a-rank-podium-equal-height-first-pass.png` 等高首轮（二三名中段空）；`03-rank-podium-equal-height.png` 最终。
- `04-chat-no-hairline.png`；`04a-chat-end-padding-88-too-short.png`；`04b-chat-end-clears-fab.png`。
- `05-meme-token-about-link-icons.png`、`05a-meme-token-about-dex-explorer-icons.png`。
- `06a-offline-cold-start-privy-unauthenticated.png`、`06b-offline-cold-start-recovered-without-action.png`、
  `06c-wallet-offline-mid-session.png`、`06d-wallet-recovered-after-network.png`。
