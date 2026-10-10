# 0143 · 挖矿领取摘要校验与 0123 原因码（S147-mobile）

## Status

Accepted 2026-10-10。主代理下单（S147-mobile），基线 `integration/v2` a4adaf7（已含 0141、0142），分支 `feat/S147-mobile`。
依据：loop-api 决策 0123（S147-api 536e74f，尚未合入、dev 未升级）、`docs/frontend-v2-mining-rewards-api.md` §3.3 / §3.4 /
§5.2 / §7、`openapi/loop-api.v2.json`；本仓决策 0141。不新增依赖、`pubspec.lock` 不变、路由清单不变、视觉 token 不变。

## Context

0141 写 codec 时合同不发 `payloadDigest`，codec 用自己对 `unsignedTransaction` 键排序 JSON 的 keccak-256 绑定签名抽屉与钱包载荷，
且 `intent` 用三键 `strictMap` 读——0123 加了第四个键后，现有包会把每个 prepare 201 判成 invalidPayload。0123 同时把
`hourly.claim.executable` 收紧（可领取为 0、低于最低额、领取在途都给 `false`）并新增 `MINING_NOTHING_SETTLED`；Meme 轨道的
`power` 改为「持有数量 TWAB × Mining Weight」，不乘价格。

## Decision

### `claim/prepare` 摘要（`loop_v2_mining_rewards_codec.dart`）

- `intent` 严格四键：`calldata / unsignedTransaction / payloadDigest / signing`。缺 `payloadDigest`、多键都 invalid。
- `payloadDigest` 必须匹配 `^0x[0-9a-f]{64}$`（服务端 viem `keccak256` 输出小写）。
- codec 用 `localDigest`（键按码元排序、无空白、`chainId` 为 JSON 数字、`null` 保留，keccak-256 of UTF-8）对**将交给钱包的同一份**
  `unsignedTransaction` 自算，`'0x' + local != payloadDigest` 即 invalid——prepare 失败，不会出现签名抽屉，也就不会签。
- `MiningClaimIntent.payloadDigest` 改存服务端值，新增 `localPayloadDigest` 与 `digestMatches`；`SigningIntent.payloadDigest` 传服务端值。
  `MiningClaimSigner.refusalBeforeWallet` 在 `payloadMatchesReview` 之外再查 `digestMatches`，不一致返回 `REVIEW_PAYLOAD_MISMATCH`
  （防御：codec 之外构造的 intent 也到不了钱包）。替换 0141「只用本地 keccak 绑定」的做法。
- `unsignedTransaction` 仍严格十一键（0123 起 OpenAPI 也是 `additionalProperties: false`，两边一致）。

### `hourly.claim.executable` 原因码（`mining_rewards_screen.dart`）

- `miningClaimUnavailableText(reasonCode, {minimum})` 按合同 §3.4 顺序列出：`MINING_SETTLEMENT_UNAVAILABLE` 结算服务暂时不可用，暂不能领取 →
  `MINING_PARAMETERS_PENDING` 挖矿规则待生效，暂不能领取 → `MINING_NOTHING_SETTLED` 首个小时结算后可领取 → `MINING_CLAIM_NOTHING_TO_CLAIM`
  暂无可领取 → `MINING_CLAIM_BELOW_MINIMUM` 满 x LOOP 可领取（x 取 `parameters.minimumClaimRaw`；缺参数时「可领取数量未达到最低领取数量」）→
  `MINING_CLAIM_IN_FLIGHT` 上一笔领取还在处理中，完成后再领取 → 五个配置原因（文案不变）；未知原因「领取暂不可用」。
  `executable = false` 时按钮置灰、显示该行，可领取余额照常显示。本地「最新一笔在途」判断改用同一句 IN_FLIGHT 文案。
- 在途时状态胶囊显示该笔进度（提交中 / 链上确认中），页面按 0141 继续用同一哈希重报跟进，不发起新 prepare。

### 无结算时的提示区分三种

`miningDisplayReasonText` 区分：`MINING_SETTLEMENT_UNAVAILABLE`（结算服务不可用，`displayState = unavailable` 时的页内提示）、
`MINING_PARAMETERS_PENDING`（挖矿规则待生效，暂时没有结算）、`MINING_NOTHING_SETTLED`（规则已生效，首个小时结算后开始展示并可领取）。
`awaiting_first_settlement` 时分钟增长卡的说明行改读 `miningAwaitingReason(view)`：`hourly.reasonCode` 优先，否则取
`hourly.claim.reasonCode == MINING_NOTHING_SETTLED`，都没有时保留原句。

### Meme 轨道按数量加权

资产轨卡片在分隔线下加说明行「按持有数量加权：算力 = 该小时平均持有数量 × 挖矿权重」（Key `mining-asset-basis`）。页面原本没有「估值」字样；
`MINING_ASSET_GRADUATED_UNREADABLE` 文案由「已毕业，外盘余额与价格暂读不到」改为「已毕业，外盘持有数量暂读不到」——0123 起不再读价格，
毕业资产退出只因外盘余额未索引。

### Fixture

`test/fixtures/s138-mining-rewards/` 由十份变十二份：`prepare_201` 加 `intent.payloadDigest`
（`0x398f74e0…8f44`，用 S147-api 的 viem `keccak256` 对规范 JSON 算出，测试里用 codec 与一个按服务端测试写法独立拼串的实现各算一次比对）；
新增 `rewards_nothing_settled`（参数已批准、无已结算小时：`lastHour / display / tracks` 为 null、`hourly.reasonCode` null、五层零值、
`claim.reasonCode = MINING_NOTHING_SETTLED`，形状照 `hourly-rewards-service.ts hourlyBlock()`）与 `rewards_in_flight`（`confirming`
的 `latest`、`MINING_CLAIM_IN_FLIGHT`、可领取余额仍含未确认金额）。三份都是按合同手写，dev 升级到 0123 后替换为实抓。

## Consequences

- 新包与 0123 之前的后端不兼容：老后端不发 `payloadDigest`，prepare 一律 invalid（领取失败、不签名）。上线顺序必须是后端 0123 先于本包。
  反向（老包 + 新后端）同样全部 invalid，即 0123 记录的已知断点。
- 0141 的抓取样例 `rewards_awaiting_captured` 里 `claim.executable` 仍是 `true`（0123 前的口径），保留为历史抓取；页面在可领取为 0 时由本地
  兜底文案「现在没有可领取的 LOOP」置灰。
- 旧挖矿页（`lib/features/mining/`，`/v2/mining/summary` 的资产行）仍显示服务端下发的「持有量 × 参考价 × 权重」公式与参考价——那是 S7
  旧接口，不在本批范围；是否随 0123 收掉需主代理定。
- 测试：`test/s138_mining_rewards_test.dart` 新增 / 改写 codec 摘要严格性（缺、不一致、交易被改、格式错、第五键）、规范 JSON 已知答案、
  签名器拒签、原因码逐条文案与按钮态、无结算三种提示、在途进度、两份新 fixture 回放、资产轨说明行。
