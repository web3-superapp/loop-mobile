# 0155 · 挖矿领取「Coming soon」与快照定位测试去时钟（S159-mobile）

## Status

Accepted 2026-10-12。用户 2026-10-12 裁决（LOOP 代币暂不上链，奖励中心化记账），主代理下单（S159-mobile），基线
`integration/v2` 468eb01，分支 `feat/S159-claim-coming-soon`。不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、
视觉 token 不变、签名出口不动、接口契约不变（只换原因码的呈现）。

## Context

服务端不配置领取合约时，`GET /v2/mining/rewards` 的 `hourly.claim` 回 `executable: false` +
`reasonCode: MINING_CLAIM_CONTRACT_NOT_CONFIGURED`。此前页面在置灰的「领取」下写「领取合约尚未配置，暂不能领取」，读者会以为
系统坏了；实际是产品阶段如此——代币还没上链，奖励已记在服务端账上。用户追加要求：这个原因码下 App 任何位置都不得出现
「领取合约尚未配置」或类似内部状态文案。

## Decision

### 1. 一个判定，一处来源

- `MiningClaimSummary.comingSoon` = `!executable && reasonCode == MINING_CLAIM_CONTRACT_NOT_CONFIGURED`
  （常量 `miningClaimContractNotConfiguredCode`）。只有这一个原因码；`CHAIN_NOT_CONFIGURED`、`SIGNER_NOT_CONFIGURED`、
  `WRITES_DISABLED`、`MAINNET_CLOSED` 等其余原因码文案不动。
- 文案常量：按钮 `Coming soon`（用户指定英文，中文文案规范的唯一例外），说明行「LOOP 代币上线后开放领取，奖励已记在账上」。

### 2. 挖矿奖励页（`mining-rewards`）

- `MiningClaimPanel`：`comingSoon`（且非本地快照、非处理中 / 锁定、服务端无在途领取）时，按钮原位置灰（`onPressed: null`），
  label `Coming soon`，下一行 12px（`LoopType.caption`，text2）说明行，key `mining-claim-coming-soon-note`。
- 此时不再出现 `mining-claim-disabled` 原因行，也不叠加阶段提示（`mining-claim-note`）：按钮 + 一行说明即全部。
- 余额汇总、分钟展示、两条轨道、五级邀请、领取记录照常。
- 兜底：`miningClaimUnavailableText` 与 `miningClaimPrepareFailureText` 对该原因码都返回同一句说明行；失败记录的
  `failureReasonCode` 为该码时不把原始码括注出来。全仓 `lib/` 不再有「领取合约尚未配置」。

### 3. 我的挖矿页的「领取奖励」入口

- `MiningScreen` 额外读 `miningRewardsViewControllerProvider`（与挖矿奖励页同一 provider，不多一次请求；能力位阻断时不读）。
  `comingSoon` 时 Lime 主卡上的「领取奖励」按钮原位置灰、文字 `Coming soon`，行动区下一行 12px 说明（Ink 67%），key
  `mining-summary-hero-coming-soon`；「算力明细」不动。奖励资源未读到 / 其他原因码时按钮照旧打开挖矿奖励页。
- 偏离说明：此时该按钮不可点，从「我的挖矿」进入挖矿奖励页的这条路径被关闭；挖矿奖励页仍可从「我 → 资产与挖矿 → 挖矿奖励」进入。
- 「我」页的「挖矿奖励」行与挖矿资产页是导航 / 只读，没有领取按钮，不变。
- 顺带：Lime 主卡上填充态按钮的 Ink 描边画在 Ink 底上（地面探针判为不可见），改为透明描边，保留 1px 占位，外观不变。

### 4. 不稳定测试

`test/s88b_snapshot_directory_test.dart`「a slow locator inside its own bound still opens the file store」用真实磁盘 IO
跑在 20 ms 的单步上限里，主机高负载时探针写入 / 读取超过 20 ms 回落内存而失败。改为 `testWidgets`（假时钟）+
`IOOverrides.runZoned` 注入即时应答的内存文件：60 ms 的定位器在 20 ms 单步上限之外、500 ms 定位上限之内，由假时钟推进判定。
断言未放宽（仍断言 `FileLoopSnapshotStore`，并新增 59 ms 时尚未完成）；把定位步骤改用单步上限的变异会让该测试失败（已验证）。
真实磁盘读写仍由同文件其它用例覆盖。

## Verification

- `test/s138_mining_rewards_test.dart` 新组「S159 · claim Coming soon (decision 0155)」6 条：该码下按钮 disabled + `Coming soon` +
  12px 说明行、整页 `find.textContaining('尚未配置')` 为空（含滚到领取记录）；其余原因码文案与「领取」label 不变；可执行时不受影响；
  文案函数兜底；我的挖矿主卡 `Coming soon` 置灰 + 说明行，其余回答时仍可打开挖矿奖励页。原「0123 claim gate」表去掉该码、补 CHAIN / SIGNER 两码。

## Consequences

- 服务端一旦配置领取合约（`executable` 变 true 或原因码变化），两处按钮自动恢复「领取」/「领取奖励」，客户端无需改动。
- 「我的挖矿」打开时多读一次 `GET /v2/mining/rewards`（与挖矿奖励页共享 provider，进入奖励页不再重复请求）。
- `Coming soon` 是全 App 唯一的英文按钮文案，来源是用户裁决；以后的中文文案检查需把它列为例外。
- Coming soon 期间「我的挖矿」→ 挖矿奖励页的入口不可点，读者从「我」页的「挖矿奖励」行进入；是否要在主卡上另给一个查看入口待主代理决定。


## 主代理修订（2026-10-12 22:40）

「我的挖矿」主卡上的按钮只是通往「奖励与领取」的入口，不是领取本身：Coming soon 期间它改读「查看奖励」并保持可点，说明行写「领取 Coming soon · LOOP 代币上线后开放领取，奖励已记在账上」；真正置灰的领取按钮只在奖励页。否则主卡置灰会把奖励页的主入口堵死。
