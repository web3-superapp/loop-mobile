# 0108 · 详情页「进入内盘交易」按钮跟随链上四轴（S103）

## Status

Proposed 2026-09-30。S103，客户端单侧。基线 `integration/v2` 3335a71。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）。**偏离原型**：原型 `launch-detail` 的主按钮固定为「进入内盘交易」且始终可点。

## Context

用户原话（闭环 A 真机通过后，看已毕业的 #6）：「既然不能没拿为什么进入内盘交易还是可点击状态？」

内盘 = 认购期在 Launch 合约里按固定价买入、只买不卖（`launch-trade` 页文案：「内盘阶段没有卖出接口。
毕业并建立外部流动性之后，交易才会转到行情模块」）。客户端只在链上 `saleState == LIVE` 且
`operationalState == ACTIVE` 时放开购买（`LaunchOnChainAvailable.isPurchasable`），其余状态进入
`launch-trade` 只能看到「内盘认购当前不可用」。按钮本身却始终是主按钮、始终可点，用户点进去只得到一句拒绝。

## Decision

1. 新增 `launchTradeButtonSpec(LaunchOnChainState)`（`launch_widgets.dart`），返回按钮文案与是否可点：
   - 链上读数不可用（`LaunchOnChainUnavailable`）：保留原型文案「进入内盘交易」并可点，页面自己解释缺读数；
   - `PAUSED`：「内盘已暂停」，不可点（优先于销售状态）；
   - `LIVE`：「进入内盘交易」，可点；
   - `SCHEDULED`：「内盘未开始」；`ENDED`：「内盘已结束 · 等待最终化」；`FAILED`：「内盘已结束 · 未达软顶」；
     `CANCELLED`：「内盘已取消」；`SUCCEEDED`：流动性 `LP_LOCKED` / `COMPLETED` 时「已毕业 · 内盘已关闭」，
     否则「内盘已结束 · 募集成功」——全部不可点。
2. `LaunchDetailScreen` 的 `launch-detail-open-trade` 按钮改用该规则；键、位置、主按钮样式不变
   （`LoopButton` 的 `onPressed: null` 即原型 disabled 形态：保形不填色）。
3. `launch-trade` 页本身不改：深链或旧入口进入时仍以页面上的不可用块兜底。

## Consequences

- 已毕业项目在详情页看到的是「已毕业 · 内盘已关闭」的灰按钮，不再误导进内盘。
- 在行情模块里交易已毕业代币（Pancake V3 池）需要把 Launch 建的池登记进行情代币目录，本决策不覆盖，待开单。
- 单测 `test/s103_launch_trade_button_test.dart` 钉住全部分支。
