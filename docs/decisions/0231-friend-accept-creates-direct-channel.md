# 0231 · 接受好友请求后由接受方立即建好私聊频道（S272）

## Status

Accepted 2026-10-22。基线 `integration/v2` 273c6b41（TestFlight build 40）。主代理下单 S272；问题来自需求方：「添加好友后没出现在列表」。
不新增依赖，`pubspec.lock` 不变；路由清单不变；不改 loop-api（staging `d5ba35a` 已有的 `POST /v2/chat/direct-channels` 足够）。

## Context

现象：好友请求被接受后，聊天 Tab 的「好友」筛选仍是空态「还没有好友会话 / 找朋友」，整个会话列表里也找不到这位好友。

根因（逐条核对过主代理给的四个假设）：

1. **成立**——接受只写好友关系，不建频道。手机端「接受」走 `MessageRequestsController.decide`（`lib/features/social/social_controllers.dart`）→ `POST /v2/message-requests/:id/decision`；后端 `loop-api/src/database/community-repository.ts` `decideMessageRequest`（约 L3229–3400）在事务里只做 `friend_requests.status = 'accepted'` 和 `insert into public.friendships`，没有 `direct_channels` 行，也不调 Stream。
   私聊频道只有 `POST /v2/chat/direct-channels`（get-or-create，`loop-api/src/routes/v2/chat.ts` L152）会建，而手机端唯一的调用点是会话页 `DirectMessageScreen` → `DirectChannelController.open`（`lib/features/chat/v2/chat_v2_controllers.dart` L180），也就是用户从资料卡点「私聊」进去时才建。
2. 不成立——后端建的 ID 是 `loop_direct_<32 hex>`（`chat-channel-repository.ts` L111），正是 `loopChatSurfaceForCid` 的 `_directChannelPrefix`（`lib/core/navigation/stream_channel_route.dart` L54），归为 `direct`，会进「好友」筛选。
3. 不成立——收件箱查询 `type = messaging` 且 `members ∋ 我`（`stream_chat_inbox_page.dart` L99），后端建的私聊频道两人都是成员。
4. 不成立——接受本身在 staging 是成功的（返回 200、出「已接受」Toast）；问题是成功之后什么都没发生。

所以「好友」筛选列的是 Stream 频道而不是好友关系（`ChatInboxFilter.friends.includes`，L180–190），一段新建立、还没人点开过的好友关系在列表里不可见。
附带：`lib/features/chat/friends/` 下 v1 的 `FriendRequestsController` / `FriendDirectController` 没有任何页面在用，本单不动。

## Decision

1. 新增 `lib/features/social/accepted_friend_direct_channel.dart`：`AcceptedFriendDirectChannel.ensure(publicProfileId)` 调 `chatV2GatewayProvider.openDirectChannel`（即 `POST /v2/chat/direct-channels`，后端幂等 get-or-create），非终态按 `retryAfterMs`（缺省 500 ms）轮询，预算 12 次，与会话页一致。
   成功拿到 `streamCid` 后 `invalidate(directChannelDirectoryProvider)`，让收件箱用新索引给这一行配上对方的名字，而不是中性标签。
2. `MessageRequestsController.decide`：服务端确认的是 `accept` 且 `blocked == false` 时，取这条请求的 `profile.publicProfileId`，`unawaited(ensure(...))`。`ignore` / `report` / 被拒绝（返回 null）都不建频道。
3. 尽力而为、不报错：好友关系已经成立，失败只意味着回到原来的路径（资料卡点「私聊」会再跑同一个 get-or-create）。不弹 Toast、不改「已接受」的文案。
4. `acceptedFriendDirectChannelProvider` 是不随页面释放的 `Provider`，并且在 `decide` 的 `await` 之前就读好：用户接受后马上离开请求页，频道照样建完。同一位好友同时多次调用共用一个进行中的操作。
5. 请求方那一侧不需要做任何事：频道两人都是成员，请求方的 Stream 客户端收到 `notification.added_to_channel`，`StreamChannelListController` 的默认事件处理会把这一行加进列表；没开着收件箱的话，下次进入时的查询也会读到。

## Consequences

- 测试：新增 `test/s272_friend_accept_direct_channel_test.dart`（接受后对请求方调用一次 get-or-create 并轮询到终态、`loop_direct_` CID 属于「好友」筛选；忽略 / 举报 / 被拒绝不建；离开页面不取消；成功后刷新私聊索引；并发去重；失败吞掉返回 false；聊天网关不可用时不调用）。先在未改的控制器上跑过，前两条按预期失败。
- 已有数据：本修复之前在 staging 接受的好友关系仍然没有频道，「好友」筛选里依旧看不到，直到任一方从资料卡点「私聊」。是否需要一次性补数（对 `friendships` 里没有对应 `direct_channels` 行的每一对调用 get-or-create，需以其中一方的身份或后端内部入口执行）由主代理决定；本单未碰 staging。
- 已知边界：如果接受后 App 立刻被杀、或网络在那一刻断开，频道不会建，回落到资料卡路径。要彻底消除这个窗口，需要后端在接受事务里同时排一个 `direct_get_or_create` 操作交给 worker——跨了 community / chat-channel 两个仓储，留作后续单。
- 对方关闭了私信（`direct_messages = disabled`）时后端拒绝建频道，`ensure` 返回 false，与资料卡路径的表现一致。
