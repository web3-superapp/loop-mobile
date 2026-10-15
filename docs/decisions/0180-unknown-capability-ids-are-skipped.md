# 0180 · 后端多出的能力位 id 一律忽略，不再整份判无效

## Status

Accepted 2026-10-15（S188 hotfix）。基线 `integration/v2` ce5f043。

## Context

`/v2/meta/capabilities` 的解码一直要求列表长度 ≤ 本构建已知的 id 数，多一个就抛 `invalidPayload`，整份能力投影作废，
所有按能力位 gating 的页面（广场、MEME、情报、钱包）一起显示「现在连不上 LOOP」，只有不依赖能力位的聊天还能用。
这已经发生三次：TF 6（dev 先上 launch2）、TF 9（staging 先上 testnetFaucet）、TF 20（staging 先上 `squareFeed`，2026-10-15 下午，
用户手机四个 Tab 全黑，误判为直连香港的网络问题并回滚了 DNS）。decision 0137 只放宽了「少几个」（omissible），没有放宽「多几个」。

## Decision

- `_parseCapabilities` 去掉上界：列表可以比本构建已知的 id 多。
- 每条先过 `_isUnknownCapabilityId`：是 Map、`capabilityId` 是字符串、且 `LoopV2CapabilityId.tryParse` 认不出 → 跳过，不解码其它字段。
  其它形状（非 Map、无 id、id 不是字符串）仍走严格解码并判无效。
- 已知 id 的规则不变：缺失（非 omissible）、重复、字段不合法仍是 `invalidPayload`；下界仍是 `已知 − omissible`。
- 后端发版顺序约定（docs/12）：新增能力位先于 App 发版部署即可，不必再等 App；但 App 删除能力位仍需两端同步。

## Consequences

- 未来后端加能力位不会再让旧包整页不可用；旧包只是看不到新功能。
- 「client capability enum equals the frozen contract enum」测试保留：它保证新构建跟上合同，不保证旧包拒绝新合同。
- 新增测试：36 条（含一条未知 id）解码出 35 条已知能力；原「未知 id」测试仍成立（替换掉的那条已知 id 变成缺失）。

## Verification

- `bin/flutter test test/loop_v2_meta_repository_test.dart test/s7_api_contract_test.dart test/s156_testnet_faucet_test.dart test/s187_4_square_feed_test.dart`：183 过。
- `bin/flutter analyze` 0；`python3 scripts/check_harness.py` 与 `tests/` 通过。
- 真机：TF 22 装上后，对 35 位的 staging 正常；TF 21（已含 35 位）同样正常，TF 19/20 对该后端不可用。
