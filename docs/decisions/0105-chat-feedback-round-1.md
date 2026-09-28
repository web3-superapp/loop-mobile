# 0105 · 聊天真机反馈第一轮（S99）

## Status

Proposed 2026-09-28。S99，客户端单侧。基线 `integration/v2` f830ba1。不新增依赖、`pubspec.lock`
不变、路由清单不变（93 条，没有新增 GoRoute；`/c/{id}/room` 与 0104 的 `/u/{id}` 一样只是 redirect）。

## Context

需求方在 iPhone 上用社区群聊「DeFi 早读会」反馈六条（第 6 条为主代理追加）：

1. 点「回复」后聊天区整片空白，只剩输入框和键盘，消息「跑到最下方」。
2. 自己（Lime 气泡）消息里的引用块看不清。
3. 任何成员都能置顶消息。
4. 语音房没有分享。
5. 通知设置点一下就切换，容易误关。
6. 聊天有新消息没有提示。

另：隐私中心两条文案按 `loop-api/docs/frontend-v2-profile-api.md`（后端决策 0090）对齐。

## Decision

### 1 · 回复态的消息列表

**根因。** Stream 的消息列表是反向（`reverse: true`）的 `ScrollablePositionedList`，它把锚点消息放在
`alignment × 视口高度` 处，而不是按像素偏移。进入一个有未读的房间时，Stream 以未读分隔线为锚、
`alignment = 0.5`（`message_list_view.dart:334`）。之后视口每少一点高度——键盘升起、回复横条出现在
输入框里——内容就以视口中线为基准整体下移半个单位，滚动偏移却不变。结果是最新消息被推到输入框下面，
读者看到的是列表上半截的空白。`SafeArea` / `viewInsets` 没有重复扣减（`enableSafeArea: false`，
Scaffold 只扣一次键盘），列表高度本身是对的，错的是锚点。

**改法。** `_LoopChannelBody` 自己持有列表的 `ItemScrollController` 与 `ItemPositionsListener`：

- 点「回复」时先 `jumpTo(index: 0)`：回复写在房间底部，就从底部读，最新消息贴着回复横条。
- 输入框获得焦点（键盘即将升起）时，把当前看到的底部那条消息改写为「这条消息、离底边这么远、偏移为 0」
  重新锚定；已经在底部的直接锚到 index 0。此后高度变化从列表顶部收缩，而不是从中线两头收缩。

不改 Stream 的 `reverse`、不加 padding、不碰 SafeArea。

### 2 · 外发气泡里的引用块

**根因。** 全局 `quotedMessageTheme` 给的是 Card 底 + Lime 竖条 + text2/text3 灰字，这是按 Ink 底设计的；
放进 Lime 气泡后是半透明 Chalk 叠 Lime、Lime 竖条叠 Lime，灰字在 Lime 上几乎不可读。

**改法。** 注册 `StreamComponentBuilders.quotedMessage = loopStreamQuotedMessageBuilder`
（`lib/integrations/communication/stream_chat_appearance.dart`）：`StreamMessageLayout` 对齐为 `end`
（外发）时画 `LoopOutgoingQuotedMessage`——Ink 12% 底、Ink 文字（名字 label 12、预览 caption 11；名字只用本会话
解析出的显示名 `loopStreamDisplayLabelOf`，解析不到就不画名字，harness 规则禁止印 Stream 账号名）、
左侧 3 dp Ink 竖条、`LoopRadius.inner`；接收气泡仍走 `DefaultStreamQuotedMessage` + 全局主题，不变。
输入框里的回复横条不在消息布局里，不受影响。

### 3 · 置顶权限

**根因。** 「置顶到会话 / 取消置顶」来自 Stream 默认长按菜单，条件是频道 `pin-message` 能力；LOOP 社区频道
给所有成员都开了这个能力。`loop_stream_channel_surface.dart` 第 691 行的 `LoopChannelPinnedNotice`（「置顶公告」）
是没有调用方的旧组件，不是入口。

**改法。**

- `CommunityViewer.mayPinMessages`：`myMembership.role` 为 `owner` / `admin` 时为真；无成员身份或未知角色为假。
- `LoopStreamChannelSurface(mayPinMessages:)` → `LoopChannelMessagePolicy`（InheritedWidget）→
  `loopStreamGroupMessageItemBuilder` 在 props 上套一层 `actionsBuilder`，删掉 `PinMessage` / `UnpinMessage`。
  只删不加：Stream 本身不给的动作，策略也不会加。
