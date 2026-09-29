# 0106 · 语音房需求方验收四条（S101）：后台保活、听筒/扬声器、断线自动重连、展开页

## Status

Proposed 2026-09-29。S101，客户端单侧。基线 `integration/v2` 6518eab。不新增依赖、`pubspec.lock`
不变（`connectivity_plus` 7.3.1 已是直接依赖，复用 `loopConnectivitySignalProvider`）、路由清单不变（93 条）。
**推翻**「语音房仅前台」（product-decisions Communication 段、implementation-constraints 两条、
`scripts/check_harness.py` 的 Audio Room 原生合同）。

## Context

需求方原话：

1. 发言人切屏（回桌面 / 切到别的 App），房间内会暂离退出，切回软件后需要重新连接发言。
2. 声音输出没有听筒和扬声器的切换设置，不知道为什么有时候听筒有时候扬声器。
3. 国内网络会断，要重连。
4. 右上角箭头好像只是主持人权限，进去后页面相似，返回后会断开语音。

根因：

1. 设计如此。`ActiveVoiceMediaController._onAppLifecycle` 与房间页 surface 自己的 observer 在
   `paused` / `hidden` / `detached` 时都退出通话；iOS `UIBackgroundModes` 只有 `remote-notification`；
   Android 把前台服务权限与 `StreamCallService` 全部 `tools:node="remove"`。
2. `mutedAudioRoomConnectOptions()` 的 `speakerDefaultOn: true` 只在 SDK 没挑出默认设备时生效。
   Stream 1.4.3 在 join 时按 dashboard 的 `speaker_default_on` / `default_device` 先挑一台
   `audioOutputDevice`（dashboard 关着就挑第一台非扬声器 = 听筒），而我们的 `speakerDefaultOn`
   只在 merge 后覆盖同名字段、不覆盖已挑好的设备；上麦时 iOS 的 voice-chat 会话又常落回听筒。
3. SDK 自己的重连（`reconnectTimeout` 默认 0 = 无限、`networkAvailabilityTimeout` 5 分钟）放弃后
   （`CallStatusReconnectionFailed` / disconnected），页面只给「语音已断开」+「重新连接语音」按钮。
4. a）大厅 surface 的 `didUpdateWidget` 用 **对象同一性** 判断「call factory 换了 = 换了 client」，
   换了就退出当前通话。`audioRoomCallFactoryProvider` 每次授权 provider 再答一次 `authorized`
   都会 new 一个 `StreamAudioRoomCallFactory(client)`——client 没变，对象变了。展开页盖在大厅上时，
   大厅（Riverpod 3 对不可见 Consumer 暂停订阅）不重建；返回时它拿到新 factory 对象、判定「换了 client」、
   把正在进行的通话退掉再重连一次，读者听到的就是「返回后断开」。回归测试在旧比较下复现（见 Evidence）。
   b）展开页对所有人都有入口，普通成员进去只看到和大厅差不多的内容。

## Decision

### 1 · 后台继续收听与发言

- `paused` / `hidden` / `inactive` 不再是收尾。通话由 `ActiveVoiceMediaController` 持有，退后台
  不退出、不静音、不挂起；正在重连的照常重连。只有「离开」、房间结束、账号变化、`detached`
  （进程被收起 / Android Activity 被销毁）才收尾。
- 房间页 surface 去掉自己的生命周期 observer（原 `_retireForBackground` / `_resumeAfterBackgroundRetirement`
  及「语音已暂停」态）；回前台时持有者只重新施加输出路由，并叫醒正在退避的重连。
- iOS：`UIBackgroundModes` 加 `audio`（不加 `voip`，不接 CallKit / PushKit）。SDK 选项维持
  `muteAudioWhenInBackground: false`——1.4.3 的后台自动静音 / 回前台自动开麦会走停止轨道重建路径，
  这是 0005 明令禁止的。
