# 0078 · 语音房按冻结原型重排，三个人数口径合并成一个

## Status

Accepted 2026-09-23。S77d，客户端单侧。不新增、不改动任何路由（`voiceroom`
与 `voiceroom-full` 都在 93 条清单内），不新增、不改动任何接口调用：本决策
只改这两页的排布、文案与数字口径，以及这次语音会话是什么时候开始申请的。
依赖的服务端契约不变（`loop-api/docs/frontend-v2-communication-api.md` §5，
决策 0051 / 0052 / 0053 / 0054 / 0069）。

## Context

2026-09-23 主代理真机走查（`LOOP/docs/acceptance/2026-09-23-full-walkthrough.md`
a14、a34–a46）判定语音房是与冻结原型差距最大的页面。用户裁决：原型差距大的
先修。差距逐条如下。

| # | 走查条目 | 原型（`docs/prototype/screens/voiceroom*.html`） | App |
| - | --- | --- | --- |
| 1 | a37 / a41 / a43 | 紧凑视图＝hero「N 人」+「正在发言」头像网格 +「听众 N」+ 三个按钮 + 一条 Stream 说明 | 另加五行统计表（当前在线 / 服务商已授权成员 / LOOP 已加入 / 发言人·听众 / 我的角色）与两段重复说明，整页远长于原型 |
| 2 | a38 | 全屏视图＝「N 人在麦上」+ 发言人行（名字 + 发言中/已静音）+ 举手队列（序号 + 等待邀请）+ 主持人控制 + 离开 | 同一张统计表，文案是实现口吻 |
| 3 | a34 / a43 | — | 顶栏「进行中 · 发言 0 · 听众 0」与 hero「1 人在房间里」并列；主持人开麦后「正在发言」网格出现「我」，顶部仍是「发言 0」 |
| 4 | a14 | — | hero「语音房状态读不到」与正文「当前没有进行中的语音房」同屏 |
| 5 | 已结束态 | — | 胶囊是裸英文「ENDED」；「进入前请确认…」在已加入与已结束时仍显示 |
| 6 | a34 | — | 建房后「正在准备语音连接」20–30 秒 |
| 7 | community-profile | — | 本社区语音房进行中时，喇叭按钮没有任何 LIVE 标识 |
| 8 | a38 | — | 统计表里的时间是 UTC |

第 3 条的根因是契约里三个人数口径（决策 0051）被原样搬到了界面上：

- `speakerCount` / `listenerCount` 是 LOOP 的角色意图，**两个都不含主持人**；
- `joinedCount` 是房内总数，**含主持人**（live 房 = 1 + speaker + listener）；
- `observed.participantCount` 是服务商当前在线参与者。

把前两个当作「发言 / 听众」印在顶栏、把第三个印在 hero，于是只有主持人的房间
显示成「1 人在房间里 · 发言 0 · 听众 0」——主持人不在任何一栏里，读者只能
读成自相矛盾。

## Decision

### 1 · 一个房间只有一套数字，而且加得起来

新增 `VoiceRoomHeadcount`（`lib/features/chat/v2/voice_room_screens.dart`）：

| 字段 | 定义 |
| --- | --- |
| `inRoom` | `participants.joinedCount ?? (speakerCount + listenerCount + 1)` |
| `speaking` | `inRoom - listening`，**含主持人** |
| `listening` | `participants.listenerCount` |

`speaking` 从房间总数里减出来，而不是在角色数上加一：这样页面上三个数字永远
两两自洽。服务端没有给 `joinedCount` 时按 live 房的定义补出来（live 房永远有
主持人：服务端对主持人的 `leave` 直接 403，主持人只能 `end`）。总数低于自身
分项这种不该出现的数据，按角色数兜底，绝不印出负数。

页面口径：

- 顶栏：`进行中 · 发言 {speaking} · 听众 {listening}`
- 紧凑 hero：`{inRoom} 人在房间里`，胶囊 `{inRoom} LIVE`
- 全屏 hero：`{speaking} 人在麦上`，胶囊 `ON AIR`（原型原词）
- 全屏「发言人 N」：`speaking`；「听众 N」：`listening`

