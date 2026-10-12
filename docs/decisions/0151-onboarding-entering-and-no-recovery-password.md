# 0151 · 加入社区后的「正在进入 LOOP」过渡页（专属汇聚动画）；拿掉「恢复密码」两处（S153-mobile）

## Status

Accepted 2026-10-12。主代理下单（S153-mobile），基线 `integration/v2` be97915，分支 `feat/S153-onboarding-transition`。
依据：需求方 2026-10-12 TestFlight 验收反馈 #4；用户 2026-10-12 裁决（过渡页用专属动画、不用 Lime 线 loader；
拿掉恢复密码）。调整 0136（等待期间可点「进入 LOOP」离开 → 不可跳过的过渡页）。
不新增依赖、`pubspec.lock` 不变、路由 slug / path / 条数不变、视觉 token 不变、后端契约解析不变。

## Context

- `onboarding-communities` 按「加入 N 个社区并进入」全部成功后进入 `settling`（`settleMutes()` 每 1 s 读一次、最多 10 轮），
  期间页面与之前一模一样，只是按钮换成「进入 LOOP」，用户不知道在等什么。
- 用户裁决不再提供「恢复密码」：开户第三步 `wallet-recovery` 与安全中心都还列着它（「不可用」）。

## Decision

### A. 过渡页 `OnboardingCommunitiesEntering`（`lib/features/account/onboarding_communities.dart`）

1. **何时出现。** `controller.enter()` 返回 `clean == true` 的同一轮里 `setState(_entering = true)`，整页换成过渡页
   （key `onboarding-communities-entering`），列表页不会以「已全部加入」的状态再画一帧；随后
   `Future.wait([settleMutes(), Future.delayed(2.6 s)])` 结束后 `_leave()`（`onDone` 只调一次）。
   上限仍是 `settleMutes` 的约 10 s；下限 `onboardingEnteringMinimumStay = 2600 ms`（主代理 2026-10-12 由 1.8 s 调整），服务端立即确认也要把汇聚、光晕（1.8–2.4 s）与字标出现（2.0–2.4 s）播完再离开。
2. **不变的路径。** `selected` 为空直接 `_leave()`；有任何失败（`!clean`）仍留在列表页逐行说明，按钮「继续进入 LOOP」，
   成功行照常后台轮询换字；「跳过」两处（右上角 close、主按钮下方文字）不变。
3. **列表页按钮。** 删除 `settling && !hasFailures ? '进入 LOOP'` 分支（新流程下不可达）；`onPressed` 只看 `hasFailures`。
   「进入 LOOP」文案只剩一个来源：一个都没勾选时。
4. **页面。** 与开屏 `SplashScreen` 同底（主题 Scaffold 底色 Ink）、同 `SafeArea` + `SizedBox.expand` + 上下 `Spacer`；
   `PopScope(canPop: false)`，无按钮、不可返回。舞台 248 × 248 固定尺寸，动画只用 `Transform.translate` /
   `ScaleTransition` / `FadeTransition`，不触发布局；不引入依赖。
5. **动画（一条 2.4 s 的 `AnimationController` 时间线 + 一条呼吸控制器）。**
   - 0–1.2 s：刚加入成功的社区（列表顺序前 5 个，`CommunityLogo` 40 px 圆形，缺图走既有字母头像）均匀排在半径 96 的圆周上
     公转（2.4 s 一圈，easeInOut 起步）。key `onboarding-entering-logo-<communityId>`。
   - 1.2–1.8 s：沿螺旋（再转半圈）汇向中心，缩到 0.4、透明度到 0（easeInCubic）；汇聚完从树上移除。
   - 1.65–1.8 s：中心 Lime 实心点（直径 12）弹出（easeOutBack）。
   - 1.8–2.4 s：点化为柔和 Lime 光晕（径向渐变环，半径 12 → 72，透明度 0.8 → 0，easeOutCubic）；同时标题「正在进入 LOOP」
     与副文案「正在为你把刚加入的社区设为免打扰…」（12 px text3）在 1.8–2.2 s 淡入。
   - 2.0–2.4 s 起：中心留下品牌字标 `LoopBrandMark(wordmark)`（40 高，key `onboarding-entering-wordmark`），其下一层 Lime 径向
     光晕以 1.6 s 周期在 0.35 ↔ 0.6 之间呼吸，直到离开。
   - `MediaQuery.disableAnimations`：直接画终态（字标 + 文案 + 静止光晕 0.475），两条控制器都不跑，不请求帧。
