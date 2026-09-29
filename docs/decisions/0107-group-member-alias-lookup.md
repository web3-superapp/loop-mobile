# 0107 · 群/社区聊天按 id 补查成员行，发送者显示群内昵称（S102）

## Status

Proposed 2026-09-29。S102，客户端单侧。基线 `integration/v2` a27b0ba。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条）。**修订** 0055 中「只用当前频道已加载成员表」的实现限制；0055 的合同
（只认当前成员的 v1 projection，缺失/非法/歧义一律「成员」，永不回落账户名或 Stream id）不变。

## Context

用户原话：「现在为什么在聊天中，我看到别人的名字都是成员，头像也是成员的汉字？不应该显示他们在群里边的名称吗？」

主代理用 Stream 服务端 `queryMembers` 核对 dev 三个社区频道（DeFi 早读会 317 人、Meme 观察室 33 人、
Alpha Signals 1 19 人）：每个成员的 member custom 都有完整的 `loop_group_alias` / `loop_group_alias_id` /
`loop_group_alias_version: 1`。服务端没有问题。

根因（客户端）：

1. `resolveLoopGroupMessageSenderLabel` 只在 `channel.state.channelState.members` 里找发送者，找不到回落「成员」，
   头像首字同源就是「成」。
2. 进房的成员身份查询（`LoopStreamMemberChannelBody._queryMemberChannel`，`queryChannelsOnline`）写的是
   **`memberLimit: 30`**，所以本地成员表只有 30 行。33 人的频道已经有 3 个人名字丢失，317 人的频道绝大多数发送者
   都是「成员」。即使调到 Stream 上限 100，大频道仍然不够。
3. 自己的成员行：Stream 把当前用户放在 `membership`，不保证在截断后的 `members` 里，所以自己的引用 / 被 @ 时也可能是「成员」。

排除的原因：S99b 把 owner/admin 改成 `channel_moderator` 后，`channel_role` / `is_moderator` 仍是 `Member`
的顶层字段（`Member._topLevelFields`），`role` 等其他键进 `extraData` 但不带 `loop_group_alias` 前缀，
不影响 projection 解析（单测 `a moderator member row still parses its Alias (S99b)` 用 `Member.fromJson` 钉住）。

旧注释（`LoopGroupMentionAutocompleteOptions`）说「不用 queryMembers 扩展」，理由是 Stream 只能按 `name`
匹配，而 LOOP 账号的 `name` 就是 id，**按输入的昵称前缀**去查会查错人或查不到。那条理由针对的是「按输入内容搜人」；
按 **Stream user id** 精确取行不涉及它：请求里没有昵称、没有账户名，返回的是和已加载行同构的 `Member`。

## Decision

1. 新增 `lib/features/chat/group_alias/group_member_directory.dart` 的 `LoopGroupMemberDirectory`，每个
   `Channel` 对象一份（`Expando`，客户端每 CID 一个 Channel，因此按频道缓存、二次进房复用）：
   - 可见消息需要的 id（发送者、@、置顶人、线程参与者、以及被引用消息的同样几项，深度 ≤3）里本地成员表没有的，
     合并去重，防抖 200 ms，每批 ≤50 个，`channel.queryMembers(filter: Filter.in_('id', ids), pagination: limit=批大小)`。
     Stream 文档的成员过滤字段是 `id`（不是 `user_id`）。
   - 查回的行只收请求过的 id；没返回的 id 记为「查过确实没有」（`absent`），不再请求；返回的行原样保存（不存名字），
     仍经 `resolveLoopGroupMessageSenderLabel` → `parseLoopGroupAliasMemberProjection` 同一 fail-closed 校验。
   - 失败：2 s、8 s 各重试一次，共 3 次；之后该 id 记为 `unavailable`，本次会话不再请求。
   - websocket 未连接时不排队、不起计时器、不计失败；下一次连上后的重建再请求。
   - `member.added` / `member.updated` 用事件里的新行覆盖；`member.removed` 立即删除并记为 `absent`，退群的人马上回到「成员」。
   - 状态五分：`unrequested` / `pending` / `found` / `absent` / `unavailable`，UI 除 `found` 且校验通过外都显示「成员」，
     查询期间不闪烁到 id 或账户名。
2. 名册合并规则（`roster`）：频道已加载的 `members` 优先；缺自己时补 `membership`；再补目录查到的行。同一 id 只来自一个来源，
   解析器的「重复即歧义」规则仍只表示 Stream 自己答了两行。
3. 用到的地方：消息气泡（名字、头像首字、引用、@ 文本替换、置顶人、线程参与者；长按菜单预览渲染同一 item）、`@` 候选卡、
   发送前的 mention 命名（与候选同一名册）、会话列表群行的最后一条预览。频道 = 社区官方群与好友群（`communication_groups`，
   同一个 `LoopStreamChannelSurface`），两者一并覆盖。
4. 进房查询 `memberLimit` 30 → 100（Stream 上限），提高首屏命中；不依赖它。收件箱列表的 `memberLimit` 保持 30（多频道，
   只为最后一条预览按需补查）。
5. `@` 候选仍不按输入内容查询服务端；已加载或已按 id 查到的人才出现在候选里。
6. harness：`scripts/check_harness.py` 把 `group_member_directory.dart` 列为第二个允许使用 Stream 类型的 group-Alias 文件，
   并锁定 `Filter.in_('id', userIds)`、批大小上限、重试上限、离线不排队几个片段与新测试标题。

## Consequences

- 不在范围：聊天搜索结果（`chat-search`）的发送者仍按 0055 显示中性「成员」——跨频道结果没有名册可查，本批不改；
  社区置顶条读的是后端公告 `byline`，与 Stream 成员无关。
- 大频道首屏会多出 1～2 次 `GET /members`（每批 ≤50 个 id），此后按需；失败最多 3 次。
- 真机未验证：DeFi 早读会（317 人）里非前 100 的发送者显示昵称；滚动加载更早消息时新发送者陆续补齐；
  离线→在线后补查；有人退群后立即变「成员」。

## Evidence

- `test/s102_group_member_lookup_test.dart`：moderator 行解析；去重/防抖/分批 50+50+20 与 absent 不再请求；离线不排队；
  退群事件立即回到「成员」；前 100 人名册下第 150 人的消息查后显示昵称（@ 候选与发送前命名同样可用）；
  查询始终失败保持「成员」且恰好 3 次后不再请求；查回非法 projection 仍 fail-closed、未请求的行被忽略；前 100 人内的发送者不请求。