- Android：启用 stream_video_flutter 1.4.3 自带的 `StreamBackgroundService`
  （`AudioRoomSystemSession.bind`，每个 client 一次）。它按 `activeCalls` 自动启停 `StreamCallService`
  和常驻通知：标题「正在语音房 · 社区名」（`voiceRoomSessionProvider` 实时改名），正文「点按回到语音房」；
  点通知 → `${applicationId}.intent.action.STREAM_CALL` → 插件回调 → 壳层横条打开 `/chat/voice?id=`
  （已在房间页则只回前台）；通知唯一按钮资源覆写为「离开」：听众/发言人等同横条「离开」（退通话 + 释放 LOOP 成员），
  主持人只断本机语音（主持人没有「离开」，也不在一次点按里替所有人结束房间），房间页随即显示「语音已断开 · 重新连接语音」。
  SDK 只在 `RECORD_AUDIO` 已授权时把 `microphone` 加进前台服务类型（Android 14 要求）；听众入场时还没授权，
  所以第一次成功开麦后（此时 LOOP 在前台）停启一次服务，让它带上麦克风类型。
  Manifest 只恢复 `FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_MICROPHONE`、`FOREGROUND_SERVICE_MEDIA_PLAYBACK`
  与 `StreamCallService`；`MANAGE_OWN_CALLS`、`FOREGROUND_SERVICE_PHONE_CALL` / `_CAMERA` / `_MEDIA_PROJECTION`、
  `StreamScreenShareService`、来电相关组件继续移除。通知小图标覆写为 LOOP 描边标（`stream_video_ic_call`），
  通道名覆写为「语音房」。

### 2 · 听筒 / 扬声器

- 默认扬声器。房间控制条（麦克风与挂断之间）加一个输出按钮：文字与图标来自 SDK 读回的
  `CallState.audioOutputDevice`（`audioRoomOutputRouteOf`：iOS `Speaker` / `Receiver`、SDK 的 `earpiece`、
  Android `speaker` / `earpiece`，其余一律视为外接设备），点一下切到另一条内置路由；读回的是外接设备
  （耳机 / 蓝牙）时按钮显示设备名且不可点——声音以它为准。读不到路由时显示「声音输出」，不拿偏好冒充读数。
- 选择只在本次 App 进程内记住（`audioRoomOutputPreferenceProvider`），不持久化。
- 施加点（`_StreamAudioRoomCallHandle`）：join 成功后连接落地（含 SDK 自己重连后再次 connected）、
  麦克风打开、音频设备增减（设备集合变化才算）、持有者 `hold` 新通话、回前台、读者切换。统一走 SDK 官方
  `Call.setAudioOutputDevice`，外接设备在 iOS 上不强制（SDK 注释：iOS 不允许隐式设置），Android 上显式选中它。

### 3 · 断线自动重连

- SDK 放弃后（有页面时由 call view 的 `onDisconnected`，无页面时由读数流），由持有者
  `ActiveVoiceMediaController.recover` 接手：读房间（`GET voice-rooms/{id}`）→ 房间仍 live、账号仍在、
  provider 侧已开放 → 新建 Call、静音 join 同一房间。退避 1s/2s/4s/8s/16s，之后每 30s；
  `loopConnectivitySignalProvider` 报「网络回来了」或 App 回前台时立即重试。
  房间结束 → 清成员横条并提示「房间已结束」；账号不在房间 → 清横条；读房间失败 = 这一次失败，继续退避。
  第二次及以后的尝试先 `retireForRetry` 会话、重新取 token 与 client（被拒的是那个 client）。
  「离开」（页内、横条、通知）、换房间、账号变化都会终止重连。
- 旧 Call 的 leave（等待它从 `activeCalls` 消失）先于新 join，最多等 10 秒——0005 的同 CID 重入规则。
- 重连期间：横条「语音正在重连」；房间页显示「语音连接中断，正在自动重连」（加载态、不给按钮、成员资格不动），
  新 Call 一被持有就显示通话视图（「加入中」），不闪空页。
- 发言身份由 LOOP 成员角色与 provider 权限决定，新 Call 自然恢复；**不自动开麦**：新 Call 仍静音进入
  （一个 Call 只允许一次 Speak，重连 = 新 Call，技术上可以开，但替读者重新打开麦克风不是读者做的决定，
  且断线期间房间状态可能已变，例如主持人已把你移下麦或全体静音）。断前麦克风开着的，房间页在通话视图上方显示
  「已重新连接，点麦克风继续发言」，读者一开麦即消失。
- SDK 自身超时：`reconnectTimeout` 已是无限、`networkAvailabilityTimeout` 5 分钟，调大不改变「放弃之后」
  这一段，所以不改 SDK 偏好；放弃之后由上面的循环兜底。

### 4 · 展开页

- a）`StreamAudioRoomCallFactory` 按 client 同一性定义 `==`，surface 用 `!=` 判断「换了 client」；
  同一 client 再读一次不再退出通话。大厅 ↔ 展开来回、从任一页返回社区页都不断开，只有明确「离开」才断。
