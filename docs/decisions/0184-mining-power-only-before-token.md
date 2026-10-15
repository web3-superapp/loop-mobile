# 0184 · LOOP 代币上线前，挖矿各页只画算力、名次与邀请，不画任何 LOOP 数量（S191-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` b4e18d3（0183 之上）。来源：主仓库 `docs/36-需求方10题答复-2026-10-15.md`
第 4 题与追问答复（需求方：「代币没上线前只做算力统计，不预先给代币数量，等代币上线才正式开挖」）。修订 0155（Coming soon）与 0167
（挖矿奖励页账本卡）在代币上线前的呈现；上线后两者原样。不改后端、不新增接口与请求类型、不新增设备本地存储、不新增依赖；
路由、状态合同、领取流程与签名出口不变。

## Context

0155 之后，代币未上线时 App 仍按小时把奖励数量算出来显示：挖矿奖励页的分钟增长「N LOOP」、累计已结算 / 已领取 / 可领取、
两条轨道的「上一小时奖励 N LOOP」、领取记录；我的挖矿主卡的「今日预估」；钱包算力条的「今日预估 N LOOP」；挖矿规则的每日产量。
领取按钮是置灰的 Coming soon，说明行写「奖励已记在账上」。需求方要的是：上线前只统计算力，不给代币数量；上线那一刻正式开挖，之前不补发。

## Decision

### 1. 开关：领取合约是否已配置（`miningTokenStage`）

不新增接口：读 `GET /v2/mining/rewards` 的 `hourly.claim`（与挖矿奖励页同一 provider，`watchMiningTokenLive` 供页外读，已读过不再请求）。

| 服务端回答 | 阶段 |
| --- | --- |
| `executable: true` | live |
| `MINING_CLAIM_CONTRACT_NOT_CONFIGURED`、`MINING_CLAIM_MAINNET_CLOSED` | preToken |
| 合约之后才检查的配置原因：`CHAIN_NOT_CONFIGURED`、`SIGNER_NOT_CONFIGURED`、`WRITES_DISABLED`、`CONTRACT_PAUSED`、`CHAIN_READ_FAILED`、`FUNDING_INSUFFICIENT` | live |
| 最近一笔领取在 BSC 主网（`eip155:56`）上 | live |
| 其余（账本原因先命中：`SETTLEMENT_UNAVAILABLE`、`PARAMETERS_PENDING`、`NOTHING_SETTLED`、`NOTHING_TO_CLAIM`、`BELOW_MINIMUM`、`IN_FLIGHT`；资源未读到） | unknown |

`miningTokenLive` 只在 live 时为真；**unknown 按 preToken 画**（fail-closed：看不出代币已上线就不画 LOOP 数量）。测试网上的旧领取不算证据：
测试合约可能配过又撤掉。后台把领取合约配上、且该账号的领取闸门走到配置检查那一刻，页面自动回到原样，客户端无需改动。

### 2. 未开挖时各页

- **挖矿奖励**（`mining-rewards`）
  - 主视觉：kicker「上一小时算力」；展示中 / 结算中为 lime 账本卡，heading「{NFT + Meme 两轨总算力} 算力」，caption「上一小时有效，已计入算力统计」/
    「上一小时没有算力」/ 结算中「下一小时结算后更新」+ 印章「结算中」；细节条「NFT 算力 x · Meme 币算力 y」与「统计时段 HH:mm–HH:mm · 每个整点统计一次」。
    不画分钟进度条与滚动数字（分钟展示是奖励的）。等待首个小时 / 读不到时仍是 quiet 卡，文案去掉「按分钟展示、可领取」。
  - 「奖励汇总」改「算力汇总」（`MiningPowerSummary`，key `mining-power-summary`）：上一小时算力 / NFT 算力 / Meme 币算力 / 有效邀请 N 人。
  - 领取区整块换成一条 `LoopNotice`（key `mining-power-only-notice`）「LOOP 代币上线后开始正式开挖，上线前只统计算力」；不画领取卡、按钮与 Coming soon。
  - 两条轨道去掉「上一小时奖励 N LOOP」行；五级邀请不变（只有算力与人数）；「领取记录」整段不画；来源行说明改为只统计算力。