6. **文案。** 主「正在进入 LOOP」，副「正在为你把刚加入的社区设为免打扰…」；不夹英文标点（`docs/copy-glossary.md`）。

### B. 拿掉「恢复密码」

1. `wallet-recovery`：`WalletRecoveryMethod.password` 从枚举删除（页面只剩 Passkey、自动恢复两行）；
   `PrivyWalletCapabilities.canUseRecoveryPassword` 保留（Privy 能力位照读，页面不展示）。
2. 安全中心：新增 `loopHiddenSecurityCapabilities = {recoveryPassword}`，`_SecurityMethodGroup` 的「验证 / 恢复」两组与
   「这些保护怎么开启」说明都过滤掉它。`GET /v2/security/capabilities` 的 codec、`LoopSecurityCapabilityId` 枚举不变：
   服务端仍下发 `recoveryPassword`，响应照样有效，客户端只是忽略。
3. 帮助与支持 FAQ「换手机怎么恢复账户」去掉「恢复密码、」。
4. 未改：`chain_contract.dart` 的 `PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING` 中文映射（原因码表，页面不再触达）。

### C. 「跳过」

两处保持不变（用户还在定）。

## Fixtures / 测试

- `test/s109a_onboarding_communities_test.dart`
  - 原「进入 LOOP joins each…」改为断言过渡页出现、列表消失，免打扰结果从 controller 状态读（列表已不在屏上）。
  - 原「the reader can leave while the mutes settle, once」改为「the entering page offers no way out and leaves once」：
    5 个 logo key、字标初始透明度 0 / 2.6 s 后 1、logo 汇聚后移除、无按钮无 TextButton、`PopScope.canPop == false`、
    10 轮上限到点 `onDone` 恰好一次、再等 5 s 仍是一次。
  - 新增「a clean result never draws on the list」：按下后到过渡页出现前的每一帧都是「正在加入…」，从不出现「进入 LOOP」。
  - 新增「nothing ticked leaves at once, without the entering page」。
  - 新增「reduced motion draws the last frame and holds still」：字标透明度 1、无 logo、不请求帧、2.6 s 下限后离开。
  - 「a server without the membership read ends the wait at once」：读失败 1 s 时还没离开，2.5 s 仍在，2.6 s 离开。
  - 失败路径补断言：列表在、过渡页不在、「继续进入 LOOP」。
  - 过渡页的呼吸一直在跑，相关用例不再 `pumpAndSettle`，改用 `tester.pump` 推进。
- `test/identity_pages_test.dart`、`test/s53_onboarding_sequence_test.dart`：`wallet-recovery` 「不可用」2 → 1，`recovery-password`
  不存在、页面无「恢复密码」。
- `test/security_capability_truthfulness_test.dart`：安全中心展示 5 项（「还没有开放」6 → 5），`security-method-recoveryPassword`
  不存在、页面无「恢复密码」。

- `scripts/check_harness.py` H5 证据：`for (final id in LoopSecurityCapabilityId.values)` + `findsNWidgets(6)` 改为
  `LoopSecurityCapabilityId.values.where((id) => !loopHiddenSecurityCapabilities.contains(id))` + `for (final id in shown)` +
  `findsNWidgets(5)`。
- `docs/decisions/0148-*` 补 `## Consequences`（基线 be97915 上 harness 即因此不过；只汇总 0148 原文，不新增决定）。

## Consequences

- 全部加入成功后不再能在等待期间提前离开（0136 的「随时可点进入 LOOP」取消）；最长约 10 s、最短 2.6 s。
- 过渡页的 logo 用列表已加载的 `logoRef`，不再发起额外请求。
- 安全中心与开户第三步不再出现恢复密码；服务端若日后真的开放该能力，需要新决策才会再展示。

## 未决项（需主代理 / 真机验收）

1. 真机看过渡页：iPhone 刘海 / 灵动岛安全区与小屏（SE 375 × 667）下舞台 248 + 文案是否居中、不裁切；Android 手势返回被拦截。
2. 动画节奏（1.2 s 公转、0.6 s 汇聚、0.6 s 光晕）与字标 40 高是否合适，属主代理自决范围，真机看后可微调常量。
3. 「跳过」两处去留待用户定。
