# 0141 · 挖矿奖励页对齐 loop-api 0116 最终合同（S138a-mobile）

## Status

Accepted 2026-10-10。主代理下单（S138a-mobile），基线 `integration/v2` e59e90f，分支 `fix/S138a-rewards-align`。
依据：loop-api 决策 0116（`integration/v2` 38bdf9f 合入，本批核对到 0ac6a5b）、`docs/frontend-v2-mining-rewards-api.md`、
`openapi/loop-api.v2.json`；`docs/16-挖矿与邀请-中心化结算方案.md` §5（领取 gas 不足 → 一键去兑换）。不新增依赖、
`pubspec.lock` 不变、路由清单不变、视觉 token 不变。

## Context

决策 0140 在后端合同定稿前按两份草案（0116 草稿的 `hourly` 块 + 下单的扁平草案）写了双分支 codec，分钟展示用
`floor(total/60)×m`，领取签名借用 `IntentKind.launchPurchase`，旧日结页 `MiningRewardsScreen` 与其解码器留着不挂载。
0116 合入后合同只有 `hourly` 一种形状，旧日结页的解码器（不认 `hourly`）已经不能解 `/v2/mining/rewards`。

## Decision

这批把 codec / model / controller / 页面收紧到最终合同，并删掉被它取代的旧日结链路。

### Codec（`loop_v2_mining_rewards_codec.dart`）

- 只解 `hourly`：根 `{hourly, contractVersion}` 必填，旧日结键 `claimable / claimExecutable / estimatedToday / accumulated /
  ledger / source` 可选且不读（合同说它们「含义不变」，留给已退役的旧页）。扁平草案分支整段删除，传来即 invalid。
- `hourly` 十一键全部必填（可为 null 的按 OpenAPI：`reasonCode / totals / lastHour / display / tracks / referral / parameters`）；
  `decimals` 必须 18；`displayState` 只认 `awaiting_first_settlement | displaying | settling | unavailable`（草案的 `showing` 删）；
  `totals` 只有 `unavailable` 时可为 null；`displaying` 必须带 `lastHour`。
- 金额全部是 `*Raw` 原始整数串（`^(0|[1-9][0-9]{0,77})$`）→ `BigInt`；算力是十进制串（≤18 位小数）→ `Decimal`；不经浮点。
- `display` 七键：`windowStart / windowEnd / nextUpdateAt` 可 null，`totalRaw / perMinuteRaw / displayedRaw` 整数串，
  `completedMinutes` 0–60，`displayedRaw > totalRaw` 视为 invalid。
- `tracks.nft`：`realNftCount`（整数串）与 `selfPower / referralPower / totalPower / networkPower / budgetRaw / rewardRaw /
  holdings[{instanceId, communityId|null, countAtEnd, power}]` 严格校验；`tracks.asset` 加 `holdings[{assetId, balanceAtEndRaw,
  power}]` 与新的 `excludedAssets[{assetId, reasonCode}]`，资产 ID 去重。
- `referral.levels` 恒 5 项、`level` 1–5 不重复，比例来自 `ratioBps`（÷100 成百分比，页面不写死），`nftUnitsByCommunity` 校验但不展示；
  合计由五层相加。
- `parameters`：`versionId / configVersion / effectiveFrom / referralRatiosBps[5×0–10000] / minimumClaimRaw`，最低领取额从这里读。
- `claim{executable, reasonCode, latest}`：`executable` 必填（不再默认 true）；`latest` 与 `claims.items[]`、`prepare.claim`、
  `report.claim` 共用一个十五键的 claim 对象，状态六种 `claimable / submitting / confirming / succeeded / failed / expired`，
  `chainReference` 若非 null 必须与 `chainId` 一致。
- `prepare` 201：`{claim, intent{calldata{to, data, value:"0"}, unsignedTransaction, signing{mode, allowed, reasonCode}}, decimals,
  contractVersion}`；`unsignedTransaction` 严格十一键（OpenAPI 写 `additionalProperties: true`，但这份对象原样交给钱包，
  未审过的键拒收），费用键随 `type`（legacy → `gasPrice`，eip1559 → 两个 `max*`），`value` 必须 `0x0`。合同不发 `payloadDigest`，
  继续用 codec 对键排序 JSON 的 keccak-256 绑定签名抽屉与钱包载荷。
- `claims` / `report`：`decimals: 18` 与 `contractVersion` 必填；`claims` 每页 ≤ 20、`claimId` 不重复。
- gas 拒绝只认合同写法：`409 INSUFFICIENT_BALANCE` + `detailsSafe.reasonCode ∈ {CLAIM_GAS_INSUFFICIENT, CLAIM_NO_GAS_SOURCE}`，
  兑换建议读扁平 `suggestedSwapFromAssetId / ToAssetId / FromSymbol / ToSymbol / ToAmount` 与 `requiredNativeAmount`；
  草案的嵌套 `suggestedSwap{}` 与把 reason 放在信封 `code` 的写法删除。

