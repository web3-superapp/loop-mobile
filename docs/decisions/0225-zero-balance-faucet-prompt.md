# 0225 · 余额为 0 先提示获取资金、报价余额不足给出入口（S266-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 792b1da4。依据：需求方新钱包（测试网 USD1 余额 0）在 MEME v2 内盘项目页点买入，
报价答 `409 DATA_STALE / LAUNCH2_QUOTE_ZERO`，面板显示「没有取到报价 · 报价已变化，请重新报价」，「确认买入」灰掉；
「获取资金」入口只挂在 prepare 被拒的那一行上，于是用户卡死。需求方原话：「没有币的话会弹出一个领取；目前因为报价问题买入按钮是灰的，弹不出领取代币的东西。」

后端同批（S266-api）把「余额为 0 / 不足以买到最小单位」改答 `409 INSUFFICIENT_BALANCE / LAUNCH2_USD1_BALANCE_INSUFFICIENT`
（`detailsSafe` 带 `maxAmountIn / requiredAmountIn / balanceUsd1`），卖出对应 `LAUNCH2_MEME_BALANCE_INSUFFICIENT`。App 不等后端上线，自己先兜住。

不新增依赖、不改 `pubspec.lock`、route manifest 不变、不新加接口。

## Context

- 0153 把余额不足说在按钮上方，0154 在「去充值」旁加了水龙头入口（0204 改词为「获取资金」，并禁止用户可见文案出现「领取测试币」）。两者都只在 **prepare** 被拒时出现；prepare 要先有报价，报价失败时没有任何入口。
- 内盘阶段项目详情的 `viewer` 余额组是 `not_graduated`，不带余额；钱包读模型 `GET /v2/wallets/{id}/balances` 的 `launchChain.usd1` 自 loop-api S246（其 0165）起读 Hooks Factory 的 `usd1()`，与 MEME v2 花的是同一个 USD1（0208 当时的错位已由后端修好）。
- `LAUNCH2_QUOTE_ZERO` 和 `LAUNCH2_DEADLINE_TOO_FAR` 原本共用「报价已变化，请重新报价」，对一个「金额太小买不到 1 个最小单位」的答复是误导。

## Decision

### 1. 报价被拒且原因是余额不足 → 同一行给出入口

- 内盘面板（`Launch2TradePanel`）报价答 `LAUNCH2_USD1_BALANCE_INSUFFICIENT` / `LAUNCH2_MEME_BALANCE_INSUFFICIENT`（`launch2IsBalanceRefusal`）时，不再画「没有取到报价 · …」，改画与 prepare 拒绝同一套的 `Launch2ActionFailureLine`：
  文案走 `launch2ActionFailure`（「USD1 余额不足：需要 X USD1，当前 Y USD1」；没有 `balanceUsd1` 时退到「最多可付」；「需要」缺省取输入框金额），
  下方「去充值」+（服务端公布 `testnetFaucet` 可用时）「获取资金」。键 `launch2-trade-quote-short` / `-quote-topup` / `-quote-faucet`。
- MEME 不足只有一句「卖出数量超过持有：…」，没有链接（与 0153 一致）。
- 外盘面板（`Launch2PoolTradePanel`）的报价被拒同样处理，复用 `_poolFailureLine`，键 `launch2-pool-quote-short` / `-quote-topup` / `-quote-faucet`。

### 2. 余额读到为 0 → 不等报价就提示

- 页面把读到的余额交给面板（`usd1Balance` / `memeBalance`，读不到为 `null`）。来源顺序：
  1. 详情 `viewer` 余额组 `balanceStatus = available`（同一区块读的两项）且钱包一致；
  2. 否则 USD1 取钱包读模型 `launchChain.usd1.balance`（18 位基础单位），必须 `chainId` 与项目一致、本页已重读过一次、不在刷新中、不是冷启动快照。任何一条不满足都当作「没读到」——**陈旧的 0 不得挡住报价**。
  3. 内盘阶段的 MEME 余额没有现成读数，保持 `null`（不拿 `curve.net` 推断，转账得来的代币不在其中）。
- 买入侧 USD1 为 0：输入框下直接显示「钱包里还没有 USD1」+「去充值」+「获取资金」（键 `launch2-trade-empty-balance` / `-empty-topup` / `-empty-faucet`），输入金额不发报价，MAX 不可点，「确认买入」灰。
- 卖出侧 MEME 为 0：「还没有这个代币」，无链接，同样不报价。
- 报价成功但 `max.limitedBy = balance` 且 `max.amountIn = 0`：同一行替代「超出可买上限 · 填入 0 USD1」。
- 「获取资金」领取成功后，除重读项目外再重读钱包余额；余额从 0 变为正数且输入框里有金额时，面板自动发起报价。

### 3. 兜底文案拆开

- `LAUNCH2_QUOTE_ZERO` →「这个金额买不到最小单位，换个金额试试」（`launch2QuoteZeroText`）。
- `LAUNCH2_DEADLINE_TOO_FAR` 保持「报价已变化，请重新报价」。

### 4. 入口文字

需求单写的是「领取测试币」。0204 已把这个链接改名为「获取资金」，且把「领取测试币」列为用户可见禁词，故沿用「获取资金」，行为（打开水龙头抽屉）不变。

## Consequences

- 后端 S266-api 上线前：USD1 为 0 的钱包只要钱包余额读到（`launchChain.usd1` 有值），面板就直接提示并给出入口，不依赖报价答复；读不到时仍会看到 QUOTE_ZERO 的新文案（没有入口），这是后端修好前的残余缺口。
- 后端上线后：余额不足的报价答复本身就带入口，两条路径互为兜底。
- 内盘面板进入页面时多一次 `GET /v2/wallets/{id}/balances`（已有接口；单飞去重，与 MEME 首页共用同一 provider）。
- 测试：`test/s266_launch2_zero_balance_faucet_test.dart`（12 例）覆盖余额不足答复的文案与入口并能打开抽屉、无水龙头只给去充值、MEME 不足无链接、余额 0 直接提示且不报价（钱包读模型与详情余额组两种来源）、领取后重读余额并自动报价、MAX=0 的报价、QUOTE_ZERO / DEADLINE_TOO_FAR 文案、有余额 / 未读到 / 他链余额照常报价；`test/s146_launch2_pool_trade_test.dart` 新增 1 例（外盘报价余额不足给去充值、不再写「没有取到报价」）。旧断言无需修改。
- 外盘面板的「余额 0 预先提示」没有做：毕业后已有持仓行与「超出持有」提示，且需求聚焦内盘；需要时另起批次。
