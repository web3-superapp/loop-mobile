# 0193 · 钱包首页净值曲线占位：没有历史时也让人知道这里有走势（S204-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 9701fe7（含 0188 ~ 0192）。修订 0188 §2（右侧小折线）与 §3（⌄ / 空区间文案）。
不新增依赖、路由、字体、字形、能力位；后端契约不变；只动 `lib/features/wallet/wallet_networth_widgets.dart`、
`lib/features/wallet/wallet_home_widgets.dart` 与 `test/s199_wallet_home_c_test.dart`。

## Context

真机 TF build 24：新钱包总资产 $0，7 天净值历史点数 < 2。0188 的规则是「点数 ≥ 2 才画小折线」，于是总资产下面只剩
「今日盈亏 暂无 ›」和一个孤零零的 ⌄，右侧 88×44 一片空白，没人知道这里能展开净值曲线。
用户原话：「钱包如果没有数据，K 线可不可给一个占位？不然那个地方别人都不知道有功能」。

## Decision

### 1. 右侧 88×44 小折线位按读取结果分四态
- 读到且可画（`LoopNetWorthHistory.drawable`，点数 ≥ 2）：仍是 `WalletNetWorthSpark`（key `wallet-networth-spark`），不变。
- 读到但不可画（0 点或 1 点）：`WalletNetWorthSparkPlaceholder`（key `wallet-networth-spark-placeholder`），同 88×44：
  上部一条 1 px 虚线基线（4 / 3 间隔，色 text3 = `LoopGround.auxiliaryOf`，key `…-placeholder-line`），下方一行
  `LoopType.captionSm` text2（`LoopGround.secondaryOf`）「净值走势 · 记录中」（key `…-placeholder-text`，一行，
  宽度不够时 `FittedBox` scaleDown，不写字面字号）。点按与小折线一样展开面板。占位没有任何数字，隐藏余额不影响它。
- 读取中（尚无值、未失败）：同尺寸 `LoopSkeletonBlock`（`WalletNetWorthSparkSkeleton`，key `wallet-networth-spark-loading`）。
- 读失败（404 / 503 / 缺键）：维持 0188，不画任何东西（今日盈亏同样不画）。
- 展开态照旧隐藏这一位。

### 2. ⌄ / ⌃ 加文字标签
`WalletNetWorthChevron` 改为水平居中一行：收起态「净值走势」+ ⌄，展开态「收起」+ ⌃（key `wallet-networth-chevron-label`），
`LoopType.captionSm` text2；触控高度仍是 `LoopTouch.minimum`，key `wallet-networth-expand` / `-collapse` 与语义标签不变。
历史端口 Unavailable 时整条仍不画（0188 §3）。

### 3. 空区间文案
展开面板 `wallet-networth-chart-empty` 从「这个区间还没有净值记录」改为
「这个区间还没有净值记录 · 每小时记一次，有资产后开始画线」，仍是一行 `LoopInlineUnavailable`（`info`）。

## Consequences

- 新钱包、空钱包首屏右侧不再空白：一条虚线 + 「净值走势 · 记录中」，下方 ⌄ 也写明「净值走势」，入口可被发现。
- 历史读取中右侧多一块骨架，读到后换成线或占位；读失败时与 0188 相同（右侧空、无今日盈亏、⌄ 打开后一行读不到 + 重试）。
- 与 0189 守卫：新文案全部用 `LoopType.captionSm` 档，未写字面字号，G1 / G2 白名单计数不变；占位文案在 88 宽里放不下时
  由 `FittedBox` 缩放渲染，不是字号阶梯里的角色，G2 只拦字面量。
- 可见变化待主代理真机验收：占位、⌄ 标签、空区间长文案（窄屏一行可能截断，按 `LoopInlineUnavailable` 原有行为）。

## Tests

`test/s199_wallet_home_c_test.dart` 新增 6 例并扩 1 例：
- 0 点 / 1 点 → 出现占位（88×44、文案、captionSm、虚线 text3 透明度），无小折线、无骨架；点占位展开面板，空区间新文案；收起后占位仍在。
- 2 点 → `wallet-networth-spark`，无占位。
- 隐藏余额 → 占位与文案不变。
- 读取中（不返回的端口）→ 同尺寸骨架，含 `LoopSkeletonBlock`；读到后换成小折线。
- chevron 标签两态「净值走势」/「收起」，captionSm，高度 `LoopTouch.minimum`。
- 原「history 503」用例补断言：占位与骨架都不出现。

门禁：`bin/dart format --output=none --set-exit-if-changed lib test`、`bin/flutter analyze`、`python3 scripts/check_harness.py`、
`python3 -m unittest discover -s tests -p 'test_*.py'`、`bin/flutter test`（全量，结果见提交说明）。未起模拟器、未做真机验收。
