# 0194 · 钱包首页「≈¥」带汇率来源与观察时间（S206-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 50f2d10（含 0188 钱包 C 与 0193 占位）。修订 0188 §2「¥ 只在 `fiat.currency == CNY` 时画」一句。
后端由 S206-api（loop-api 决策 0149）并行实现：`networth/history` 的 `fiat` 由固定常数改为有来源的实时汇率读取，形状 additive。
不新增依赖、路由、字体、字形、能力位；未碰 `lib/features/square/`。

## Context

AGENTS 第 25 条：每个链上 / 市场 / 钱包数字都带来源与观察时间，`stale` 要有可见标记。0188 的「≈ ¥913.27」只有币种、汇率与金额，
说不出汇率从哪来、什么时候的，也无法标出过期。S206-api 把 `fiat` 扩为：

```
fiat: { currency, rate, amount, source: "ecb", asOf: "2026-10-15", fetchedAt: ISO, quality: "fresh" | "stale" } | null
```

`asOf` 是发布方定价的那一天，`fetchedAt` 是 LOOP 拉取的时间，`rate` 的含义是 1 USD = rate CNY。

## Decision

### 1. 模型与解码（宽松）
- `LoopNetWorthFiat` 新增可空 `source`（服务端标识原样，不打印）、`asOf`（日历日，存 UTC 零点；接受 `yyyy-MM-dd` 或完整 ISO，取其 UTC 日期）、
  `fetchedAt`（UTC）、`quality`（复用 `LoopFactQuality`，只取 `fresh` / `stale`）；`hasProvenance` 四者齐全；`stale` 便捷位。
- 缺 `source` / `asOf` / `fetchedAt` / `quality` 任一，或其一不可解析 → 视为旧形状：¥ 照画，四个字段全为 null，不画来源。
- `quality` 存在但不是 `"fresh"` → 按 `stale`（未知值永远不当新鲜）。
- `fiat: null` 或 currency / rate / amount 畸形 → 与 0188 相同，不画 ¥。

### 2. 总资产下一行（`wallet-total-subline`）
- 文案不变：「≈ ¥913.27 · 0x1d27…86ed」，隐藏余额时 ¥ 金额仍是 `****`。
- `stale` 时 ¥ 金额后插入市场数字同款 stale 标记：`LoopBadge('数据可能过期', kind: LoopBadgeKind.down)`（与 `LoopFactRow` 同一部件，
  key `wallet-total-fiat-stale`），整行改为 `Text.rich`（同一 key、同一 caption 样式），读屏标签为「≈ ¥913.27，数据可能过期 · 地址，复制钱包地址」。
  徽标不是数字，隐藏余额时保留。

### 3. 来源写在两处（同一句，`walletFxProvenanceText`）
- 句式：「人民币按{来源}{空格}1 USD = {rate} CNY（{MM-dd} 发布，观察于 {HH:mm}）折算」；`stale` 时句末加「，数据可能过期」。
  - 来源映射 `walletFxSourceLabel`：`ecb` → 「欧洲央行参考汇率」，其它一律「参考汇率」，不打印原始标识符。
  - 发布日取 `asOf` 的日历日；观察时间取 `fetchedAt` 的本机时间，不是今天时写「MM-dd HH:mm」。
  - rate 经 `loopFormatDecimal`（最多 6 位小数，去尾零）。
  - 只在 `currency == CNY` 且 `hasProvenance` 时有这句；否则返回 null，两处都不画。
- ① 总资产 (i) 说明弹层：「不是可用余额」那段之下一行（`bodySm` text2，key `wallet-info-fx`）。`showWalletTotalInfoSheet` 新增可选 `fiat` 参数，由顶部块传入 7 天历史的 `fiat`。
- ② 展开面积图下：`LoopProvenanceLine`（净值快照）之后再一行（`LoopType.captionSm` · `LoopGround.secondaryOf`，key `wallet-networth-fx-provenance`）。
  只在可画图时出现（与来源行同在）。

最终文案示例：
- fresh：「人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算」
- stale：「人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算，数据可能过期」
- 未知来源：「人民币按参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算」

## Consequences

- 后端上线前（旧形状）页面与 0193 完全相同；上线后 (i) 与展开图各多一行，stale 时总资产下一行多一个灰徽标。
- 0189 守卫：新文字全部走 `LoopType.bodySm` / `captionSm` / `LoopBadge`，无字面字号，G1 / G2 计数不变。
- 可见变化待主代理真机验收：stale 徽标在 caption 行内的高度（徽标比 caption 高，行会略高）、窄屏下 subline 截断。
- 顺带：基线 `test/s168_launch2_dynamic_pool_test.dart` 一行超长未过 `dart format` 门禁，本批只做了格式化（无语义改动）。

## Tests

`test/s199_wallet_home_c_test.dart` 新增组「≈¥ · rate provenance (0194)」8 例：
- 解码新形状四字段；`stale`；未知 quality → stale；完整 ISO 的 `asOf` 取 UTC 日。
- 旧形状、四键任缺其一、`asOf` 不可解析 → ¥ 照有、来源全空、句子为 null。
- 句子：欧洲央行 / 未知来源「参考汇率」/ stale 尾巴 / 非今天带日期。
- fresh：subline 原样、无徽标，(i) 有来源句且不出现 `ecb`。
- stale：subline 纯文本不变 + `LoopBadge` down「数据可能过期」，(i) 句末「，数据可能过期」。
- 隐藏余额：¥ 打码、徽标保留。
- 旧形状：无徽标、展开图无汇率行、(i) 无汇率句。
- 展开面板：汇率行在净值来源行之下，captionSm、text2。

门禁：`bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
`python3 -m unittest discover -s tests -p 'test_*.py'`、`bin/flutter test`（全量，结果见提交说明）。未起模拟器、未做真机验收。
