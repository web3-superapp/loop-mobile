# 0292 · 实时条在「›」前裁切、交易日期头降级、推广卡可进算力排行榜（S368-mobile）

## Status

Accepted · 2026-11-05（S368-mobile）。需求方 11-05 TF 66 真机验收九条中的第 1 / 6 / 9 条（docs/62）。改写 0256（UX-004）里「「›」压在渐变上、文字从下面跑过」的做法和 0133 / 0190 M29 里「日期头是小节标题（LoopLabel）」的做法；扩 0100 的推广 deeplink 白名单一项。

## Context

- 第 1 条「这块漏字了」：MEME 首页实时条（`Launch2TradeTicker`）的滚动行铺满整条，右端「›」按钮用一段半透明渐变盖在上面，文字（「GEM [买入] …」）在按钮下仍看得见一半。
- 第 6 条「这个字太大了，这个信息不重要」：「我的 · 交易」流水按日分组，分组头（今天 / 昨天 / 10月21日）走 `LoopLabel`，平铺页上是 22 粗的小节标题。
- 第 9 条：情报 · 行情的占位推广「LOOP 挖矿算力周榜」deeplink = `/intel`，`IntelScreen.openPromotion` 把它当「切到算力页签」，点了等于没跳；需求方脑图要进排行榜二级页 `/mining/rank`。api 侧改 deeplink 由 S369-api（0201）做；客户端 codec 的推广 deeplink 是严格白名单，不认 `/mining/rank` 会把整页行情判无效。

## Decision

- **实时条**：滚动区在按钮前结束——带内 Row 在 `Expanded` 滚动区后面留 `allWidth(44) + 1 + allGap(8)`，滚动区本身已是 `ClipRect`，所以文字物理上越不过按钮左边 8。滚动区 `ShaderMask` 从左端 18 渐显改为两端：左 18 渐显、右 16（`railFade`）渐隐（`launch2TickerRailStops`）。「›」是宽 44 的不透明底（`Launch2TradeTicker.fade`，即 searchBg #0e0f10），去掉原来的透明渐变；仍是 44 触控行。左端「● 实时」不变；空态（暂无成交）没有按钮，也不留位。
- **日期头**：`WalletActivityDayHeader` 不再用 `LoopLabel`，改为 13 / 500（`LoopType.eyebrow` 字阶）+ Text3，上 16、下 8，带 `Semantics(header)`；左边与行内容对齐——平铺页里行在卡块内缩 16，所以左 = 页边 20 + 16；非平铺页 = 页边 20。今天 / 昨天 / 具体日期同一处理。
- **推广 deeplink**：`_promotionDeeplinkPattern` 只加 `/mining/rank` 这一个完整路径（不带参数、不放宽成 `/mining/*`）。`openPromotion` 的 default 分支已是 `push(location)`，`/mining/rank` 走它进排行榜二级页；`/intel`、`/square`、`/meme`、社区主页行为不变。

## Consequences

- 实时条改在 `launch2_atmosphere.dart`（`Launch2TradeTicker` 实际在这个文件里，不在任务书写的 launch2_widgets.dart）；只动了 ticker 的 build / `_rail` 和三个常量，S367 去氛围层若同改此文件需注意合并。
- api 的 deeplink 改动（S369-api / 0201）必须等带本批的 TF 68 传完再部署 staging，否则 TF 67 及更早客户端行情页整页判无效（docs/62 第 9 条）。
- 没有新增文案，ARB 不变。

## Tests

- 新增 `test/s368_ticker_day_header_promotion_test.dart`：滚动区右边缘 ≤ 按钮左边缘且间距 8、滚动区内有 ClipRect、按钮底不透明无渐变、右端渐隐 16 / 左端 18、「● 实时」仍在左、点按钮打开全部；空态无按钮无遮罩；窄宽 stops 有序。日期头 13 / Text3、上 16 下 8、在交易流水页上与行图标左对齐。推广：`/mining/rank` 与旧四种可解码，`/mining`、`/mining/rank/x`、`/mining/rank?scope=users`、`/mining/ranks`、`/wallet`、https 链接仍判无效；`/mining/rank` 被 push，`/intel` 仍只切页签。
- 改写 `test/s197_2_type_test.dart`「the day header is a LoopLabel」→「the day header is a 13 Text3 caption」。
