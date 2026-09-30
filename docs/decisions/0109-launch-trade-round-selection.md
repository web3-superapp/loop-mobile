# 0109 · 认购页轮次选择跟随时间窗，高亮与提交同源（S105 = S83c4）

## Status

Proposed 2026-09-30。S105，客户端单侧。基线 `integration/v2` 5ff46de。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）。布局与文案不偏离原型（见文末「与原型的关系」）。

## Context

真机取证（2026-09-30，sale 8，测试网）：第 1 轮 09:25:13–09:28:13Z，第 2 轮 09:28:13–09:31:13Z。
09:25 暂停时用户进入 `launch-trade` 看到拦截；09:27 恢复后刷新/重进，09:29:56 点「买入」，服务端
request digest 核对为 **R1** 的 roundId——此时 R1 已结束 1 分 43 秒，被拒；再次刷新后才以 R2 在
09:30:05 成交。9-27 的 S83c4 记录同源：轮次卡 R2 标「已选择」，实际成交 Round 1。

改前现状（`lib/features/launch/launch_trade_screen.dart`）：

- `_roundId` 默认 `null`，只在两处写入：用户点轮次行（`onSelect`），以及已准备意向的 roundId
  回写（决策 0094 的 `ref.listen`）。
- 详情重读、时间流逝都不会重算它：用户在 R1 窗口内点过 R1，R1 结束后页面仍提交 R1。
- `canSubmit` 只要求 `roundId != null`，不看轮次时间窗；页面没有任何定时重建。
- 「已选择」高亮与提交值在 0094 之后已同源（都来自 `prepared?.intent.roundId ?? _roundId`
  解析出的 `selected.roundId`）；S83c4 的不一致来自 0094 之前的构建，以及选中值不随窗口更新。

## Decision

1. **默认轮次** `launchTradeDefaultRound(rounds, now)`（`launch_trade_screen.dart` 顶层函数）：
   链上 `startAt/endAt` 与本机时间下处于窗口内的轮次（`LaunchChainRound.isOpenAt`，与
   `launch-detail` 发射轨道同一判定）；没有则取下一个未开始的轮次（只展示，不可提交）；都已结束
   则为空。没有 LOOP `roundId` 的链上轮次不参与（意向必须带 roundId）。
2. **重算时机**（事件驱动，不在每次 build 重算，否则用户手动选的已结束轮次会被立即改掉）：
   - 首次读到详情；
   - 详情读数对象变化（reload、下拉、意向结算后的重读）；
   - 轮次锁释放（「重新报价」丢弃意向后）；
   - 下一个轮次边界（最近的 `startAt`/`endAt`）到点——一次性 `Timer`，只 `setState`，不读网络，
     每次重算后重新布置，`dispose` 时取消。时间取注入的 `clock`，缺省为设备时钟。
   重算规则：当前选中为空、不在列表里、或已结束 → 换成默认轮次；选中的是未开始轮次则保留。
   所有轮次都已结束时保留原选择，好让页面说清是哪一轮结束了。意向准备/签名/广播/授权进行中
   （`roundLocked`）不重算，轮次以意向为准（决策 0094 不变）。
3. **提交闸门**：`canSubmit` 追加「所选轮次此刻在窗口内」。窗口外时买入禁用，沿用现有
   `launch-trade-refusal` 通知（`LoopNotice`，不新造组件），正文：
   - 未开始：`Round N 尚未开始，YYYY-MM-DD HH:MM UTC 开放后才能认购。`
   - 已结束：`Round N 已于 YYYY-MM-DD HH:MM UTC 结束，请选择进行中的轮次。`
   时间用 `launchTimestampLabel`（UTC，与轮次行一致）。
4. **同源**：「已选择」高亮、`本次认购：Round N`、限制卡与 `prepare(roundId:)` 全部读同一个
   `selected`（由 `prepared?.intent.roundId ?? _roundId` 解析），不存在第二个状态变量。

## Consequences

- 真机场景：R1 结束后重读详情，或页面停留跨过 09:28:13Z 边界，选中会自动切到 R2；按钮不会再以
  已结束轮次提交。服务端的 `LAUNCH_ROUND_NOT_OPEN` 仍是最后一道闸（后端 S104 修 500 → 409）。
- 本机时钟偏差会让边界前后几秒的判定与链上不同：客户端只据此禁用/切换，不据此放行——服务端
  与合约仍以链上时间拒绝。
- 用户手动选已结束轮次后，下一次重读或边界到点会被切回进行中的轮次（按规则 2）。
- 测试：`test/s105_launch_trade_round_selection_test.dart`（默认选中、重读切走、边界重算不打
  网络、未开始/已结束拦截文案、高亮与提交 roundId 一致）。`test/s7_launch_pages_test.dart`
  「a malformed amount never becomes a request」原先不注入时钟，fixture 轮次（2026-09-21～23）
  在真实时间下已结束，现注入 `s83cNow`，断言不变。

## 与原型的关系

冻结原型 `#launch-trade` 没有轮次列表（只写「包含本轮」，隐含当前轮次）；轮次列表是 S83c 接链时
加入的既有实现。本决策让默认值回到原型的隐含语义（当前轮次），不改布局、不加组件，只新增上面两句
拦截正文。