- `community-chat` 传 `detail.viewer.mayPinMessages`；私聊与好友群不传（`null`），仍由 Stream 能力决定。
- 客户端只是第一道门，后端会在 Stream 侧同步收紧 `pin-message`。

### 4 · 语音房分享与 `/c/{communityId}/room`

- 语音房顶栏（`voiceroom` / `voiceroom-full`）在房间 **进行中** 时加分享图标（`LoopIconButton` `share`，与 0104
  「我的」同一组件、同一 `loopTextShareProvider`）。已结束的房间不画——链接会落到「语音房已结束」。
- 分享文本：`来 LOOP 的『{社区名}』语音房：{房间标题}` + 换行 + `{LOOP_BACKEND_BASE_URL 的 scheme+host}/c/{communityId}/room`；
  未配置后端时只分享第一行。房间资源没有自己的标题（后端决策 0052），房间标题就是页面标题「{社区名} 语音房」。
  面板打不开时 Toast「无法打开分享」。
- 深链：顶层 redirect 识别 `/c/{id}/room`（`^/c/[A-Za-z0-9_-]{1,64}/room/?$`），改写为
  `/community/profile?id={id}&room=live`（manifest `community-profile`）。登录前到达的链接存进 0104 的
  `LoopProfileLinkInbox`（新增 `holdRoom` / `takeRoom`），账号照常落 `community`，再把社区资料页 push 上去。
  格式不对的 `/c/...` 按未知路由记错并回社区。
- `community-profile` 收到 `room=live` 后，等服务端的新读数（不用恢复出的快照）：
  - 房间进行中 → 用页面已有的 `onOpenVoiceRoom` 打开语音房（叠在资料页上，返回回到资料页）；
  - 没有进行中的房间 → 留在资料页，Toast「语音房已结束」；
  - 非成员 → 留在资料页，Toast「加入社区后才能进入语音房」。
  只应答一次，从房间返回不会再次进房。
- Android：`MainActivity` 把 `/c/{id}/room` 与 `/u/{id}` 一样交给路由；manifest 的 autoVerify intent-filter
  增加 `pathPrefix="/c/"`。iOS：entitlements 已有 `applinks:api-dev` / `applinks:api-staging`，只改注释。

### 5 · 通知设置误触

- 「已开启 → 已关闭」先弹确认 sheet（`confirmCommunityAction`，即 `showLoopSheet`）：标题「关闭『{类别}』通知？」，
  说明为该类别现有副文案（`LoopNotificationCategory.detail`；没有副文案的类别用「关闭后不会再收到这一类通知。」），
  按钮「关闭」/「取消」。取消不写任何东西。
- 「已关闭 → 已开启」不确认，直接写。
- 「安全事件」仍锁定、不可点。
- 减弱动效：`showLoopSheet` 在 `MediaQuery.disableAnimations` 下用零时长控制器，sheet 直接出现。

### 6 · 未读提示

- 数据源：已连接的 Stream Chat 客户端自己的 `state.totalUnreadCount` / `totalUnreadCountStream` 与各频道
  `state.unreadCount` / `unreadCountStream`，随现有 websocket 事件更新；不新开连接、不调接口。
- `streamChatUnreadTotalProvider`（`lib/integrations/communication/stream_chat_unread.dart`）：socket
  `connected` 时给 Stream 的总数，否则 `null`；没有会话（未登录、Preview、未配置 Stream）也是 `null`。
- 展示（`lib/widgets/loop_unread_badge.dart`）：`null` 与 `0` 都不画；>99 显示 `99+`；有数字为 16 dp 高胶囊，
  无数字为 8 dp 圆点；颜色 `LoopColors.danger`（主题里现有的警示红，Ink 与 Lime 底上都可读）；不进语义树，
  数量写进所在控件的语义标签。
  - 社区页顶栏消息入口（铃铛）：总未读胶囊；Preview 模式不画。
  - 消息面板「聊天」行副标题：`{n} 条未读消息`；有 Stream 读数时隐藏服务端「未读总数还没有开放」卡片。
  - 会话列表每行：时间右侧显示该频道未读胶囊（`loopStreamChannelListTrailing`，私聊与群两种单元格共用），
    Stream 自带的未读徽标关掉，避免出现两个。
