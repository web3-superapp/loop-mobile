# 0119 · 钱包页 OKX 式重排：总资产 + 眼睛 + 24h、四键、无包裹资产行、底部入口含设置（S114）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S112-S114-intel-wallet-visual.md` §4），S114-mobile 实施。
基线 `integration/v2` 9e46f42（已含 S112 / 0117 的 `rise / fall`、`LoopInlineUnavailable`、`LoopProvenanceLine`）。
后端契约 loop-api `integration/v2` 148b1e0（loop-api 决策 0100：`valuation.change24hPct`、`netWorth.change24h`）。
客户端单侧：不新增依赖、`pubspec.lock` 不变、路由清单不变、`lib/app.dart` / theme / widgets / feature switches 不改；
只改 `lib/features/wallet/**`、`lib/integrations/backend/v2/wallet/**` 与测试。任何资金动作的语义不变：发送、兑换仍按
各自 capability 闸门放行，签名仍只走统一签名出口。

## Context

1. 需求方 v3（`LOOP/docs/09` §1 位置 5、§6.1 第 7 条）：钱包一级页「直接抄 OKX 第一个菜单页面的上半部分」，下面放
   扫码 / 兑换与设置；钱包管理与安全收进这个一级页。裁决 B6：钱包页底部放「设置」。§6.2：减少包裹、去英文小标题与
   开发味文案；D2：列表滚动加载，不要分页控件；D3：默认绿涨红跌。
2. 旧页：Lime 账本卡（`WALLET LEDGER`）+ Pay 胶囊 + 兑换 + 发送 / 接收 / 跨链三宫格 + 算力条 + `Wallet Assets` 分组卡
   （每行「可动用 · 算力」三行副标题）+ 区块脚注 + `Security & Connections` 四行（副标题含 `allowance()`、
   `approve(spender, 0)`、RPC）。链节点（`bscRead`）关闭时整页大卡，余额读失败时资产区一整张状态卡。
3. 后端 0100 已部署：每行 `valuation.change24hPct`（百分点字符串或 `null`）；`netWorth.change24h` 三态——
   (a) `{usd(6 位), pct(4 位)}`；(b) `null` 且带 `change24hUnavailable.reasonCode = PRICE_CHANGE_PARTIAL`；
   (c) `netWorth` 本身 unavailable 时两个字段都不出现。

## Decision

### 1. 编解码（`loop_v2_wallet_api.dart`）

- `valuation` 可用分支把 `change24hPct` 列为必需键，值为有符号十进制字符串或 `null`，进 `LoopValuationAvailable.change24hPct`。
- `netWorth` 可用分支把 `change24h` 列为必需键、`change24hUnavailable` 为可选键，二者互斥且必须恰有其一：有值 →
  `LoopNetWorthChangeAvailable(usd, pct)`（均有符号 `Decimal`）；`null` + 理由 → `LoopNetWorthChangeUnavailable(reasonCode)`；
  `null` 无理由、有值又带理由、缺键、畸形值一律 `invalidPayload`。unavailable 分支仍是严格的 `{status, reasonCode}`，
  多出任何一个 24h 字段即拒绝（状态 c）。
- 旧快照（0095）里没有这些键的正文会被今天的解码器拒绝，按既有规则「不是快照」，页面回到骨架，不会把旧形状当新数据。

### 2. 钱包页（`WalletScreen`，`wallet_home_widgets.dart`）

- 顶部「总资产」小标 + 眼睛 + (i) + figureXl 大数字（点按或右侧箭头进净值明细）+ 24h 行：有值 `▲ $x (+x%) · 24h`，颜色只经
  `LoopPriceMove`（rise / fall，持平无箭头 muted）；`null` 一行弱化「24h 变动暂不可用」；净值不可用不画这一行。弱化说明行：
  地址、`N 项资产暂无价格，未计入`（partial）、`数据可能过期`（stale）、不可用时的服务端理由。非 release 构建的环境标签
  仍在这一行右端。
- 眼睛：遮住总额、24h 金额、每行数量与估值（`****`），涨跌百分比保留。状态在 `walletAmountsHiddenProvider`（非
  autoDispose 的进程内 Notifier），本次运行内记忆，不落盘（AGENTS 23）。净值明细页共用同一状态。
- (i)：弹层说明「总资产是估值，不是可用余额」，并列出价格来源、观察时间、未计入项数、24h 说明、余额区块、确认数、
  手续费保留——旧页面常驻的「净值不是可用余额」与来源脚注收进这里。
- 右上角：交易记录、钱包管理（原「切换钱包」改名）。
- 四键一排等宽（圆形图标 + 文字）：接收 → `WalletRoute.receive(walletId)`、发送 → `/wallet/send`、兑换 →
  `/wallet/swap`、扫码 → `/scan`（沿用 0113：扫码转账，`pay` 页不动；键仍是 `wallet-pay-entry` 以满足 harness）。
  发送 / 兑换闸门关闭时保持形状、禁用语义、点按 toast 服务端理由，与旧页一致。
- 资产：标题「资产」+ 右侧小标签「产生算力」（点开弹层：说明 + 原 `WalletHoldingsPowerHint` + 去挖矿）。行无包裹卡：
  Logo 40 · SYMBOL / 名称（附 `以 WBNB 计价`、`数据可能过期`、`待确认 x`、`数据源尚未对齐`）· 右侧数量 /
  `≈$x · ▲x%`；估值不可用写「暂无估值」；`change24hPct = null` 不画百分比。读不到的行保留 Logo 与代码，第二行
  `LoopInlineUnavailable`「余额读不到 · 服务端理由」+ 重试。零余额（读到且恰为 0、无待确认入账）默认折叠，列表下
  「隐藏零余额资产 · N 项」开关，状态 `walletHideZeroBalancesProvider` 同样只在本次运行内记忆；读不到的行永远不算 0。
