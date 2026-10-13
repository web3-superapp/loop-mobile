# 0158 · 2026-10-13 审查九条修复（S169-mobile）

## Status

Accepted 2026-10-13。主代理下单（S169-mobile），基线 `integration/v2` 95030ef，分支 `fix/S169-review-findings`。
修正决策 0152（大额二次验证）、0154（测试网领取）、0156（安全中心）在审查中发现的问题。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变；无新网络请求或请求头。

## Context

2026-10-13 审查在 0152 / 0154 / 0156 的实现里找出 9 条：兑换收 USD1 时按到手估算计价会漏掉「高价值资产换少量 USD1」，
且 USD1 按符号判定；安全中心把服务端「可用」写成「已启用」；领取测试币进行中就释放了幂等键；轮询读回把「发出」写成「到账」；
AGENTS 第 22 条没点名 0152 的开关与安全存储；设备能力读不到时大额签名被放行；授权已发出后取消仍说「没有发生任何变化」；
开户进入页在 `settleMutes` 抛错时不离开；冷却时长写死 24 小时、外部钱包也有领取入口、客服恢复问答与安全中心矛盾。

## Decision

### F1 · 兑换收 USD1 的二次验证金额（调整 0152 §2）

- USD1 只按 CAIP `assetId` 判定：新 `lib/core/chain/loop_usd1_asset.dart`，`loopPrimaryUsd1AssetId` =
  `eip155:56:0x8d0d000ee44948fc98c9b98a4fa4921476f08b0d`（WLFI USD1，LOOP docs/24 §7.4 已确认；写法同 loop-api
  `assetIdForAddress`：链 id + 冒号 + 小写地址），`loopIsUsd1AssetId` 忽略大小写比较。钱包发送 / 兑换 / 授权只在主链
  （0062），所以这是钱包意图唯一可能出现的 USD1。只叫 `USD1` 的其他代币按普通代币取 `policy.valueUsd`。
- 收 USD1 的兑换：`stepUpUsd1` = `max(policy.valueUsd, quote.estimatedOutputAmount)`，任一缺失取另一个，都缺为 `null`。
  高价值资产换少量 USD1 时按付出侧价值触发。付 USD1 的兑换、USD1 发送仍取数量。

### F2 · 自动恢复不写「已启用」（调整 0156 §2）

- `autoRecovery` available 时徽标改中性「默认方式」（灰色 mute 徽标），副标题仍是来源句。与 0156 Consequences
  「available 只表示客户端流程可用，已开启只来自 Privy 在设备上的回答」一致：设备上没有任何来源能读回自动恢复的状态。

### F3 · 领取进行中保留 Idempotency-Key（调整 0154 §2）

- `claim` 结果为 `TestnetFaucetPending`（409 `TESTNET_FAUCET_IN_FLIGHT` / 503 `REQUEST_TIMEOUT`）时不释放 key，
  再次领取用同一个 key，服务端回放这一笔的结果；拿到确定结果（201 / 冷却 / 部分到账 / 拒绝）才释放。
- 服务端对同 key 永久回放已存结果，所以 `loadStatus` 读到 `available: false`（发放已记账、进入冷却）时也释放该钱包的 key，
  冷却过后的下一次领取用新 key，不会回放一天前的结果。

### F4 · 轮询读回缺 tUSD1 哈希

- `TestnetFaucetPartial` 加 `readBack`；轮询从状态读回的发放记录有 tBNB 哈希、无 tUSD1 哈希时文案为
  「tBNB 已发出，tUSD1 这次没发；<冷却>后可再领」，不再写「已到账」（记录只证明发出）。

### F5 · AGENTS 第 22 条

- 写明 0152 的大额二次验证开关 / 阈值有设置回调，规则只在设备上由 `LoopStepUpWalletSigningGateway` 执行；
  安全存储 owner 以 `check_harness.py` 的 `SECURE_STORAGE_OWNERS` 为准，0152 新增
  `SecureStorageLoopStepUpSettingsStore`，只写 `loop.step_up.v1.<owner partition>`。

### F6 · 设备能力读不到时不放行（调整 0152 §1）

