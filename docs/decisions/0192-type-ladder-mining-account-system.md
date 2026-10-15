# 0192 · 挖矿 / 账户 / 安全 / 系统 / 发射创建页落档（S197-4-mobile）

## Status

Accepted 2026-10-16。基线 `integration/v2` 6678e8b（S197-3 / 0191 合入后）。来源：主仓库 `docs/37-全App字体一致性走查-2026-10-15.md` §1、§2、§4 批 4；阶梯与守卫见 0189。
范围：`lib/features/{mining,mining_rewards,account,security,shell,system,launch}/**`、`lib/features/launch2/creator/**`、`lib/features/wallet/approval_screens.dart`（只动 M11 两个弹层标题与该文件的别名）。
旧发射 `lib/features/launch/**` 仍挂在 `lib/app.dart` 路由（`LaunchDetailScreen` / `LaunchTradeScreen` / `LaunchApplyScreen` 等），所以按本批一起落档，不是只缩白名单。
不新增依赖、路由、字体、资产；`pubspec.lock` 不变；`lib/widgets/**` 与 `test/type_roles_test.dart` 未动。

## Context

0189 定稿阶梯并把 features 的离档调用按文件登记进 G1 / G2 白名单，第 2–4 批逐页落档。本批覆盖的 23 个文件占 0189 基线 144 处数字 builder、8 处弃用别名与 8 处低于 11px 的字号：
挖矿主卡与统计格用 9 / 10px 的 eyebrow / caption，挖矿奖励页同页说明 11 / 13 / 14 三档，Referral 弹层标题 18/700，居中状态页标题 15 / 16 / 22 混用，金额输入与验证码格 16 / 26，旧发射页金额 24/700。

## Decision

### 1. 逐条（docs/37 ID → 文件 → 前 → 后）

