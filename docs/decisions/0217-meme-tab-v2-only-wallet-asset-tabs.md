# 0217 · S259 需求方走查：MEME Tab 只留 v2 发射台、钱包资产区改「代币 / NFT」且不显示零余额（S259-mobile）

## Status

Accepted 2026-10-20。基线 `integration/v2` a72bcf2f。依据：需求方走查反馈（主代理 S259 派单）。
只改 App：不新增依赖、字体、颜色 token，`pubspec.lock` 不变；route manifest 条目不变；不改 loop-api。视觉按 docs/42 附C（决策 0212）§4。

## Context

1. 需求方：「自选 / 代币 / 已毕业」这行 tab 去掉；上面的「已毕业」也去掉，下面四个阶段标签（铸造中 / 内盘 / 预告 / 已毕业）已经覆盖。
2. 需求方：只保留 v2 发射的，之前的不要。
3. 需求方：钱包 0 的资产不显示，不要「余额都为 0，已收起 / 显示 N 项零余额资产」这种折叠。
4. 需求方：钱包资产区改成「代币 / NFT」两个 tab。

## Decision

### 1. MEME Tab = v2 发射台本身

- 构建开关 `launch2Visible` 开（默认）时，MEME Tab 不再有「v2 发射 / 历史 / 已毕业」分段行：整页就是 v2 发射台（`Launch2ListSegment(scope: all)`），
  标题「MEME」，右上「我的项目」人像与「+」（`Launch2CreatorActions`）。
- 「已毕业」只经发射台里的阶段胶囊进入：点它滚到页内「已毕业」分组（不再切到独立已毕业列表）。
- 「历史」（经典 MEME v1 曲线列表，其内「自选 / 代币 / 已毕业」三标签）与独立「已毕业」列表不再有任何入口。
  它们不是路由而是分段，因此没有路由需要重定向；manifest 93 条、`meme-*` / `launch2-*` 路由不变。
- 判定从「开关开 且 `launch2` 能力可用」改为「开关开」：能力未读到 / 关闭时，发射台自己显示一行不可用（`launch2-list-all-unavailable`），
  不再回退到经典发射台 / 行情两段。
- IDO 开关（默认关）打开时，Tab 为「发射台 / IDO」两段，保留其可恢复性（决策 0110）。
- `launch2Visible` 关的构建（不发版）仍是旧的「发射台 / 行情」，经典代码保留未删。
- 经典创建页「经典发射已停用」提示去掉「已有的经典代币仍可在 MEME 的「历史」里查看和买卖」一句。

### 2. 钱包资产区：「代币 / NFT」

- 「余额」标签行改为 tab 行：两个 36 高胶囊（`LoopSeg` capsule，选中 purple 实心白字，附C §4），右侧保留「产生算力」。tab 选择是页内状态。
- **代币**：主网资产行 + Launch 链 BNB / USD1 + MEME v2 代币行合为一个列表。排序：有 USD 估值的行按估值降序在前，其余按数量降序；同值保持原顺序
  （`walletSortTokenEntries`）。Launch 链各行副标写「Launch 链」（MEME v2 内盘持仓为「Launch 链 · 内盘持仓」），「手续费保留」「可动用」保留在行内。
  「Launch 链」独立区块标题删除；测试提示开时的「不计入总资产」说明与测试网 (i) 移到列表下方一行。
  数据来源脚注（区块 / 来源 / 观察于）在列表底部一行，Launch 链区块号并入其详情。
- **NFT**：项目 NFT 行（`FROG NFT · 项目 NFT #1 × 1`），点进共识勋章页（`/launch2/nft`）。五态：加载骨架、空（「还没有 NFT」）、读失败一行重试、
  `launch2` 关一行不可用、有数据列表 + 脚注。
- **零余额不显示**：读到且恰为 0、无在途的行不画（`walletRowIsZero`）；读失败的行不是 0，照常显示失败行。Launch 链 USD1 未读到时不是 0，照常显示「—」与原因。
  `WalletZeroBalanceToggle`、`walletHideZeroBalancesProvider`、「余额都为 0，已收起」一并删除；全部为 0 时显示一个空态。
- 「总资产」口径不变（主网，Launch 链不计入）。

## Consequences

- 测试：s106 / s106b / s117 / s136 / s114 / s121c / s123c / s58 / s236 / s237 按新结构更新；新增 `test/s259_meme_tabs_wallet_assets_test.dart`。
- `WalletLaunchChainCard` 与 `Launch2WalletRows` 保留为组件（由新的行构造函数与 `launch2WalletEntries` 组成），钱包首页不再直接使用。
- 经典 MEME 代币详情 `/meme/token` 仍可从既有链接（搜索、聊天代币卡）打开；是否也要收口由主代理 / 需求方定。
