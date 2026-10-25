# 0247 · 情报「行情」行改为 24h 折线 + 百分比（E 稿，S307-mobile）

## Status

Accepted 2026-10-25。基线 `integration/v2` d5f46cc5。用户 2026-10-25 在 docs/49 的 E / F 两稿中裁决选 E。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api。`/v2` 只新增一个**可选键**，客户端先行（与并行的 S307-api 对齐）。
编号说明：0246 已被并行分支 S306（外部钱包绑定 / 解绑）占用，本决策取 0247。

## Context

- 决策 0122 / 0146 定下的情报「行情」行：36 圆标 · 名称两行 · 价格两行 · 右端 96 × 44 涨跌胶囊。
- docs/49「E 稿」：右端胶囊换成「24h 折线 + 无底色百分比」，行高 80 不变。
- 数据：每行需要 24 小时、每小时一点的价格序列。S307-api 在行情列表每行新增 `sparkline24h: number[] | null`。

## Decision

1. **契约（客户端）。** 分类列表行（`GET /v2/market/categories`）与概览的自选 / 热门行（`GET /v2/market/overview`，共用 `_assetRow`）都接受可选键 `sparkline24h`，宽松解码，任何情况下都不让整行或整个列表失败：
   - 缺键、`null`、非数组、空数组、少于 2 点 → 无序列；
   - 任一元素不是有限非负数字 → 整条无序列（JSON 数字与十进制字符串都算数字；`true`、`null`、对象、负数不算）；
   - 超过 24 点 → 只保留最新 24 点（不判失败）。
   序列存为 `Decimal`，只在画布里归一化成 `double`；不打印、不比较、不用于任何报价。
2. **回退。** `trendCloses` = 有效的 `sparkline24h`，否则回退到既有结构化 `sparkline` 块（决策 0074 §3a，`available` 且 ≥ 2 点），都没有 → 无序列。两者都是服务端真实数据，不补点、不插值。
3. **行布局（E 稿）。** 只在 `MarketFomoRow` 打开新构造参数 `trend: true` 时生效，`MarketScreen`（情报「行情」分段与 `/market` 子页是同一个页面）的自选行与分类行打开；MEME 首页列表（`meme_launchpad`）及其它 `LoopChangePill` 用户保持原样。
   - 36 圆标 · 12 · 名称列（`LoopType.titleLg` 17 / 600 + `LoopType.caption` 14 Text3，最小宽 112，超出省略）· 10 · 价格（`LoopType.figureMd` 17 / 600 右对齐，最大宽 92，超宽等比缩小）· 12 · 趋势列 96。
   - `LoopQuoteRow` 新增可选 `valueMaxWidth`（替代 140 / 36 % 上限）与 `trailingSlotWidth`（名称最小宽的预算），默认 `null` 行为不变。390 宽时名称列保 112，价格上限按剩余宽度为 72，超出缩小；320 宽时价格降到 56、名称让位，不溢出。
   - 趋势列：96 × 32 折线（复用 `LoopSparklinePainter`，新增可选 `padding` / `endDotRadius` / `progress`，默认值保持旧行为）；线宽 1.6，绘图区 x 2 → 92、y 3 → 29，按序列自身最小最大归一化，末端实心点 r 2.6；其下间隔 2 为百分比 `LoopType.figureSm` 14 / 700、行高 1.3、无胶囊底。
   - 颜色按 24h 涨跌：涨 `LoopColors.rise`、跌 `LoopColors.fall`、平盘或未报告的线为 `LoopColors.line3`；平盘百分比用 `LoopGround.inkOf`（深色底即 Chalk），未报告显示 Text3「未报告」。
   - 无序列：折线位留空 96 × 32（不画占位虚线），百分比位置、列宽、右边缘与有序列行一致。
4. **动效。** 折线首次出现 360 ms 从左向右画入（`LoopMotion.enter`），点跟随笔尖；减弱动态效果（`MediaQuery.disableAnimations`）时直接画完整。
5. **无障碍。** 行仍是一个合并语义节点；涨跌片段改读：有序列「24 小时走势上涨 8.40%」/「下跌」/「持平」，无序列「24 小时涨跌 +8.40%」，未报告「24 小时涨跌未报告」。趋势列单独使用时自带同样的标签。

## Consequences

- 测试：新增 `test/s307_market_sparkline_test.dart`（分类列表与概览两处 codec 的退化情况、超长截断、回退规则；涨 / 跌 / 平 / 无序列 / 未报告五种渲染；画入动画与减弱动效；390 / 320 宽长名称省略且不溢出；情报列表用趋势列、默认行仍是胶囊）。`test/s113_intel_market_token_test.dart` 的胶囊断言改为趋势列。
- 已知未还原：行情列表骨架屏（`LoopSkeletonType.priceRow`）右端仍是胶囊形占位，未改成折线形；加载态视觉差异小，留待动效批次。
- 需要 loop-api 校正的点见 S307 报告：数值类型（建议明确 JSON number）、点数上限、与既有 `sparkline` 块的关系。
