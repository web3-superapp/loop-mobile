# 0186 · 安装后首次登录成功时提示开启应用锁（S196-mobile）

## Status

Accepted 2026-10-15。基线 `integration/v2` 3e342eb。用户删掉重装后应用锁开关（钥匙串）被清，App 没有任何提示，用户以为是 bug。

## Context

应用锁的开关只存在 `SecureStorageLoopAppLockStore`（`loop.app_lock.v1.enabled`）。重装后它读回 `null`，锁当作没开，
设置页那一行照实显示「未开启」，但没有任何地方告诉用户。

## Decision

- 到达时机：沿用 0076 的「到达」（profile 落地为社区 + 产品帧已画出，两者后到的那一刻），即过渡页结束、首页画出之后；
  `app.dart` 在该时刻的下一帧调用 `loopOfferAppLock`（`features/security/app_lock/app_lock_prompt.dart`）。
- 条件：会话为 `authenticated` / `authenticatedUnverified`（Preview 不弹）；应用锁可用（`isAvailable`）且未开启；
  本安装未提示过；本次运行未提示过。条件读之前先等应用锁的启动读取（`LoopAppLockController.whenLoaded()`），不把「未读到」当「未开启」。
- 弹层：`LoopSheet`，标题「开启应用锁」，说明「切到后台 60 秒后回来需要 Face ID / 指纹，钱包和聊天更安全」，
  主按钮「开启」（唯一满 lime，调用现有 `loopAppLockProvider.enable()`，系统验证通过即开并关闭弹层；
  未通过时弹层保留并用 `loopAppLockAttemptText` 说明结果），次按钮「以后再说」。
- 记录：点「开启」、「以后再说」或以其它方式关掉弹层，都记为已提示。应用锁不可用或已开启时不弹也不记。
- 持久化：新设备本地偏好 `loop.display.v1.app_lock_prompted`（布尔），一 key 适配器
  `SharedPreferencesLoopAppLockPromptStore`（`integrations/personalization/`，`SharedPreferencesAsync`，只调 getBool / setBool），
  只由 `lib/main.dart` 组装；缺省 provider 为不可用存储（读失败）。读写 1 秒超时 fail-open：读失败按「未提示」，
  但本次运行内只弹一次；写串行、失败只在本次运行有效。**不**写钥匙串，不新增 SecureStorage owner。
- harness：SharedPreferences 导入白名单加第五个文件；新增 `check_app_lock_prompt_store_contract`（导入三条、恰一个 key、
  只有该 key 字面量、只 getBool / setBool、恰一个 `SharedPreferencesAsync()`、只由 main 组装、文档与测试标记）。AGENTS 23 条补一句。
- 设置页应用锁那一行不变。

## Consequences

- 重装后第一次进入首页会看到一次提示；之后无论选什么都不再提示，直到再次重装（SharedPreferences 随 App 删除）。
- 偏好是安装级，不按账户分区：同一台设备换账号不会再问。
- 新账号若已在开户流程的安全步骤里开了锁，到达时锁已开，不弹；在那一步跳过的，到达时会再被问一次。

### 未按清单做的点

- 除两个按钮外，点遮罩 / 下拉关闭也记为已提示（视作「以后再说」）；弹层还开着时被杀进程则不记，下次启动再问。

## Verification

- 新增 `test/s196_app_lock_prompt_test.dart`：可用且未开 → 弹且只弹一次（同次运行与下次运行都不再弹）、同屏只有「开启」一个 primary；
  已开 → 不弹不记；不可用 → 不弹不记；Preview → 不弹；已提示过 → 不弹；读失败 → 弹一次、本次运行不再弹；读超时 → 按未提示弹；
  点「开启」→ 走 `enable()`（系统提示「验证身份以开启应用锁」）、锁开启并持久化、弹层关闭；验证取消 → 弹层保留并说明；适配器 key。
- `tests/test_check_harness.py` 新增 `AppLockPromptStoreContractTests`。
- 未起模拟器、未做真机验收。
