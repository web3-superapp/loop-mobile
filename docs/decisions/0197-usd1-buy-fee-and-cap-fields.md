# 0197 · 外盘买入基础税按币种展示 + 内盘单地址上限按实例读（S218-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 13f137e。依据：loop-api 决策 0152（同步 loop-contracts 0015：内盘上限参数化、外盘买入税改收 USD1）
与 `loop-api/openapi/loop-api.v2.json`（loop-api `integration/v2` a31a54f）。
修订 0139（累计额度条 5,000,000）、0145（买入税只写 MEME）、0157（买入报价行「外盘税 2%（扣 MEME）」）、0159 §2 / §8（`dynamic` 严格 10 键、买入税行），
原文处加「0197 修订」注。不新增依赖、路由、字体、颜色 token；`pubspec.lock` 不变。

## Context

loop-contracts 0015 让 S209 起的新 LoopDynamic 工厂在 `beforeSwap` 从 USD1 输入侧扣 2% 买入税（池子只换 `amountIn − 税`，MEME 输出不再扣），
内盘单地址累计上限从常量 500 万变为工厂参数。旧工厂实例不变。loop-api 0152 两代同时支持，读面新增（additive）：

- `pool/quote`（及 `pool/trade/prepare` 的 `quote`）：`dynamic.baseTaxToken`（`meme` | `usd1`，小写）；S209 买入 `taxToken = usd1`、`taxUsd1 = taxAmount`；
- `pool/trades`：S209 买入行 `taxToken = usd1`；
- `dynamic-pool`：`buyFeeToken`（`meme` | `usd1`，非 active 为 null）、`summary.buyFeesUsd1`（`buyFeesMeme` 保留，只计旧代）；
- 单地址上限：执行器写 `verification.curveMaxCumulativeBuy`，但它**不出现在 App 读的 v2 合同里**——loop-api 把它派生成实例的
  `template.perAddressCap` / `perAddressCapBps`（缺键 = 500 万）与内盘报价 `quote.quota.capMeme`（链上读）。

本仓库在此之前：严格解码器把「买入税 = USD1」当无效载荷（S209 外盘买入报价与成交记录整页失败）；`dynamic-pool` 解码器还不认识 loop-api
0144 / 0146 已加的六个键（真实响应同样会整页失败），新字段因此无法到达；`summary` 已解码却没有任何地方展示；
`launch2LimitedByText` 与 `LAUNCH2_QUOTA_EXHAUSTED` 文案写死「5,000,000 枚」。

## Decision

### 1. 解码（缺字段 = 旧代，宽进严出）

- `quote.dynamic`：严格 10 键 + 可选 `baseTaxToken`。缺 → 买入 `meme`、卖出 `usd1`；在场必须是小写 `meme` / `usd1`，卖出必须 `usd1`。
- 报价 `taxToken`：卖出 = `usd1`；买入 = `dynamic.baseTaxToken`（无 `dynamic` 的 OfficialTax 报价 = `meme`，与 0145 相同）。
  买入 `usd1` 时要求 `taxUsd1 == taxAmount`。两者不一致即 `invalidPayload`。
- `pool/trades`：卖出仍只能 `usd1`；买入 `meme` 或 `usd1`。
- `pool/trade/prepare`：意图的 `taxMeme` 只在 `taxToken = meme` 时带；S209 买入签名表单税行因此显示意图的 `taxUsd1`（USD1）。
- `dynamic-pool`：可选 `buyFeeToken`（active 时缺 → `meme`；在场必须非空的 `meme` / `usd1`；`not_applicable` / `not_graduated` 必须为 null）；
  `summary` 可选 `buyFeesUsd1`（缺 → null）。loop-api 0144 / 0146 的 `maxDynamicFeeWad`、`maxDynamicFeeBps`、`currentDynamicTaxBps`、
  `roundCloseRule`、`armedAfterRoll`、`currentRoundBuyers` 作为可选键接受并按 schema 校验类型（金额串 / 0–10000 整数 / 两值枚举 / 布尔 / 对象），本批不建模、不展示。
  其它未知键仍无效。

