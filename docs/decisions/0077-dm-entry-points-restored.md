# 0077 · 私聊入口按原型接回

## Status

Accepted 2026-09-23. S75a，客户端单侧。不新增路由，93 条路由清单不变；
`/chat/dm` 与 `/chat/requests` 都是已有 route。它依赖已上线的
`POST /v2/chat/direct-channels`、`GET /v2/chat/operations/{id}` 与
`POST /v2/message-requests`（`loop-api/docs/frontend-v2-communication-api.md`
§3、§4；后端决策 0032 与 S4 热修）。隐私中心的社交开关界面不在本决策内。

## Context

冻结原型在五个地方把用户行当作 `dm` 入口：

| 原型位置 | 片段 |
| --- | --- |
| `community-members` 成员行 | `<div class="row" data-go="dm">`（Owner/Admin/成员四行） |
| `search` 的 `USERS` 行 | `<div class="row" data-go="dm">` |
| `group-info` 成员行 | `<div class="row" data-go="dm">`（两行） |
| `community` 消息中心 | `data-go="dm"` 的会话行 + `data-go="dm-requests"` 的「陌生人请求」行 |
| `dm` 本身 | 会话页 |

S3 做成员目录与全局搜索时，LOOP 没有另一个账号的页面，于是用共享的公开资料
卡片（`showPublicProfileSheet`）替代跳转。当时 V2 还没有私聊建立路径，卡片上的
「打开私聊」是一个 `onPressed: null` 的禁用按钮，下面写着「私聊还不能从这里
发起：这个入口没有可用的私聊通道。」

S4 之后这句话不再成立：`POST /v2/chat/direct-channels` 与
`POST /v2/message-requests` 都已接通，关注/粉丝行 → 动作表 → `/chat/dm` 这条路
一直在用。结果是同一个动作在一个入口可用、在另外两个入口写着「还不能」，而
用户能找到的人（搜索、成员列表）恰恰在不可用的那两个里。2026-09-23 用户裁决：
按原型恢复私聊入口。

## Contract facts this rests on

| Fact | Value |
| ---- | ----- |
| 唯一命令目标 | `publicProfileId`（opaque UUID）。alias、LOOP ID、钱包地址都不是 |
| 建立会话 | `POST /v2/chat/direct-channels`，好友关系是唯一准入；无好友关系时返回 `friendshipRequired` |
| 加人闭环 | `POST /v2/message-requests`，对方接受后产生 friendship，会话才存在 |
| 会话定位 | 只用服务端签发的 `channelCid`，客户端不拼装 |
| 群成员显示名 | 社区/小群内是服务端生成的 persona（`loop_group_alias`），**不含** `publicProfileId`；LOOP 没有「由群成员查公开资料」的接口 |
| 陌生人请求计数 | 只有 `GET /v2/message-requests` 这一个来源，且它就是 `/chat/requests` 那一页的读 |

## Decision

| Topic | Ruling |
| ----- | ------ |
| 资料卡承载私聊 | 「打开私聊」变成资料卡上的常规控件：关闭卡片，把这张卡画的那个账号交给调用方。卡片自己不导航，和它渲染服务端治理动作时的分工一致。过期的禁用态与「私聊还不能从这里发起」整句删除，不是隐藏。 |
| 路由归属 | `lib/app.dart` 的 `_openDirectMessageFromProfile` 是这条路径上唯一 `context.push('/chat/dm')` 的地方。对方的四字段投影作为 typed extra 传递，永远不进 URL（R15-1 守卫照旧生效）。 |
| 身份投影 | `PublicProfileIdentity.profile` 只在既有命令目标又有规范 LOOP ID 时给出 `LoopPublicProfile`。搜索快照的副标题不是 LOOP ID 时没有投影，会话页就以无名方式打开，而不是编一个名字。 |
| 自己的卡片 | 不画这个按钮。成员目录知道自己那行（`entry.isSelf`）；搜索不知道，于是由卡片比对当前账号已经读到的 LOOP ID（`profileControllerProvider` 的现有状态，不发起任何读）。两个判断合并在 `publicProfileDirectMessageOffered` 一个纯函数里。 |
| 准入留在会话页 | 卡片不预判好友关系，也不在这里发请求。没有 friendship 时，`dm` 页照旧显示「还不能直接私聊」并提供「发送消息请求」——那一步才是把两个人连起来的动作。 |
| 收件箱 | 生产版 `StreamChatInboxPage` 在会话列表上方补「陌生人请求」入口 → `/chat/requests`，形态取自 `#scr-community` 消息中心那一行。**不显示数字**：LOOP 没有可在不打开请求列表的前提下读到的待处理计数，没人读过的数不画。 |
| 「添加好友」 | 终点仍是 `/search`，但菜单项加副标题「搜索用户并发送消息请求」，说明这条路走到哪里。 |
| 群资料页成员行 | **本次不做**，见下节偏离。 |

