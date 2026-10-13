# 0160 · 创建者 hooks-config 接受 LoopDynamic 模板键（S172-mobile）

## Status

Accepted 2026-10-14。主代理直接修，基线 `integration/v2` 2bab1cb。依据：loop-api 决策 0131 / 0132 与 `openapi/loop-api.v2.json`
（loop-api 231c176）里 `GET /v2/launch/projects/{id}/hooks-config` 的 `draft.config` 与 `draft.config.fixedEconomics`。
不新增依赖、`pubspec.lock` 不变、路由与视觉不变、无新请求。

## Context

loop-api S170 让 Hooks 发起链路支持 LoopDynamic 工厂。LoopDynamic 项目的草稿多了三处键：`config.poolHookKind = "loopDynamic"`、
`fixedEconomics.officialPoolHookKind`、`fixedEconomics.loopDynamic`（router / buyFeePpm / baseSellFeePpm / baseFeeRecipient /
priceTiming / routingPolicy / routerRegistryAdmin / excludeBuybackFromRewards）。OfficialTax 草稿一个都没有。
App 的创建者编解码对 `config` 与 `fixedEconomics` 都是严格键集，遇到任一新键整份判无效，LoopDynamic 项目的创建者页面会打不开。
测试网首个 LoopDynamic 实例（2026-10-14）走查时同一处在后端先以 500 暴露（响应 schema 同样没收这些键），后端已修。

## Decision

1. `config` 允许可选键 `poolHookKind`，值只能是 `loopDynamic`；读进 `Launch2HooksDraft.poolHookKind`（OfficialTax 为 null）。
2. `fixedEconomics` 允许可选键 `officialPoolHookKind`（`officialTax` / `loopDynamic`）与 `loopDynamic`；两者必须同时出现或同时缺席
   （`officialPoolHookKind == loopDynamic` ⇔ 有 `loopDynamic` 对象），否则判无效。`loopDynamic` 对象本身是严格八键，
   `priceTiming` 只认 `PRE_SWAP` / `POST_SWAP`，`routingPolicy` 只认 `LoopRouterOnly` / `Open`，地址按小写 40 位十六进制，
   ppm 上限 1 000 000。读进新模型 `Launch2LoopDynamicEconomics`。
3. 页面暂不消费这些字段：创建者流程的展示与 PUT 体不变（PUT 仍只送七个 owner 字段）。后续若要在创建者页展示「外盘 Hook 种类」，
   以此模型为数据源。

## Consequences

- 新 fixture `hooks_config_draft_loop_dynamic.json`（手写，来源 0131/0132 与测试网 manifest factory-20261013T134534Z），
  三条测试：LoopDynamic 草稿读出全部字段、OfficialTax 草稿两键皆空、种类与参数块不一致或未知种类被拒。
- 对老后端（无这些键）行为不变。
