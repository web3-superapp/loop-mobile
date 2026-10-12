# 0152 · 大额交易二次验证（设备验证，纯客户端，S154-mobile）

## Status

Accepted 2026-10-12。用户 2026-10-12 裁决「大额交易二次验证」从「即将推出」占位改为真功能；主代理下单 S154-mobile，
基线 `integration/v2` be97915，分支 `feat/S154-large-amount-stepup`。
纯客户端：不改任何后端请求、请求头、响应解析与契约；不新增依赖、`pubspec.lock` 不变；路由 slug / path / 条数不变；
视觉 token 不变。调整决策 0121（`security-setup` 的「交易验证」卡）。

## Context

`security-setup`（开户第四步）的「大额交易二次验证」一行自 0121 起是不可点的「超过阈值时再验一次身份 · 即将推出」。
App 已有一套设备验证（应用锁：`LoopDeviceAuthenticator`，生物识别、系统锁屏密码兜底，LOOP 不持有 PIN）。
所有资金动作都经 `walletSigningGatewayProvider` 这一个出口进入 Privy 钱包（`PrivyWalletSigningGateway.handoff`）。
需求：签名前，当这笔操作的 USD1 等值金额达到阈值，先用同一套设备验证；取消或失败则不签名。

## Decision

### 1. 规则与出口

- 新 `LoopStepUpWalletSigningGateway`（`lib/features/security/step_up/step_up_controller.dart`）包在
  `walletSigningGatewayProvider` 外面，作为新的 `loopGuardedWalletSigningGatewayProvider`。五个功能签名器
  （MEME 曲线、MEME v2 曲线 / 官方池 / NFT、Launch 认购 / 领取 / 退款、钱包发送 / 兑换 / 授权 / 回收、挖矿领取）
  的 provider 全部改为读它；`check_harness.py` 新 `check_step_up_store_contract` 锁住这五处不得再读裸出口。
- `SigningIntent.backendCanonical` 新可选字段 `stepUpUsd1`（`Decimal?`）：各功能在构造签名意图时写入本笔的
  USD1 等值。它不进 payload、不进确认事实、不上屏；`null` = 不知道，不是 0。
- 出口顺序：意图本身会被拒（过期 / 链不允许 / 非 canonical）→ 直接交给内层出口拒绝，不弹设备验证；
  否则 `guard.verify(stepUpUsd1)`：
  - 规则关闭、设备没有任何验证能力、金额未知、金额 < 阈值 → 不问，照旧开钱包；
  - 金额 ≥ 阈值（**等于即触发**）→ 系统验证（文案「验证身份以签名这笔大额交易」）；通过才开钱包；
  - 取消 → `WalletHandoffResult.rejected('step_up_cancelled')`；失败 / 锁定 / 平台错误 →
    `'step_up_failed'`。钱包从未打开，各签名器照旧归为 `walletRejected`（「没有提交任何交易」，可重试，不锁定）。
- 新失败种类 `LoopChainFailureKind.stepUpCancelled`，文案「已取消，没有发生任何变化。」；
  `loopStepUpFailureKind(code)` 把两个码都映射到它。签名面板文案：取消「已取消，没有发生任何变化。」、
  失败「身份验证没有通过，没有发生任何变化。」（`loopStepUpReasonText`，五个签名器的原因表都加了这两个码）。
- 阈值比较用 `Decimal`（精确有理数）：`usd1 >= Decimal.fromInt(thresholdUsd1)`；原子单位用
  `Decimal.fromBigInt(atomic).shift(-18)`。全程无 double。
- 一次操作只问一次：验证通过后在 2 分钟内、金额不超过已验证金额的后续 handoff 直接放行（覆盖「先授权再买」两次钱包、
  0148 授权后重报价的第二笔）；签名面板关闭（`dispose`）即释放；金额更大则重新验证。

### 2. 金额来源（哪些出口能算 USD1）

| 出口 | 意图 | USD1 等值 |
| --- | --- | --- |
| MEME 曲线 `MemeIntentSigner` | 买 / 创建首买 | `usd1Amount`（18 位）；创建无首买 = `null` |
| | 卖 | `expectedOut`（USD1，18 位） |
| MEME v2 `Launch2IntentSigner` | 曲线买 / 官方池买 / NFT | `amountIn`（最多支付，含税） |
| | 曲线卖 / 官方池卖 | `expectedOut` |
| Launch `LaunchPurchaseSigner` | 认购 | `usd1Amount` |
| | 退款 `claimRefund` | `refundableUsd1` |
| | 领取 `claim` | `null`（项目代币，无 USD1 价） |
| 钱包 `MoneyActionSigner` | USD1 发送 / 付 USD1 的兑换 | `review.amount.value` |
| | 收 USD1 的兑换 | `swap.quote.estimatedOutputAmount.value` |
| | 其他代币发送 / 兑换 / 授权 | `policy.valueUsd`（服务端 prepare 时的行情价 × 数量；授权为 `min(allowance, balance)` 的价值）；USD 按 1:1 视作 USD1 |
| | 回收授权 | `null`（不转移价值） |
| 挖矿 `MiningClaimSigner` | 领取 | `null`（LOOP 代币，App 内无价格来源） |
| 发射创建 EIP-712（`PrivyLaunch2TypedDataSigner`） | 签配置 | 不经过本出口：签名不动用户资金（执行器部署），无 USD1 金额 |

**缺口（按需求写明）**：行情不可得（`policy.valueUsd` 为 `null`）或意图本身无金额（Launch 领取、挖矿领取、无首买的
创建、回收授权、发射配置签名）时视为未达阈值，不触发二次验证。挖矿领取需求里点名了，但 LOOP 代币在 App 内没有任何
价格来源，算不出 USD1，本批不触发。