- **我的挖矿**（`mining`）：主卡三格改为 全网算力 / 上一小时算力 / 有效邀请（不再有今日预估、累计已挖、待领取及其原因行）；
  第一个按钮「小时算力」（仍打开挖矿奖励页），按钮下一行同一句 notice（key `mining-summary-hero-power-only`）；公式待批准时 caption 只说算力。
- **挖矿规则**：版本的「每日产出」行不画产量数字，caption「LOOP 代币上线后公布」。
- **钱包算力条**（`wallet-power-hint`）：只写「N 算力」，不写「今日预估 N LOOP」。
- 已确认无需改：挖矿资产 / 社区挖矿 / 邀请页、「我」页（总算力与名次）、算力榜（只画算力、权重、人数）、社区主页「预估/日」（一直是 —）。

### 3. Coming soon 退役

0155 的 Coming soon 按钮、说明行「LOOP 代币上线后开放领取，奖励已记在账上」与 `MiningClaimSummary.comingSoon` 删除：该原因码现在整块换成
§2 的 notice。`miningClaimUnavailableText` / `miningClaimPrepareFailureText` 对该码兜底返回同一句 notice。挖矿两个目录不再有「Coming soon」文案，全仓 `lib/` 不再有「已记在账上」（钱包 `deferred_screens.dart` 的 Coming soon 徽标与本决策无关，未动）。

### 4. 已开挖时
全部照旧（0155 之前的「领取」按钮、0167 的账本卡与分钟展示、今日预估、领取记录、规则产量）。

## Consequences

- unknown 按未开挖画：**代币上线后**，领取闸门先停在账本原因的账号（还没结算过有算力的小时、可领取为 0 或低于最低领取、且没有主网领取记录）
  仍会看到「只统计算力」页与那句 notice，直到它可领取 ≥ 最低额度。要消除这一点需后端单独投影配置原因（例如 `hourly.claim` 增加不受账本原因遮挡的
  `configurationReasonCode`，即 `miningClaimUnavailableReason(deps)`）；本批按「不改后端」未做，留给上线前的后端批次。
- 钱包首页与挖矿规则页多读一次 `GET /v2/mining/rewards`（与挖矿奖励页共享 provider，同一会话内不重复请求；能力位阻断时规则页不读）。
- 页面标题「挖矿奖励」、路由标题「奖励与领取」、「我」页的「挖矿奖励」行与「奖励」按钮未改名（导航一致性），上线前读者从这里进入的是算力页。

## Verification

- `test/s138_mining_rewards_test.dart` 新组「S191 · power only before the LOOP token (decision 0184)」：未开挖时奖励页全部 `RichText` 无
  「数字 + LOOP」（首屏与滚到底各查一次）、主视觉为算力、算力汇总、领取区是 notice 且无领取卡 / 按钮 / Coming soon、轨道无奖励行、无领取记录；
  账本原因（NOTHING_TO_CLAIM / BELOW_MINIMUM / NOTHING_SETTLED / MAINNET_CLOSED）同样只画算力；可执行与合约后原因时原样；`miningTokenStage` 全表
  （含主网 / 测试网领取证据）；我的挖矿未开挖时三格与按钮文案、notice、无 LOOP 数量，已开挖时原样。原 0155 组删除；0123 闸门表只在 live 原因下挂页，
  其余原因只校验文案函数；「nothing settled」「first own hour」「awaiting folio」三条随新文案改；in-flight 用例的领取改到主网。
- `test/s7_mining_pages_test.dart`：规则页未开挖时不画产量；钱包算力条未开挖 / 已开挖两态；原有五条主卡用例与规则用例以 `s7TokenLive()` 挂载。
- `test/s59_mining_structure_test.dart` 主卡结构用例以 `s7TokenLive()` 挂载。`test/support/s7_page_harness.dart` 新增 `S7TokenStageRewards` 与 `s7TokenLive()`。
- mining / profile / intel / wallet / 导航相关 23 个测试文件 592 条通过；`bin/flutter analyze` 0；`python3 scripts/check_harness.py` 通过（含 S7 挖矿真值守卫）。