- 清零：沿用 Stream 列表的 `markReadWhenAtTheBottom`，读到底部后 `channel.markRead()`，事件回来后总数与行徽标归零。
- 底部 Tab 不加红点：五个 Tab 里没有聊天入口（聊天是社区的子域）。

### 隐私中心文案

- 身份卡第二行开关由「显示 LOOP ID」改名为「可被发现」；副标题：开 =「允许别人按昵称搜到你、关注你；LOOP ID 始终可被精确搜索」，
  关 =「别人无法按昵称搜到你或关注你；LOOP ID 始终可被精确搜索」。开关行副标题允许两行。
- 「允许陌生人发消息请求」改为「允许陌生人发好友申请」；副标题：开 =「知道你 LOOP ID 的人可以加你」，关 =「陌生人无法向你发好友申请」。
  不再提示「还需要开启显示 LOOP ID」——后端 0090 起好友申请不要求 `discoverable`。
- 引用旧名字的四处文案同步：搜索页范围说明、关注页提示与关注确认、挖矿匿名说明。

## 服务端需要做的（本单不含）

- `/.well-known/apple-app-site-association` 的 `components` 在 `/u/*` 之外补 `{"/":"/c/*"}`；
  `assetlinks.json` 不需要改（按域名验证）。
- Stream 侧收紧社区频道的 `pin-message`：只给 owner / admin 角色。
- `/c/{communityId}/room` 的网页落地页（未装 App 时）。

## Consequences

- 回复与键盘升起时会把列表重新锚定到读者当前看到的底部消息；读者如果正停在很早的历史里点回复，会被带回最新处。
  这是有意的：回复写在底部。
- 引用块在外发气泡里的外观由 LOOP 自绘，Stream 升级时 `DefaultStreamQuotedMessage` 的变化不会自动出现在外发气泡里。
- 分享文本里的链接主机沿用 `LOOP_BACKEND_BASE_URL`（api-dev / api-staging），正式短域名等生产环境再定（同 0104）。

## Evidence

`test/s99_chat_feedback_test.dart`（29 项）：

- 回复态（有未读 / 无未读两种进入方式）+ 300 pt 键盘：列表顶 = 可视区顶、列表底 = 输入区（含回复横条）顶、
  列表高 = 可视高 − 输入区；最新消息可见且离回复横条 < 64 pt。去掉修复后「有未读」一例失败（最新消息不在屏上），即真机现象。
- 外发引用：底色 = Ink 12%、非 Lime；竖条 Ink、3 dp；名字与预览为 Ink；接收气泡仍为 `DefaultStreamQuotedMessage`。
- 置顶：`mayPinMessages` 四种角色；member 长按菜单无「置顶到会话」，owner/admin 有；过滤器只删置顶/取消置顶。
- 分享：文本与链接、无后端时无链接；链接路径解析（合法、结尾斜杠、多段、空 ID、`/u/`）；进行中房间分享一次且文本正确；
  已结束房间无分享；深链在产品内打开社区资料页并带 `openLiveRoomOnArrival`；登录前到达先落社区再 push、返回回社区；
  畸形链接回社区；资料页收到链接时进行中直接开房、已结束提示「语音房已结束」、普通访问不自动开房。
- 通知：关需要确认、取消不写、确认写 `false`（安全事件仍为 `true`）、开不确认、安全事件不可点、减弱动效两帧内 sheet 就位、标题/说明来源。
- 未读：映射（null/0/负数/7/99/100→99+）；未连接为 null、连接后跟随 Stream 总数、读到 0 后不画、断线回到 null；
  无会话为 null；铃铛 16 dp 胶囊、警示红、语义标签带数量；8 dp 圆点；会话行徽标与 0 不画。

`test/stream_chat_appearance_test.dart` 源码扫描同步：两个会话单元格都经 `loopStreamChannelListTrailing`，
时间仍各由一次 `loopStreamChannelListTimestamp(channel)` 构造。

`test/support/loop_ground_probe.dart`：`_decorationFill` 增加 `ShapeDecoration`。Stream 的未读徽标（回到底部按钮上的数字）
用 `ShapeDecoration` 画底，探针原先看不到这层底，把 Ink 数字判成画在 Ink 页面上；真机截图上徽标是 Lime 底、清晰可读。
这是探针的盲区修正，不是豁免，全量测试未因此出现新的失败。

模拟器（emulator-5554，连 api-dev）截图 `/private/tmp/s99/`。
