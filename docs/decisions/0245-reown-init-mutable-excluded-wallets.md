# 0245 · Reown 初始化失败 hotfix：excludedWalletIds 改可修改集合，初始化失败不再锁死（S305-mobile）

## Status

Accepted 2026-10-25。基线 `integration/v2` 8d57194e。主代理下单 S305-mobile（hotfix）。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api、不改 `/v2` 契约；用户可见文案不变。

## Context

- 现象：「连接已有钱包」必现「Reown 初始化失败，请重启 LOOP 后重试。」，重启后再点依旧。
- 根因：`ReownExternalWalletConnector._createModal` 传给 `ReownAppKitModal` 的 `excludedWalletIds` 是 `const <String>{…}`（不可修改集合）。reown_appkit 1.8.4 `ExplorerService._excludedWalletsParam`（explorer_service.dart:67-72）对传入集合原地 `..addAll(_installedWalletIds)..addAll(featuredWalletIds)`，抛 `UnsupportedError: Cannot change an unmodifiable set`，发生在任何 HTTP 请求之前。
- 放大器：`ExternalWalletInitializationGate.acquire` 的 `catch (error)` 把它归成「初始化失败」、不记录真实异常，并写 `_terminalFailure`，此后每次点击都直接抛「初始化未完成」，直到重启。

## Decision

1. **集合改为每次新建、可修改。** 新增 `ReownExternalWalletConnector.excludedWalletIds()`（`@visibleForTesting` 静态方法），每次 `_createModal` 返回新的 `<String>{Phantom, Solflare, Coinbase}`。同文件其余交给 SDK 的集合（metadata `icons`、`socials`、命名空间 `chains` / `methods` / `events`）一并去掉 `const` / `growable: false`。审过 SDK 1.8.4 源码，目前只有 excluded 集合被原地修改，其余是防御性改法。
2. **记录真实异常。** `acquire` 的 create 与 initialize 两处 catch 改为 `catch (error, stack)`，通过 `logExternalWalletInitializationFailure` 写 `debugPrint`（与 Privy / Stream 等集成相同的通道，Release 也会进 logcat / Xcode console）：`LOOP reown init failed [stage]: <runtimeType>: <toString>` + 堆栈前 5 行。App 没有统一的持久诊断日志，网络诊断页只做探测，故未新建机制。
3. **不锁死。** 去掉 `_terminalFailure`。create / initialize 抛异常、或初始化完成但未就绪时，gate 记录后清空 `_owner / _initialization`，并在后台 `dispose()` 失败的 owner（错误吞掉）；下次点击会重新 create + init。若上一个失败 owner 的 dispose 尚未结束，新的 `acquire` 先等它（受同一超时约束），超时才抛「Reown 初始化未完成」——这是该文案现在唯一的触发条件，保证任何时刻至多一个 owner。超时分支语义不变（保留 owner，重试时 reconnect 并继续等同一个初始化）。并发点击仍共享同一个 owner 与初始化 future（connector 的 `_active` 也会先挡住同实例并发）。

## Consequences

- 测试：新增 `test/s305_reown_init_gate_test.dart`（excluded 集合可 `addAll` 且每次独立；initialize 异步 / 同步抛错后记录真实类型、dispose、第二次 acquire 重新 create；重试等待 dispose 完成；并发共享一个 owner）。`test/external_wallet_credential_gateway_test.dart` 的超时复用用例不变、仍通过。
- 已知残留（SDK 限制）：AppKit 1.8.4 在构造函数里向 GetIt 注册服务，而 `dispose()` 只在 `status == initialized` 时注销。初始化中途失败的 owner 被 dispose 后，其服务仍留在 GetIt，下一个 owner 的 `registerSingletonIfAbsent` 会复用这些绑定旧 core 的服务。修复本根因后此路径只在罕见的其它初始化失败时出现；彻底清理需要直接依赖 `get_it`（锁文件 `dependency: transitive → direct main`），留给主代理决定。
