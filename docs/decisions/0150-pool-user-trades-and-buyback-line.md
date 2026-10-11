# 0150 · 官方池用户成交与回购分开、回购暂缓行两行、`HOOKS_CONFIG_VERSION_USED` 中文（S152-mobile）

## Status

Accepted 2026-10-11。主代理下单（S152-mobile），基线 `integration/v2` 2d9b353（含 0144–0149），分支 `feat/S152-mobile`。
依据：loop-api S151-api（integration/v2 66b04fa，决策 0127）`docs/frontend-v2-launch2-api.md` §3.10、
`docs/frontend-v2-hooks-launch-api.md` §13、`openapi/loop-api.v2.json` 的 `instance.pool`；主代理验收记录
`LOOP/docs/acceptance/2026-10-11-s142-emulator.md`「观察项（续 2）」5。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变。

## Context

S151-api 给 `instance.pool` 加了三个必带键 `userTradeCount` / `userBuyVolumeUsd1` / `userSellVolumeUsd1`：与
`tradeCount` / `buyVolumeUsd1` / `sellVolumeUsd1` 同口径，但剔除本实例回购适配器 / 执行器发起的池内成交。App 的 pool codec 是
严格键集，不处理则升级后整个项目详情判无效（API 文档要求先发能接受这三个键的包）。同时项目页「外盘成交」把回购也算作成交，
用户看不出市场上真实有多少人在买卖；回购卡合并后的暂缓行（0148）在 360 宽截断，重试时间看不到；签名准备新增
`422 HOOKS_CONFIG_VERSION_USED` 没有中文。

## Decision

### 1. codec 与模型

- `LoopV2Launch2PoolCodec.userSummaryKeys` 三键用 `strictMapWithOptional` 读，**成组可选**（同 0147 / 0148 做法）：三键全缺 =
  S151 之前的服务端，模型字段为 `null`；缺一或缺二判 invalid；出现时必须是对应格式（`null` / 数字 / 非法串均 invalid）；
  其他未知键照旧拒绝。
- 额外校验 `userTradeCount ≤ tradeCount`、`userBuyVolumeUsd1 ≤ buyVolumeUsd1`、`userSellVolumeUsd1 ≤ sellVolumeUsd1`（服务端 check
  约束同口径），违反判 invalid。
- `Launch2PoolSummary` 新增可空 `userTradeCount` / `userBuyVolumeUsd1` / `userSellVolumeUsd1` 与派生 `buybackTradeCount`
  （`tradeCount − userTradeCount`）。

### 2. 项目页官方池读数

- 新服务端：「外盘成交」=「N 笔用户成交」，回购笔数 > 0 时加「 · 另有回购 M 笔」；新增一行「用户买入 / 卖出」=「50 / 40 USD1」
  （`userBuyVolumeUsd1` / `userSellVolumeUsd1`）。
- **与任务单示例的偏差**：示例「3 笔用户成交 · 买 2 / 卖 1 · 另有回购 3 笔」需要用户买 / 卖**笔数**，服务端没有给
  （`buyCount` / `sellCount` 仍含回购）。可以按「回购只买不卖」推算（用户买 = buyCount − 回购笔数），但那是客户端推断，
  不是服务端事实，本批不做；改用服务端给的用户买 / 卖 **USD1 量**单列一行（360 宽下一行一事，不折三行）。
  若要笔数，需后端加 `userBuyCount` / `userSellCount`（见未决 1）。
- 「24 小时成交额」保持总量（`volume24hUsd1` 含回购）不变；「外盘最新价」「最近成交」不变。
- 旧服务端（三键缺）维持原文案「12 笔 · 买 8 / 卖 4」，不显示「用户买入 / 卖出」行。

### 3. 回购卡合并暂缓行（调整 0148）

- `launch2BuybackHeldLine` 改为返回 `Launch2BuybackHeldLine { reason, detail }`：
  - 两个来源原因相同：第一行「下一笔暂缓：<原因>」，第二行「来源：链上读数 · 自动回购 · HH:mm 后再试」（无重试时间则只写来源）。
  - 原因不同：第一行照旧「下一笔暂缓：A（链上读数）；B（自动回购）」，第二行只写「HH:mm 后再试」（无则无第二行），不重复来源。
- 页面不再用单行的 `LoopInlineUnavailable`（`maxLines: 1` + 省略号是截断根因），改为本页 `_BuybackHeldRow`：同样的时钟图标、
  `captionSm` 辅助色，两段文字都不限行数，第一行长原因可折行，时间不会被截。
- 测试在 360 × 2600 下断言两段都是单行且 `didExceedMaxLines == false`。

### 4. 签名准备 `422 HOOKS_CONFIG_VERSION_USED`

- 新常量 `launch2ConfigVersionUsedCode`；`launch2FailureText` 中文：「这一版配置的版本号已被你钱包的另一个项目用过，请修改资料重新保存一版。」
- 新 `launch2FailureNeedsResave`（`HOOKS_BUYBACK_RECIPIENT_FIXED` 或 `HOOKS_CONFIG_VERSION_USED`）：签名页两处失败提示都给「修改资料」按钮。
- `503 HOOKS_LAUNCH_FACTORY_UNAVAILABLE` 已有中文（「发射工厂暂时不可用（或正在计算地址），稍后再试。」），本批只加测试确认，不改。

## Fixtures / 测试

- 新目录 `test/fixtures/s152-launch2/`（手写，`_handwritten` 注明 loop-api 66b04fa 与文档节；dev 未实抓）：
  `pool_user_trades.json`（6 笔含 3 笔回购）、`error_config_version_used.json`（`GET …/hooks-config/signing-request` 422）。
- `test/s152_launch2_pool_user_trades_test.dart`：三键解析、全缺（旧服务端）、缺一 invalid、超过总量 / `null` / 数字 / 多未知键 invalid、
  等于总量合法；官方池读数四种（有回购、无回购、只有回购、旧服务端），360 宽。
- `test/s150_launch2_followups_test.dart`：暂缓合并用例改为两段断言。
- `test/s136_launch2_user_test.dart`：同原因用例改为两行断言；新增 360 宽不截断用例（`_pump` 加 `size` 透传）。
- `test/s135_launch2_creator_codec_test.dart`：签名准备 422 经网关带出 `reasonCode` 与中文、`launch2FailureNeedsResave`、503 工厂中文。
- `test/s135_launch2_creator_pages_test.dart`：签名页 422 版本号已用 → 中文、无重试、「修改资料」可点。

## Consequences

- App 可先于或晚于 S151-api 上 dev；先上 App 时界面维持旧文案。
- 回购数在页面上只来自 `tradeCount − userTradeCount`（池内已索引的回购 swap），与回购卡「累计回购 N 笔」（回购账本）口径不同，
  两者在索引延迟时可能短暂不一致；页面不做对账。

## 未决项（需后端 / 主代理决策）

1. 用户买 / 卖**笔数**：要还原「买 2 / 卖 1」需 loop-api 增加 `userBuyCount` / `userSellCount`（或确认「回购只买」后允许客户端推算）。
2. loop-api 决策 0127 §5.1：市场统计是否剔除回购尚待用户确认；若用户否决，本批改动只需把 `Launch2PoolStats` 的分支去掉。
3. 三键客户端按成组可选处理（OpenAPI 为 required）；dev / staging 都上 S151 后可改必填。
