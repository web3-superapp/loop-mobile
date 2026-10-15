# 0185 · 「LOOP 代币是否已开挖」改读 `hourly.claim.configurationReasonCode`（S195-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e342eb（0184 之上）。后端契约：loop-api 决策 0144 §8（`GET /v2/mining/rewards` 的
`hourly.claim` 新增必有字段 `configurationReasonCode`，= 领取路径的配置原因，已配置时为 `null`，不受账本原因遮挡）。修订 0184 §1 的
判定来源；0184 §2–§4 的页面呈现不变。不新增接口、请求、本地存储与依赖。

## Context

0184 只能从 `reasonCode` 推断：领取闸门先报账本原因（`NOTHING_SETTLED`、`NOTHING_TO_CLAIM`、`BELOW_MINIMUM` 等）再报配置，账本原因命中时
看不出合约配没配，只好按 unknown（= 未开挖）画，并借「最近一笔领取在主网」作间接证据。后端现在单独投影配置原因，盲区可以消除。

## Decision

### 1. codec（宽松读取）

`hourly.claim` 允许可选键 `configurationReasonCode`（`strictMapWithOptional`，其余未知键仍拒收）。`MiningClaimSummary` 新增
`configurationReported`（键是否在）与 `configurationReasonCode`。键缺失（旧后端）或值不是合法原因码时 `configurationReported = false`，
不因这一个字段让整个奖励资源读失败。

### 2. `miningTokenStage`

| `configurationReasonCode` | 阶段 |
| --- | --- |
| 键在且为 `null` | live |
| `MINING_CLAIM_CONTRACT_NOT_CONFIGURED`、`MINING_CLAIM_MAINNET_CLOSED` | preToken |
| `MINING_CLAIM_CHAIN_NOT_CONFIGURED`、`_SIGNER_NOT_CONFIGURED`、`_WRITES_DISABLED`（合约之后才检查） | live |
| `MINING_SETTLEMENT_UNAVAILABLE`（未配置结算库，在合约之前检查）及其它 | unknown（按 preToken 画） |
| 键不在（旧后端） | 退回 0184 §1 的全部推断（含主网领取证据） |

新字段在时只看它：`executable`、`reasonCode` 里的账本原因与最近领取的链都不再参与判定。「主网最近一笔领取」推断只保留在旧后端分支。

## Consequences

- 0184 Consequences 里的盲区（上线后账本原因先命中的账号仍看到「只统计算力」）在新后端上消失；旧后端上照旧。
- 后端全部升级到 0144 §8 之后，旧后端分支可在单独批次删除。

## Verification

- `test/s138_mining_rewards_test.dart` 新组「S195 · token stage by configurationReasonCode (decision 0185)」：codec 三态（null / 原因 / 缺键）
  与非法值退回旧分支、其余未知键仍拒收；六种账本原因 × null / 两种未开挖原因均以新字段为准；合约后原因为 live、结算库未配置为 unknown；
  新字段在时主网领取不再算证据；页面：`BELOW_MINIMUM` + `null` 画完整领取页（按钮置灰），`NOTHING_SETTLED` + 合约未配置只画算力与 notice。
- 0184 组与其余用例不带新键，走旧分支，原样通过。`test/support/s7_page_harness.dart` 的 `S7TokenStageRewards` 两态带上新字段（模拟当前后端）。
- mining 相关 53 个测试文件 1437 条通过（3 条原本跳过）；`bin/flutter analyze` 0；`dart format` 无改动；`python3 scripts/check_harness.py` 通过。
