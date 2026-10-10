# 0140 · 挖矿奖励页：双轨小时结算、分钟展示、五级邀请、Claim 领取（S138-mobile）

## Status

Accepted 2026-10-10。主代理下单（S138-mobile），基线 `integration/v2` 24695c0，分支 `feat/S138-mobile`。
依据：`docs/16-挖矿与邀请-中心化结算方案.md` §1、§2、§5、§6；需求方《LOOP 双轨挖矿开发说明》2026-10-10 §6.2、§7、§8.1；
loop-api 决策 0116 草稿（S138-api worktree 未合入时的 `mining-rewards-schemas.ts`）。不新增依赖、`pubspec.lock`
不变、路由清单不变（`mining-rewards` slug 与 `/mining/rewards` path 未动，只换挂载的页面）、视觉 token 不变。

## Context

旧 `mining-rewards`（`MiningRewardsScreen`，S7 决策 0058）是日结骨架：可领取与累计都是 `unavailable`，领取按钮恒禁用。
需求方 2026-10-10 改成两条轨道（NFT / Meme 币资产）每小时结算、下一小时按分钟展示上一小时奖励、五级邀请、小时结算后即可 Claim。
后端合同 `loop-api/docs/frontend-v2-mining-rewards-api.md` 与本批并行在写；下单给了一份扁平字段草案，S138-api 的工作区里则是
`GET /v2/mining/rewards` 旧键旁加 `hourly` 块（`*Raw` 整数串）。

## Decision

### 页面（`lib/features/mining_rewards/`，archetype `record`、布局 `dashboard`）

1. `/mining/rewards` 挂新页 `MiningRewardsHourlyScreen`；`MiningRewardsScreen` 文件保留、不再挂载。「我 → 挖矿奖励」与挖矿页的
   「奖励」入口都走同一 path，自动指向新页，无需改 `profile_v2_screens.dart`。
2. 六个模块（需求方 §8.1），自上而下：
   - **分钟增长**（页面唯一的大数字，figureXl Lime）：上一小时奖励展示进度、`n/60` 进度条、下次更新时间、上一小时总奖励与结算时段；
     首小时「首个小时结算后开始展示奖励」，窗口结束未出新结算「结算中」（展示整小时数）。
   - **奖励汇总**：累计已结算 / 累计已领取 / 当前可领取（三格，4 位小数、截断不进位）。
   - **领取**：本次可领取、状态胶囊（可领取 / 提交中 / 链上确认中 / 成功 / 失败，另有凭证过期）、领取按钮、处理说明、成功交易行（复制 BscScan 链接；
     App 无 url_launcher，同钱包交易详情的做法）。
   - **NFT 轨道**：真实 NFT 数量（单列一行，不与等效算力合并）、本人加权算力、邀请算力、总算力、上一小时奖励。
   - **Meme 币轨道**：资产明细（资产 + 算力）、本人 / 邀请 / 总算力、上一小时奖励。
   - **五级邀请**：层级 / 比例 / 有效人数 / NFT 算力 / 资产算力 五列表格 + 合计行 + 一行口径说明（只计下级本人算力、本人算力为 0 不计）。
   - 其后「领取记录」（`GET /v2/mining/claims`，到底自动读下一页）与来源行（ⓘ 里说明小时结算与「分钟增长只是展示」）。
3. 五态：无值时 `LoopChainStateBlock`（loading 骨架 / error / offline / unavailable / permission）；有值时 `hourly.displayState =
   unavailable` 只在页内一行提示。资金态：领取的 pending（提交中 / 确认中）、reverted（失败，余额不变）、submissionUnknown（已广播结果未知 → 锁定、
   只允许「重新上报」同一哈希或「继续查询」，不再签名）。
4. 视觉：卡片 `card` 面 16 圆角、无描边无阴影；每页一个 figureXl；数字全 tabular；分钟数字换分钟时上滑淡入一次（`LoopMotion.contentFadeIn`），
   reduced motion 下直接替换。

### 分钟推导规则（`mining_rewards_display.dart`，纯函数）

- 服务端时钟 `serverNow = serverTime + (设备现在 − 收到该答复的设备时刻)`；只用设备**时长**，不用设备的时刻；设备时钟回拨不让服务端时钟倒退。
  收到时刻取读控制器的 `valueObservedAt`（`loopReadClockProvider`），快照还原时为快照的 `observedAt`。
- 窗口起点 = `display.windowStart`，缺省用上一结算小时的 `epochEnd`；`m = clamp(floor((serverNow − windowStart) / 60 s), 0, 60)`。
- 展示值 `shown(m) = floor(total / 60) × m`（m < 60），`m = 60` 时 = `total`：除法余数在最后一分钟补齐，整小时展示总和等于实际奖励。
  （loop-api 0116 草稿的 `displayedRaw` 用 `floor(total × m / 60)`，两者差不超过 59 个最小单位，4 位小数下不可见；以需求方原文为准。）