## 与原型的偏离

1. **资料卡是中间层。** 原型里成员行、搜索的用户行本身就是 `dm`，点一下直接
   进会话。LOOP 多一层公开资料卡：因为同一行还要承载关注与服务端下发的治理
   动作，而 LOOP 没有「别人的资料页」。接受这一偏离；代价是多一次点击，换来
   一个能同时放关注、治理与私聊的固定位置。
2. **群资料页成员行没有私聊。** `group-info` 的成员目录整体仍是
   `GROUP_MEMBER_DIRECTORY_DEFERRED`：服务端没有群成员目录接口，而群内显示名
   是 persona，按契约「永远不画 `user.id`」，客户端拿不到也不允许由 Stream 成员
   推出 `publicProfileId`。即使拿得到，把群内匿名人格接到公开资料上也会把
   persona 的匿名性反解开，这需要一次产品裁决而不是一次前端实现。等群成员目录
   契约（带 `publicProfileId` 与每行动作）落地后再做。
3. **收件箱没有未读/待处理数字。** 原型消息中心写「2 条请求待处理」。那条行在
   Community 面板上有来源时才带数字；收件箱这一行没有来源，于是只写它能做什么。

## 与决策 0073 的关系

0073 规定成员行的**行内动作**完全由服务端 `items[].actions` 决定，客户端不得
自加行内入口。私聊没有违反它，也没有豁免它：

- 私聊不是行内动作，不进 `entry.actions` 渲染的那个列表，也不参与那段代码；
  `check_harness.py` 对该列表「不得过滤、不得由观察者标记推导」的守卫原样保留。
- 它是资料卡上的**固定控件**，和「关注」同级。关注同样不在服务端下发的清单里
  ——它不是治理动作，成不成由社交图谱与对方的隐私设置决定，服务端在写接口上
  校验。私聊同理：能不能发起由 friendship 与对方的社交开关决定，服务端在
  `POST /v2/chat/direct-channels` 与 `POST /v2/message-requests` 上校验，客户端
  只负责把用户带到那个会答复它的页面。
- 0073 要消灭的是「注定 403 的行内治理入口」。私聊的被拒不是权限矩阵的死路，
  而是一条要走完的流程（发请求 → 对方接受），会话页把这条流程写在脸上。

## Consequences

- 用户能从搜索或成员列表找到一个人并把关系建立起来，这条路第一次是通的：
  搜索 → 资料卡 → 打开私聊 → 发送消息请求。
- 服务端当前对没有社交开关行的账号返回 `NOT_FOUND`（S75b 正在改）。客户端不
  绕：那是 `dm` 页现成的失败态，显示「目标不存在、已被移除，或对当前账号不
  可见」，不伪造成功，也不在本地放行。
- 资料卡不再有任何禁用控件；`lib/` 里不再有「私聊还不能从这里发起」这句话。
- 仍然拒绝：由 alias、LOOP ID 或 Stream `user.id` 推 `publicProfileId`；在 URL
  里带对方的名字；在卡片上预判好友关系；给任何一个没有读过的计数画数字。

## Evidence

- `test/community_public_profile_and_apply_test.dart` → `public profile sheet`：
  成员列表 → 资料卡 → 打开私聊，回调拿到完整四字段投影且卡片随之关闭；没有
  回调的调用方不渲染该控件，也不再出现旧文案；自己的卡片不带控件；
  `publicProfileDirectMessageOffered` 的 LOOP ID 比对与缺命令目标两条分支。
- `test/community_social_pages_test.dart` → `search`：用户结果 → 资料卡 →
  打开私聊，只有服务端的 `stableId` 作为命令目标，规范 LOOP ID 才随行。
- `test/stream_chat_inbox_page_test.dart`：收件箱有「陌生人请求」入口，点进
  `dm-requests` 页，且不画任何请求条数。
