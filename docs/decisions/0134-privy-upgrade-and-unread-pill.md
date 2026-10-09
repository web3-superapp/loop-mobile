# 0134 · privy_flutter 升到 0.11.0、删掉 privy-core 强制覆盖；会话未读浮条不再压日期（S130）

## Status

Accepted 2026-10-10。主代理下单（S130-mobile），基线 `integration/v2` 4cb4293，分支 `fix/S130-privy-upgrade`。
来源：决策 0125（privy-core 0.12.1 空闲忙等）；证据 `docs/evidence/2026-10-10-s123f/07-channel-first-frame.png`。
依赖变更：`pubspec.yaml` / `pubspec.lock` 中 `privy_flutter` 0.10.1 → 0.11.0（锁文件只此一项变化）；
`ios/Podfile.lock` 中 `PrivySDK` 2.12.0 → 2.16.2（只此两项与 checksum 变化）。不新增任何依赖。路由清单不变。

## Context

两件事：privy_flutter 0.10.1 钉死 `io.privy:privy-core:0.12.1`，其 `WebViewState.awaitReady()` 在 `Dispatchers.IO` 上忙等，
导致 Android 空闲 CPU 约 146% 与 ANR，决策 0125 用 Gradle `resolutionStrategy` 把 privy-core 强制到 0.15.0 作为临时补丁；
本单查 privy_flutter 是否已有自带 ≥ 0.14.0 核心的版本以便去掉覆盖。另外真机走查发现进会话首帧「↑ 4 条未读 ×」浮条压在
日期分隔 chip「9月28日」上（证据 07）。

## Decision

### 一、privy_flutter 升级

#### 事实（2026-10-10 查询）

- pub.dev `https://pub.dev/api/packages/privy_flutter`：最新稳定版 **0.11.0**（版本序列 …0.10.0、0.10.1、0.10.2、0.11.0）。
- 各版本 `android/build.gradle` 声明的 Android 核心与 `ios/privy_flutter.podspec` 声明的 iOS SDK：

  | privy_flutter | io.privy:privy-core | PrivySDK (iOS) |
  |---|---|---|
  | 0.10.1（升级前） | 0.12.1 | 2.12.0 |
  | 0.10.2 | 0.15.0 | 2.16.2 |
  | 0.11.0（升级后） | **0.15.0** | 2.16.2 |

- CHANGELOG：0.10.2「Bumped the iOS SDK to 2.16.2 and the Android SDK to 0.15.0」；0.11.0 只新增 `privy.onNetworkRestored()`。
- 0.10.1 → 0.11.0 的 Dart 面变化（逐文件 diff 归档包核对）：
  1. 新增 `PrivyAuthException` / `PrivyWalletException` / `PrivyTimeoutException`，均为 `PrivyException` 子类；
     `convertToPrivyException` 按原生 code 选子类，`message` 仍是原生 `PlatformException.message`（为空才用新的默认句）。
  2. 若干「无响应」兜底文案改写（如 `Failed to send code` → `Email sendCode: No response from native platform`）。
  3. `PrivyConfig.awaitReadyTimeout`（默认 30 s）——只作用于 `awaitReady()`；LOOP 不调用 `awaitReady`（决策 0064）。
  4. `Privy` 抽象类新增 `onNetworkRestored()`；LOOP 没有实现 `Privy` 的假件，编译不受影响。
  5. 以太坊内嵌钱包 provider 未变：仍没有切链调用，决策 0062 的「只在 primary 链签名」结论不变。

#### 判断与改动

0.11.0 自己钉 privy-core 0.15.0（≥ 0.14.0，即修掉 `WebViewState.awaitReady()` 忙等的版本），API 变化只是加法，
因此 **升级**，并删除 `android/build.gradle.kts` 里 `loop.privyCoreVersion` 的 `resolutionStrategy` 强制覆盖，留一段历史注释
（以后某个 privy_flutter 若又钉回 < 0.14.0 才需要重新加）。`compileSdk = 36` 的覆盖保留：0.11.0 仍写 `compileSdk = 34`。

- `PrivyFailureClassifier` 继续按报文分类：新子类的 `flow` / `stage` 只说出错的是哪一步，不说凭据被拒还是设备离线，
  而登出只能由明确的凭据答复触发（决策 0064）。新兜底文案不含任何凭据标记（`login` / `sendCode` 都不在标记表里），
  只会落到 `unknown`（与网络同等对待），行为与 0.10.1 一致。