- 服务端 `settling`，或推导出 `m ≥ 60` → 「结算中」，显示整小时数，立即重读一次，之后页面可见时每 30 s 重读（`LoopForegroundPoll`，切后台/被遮挡即停）。
- 无结算小时或 `awaiting_first_settlement` → 首小时文案，不显示任何增长；`unavailable` → 「暂时读不到结算结果」。
- 计时器只决定何时重画：在 `nextUpdateAt` 处排一次 `setState`；App 回到前台立即重算。刷新、切后台、换设备都由同一公式得出同一数字。
- 分钟增长不改变可领取：Claim 永远用 `claimable`（累计已结算 − 累计已成功领取）。

### Claim 流程

`领取` → `POST /v2/mining/claim/prepare {walletId}`（钱包取钱包目录的当前钱包）→ 单一签名出口抽屉（`LoopSignSheet`：操作、领取数量、收款钱包、合约、
网络、网络费、凭证有效期）→ Privy `eth_sendTransaction`（服务端交易原样）→ `POST /v2/mining/claim/report {claimId, transactionHash}` → 每 4 s 读
`GET /v2/mining/rewards` 的 `claim.latest`，到 `succeeded / failed / expired` 为止（最多 45 次，超时显示「继续查询」）。

- 签名前拒绝：凭证过期、`signing.allowed = false`、交易与复核内容不符（`to`/`data`/`chainId` 必须与合约和 calldata 一致）、钱包地址不符、链不允许。
- 链：领取合约先部署在 Launch 槽的 BSC 测试网；钱包边界只放行 Launch 槽两种 kind 离开主链（决策 0089），所以领取沿用 MEME 的做法走
  `IntentKind.launchPurchase`（决策 0120）。专用 kind 属 `lib/core` 与 Privy 签名器改动，留给主代理裁决。
- `payloadDigest`：后端给就用；0116 草稿没有，则对原样交易做 keccak-256（键排序的 JSON）作为绑定摘要。请后端补发。
- `CLAIM_GAS_INSUFFICIENT` → 关闭流程，开一个抽屉「BNB 不足以支付网络费，先用 USDT 兑换 BNB」+（若有）所需 BNB 数量 +「去兑换」：
  跳 `/wallet/swap?from=&to=`（预填 `suggestedSwap` 的资产对；数量不预填——建议数量是要换到的 BNB，兑换页输入的是支付额）。自动兑换待 `privySwap` 可执行。
- `CLAIM_NO_GAS_SOURCE` → 抽屉「钱包里没有 BNB，也没有可兑换的 USDT，先充值少量 BNB」+「去充值」（`/wallet/receive`）。
- 取消 / 钱包拒绝 / 链上失败：余额不变、页面回到可领取。已广播但上报失败或钱包结果未知：锁定，只给「重新上报」同一哈希（幂等）或轮询，不再打开签名。
- 服务端已有在途领取（`claim.latest.status` 为 `submitting`/`confirming`）：按钮禁用，页面接管轮询，不重复发。
- 幂等：prepare 每次一个新 key，只有结果未知（离线 / 取消 / 解析失败）时同一操作重放同一个 key；report 以 `claimId + hash` 为一操作。

### 缓存（决策 0095 / 0132）

- 新快照资源 `mining.rewards`，登记为**稳定**资源（30 天、同次运行可重复还原）：首帧直接画汇总与分钟进度，线上读取在后面替换。
- 还原值上的领取按钮一律禁用（「正在读取最新的可领取数量」），领取只基于本次运行的线上答复。

### Codec（`lib/integrations/backend/v2/mining_rewards/`）

同一个 `GET /v2/mining/rewards` 接受两份草案，按根上是否有 `hourly` 区分，都解成 `MiningRewardsView`；全部严格键，列出的可选键可缺。

- **hourly 块（loop-api 0116 草稿）**：根 `{hourly}` + 可选旧键 `claimable, claimExecutable, estimatedToday, accumulated, ledger, source,
  contractVersion`（旧键不解析）；`hourly` 严格 `{serverTime, decimals(=18), displayState(awaiting_first_settlement|displaying|settling|unavailable),
  reasonCode, totals{settledRaw, claimedRaw, claimableRaw}|null, lastHour{epochId, hourStart, hourEnd, settledAt, nftRewardRaw, assetRewardRaw,
  totalRewardRaw}|null, display{windowStart, windowEnd, totalRaw, perMinuteRaw, completedMinutes, displayedRaw, nextUpdateAt}|null,
  tracks{nft{realNftCount, selfPower, referralPower, totalPower, networkPower, budgetRaw, rewardRaw, holdings[{instanceId, communityId, countAtEnd,
  power}]}, asset{selfPower, referralPower, totalPower, networkPower, budgetRaw, rewardRaw, holdings[{assetId, balanceAtEndRaw, power}],
  excludedAssets[{assetId, reasonCode}]}}|null, referral{levels[5×{level, ratioBps, effectiveMembers, nftPower, assetPower, totalPower,
  nftUnitsByCommunity[{communityId, units}]}]}|null, parameters{versionId, configVersion, effectiveFrom, referralRatiosBps[5], minimumClaimRaw}|null,
  claim{executable, reasonCode, latest: claim|null}}`；`totals` 只有 `unavailable` 时可为 null。