### 分钟展示（`mining_rewards_display.dart`）

- 公式改为合同 §3.2：`displayedRaw(m) = m ≥ 60 ? total : floor(total × m / 60)`（BigInt），与服务端 `displayedRaw` 逐分钟一致；
  0140 的 `floor(total/60)×m` 废止。
- 窗口取 `display.windowStart / windowEnd / totalRaw`，缺省回落到 `lastHour.hourEnd`、+1 h、`totalRewardRaw`。
- 服务端 `completedMinutes` 等于本机推导的 m 时直接用服务端 `displayedRaw` 作首帧，之后各分钟按公式推导。
- `now ≥ windowEnd` 也视同 `settling`（之前只看 m ≥ 60）。阶段名 `showing` 改 `displaying`（Key `mining-minute-displaying`）。

### Claim

- 签名改用专用 `IntentKind.miningClaim`。新常量 `launchSlotIntentKinds = {launchPurchase, launchApproval, miningClaim}`，
  `SigningIntent.chainIsPermitted` 与 Privy `privyChainRefusal` 都只读这一个集合；`check_harness.py` 整集比对，第四个 kind 需新决策。
- 轮询按合同 §5.3：已有交易哈希且处于等待时，每 4 s 用**新的** Idempotency-Key 重报同一哈希（keyring 在成功后释放，下一次自然换 key），
  直到 `succeeded / failed / expired`，最多 45 次后给「继续查询」；没有哈希或上报丢失被锁定时，才读 `hourly.claim.latest`，
  不主动重报（由用户点「重新上报」）。
- `executable = false` 时按钮置灰并显示 `hourly.claim.reasonCode` 的中文（合同 §7 七个原因 + 结算不可用），可领取余额照常显示；
  prepare 失败文案补 `MINING_CLAIM_FUNDING_INSUFFICIENT`、`MINING_CLAIM_EXPIRED`；领取卡加「最低领取 x LOOP」一行（`minimumClaimRaw > 0` 时）。

### 页面

- `displayState = unavailable` 的页内提示按 `hourly.reasonCode` 区分 `MINING_PARAMETERS_PENDING` / `MINING_SETTLEMENT_UNAVAILABLE`。
- Meme 轨道：资产行只显示合约地址缩写 + 算力（合同不带符号与精度，`balanceAtEndRaw` 不渲染成整币）；`excludedAssets` 逐行显示
  「已退出（原因）」，`MINING_ASSET_GRADUATED_UNREADABLE` → 「已毕业，外盘余额与价格暂读不到」，不静默丢弃。

### 删除旧日结链路

`MiningRewardsScreen`（`mining_secondary_screens.dart`）、`MiningRewards` 模型、`miningRewardsControllerProvider`、
`MiningGateway.loadRewards`、`LoopV2MiningApi.getRewards` / `rewardsPath` 一并删除——0140 已不挂载，且其严格解码器不认 `hourly`，
留着只会是解不了的死代码。对应测试随之删除（见 Consequences）。

### Fixture

`test/fixtures/s138-mining-rewards/` 十份样例，每份带来源说明：`rewards_awaiting_captured`、`claims_empty_captured` 是 2026-10-10
从 Development 库经 loop-api 0ac6a5b `buildApp()+inject` 抓的真实答复（dev 尚无已结算小时、无审批参数版本）；其余八份
（displaying / unavailable / claims 一页 / prepare 201 / 三种 409 / report 200）按合同与 OpenAPI 手写，dev 结算出第一个小时后替换为抓取。

## Consequences

- 删除的测试全部只覆盖已退役的日结页或其解码器，由 `test/s138_mining_rewards_test.dart` 的新用例取代：
  `s7_mining_pages_test.dart` 的 `mining-rewards` 组（7 个）、`s7_api_contract_test.dart` 的四个 `getRewards` 解码用例、
  `s59_mining_structure_test.dart` 的「奖励与领取」顺序用例、`s8_launch_mining_state_pages_test.dart` /
  `s8_offline_permission_states_test.dart` 里的 `mining-rewards` 五态与离线/权限行；`s7_api_contract_test.dart` 中「读失败不显示
  结果未确认」改用 `getSummary` 继续覆盖；`device_preflight_replay_test.dart` 的 `/v2/mining/rewards` 路由改登记到
  `DioLoopV2MiningRewardsApi#getRewards`。新 s138 测试覆盖：§3.2 推导、codec 严格键与六种状态、fixture 回放、gas 拒绝、
  `miningClaim` 只在已发布 Launch 槽放行、页面六模块、五态、领取全流程、取消、去兑换、去充值、上报丢失只重报。
- `/v2/mining/rewards/epochs`（每小时明细）合同已有、本批未接：需求方 §8.1 六模块没有逐小时列表，接入需要主代理定页面位置。
- 快照资源 `mining.rewards` 不变；旧格式快照解不开即丢弃，首帧回到读取态。
- `unsignedTransaction` 比 OpenAPI 更严（不收额外键）；后端若加键，需同步本 codec。
