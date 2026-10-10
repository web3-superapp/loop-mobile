# 0137 · App 认识 `launch2` 能力位（33 位），旧后端的 32 位列表照常可读（S134）

## Status

Accepted 2026-10-10。主代理下单（S134-mobile），基线 `integration/v2` 4b0bb0e，分支
`feat/S134-launch2-capability`。配套 loop-api 决策 0114（`feat/S134-launch2-read-model`，已合入 loop-api
`integration/v2` 8c4e038）。不新增依赖，路由清单不变，视觉 token 不变，没有新页面。

## Context

loop-api 0114 在 `GET /v2/meta/capabilities` 末尾（`meme` 之后）加了第 33 位 `launch2`（MEME v2：NFT 发售 →
持有人提前购 → 公开内盘）。`DioLoopV2MetaRepository` 要求列表与 `LoopV2CapabilityId` 全集一一对应，
未知 id 即 `invalidPayload`：后端一部署，所有旧包的 meta 解码失败、整个 App 连不上。反过来，新包也不能要求 33 位——
dev 部署 S134 之前、Staging、TestFlight build 1 面对的都是 32 位后端。

## Decision

1. **枚举加 `launch2('launch2')`，排在 `meme` 之后。** 顺序以 loop-api `src/features/meta/product-policy.ts`
   的 `v2CapabilityIds` 与 `openapi/loop-api.v2.json` 的 `capabilityId.enum` 为准（33 位，最后三位
   `communityAi, meme, launch2`）。`test/loop_v2_meta_repository_test.dart` 的合同对照测试读同一个 enum。
2. **`launch2` 可缺省，其余 32 位仍严格。** `DioLoopV2MetaRepository.omissibleCapabilities = {launch2}`：
   - 列表长度只能是 33，或 32（缺的必须是可缺省的那位）；缺任何其他 id、重复、未知 id 仍是 `invalidPayload`。
   - 缺省的 `launch2` 由客户端补一行 `availability: deferred`、`reasonCode: LAUNCH2_CAPABILITY_ABSENT`
     （客户端自有码，后端从不发，便于日志区分；后端「模块未开」发的是 `LAUNCH2_MODULE_NOT_ENABLED`）、
     `evidence: {status: notApplicable, reasonCode: null}`——与后端 `deferredCapability()` 同形。补的行追加在末尾，
     结果仍是按合同顺序的 33 行，`capabilities[LoopV2CapabilityId.launch2]` 永远可取。
   - 何时收紧：所有在用后端（Development、Staging、TestFlight 指向的后端）都部署 0114 之后，可以把
     `omissibleCapabilities` 清空恢复全严格；收紧前须确认没有仍在用的 32 位后端。
3. **evidence 可选键不放开。** `launch2` 不带 `launchChainId` / `reference` / `launchContractVersion`
   （0114：模块关时 `notApplicable`，开着时 `pending` + 原因，`LAUNCH2_TESTNET_EVIDENCE_PENDING` 或缺依赖的原因码），
   现有规则已把这三键限定在 `launch` / `voiceRooms`，出现在 `launch2` 上即 `invalidPayload`；`confirmed` 在 `launch2`
   上同样被拒（它既不在「带原因确认」名单，也不是 `voiceRooms`）。
4. **功能开关 `LoopFeatureSwitches.launch2Visible = false`。** 本批没有 MEME v2 页面，只认识能力位、不画任何入口；
   页面落地时改 true，并以 `launch2 == available` 决定是否显示入口（合同 §1）。
5. **harness**：`S5_CAPABILITY_IDS` 改 33 位（末位 `launch2`），`tests/test_check_harness.py` 的变异用例改为
   「多出第 34 位」「删掉 `launch2`」等，均须报「33 ids」。

## 与下单描述的偏离

- 下单写 preflight 样例里 `launch2` 为 `deferred` + `evidence: {status: pending, reasonCode:
  LAUNCH2_TESTNET_EVIDENCE_PENDING}`。loop-api 实现（`launch2Capability()`）模块关时走 `deferredCapability()`，
  evidence 是 `{status: notApplicable, reasonCode: null}`；`pending` 只在模块开着时出现。样例按实现写。
- preflight 样例目录 `docs/integration/preflight-2026-09-16/` 在 LOOP 工作区根（不在 loop-mobile 仓库里），
  手工补的条目不随本分支提交；目录 README 记录了来源与待重抓。

## Consequences

- 33 位后端、32 位后端都能读；旧包面对 33 位后端仍会失败——这是旧包的既有行为，只能靠新包覆盖。
- 主仓 loop-mobile 的合同对照测试（`../loop-api/openapi`，loop-api 已是 33 位）在合入本分支前会失败，合入后通过。
