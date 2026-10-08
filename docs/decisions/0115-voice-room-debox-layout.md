# 0115 · 语音房按 DeBox 重排：主持人、发言者、听众三段 + 底部固定控制条；房间标题；广场卡片头像叠放（S110）

## Status

Accepted 2026-10-08。主代理设计（`LOOP/docs/modules/S108-S110-social-batch2b.md` §5），S110-mobile 实施。
基线 `integration/v2` e1007fd。对接后端 S109b-api（决策 0098，并行实现中）：`POST …/voice-rooms` 可选 body
`{ title }`、房间资源与 live 列表条目的 `title`、live 条目的 `speakersPreview`。不新增依赖、`pubspec.lock`
不变、路由清单不变（`voiceroom` / `voiceroom-full` 两个 route 原样保留）。

## Context

1. 需求方 v3（`LOOP/docs/09` §6.2 第 8 节）要求语音房参照 DeBox：主持人大头像居上，发言者与听众分网格，
   控制在底部；开播能起标题；广场能看出房间在聊什么、谁在麦上。
2. S110 之前：`/chat/voice` 是 folio 主图（「N 人在房间里」）+「正在发言」网格 + 一个「查看听众名单」按钮，
   举手 / 离开 / 结束房间在页面流里；媒体层（`StreamForegroundCallView`）再画一套自己的参与者网格与麦克风、
   挂断按钮；「Stream Video / Audio Rooms」说明和「服务商侧未确认」notice 占在主布局里；房间标题恒为
   「社区名 语音房」；广场卡片是一行 record row，没有头像。

## Decision

### 1. `/chat/voice`（直播中的房间）

- **顶栏**：返回（标签「收起语音房」，返回不等于离开）、社区 logo、标题（`title` ?? `「{社区名} 语音房」`）、
  副标题（无标题时「N 在听」，有标题时「{社区名} · N 在听」）、分享、(i)。
- **主持人区**：72 头像 + 名字 +「主持人」徽标 + 说话态 Lime 光环（减弱动态效果时瞬切）+「正在发言 / 麦克风已开 /
  已静音」。
- **发言者**：标题「发言者 {speakerCount}」，每行 4，48 头像 + 名字 + 角标麦克风态（关麦为斜杠 `voice-off`）。
  点有服务端命令的头像 → 原成员命令弹层（命令仍逐行由服务端下发）。
- **听众**：标题「听众 {listenerCount}」，每行 6，40 头像 + 名字，举手者角标手势；总数 > 18 时前 17 个头像 +
  第 18 格「+N」（N = 总数 − 17），点「+N」进 `/chat/voice/full`。名单页为空而房间计数 > 0 时只画「+N」。
- **底部固定控制条**（`LoopDashboardPage.bottomBar`，不随滚动）：
  - 听众：举手 / 取消举手 · 离开
  - 发言者：静音 / 取消静音 · 下麦 · 离开
  - 主持人：麦克风 · 邀请发言（角标 = 待处理举手数，→ `/chat/voice/full`）· 全体静音 · 结束房间
  - 未加入：单个「加入语音房」主按钮；房间不可加入 / 已结束时不出控制条，页面内说明。
- **媒体层**：`_MediaSection` 外包 `VoiceMediaPresentation`（`lib/features/chat/calls/voice_media_presentation.dart`）。
  `StreamForegroundCallView` 读到它时不再画自绘参与者网格与人数行；主页面把麦克风按钮交给
  `VoiceMicrophoneBridge`，由控制条画（命令、拒绝文案、「一次通话只能开一次麦」等逻辑仍在 call view 里），
  媒体层只留连接状态、系统暂停提示、麦克风说明、错误文本与输出（扬声器 / 听筒）控制；挂断由控制条的离开 /
  结束房间承担。live speakers（`audioRoomLivePresenceProvider`）继续喂主持人与发言者网格的说话态。
- **(i) 弹层**（`voiceroom-info-sheet`）：社区、开播时间、人数分项（`进行中 · 发言 N · 听众 N`）、我的身份、
  返回 / 进入说明、「服务商侧未确认」（如有，(i) 图标同时变 warning 色）、「Stream Video / Audio Rooms」说明。
  主布局不再放这两条 notice。演示数据标注（`CommunityPreviewNotice`）仍在主布局。
- 没有房间、读取失败、能力关闭、房间已结束：保持原 folio + 五态块（`voiceroom-screen` 同一页）。

### 2. `/chat/voice/full`

保留为完整名单与举手队列页：原布局（发言人行 + 主持人行、举手队列、主持人控制、听众名单分页、流内控制）不变。
标题跟随房间标题；顶栏去掉旧的「展开」入口（主持人改由控制条「邀请发言」进入），加 (i)；「服务商侧未确认」
同样收进 (i)。媒体层同样不画自绘网格，但麦克风与挂断留在媒体层（此页没有控制条）。

### 3. 开播填标题

`showVoiceRoomStartSheet(context, communityId) → Future<VoiceRoomOpenOutcome?>`
（`voice_room_stage.dart`，经 `voice_room_screens.dart` 导出）：说明文案 + 标题输入（可空，按码点限 40）+
开播 / 取消。提交时 trim，空串不传 `title`（请求无 body，与旧请求完全一致）；返回 `openRoom` 的结果，取消返回
null，结果的提示与跳转留给调用方。社区页 `_createVoiceRoom` 用它替换原确认弹层；S109b-mobile 的社区管理中心可
直接复用。弹层 key 沿用 `community-open-voice-room-sheet`。

### 4. 广场语音房卡片

