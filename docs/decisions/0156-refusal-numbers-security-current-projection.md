# 0156 · 拒绝响应带数字与安全中心真实状态（S160-mobile）

## Status

Accepted 2026-10-13。主代理下单（S160-mobile），基线 `integration/v2` bc165dd，分支
`feat/S160-refusal-numbers-security-current`。对接 loop-api 决策 0129 §1 / §4（loop-api `integration/v2` = bb096ba，
staging 同）。不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变、签名出口不动。

## Context

- loop-api 0129 §1：三个 launch2 prepare 的 `409 INSUFFICIENT_BALANCE` 在 `detailsSafe` 里追加可选键
  `balanceUsd1`（USD1 不足）、`balanceMeme`（MEME 不足）、`requiredBnb` / `balanceBnb`（`LAUNCH2_GAS_INSUFFICIENT`），
  均为整单位十进制字符串。S155（决策 0153）只读旧键。
- loop-api 0129 §4：`GET /v2/security/capabilities?projection=current` 让 `mfa`、`passkey`（API 发布了 RP 关联文件时）、
  `autoRecovery` 报 `available`（`reasonCode: null` + `evidence {status: confirmed, reasonCode, reference}`）；
  不带 query 时仍是决策 0037 的全 `unavailable` 文档。旧 codec 只认 `unavailable` + `pending`，遇到 `available` 整段失败。

## Decision

### 1. 拒绝数字（`Launch2ActionFailureLine`）

- `LoopFailureDetails` 加 `balanceUsd1` / `balanceMeme` / `requiredBnb` / `balanceBnb` 四个可选键，与既有键同一十进制
  白名单；坏值只丢该键，不影响 `reasonCode` 与其余键。`LoopChainException` / `loopChainExceptionForV2` 透传。
- `launch2ActionFailure`：
  - USD1 不足：「USD1 余额不足：需要 X USD1，当前 Y USD1」，Y 先取 `balanceUsd1`，没有再回退 0153 的逻辑
    （官方池 `maxAmountIn` / 页面已读余额 / 曲线「最多可付」）。
  - MEME 不足：「卖出数量超过持有：需要 X，当前持有 Y」，Y 先取 `balanceMeme`，没有再回退（官方池 `maxAmountIn`
    视作持有，曲线写「最多可卖」）。
  - tBNB 不足：「tBNB 手续费不足：这笔约需 X tBNB，钱包有 Y tBNB，充值后再试」（最多 8 位小数）；只到一个数字时只写那一句；
    两个都没有保留原句 `launch2GasShortText`。「去充值」/「领取测试币」条件不变。
- 创建流程（`launch2_sign_screen` / `launch2_create_screen`）的 `launch2FailureText` 不在本批范围，不变。

### 2. 安全中心读 `projection=current`

- 唯一读取点 `DioLoopV2SecurityApi.getCapabilities` 带 `?projection=current`。
- codec：每项仍是固定五键、固定六项、固定顺序。
  - `status: unavailable`：`reasonCode` 必填、`evidence` 恰为 `{status: pending, reasonCode}`（旧形状，默认投影照收）。
  - `status: available`：只允许 `mfa` / `passkey` / `autoRecovery`；`reasonCode` 必须显式 `null`；`evidence` 恰为
    `{status: confirmed, reasonCode, reference}`，`reference` 1–120 字符、无控制字符。
  - 其余（未知 status、available 带 reason、available + pending、缺 / 空 / 超长 reference、多键、unavailable 带
    confirmed 或 reference、`recoveryPassword` / `socialRecovery` / `keyExport` 报 available）整段判无效。
- 模型 `LoopSecurityCapability` 加 `.available` 构造、`evidenceReference`、`isAvailable`；`reasonCode` 改可空（只在
  available 时为 null）。
- 渲染（`security`）：
  - `mfa` / `passkey` available：去掉「还没有开放」；状态读客户端的 `loopMfaProvider`（Privy 返回的
    `enrollments` / `passkeys`，与 MFA / Passkey 抽屉同源）。服务端说 available 后才去问 Privy；读取中「读取中」，
    读不到「读不到」+ 原因、点按重试（不说未开启）；MFA 有方法 = 「已开启」（副标题列方法），Passkey 有凭据 =
    「已开启」（副标题列名字）；否则「未开启」，点按打开 `showLoopMfaSheet` / `showLoopPasskeySheet`。本构建没有
    Passkey 域名凭据时 Passkey 行「不可用」+ 原因、不可点。
  - `autoRecovery` available：「已启用」+ 来源句。来源句取 `evidence.reference` 去掉开头的工程标签（如「S60a: 」），
    去完为空时用 S60a 那句 `walletAutomaticRecoveryEvidence`。
  - `socialRecovery` / `keyExport` 仍「还没有开放」，入口不变。`recoveryPassword` 仍按 0151 隐藏。
  - 原因码 `PASSKEY_RELYING_PARTY_NOT_CONFIGURED`（服务端未发布 RP 时的 passkey）归入「还没有开放」。
  - 「这些保护怎么开启」只列仍未开放的项；全部开放时不渲染。底部说明在有 available 项时改为
    「这些保护由 Privy 提供。<未开放项>开放后会在这里显示。」；全 unavailable 时原句不变。
- 开户第三步（`wallet-recovery`）、第四步（`security-setup`）不读这个投影（它们读 `PrivyWalletCapabilities` 与
  `loopMfaProvider`），本批不变。

## Consequences

- 安装了本批之前版本的 App 仍走默认投影，不受影响；本批起 App 发 `projection=current`。
- 「available」只表示客户端流程可用，「已开启」只来自 Privy 在设备上的回答，两者不互相推导。
- 测试：`test/s160_launch2_refusal_numbers_test.dart`（键读取 / 坏值 / 三种数字文案 / 缺键回退）、
  `test/s160_security_current_projection_test.dart`（两种投影正例、坏形状、query、三项 available 渲染、未开放两项、
  旧投影渲染、Privy 读不到 / 无域名、抽屉入口）、`test/s146_launch2_pool_trade_test.dart` 官方池 tBNB 带数字一步。
