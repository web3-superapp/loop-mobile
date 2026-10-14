# 0161 · MEME v2 实例的 USD1 暂停 / 地址冻结提示（S177-mobile）

## Status

Accepted 2026-10-14。基线 `integration/v2` 17fc454，与 loop-api S177 同批（后端 chain guard）。
不新增依赖、`pubspec.lock` 不变、路由与视觉 token 不变、无新请求。

## Context

USD1 被发行方暂停、或我方合约地址被 USD1 冻结时，链上买卖、NFT 购买与外盘奖励领取必然失败。后端 S177 在
`GET /v2/launch2/instances/:instanceId` 的 `instance` 上新增 `tradingHold`，并在 hold 期间拒绝写请求
（内盘 quote / trade prepare、nft prepare、外盘 pool quote / pool trade prepare、dynamic-pool claim prepare），
reasonCode 为 `LAUNCH2_USD1_PAUSED` / `LAUNCH2_ADDRESS_FROZEN`。App 要在下单前说清楚并关掉按钮。

## Decision

1. 契约：`tradingHold: null | { kind: "usd1_paused" | "address_frozen", since: date-time }`，可缺失（旧后端）。
   编解码把它列为详情的可选键；缺失 / null / 非对象 / 未知 kind 一律读成无 hold，不让整页判无效
   （后端仍会以拒绝码兜底）；`since` 读不出时保留 hold、只不显示时间。模型 `Launch2TradingHold` / `Launch2TradingHoldKind`。
2. 文案（横幅、面板状态行、拒绝码三处同一句）：
   - `usd1_paused` / `LAUNCH2_USD1_PAUSED`：「USD1 已被发行方暂停，买卖和领取暂不可用」
   - `address_frozen` / `LAUNCH2_ADDRESS_FROZEN`：「本项目合约地址被 USD1 发行方限制，买卖和领取暂不可用」
   - 第二行「自 HH:mm 起」（当天）或「自 yyyy-MM-dd HH:mm 起」（更早），用 `loop_time_format` 的本地时间函数。
   拒绝码加在 `launch2ReasonText`；`launch2PoolReasonText` 落回该表，外盘与领取自动覆盖。
3. 项目页：hold 非空时在阶段条下、所有阶段内容（交易面板）之上画 `LoopInlineUnavailable`（icon `warn`，
   key `launch2-trading-hold`，主句最多两行以免 360 dp 截断，第二行为时间）。`LoopInlineUnavailable` 为此新增可选
   `detail`（第二行）与 `maxLines`（默认 1），其他调用方不变。
4. 内盘 / 外盘面板：确认键禁用，键下一行同一句（`launch2-trade-hold` / `launch2-pool-hold`）；输入框、MAX 与报价照常，
   报价被拒时面板显示拒绝码文案。`_confirm` 也再判一次 hold。
5. NFT 发售底栏：「购买 NFT」禁用，按钮上方显示同一句（`launch2-bar-hold`），不再显示上一次的失败行。
6. 外盘奖励页：读得到实例详情且有 hold 时，轮次列表上方同一横幅，所有「领取」禁用；读不到详情时本页本就不给领取，
   由后端拒绝码兜底。
7. 项目列表卡片不改。

## Consequences

- 新测试 `test/s177_launch2_trading_hold_test.dart` 15 条：解码（缺失 / null / 两种 kind / 未知 kind 与非对象 / since 不可读）、
  文案与时间格式、项目页提前购与外盘各三态（无 / 暂停 / 冻结）断言横幅 key、文案、确认键禁用与输入仍可报价，
  NFT 发售有无 hold，外盘奖励页有无 hold。
- 对旧后端（无此键）行为不变。