- **扁平草案（本批下单）**：根必有 `settledTotal, claimedTotal, claimable, lastEpoch, display, nft, asset, invites, claim, serverTime`，可选
  `contractVersion, decimals, minimumClaim`；数量是整 LOOP 十进制串（≤ 18 位小数）。`lastEpoch{epochStart, epochEnd, totalReward, nftReward,
  assetReward}`（可选 `epochId, settledAt`）| null；`display{state(…|showing|…), minutesElapsed, minuteIncrement, nextUpdateAt}`（可选
  `windowStart, reasonCode`）；`nft{realCount, ownPower, invitePower, totalPower, reward}`|null；`asset{assets[{assetId, power}+可选 symbol, amount],
  ownPower, invitePower, totalPower, reward}`|null；`invites{levels[{level, ratePercent, activeMembers, nftPower, assetPower}+可选 totalPower],
  total{nftPower, assetPower}+可选 activeMembers, totalPower | null}`|null（total 缺省时由五层相加）；`claim{status(none|claimable|submitting|confirming|
  succeeded|failed|expired), lastTx(哈希串 | {txHash}+可选 chainId, amount, at | null)}` + 可选 `claimId, executable, reasonCode, amount`。
- 领取记录（两种）：0116 `claim` 对象 `{claimId, walletId, status, chainId, chainReference, contractAddress, cumulativeAmountRaw, amountRaw, nonce,
  deadline, transactionHash, blockNumber, failureReasonCode, createdAt, updatedAt}`；扁平 `{claimId, status, amount, createdAt}` + 可选
  `txHash, chainId, failureReasonCode, updatedAt`。列表 `{items, nextCursor}` + 可选 `decimals, contractVersion`。
- prepare 201：`{claim, intent{calldata{to, data, value:"0"}, unsignedTransaction{chainId, to, data, from}+可选 value, gas, nonce, type, maxFeePerGas,
  maxPriorityFeePerGas, gasPrice, signing{mode:"device_eth_send_transaction", allowed, reasonCode}}+可选 payloadDigest}` + 可选 `decimals, contractVersion`。
  report 200：`{claim}` + 可选 `decimals, contractVersion`。
- prepare 409 的两种 gas 拒绝：信封 `code` 为 `CLAIM_GAS_INSUFFICIENT`/`CLAIM_NO_GAS_SOURCE`，或 `INSUFFICIENT_BALANCE` + `detailsSafe.reasonCode`；
  兑换建议接受嵌套 `suggestedSwap{fromAssetId, toAssetId, fromSymbol, toSymbol, amount}` 或扁平 `suggestedSwapFromAssetId / …ToAssetId / …FromSymbol /
  …ToSymbol / …ToAmount`，以及 `requiredNativeAmount`；这两种拒绝在信封校验之前读，其余 409 仍按目录严格校验。

## 偏离与未做

- 页面不按 `mining` 能力位整页封锁：结算是否可用由答复自己的 `displayState` / `claim.executable` 说明（旧页按能力位封锁，dev 能力位仍是 pending）。
- Meme 资产只显示合约地址缩写（0116 草稿不带符号与精度，余额不显示）；扁平草案带 `symbol`/`amount` 时显示。
- 没有 Preview（`main_preview.dart`）演示数据：本页生产路径缺数据即 unavailable。
- 「去兑换」不预填数量（见上）；自动兑换未做。
- 领取签名沿用 `launchPurchase` kind（见上）。

## Consequences

- 后端合同落盘后按其字段收紧 codec：删掉未采用的那份草案的分支，保留严格键 + 可选键；`payloadDigest` 若后端补发即改为必填。
- 旧 `MiningRewardsScreen` 与 `miningRewardsControllerProvider` 不再被挂载；0116 在 `/v2/mining/rewards` 根上加 `hourly` 后，
  旧解码器（不认 `hourly`）只会在旧页上失败，旧页已无入口，可在下一批删除。
- 快照多一项 `mining.rewards`（稳定），上限 24 条不变。
- 新测试 `test/s138_mining_rewards_test.dart`：分钟推导（余数补齐、服务端时钟、首小时、结算中）、两份 codec 草案与可选键缺省、快照解码、
  gas 拒绝两种写法、页面六模块、分钟跳格与回前台重算、快照首帧、五态、Claim 五状态、完整领取、取消、去兑换、去充值、上报丢失只重报。