### 2. 外盘买入报价行（LoopDynamic）

| | 标签 | 值 |
|---|---|---|
| S209（`baseTaxToken = usd1`） | 基础税 2%（从付出的 USD1 扣） | `taxUsd1`，如「2 USD1」 |
| 旧代（缺键或 `meme`） | 基础税 2%（从到手的 MEME 扣） | `taxAmount`，如「3,200 $FROG」 |

税率取 `dynamic.baseTaxBps`。「预计获得 / 最少获得」一律是服务端 `expectedOut` / `minOut`，客户端不扣税、不反推。
来源行买入：S209「已从付出的 USD1 扣 2% 基础税」，旧代「已扣 2% 外盘税」（不变）。卖出行与 OfficialTax 报价不变。

### 3. 费用累计卡（项目页「本轮状态」下、外盘奖励页轮次上方）

`Launch2DynamicFeeSummaryCard`（`.label`「费用累计」+ 一张 `.record-card`）：动态税累计（`dynamicFeesUsd1`）、卖出基础税累计（`baseSellFeesUsd1`）、买入基础税累计：

- `buyFeeToken = usd1`：「买入基础税累计 x USD1」（`buyFeesUsd1`）；
- 否则：「买入基础税累计 x $T」（`buyFeesMeme`，无 ticker 时写 MEME）；
- 两个合计都有费用（> 0）时各列一行，USD1 在前。

### 4. 内盘单地址上限

- 上限 = `quote.quota.capMeme`，否则 `template.perAddressCap`；缺或 ≤ 0 回退 5,000,000（`launch2CurveCapOf`）。
- 显示为整数枚、千分位（`launch2CurveCapFigure`）：发射规则「单地址上限 3,000,000 枚（0.3%）」（原 `launch2MemeCompact` 的「5M」）；
  MAX 原因「单地址累计上限 N 枚」；内盘面板 `LAUNCH2_QUOTA_EXHAUSTED`「已用完单地址累计 N 枚额度」；额度条读屏「…，每个地址最多买 N 枚」。
- 不知道实例的通用场景（`launch2ReasonText`）改为不带数字的「已用完单地址累计买入额度」。

## Consequences

- S209 新工厂实例的外盘买入报价、成交记录与动态池不再因严格解码失败；旧工厂实例显示与之前一致（文案由「外盘税 2%（扣 MEME）」改为「基础税 2%（从到手的 MEME 扣）」）。
- 0144 / 0146 的六个键现在被接受但未展示；展示另批。
- 创作者向导里的「单地址累计上限 500 万」（`launch2_creator_*`，模板常量）不在本批范围。（**0198 修订**：创建者模板卡改读工厂的 `maxCumulativeBuy`，写法同发射规则「N 枚（x%）」。）

## Tests

- `test/s168_launch2_dynamic_pool_test.dart` 新组 `decision 0197`：报价新旧形状解码（缺键 = MEME、显式 meme、S209 usd1、卖出 usd1）；
  七种不一致拒绝（USD1 税缺键 / 键说 meme、键说 usd1 而税是 MEME、`taxUsd1 ≠ taxAmount`、大写、卖出 meme、OfficialTax 买入 USD1）；
  两种报价行文案与预计到手取服务端数；`dynamic-pool` 新旧形状 + 0144/0146 键接受 + 坏值拒绝；费用行 USD1 / MEME / 两行；
  项目页 S209 报价税行与费用卡、外盘奖励页旧代费用卡。原两条「外盘税 2%（扣 MEME）」断言改为新文案。
- `test/s150_launch2_followups_test.dart`：成交记录 S209 买入 USD1 税可读，卖出 MEME 税与大写拒绝。
- `test/s136_launch2_user_test.dart`：上限读取与回退（null / 0 / 小数）、文案函数；发射规则 3,000,000 / 5,000,000、额度条 `1,000 / 3,000,000`；
  MAX 原因读报价 `capMeme`、配额拒绝读详情上限。
- `test/support/launch2_fixtures.dart`：`l2Detail(perAddressCap:)`、`l2Quote(capMeme:)` 参数（默认值不变）。