- b）**偏离原型**：`voiceroom` 顶栏右上角「展开」（`voiceroom-open-full`）只对有主持人控制的人
  （`viewer.showsHostControls`：主持人且服务端给了邀请 / 全体静音 / 结束权限之一）显示；普通听众与发言人不显示。
  深链直接进 `voiceroom-full` 的非主持人照常可看、不报错。大厅里「查看听众名单」按钮（决策 S77 系列的走查反馈
  「听众列表在哪」）保留给所有人（主代理 2026-09-29 裁决，见下）。

## Consequences

- 真机行为全部未验证：iOS 锁屏/切 App 后收听与发言、控制中心音频条、打断（来电 / 闹钟）恢复；
  Android 12–15 前台服务启动、Android 14 麦克风类型、通知点按与「离开」、划掉任务后的收尾；
  听筒/扬声器/有线耳机/蓝牙四种路由读回；国内弱网下重连次数与耗时。
- `ActiveVoiceMediaController` 现在同时持有「重连循环」；它只在有成员横条（`voiceRoomSessionProvider`）时运行。

## 主代理裁决（2026-09-29）

1. 大厅「查看听众名单」对所有人保留（本决策 4b 只收起右上角「展开」）。
2. **Android 根页面系统返回键**：本机持有语音通话（`ActiveVoiceMediaController` 有 held call，或正在自动重连）时，
   返回键退到后台而不结束 Activity；没有通话时维持原状。实现（S101 追加 commit）：
   - `MainActivity` 在 `super.onCreate` 之后向 AndroidX `OnBackPressedDispatcher` 注册一个默认禁用的
     `OnBackPressedCallback`，处理为 `moveTaskToBack(true)`。它先于 `FlutterFragment` 自己的回调注册，
     优先级最低：Flutter 还能 pop 的页面全部仍由 Flutter 处理（0085 的返回链路不变）；只有 Flutter 在根页面
     把返回交还给系统时（其回调在根页面处于禁用，或 `SystemNavigator.pop` 经 `popSystemNavigator` 回到分发器）才落到它。
   - 启用与否由 Dart 经 `com.cywd.loop/voice_room_back` 的 `setHoldsVoiceCall(bool)` 告知
     （`lib/integrations/device/voice_room_back_guard.dart`，仅 Android 发送），持有者在 hold / release / 重连开始与结束 /
     账号轮换时同步，只在值变化时发送。iOS 没有结束 App 的系统返回，不发送。
   - 单测：适配器只在 Android 发送且参数正确；持有 → true，重连期间（含失败尝试与新 Call）保持 true，
     离开 → false，房间结束 → false。harness 锁定 `MainActivity` 与适配器的关键片段。
3. Play Console 前台服务类型声明作为发布待办（见下）。
4. 不改 SDK 的联网检测地址。

## 发布待办

- Play Console（target SDK 36）声明前台服务类型：`microphone`、`mediaPlayback`，并附语音房后台收听 / 发言的用途说明
  与演示视频。Stream 的 `StreamCallService` 在 manifest 里还声明了 `camera` / `phoneCall` / `shortService`
  类型，LOOP 不申请对应权限、运行时也不会以这些类型启动；如审核要求，发布前再决定是否用 `tools:replace` 收窄。

## Evidence

- `test/s101_voice_room_acceptance_test.dart`：退避 1/2/4 秒与第 4 次成功、网络恢复立即重试、离开后永不再连、
  房间结束不再连、成员资格丢失不再连、读房间失败算一次尝试、发言人重连后静音并提示、听众无提示、
  后台 3 分钟不退通话不关麦、输出偏好施加到当前与重连后的 Call、输出读回映射与切换、
  大厅→展开→（授权再答一次）→大厅→展开→大厅→社区全程不 leave、仅主持人有展开入口、听众深链可进展开页。
- 把 surface 的比较改回 `!identical(...)` 后，「大厅→展开→…」用例失败（返回大厅时新建了第二个 Call），
  确认 4a 的机制。
- `test/communication_pages_test.dart`：后台保持通话、`detached` 收尾、横条「语音正在重连」与自动重连、
  房间结束时横条消失并提示。
- `scripts/check_harness.py` 的 Audio Room 原生合同随本决策更新（三项前台服务权限改为必须声明、
  `StreamCallService` 不再移除、iOS 背景模式为 `audio` + `remote-notification`、必须有 `STREAM_CALL` intent-filter），
  `tests/test_check_harness.py` 相应更新并新增缺 intent-filter 的反例。
