# 0227 · MEME v2 项目页 K 线（S267-mobile）

## Status

Accepted 2026-10-21。基线 `integration/v2` 792b1da4（0224 合入后）。依据：需求方 2026-10-21「我们发射的代币详情里没有 K 线」；后端同批 S267-api 的接口合同 `GET /v2/launch2/instances/:instanceId/candles`。

不新增依赖，`pubspec.lock` 不变；route manifest 不变；不改 loop-api。

## Context

行情页和旧 MEME 代币页有共享的 `LoopMarketChart`（蜡烛 / 折线、成交量、左右拖动、双指缩放、长按十字线），launch2 项目页只有「当前价 / 内盘已售」数字卡和进度条，没有图。
接口合同：`interval=1m|5m|15m|1h|4h|1d`、`limit 1..500（默认 200）`、`before`（unix 秒，可选）；`t` 升序，o/h/l/c 为 USD1 价的十进制字符串，v / q / n；空桶服务端已用上一 close 填平；无成交时 candles 为空、latest 为起始价；422 `LAUNCH2_CANDLE_INTERVAL_INVALID`；404 同详情。合同要求 codec 忽略未知键、容错缺省字段。

## Decision

1. **端口**：`Launch2Gateway.candles(instanceId, interval, {limit, before})`，模型 `Launch2Candle` / `Launch2CandleSeries` / `Launch2CandleInterval` / `Launch2CandleSource`（`launch2_candle_models.dart`）。适配器 `DioLoopV2Launch2Api.getCandles`；错误目录 = 读目录 + 422 两个 code。不带标准信封的 404（S267 前的服务端）也映射为 `notFound`。
2. **codec 宽松**（与 launch2 其它严格 codec 不同，按合同）：根不是对象才算 invalid；未知键忽略；`latest` 非对象 → null；缺 `v/q/n` → 0；缺 `o/h/l` → 用 `c`；缺 `t` 或 `c`、负数、非十进制的桶整根丢弃，绝不编价；同一 `t` 去重并按 `t` 升序；高低不包住开收时放宽到包住。
3. **图复用 `LoopMarketChart`**，不另写一套。为此给它加了全部可选、默认不改现有行为的参数：`priceFormatter`（项目页传 `launch2PriceLabel`，坐标轴 / 十字线 / 最新价都用 `$0.0₄4286` 下标格式）、`axisStyle`（Arimo 11 Text3）、`priceAxisWidth`（项目页 66）、`retainViewport`（刷新 / 往前翻页时窗口按「距最新一根」保持不跳）、`onReachStart`（每次拖动到最左只回调一次）、`markers`（竖虚线 + 小标）。
4. **卡片**：`LoopRecordCard`（card 底、16 圆角），内放周期胶囊 `1分 / 5分 / 15分 / 1时 / 4时 / 1天`（`LoopSegBar`，选中态即公共组件的喷点）和 220 高的蜡烛 + 成交量图，涨绿跌红用 `LoopColors.rise / fall`。位置：内盘阶段在「内盘」标题下、数字卡之上；毕业后在「官方池」标题下、「毕业时间」之上，默认周期内盘 5 分、毕业后 1 时。
5. **毕业竖线**：只在 stage = graduated、`source` 不是单一 `curve` / `pool`（即 mixed 或未知）、毕业时刻落在已加载的桶范围内时画紫色（`LoopColors.purple`）竖虚线 +「毕业」小标；时刻取 `graduation.graduatedAt`，没有则取 row 的 `graduatedAt`。
6. **状态**：首读中 → 骨架块（减少动效时不脉动）；空数组 → 灰阶蜡烛占位 +「还没有成交，第一笔成交后出现 K 线」；`notFound` / `unavailable` 或 launch2 读能力关闭 → 整块不画、不报错、不轮询；其它失败 → 「K 线暂时读不到，点按重试」，整块可点。刷新失败静默保留旧图；翻页失败下次拖到最左再试。
7. **刷新与翻页**：`LoopForegroundPoll` 每 15 s 重读最新一页，页面被盖住 / Tab 不在前台 / App 在后台时停，回来后按间隔继续；合并时保留比新页更早的已加载桶。拖到最左用 `before = 最早一根的 t` 取上一页并前插；返回不足一页即视为到头，不再请求。切周期用 generation 丢弃旧周期的迟到应答。

## Consequences

- 行情页 / 旧 MEME 页的图行为不变（新参数默认值等于原值，全量测试通过）。
- 测试替身：5 个 `implements Launch2Gateway` 的完整替身加了 `candles` 桩（返回 unavailable，卡片隐藏）；用 `noSuchMethod` 的替身不需要改。
- 未做：十字线读数只显示收盘价和时间，不显示 OHLC / 成交额（共享组件本就如此）；`latest` 已解码但图上不用（最新价标签取最后一根 close）；没有 MA 线。
- 需要后端确认：空桶已填平意味着 1m 周期在冷门项目上几乎全是平线；`before` 是否不含边界（客户端已自行过滤 `t >= 当前最早一根` 的重复桶，含或不含都能工作）。