### 3. 设置

- 存本地、按账号分区：`SecureStorageLoopStepUpSettingsStore`（`lib/integrations/device/`），键
  `loop.step_up.v1.<LoopV2OwnerPartition.fromPrincipal(principal)>`（与会话日志、开户进度同一分区值，原始 principal
  不落盘），值 `1:1000` / `0:1000`；读到其他值视为未存（= 默认）。放平台安全存储而不是 SharedPreferences：关掉它正是
  拿到解锁手机的人想悄悄做的事。这是安全存储的第三个 owner，`check_harness.py` 的 `SECURE_STORAGE_OWNERS` 同步登记，
  并由 `check_step_up_store_contract` 锁定键前缀与编码。
- 默认开启、阈值 1000 USD1；阈值为整数 USD1，1–1,000,000（输入只收数字，越界「金额需在 1 到 1,000,000 USD1 之间」，
  空「请输入整数金额」）。
- 开、关都先做同一套设备验证（「验证身份以开启 / 关闭大额交易二次验证」）；**提高**阈值在规则开启时先验证
  （「验证身份以提高大额交易的验证金额」），降低直接保存。设备没有任何验证能力时规则不生效、开关不可开。
- 无账号（无 principal）时只在本次运行有效，副标题加「这次有效，重开 App 后不会记得」。

### 4. 页面

- `security-setup` 「交易验证」卡第一行改为 `LoopStepUpSettingRow`：标题「大额交易二次验证」、副标题
  「达到 N USD1 时再验一次身份」（N 千分位，主代理 2026-10-12 裁决：与「等于即触发」一致）、右侧开关；点行打开阈值抽屉（数字输入、预设 500 / 1,000 / 5,000、保存）。
  设备不可验证时：无开关、「不可用」、副标题追加应用锁同款原因（`loopAppLockFactorText`）。删除
  `securityLargeAmountSubtitle` 与「即将推出」语义标签。卡片 `_SecurityCard` 接受非 `LoopRecordRow` 子项，
  `_SecurityRow` 绘出 `trailingBadge`（开关）。没有 ProviderScope 的树（部分页面测试）显示同一行、无开关、
  「这次运行没有可用的设备验证」。
- 「我 → 安全中心」在「验证 / 恢复」与「设备」之间加「交易验证」分组，同一行。安全中心整页因 capability 被拦截时
  （`security-capability-block`）这一组也不显示（整页 block 的既有行为）。
- 签名面板：`withStepUpStrip` / `Launch2SignStepStrip(verify:)` 在触发时显示「1 验证身份 → 2 签名」（有授权时
  「1 验证身份 → 2 授权 → 3 买入」），复用两步条样式（抽成共享 `LoopSignStepStrip`，`lib/widgets/loop_sign_steps.dart`；
  `Launch2StepStatus` 改为 `LoopSignStepStatus` 的 typedef，原有 key 不变）。验证中忙碌态写「正在验证身份」。
  取消 / 失败后面板回到待确认，原因行为中文，「确认签名」可再点；`latch.enteredSigning` 在验证通过后才置位，
  所以取消后关闭面板对调用方是「未开钱包」（`null`），不是锁定。四个面板接入：MEME、MEME v2、Launch、钱包发送 / 兑换 / 授权。
  挖矿领取面板金额恒为 `null`，不接条。

## Fixtures / 测试

- 新 `test/s154_large_amount_step_up_test.dart`（31 条）：阈值等于触发 / 低于不触发 / 无金额不触发、编码与越界、
  输入解析；MEME 买卖、MEME v2 买、钱包 WBNB 发送按服务端估值、USD1 发送按数量、估值缺失为 `null`；出口：低于阈值不问、
  等于阈值先验证后开钱包（事件顺序）、取消 / 失败不开钱包且返回新失败种类与中文、一次验证覆盖同一操作且金额更大或释放后重问、
  会被拒的意图不问、规则关闭 / 设备无锁屏不问、经 `launch2IntentSignerProvider` 端到端；设置按账号分区与持久化、
  开关两向验证、提高阈值验证 / 降低不验证 / 越界拒绝、无能力不可开、安全存储键分区且不含原始 principal；设置行开关、
  阈值抽屉（越界报错、预设 5000、保存后副标题更新）、无能力无开关；签名面板显示验证步、通过后签名、取消后不开钱包可重试、带授权时三步条、
  低于阈值无步骤条。
- 更新：`test/security_capability_truthfulness_test.dart`、`identity_pages_test.dart`、`s53_onboarding_sequence_test.dart`
  （「不可用」2 → 3，「即将推出」→ 新副标题）、`mfa_test.dart`、`s121a_copy_search_security_test.dart`（新副标题）、
  `s59_profile_structure_test.dart`（安全中心分组多「交易验证」）。

## Consequences

- 没有任何网络请求、请求头或解析变化；服务端不知道这一步是否发生。
- 生物识别 / 锁屏密码的真机行为、系统弹窗文案只能真机验证（记 unverified）。
- 测试树默认 `UnavailableLoopDeviceAuthenticator`，规则不生效，既有签名测试行为不变。

## 主代理裁决（2026-10-12）与待办

1. 挖矿领取与 Launch 领取暂不触发：**待办**——后端在意图里给出 USD 估值（如 `valueUsd`）后，接入 `stepUpUsd1`。
2. 钱包非 USD1 资产用服务端 `policy.valueUsd`（USD）按 1:1 当作 USD1：接受。
3. 存储保持平台安全存储（第三个 secure storage owner，本决策登记）。
4. 副标题改为「达到 N USD1 时再验一次身份」，与「等于即触发」一致；阈值抽屉保持「达到或超过」。
