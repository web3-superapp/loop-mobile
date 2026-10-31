# 0259 · 钱包净值图表恢复折叠与安静区间 tab

## Status

Accepted · 2026-10-31（S329-mobile）。部分覆盖 0257 的 UX-015。

## Context

0257（S327）按 UX-015 把钱包主页「总资产」卡下的净值图表改为始终展开、删去折叠（`walletNetWorthExpandedProvider`），区间改为 `WalletSegmentedControl`（44 高、轨道底、凸起选中格）。用户 2026-10-31 看过 TF 56 后裁决：图表恢复折叠、默认关闭；关闭态要比 S327 之前更矮；区间按钮缩小，不要胶囊 / 轨道。

## Decision

### 折叠

- 恢复 `walletNetWorthExpandedProvider`（`WalletSessionFlag`，默认 `false`）：会话级，不持久化；打开后本次运行内保持打开。
- 开关并进今日盈亏行（`WalletPnlLine`）的右端：左「今日盈亏 + 金额」，右「净值走势 ⌄」（Text2 小字 + 向下 chevron）；打开后右端变「收起 ⌃」，下方为 150 高图表 + 区间行。整行是同一个点击目标、只做开 / 合，没有第二种含义。
- 覆盖 0257 的两条：「图表始终展示」作废；「今日盈亏 › 把图表切到 1 天」作废（该行右端的 › 改为折叠 chevron，区间沿用本次运行已选，默认 7 天）。
- 不恢复 88×44 迷你走势槽及其占位 / 喷点 / 骨架（0193 / 0224 的槽位不回来）。
- 周历史尚未读到或读失败时，今日盈亏不画，该行只剩右端「净值走势 ⌄」（key `wallet-networth-toggle`），仍可打开以看到图表自己的加载 / 不可用态。历史端口不可用（404 / 503 / 无端口）时整行不出现，同 0188。
- 关闭态只读 7 天历史（今日盈亏要用）；打开后才按所选区间读。

### 区间 tab

- 新组件 `WalletQuietTabs<T>`（`features/wallet/wallet_segmented_control.dart`），只用于净值图表区间：纯文字，`LoopType.caption`（14，主题规定 13 以下只给 tag，故未用 12）；选中 `LoopColors.chalk` w700 + 1.5 px Chalk 下划线，未选 `LoopColors.text3` w500；每项水平 padding 8；绘制高度 28，触控格 44（透明撑开）；无轨道底、无边框、无选中填充、无胶囊、无 Lime / Purple 发光。左对齐一行，窄屏 `FittedBox` 缩放。
- 兑换滑点、个人中心时间段仍用 `WalletSegmentedControl`，本批不改。

### 高度（390 宽、带 ¥ 行与今日盈亏的同一组夹具，测试实测）

| | `wallet-total-header` 关闭态 | `wallet-total-plate` 关闭态 |
| --- | --- | --- |
| S327 之前（836927b2^） | 238 | 284 |
| S327（常开，无关闭态） | 421 | 467 |
| 本批 | 209 | 255 |

本批打开态 header 413。`test/s329_wallet_networth_fold_test.dart` 断言关闭态 ≤ 212 且 < 238。

## Consequences

- 改动：`wallet_home_widgets.dart`（恢复 provider、折叠）、`wallet_networth_widgets.dart`（`WalletPnlLine` 带开关、`WalletNetWorthChevron` 只绘制、面板改用 `WalletQuietTabs`）、`wallet_segmented_control.dart`（新增 `WalletQuietTabs`）。未改接口、codec、`lib/core/theme/*`、`lib/widgets/*`；未加说明文案。
- 测试：更新 `s199_wallet_home_c_test.dart`、`s327_ux_batch_test.dart`；新增 `s329_wallet_networth_fold_test.dart`。
