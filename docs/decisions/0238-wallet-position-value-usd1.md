# 0238 · 钱包代币列表 MEME v2 行显示 USD1 估值（S281-mobile）

## Status

Accepted 2026-10-22。基线 `integration/v2` 1274db1c（S276 合入后）。主代理下单 S281-mobile，对应需求方 2026-10-22 验收反馈第 08 条「钱包代币列表需要显示持仓代币以 USD1 计价的价值」。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api（后端 S280 同步加字段，本批客户端先行，按「/v2 新增键必须客户端先行」）。

## Context

`GET /v2/launch2/me/positions` 的行此前没有价格，钱包「代币」列表里 MEME v2 行右侧只有持仓数量和阶段文案（「公开内盘 / 已毕业」），排序时也因无价一律排在所有有价行之后（0217）。
S280 约定每行新增三个**可选**键，后端默认不发、开关打开才发：

- `priceUsd1`: string | null（与 `curve.usd1Spent` 同一小数字符串编码）
- `valueUsd1`: string | null（= 持仓数量 × 价；未毕业数量 = `curve.net`，已毕业 = `memeBalance`）
- `priceSource`: `'curve' | 'pool' | null`

## Decision

1. **Codec 宽容读取。** `positionOptionalKeys` 加入 `positionValuationKeys`（三键）。每个键独立读取，`LoopV2Launch2Codec.lenientAmount` 只接受 `amountPattern` 的字符串；缺键、`null`、非字符串、格式不对都读成 `null`（无价），绝不拒绝整行。`priceSource` 经 `Launch2PriceSource.tryParse`，未知枚举读成 `null`。`Launch2Position` 新增 `priceUsd1` / `valueUsd1` / `priceSource` 三个可空字段。
2. **行显示。** 右侧主数字仍是持仓数量。有 `valueUsd1` 时：右侧副文本为「≈ 1,234.56 USD1」（两位小数、千分位；大于 0 小于 0.01 显示「< 0.01 USD1」），阶段文案移到左侧灰行末尾（「Launch 链 · 内盘持仓 · 公开内盘」、已毕业行「Launch 链 · 已毕业」）。无价时与之前完全一致（右侧副文本是阶段）。隐藏金额时副文本为「≈ **** USD1」。副文本 key 为 `launch2-wallet-meme-<instanceId>-caption`。
3. **排序。** `Launch2WalletTokenEntry` 加 `valueUsd1`；钱包页把它作为 `valueUsd` 交给 `walletSortTokenEntries`（USD1 按 USD 读，同一数值比较）。有估值的 MEME v2 行与普通资产按估值统一降序；无估值的仍按数量排在所有有价行之后。
4. **不动总资产卡。** 总资产、持仓分布、算力估值不计入 MEME v2 估值（S145 / 0038 的口径不变）；本批只改列表行。

## Consequences

- 测试：新增 `test/s281_position_value_usd1_test.dart`（10 例：三键有值、缺键、`null`、11 种垃圾值与未知枚举不拒行；估值文案；钱包页有价行 / 无价行 / 已毕业池价行；隐藏金额；有价 MEME 行与 BNB 按估值统一排序、无价行垫底）。`test/support/launch2_fixtures.dart` 的 `l2PositionsJson` / `l2Positions` 加 `extra` 参数。
- 截图：`--dart-define=LOOP_SHOTS=true` 时写 `docs/integration/S281/shots/wallet-tokens-usd1-value-1.png`（BIG 有价排在 BNB 前，SMALL 有价排在 BNB 后，NOPRICE 无价垫底）。
- 文案差异：普通资产行的估值写法是「≈$5,231.73」，MEME v2 行是「≈ 1,234.56 USD1」（按需求方口径用 USD1 计价，单位后置）。如需统一由主代理定。
- 后端开关打开前，客户端行为与之前完全一致。
