# 0086 · 每个代币都戴自己的 logo，红色只表示下跌

- Status: Accepted（需求方 2026-09-23 晚三条反馈；主代理接手 S82a 收口）
- Date: 2026-09-23
- Scope: loop-mobile `lib/widgets/loop_token_card.dart`、`loop_price_move.dart`（新）、`loop_pages.dart`（`bottomBar` 槽位）、market/token 页、发现页行、wallet/mining/search 三处 codec 与行组件、`scripts/check_harness.py` K 线配色守卫

## Context

1. 后端决策 0072 给所有资产行下发了 `logo`，S78b 只在行情与自选画了出来；社区详情「社区币」卡、聊天代币卡、钱包、挖矿、搜索、提醒、自选管理仍是首字母 monogram（用户截图：Builders Guild 的 USDT 仍是自绘 ₮）。
2. 发现社区页行距与冻结原型 `renderRow('community')` 不一致。
3. 需求方要求代币详情页「更像交易所」，并指出下跌的数字不是红色。

## Decision

- **logo 一处来源**：`LoopTokenLogo` 三级回落（远端 → 内置 → monogram）接到全部九个投影点；wallet / mining / search 三处 codec 从「校验即丢」改为投影到模型。
- **涨跌配色单一来源**：新增 `lib/widgets/loop_price_move.dart`，三态且只有三态——涨 `lime`、跌 `danger`、持平/读不到 `muted`。`MarketMove`、`LoopTokenCardModel.move`、`LoopRecordRow` 尾注、K 线 OHLC 的 C 值、K 线下跌实体/影线/成交量全部走它。`check_harness.py` 的 K 线「单色」守卫改为「两色：涨 lime、跌 danger」，依据 0084 §2 与已批准的 Token.dc.html。
- **代币页交易所化**（补齐 0084 未落地四项）：`LoopDashboardPage.bottomBar` 槽位 + 固定买入/卖出条（沿用 `capability.swappable` 门禁）；周期 Tab + MA7/MA25 一行紧贴 K 线（图高 236，含成交量）；下半页四 Tab 社区 / 持有人 / 成交 / 简介；24h 高 / 低两格读 0074 的 `range24h`。
- **契约收紧（0074）**：overview 行 `sparkline` 必填（`source` / `quality` 放行，七个拒绝码白名单，closes 1–24），`market/assets/{id}` 顶层 `range24h` 必填；24h 涨跌 `quality: stale` + `MARKET_FACT_NOT_REPORTED` 按可用值显示。
- **发现页行**：按原型重排为「名称 / N 名成员 · 已验证」，去掉右侧两行值列，行高 71（13 + 44 + 13 + 1），chip 行下边距 16、间距 7。

## Consequences

- MA7 / MA25 不采用设计稿的蓝 / 橙（会引入第三、第四个色相），仍用 lime / chalk 描边；需求方若坚持，改 `loop_candle_chart.dart` 两个常量。
- 后端 `1ab26d7`（0074）与本单必须同批部署：`range24h` 必填键会让旧客户端代币页解码失败。
- 测试：新增 `test/s82_logos_discover_and_token_test.dart` 24 条；全量 3349 通过；harness 通过。