- `onNetworkRestored()` 是 `authenticatedUnverified` 的恢复入口，本单不接入；留作后续（见「未做」）。
- 版本号同步：`lib/app/bootstrap/sdk_compatibility.dart`、`test/sdk_compatibility_test.dart`、`scripts/check_harness.py` 的直接依赖钉、
  `harness.json` 技术栈、`docs/open-source-attribution.md`，以及仍然成立的代码注释（0.11.0 同样两步恢复会话、同样无切链）。
- `ios/Podfile.lock`：`pod update PrivySDK privy_flutter`（CocoaPods 1.14.3，x86_64 Ruby 需 `arch -x86_64`；CDN 直连报 HTTP2 framing
  错误，经本机代理 7897 完成）。锁文件仍含全部插件 pod（52 个），harness 通过。

#### 验证

- `flutter build apk --profile` 成功（无覆盖）；`./gradlew :app:dependencies --configuration profileRuntimeClasspath`
  解析为 `io.privy:privy-core:0.15.0`，没有冲突改写箭头。
- 空闲 CPU 的真机复测（0125 的 146% → 1–2%）本单没有做（不碰模拟器 / 设备），需主代理验收时在 Android 真机上复核一次。

### 二、会话首帧「N 条未读」浮条压住日期

#### 原因

Stream 把 `UnreadIndicatorButton` 画在列表的 `Stack` 上，距列表顶 `spacing.sm`。有未读时列表首帧把第一条未读消息锚在视口中部，
此时顶端那一行恰是最早一天的日期 chip（证据中的「9月28日」），被「↑ 4 条未读 ×」盖住。

先试过「最早一天的日期 chip 在有未读时加顶部留白」：列表锚在未读消息上时，chip 上方加的空间只会把内容往上（屏外）撑，chip 本身不动，
测试复现确认无效，已撤回。

#### 决定

浮条保留、外观不变（仍是 Stream 的 `UnreadIndicatorButton`），从「浮在列表上」改为「停靠在列表上方自己的一条」：

- 新文件 `lib/integrations/communication/stream_unread_pill_band.dart`：
  - `loopChannelListConfiguration(context)`：应用的列表配置 + `showUnreadIndicator: false`（关掉 Stream 自己的浮层）；
  - `LoopStreamUnreadDockedList`：`Column[LoopStreamUnreadPillBand, Expanded(list)]`；
  - `LoopStreamUnreadPillBand`：订阅 `currentUserReadStream`，有未读时显示浮条（上留 `LoopSpacing.x2`），否则高度 0；
    出现 / 收起用 `AnimatedSize`（`LoopMotion.contentFadeIn`，减弱动态时为 0）。
  - 「↑」复刻 Stream 的跳转：`StreamChannelState.getFirstUnreadMessage()`，在默认过滤后的新→旧列表里取下标 +2，`scrollTo(alignment: 0.5)`；
  - 「×」= `channel.markRead()`（与 Stream 相同）；失败只记 debug 日志，浮条留在原处。
- 接入两处主列表：`LoopStreamChannelSurface`（社区群 / 群 / 私聊）与 `LoopStreamGroupChannelPage`（后者新增 `ItemScrollController`）。
  线程列表本来就不显示未读浮条，不动。
- 有未读时列表顶比原来低一条浮条的高度（约 48 dp）；已读或点 × 后收起，列表拿回空间。视觉 token 不变。

#### 测试

- 新 `test/s130_unread_pill_band_test.dart`（6 例）：只有一个浮条（Stream 浮层已关）；浮条底 ≤ 列表顶，最早一天的日期 chip
  与所有消息行都不与浮条相交；已读后条收起、列表顶回到 0；无未读不出条；× 被拒时浮条保留且无异常；↑ 把第一条未读带回视口；
  减弱动态时动画时长为 0。
- `test/s99_chat_feedback_test.dart` 第 1 组（unread: true）原断言「列表顶 = 会话体顶」，改为「列表顶 = 会话体顶 + 浮条条高」。

## Consequences

- Android 不再需要任何 privy-core 覆盖，`-Ploop.privyCoreVersion` 参数随之失效；iOS 实际从 PrivySDK 2.12.0 升到 2.16.2。
- 有未读时会话列表顶部下移一条浮条的高度，任何消息行或日期 chip 都不会再被浮条遮住；已读后恢复。

### 未做 / 需决策

- `privy.onNetworkRestored()` 未接入 `authenticatedUnverified` 恢复流程（可在网络恢复信号 `LoopConnectivitySignal` 上调用后重读 `getAuthState`）。
- Android 真机空闲 CPU 复测、iOS 真机登录 / 签名回归（PrivySDK 2.12.0 → 2.16.2 是 iOS 侧的实际升级）未做。
- 浮条两枚按钮仍是 Stream 的 `StreamButtonSize.small`（32 dp），低于 44 dp 触控；这是 Stream 组件原样，本单只改位置。