| ID | 文件 | 前 | 后 |
|---|---|---|---|
| M32 | `mining_rewards/mining_rewards_screen.dart`（领取说明、不可领原因、「有算力的小时结算后显示」、空资产、加权说明、邀请说明） | `bodySm` 13 text2 / `captionSm` 11 | R20 `caption` 12 text3（网费提示留 `body` 14 text2） |
| — | 同文件「领取状态」卡内首行 | `caption(11)` text2 | R3c `eyebrow` 12 |
| — | 同文件五级邀请表 | 表头 `LoopMono.label`、数 `figure(11)` 500 / 700 | 表头 R13 `kicker`；数 R29 `figureXs`@500，合计行 `figureXs`@600 chalk |
| M33 | `mining/mining_widgets.dart` 主卡「MINING POWER」「RANK」 | `eyebrow(9)` | R8 `kicker` 11；名次数 `figureXs`@600 |
| M34 | 同上 主卡三格 | 值 `figure(11,700)`、标签 `caption(10,700)` | 值 R12 `figure` 13/600、标签 R13 `kicker` 11 |
| — | 同上 主卡大数字 | `display(44)`（字为 29）字距 −2、行高 0.98；单位 `figure(16,700)` | 数字 R22 `figureXl` 28、文字 R9 `displayXl` 28，字距 0；单位 R23 `figureMd` 17 |
| M37 | 同上 `MiningMetricRow` | 标签 `figure(11)`、值 `figure(20)` h1.15 | 标签 R13 `kicker`、值（主数字）`figureLg` 20 |
| — | 同上 `MiningDetailRow` | `figure(valueSize=20, 700)`；成对值 `figure(12,700)` | `valueStyle ?? figureLg`（参数由 `double valueSize` 改为 `TextStyle? valueStyle`，无外部调用方传过）；成对值 R6 `figure` |
| M35 | `mining/mining_secondary_screens.dart` | 社区说明 `caption(10)`、格标签 `caption(9)`、评定说明 `caption(9)`；格值 `figure(16,700)` | `captionSm` 11 / R13 `kicker` / `captionSm`；格值 R23 `figureMd` 17 |
| L4 | 同上 规则页状态行 | `labelMedium` 12/500 | R21 `captionSm` |
| — | 同上 `DAILY OUTPUT` | `LoopMono.label` | `eyebrow`（同像素） |
| M36 | `mining/referral_screen.dart` 等级格 | `eyebrow(9)` + `figure(15,700)` | R13 `kicker` + R12 `figure` 13（`LoopStatGrid` 的同两档，格子留本地，见保留项） |
| M7 | 同上 两个弹层标题 | `heading(18,700)` | `LoopSheetHeading`（R2 20/600）；弹层外边距改为 0、正文另包 16 横向内边距，与其它 `LoopSheetHeading` 弹层同构 |
| M17 / L1 | 同上 两段弹层说明 | `body(13)` muted、`caption(12)` muted | R19 `bodySm` text2 |
| M38 | `mining/mining_screen.dart`「邀请关系加成」 | `display(21)` | `headingSm` 17；`REFERRAL POWER` `LoopMono.label` → `eyebrow` |
| M42 | `security/step_up/step_up_widgets.dart` 金额输入 | `figure(16)` | R24 `figureLg` 20 |
| M18 | 同上 弹层说明 | `body(14)` text2 | R19 `bodySm` |
| — | `security/app_lock/app_lock_prompt.dart` 弹层说明 | `body(14)` text2 | R19 `bodySm` |
| M17 | `security/mfa/mfa_sheet.dart` ×3、`passkey_sheet.dart` | `caption(12)` text3 | R19 `bodySm` text2；两处标题 `headlineMedium` → 显式 `LoopType.heading`（同值，保留测试 key） |
| — | `mfa_sheet.dart` TOTP 密钥 | `figure(15)` | R30 `code` 13 |
| M11 | `wallet/approval_screens.dart` 两个弹层标题 | `titleLg` 16 | `LoopSheetHeading`；弹层正文包 16 横向内边距（原先贴边）；`APPROVAL GUARD · REQUEST` `LoopMono.label` → `eyebrow` |
| M44 | `security/app_lock/app_lock_gate.dart`、`account/privy_login_screen.dart`（恢复中 `titleMedium` 15、失败 `title(16)`）、`account/onboarding_communities.dart`、`shell/loop_pending_surface.dart`（卡标题 `titleLarge`、顶栏 `headlineLarge` 22） | 15 / 16 / 22 | R31 `titleLg` 16 |
| M39 | `account/loop_id_setup_screen.dart:177`、`account/privy_login_screen.dart` 输入 | `body(16)` | R25 `bodyLg` 15 |
| L6 | `account/privy_otp_screen.dart` 验证码格 | `figure(26)` h1.15 | R24 `figureLg` 20 |
| L7 | `account/account_screens.dart` 建钱包标题 / 说明 | `display(21)` + `body(12.5)` | `heading` 20 + `caption` 12 text2 |
| L27 | `account/privy_login_screen.dart`「或」 | `eyebrow(10)` | R21 `captionSm` 11 |
| L21 | `account/onboarding_communities.dart`「跳过」 | `label(14)` muted | R17 `label`@600 text2 |
| — | `privy_login_screen.dart` 步骤标题 | `heading(24,700)` | R1c `stepTitle` |
| L9 | `launch2/creator/launch2_deployment_screen.dart` 状态文字 | `figureLg` | `heading` 20 |
| L11 | `launch2/creator/launch2_creator_widgets.dart`「总量」 | `figureXl` 28 | `figureLg` 20 |
| — | `shell/loop_pending_surface.dart` kicker / 键值行 | `LoopMono.label` / `LoopMono.value` | `eyebrow` / `figure`（同像素） |
| — | 旧发射 `launch/**` 四个文件（56 处 + 1 别名） | 金额输入 / 占位 `figure(24,700)`、预计获得 `figure(18,700)`、格值 `figure(15/16,700)`、卡标题 `title(24)`、投影行 `title(14)`、格标签 `figure(11)`、错误代码 `figure(12)`、`LoopMono.stamp` 等 | R24 `figureLg` / R23 `figureMd` / R6·R12 `figure` / `displaySm` / `title` / R13 `kicker` / R30 `code` / `figureXs`；其余 `caption(11|12)`、`eyebrow(11)`、`label(12)` 机械换成 `captionSm` / `caption` / `kicker` / `label` |
| — | 其余机械替换（各文件） | `caption(11|12)`、`body(13|14|15)`、`title(15|16)`、`figure(13|20)`、`label(12,700)` | 同像素的 `LoopType` 步（颜色只经 `copyWith(color:)`，字重只经 `withWeight`） |

### 2. 保留项

- `account/loop_id_setup_screen.dart`：LOOP ID 主值（`:227`）由 S197-3 / 0191 落为 `figureLg`；未分配时的「尚未分配」本批落为 `bodySm` text3（同 13px）。该文件白名单清零。
- `mining/referral_screen.dart` 等级格：五个并排、当前层 Lime 填色，不是 `LoopStatGrid` 的两列网格，换部件会改布局；只把字换成该部件的两档（`kicker` / `figure`）。部件缺口：`LoopStatGrid` 没有「横排 N 格 + 高亮格」变体。
- `mining_secondary_screens.dart` 社区贡献两格同理，手写但用 `figureMd` / `kicker`。
- 挖矿主卡大数字 44 → 28 是本批最明显的视觉变化（docs/37 未列，属「顺带」：44 不在阶梯内，R22 只有 28）；主卡会变矮，三格与按钮上移。如主代理认为挖矿主视觉需要更大一档，应在阶梯补档而不是回到 44。
- 居中状态页的说明行（锁屏、恢复中等）仍是 `caption` 12，未改成 `LoopEmptyState` 的 `bodySm` 13（docs/37 未列）。
- `wallet/approval_screens.dart` 第二个弹层的风险原因行仍是 `caption`（只允许动标题）。

