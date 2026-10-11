# 0147 · 2026-10-11 接 loop-api S148（决策 0125）的契约键：挖矿 `assetPowerBasis`、规则新公式 key、项目 `communityId`、奖励首个本人结算小时（S149-mobile）

## Status

Accepted 2026-10-11。主代理下单（S149-mobile），基线 `integration/v2` 3cd40d5（已含 0144 / 0145 / 0146），分支 `feat/S149-mobile`。
依据：loop-api S148-api ba6aa45、决策 0125，`docs/frontend-v2-mining-api.md` S148 节、`docs/frontend-v2-mining-rewards-api.md` §8、
`docs/frontend-v2-launch-api.md` S148 节、`openapi/loop-api.v2.json`。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变。

## Context

S148-api 改了几处响应形状，而 App 的 codec 是严格键集：`/v2/mining/summary` 与 `/v2/mining/assets` 多了必有键 `assetPowerBasis`，
`/v2/launch/projects*` 的项目对象在绑定社区时多 `communityId`。不处理的话升级后这几条读接口整体判无效。同时规则页公式 key 换成
`mining.rules.formula.holdingTimesWeight`、`priceGuardRules` 废弃；奖励页 `awaiting_first_settlement` 改按「本人」判定；claim 门槛加第 8 条（合约暂停 / 读链失败）。
本批同时收掉 0146 的未决项 1、2（服务端已改数量口径并下发 `assetPowerBasis` 与新 key）。

## Decision

### 1. `assetPowerBasis`（summary / assets）

- 模型新增 `MiningAssetPowerBasis { quantity }`，`MiningSummary.assetPowerBasis`、`MiningAssets.assetPowerBasis`（可空）。
- codec 用 `strictMapWithOptional`：键**可缺省**（读作 `null` = 0125 之前的服务端），出现时必须是 `"quantity"`，`null` / 其他值 / 非字符串一律 invalid；
  其他未知键照旧拒绝。OpenAPI 把它列为 required，客户端放宽为可选是为了 App 与 API 任意先后上线都不把整页判无效。
- 页面不改（0146 已显示「持有量 × 权重」）。

### 2. 规则页

- `miningRuleKeyText` 加 `mining.rules.formula.holdingTimesWeight` →「算力 = 持有量 × 权重」；旧 key 的译文保留（老服务端仍按价格算时如实说明）。
- `priceGuardRules` 继续解析（字段注释标 deprecated），规则页不再画「Reference Price Guard」分区；待批准版本的说明去掉「价格保护阈值」。

### 3. 项目 `communityId`（经典目录 `/v2/launch/projects*`）

- `LaunchProject.communityId`（可空）：键只在绑定时出现；出现时必须是 UUID，`null` 值或非 UUID 判 invalid（schema 用「缺省」表示未绑定）。
- 请求体：`LaunchProjectDraft.community`（`LaunchDraftCommunity`），三态：`keep()`（默认，不发键——创建 = 不绑定且幂等摘要与之前逐字节一致；编辑 = 保持原值）、
  `bind(id)`（发 UUID）、`clear()`（发 `null`，编辑时清除）。本地形状校验新增 `LaunchDraftField.community`「关联社区的标识无效，请重新选择。」。
- 422 `VALIDATION_FAILED` / `LAUNCH_COMMUNITY_NOT_OWNED`：`launchReasonCodeText` 中文「只能关联你担任群主的社区；这个社区不存在、已被驳回，或你已不是群主。资料没有保存。」；
  `LoopBackendFailure.detailsSafe.reasonCode` → `LaunchException.reasonCode` 原有通路即可带到页面。
- 拒绝理由 `community_binding_mismatch` 已在 0144 的 `LaunchRejectionReason` 中，不改。
- **不做社区选择器 UI**（见未决项 1）；现有经典申请页与 launch2 创建流都用默认 `keep()`，行为不变。

### 4. 奖励页（§8）

- §8.1：`awaiting_first_settlement` + `lastHour / display / tracks = null` + 合计全 0 + `claim.reasonCode = MINING_NOTHING_SETTLED` 的组合，
  0140 / 0143 的 codec 与页面本来就接受（`rewards_nothing_settled` 同形）。文案按「本人」口径改：「挖矿规则已生效，你的首个有算力的小时结算后开始展示并可领取。」；
  标题「首个小时结算后开始展示奖励」与领取行「首个小时结算后可领取」不变；无增长动画。
- §8.2：`MINING_CLAIM_CONTRACT_PAUSED` 已有中文（「领取合约已暂停，暂不能领取」）。`MINING_CLAIM_CHAIN_READ_FAILED` 之前落到通用「领取暂不可用」，
  本批补明确文案：领取行「领取合约暂时读不到，暂不能领取」，prepare 失败「领取合约暂时读不到，没有生成领取凭证，余额不变。」。
- §8.3 / §8.4：字段不变，无需改。

## Fixtures / 测试

- 新目录 `test/fixtures/s149-s148-api/`（10 份，全部手写，`_handwritten` 注明来源 ba6aa45 与对应文档节；dev 未上 0125，无实抓）：
  summary 可用 / 不可用、assets（10 × 0.8 = 8）、rules（新 key + 废弃 guard）、项目带社区、列表混合、创建 422、奖励 §8.1、§8.2 两种。
- `test/s149_s148_api_contract_test.dart`：`assetPowerBasis` 有 / 缺省 / 非法值 / 旁边多未知键；规则新 key 与规则页不画 guard、资产页读 0125 回答；
  `communityId` 解析、列表混合、非法值拒绝、默认草稿不发键、bind 进创建与编辑体、clear 发 null、本地拦截非法 id 且不发请求、422 原因码与中文。
- `test/s138_mining_rewards_test.dart` 新组「S148 values」：§8.1 解析与页面、§8.2 两码的领取行与按钮禁用、prepare 文案。
- 既有用例：`s7_fixtures` 的 `expressionKey` 改新 key；`s7_mining_pages_test` 公式文案、guard 用例改为「解析但不展示」；`s59_mining_structure_test` 分区顺序去掉 guard。

## Consequences

- App 可先于或晚于 S148-api 上 dev，两种顺序 summary / assets 都能读。
- 老服务端（0125 前）若仍下发旧公式 key，规则页仍如实写「持有量 × 参考价 × 权重」，但 guard 分区已不再展示。

## 未决项（需后端 / 主代理决策）

1. 社区选择器 UI：在哪个页面（经典申请页 / launch2 创建第一步）、候选列表来自哪个接口（需要「我是群主且未被驳回的社区」列表，现有接口是否直接给出待确认）、
   编辑时如何展示「已绑定 / 清除」。本批只备好模型与请求体。
2. 422 原因码在经典申请页上目前只显示 `writeFailureKind` 的通用句（`LaunchApplyState` 未保存 `reasonCode`）；接选择器时一并把 `reasonCode` 带进写失败态。
3. `assetPowerBasis` 客户端按可选处理（与 OpenAPI required 不一致）；等 dev / staging 都上 0125 后可改为必填，届时需同步更新 s7 / s8 / 回放样本。