- 规则开启、设备能力读成 `unknown`（读取异常或平台答「不知道」）且金额达到阈值时：`plan.required = true`，
  `verify` 直接返回 `failed`（`step_up_failed`，「身份验证没有通过，没有发生任何变化。」），钱包不打开、可重试。
  能力明确为「没有锁屏 / 平台不支持」时仍按 0152 不生效；规则关闭时不问。

### F7 · 授权已发出后的取消 / 失败文案

- `launch2SignReasonText` / `memeSignReasonText` 加 `approvalSent`；同一操作的授权已广播（`approvalTxHash` 非空）
  后二次验证取消或失败时文案为「授权已发出，交易未发起。」（共享常量 `loopStepUpAfterApprovalText`）。
  MEME 签名面板、MEME 提交状态行、MEME v2 签名面板接入。

### F8 · 开户进入页一定离开

- `_enter` 里等待 `settleMutes` 与最短停留的 `Future.wait` 外包 `try / on Object / finally`，finally 里
  `if (mounted) _leave()`；`settleMutes` 抛错也离开一次。`OnboardingCommunitiesController` 由 `final class` 改为
  `base class`，供测试替换一个抛错的控制器。

### F9 · 冷却时长、外部钱包入口、客服文案

- 冷却时长读服务端 `cooldownSeconds`：`testnetFaucetCooldownText`（86400 =「24 小时」，整天「N 天」，整小时「N 小时」，
  整分钟「N 分钟」，否则「N 秒」）；抽屉说明、冷却行、按钮、部分到账、429 文案都用它；状态未读到时不写时长
  （「稍后可再领」/「最近已经领过」/「可以定期领」）。钱包 Tab 入口不读状态，副标题去掉「每 24 小时一次」，为
  「测试网专用 · 领 tBNB 与 tUSD1」。
- 钱包 Tab 只在当前钱包 `kind == embedded` 时显示领取入口（服务端只给本人内置钱包发放）。
- 客服「换手机怎么恢复账户」改为与安全中心一致：「账号身份由 Privy 保管。Passkey 与多因素验证可以在安全中心开启，
  自动恢复是默认的恢复方式；社交恢复与导出私钥还没有开放。安全中心会显示每一项的当前状态。」

## Consequences

- 二次验证在高价值换 USD1 与设备能力未知时都不再放行；只叫 USD1 的代币不再按其数量计价。
- 测试网领取的重试不会产生第二笔发放，冷却之后的领取也不会回放旧结果。
- 安全中心、客服问答与开户进入页不再陈述设备读不到的事实。
- 无请求、请求头、解析、路由或依赖变化。

## 偏离

- F1：代码里原本没有 USD1 `assetId` 常量或配置，本批新增客户端常量（仅主链 USD1）；测试网 tUSD1 不进入钱包意图，不列入。
- F7：`lib/features/launch2/launch2_instance_screen.dart` 的项目页待处理行（「授权已广播，$noun没有签名。可以重新发起。」）
  属于 launch2 UI 文件，按任务单不在本批改动范围，仍为原句。
- F8：为测试把控制器从 `final` 改为 `base`。
- F8：`settleMutes` 抛错时 `Future.wait` 立即结束，不再等满最短停留就离开。

## Fixtures / 测试

- `test/s154_large_amount_step_up_test.dart`：USD1 发送改用 `loopPrimaryUsd1AssetId`；只叫 USD1 的代币按估值；收 USD1 的兑换
  取较大者（5000 vs 3.74、1 vs 3.74）；假 USD1 目标按估值；高价值换少量 USD1 经出口触发验证；能力 `unknown` 时达阈值
  失败且钱包不开、低于阈值放行；能力读取抛错 `failed` 且 `plan.required`；规则关闭不问。
- `test/s156_testnet_faucet_test.dart`：409 → 503 → 201 三次请求同一 key、结果确定后释放、下一次新 key；状态读到冷却释放
  key、仍可领不释放；读回缺 tUSD1 文案；冷却时长单测与 1 小时冷却的抽屉文案；外部钱包无入口；部分到账无冷却时「稍后可再领」。
- `test/s160_security_current_projection_test.dart`：自动恢复徽标「默认方式」、页面无「已启用」。
- `test/s109a_onboarding_communities_test.dart`：`settleMutes` 抛错仍离开一次。
- `test/s8_settings_about_support_test.dart`：客服恢复问答新文案。
- `test/s169_review_findings_test.dart`（新）：F7 两组文案。