卡片（`LiveVoiceRoomCard`）：社区 logo、标题（`title` ?? `「{社区名} 语音房」`）、社区名、状态徽标（直播中 /
已在房间 / 需加入）、主持人 + 发言者头像叠放（`speakersPreview` 最多 4；字段缺省或空时只叠主持人；匿名者只画
「匿名成员」首字母、不画图）、「主持 {名字}」、「N 在听 · 开播 X」。

### 5. 契约与数据层

- `VoiceRoomRecord.title`（可空）；房间资源编码器 `title` 为可选键（缺省 / null / 空白 → null，非字符串判无效）。
- `VoiceRoomGateway.createRoom(communityId, {String? title})`、`LoopV2CommunicationApi.createVoiceRoom(…, title)`：
  有标题时 body `{ "title": … }`，否则无 body。
- 幂等：开播键在「房间已建、通话未就绪」时会保留（既有行为，见 `dio_loop_v2_communication_gateway.dart`）。保留键的重试沿用第一次的标题，不会用同一
  个键发出不同 body；新标题等新房间。
- live 列表编码器：`title`、`speakersPreview` 进可选键集（其它键仍严格）；`speakersPreview` 缺省 / null → 空，
  非数组判无效，条目按 host 规则解码（无名者不得带 id / 头像），超过 4 条取前 4。
- `VoiceRoomOpenController.openRoom(communityId, {title})`；Preview 夹具（`MemoryVoiceRoomGateway`、
  `MemoryLiveVoiceRoomGateway`）带标题与 `speakersPreview`，仍只在 `main_preview.dart` 组合，模式 preview。

## 与契约的偏离

| # | 项 | S108–S110 §4 / §5 | 本批实现 | 原因 / 后续 |
| --- | --- | --- | --- | --- |
| 1 | 「{听众数} 在听」 | 顶栏与卡片写听众数 | 写房间总人数：房间页 `VoiceRoomHeadcount.inRoom`（主持人 + 发言 + 听众），卡片 `listenerCount + speakerCount + 1` | 主持人与发言者也在听；与决策 0051 起「所有数字互相加得起来」一致。听众段标题仍是纯听众数 |
| 2 | 主持人控制条 | 邀请发言 · 全体静音 · 结束房间（三项） | 前面加「麦克风」，共四项 | 主持人也要开麦；媒体层不再画麦克风按钮，否则主持人没有开麦入口 |
| 3 | 发言者「下麦」 | 控制条一项 | 按钮在，点击 toast「自助下麦当前不可用：后端只允许主持人调整发言人…」，不发请求 | `DELETE …/speakers/{本人}` 被后端拒绝，没有自助下麦命令。**需要后端**加 `DELETE /v2/voice-rooms/{id}/speakers/me`（或让本人行带 `remove_speaker`）；客户端届时只改 `_stepDown` |
| 4 | 主持人名字 / 头像 | 主持人大头像 + 名字 | 本人是主持人显示「我 · 名字」；否则取广场 live 列表同一房间条目的 `host`（页面进入时读一次 `GET /v2/voice-rooms/live`）；读不到或不在首页时显示「主持人」+ 首字母 | 房间资源与 members 都不含主持人（决策 0052）。**建议后端**在房间资源上加 `host { publicProfileId, displayName, avatarRef }`，客户端即可去掉这次列表读取 |
| 5 | 发言者 / 听众头像图 | 头像 | 首字母头像 | members 行没有 `avatarRef`。**建议后端**在 members 行补 `avatarRef`（匿名者 null） |
| 6 | 说话态匹配 | live speakers 喂说话态 | 本人行按 `isLocal` 匹配，其他人按 Stream 名字 = 名单显示名匹配；非主持人视角下，名单外且非本机的发声者视为主持人 | Stream 参与者不带 LOOP `publicProfileId`；名字不一致时只是不亮环，不会错标他人 |
| 7 | 社区 logo | 顶栏社区 logo | 取 live 列表条目的 `communityLogoRef`，没有则用社区首字母 tile | 房间资源不带 logo |
| 8 | 顶栏组件 | 顶栏 = 返回 + logo + 标题 | 直播态页面自绘一条 `LoopTopbar(leading: 返回 + logo)`，内容区用 `LoopDashboardPage(embedded: true)` | `LoopDashboardPage` 不透传 `leading`；本单不改共享 `lib/widgets/` |

## Consequences

- 测试：新增 `test/s110_voice_room_debox_test.dart`（三种角色控制条、麦克风经桥接、听众 > 18 显示 +N、
  名单五态、标题回退、开播标题传网关 / 空串不传 / 码点上限 / 取消不开播、广场卡片标题与头像叠放 / 空与匿名
  `speakersPreview`、live 编码器可选键）；`communication_api_contract_test.dart` 加 title body 与房间 `title`
  解码。改写的既有测试：`communication_pages_test.dart`（人数改「N 在听」、notice 进 (i)、两路名单各读一次、
  听众入口改「+N」、主持人说话态在主持人区）、`s77d_voice_room_prototype_test.dart` 大厅组（测试名保持，
  `scripts/check_harness.py` 依赖）、`s101_voice_room_acceptance_test.dart`（`voiceroom-open-full` →
  `voiceroom-invite-open`）、`community_pages_test.dart`（开播弹层按钮 key）、`s106_v3_navigation_test.dart`
  （卡片文案）。
- `voiceRoomHeading` / `voiceRoomStamp` 仍服务于无房间 / 已结束 / `voiceroom-full` 的 folio；`voiceRoomTopbarLine`
  进 (i)。
- 未验证（需真实房间）：真机说话态光环、控制条麦克风开关与「重新发言」、输出切换在新位置的可达性、真实
  `speakersPreview` / `title` 回包、长标题截断。