### 2 · 紧凑视图＝`#scr-voiceroom`

删掉五行统计表（`_RoomFacts`）、「返回不等于离开」、「主持人不能离开房间」
两段说明，以及长版「语音由 Stream 承载」。留下的是原型的顺序：正在发言网格 →
听众 N（+「查看听众名单」，S72 为反馈 #6a 加的出口）→ 通话面板 → 控制条 →
一条 Stream 说明。

统计表删掉之后，「此刻在通话里 N 人」只剩通话面板一处在说，页面不再同时给出
两个在线数字；`observed` 读不到时也不再有一行会印出「—」。

### 3 · 全屏视图＝`#scr-voiceroom-full`

顺序：通话面板 → 发言人 N → 举手队列 N → 主持人控制（仅主持人）→ 听众 N →
控制条。

- **发言人**行按原型压成一句：`可以发言` / `已静音`（可取消时写「点这一行可以
  取消静音」），状态本身由右侧徽章承担，行首补头像。
- **主持人行**：`GET …/members` 两个视图都不含主持人（决策 0052），所以只有
  主持人在说话的房间过去显示「当前没有发言人」，而标题里又数着一个人。现在
  发言人列表的第一行是主持人自己：读者是主持人时写「我」，并按本机通话状态
  写「主持人 · 发言中 / 麦克风已开」；读者不是主持人时写「主持人」，不编造
  名字——服务端没有发布主持人的身份投影（见下「未做」）。
- **举手队列**行：`第 N 位 · 等待邀请`，徽章是序号，与原型一致。
- **主持人控制**只在全屏视图出现，内容是服务端逐条发布的「邀请发言」列表加
  「全体静音」；「移出发言 / 静音 / 取消静音」仍然只在发言人行上，来自服务端
  的 per-row `commands`（决策 0073）。没有新增任何端点。
- **结束房间**从主持人控制区移到控制条，两个视图都在：主持人没有「离开」，
  结束房间就是主持人在原型控制条里的位置。原来两段解释「为什么没有离开」的
  文字删除，只在「结束房间」这次读不到时留一句。

### 4 · hero 与正文是同一个回答

`voiceRoomHeading` / `voiceRoomCaption` 现在读页面的 `CommunityViewPhase`：

| 状态 | hero | 正文 |
| --- | --- | --- |
| loading | 正在读取语音房 | 骨架 |
| empty | 当前没有语音房 | 当前没有进行中的语音房 |
| error / offline / unavailable | 语音房状态读不到 | 对应五态块 |

已加入时 caption 是「返回会把房间收起在顶部，随时点开回来。」——「返回不等于
离开」整条 notice 压成这一句；未加入时才是原型的「进入前确认主持人、在线人数
与录音说明。」；已结束时是「主持人已经结束这个语音房。」胶囊 `ENDED` 改成
「已结束」。

### 5 · 社区详情页的 LIVE 标识

`community-profile` 的语音按钮在房间进行中时带 `LIVE` 字样（无障碍名
「进入语音房 · 进行中」）。亮起的时机不变，仍是 S72 的 5 秒前台轮询
`GET …/voice-rooms/current`，满足「≤5 s 内亮起」。

### 6 · 语音会话与建房并行

「正在准备语音连接」就是 `streamVideoAuthorizationProvider`：LOOP 身份
（bootstrap authorize）→ `POST /v2/video/token` → 建 Stream 客户端 →
`client.connect()` 的 WebSocket。这四步**与房间无关**，只需要账号。

改之前是严格串行：

```
点「开启语音房」
  → POST /v2/communities/{id}/voice-rooms（LOOP 行 + Stream create + go_live）
  → 进入语音房页 → GET …/voice-rooms/current
  → 视图判定已加入 → 挂载通话面板
  → 这时才开始 watch 语音授权（身份 + token + 连接）
  → call.join()
```

改之后，语音授权在两个更早的位置被 watch 住：