- 整个余额读失败不再是整块状态卡：资产标题下一行 `LoopInlineUnavailable`，按阶段区分文案与 key
  （`wallet-balances-state-offline / error / unavailable / permission`；permission 无重试），四键与入口组照常。
  `bscRead` 关闭（dev RPC 挂掉）不再整页拦截：仍读钱包清单，不发余额请求，资产区一行服务端理由；只有 `walletRead`
  关闭才整页 `LoopCapabilityPageBlock`。
- 区块脚注合并为一行 `LoopProvenanceLine`（「区块 N · 来源 DexScreener · 观察于 HH:mm」，点开含确认数与手续费保留）。
- 底部入口组（有图标行）：跨链 → `/wallet/bridge`、授权与网络 → 二级列表弹层（代币授权 `/wallet/approvals`、网络
  `/wallet/networks`、DApp 网址核对 `/wallet/dapp`）、安全中心 → `/profile/security`、设置 → `/profile/settings`。
  入口组在没有钱包、清单读失败时也在，设置始终可达。
- 文案：去掉 `WALLET LEDGER / Wallet Assets / Security & Connections`；授权行副标题改为「查看授出的额度，不再需要的可以收回」，
  网络「已启用的网络与连接状态」，DApp「打开前先核对网址；连接与签名暂未开放」。
- 每行算力（「算力 x」）不再画在资产行上，页面不再读 `mining/assets`；下拉刷新只在算力摘要已被读过时重读它。

### 3. 净值明细 / 交易历史 / 其它钱包子页

- 净值明细页头改用与钱包页同一个 `WalletTotalHeader`（总资产 + 眼睛 + (i) + 24h），像代币页以价格开头；去掉 Chalk 卡与
  `WALLET OVERVIEW`、去掉重复徽章条；「按资产」行与钱包页同款；来源一行；30D 走势面板保留（文案去掉「24h 涨跌」）。
- 交易历史：「加载更多」按钮改为 `LoopLoadMoreSentinel`（列表末端进入视野时按 cursor 请求一次，同一 cursor 不再请求），
  请求中末尾一行骨架；下一页失败仍是原来的离线卡 / 错误卡与重试，已显示的行保留；无更多时一行「没有更早的记录」。
  hero 的 `WALLET ACTIVITY` 改「钱包记录」、去掉 `N TXNS` 戳记。
- 钱包子页英文小标题顺手改中文：`WALLET ASSET` → 钱包资产、`Wallet 收发记录` → 收发记录、`RECEIVE ADDRESS` → 收款地址、
  `WALLET IDENTITY` → 我的钱包、`NETWORK HEALTH` → 网络状态。

### 与设计 §4 的偏离

| 设计 §4 | 实施 | 原因 |
| --- | --- | --- |
| 「授权与网络」合并为二级列表**页** | 二级列表**弹层**（三行，各开原页面） | 新页需要新路由，路由表 / `app.dart` 不在本单边界内；弹层零路由改动、返回关系最短。需要独立页时由主代理加路由 |
| 眼睛、扫码用图标 | 眼睛与扫码键用 Material `Icons.visibility*` / `Icons.qr_code_scanner_rounded` | LOOP 图标集里没有 eye / scan，新增图标属于 widgets/assets，不在本单边界内 |
| 资产行 `▲x%` 在 `change24hPct = null` 时 | 不画百分比（后端文档写「显示 —」） | AGENTS 25：未读到的值不得画成破折号 |
| （未提及）资产行算力 | 去掉每行「算力 x」，页面不再读 `mining/assets` | §4 行结构不含算力；算力集中到「产生算力」标签弹层 |
| （未提及）`bscRead` 关闭 | 不再整页拦截，资产区一行不可用 | §5「dev RPC 失败时资产行显示 inline 不可用而不是整页大卡」 |
| （未提及）其它钱包子页英文 kicker | 一并改中文 | §6.2 去英文小标题；不改布局 |

## Consequences

- 0092 用户裁决（资产回到一张分组卡、行内「可动用 · 算力」）被本决策取代：钱包页资产行无包裹、无「可动用」、无算力；
  「可动用」与手续费保留在资产页（`wallet-asset`）照旧分开展示（AGENTS 25 的五个口径不变）。
- 测试：新增 `test/s114_wallet_okx_layout_test.dart`（编解码三态与 `change24hPct`、24h 三态与颜色、眼睛遮挡与会话内
  记忆、(i)、四键跳转与闸门、零余额折叠与读不到的行不折叠、设置入口、交易历史滚动加载）；更新 `s5_wallet_pages_test`、
  `s58_wallet_layout_test`、`s5_offline_permission_states_test`、`s8_chain_state_pages_test`、`s88_loading_experience_test`、
  `s88d_followups_test`、`s91_backend_identity_test`、`s26_wallet_money_action_promises_test` 中依赖旧布局的断言。
- 未验证：真机 / 模拟器视觉（字号、留白、眼睛与 (i) 的点按区、深浅地面）、dev 环境 RPC 真实失败时的整页表现、
  后端 `change24h` 真实数据的颜色与舍入显示；`flutter build apk --debug` 未跑（不是特性检查点要求的原生变更）。
- 待办：红涨绿跌偏好（D3 后半，AGENTS 23 限制）；授权与网络若需要独立路由页；钱包子页的英文戳记（`QR READY`、
  `N WALLETS` 等）未动。