### 3. 白名单变化（`scripts/check_harness.py`）

`TYPE_LADDER_FEATURE_ALLOWLIST`（builders, aliases）——全部删除条目：

| 文件 | 前 → 后 |
|---|---|
| `account/account_screens.dart` | (8, 0) → 删 |
| `account/loop_id_setup_screen.dart` | (5, 0)，S197-3 后 (4, 0) → 删 |
| `account/onboarding_communities.dart` | (4, 0) → 删 |
| `account/privy_login_screen.dart` | (11, 0) → 删 |
| `account/privy_otp_screen.dart` | (3, 0) → 删 |
| `launch/launch_action_screens.dart` | (13, 0) → 删 |
| `launch/launch_detail_screens.dart` | (11, 1) → 删 |
| `launch/launch_trade_screen.dart` | (15, 0) → 删 |
| `launch/launch_widgets.dart` | (17, 0) → 删 |
| `mining/mining_screen.dart` | (2, 1) → 删 |
| `mining/mining_secondary_screens.dart` | (11, 1) → 删 |
| `mining/mining_widgets.dart` | (16, 0) → 删 |
| `mining/referral_screen.dart` | (9, 0) → 删 |
| `mining_rewards/mining_rewards_screen.dart` | (3, 1) → 删 |
| `security/app_lock/app_lock_gate.dart` | (2, 0) → 删 |
| `security/app_lock/app_lock_prompt.dart` | (2, 0) → 删 |
| `security/mfa/mfa_sheet.dart` | (5, 0) → 删 |
| `security/mfa/passkey_sheet.dart` | (1, 0) → 删 |
| `security/step_up/step_up_widgets.dart` | (2, 0) → 删 |
| `shell/loop_pending_surface.dart` | (0, 3) → 删 |
| `shell/loop_shell.dart` | (1, 0) → 删 |
| `system/system_surfaces.dart` | (3, 0) → 删 |
| `wallet/approval_screens.dart` | (0, 1) → 删 |

合计 23 个文件、144 处数字 builder + 8 处别名 → 0（以 0189 基线计；`loop_id_setup` 的 1 处已由 0191 先行落档）。
`TYPE_FLOOR_FEATURE_ALLOWLIST`：`account/privy_login_screen.dart` 1、`mining/mining_secondary_screens.dart` 3、`mining/mining_widgets.dart` 3、`mining/referral_screen.dart` 1 → 全删（8 → 0）；剩 `meme/meme_widgets.dart` 1 归 S197-2。
`tests/test_check_harness.py` 的 G2 总数断言 9 → 1（S197-2 合入时再改 0）。

## Consequences

- 可见变化（待主代理真机验收）：挖矿主卡大数字 44 → 28、9/10px 小字全部到 11（主卡与社区卡略变高）、指标值 11 → 13；挖矿奖励页说明统一 12 灰；Referral 两个弹层标题 18/700 → 20/600、说明变 text2 13；
  邀请等级格值 15/700 → 13/600；锁屏 / 恢复中标题 15 → 16，待开放页顶栏标题 22 → 16；大额验证金额输入 16 → 20；验证码格 26 → 20；建钱包标题 21 → 20、说明 12.5 → 12；登录与 LOOP ID 输入 16 → 15；
  发射创建「总量」28 → 20、部署状态文字改 heading；授权两个弹层标题 16 → 20 且正文有了 16 边距；旧发射页金额输入 24/700 → 20/600、格值 16/700 → 13/600。
- 新测试 `test/s197_4_type_test.dart`（6 例）：挖矿主卡（M33 / M34 + 大数字）、`MiningMetricRow`（M37）、`MiningDetailRow`、Referral 等级格与说明弹层（M36 / M7 / M17 / L1）、待开放页（M44）、建钱包（L7），按绘制样式断言字号 / 字重。
- 没有既有测试因字号改档而需要修改。
- 门禁（基线 6678e8b rebase 后）：`dart format --set-exit-if-changed lib test` 0 changed；`flutter analyze` No issues found；`check_harness.py` passed；`unittest` 482 OK；全量 `flutter test` +5186 ~3 All tests passed。未起模拟器。