- 社区详情页：点「开启语音房」或「进入语音房」的那一刻开始，并由该页
  持有到 push 之后（页面仍在栈里，`autoDispose` 不会回收）；
- 语音房页：只要页面打开且能力未被关闭就持有。

于是授权与 `POST …/voice-rooms`、`GET …/current`、`POST …/join` 并行。它
不加入任何通话、不申请麦克风权限——这两件事仍然只发生在通话面板内部
（`autoConnect` 的语义不变）。

**耗时量化未完成**：本机没有真机，这里只能给出结构结论（一条串行链变成两条
并行链，省掉的是授权链的整段往返）。为了让主代理在真机上直接读到数字，debug
构建会打印三条：

```
LOOP voice connect · session · <ms>      # 语音授权可用
LOOP voice connect · call.created · <ms> # 通话对象建好
LOOP voice connect · call.joined · <ms>  # call.join() 返回
```

时间原点是通话面板挂载的那一刻。真机复核时把三条数字记进走查报告，如果
`session` 仍然占大头，下一步是把 `POST /v2/video/token` 的结果在会话级缓存
（当前每次授权都重新取）。

### 7 · 时间

语音房两页现在不显示任何时间：唯一显示时间的地方是被删掉的统计表里的
「观察于 … UTC」。共享助手 `communityObservedAtLabel` 仍然输出 UTC，它被另外
七个页面使用、属于 `community_widgets.dart`，本次不动（见「未做」）。语音房
将来若要再显示时间，按本决策必须是本地时间。

## Consequences

- 两页都比改前短：紧凑视图少了 5 行记录 + 2 条 notice，全屏视图少了同一张表。
- `observed.memberCount` / `observed.participantCount` / `observedAt` 不再出现
  在语音房页面上。决策 0051 的三个口径在契约里没变，只是界面不再同时陈列。
  「此刻在通话里 N 人」仍由通话面板陈述，它的每一种相位的措辞由
  `test/stream_foreground_call_presentation_test.dart` 逐条锁定。
- 「我的角色」行消失：角色由控制条本身表达（举手/离开 vs 结束房间），全屏视图
  里还有自己的那一行。
- 语音授权比过去更早开始，读者只是打开语音房页而从不加入时，也会建立一次
  Stream 客户端连接。这是这次决策明确接受的代价；它仍然不加入通话、不开麦。

## What this does not do

- **不为非主持人解析主持人身份**。服务端的房间资源不发布主持人的
  `publicProfileId` 或 alias，名单两个视图也不含主持人。非主持人看到的那一行
  只写「主持人」。要显示名字需要后端在房间资源里增加一个主持人身份投影
  （与决策 0053 的匿名规则一致）——已记入待办，本次不编造。
- **不新增任何主持人命令**。原型「主持人控制」卡片写的是「邀请发言 / 移出发言
  / 全体静音」；邀请发言与全体静音走决策 0069 已有端点，移出发言是发言人行上
  服务端逐行下发的命令，三者都不是新接口。
- **不改 `communityObservedAtLabel`**（社区、挖矿、聊天等七处共用，属另一条
  正在进行的工作线）。
- **不量化真机连接耗时**（无真机，见上）。
- **不动 `ios/Podfile.lock`**：`python3 scripts/check_harness.py` 在基线
  `3d62557` 上就已经因为 `COCOAPODS: 1.16.2` 失败，属 iOS 工具链那条线。

## Verification

```
bin/flutter pub get --enforce-lockfile
bin/dart format --output=none --set-exit-if-changed lib test
bin/flutter analyze
bin/flutter test
python3 scripts/check_harness.py
python3 -m unittest discover -s tests -p 'test_*.py'
```

新增 `test/s77d_voice_room_prototype_test.dart`：人数口径（含主持人、总数缺失
时的推导、不出现负数）、紧凑视图的两种角色、全屏视图的两种角色、已结束态、
hero 与正文一致、只有主持人的房间不是空名单。`test/community_pages_test.dart`
锁定 LIVE 标识。
