# 0162 · MEME v2 实例的 NFT 款出口：超时开盘与托管退款（S179-mobile）

## Status

Accepted 2026-10-14。基线 `integration/v2` 6f5eb19，与 loop-api S179 同批（后端兜底开盘 + 退款路由）。
不新增依赖、`pubspec.lock` 不变、路由与视觉 token 不变。新增两条写请求（退款 prepare / report）。

## Context

合约新增两条 NFT 款出口：发售结束后一段时间仍没人发布快照，任何人可开公开轮（后端兜底去开）；开盘后一段时间仍未毕业，
NFT 持有人可按比例退回托管款（正常每枚 100 USD1）。App 要在快照阶段说清何时可直接开盘、公开轮标明超时开盘，
并给持有人一个退款入口。

## Decision

1. 契约（字段名与枚举值照后端，不改）：实例详情可选
   `exitPaths: null | { snapshotTimeoutAt, timeoutOpenState: not_applicable|waiting|available|opened_by_timeout,
   refundOpensAt, refundState: not_applicable|waiting|open|closed_graduated, refundedCount, totalMinted }` 与
   `viewerNftRefunds: null | [{ tokenId, refunded, claimable, amount, opensAt }]`。缺失 / null / 非对象 / 时间或计数读不出
   一律读作「不支持」（`exitPaths = null`），整页不判无效；未知枚举只把那一条路径读作 `not_applicable`；
   `viewerNftRefunds` 非列表读作 null，读不出的单条跳过。模型 `Launch2ExitPaths` / `Launch2TimeoutOpenState` /
   `Launch2RefundState` / `Launch2NftRefund` / `Launch2NftRefundReport`。
2. 写路由：`POST …/instances/:id/nft/refund/prepare` 与 `…/nft/refund/report`，新端口 `Launch2NftRefundGateway`
   （与 `Launch2Gateway` 分开，旧 fake 与组合不动），`main.dart` 接 `loopV2Launch2NftRefundGatewayProvider`。
   prepare 回包与 `nft/prepare` 同一 `launch2Intent` 信封，kind `nft_refund`，只在退款路由（venue `nftEscrow`）接受，
   曲线路由收到它判无效；必须无 approval、属于本实例与本钱包。目标合约是实例的 NftEscrow（`claimRefund`）：
   `contractAddress` 与 `calldata.to` 都等于 `contracts.escrow`（loop-api S179 定稿）。prepare 请求体按 `nft/prepare`
   同形发 `{walletId, tokenId}`；report 请求体按外盘领取 report 发 `{intentId, transactionHash, walletId, tokenId}`。
   report 回包 `{nftRefundReport: {intentId, instanceId, walletId, tokenId, transactionHash, status: submitted|confirmed,
   amountUsd1, refundedAt, blockNumber, reportedAt}, contractVersion}`，App 只读 `contractVersion` 与
   `nftRefundReport.status / intentId`（`confirmed` 才算已确认）。
3. 项目页：
   - 快照阶段（`snapshot_pending`）阶段条第三行：`waiting`「快照未发布 · {snapshotTimeoutAt} 后任何人可直接开盘」，
     `available`「已到可开盘时间，等待开盘」（key `launch2-exit-timeout`，最多两行）。
   - 公开轮（`public`）且 `opened_by_timeout`：阶段标题后附注「超时开盘，无提前购」（`launch2-exit-opened-by-timeout`）。
   - 退款区（NFT 发售卡片、快照数字、内盘曲线块、毕业块之后各放一处，按状态画或不画）：
     `waiting` 且持有 NFT：一行「若 {refundOpensAt} 前未毕业，可按比例退回 NFT 款」；
     `open` 且持有：标题「退回 NFT 款」+「已退 x / y 枚」，每枚一行（NFT #编号、金额、徽标 可退 / 已退 / 不可退），
     可退一行带「退款」；`closed_graduated` 且有未退：一行「项目已毕业，NFT 款转入回购，不再退款」；其余不画。
     「持有」= `viewer.nftHeld > 0` 或 `viewerNftRefunds` 非空。
   - 「退款」：确认页（复用购买 NFT 确认页的部件，标题「退回 NFT 款」，展示 amount USD1）→ prepare → 合约须为本项目
     `contracts.escrow` 且无授权（读不到 escrow 地址同样拒签），否则「交易内容与确认内容不一致」；签名页地址行为「托管合约」→ 签名页（标题「退回 NFT 款」，字段「退回」= intent
     `expectedOut`）→ report → 立即重读详情；行变「已退」后页面通知「退回 NFT 款已在链上确认。」。上报失败只说
     「上报没有成功，链上结果不受影响」。拒绝留在该行下（`launch2-refund-failed-{id}`），带 reasonCode 的拒绝顺带重读。
   - 交易冻结（0161 `tradingHold`）期间「退款」禁用并给同一句。
4. 拒绝码（`launch2ReasonText`）：
   `LAUNCH2_REFUND_NOT_OPEN`「退款还没有开放，没有发起退款」、`LAUNCH2_REFUND_ALREADY_CLAIMED`「这枚 NFT 的款已经退过，
   没有重复退款」、`LAUNCH2_REFUND_NOT_OWNER`「这枚 NFT 不在当前钱包里，没有发起退款」、`LAUNCH2_REFUND_GRADUATED`
   「项目已毕业，NFT 款已转入回购，没有发起退款」、`LAUNCH2_EXIT_PATHS_UNSUPPORTED`「这个项目的合约不支持退款，没有发起退款」、
   `LAUNCH2_REFUND_NOTHING_TO_REFUND`（409，托管余额被没收清空）「托管里已经没有可退的款，没有发起退款」；
   report 的 `LAUNCH2_REFUND_INTENT_NOT_FOUND`（404）「找不到这笔退款记录，上报没有成功，链上结果不受影响」、
   `LAUNCH2_REFUND_TRANSACTION_CONFLICT`（409）「这笔退款已用另一笔交易上报过，这次上报没有记录，链上结果不受影响」
   （页面上 report 失败仍统一说「上报没有成功，链上结果不受影响」）；两个 hold 码沿用 0161。
   后端状态码：503 `EXIT_PATHS_UNSUPPORTED`、403 `NOT_OWNER`、409 `NOT_OPEN`（detailsSafe 带 `opensAt`，App 暂不读）/
   `GRADUATED` / `ALREADY_CLAIMED` / `NOTHING_TO_REFUND`。
5. 钱包 · 资产的 NFT 行：副标题末尾加「 · 可退款」，数据来自 `me/positions` 行上可选的 `viewerNftRefunds`。
   loop-api S179 的 `me/positions` **不带**该字段，所以此标记目前不会出现；解码保留，后端日后加上即生效。

## Consequences

- 新测试 `test/s179_launch2_escrow_exit_test.dart` 22 条：解码（缺失 / null / 全字段 / 未知枚举 / 读不出 / 单条跳过 /
  refund intent 只认退款路由 / 无 refunds 的持仓行不可退），八个退款拒绝码与标题，快照四态与公开轮附注，refundState 三态 × 有无 NFT，
  退款按钮走 prepare → 签名 → report 后重读变「已退」，拒绝留在行下且不签名，目标不是 `contracts.escrow` 的 intent 在钱包前拒签，
  钱包行无 refunds 时不带「可退款」（不断言其出现）。
- 样本为既有 fixture 手工加字段（intent 目标改为 fixture 的 escrow 地址），待抓取后端真实回包替换。对旧后端（无这些键）行为不变。
