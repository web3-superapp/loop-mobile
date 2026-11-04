# 0282 · 兑换走 Privy 自带 swap：只列 BSC 主网资产、无余额说明态、执行带 reviewSha256

## Status

Accepted · 2026-11-04（S357-mobile）。用户 11-04 裁决「选 A」：钱包兑换 = Privy 嵌入式钱包自带的 swap，不自建路由、不加平台抽成。后端半边是 loop-api 决策 0198（integration/v2 01bc062，`PRIVY_SWAP_EXECUTION_ENABLED` 默认 off）。主网真机验证由用户在 TF 包上做（docs/62），本单不改任何生产开关。

## Context

- Privy swap 只支持 `eip155:56`，不支持 Launch 测试网 97（S356 实测）。
- 0198 `on` 时：capability `privySwap.evidence = {status: confirmed, reasonCode: null}`；prepare 直接给 `awaiting_signature` + `signing.allowed = true`；`simulation` 仍如实是 `unavailable / provider_quote / SWAP_SIMULATION_PROVIDER_PENDING`；execute 体可带可选 `reviewSha256`（不符 → `409 DATA_STALE`，什么都不发）。`off` 与 0035 逐字节一致。
- App 侧确认键早已是两道门：`capability.isUsable`（available 且 evidence 非 pending）+ 签名抽屉里的 `intent.canSignAt`（`signing.allowed`、`awaiting_signature`、未过期、payload 在）。模拟结果只是抽屉里的一行事实，从不拦截。所以 0198 `on` 不需要改门禁逻辑，只需确认没有任何地方因模拟不可用而拦。

## Decision

1. **只列 BSC 主网资产**（`swapIsMainnetAssetId` = `assetId` 以 `eip155:56:` 开头）。兑换页拿到的余额先过 `swapMainnetBalances`，资产选择器、余额行、报价请求都只见主网行。别的页带进来的配对（MEME「去兑换」的 `from` / `to`）若不在主网，丢掉该侧、页顶一条 warn 提示 `wallet_swapMainnetOnly`（“Swap supports BNB Chain mainnet assets only.” / 「兑换只支持 BSC 主网资产。」），不报价。
2. **主网无余额说明态**：主网每一行都读到且 `displayBalance` 为 0（`swapHasNoMainnetBalance`）时，页面主体换成一块 `LoopEmptyState`（`swap-no-mainnet-balance`）：标题 `wallet_swapNoMainnetBalanceTitle`（“No BNB Chain mainnet balance” / 「BSC 主网暂无余额」），正文同第 1 条那句，唯一动作「接收」（`swap-receive-entry` → `WalletRoute.receive(walletId)`，现有接收页）。底部主按钮不画。任一行读取失败不算「无余额」：保留表单，选择器里那行照常写失败原因。用 `displayBalance` 而不是 `spendableBalance`：只剩 gas 储备的钱包不是「没有余额」，表单里选择器会把它折叠成不可选。
3. **确认键**：门禁不变（`isUsable` + 抽屉 `canSignAt`）。evidence `confirmed` 时 pending 提示消失、确认键显示倒计时可按 → prepare → 统一签名抽屉 → `generateAuthorizationSignature`（`privy_device_signer.dart`，对 `authorizationPayload` 原对象）→ execute → 结果页 `/wallet/tx/result?intentId=`（tx-result 现有 4 s 轮询到 `confirmed` / `failed` / `reverted` / `unknown`）。
4. **execute 带 `reviewSha256`**：`WalletIntentsGateway.execute` / `LoopV2WalletIntentsApi.execute` 加可选 `reviewSha256`，`MoneyActionSigner` 传 `intent.reviewSha256`（抽屉渲染的就是这份 intent）。客户端先按 `^[0-9a-f]{64}$` 校验，格式不对当 `400` 不发；为 `null` 时请求体与 0035 相同。响应键无变化，codec 不需要新增可选键。
5. **「我的」页兑换快捷键**只看 `privySwap` capability 是否 available，不看余额：主网无余额也可点，进页看说明（Figma 形态不动）。挖矿领取「去兑换」、行情代币页的兑换入口行为不变，文案已在 S355 迁入 ARB，本单只核对。

## Consequences

- 新文案两条，只在 `lib/l10n/fragments/wallet.json`（zh + en，链名按术语表写 BNB Chain）。
- 测试：`test/s357_swap_execution_test.dart`（主网过滤、读失败不算无余额、无余额说明态 + 接收、非主网配对丢弃、有余额报价态 + pending 不可按、confirmed 态确认 → 抽屉 → execute 带 review、`signing.allowed=false` 的 intent 不签、「我的」快捷键无余额仍可点、execute 请求体三例）。测试支持里加了 `swapEvidenceConfirmed`（发 `confirmed`）与 `s6SwapIntent(executable: true)`（0198 `on` 的 intent）。
- 0198 残余风险 3（Flutter SDK 的 `generateAuthorizationSignature` 是否与 Node SDK 同一 RFC 8785 规范化）只能在主网真机上验证；失败会表现为 execute 后 Privy 拒签 → intent `failed`（`PRIVY_SWAP_REJECTED`），不会花钱。
- 回滚：后端关 `PRIVY_SWAP_EXECUTION_ENABLED` 即回到 evidence pending、确认键不可按；本单客户端改动在 `off` 下无行为差异（除主网过滤与无余额说明态）。
