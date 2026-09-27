# 0099 · S88d 四件小事：签名前强制刷新 capability、挖矿读保留、离线卡文案、Launch 空分段文案

## Status

Proposed 2026-09-27。S88d，客户端单侧。基线 `integration/v2` 474dad4。不新增依赖、
`pubspec.lock` 不变、不改路由清单（93 条）、不改 API 形状与严格解码。

## Context

0098 留下两项待办：签名出口打开前应拿服务端当前的 capability（而不是最长 60 秒前的答复），
`MiningReadController` 应与钱包读一样跨页面保留。主代理在 Android 模拟器上看到首读期间连接被系统
重置时，离线卡写「离线 · 显示缓存」而右上角是「缓存 —」，自相矛盾。Launch 目录的空分段文案仍写
「分段只反映排期状态」，而后端 S83b7 起分段已按链上 saleState 划分。

## Decision

1. **签名出口前强制刷新 capability**（0098 裁决 6 的遗留）。
   `lib/core/policy/loop_capability_refresh.dart` 新增
   `loopRefreshCapabilitiesBeforeSigning(ref)`：`await loopCapabilityRefreshProvider()`，
   任何失败都吞掉、沿用当前答复（0098 裁决 4，不新增关门规则）。接入四处：
   - Send `send-confirm`：点「确认发送」后先刷新，再按原门禁
     `moneyActionBlocks(mode, sendApprovals)` 判定；关门则不开 sheet，页面自己的
     `send-confirm-capability-block` 出现。
   - Swap：点「兑换」后先刷新，再按原门禁（`moneyActionBlocks` + `isUsable`）判定；关门则
     **不 prepare intent**、不开 sheet。
   - Launch 授权（先授权 USD1）与买入签名（签名认购）：先刷新，再按原门禁
     `launchCapabilityBlocks` + `evidencePending` 判定；关门则走 `launch-trade-capability-unavailable`。
   - 刷新期间主按钮不可点，文案 `moneyCapabilityCheckingLabel` =「正在核对可用性」；Launch
     复核区的「重新报价」同时不可点，避免刷新期间换掉要签的 intent。
   - 授权盘点页 revoke 与 approval-guard 不在本单范围，未接。
2. **MiningReadController 接 0095 保留机制**。基类 `build` 调 `loopRetainRead`、watch
   `loopAccountScopeProvider`，回访时 ≥10 s 才后台重读，5 分钟无监听释放；成功时记 `_readAt`。
   以 route 为主体的 `MiningCommunityController` 以 `retainsAnswer => false` 退出。挖矿答复不进
   冷启动快照。钱包页下拉刷新（`_refreshWallet`）同时 reload `mining/assets`，以及已挂载时的
   `mining/summary`。影响面：挖矿 Tab 各页同样变为「回来即有内容 + 更新中」。
3. **离线卡文案**（`LoopOfflineState`）。新增 `LoopOfflineCause { connection, timeout }`：
   - 有 `cachedAtLabel`：「离线 · 显示缓存」+「缓存 HH:MM」（超时为「LOOP 响应超时 · 显示缓存」）。
   - 无缓存：标题「连不上 LOOP」/ 超时「LOOP 响应超时」，副文案「这次读取没有完成，还没有可显示的
     缓存。」+ 原「已暂停：…」，**不画缓存戳**，保留「重试连接」。
   - 为了能区分超时，`LoopChainFailureKind` / `LaunchFailureKind` / `CommunityFailureKind`
     各加 `timedOut`：只有**读**的 `LoopBackendFailureKind.timeout` 映射到它；写仍是 `offline`
     （结果未决语义不变）。页面相位、首读静默重试、`OutcomeIsUnresolved` 都把它当 offline。
     `LoopChainStateBlock`、`LaunchStateBlock`（含挖矿）、`CommunityStateBlock`、`MoneyOfflinePause`
     与钱包/自选/提醒/通知设置四处 `== offline` 分支按 kind 选措辞。
   - 生产代码里没有任何调用方传 `cachedAtLabel`（0095 之后有值时走 `LoopFreshnessStrip`，离线卡只在
     没有内容时出现），所以实际上所有离线卡都会显示「连不上 LOOP / LOOP 响应超时」。
   - 未区分超时的调用方：聊天 v2、个人资料/隐私、LOOP ID、群别名等自有 failure kind 的页面仍用
     connection 措辞（「连不上 LOOP」，对超时也不算错）。
4. **Launch 空分段文案**：「这个分段目前没有项目。分段按链上销售状态划分；没有链上读数的项目按
   排期状态归类。」（`launchSegmentEmptyBody`）；待排期分段原文不变；类注释同步 S83b7。

## Consequences

- 每次打开签名 sheet 多一对 D0 请求（policy + capabilities），经隧道约 0.5–2.3 s；期间按钮显示
  「正在核对可用性」。刷新失败不阻断签名，与 0098 裁决 4 一致。
- Swap 在关门时不再 prepare intent，服务端少一条会被放弃的 intent。
- 挖矿 Tab 与钱包页的挖矿数字在 10 s 内来回切换不再重读；5 分钟内回来先画旧值再后台更新。
- 三个 feature failure kind 各多一个只用于读的 `timedOut`；写路径语义不变。
- 离线卡不再出现「缓存 —」；「显示缓存」只在调用方真的传入缓存时间时出现。

## Evidence

- `test/s88d_followups_test.dart`（11 例）：send 刷新前后一对 meta 请求、pending 文案与不可点、
  关门不开 sheet 走 block、刷新失败沿用旧值照常开 sheet；swap 同上且关门不 prepare；钱包页二次进入
  不发 `mining/assets`，下拉刷新发；离线卡三态（有缓存 / 无缓存 / 超时）；链读超时到页面措辞；三组
  mapper 读超时 → `timedOut`、写超时 → `offline`。
- `test/s83c_launch_pages_test.dart`、`test/s83c2_launch_approve_test.dart` 各 +2（买入 / 授权的
  刷新与关门）。`pumpS6Page` / `pumpS7Page` 新增可选 `metaRepository`，走真实 D0 缓存；共用假服务
  `test/support/s88d_meta_server.dart`。
- 改断言不删：`loop_components_test`（无缓存不再出现「缓存 —」）、`s8_five_state_pages_test`、
  `s8_launch_mining_state_pages_test`（离线标题）、`s59_mining_recorded_page_test`、
  `s26_first_read_transient_offline_test`（否定断言换成新标题）、`s8_api_contract_test`（About 读
  `REQUEST_TIMEOUT` → `timedOut`）、`s7_launch_pages_test`（新增空分段文案断言）。
- 回退 send / mining 修复后，对应 4 例确认失败。
